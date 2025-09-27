# 1. Generate hardware config
nixos-generate-config --root /mnt
# 2. Get the config file in the right place for the flake symlink
cp /mnt/etc/nixos/hardware-configuration.nix /etc/nixos/hardware-configuration.nix

# Find flake.nix one directory up
FLAKE_FILE="$(dirname "$0")/../flake.nix"

# Extract host names from flake.nix: look for lines like 'name = nixpkgs.lib.nixosSystem {'
HOSTS=$(awk '
  /nixosConfigurations[[:space:]]*=/ {inBlock=1; depth=0; next}
  inBlock {
    nOpen = gsub(/{/, "{"); nClose = gsub(/}/, "}"); depth += nOpen - nClose
    if (/^[[:space:]]*[a-zA-Z0-9_-]+[[:space:]]*=[[:space:]]*nixpkgs\.lib\.nixosSystem/) {
      match($0, /^[[:space:]]*([a-zA-Z0-9_-]+)[[:space:]]*=/, m)
      if (m[1] != "") print m[1]
    }
    if (inBlock && depth < 0) inBlock=0
  }
' "$FLAKE_FILE")

# Convert to array for POSIX sh
set -- $HOSTS

# Present hosts as a numbered list
echo "Available hosts:"
i=1
for host in "$@"; do
    printf "%d) %s\n" "$i" "$host"
    i=$((i+1))
done

# Prompt user to select a host
read -p "Select a host number: " HOST_NUM

# Validate input
if [ "$HOST_NUM" -ge 1 ] 2>/dev/null && [ "$HOST_NUM" -le $# ]; then
    eval SELECTED_HOST=\${$HOST_NUM}
    echo "Selected host: $SELECTED_HOST"
else
    echo "Invalid selection."
    exit 1
fi
nixos-install --impure --no-write-lock-file --flake github:adfitzhu/nix#$SELECTED_HOST 

