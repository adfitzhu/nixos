{ config, pkgs, lib, unstable, ... }:

{
  users.users.guest = {
    isNormalUser = true;
    group = "guest";
    extraGroups = [ "networkmanager" "wheel" "vboxsf" "dialout" "audio" "video" "input" "docker" ];
  };
  users.groups.guest = {};
}
