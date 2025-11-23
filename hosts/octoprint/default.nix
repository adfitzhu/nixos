{ config, pkgs, lib, unstable, ... }:

let
  # Desktop mode toggle - set to true to enable desktop for initial setup/troubleshooting
  desktopMode = true;  # Change to 'false' once configured, then rebuild
in
{
  imports = [
    ../../bundles/server.nix
    ../../users/adam/user.nix
  ];


  # Desktop services - only enabled when desktopMode = true
  services.desktopManager.plasma6.enable = desktopMode;
  services.displayManager = lib.mkIf desktopMode {
    sddm.enable = true;
    sddm.wayland.enable = true;
    autoLogin = { enable = true; user = "adam"; };
  };

  # Networking configuration
  networking = {
    hostName = "Octoprint";
    
    # Static IP configuration
    useDHCP = false;
    interfaces.enp2s0 = {
      ipv4.addresses = [{
        address = "192.168.1.50";
        prefixLength = 24;
      }];
    };
    defaultGateway = "192.168.1.1";
    nameservers = [ "192.168.1.10" "192.168.1.1" ];
  };

  # Filesystem mounts
  fileSystems."/vol" = {
    device = "/dev/disk/by-label/VOL";  # Adjust this label to match your disk
    fsType = "ext4";  # or "btrfs" if you prefer
    options = [ "defaults" ];
  };

  # Desktop environment (only when desktopMode = true)
  services.displayManager = lib.mkIf desktopMode {
    sddm.enable = true;
    sddm.wayland.enable = true;
    autoLogin = { enable = true; user = "adam"; };
  };

  services.desktopManager.plasma6.enable = desktopMode;

  # OctoPrint service configuration
  services.octoprint = {
    enable = true;
    port = 90;  # Match the docker compose port
    host = "0.0.0.0";  # Listen on all interfaces
    openFirewall = true;
    stateDir = "/vol/octoprint";  # Use /vol for persistent storage
    
    # Enable webcam streaming (matches ENABLE_MJPG_STREAMER from docker compose)
    extraConfig = {
      webcam = {
        enabled = true;
        stream = "http://localhost:8080/?action=stream";
        snapshot = "http://localhost:8080/?action=snapshot";
        ffmpeg = "${pkgs.ffmpeg}/bin/ffmpeg";
      };
      # Serial port configuration
      serial = {
        port = "/dev/ttyUSB0";
        baudrate = 115200;  # Adjust if your printer uses different baud rate
      };
    };
    
    # Add useful plugins
    plugins = plugins: with plugins; [
      # Webcam streaming plugin
      # Add more plugins as needed, e.g.:
      # bedlevelvisualizer
      # printtimegenius
      # themeify
    ];
  };

  # MJPG Streamer for webcam (matches docker compose ENABLE_MJPG_STREAMER)
  systemd.services.mjpg-streamer = {
    description = "MJPG Streamer for OctoPrint webcam";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      User = "octoprint";
      ExecStart = "${pkgs.mjpg-streamer}/bin/mjpg_streamer -i 'input_uvc.so -d /dev/video0 -r 640x480 -f 10' -o 'output_http.so -p 8080 -w ${pkgs.mjpg-streamer}/share/mjpg-streamer/www'";
      Restart = "always";
    };
  };

  # Additional packages
  environment.systemPackages = with pkgs; [
    # Serial port tools for troubleshooting printer connection
    python3Packages.pyserial
    minicom
    screen
    
    # Useful utilities
    htop
    vim
  ];

  # Add user to dialout and video groups for serial port and webcam access
  users.users.adam.extraGroups = [ "dialout" "video" ];
  
  # Also add octoprint user to video group for webcam
  users.users.octoprint.extraGroups = [ "dialout" "video" ];

  # Ensure directories exist
  systemd.tmpfiles.rules = [
    "d /vol 0755 root root - -"
    "d /vol/octoprint 0755 octoprint octoprint - -"
  ];

  # Optional: Systemd service to monitor printer connection
  systemd.services.printer-monitor = {
    description = "Monitor 3D printer USB connection";
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if [ -e /dev/ttyUSB0 ]; then
        echo "3D Printer detected at /dev/ttyUSB0"
      else
        echo "WARNING: No printer found at /dev/ttyUSB0"
        echo "Available serial devices:"
        ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || echo "  None found"
      fi
      
      if [ -e /dev/video0 ]; then
        echo "Webcam detected at /dev/video0"
      else
        echo "WARNING: No webcam found at /dev/video0"
      fi
    '';
    wantedBy = [ "multi-user.target" ];
  };

  # System configuration
  system.stateVersion = "25.05";
}
