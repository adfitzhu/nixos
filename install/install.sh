# 1. Generate hardware config
nixos-generate-config --root /mnt
# 2. Get the config file in the right place for the flake symlink
cp /mnt/etc/nixos/hardware-configuration.nix /etc/nixos/hardware-configuration.nix

# Find flake.nix one directory up
HOST_DIR="$(dirname "$0")/../hosts"

# List directories under hosts/ and present them to the user.
mapfile -t HOSTS < <(find "$HOST_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

if [ ${#HOSTS[@]} -eq 0 ]; then
  echo "No hosts found in $HOST_DIR"
  exit 1
fi

echo "Available hosts:"
for i in "${!HOSTS[@]}"; do
  printf "%d) %s\n" $((i+1)) "${HOSTS[i]}"
done

read -p "Select a host number: " HOST_NUM

if ! printf '%s' "$HOST_NUM" | grep -Eq '^[0-9]+$' || [ "$HOST_NUM" -lt 1 ] || [ "$HOST_NUM" -gt ${#HOSTS[@]} ]; then
  echo "Invalid selection."
  exit 1
fi

SELECTED_HOST="${HOSTS[$((HOST_NUM-1))]}"
echo "Selected host: $SELECTED_HOST"

# Run the installer for the selected host
nixos-install --impure --no-write-lock-file --flake github:adfitzhu/nixos#${SELECTED_HOST}

