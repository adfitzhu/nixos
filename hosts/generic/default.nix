{ config, pkgs, lib, ... }:

{
  imports = [
   ../../bundles/desktop.nix
   ../../users/adam/user.nix 
   ../../users/guest/user.nix
  ];

  networking.hostName = "nixos";

  # system user imported from users/adam/user.nix

  environment.systemPackages = with pkgs; [  ];

  services.flatpak.packages = [

  ];

  services.displayManager = {
    sddm.enable = true;
    sddm.wayland.enable = true;
    autoLogin = { enable = true; user = "adam"; };
  };

}
