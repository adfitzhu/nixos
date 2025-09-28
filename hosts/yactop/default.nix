{ config, pkgs, lib, unstable, ... }:

{
  imports = [ ../../bundles/desktop.nix ../../users/beth/user.nix ];

  networking.hostName = "yactop";

  # system user imported from users/beth/user.nix

  environment.systemPackages = with pkgs; [ pkgs.obs-studio pkgs.droidcam pkgs.kdePackages.skanpage pkgs.audacity pkgs.clementine pkgs.superTuxKart ];

  services.flatpak.packages = [ "com.microsoft.Edge" ];

  services.displayManager = {
    sddm.enable = true;
    sddm.wayland.enable = true;
    autoLogin = { enable = true; user = "beth"; };
  };

  systemd.services.my-auto-upgrade = {
    description = "Custom NixOS auto-upgrade (host-specific)";
    serviceConfig.Type = "oneshot";
    script = ''
      set -euxo pipefail
  ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --upgrade --flake github:adfitzhu/nixos#hosts.yactop --no-write-lock-file --impure
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

  # Wire Beth's Home Manager config via home-manager.users
  home-manager.users = {
    beth = import ../../users/beth/home.nix;
  };

}
