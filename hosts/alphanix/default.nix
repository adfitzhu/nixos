{ config, pkgs, lib, ... }:

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
}

