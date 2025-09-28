{ config, pkgs, lib, ... }:

{
  imports = [ ../../bundles/desktop.nix ../../users/adam/user.nix ];

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

  # Wire Adam's Home Manager config via home-manager.users
  home-manager.users = {
    adam = import ../../users/adam/home.nix;
  };
}
