{ config, pkgs, lib, unstable, ... }:

{
  # system-level user and group for adam
  users.users.adam = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "vboxsf" "vboxusers" "dialout" "audio" "video" "input" "docker" ];
  };
  users.groups.adam = {};


  environment.systemPackages = with pkgs; [
    vscode
    kdePackages.yakuake         
    firefox
  ];




}

