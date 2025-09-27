#!/usr/bin/env bash

# Get all user directories in /mnt/home (excluding system users like 'nixos')
for userdir in /mnt/home/*; do
    if [ -d "$userdir" ]; then
        username=$(basename "$userdir")
        # Skip system users if needed
        if [ "$username" != "nixos" ]; then
            echo "Setting password for user: $username"
            # Use nixos-enter to enter the chroot and set the password
            echo "Run: passwd $username inside nixos-enter shell."
            nixos-enter --command "passwd $username"
        fi
    fi
done