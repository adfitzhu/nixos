{ config, pkgs, lib, ... }:

{
  # Basic gaming packages
  environment.systemPackages = with pkgs; [
    steam-run            # FHS wrapper for running external binaries
    heroic               # Epic Games launcher
    bottles              # Wine bottles manager
    protonup             # Manage Proton-GE versions
    gamemode             # Feral GameMode
    gpu-viewer           # GPU monitoring
    lutris               # Gaming platform with installers
  ];

  # Steam configuration
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  # Enable 32-bit graphics support for Steam
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Sunshine game streaming service
  services.sunshine = {
    enable = true;
    openFirewall = true;
  };

  # Waydroid for Android gaming
  virtualisation.waydroid.enable = true;

  # Gaming firewall ports
  networking.firewall = {
    allowedTCPPorts = [ 29900 ];  # BF2 GameSpy services
    allowedUDPPorts = [ 16567 ];  # BF2 gameplay
  };
}
