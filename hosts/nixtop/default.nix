{ config, pkgs, lib, ... }:

{
  imports = [ ../../bundles/desktop.nix ../../users/adam/user.nix.nixos ];

  networking.hostName = "nixtop";

  # system user imported from users/adam/user.nix

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

  # Enable Home Manager on this host and wire Adam's Home Manager config
  programs.home-manager.enable = true;

  home-manager.users = {
    adam = import ../../users/adam/home.nix;
  };
}
