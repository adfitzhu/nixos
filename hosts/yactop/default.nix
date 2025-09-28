{ config, pkgs, lib, ... }:

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

  # Wire Beth's Home Manager config via home-manager.users
  home-manager.users = {
    beth = import ../../users/beth/home.nix;
  };

}
