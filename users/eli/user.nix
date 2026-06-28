{ config, pkgs, lib, unstable, ... }:

{
  users.users.eli = {
    isNormalUser = true;
    group = "eli";
    extraGroups = [ "networkmanager" "wheel" "vboxsf" "dialout" "audio" "video" "input" "docker" ];
  };
  users.groups.eli = {};
}
