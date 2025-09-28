{ config, pkgs, lib, unstable, ... }:

{
  users.users.beth = {
    isNormalUser = true;
    group = "beth";
    extraGroups = [ "networkmanager" "wheel" "vboxsf" "dialout" "audio" "video" "input" "docker" ];
  };
  users.groups.beth = {};
}

