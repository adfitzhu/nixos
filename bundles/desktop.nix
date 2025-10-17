{ config, pkgs, unstable, ... }:
{
  # Shared config for all desktop machines
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
  programs.nix-ld.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.networkmanager.enable = true;
  system.stateVersion = "25.05";


  environment.systemPackages = with pkgs; [
    kdePackages.discover
    kdePackages.kdesu
    libreoffice
    libnotify
    kdePackages.kdialog
    flatpak
    git
    vlc
    p7zip
    corefonts
    vista-fonts
    btrfs-progs
    btrbk
    btrfs-assistant    
    kdePackages.filelight
    #rustdesk
    python3Full
    python3Packages.pyqt6
    wine
    steam-run
    #syncthingtray
    firefox
    google-chrome
    vscode
    kdePackages.yakuake
    digikam
  (import ../utils/dolphin-versions/dolphin-versions.nix { inherit pkgs; })
  unstable.tailscale
  ];
  services.flatpak.enable = true;
  systemd.services.flatpak-repo = {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };

  # Declarative Flatpak configuration (packages defined per host)
  services.flatpak.update.auto = {
    enable = true;
    onCalendar = "daily";
  };

  services.flatpak.uninstallUnmanaged = false;

  # Global flatpak overrides - allows all apps access to home directory
  services.flatpak.overrides = {
    global = {
      Context.filesystems = [ "home" ];
    };
  };
  time.timeZone = "America/Los_Angeles";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  services.printing = {
    enable = true;
    browsing = true;
    drivers = [ pkgs.epson-escpr2 ];
    extraConf = ''
      FileDevice No
      DefaultPrinter None
    '';
  };
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    pulse.enable = true;
    extraConfig.pipewire-pulse."99-no-ducking" = {
      "context.modules" = [
        # This override removes the cork/ducking modules from defaults
      ];
    };
  };
  security.rtkit.enable = true;
  xdg.portal = {
    enable = true;
    # Prefer the KDE portal backend so portal file choosers look like Dolphin/KDE.
    # Keep the GTK portal as a fallback for apps that need it.
    # The top-level alias was removed; use the explicit kdePackages path.
    extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde pkgs.xdg-desktop-portal-gtk ];
  };

  # Force GTK apps (including Firefox GTK builds) to use the xdg-desktop-portal
  # file chooser instead of the built-in GTK file chooser. Also enable
  # Wayland support in Firefox so portal usage behaves correctly under Wayland.
  environment.sessionVariables = {
    GTK_USE_PORTAL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };
  hardware.bluetooth.enable = true;
  services.openssh.enable = true;
  services.fail2ban.enable = true;
  services.tailscale.enable = true;
  services.tailscale.package = unstable.tailscale;
  services.fwupd.enable = true;
    
  services.btrbk.instances = {
    "home" = {
      onCalendar = "hourly";
      settings = {
        timestamp_format = "long";
        snapshot_preserve_min = "1d";
        snapshot_preserve = "6h 7d 4w 3m";
        volume = {
          "/home" = {
            snapshot_dir = ".snapshots";
            subvolume = ".";
          };
        };
      };
    };
  };
  # Ensure /home/.snapshots exists for btrbk
  systemd.tmpfiles.rules = [
    "d /home/.snapshots 0755 root root"
  ];

# Enable VirtualBox guest additions when this system runs as a VirtualBox VM
virtualisation.virtualbox.guest.enable = true;
services.xserver.videoDrivers = [ "virtualbox" ];

nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};
}
