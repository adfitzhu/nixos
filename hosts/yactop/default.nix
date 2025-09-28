{ config, pkgs, lib, ... }:

{
  imports = [ ../../bundles/desktop.nix ../../users/beth/user.nix.nixos ];

  networking.hostName = "yactop";

  # system user imported from users/beth/user.nix

  environment.systemPackages = with pkgs; [ pkgs.obs-studio pkgs.droidcam pkgs.kdePackages.skanpage pkgs.audacity pkgs.clementine pkgs.superTuxKart ];

  services.flatpak.packages = [ "com.microsoft.Edge" ];

  services.displayManager = {
    sddm.enable = true;
    sddm.wayland.enable = true;
    autoLogin = { enable = true; user = "beth"; };
  };

  # Enable Home Manager on this host and wire Beth's Home Manager config
  programs.home-manager.enable = true;

  home-manager.users = {
    beth = import ../../users/beth/home.nix;
  };


