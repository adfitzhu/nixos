{ config, pkgs, lib, unstable, ... }:

{
  imports = [
   #../../bundles/desktop.nix
   ../../bundles/server.nix
   ../../users/adam/user.nix
   #../../users/guest/user.nix
  ];

  networking.hostName = "webserver";

  environment.systemPackages = with pkgs; [ 


   ];

  services.flatpak.packages = [

  ];


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
    ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --upgrade --refresh --flake github:adfitzhu/nixos#webserver --no-write-lock-file --impure
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
