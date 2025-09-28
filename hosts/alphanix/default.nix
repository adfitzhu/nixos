{ config, pkgs, lib, unstable, ... }:

{
  # Host-specific settings for alphanix

  imports = [
    ../../bundles/desktop.nix
    ../../users/adam/user.nix
    ../../users/guest/user.nix
  ];

  networking.hostName = "alphanix";

  # system user is imported from users/adam/user.nix (nixos fragment)

  environment.systemPackages = with pkgs; [ pkgs.orca-slicer pkgs.clonehero ];

  services.flatpak.packages = [
    "com.usebottles.bottles"
    "com.heroicgameslauncher.hgl"
    "com.discordapp.Discord"
    "com.obsproject.Studio"
    "com.github.tchx84.Flatseal"
  ];

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
  ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --upgrade --flake github:adfitzhu/nixos#hosts.alphanix --no-write-lock-file --impure
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

