{ config, pkgs, lib, unstable, ... }:

{
  imports = [
    ../../bundles/desktop.nix
    ../../bundles/server.nix
    ../../bundles/gaming.nix
    ../../users/adam/user.nix
  ];

  networking.hostName = "ScrapServer";

  services.sunshine = {
    enable = true;
    capSysAdmin = true;
    openFirewall = true;
    settings = {
      channels = 2;
      # encoder = "quicksync";  # Intel QuickSync
      # encoder = "vaapi";      # AMD/Intel VA-API
      # encoder = "nvenc";      # NVIDIA
      bitrate = 30000;
      fps = 60;
      hevc_mode = 2;
      av1_mode = 0;
      min_log_level = 2;
      qp = 28;
      crf = 0;
      rc = "cbr";
      fec_percentage = 5;
      min_threads = 2;
    };
    applications = {
      env = {
        PATH = "$(PATH):$(HOME)/.local/bin:/run/current-system/sw/bin";
        DISPLAY = ":0";
        WAYLAND_DISPLAY = "wayland-0";
      };
      apps = [
        {
          name = "Desktop";
          exclude-global-prep-cmd = "false";
          auto-detach = "true";
        }
      ];
    };
  };

  services.desktopManager.plasma6.enable = true;
  services.displayManager = {
    sddm.enable = true;
    sddm.wayland.enable = true;
    autoLogin = { enable = true; user = "adam"; };
  };

  systemd.services.my-auto-upgrade = {
    description = "Custom NixOS auto-upgrade (host-specific)";
    serviceConfig.Type = "oneshot";
    script = ''
      set -euxo pipefail
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --upgrade --refresh --flake github:adfitzhu/nixos#ScrapServer --no-write-lock-file --impure
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
