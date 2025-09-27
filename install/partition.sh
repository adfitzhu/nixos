#!/bin/sh
set -eu

# partition.sh: Interactive partitioning and subvolume setup (no disko, pure shell)
# This script will:
# 1. Show available disks
# 2. Let user pick a disk
# 3. Partition, format, and set up btrfs subvolumes as in disko-config.nix
# 4. Do NOT mount anything (for use with graphical installer)

# 1. Show available disks
lsblk -dpno NAME,SIZE,MODEL | grep -v "/loop" || true

echo "\nWARNING: This will ERASE ALL DATA on the selected drive!"
DISKS=($(lsblk -dpno NAME | grep -v loop))
for i in "${!DISKS[@]}"; do
  echo "$((i+1)). ${DISKS[$i]}"
done
read -rp "Enter the number of the disk to partition: " DISKNUM
DRIVE="${DISKS[$((DISKNUM-1))]}"

echo "You selected $DRIVE"
read -rp "Are you sure you want to partition $DRIVE? This will destroy all data on it! (yes/NO): " CONFIRM
[ "$CONFIRM" = "yes" ] || { echo "Aborted."; exit 1; }

# Ask for swap partition size in GB
read -rp "Enter swap partition size in GB (0 for no swap): " SWAP_GB

# 2. Unmount and wipe
umount ${DRIVE}?* 2>/dev/null || true
swapoff ${DRIVE}?* 2>/dev/null || true
wipefs -a "$DRIVE"

# 3. Partition (GPT: bios, boot, [optional swap], root)
if [ "$SWAP_GB" -eq 0 ]; then
  parted --script "$DRIVE" \
    mklabel gpt \
    mkpart primary 1MiB 2MiB \
    set 1 bios_grub on \
    name 1 bios \
    mkpart primary fat32 2MiB 514MiB \
    set 2 esp on \
    name 2 boot \
    mkpart primary 514MiB 100% \
    name 3 root
  SWAP_PART=""
  if echo "$DRIVE" | grep -q nvme; then
    BOOT_PART="${DRIVE}p2"
    ROOT_PART="${DRIVE}p3"
  else
    BOOT_PART="${DRIVE}2"
    ROOT_PART="${DRIVE}3"
  fi
else
  SWAP_END=$((514 + SWAP_GB * 1024))
  parted --script "$DRIVE" \
    mklabel gpt \
    mkpart primary 1MiB 2MiB \
    set 1 bios_grub on \
    name 1 bios \
    mkpart primary fat32 2MiB 514MiB \
    set 2 esp on \
    name 2 boot \
    mkpart primary linux-swap 514MiB "${SWAP_END}MiB" \
    name 3 swap \
    mkpart primary "${SWAP_END}MiB" 100% \
    name 4 root
  if echo "$DRIVE" | grep -q nvme; then
    BOOT_PART="${DRIVE}p2"
    SWAP_PART="${DRIVE}p3"
    ROOT_PART="${DRIVE}p4"
  else
    BOOT_PART="${DRIVE}2"
    SWAP_PART="${DRIVE}3"
    ROOT_PART="${DRIVE}4"
  fi
fi

# Format boot partition with label 'boot'
mkfs.vfat -F32 -n boot "$BOOT_PART"

# Format swap partition with label 'swap' (if present)
if [ -n "${SWAP_PART:-}" ]; then
  mkswap -L swap "$SWAP_PART"
  swapon "$SWAP_PART"
fi

# Format root partition with label 'root'
mkfs.btrfs -f -L root "$ROOT_PART"

# 5. Create btrfs subvolumes (but do not mount for install)
mount "$ROOT_PART" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

# 6. Do NOT mount anything (for graphical installer compatibility)
echo "Partitioning, formatting, and subvolume setup complete. You may now use the graphical installer and assign mount points as needed."
