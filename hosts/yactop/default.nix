{ config, pkgs, lib, ... }:

{
  imports = [ ../../bundles/desktop.nix ];

  networking.hostName = "yactop";

  users.users.beth = {
    isNormalUser = true;
    group = "beth";
    extraGroups = [ "networkmanager" "wheel" "vboxsf" "dialout" "audio" "video" "input" "docker" ];
  };
  users.groups.beth = {};

  environment.systemPackages = with pkgs; [ pkgs.obs-studio pkgs.droidcam pkgs.kdePackages.skanpage pkgs.audacity pkgs.clementine pkgs.superTuxKart ];

  services.flatpak.packages = [ "com.microsoft.Edge" ];

  services.displayManager = {
    sddm.enable = true;
    sddm.wayland.enable = true;
    autoLogin = { enable = true; user = "beth"; };
  };
}
import ./config.nix
