{ config, pkgs, ... }:

{
  # system-level user and group for adam
  users.users.adam = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "vboxsf" "dialout" "audio" "video" "input" "docker" ];
  };
  users.groups.adam = {};
}

