{ config, pkgs, lib, ... }:

{
  # Host-specific settings for alphanix
  imports = [
    ../../bundles/desktop.nix
  ];

  networking.hostName = "alphanix";

  users.users.adam = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "vboxsf" "dialout" "audio" "video" "input" "docker" ];
  };

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
# Thin wrapper so the flake can import the host directory
import ./config.nix
