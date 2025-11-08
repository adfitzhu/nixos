{ config, pkgs, lib, unstable, ... }:

let
  # Path to docker-compose file (used by the systemd service restartTriggers and scripts)
  composeFile = ./compose/docker-compose.yml;
in
{
  # Host-specific settings for alphanix

  imports = [
    ../../bundles/desktop.nix
    ../../bundles/server.nix
    ../../bundles/gaming.nix
    ../../users/adam/user.nix
    ../../users/guest/user.nix
  ];

  
  # Network configuration
  networking = {
    hostName = "alphanix";
    useDHCP = false;
    interfaces.enp9s0 = {
      ipv4.addresses = [{
        address = "192.168.1.20";
        prefixLength = 24;
      }];
    };
    defaultGateway = "192.168.1.1";
    nameservers = [ "192.168.1.60" "192.168.1.1" ];
  };

  # Additional filesystem mounts
  fileSystems."/archive" = {
    device = "/dev/disk/by-label/Storage";
    fsType = "btrfs";
    options = [ "defaults" "compress=zstd" ];
  };

  fileSystems."/cloud" = {
    device = "/dev/disk/by-label/Storage";
    fsType = "btrfs";
    options = [ "defaults" "compress=zstd" "subvol=cloud" ];
  };

  fileSystems."/localdata" = {
    device = "/dev/disk/by-label/SU800";
    fsType = "btrfs";
    options = [ "defaults" "compress=zstd" "subvol=localdata" ];
  };

  fileSystems."/games" = {
    device = "/dev/disk/by-uuid/e10f657a-0e3c-4bf5-bfeb-7b8e35b8c155";
    fsType = "btrfs";
    options = [ "defaults" "compress=zstd" "subvol=games" ];
  };

  fileSystems."/vol" = {
    device = "/dev/disk/by-uuid/e10f657a-0e3c-4bf5-bfeb-7b8e35b8c155";
    fsType = "btrfs";
    options = [ "defaults" "compress=zstd" "subvol=vol" ];
  };

  environment.systemPackages = with pkgs; [ 
    pkgs.orca-slicer 
    pkgs.clonehero 
    pkgs.intel-gpu-tools  # For monitoring Intel GPU usage with intel_gpu_top
    # Backup management script (temporarily disabled due to path issues)
    # (pkgs.writeScriptBin "backup-manager" (builtins.readFile ../../utils/backup-manager.sh))
  ];

  services.flatpak.packages = [
    "com.discordapp.Discord"
    "com.obsproject.Studio"
    "com.github.tchx84.Flatseal"
  ];
  services.desktopManager.plasma6.enable = true;

  services.displayManager = {
    sddm.enable = true;
    sddm.wayland.enable = true;
    autoLogin = { enable = true; user = "adam"; };
  };


  hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        vpl-gpu-rt # for newer GPUs on NixOS >24.05 or unstable
      ];
    };

  # Sunshine game streaming service
  services.sunshine = {
    enable = true;
    capSysAdmin = true;
    openFirewall = true;
    settings = {
      channels = 2;
      # Encoding settings 
      encoder = "quicksync";    # Use Intel QuickSync 
      # encoder = "vaapi";      # Alternative: VA-API for Arc A770
      
      bitrate = 30000;          
      fps = 60;                
      hevc_mode = 2;           # Use HEVC/H.265 for better compression
      av1_mode = 0;            # Disable AV1 for now (compatibility)
      
      # Low-latency optimizations
      min_log_level = 2;       # Reduce logging overhead
      adapter_name = "Intel";  # Force Intel adapter for QuickSync
      
      # Encoder tuning for low latency
      qp = 28;                 # Lower QP for better quality/speed balance
      crf = 0;                 # Disable CRF, use CBR for consistent latency
      rc = "cbr";              # Constant bitrate for predictable latency
      
      # Frame pacing
      fec_percentage = 5;      # Forward error correction
      min_threads = 2;         # Minimum encoding threads
    };
    applications = {
      env = {
        PATH = "$(PATH):$(HOME)/.local/bin:/run/current-system/sw/bin";
        DISPLAY = ":0";        # Ensure X11 display is available
        WAYLAND_DISPLAY = "wayland-0";  # Ensure Wayland display is available
      };
      apps = [
        {
          name = "Desktop";
          prep-cmd = [
            {
              do = "${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.HDMI-A-1.disable";
              undo = "${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.HDMI-A-1.enable output.HDMI-A-1.position.1920,0";
            }
          ];
          exclude-global-prep-cmd = "false";
          auto-detach = "true";
        }
      ];
    };
  };



  # Docker configuration
  virtualisation.docker = {
    enable = true;
    storageDriver = "overlay2";
    autoPrune = {
      enable = true;
      dates = "daily";
      flags = [ "--all" "--volumes" ];
    };
    daemon.settings = {
      "log-driver" = "json-file";
      "log-opts" = {
        "max-size" = "10m";
        "max-file" = "3";
      };
    };
  };

  # Docker Compose service for all containers
  systemd.services.docker-compose-stack = {
    description = "Docker Compose application stack";
    after = [ "docker.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [ composeFile ];
    path = [ pkgs.docker pkgs.coreutils pkgs.bash ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      EnvironmentFile = "/vol/immich/immich.env";
    };
    script = ''
      set -euo pipefail
      echo "[compose-stack] Bringing application stack up" >&2
      # Change to the compose directory so relative paths work
      cd $(dirname ${composeFile})
      docker compose -f ${composeFile} up -d --remove-orphans
    '';
    preStop = ''
      set -euo pipefail
      echo "[compose-stack] Stopping application stack" >&2
      cd $(dirname ${composeFile})
      docker compose -f ${composeFile} down
    '';
  };

  # Syncthing system service
  services.syncthing = {
    enable = true;
    user = "adam";  # Run as adam user
    dataDir = "/home/adam/.local/share/syncthing";   # User-accessible location for Syncthing database
    configDir = "/home/adam/.config/syncthing";      # User-accessible location for Syncthing config
    openDefaultPorts = true;  # Opens ports 8384 (web UI), 22000 (sync), 21027 (discovery)
    
    # Let web UI configuration persist across rebuilds
    overrideDevices = false;    # Don't override devices added via web UI
    overrideFolders = false;    # Don't override folders added via web UI
    
    # Basic settings - you can configure more via web UI
    settings = {
      gui = {
        address = "0.0.0.0:8384";  # Allow access from any IP (useful for remote management)
        insecureAdminAccess = false;  # Require authentication
      };
      
      options = {
        extraFlags = [ "--no-default-folder" ];
        urAccepted = -1;
        urSeen = 9999;
        crashReportingEnabled = false;
      };
      
      folders = {
        "adam_documents" = {
          id = "adam_documents";
          label = "Adam's Documents";
          path = "/cloud/Documents/Adam's Documents";
        };
        
        "adam_music" = {
          id = "adam_music";
          label = "Adam's Music";
          path = "/cloud/Entertainment/Music/Adam's Music";
        };
        
        "beth_documents" = {
          id = "beth_documents";
          label = "Beth's Documents";
          path = "/cloud/Documents/Beth's Documents";
        };
        
        "beth_music" = {
          id = "beth_music";
          label = "Beth's Music";
          path = "/cloud/Entertainment/Music/Beth's Music";
        };
        
        "pictures" = {
          id = "pictures";
          label = "Pictures";
          path = "/cloud/Photos&Videos/Pictures";
        };
        
        "upload" = {
          id = "upload";
          label = "Instant Upload";
          path = "/cloud/Photos&Videos/Immich/library/admin";
          type = "sendonly";  # Send-only from server (one-way sync)
          ignorePerms = true;  # Ignore permission changes
        };
        
        "eli_documents" = {
          id = "eli_documents";
          label = "Eli's Documents";
          path = "/cloud/Documents/Eli's Documents";
        };
        
        "eli_music" = {
          id = "eli_music";
          label = "Eli's Music";
          path = "/cloud/Entertainment/Music/Eli's Music";
        };
        
        "eli_pictures" = {
          id = "eli_pictures";
          label = "Eli's Pictures";
          path = "/tmp/syncthing-placeholder/eli_pictures";
        };
        
        "steven_documents" = {
          id = "steven_documents";
          label = "Steven's Documents";
          path = "/cloud/Documents/Steven's Documents";
        };
        
        "steven_music" = {
          id = "steven_music";
          label = "Steven's Music";
          path = "/cloud/Entertainment/Music/Steven's Music";
        };
        
        "steven_pictures" = {
          id = "steven_pictures";
          label = "Steven's Pictures";
          path = "/tmp/syncthing-placeholder/steven_pictures";
        };
        
        "localsync" = {
          id = "localsync";
          label = "Local Sync";
          path = "/cloud/LocalSync";
        };
      };
    };
  };

  # NFS Server configuration
  services.nfs.server = {
    enable = true;
    exports = ''
      /cloud *(rw,sync,no_subtree_check,no_root_squash,fsid=0)
    '';
  };

  # Open firewall ports for NFS and Plex
  networking.firewall = {
    allowedTCPPorts = [ 
      
      2049 111 20048 # NFS ports
      32400          # Main Plex port
      3005           # Plex Companion
      8324           # Plex for Roku via Plex Companion
      32469          # Plex DLNA Server
      2283           # Immich web interface
    ];
    allowedUDPPorts = [ 
      
      2049 111 20048 # NFS ports
      1900           # Plex DLNA Server
      5353           # Bonjour/Avahi
      32410 32412 32413 32414  # GDM network discovery
    ];
  };

  # Samba Server configuration for Windows compatibility
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "alphanix";
        "netbios name" = "alphanix";
        "security" = "user";
        "map to guest" = "bad user";
        "guest account" = "nobody";
        "dns proxy" = "no";
      };
      "cloud" = {
        "path" = "/cloud";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "adam";
        "force group" = "users";
      };
    };
  };


  # Additional btrbk configurations for backup system
  services.btrbk.instances = {
    # Local snapshots of /cloud (alphanix)
    "cloud-local" = {
      onCalendar = "daily";
      settings = {
        timestamp_format = "long";
        snapshot_preserve_min = "2d";
        snapshot_preserve = "7d 4w 3m";
        snapshot_create = "always";
        
        volume = {
          "/cloud" = {
            snapshot_dir = ".btrbk_snapshots";
            subvolume = ".";
          };
        };
      };
    };
    
    # Local snapshots of /vol (alphanix)
    "vol-local" = {
      onCalendar = "daily";
      settings = {
        timestamp_format = "long";
        snapshot_preserve_min = "2d";
        snapshot_preserve = "7d 4w 3m";
        snapshot_create = "always";
        
        volume = {
          "/vol" = {
            snapshot_dir = ".btrbk_snapshots";
            subvolume = ".";
          };
        };
      };
    };
    
    # Network backup to webserver (both /cloud and /vol)
    "data-to-webserver" = {
      onCalendar = "weekly";
      settings = {
        timestamp_format = "long";
        snapshot_preserve_min = "2d"; 
        snapshot_preserve = "7d 4w 3m";
        target_preserve_min = "1w";
        target_preserve = "4w 6m 2y";
        incremental = "yes";
        
        ssh_identity = "/root/.ssh/btrbk_rsa";
        ssh_user = "btrbk";
        
        volume = {
          "/cloud" = {
            snapshot_dir = ".btrbk_snapshots";
            subvolume = ".";
            target = "ssh://192.168.1.10/mnt/backup-hdd/alphanix/snapshots/cloud";
          };
          "/vol" = {
            snapshot_dir = ".btrbk_snapshots";
            subvolume = ".";
            target = "ssh://192.168.1.10/mnt/backup-hdd/alphanix/snapshots/vol";
          };
        };
      };
    };
  };

  # Create mount point for USB backup HDD
  systemd.tmpfiles.rules = [
    "d /archive 0755 adam users - -"
    "d /cloud 0755 adam users - -" 
    "d /localdata 0755 adam users - -"
    "d /games 0755 adam users - -"
    # Docker volume directories
    "d /vol 0755 root root - -"
    "d /vol/plex 0755 root root - -"
    "d /vol/plex/config 0755 root root - -"
    "d /vol/plex/transcode 0755 root root - -"
    # Immich directories
    "d /vol/immich 0755 root root - -"
    "d /vol/immich/data 0755 root root - -"
    "d /vol/immich/db 0755 root root - -"
    # Backup mount point
    "d /mnt/backup-hdd 0755 root root - -"
    # Btrbk snapshots directories
    "d /cloud/.btrbk_snapshots 0755 root root - -"
    "d /vol/.btrbk_snapshots 0755 root root - -"
  ];

  systemd.services.my-auto-upgrade = {
    description = "Custom NixOS auto-upgrade (host-specific)";
    serviceConfig.Type = "oneshot";
    script = ''
      set -euxo pipefail
  ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --upgrade --refresh --flake github:adfitzhu/nixos#alphanix --no-write-lock-file --impure
    '';
  };
  systemd.timers.my-auto-upgrade = {
    description = "Run custom NixOS auto-upgrade weekly (host-specific)";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };
}

