#!/bin/bash
# Initial backup setup script for alphanix
# Run this script as root after connecting the USB HDD to alphanix

set -euo pipefail

echo "=== BTRBK Backup Setup Script ==="
echo "This script will:"
echo "1. Mount the USB HDD"
echo "2. Perform initial backup of /cloud and /vol"
echo "3. Set up SSH keys for network backups"
echo ""

# Check if USB HDD is connected
if ! lsblk -f | grep -q "Elements"; then
    echo "ERROR: USB HDD with label 'Elements' not found!"
    echo "Please connect the USB HDD and try again."
    exit 1
fi

# Mount the USB HDD if not already mounted
if ! mountpoint -q /mnt/backup-hdd; then
    echo "Mounting USB HDD..."
    mount -t btrfs -o defaults,compress=zstd /dev/disk/by-label/Elements /mnt/backup-hdd
    echo "✓ USB HDD mounted at /mnt/backup-hdd"
else
    echo "✓ USB HDD already mounted"
fi

# Create backup destination directories
mkdir -p /mnt/backup-hdd/alphanix/snapshots/cloud
mkdir -p /mnt/backup-hdd/alphanix/snapshots/vol
echo "✓ Created backup destination directories"

# Perform initial backup
echo ""
echo "=== Performing Initial Backup ==="
echo "This may take a while depending on the size of /cloud and /vol..."
echo ""

# Run btrbk for the initial backup
btrbk --config /etc/btrbk/btrbk.conf run cloud-to-usb || {
    echo "Backup failed. Trying manual btrbk configuration..."
    
    # Create a temporary btrbk config for both volumes
    cat > /tmp/btrbk-initial.conf << 'EOF'
timestamp_format        long
snapshot_preserve_min   1d
snapshot_preserve       6h 7d 4w 3m
target_preserve_min     1d  
target_preserve         7d 4w 6m 1y
snapshot_create         onchange
incremental             yes

volume /cloud
    snapshot_dir        .btrbk_snapshots
    subvolume           .
    target              /mnt/backup-hdd/alphanix/snapshots/cloud

volume /vol
    snapshot_dir        .btrbk_snapshots
    subvolume           .
    target              /mnt/backup-hdd/alphanix/snapshots/vol
EOF
    
    echo "Using temporary config to perform initial backup of both /cloud and /vol..."
    btrbk --config /tmp/btrbk-initial.conf run
}

echo ""
echo "✓ Initial backup of /cloud and /vol completed!"

# Set up SSH keys for network backups
echo ""
echo "=== Setting up SSH Keys ==="

# Generate SSH key if it doesn't exist
if [ ! -f /root/.ssh/btrbk_rsa ]; then
    echo "Generating SSH key for btrbk..."
    ssh-keygen -t rsa -b 4096 -f /root/.ssh/btrbk_rsa -N "" -C "btrbk@alphanix"
    echo "✓ SSH key generated"
else
    echo "✓ SSH key already exists"
fi

# Display the public key for manual setup
echo ""
echo "=== SSH Public Key Setup ==="
echo "Copy this public key to webserver's btrbk user authorized_keys:"
echo ""
cat /root/.ssh/btrbk_rsa.pub
echo ""
echo "On webserver, run:"
echo "  echo '$(cat /root/.ssh/btrbk_rsa.pub)' >> /var/lib/btrbk/.ssh/authorized_keys"
echo ""

# Test SSH connection
echo "=== Testing SSH Connection ==="
echo "Testing SSH connection to webserver..."
if ssh -i /root/.ssh/btrbk_rsa -o ConnectTimeout=5 btrbk@192.168.1.10 "echo 'SSH connection successful'" 2>/dev/null; then
    echo "✓ SSH connection to webserver successful!"
else
    echo "⚠ SSH connection failed. Make sure:"
    echo "  1. webserver is running the updated NixOS configuration"
    echo "  2. The public key is added to webserver's btrbk user"
    echo "  3. SSH service is running on webserver"
fi

echo ""
echo "=== Next Steps ==="
echo "1. Physically move the USB HDD from alphanix to webserver"
echo "2. Rebuild webserver configuration: nixos-rebuild switch"
echo "3. Test network backups with: systemctl start btrbk-cloud-to-webserver"
echo ""
echo "Initial setup complete!"