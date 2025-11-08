#!/bin/bash
# Webserver backup setup script
# Run this script as root after moving the USB HDD to webserver

set -euo pipefail

echo "=== Webserver Backup Setup Script ==="
echo "This script will:"
echo "1. Verify USB HDD is connected and mounted"
echo "2. Set up btrbk user SSH access"
echo "3. Test backup configurations"
echo ""

# Check if USB HDD is connected
if ! lsblk -f | grep -q "Elements"; then
    echo "ERROR: USB HDD with label 'Elements' not found!"
    echo "Please connect the USB HDD and try again."
    exit 1
fi

# Check if HDD is mounted
if ! mountpoint -q /mnt/backup-hdd; then
    echo "ERROR: USB HDD not mounted at /mnt/backup-hdd"
    echo "The NixOS configuration should auto-mount it."
    echo "Try: mount /mnt/backup-hdd"
    exit 1
else
    echo "✓ USB HDD properly mounted"
fi

# Verify backup directories exist
if [ -d /mnt/backup-hdd/alphanix/snapshots/cloud ]; then
    echo "✓ Found existing cloud backups from alphanix"
    echo "  Backup count: $(ls -1 /mnt/backup-hdd/alphanix/snapshots/cloud 2>/dev/null | wc -l) snapshots"
else
    echo "⚠ No cloud backups found - this is expected if this is first setup"
    mkdir -p /mnt/backup-hdd/alphanix/snapshots/cloud
fi

if [ -d /mnt/backup-hdd/alphanix/snapshots/vol ]; then
    echo "✓ Found existing vol backups from alphanix"
    echo "  Backup count: $(ls -1 /mnt/backup-hdd/alphanix/snapshots/vol 2>/dev/null | wc -l) snapshots"
else
    echo "⚠ No vol backups found - this is expected if this is first setup"
    mkdir -p /mnt/backup-hdd/alphanix/snapshots/vol
fi

# Set up backup directories for webserver
mkdir -p /mnt/backup-hdd/webserver/snapshots/vol
echo "✓ Created webserver backup directory"

# Check btrbk user setup
if id btrbk >/dev/null 2>&1; then
    echo "✓ btrbk user exists"
else
    echo "ERROR: btrbk user not found. Make sure you've applied the NixOS configuration."
    exit 1
fi

# Prompt for SSH public key setup
echo ""
echo "=== SSH Key Setup ==="
echo "If you haven't already, add alphanix's public key to btrbk user:"
echo ""
echo "The key should be added to: /var/lib/btrbk/.ssh/authorized_keys"
echo ""
read -p "Have you added the SSH public key from alphanix? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "✓ SSH key setup confirmed"
else
    echo "Please add the SSH public key from alphanix setup script and run this script again."
    exit 1
fi

# Test local backup capability
echo ""
echo "=== Testing Local Backup ==="
echo "Testing btrbk configuration for local /vol backup..."

# Create a test btrbk config to verify it works
cat > /tmp/btrbk-test.conf << 'EOF'
timestamp_format        long
snapshot_preserve_min   1d
snapshot_preserve       6h 7d 4w 3m
target_preserve_min     1d
target_preserve         7d 4w 6m 2y
snapshot_create         onchange
incremental             yes

volume /vol
    snapshot_dir        .btrbk_snapshots
    subvolume           .
    target              /mnt/backup-hdd/webserver/snapshots/vol
EOF

echo "Running dry-run test..."
if btrbk --config /tmp/btrbk-test.conf --dry-run run 2>/dev/null; then
    echo "✓ Local backup configuration is valid"
else
    echo "⚠ Local backup test failed - this might be normal if /vol doesn't have btrfs subvolumes"
fi

# Check systemd services
echo ""
echo "=== Checking Services ==="
if systemctl list-unit-files | grep -q "btrbk-vol-to-hdd"; then
    echo "✓ btrbk systemd service found"
    echo "  Status: $(systemctl is-enabled btrbk-vol-to-hdd.timer || echo 'not enabled')"
else
    echo "⚠ btrbk systemd service not found - make sure NixOS config is applied"
fi

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Available operations:"
echo "1. Test network backup reception:"
echo "   systemctl status btrbk-*"
echo ""
echo "2. Manually trigger local backup:"
echo "   systemctl start btrbk-vol-to-hdd"
echo ""
echo "3. View backup status:"
echo "   btrbk list"
echo "   ls -la /mnt/backup-hdd/"
echo ""
echo "4. Check logs:"
echo "   journalctl -u btrbk-*"
echo ""
echo "The backup system is now configured!"