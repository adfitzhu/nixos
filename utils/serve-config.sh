#!/usr/bin/env bash
# Serve NixOS config over HTTP for remote rebuilds
# Usage: ./serve-config.sh

set -euo pipefail

PORT=80
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== NixOS Config HTTP Server ==="
echo "Project directory: $PROJECT_DIR"
echo

# Open firewall port
echo "Opening firewall port $PORT..."
sudo iptables -I nixos-fw 3 -p tcp --dport "$PORT" -j nixos-fw-accept
echo "✓ Port $PORT opened (temporary - will reset on reboot/rebuild)"
echo

# Trap to clean up on exit
cleanup() {
    echo
    echo "Cleaning up..."
    sudo iptables -D nixos-fw -p tcp --dport "$PORT" -j nixos-fw-accept 2>/dev/null || true
    echo "✓ Firewall rule removed"
}
trap cleanup EXIT INT TERM

# Get local IP
LOCAL_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)192\.168\.\d+\.\d+' | head -n1)

echo "=== Server running ==="
echo "Local: http://localhost"
if [ -n "$LOCAL_IP" ]; then
    echo "Network: http://$LOCAL_IP"
    echo
    echo "Remote rebuild command:"
    echo "  sudo nixos-rebuild switch --flake http://$LOCAL_IP#<hostname>"
fi
echo
echo "Press Ctrl+C to stop server and close firewall port"
echo "=========================================="
echo

# Start HTTP server
cd "$PROJECT_DIR"
sudo python3 -m http.server "$PORT"
