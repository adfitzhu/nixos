{ config, pkgs, lib, ... }:

{
  # Basic gaming packages
  environment.systemPackages = with pkgs; [
    steam-run            # FHS wrapper for running external binaries
    heroic               # Epic Games launcher
    bottles              # Wine bottles manager
    protonup-ng             # Manage Proton-GE versions
    gamemode             # Feral GameMode
    gpu-viewer           # GPU monitoring
    lutris               # Gaming platform with installers
    clonehero            # Clone Hero rhythm game
    superTuxKart         # TuxKart racing game
  ];

  # Steam configuration
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  # Enable 32-bit graphics support for Steam
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Gaming optimizations and ESYNC limits
  systemd.user.extraConfig = ''
    DefaultLimitNOFILE=1048576
  '';
  
  # Set user session limits for ESYNC compatibility
  security.pam.loginLimits = [
    {
      domain = "@users";
      type = "soft";
      item = "nofile";
      value = "1048576";
    }
    {
      domain = "@users";
      type = "hard";
      item = "nofile";
      value = "1048576";
    }
  ];
  
  # Additional gaming kernel parameters
  boot.kernel.sysctl = {
    "fs.file-max" = 2097152;
    "vm.max_map_count" = 2147483642;  # For games that need large memory mappings
  };

  # Waydroid for Android gaming
  virtualisation.waydroid.enable = true;

  # Gaming firewall ports
  networking.firewall = {
    allowedTCPPorts = [ 29900 ];  # BF2 GameSpy services
    allowedUDPPorts = [ 16567 ];  # BF2 gameplay
  };
}
