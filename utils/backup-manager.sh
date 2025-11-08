#!/bin/bash
# Backup system monitoring and management script

set -euo pipefail

show_usage() {
    cat << EOF
Backup System Management Script

Usage: $0 [COMMAND]

Commands:
    status      Show overall backup system status
    list        List all backups and snapshots
    test        Test backup configurations
    manual      Run manual backup operations
    monitor     Show live backup monitoring
    cleanup     Clean up old snapshots (interactive)
    help        Show this help message

Examples:
    $0 status              # Check system status
    $0 list                # Show all backups
    $0 manual cloud        # Manual backup of cloud
    $0 test network        # Test network connectivity
EOF
}

check_backup_health() {
    echo "=== Backup System Health Check ==="
    echo ""
    
    # Check if we're on alphanix or webserver
    HOSTNAME=$(hostname)
    echo "Host: $HOSTNAME"
    echo ""
    
    # Check USB HDD
    if lsblk -f | grep -q "Elements"; then
        if mountpoint -q /mnt/backup-hdd 2>/dev/null; then
            USED=$(df -h /mnt/backup-hdd | awk 'NR==2 {print $5}')
            AVAIL=$(df -h /mnt/backup-hdd | awk 'NR==2 {print $4}')
            echo "✓ USB HDD mounted - Used: $USED, Available: $AVAIL"
        else
            echo "⚠ USB HDD detected but not mounted"
        fi
    else
        echo "✗ USB HDD not connected"
    fi
    echo ""
    
    # Check btrbk services
    echo "=== Service Status ==="
    if systemctl list-unit-files | grep -q btrbk; then
        for service in $(systemctl list-unit-files | grep btrbk | awk '{print $1}'); do
            if [[ $service == *.timer ]]; then
                STATUS=$(systemctl is-active $service || echo "inactive")
                ENABLED=$(systemctl is-enabled $service || echo "disabled") 
                echo "$service: $STATUS ($ENABLED)"
            fi
        done
    else
        echo "No btrbk services found"
    fi
    echo ""
    
    # Check recent backups
    echo "=== Recent Backup Activity ==="
    if command -v btrbk >/dev/null; then
        echo "Last 5 journal entries:"
        journalctl -u "btrbk-*" --no-pager -n 5 --output=short-iso || echo "No btrbk journal entries"
    else
        echo "btrbk not installed"
    fi
}

list_backups() {
    echo "=== Backup Inventory ==="
    echo ""
    
    if [ -d /mnt/backup-hdd ]; then
        echo "USB HDD Contents:"
        find /mnt/backup-hdd -maxdepth 3 -type d | sort
        echo ""
        
        # Count snapshots by system and volume
        echo "=== Alphanix Backups ==="
        if [ -d /mnt/backup-hdd/alphanix/snapshots/cloud ]; then
            COUNT=$(ls -1 /mnt/backup-hdd/alphanix/snapshots/cloud 2>/dev/null | wc -l)
            echo "Cloud backups: $COUNT snapshots"
            if [ $COUNT -gt 0 ]; then
                echo "  Latest: $(ls -1t /mnt/backup-hdd/alphanix/snapshots/cloud 2>/dev/null | head -1)"
                echo "  Oldest: $(ls -1t /mnt/backup-hdd/alphanix/snapshots/cloud 2>/dev/null | tail -1)"
            fi
        fi
        
        if [ -d /mnt/backup-hdd/alphanix/snapshots/vol ]; then
            COUNT=$(ls -1 /mnt/backup-hdd/alphanix/snapshots/vol 2>/dev/null | wc -l)
            echo "Vol backups: $COUNT snapshots"
            if [ $COUNT -gt 0 ]; then
                echo "  Latest: $(ls -1t /mnt/backup-hdd/alphanix/snapshots/vol 2>/dev/null | head -1)"
            fi
        fi
        
        echo ""
        echo "=== Webserver Backups ==="
        if [ -d /mnt/backup-hdd/webserver/snapshots/vol ]; then
            COUNT=$(ls -1 /mnt/backup-hdd/webserver/snapshots/vol 2>/dev/null | wc -l)
            echo "Vol backups: $COUNT snapshots"
            if [ $COUNT -gt 0 ]; then
                echo "  Latest: $(ls -1t /mnt/backup-hdd/webserver/snapshots/vol 2>/dev/null | head -1)"
            fi
        fi
    else
        echo "No backup HDD mounted"
    fi
    echo ""
    
    # Show local snapshots
    if [ -d /cloud/.btrbk_snapshots ]; then
        COUNT=$(ls -1 /cloud/.btrbk_snapshots 2>/dev/null | wc -l)
        echo "Local cloud snapshots: $COUNT"
    fi
    
    if [ -d /vol/.btrbk_snapshots ]; then
        COUNT=$(ls -1 /vol/.btrbk_snapshots 2>/dev/null | wc -l)
        echo "Local vol snapshots: $COUNT"
    fi
}

test_system() {
    local TEST_TYPE=${1:-all}
    
    echo "=== Testing Backup System ==="
    echo ""
    
    if [[ "$TEST_TYPE" == "all" || "$TEST_TYPE" == "network" ]]; then
        echo "Testing network connectivity..."
        HOSTNAME=$(hostname)
        
        if [[ "$HOSTNAME" == "alphanix" ]]; then
            if ping -c 1 192.168.1.10 >/dev/null 2>&1; then
                echo "✓ Can reach webserver (192.168.1.10)"
                
                if ssh -i /root/.ssh/btrbk_rsa -o ConnectTimeout=5 btrbk@192.168.1.10 "echo 'SSH OK'" 2>/dev/null; then
                    echo "✓ SSH to webserver successful"
                else
                    echo "✗ SSH to webserver failed"
                fi
            else
                echo "✗ Cannot reach webserver"
            fi
        elif [[ "$HOSTNAME" == "webserver" ]]; then
            if ping -c 1 192.168.1.20 >/dev/null 2>&1; then
                echo "✓ Can reach alphanix (192.168.1.20)"
            else
                echo "✗ Cannot reach alphanix"
            fi
        fi
        echo ""
    fi
    
    if [[ "$TEST_TYPE" == "all" || "$TEST_TYPE" == "config" ]]; then
        echo "Testing btrbk configuration..."
        if command -v btrbk >/dev/null; then
            if btrbk --dry-run list >/dev/null 2>&1; then
                echo "✓ btrbk configuration is valid"
            else
                echo "✗ btrbk configuration has errors"
            fi
        else
            echo "✗ btrbk not installed"
        fi
    fi
}

manual_backup() {
    local TARGET=${1:-}
    
    if [ -z "$TARGET" ]; then
        echo "Available manual backup targets:"
        echo "  cloud     - Backup /cloud to USB HDD"
        echo "  vol       - Backup /vol to USB HDD" 
        echo "  network   - Run network backup to webserver"
        echo ""
        read -p "Select target: " TARGET
    fi
    
    case "$TARGET" in
        cloud)
            echo "Running manual cloud backup..."
            systemctl start btrbk-cloud-local || echo "Service may not exist"
            ;;
        vol)
            echo "Running manual vol backup..."
            systemctl start btrbk-vol-local || echo "Service may not exist"
            ;;
        network)
            echo "Running network backup..."
            systemctl start btrbk-data-to-webserver || echo "Service may not exist"
            ;;
        *)
            echo "Unknown target: $TARGET"
            exit 1
            ;;
    esac
}

monitor_live() {
    echo "=== Live Backup Monitor ==="
    echo "Press Ctrl+C to exit"
    echo ""
    
    while true; do
        clear
        check_backup_health
        echo ""
        echo "Refreshing in 30 seconds..."
        sleep 30
    done
}

cleanup_old() {
    echo "=== Cleanup Old Snapshots ==="
    echo "This will show you old snapshots that can be cleaned up"
    echo ""
    
    if command -v btrbk >/dev/null; then
        echo "Current btrbk retention policy will clean:"
        btrbk --dry-run clean 2>/dev/null || echo "No cleanup needed or btrbk config error"
    else
        echo "btrbk not available for automatic cleanup"
    fi
    
    echo ""
    read -p "Run cleanup? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        btrbk clean || echo "Cleanup failed or not needed"
    else
        echo "Cleanup cancelled"
    fi
}

# Main command processing
case "${1:-help}" in
    status|s)
        check_backup_health
        ;;
    list|l)
        list_backups
        ;;
    test|t)
        test_system "${2:-all}"
        ;;
    manual|m)
        manual_backup "${2:-}"
        ;;
    monitor|mon)
        monitor_live
        ;;
    cleanup|clean)
        cleanup_old
        ;;
    help|h|--help|-h)
        show_usage
        ;;
    *)
        echo "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac