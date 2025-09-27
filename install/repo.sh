mkdir -p /mnt/usr/local
git clone http://github.com/adfitzhu/nix /mnt/usr/local/nixos
for userdir in /mnt/home/*; do
    desktop_dir=$userdir/Desktop
    if [ -d "$userdir" ]; then
        username=$(basename "$userdir")
        mkdir -p "$desktop_dir"
        cp /mnt/usr/local/nixos/utils/Setup.desktop "$desktop_dir/"
        nixos-enter --root /mnt -- chown "$username" "/home/$username/Desktop/Setup.desktop"
        nixos-enter --root /mnt -- chmod 755 "/home/$username/Desktop/Setup.desktop"
    fi
done
