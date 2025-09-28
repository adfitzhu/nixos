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

# Prepare a temporary secrets dir for user to drop an optional secrets.nix
TMP_SECRETS_DIR="/tmp/secrets"
mkdir -p "$TMP_SECRETS_DIR"
chmod 0700 "$TMP_SECRETS_DIR"

echo
echo "If you have a secrets.nix for this host, copy it to $TMP_SECRETS_DIR now."
echo "It will be copied into /etc/secrets for the installer run and into /mnt/etc/secrets for the installed system." 
read -p "Press ENTER to continue after copying (or Ctrl-C to cancel)..." _

SECRETS_SRC="$TMP_SECRETS_DIR/secrets.nix"
if [ -f "$SECRETS_SRC" ]; then
  echo "Found $SECRETS_SRC — installing into /etc/secrets and /mnt/etc/secrets"
  mkdir -p /etc/secrets
  chmod 0700 /etc/secrets
  cp -f "$SECRETS_SRC" /etc/secrets/secrets.nix
  chown root:root /etc/secrets/secrets.nix
  chmod 0600 /etc/secrets/secrets.nix

  # Also copy into the target root so the installed system has it after first boot
  mkdir -p /mnt/etc/secrets
  chmod 0700 /mnt/etc/secrets
  cp -f "$SECRETS_SRC" /mnt/etc/secrets/secrets.nix
  chown root:root /mnt/etc/secrets/secrets.nix
  chmod 0600 /mnt/etc/secrets/secrets.nix
else
  echo "No secrets.nix found in $TMP_SECRETS_DIR — continuing without host secrets."
fi

# Run the installer for the selected host
nixos-install --impure --no-write-lock-file --flake github:adfitzhu/nixos#${SELECTED_HOST}

