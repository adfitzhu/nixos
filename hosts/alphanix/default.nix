{ config, pkgs, lib, unstable, ... }:

{
  # Host-specific settings for alphanix

  imports = [
    ../../bundles/desktop.nix
    ../../bundles/server.nix
    ../../bundles/gaming.nix
    ../../bundles/musicprod.nix
    ../../bundles/localAI.nix
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
    nameservers = [ "192.168.1.10" "192.168.1.1" ];
  };

  # Additional filesystem mounts
  fileSystems."/archive" = {
    device = "/dev/disk/by-label/Storage";
    fsType = "btrfs";
    options = [ "defaults" "compress=zstd" ];
  };

  fileSystems."/cloud" = {
    device = config.fileSystems."/archive".device;
    fsType = "btrfs";
    options = [ "defaults" "compress=zstd" "subvol=cloud" ];
  };

  fileSystems."/localdata" = {
    device = "/dev/disk/by-label/SU800";
    fsType = "btrfs";
    options = [ "defaults" "compress=zstd" "subvol=localdata" ];
  };

  fileSystems."/games" = {
    device = config.fileSystems."/".device;
    fsType = "btrfs";
    options = [ "defaults" "compress=zstd" "subvol=games" ];
  };

  fileSystems."/vol" = {
    device = config.fileSystems."/".device;
    fsType = "btrfs";
    options = [ "defaults" "compress=zstd" "subvol=vol" ];
  };

  environment.systemPackages = with pkgs; [ 
    pkgs.qpwgraph
    pkgs.orca-slicer 
    pkgs.clonehero 
    pkgs.intel-gpu-tools  # For monitoring Intel GPU usage with intel_gpu_top
    # Backup management script
    (pkgs.writeShellScriptBin "backup-manager" ''
      exec ${pkgs.bash}/bin/bash ${../../utils/backup-manager.sh} "$@"
    '')
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
              do = "${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-2.disable";
              undo = "${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor output.DP-2.enable output.DP-2.position.1920,0";
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

  # OCI Containers (Plex, Immich stack, etc.)
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      # Plex Media Server
      plex = {
        image = "plexinc/pms-docker:latest";
        autoStart = true;
        environment = {
          TZ = "America/Los_Angeles";
          PLEX_CLAIM = "<claimToken>";
        };
        volumes = [
          "/vol/plex/config:/config"
          "/vol/plex/transcode:/transcode"
          "/archive/cloud/Entertainment:/data"
        ];
        extraOptions = [
          "--network=host"
          "--device=/dev/dri:/dev/dri"
        ];
      };

      # Immich Server
      immich-server = {
        image = "ghcr.io/immich-app/immich-server:release";
        autoStart = true;
        dependsOn = [ "immich-redis" "immich-postgres" ];
        environment = {
          TZ = "America/Los_Angeles";
          # DB_HOSTNAME/REDIS_HOSTNAME use 127.0.0.1 since we're on host network
          DB_HOSTNAME = "127.0.0.1";
          DB_PORT = "5432";
          REDIS_HOSTNAME = "127.0.0.1";
          REDIS_PORT = "6379";
        };
        volumes = [
          "/cloud/Photos&Videos/Immich:/data"
          "/etc/localtime:/etc/localtime:ro"
          "/cloud/Photos&Videos:/external-storage"
        ];
        extraOptions = [
          "--network=host"
          "--device=/dev/dri:/dev/dri"
          "--env-file=/vol/immich/immich.env"
        ];
      };

      # Immich Machine Learning with OpenVINO for Intel Arc
      immich-machine-learning = {
        image = "ghcr.io/immich-app/immich-machine-learning:release-openvino";
        autoStart = true;
        environment = {
          # OpenVINO/Intel Arc optimizations
          MACHINE_LEARNING_CLIP_MODEL_TEXTUAL = "ViT-B-16-SigLIP2__webli";
          MACHINE_LEARNING_CLIP_MODEL_VISUAL = "ViT-B-16-SigLIP2__webli";
          MACHINE_LEARNING_MODEL_TTL = "600";
          MACHINE_LEARNING_REQUEST_THREADS = "4";
          MACHINE_LEARNING_MODEL_INTER_OP_THREADS = "2";
          MACHINE_LEARNING_MODEL_INTRA_OP_THREADS = "4";
          MACHINE_LEARNING_PRELOAD__CLIP__VISUAL = "ViT-B-16-SigLIP2__webli";
          MACHINE_LEARNING_PRELOAD__CLIP__TEXTUAL = "ViT-B-16-SigLIP2__webli";
        };
        volumes = [
          "immich-model-cache:/cache"
          "/dev/bus/usb:/dev/bus/usb"
          "/cloud/Photos&Videos:/external-storage:ro"
        ];
        extraOptions = [
          "--network=host"
          "--device=/dev/dri:/dev/dri"
          "--device-cgroup-rule=c 189:* rmw"
        ];
      };

      # Immich Redis
      immich-redis = {
        image = "docker.io/valkey/valkey:8-bookworm";
        autoStart = true;
        extraOptions = [
          "--network=host"
        ];
      };

      # Immich PostgreSQL
      immich-postgres = {
        image = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0";
        autoStart = true;
        environment = {
          # Non-sensitive settings inline, password from env file
          POSTGRES_INITDB_ARGS = "--data-checksums";
        };
        volumes = [
          "/vol/immich/database:/var/lib/postgresql/data"
        ];
        extraOptions = [
          "--network=host"
          "--shm-size=128mb"
          "--env-file=/vol/immich/immich.env"
        ];
      };

      # Paperless-ngx - Document management system
      # Web UI: http://localhost:8000
      paperless-redis = {
        image = "docker.io/valkey/valkey:8-bookworm";
        autoStart = true;
        extraOptions = [
          "--network=host"
        ];
        cmd = [ "valkey-server" "--port" "6380" ];  # Different port from Immich redis
      };

      paperless-postgres = {
        image = "docker.io/postgres:16";
        autoStart = true;
        environment = {
          POSTGRES_DB = "paperless";
          POSTGRES_USER = "paperless";
        };
        volumes = [
          "/vol/paperless/database:/var/lib/postgresql/data"
        ];
        extraOptions = [
          "--network=host"
          "--env-file=/vol/paperless/paperless.env"  # Contains POSTGRES_PASSWORD
        ];
        cmd = [ "-c" "port=5433" ];  # Different port from Immich postgres
      };

      paperless = {
        image = "ghcr.io/paperless-ngx/paperless-ngx:latest";
        autoStart = true;
        dependsOn = [ "paperless-redis" "paperless-postgres" ];
        environment = {
          PAPERLESS_REDIS = "redis://127.0.0.1:6380";
          PAPERLESS_DBENGINE = "postgresql";
          PAPERLESS_DBHOST = "127.0.0.1";
          PAPERLESS_DBPORT = "5433";
          PAPERLESS_DBNAME = "paperless";
          PAPERLESS_DBUSER = "paperless";
          # PAPERLESS_DBPASS from env file
          PAPERLESS_TIME_ZONE = "America/Los_Angeles";
          PAPERLESS_OCR_LANGUAGE = "eng";
          PAPERLESS_URL = "http://alphanix:8010";
          PAPERLESS_PORT = "8010";  # Run on port 8010 directly
          USERMAP_UID = "1000";
          USERMAP_GID = "100";
        };
        volumes = [
          "/vol/paperless/data:/usr/src/paperless/data"
          "/vol/paperless/media:/usr/src/paperless/media"
          "/vol/paperless/export:/usr/src/paperless/export"
          "/vol/paperless/consume:/usr/src/paperless/consume"
        ];
        extraOptions = [
          "--network=host"
          "--env-file=/vol/paperless/paperless.env"  # Contains PAPERLESS_DBPASS, PAPERLESS_SECRET_KEY
        ];
      };

      # VERT - File converter web UI
      # Web UI: http://localhost:3001
      vert = {
        image = "ghcr.io/vert-sh/vert:latest";
        autoStart = true;
        dependsOn = [ "vertd" ];
        ports = [ "3001:80" ];
      };

      # vertd - VERT conversion daemon with Intel Arc GPU acceleration
      # API: http://localhost:24153
      vertd = {
        image = "ghcr.io/vert-sh/vertd:latest";
        autoStart = true;
        environment = {
          VERTD_FORCE_GPU = "intel";  # Force Intel Arc GPU
        };
        ports = [ "24153:24153" ];
        extraOptions = [
          "--device=/dev/dri:/dev/dri"
        ];
      };
    };
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
      8010           # Paperless-ngx web interface
      3001           # VERT web interface
      24153          # vertd API
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
      onCalendar = "hourly";
      settings = {
        timestamp_format = "long";
        snapshot_preserve_min = "6h";
        snapshot_preserve = "6h 2d 4w 3m";
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
        
        backend_remote = "btrfs-progs-sudo";
        ssh_identity = "/var/lib/btrbk/.ssh/btrbk_rsa";
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
    
    # Manual backup to external SafeDrive HDD
    "cloud-to-safedrive" = {
      onCalendar = null; # Manual execution only
      settings = {
        timestamp_format = "long";
        snapshot_preserve = "no";           # Don't preserve source snapshots
        target_preserve = "400d";           # Keep for 400 days (~13 months)
        incremental = "yes";                # Enable incremental transfers
        snapshot_create = "ondemand";       # Create fresh snapshot when running
        
        volume = {
          "/cloud" = {
            subvolume = ".";
            target = "/run/media/adam/SafeDrive/cloud";
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
    # Paperless directories
    "d /vol/paperless 0755 root root - -"
    "d /vol/paperless/data 0755 root root - -"
    "d /vol/paperless/database 0755 root root - -"
    "d /vol/paperless/media 0755 root root - -"
    "d /vol/paperless/export 0755 root root - -"
    "d /vol/paperless/consume 0777 root root - -"  # World-writable for easy document dropping
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

  # Docker image update service - dynamically discovers and updates all containers
  systemd.services.docker-image-update = {
    description = "Pull latest Docker images and restart containers";
    after = [ "docker.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    serviceConfig.Type = "oneshot";
    path = [ pkgs.docker pkgs.coreutils pkgs.gnugrep ];
    script = ''
      set -euo pipefail
      
      echo "=== Docker Image Update ==="
      echo ""
      
      # Get all images currently in use by running containers
      echo "Discovering images from running containers..."
      IMAGES=$(docker ps --format '{{.Image}}' | sort -u)
      
      if [ -z "$IMAGES" ]; then
        echo "No running containers found."
        exit 0
      fi
      
      echo "Found images:"
      echo "$IMAGES" | while read img; do echo "  - $img"; done
      echo ""
      
      # Pull each image
      echo "Pulling latest versions..."
      UPDATED=""
      for IMAGE in $IMAGES; do
        echo "Pulling: $IMAGE"
        # Capture the pull output to detect if image was updated
        if docker pull "$IMAGE" 2>&1 | grep -q "Downloaded newer image\|Pull complete"; then
          UPDATED="$UPDATED $IMAGE"
        fi
      done
      echo ""
      
      # Find and restart systemd services for docker-* containers
      echo "Restarting container services..."
      SERVICES=$(systemctl list-units --type=service --state=running --no-legend | grep '^docker-' | awk '{print $1}')
      
      for SERVICE in $SERVICES; do
        echo "Restarting: $SERVICE"
        systemctl restart "$SERVICE" || echo "  Warning: Failed to restart $SERVICE"
      done
      
      echo ""
      echo "=== Docker image update complete! ==="
    '';
  };
  systemd.timers.docker-image-update = {
    description = "Pull latest Docker images weekly";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h";  # Spread load, don't run exactly with auto-upgrade
    };
  };
}

