{ config, pkgs, lib, unstable, ... }:

{
  users.users.steven = {
    isNormalUser = true;
    group = "steven";
    extraGroups = [ "networkmanager" "wheel" "vboxsf" "dialout" "audio" "video" "input" "docker" ];
  };
  users.groups.steven = {};
}
