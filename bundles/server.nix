{ config, pkgs, unstable, ... }:
{
  # Shared config for all desktop machines
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
  programs.nix-ld.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # Automatic boot failure recovery with boot counting
  boot.loader.timeout = 5;  # Give you 5 seconds to intervene manually
  boot.loader.systemd-boot.graceful = true;  # Enable graceful boot failure handling
  networking.networkmanager.enable = true;
  system.stateVersion = "25.05";


  environment.systemPackages = with pkgs; [
    flatpak
    git
    vlc
    p7zip
    corefonts
    vista-fonts
    btrfs-progs
    btrbk
    python3Full
    python3Packages.pyqt6
    docker-compose
 
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


  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
  
  security.rtkit.enable = true;

  services.openssh.enable = true;
  
  # Configure fail2ban with local network whitelist
  services.fail2ban = {
    enable = true;
    ignoreIP = [
      "127.0.0.0/8"      # Localhost
      "192.168.1.0/24"   # Local network - prevents btrbk backups from being banned
    ];
  };
  
  services.tailscale.enable = true;
    
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


nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
};

  # Docker defaults for server hosts
  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";
    autoPrune = {
      enable = true;
      dates = "daily";
      flags = [ "--all" ]; # Removed --volumes to protect database volumes
    };
    daemon.settings = {
      "log-driver" = "json-file";
      "log-opts" = {
        "max-size" = "10m";
        "max-file" = "3";
      };
    };
  };

  # Weekly prune of Docker builder cache older than 7 days
  systemd.services.docker-builder-prune-weekly = {
    description = "Prune Docker builder cache older than 7 days";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.docker}/bin/docker builder prune --filter until=168h -f";
    };
  };
  systemd.timers.docker-builder-prune-weekly = {
    description = "Weekly Docker builder cache prune";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  # Useful shell aliases for server management
  programs.bash.shellAliases = {
    "docker-status" = "docker ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'";
  };
}
