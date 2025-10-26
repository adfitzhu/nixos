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

  environment.systemPackages = with pkgs; [ pkgs.orca-slicer pkgs.clonehero ];

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

  # Set up mount point permissions to be user-writable
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
  ];

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
    };
    script = ''
      set -euo pipefail
      echo "[compose-stack] Bringing application stack up" >&2
      docker compose -f ${composeFile} up -d --remove-orphans
    '';
    preStop = ''
      set -euo pipefail
      echo "[compose-stack] Stopping application stack" >&2
      docker compose -f ${composeFile} down
    '';
  };

  # NFS Server configuration
  services.nfs.server = {
    enable = true;
    exports = ''
      /cloud *(rw,sync,no_subtree_check,no_root_squash,fsid=0)
    '';
  };

  # Open NFS ports in firewall
  networking.firewall = {
    allowedTCPPorts = [ 2049 111 20048 ];
    allowedUDPPorts = [ 2049 111 20048 ];
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

