#!/bin/sh
# setup.sh - initial post-install setup script

# Add Flathub repo for Flatpak (user scope, just in case)
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Run Flatpak installer before starting Tailscale
python3 "/usr/local/nixos/utils/install-flatpaks.py"

# Start Tailscale (will prompt for auth if not already up)
echo "Starting Tailscale..."
sudo tailscale up

echo "Tailscale command issued. Follow prompts in your browser if needed."

# Symlink Update.desktop to user's Desktop for manual update access
ln -sf "/usr/local/nixos/utils/Update.desktop" "$HOME/Desktop/Update.desktop"
