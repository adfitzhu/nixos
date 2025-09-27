> **Inspiration:** This project was inspired by [nixbook](https://github.com/mkellyxp/nixbook). I liked the idea of the nixbook but wanted to make my own version using BTRFS, KDE, and some specific apps for my users' needs.

## Features
- Auto setup of BTRFS filesystems at install (not disko, just a shell script)
- Pre-configured home snapshots, and a custom dolphin context menu item to easily see different version of files and folders and restore if needed.
- Configs for various hosts and users 
- An initial flatpak installer to get systems up and running quickly with selectable sets of flatpaks that are easily changeable by users later through Discover.

## Automated Install Procedure

This guide will help you install NixOS using this flake-based configuration, fully automated with `autoinstall.sh`.

### Step 1: Prepare the Live Environment
- Boot the target machine with the latest NixOS **graphical installer ISO**.
- Connect to WiFi using the network applet in the system tray.
- Open Konsole

### Step 2: Clone this repository to the correct location
```sh
git clone https://github.com/adfitzhu/nix /tmp/nix
```

### Step 3: Run the installer
```sh
sudo sh /tmp/nix/install/autoinstall.sh
```

### Step 4: Follow the prompts
- Select the target drive from a numbered menu (e.g., `/dev/sda`).
- Verify the right one is listed and confirm deleting the entire thing by typing yes
- Enter a value for the swap partition size in GB. Entering 0 results in no swap.
- Select the system configuration you want to use (e.g., `generic`, `other build`) from a numbered menu.

### Step 5: Wait for the script to finish
- The script will partition and format the drive, generate hardware config, install NixOS, 

### Step 6: Set passwords
- When the install finishes, it will prompt for a root password and passwords for any configured users.
- Once passwords are set, install is complete and you can reboot.

### Step 7: Run the Setup script on your Desktop
- After rebooting and logging in, double-click the **Setup** icon on your Desktop to complete extra configuration.  It will install default flatpaks, set up tailscale, and more.

### Notes
- **All data on the selected drive will be erased.**
- This setup is intended for my personal use.  If you've found this and want to use it, feel free to clone it and modify for your own systems or users.  You can also test it out by using the generic option at install.

---

Enjoy your reproducible, flake-powered NixOS system!