#!/bin/bash
# Migrate /vol to btrfs subvolume on alphanix
# Run this script as root on alphanix BEFORE applying the new NixOS configuration

set -euo pipefail

echo "=== /vol to btrfs subvolume migration ==="
echo ""
echo "This script will:"
echo "1. Create a @vol btrfs subvolume on the root filesystem"
echo "2. Move existing /vol data to the new subvolume"
echo "3. Prepare for NixOS configuration change"
echo ""
echo "⚠️  WARNING: This modifies filesystem structure. Ensure you have backups!"
echo ""

# Verify we're on alphanix
if [[ "$(hostname)" != "alphanix" ]]; then
    echo "❌ This script should only be run on alphanix"
    exit 1
fi

# Check if /vol exists and has data
if [ ! -d "/vol" ]; then
    echo "❌ /vol directory doesn't exist"
    exit 1
fi

# Check current /vol contents
VOL_SIZE=$(du -sh /vol 2>/dev/null | awk '{print $1}')
echo "Current /vol size: $VOL_SIZE"

if [ -z "$(ls -A /vol 2>/dev/null)" ]; then
    echo "✅ /vol is empty, migration will be simple"
    EMPTY_VOL=true
else
    echo "📁 /vol contains data, migration will preserve it"
    EMPTY_VOL=false
fi

# Get root filesystem info
ROOT_FS=$(findmnt -no SOURCE /)
echo "Root filesystem: $ROOT_FS"

if [[ "$ROOT_FS" != *"btrfs"* ]]; then
    echo "❌ Root filesystem is not btrfs. Cannot create subvolume."
    exit 1
fi

echo ""
read -p "Continue with migration? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled"
    exit 1
fi

# Create temporary mount point for root btrfs
TMP_ROOT="/tmp/btrfs-root"
mkdir -p "$TMP_ROOT"

# Mount root btrfs filesystem
echo "🔧 Mounting root btrfs filesystem..."
mount -o subvol=/ "$ROOT_FS" "$TMP_ROOT"

# Check if vol subvolume already exists
if [ -d "$TMP_ROOT/vol" ]; then
    echo "⚠️  vol subvolume already exists"
    ls -la "$TMP_ROOT/vol"
    echo ""
    read -p "Remove existing vol subvolume? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        btrfs subvolume delete "$TMP_ROOT/vol"
        echo "✅ Removed existing vol subvolume"
    else
        echo "❌ Cannot proceed with existing vol subvolume"
        umount "$TMP_ROOT"
        exit 1
    fi
fi

# Create vol subvolume
echo "📁 Creating vol subvolume..."
btrfs subvolume create "$TMP_ROOT/vol"

# If /vol has data, copy it to the subvolume
if [ "$EMPTY_VOL" = false ]; then
    echo "📋 Copying existing /vol data to @vol subvolume..."
    rsync -avH /vol/ "$TMP_ROOT/vol/"
    echo "✅ Data copied successfully"
    
    # Verify copy
    ORIG_SIZE=$(du -sb /vol | awk '{print $1}')
    NEW_SIZE=$(du -sb "$TMP_ROOT/vol" | awk '{print $1}')
    
    echo "Original size: $ORIG_SIZE bytes"
    echo "New size: $NEW_SIZE bytes"
    
    if [ "$ORIG_SIZE" -ne "$NEW_SIZE" ]; then
        echo "⚠️  Size mismatch detected"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Migration aborted due to size mismatch"
            btrfs subvolume delete "$TMP_ROOT/vol"
            umount "$TMP_ROOT"
            exit 1
        fi
    fi
fi

# Set proper permissions on vol subvolume
chown root:root "$TMP_ROOT/vol"
chmod 755 "$TMP_ROOT/vol"

# Backup original /vol directory
echo "💾 Backing up original /vol to /vol.backup..."
mv /vol /vol.backup

# Create empty /vol directory for mount point
mkdir /vol

echo "✅ Migration completed successfully!"
echo ""
echo "Next steps:"
echo "1. Apply the NixOS configuration: nixos-rebuild switch"
echo "2. Verify /vol mounts correctly with the @vol subvolume"
echo "3. If everything works, you can remove /vol.backup"
echo ""
echo "If something goes wrong:"
echo "1. mv /vol.backup /vol"
echo "2. btrfs subvolume delete $TMP_ROOT/vol"
echo ""

# Cleanup
umount "$TMP_ROOT"
rmdir "$TMP_ROOT"

echo "🎉 Ready for NixOS configuration rebuild!"