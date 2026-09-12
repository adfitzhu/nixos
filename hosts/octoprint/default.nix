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
  networking.hostName = "Octoprint";

  # Persistent storage for OctoPrint lives on the host at /vol/octoprint and is
  # mounted into the container at /octoprint.

  # OctoPrint is now managed via OCI container instead of the Nix package.
  services.octoprint.enable = false;

  # Docker backend for the OctoPrint OCI container
  virtualisation.docker.enable = true;
  virtualisation.oci-containers = {
    backend = "docker";
    containers.octoprint = {
      image = "octoprint/octoprint:latest";
      autoStart = true;
      environment = {
        TZ = "America/Los_Angeles";
      };
      volumes = [
        "/vol/octoprint:/octoprint"  # host /vol/octoprint -> container /octoprint
      ];
      extraOptions = [
        "--network=host"
        "--device=/dev/ttyUSB0:/dev/ttyUSB0"
        "--device=/dev/video0:/dev/video0"
        "--device=/dev/bus/usb:/dev/bus/usb"
      ];
    };
  };

  # MJPG Streamer for webcam (matches docker compose ENABLE_MJPG_STREAMER)
  systemd.services.mjpg-streamer = {
    description = "MJPG Streamer for OctoPrint webcam";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      User = "octoprint";
      ExecStart = "${pkgs.mjpg-streamer}/bin/mjpg_streamer -i 'input_uvc.so -d /dev/video0 -r 1920x1080 -f 10' -o 'output_http.so -p 8080 -w ${pkgs.mjpg-streamer}/share/mjpg-streamer/www'";
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

  # Explicitly define the octoprint system user/group used by the host webcam
  # helper service. This is needed because we are no longer using the Nix
  # OctoPrint module directly.
  users.groups.octoprint = {};
  users.users.octoprint = {
    isSystemUser = true;
    group = "octoprint";
    extraGroups = [ "dialout" "video" ];
  };

  # Ensure directories exist and are writable for the container-mounted data dir.
  systemd.tmpfiles.rules = [
    "d /vol 0755 root root - -"
    "d /vol/octoprint 0777 root root - -"
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
