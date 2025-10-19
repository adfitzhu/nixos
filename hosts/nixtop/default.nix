{ config, pkgs, lib, unstable, ... }:

{
  imports = [
    ../../bundles/desktop.nix
    ../../users/adam/user.nix
  #  ../../users/guest/user.nix
  ];


  #boot.blacklistedKernelModules = lib.mkForce [ "vboxsf" ];

  home-manager.users = {
    adam = import ../../users/adam/home.nix;
  };
  
  networking.hostName = "nixtop";

  environment.systemPackages = with pkgs; [ 
    pkgs.orca-slicer
    pkgs.clonehero
     ];

  services.flatpak.packages = [
    "com.usebottles.bottles"
    "com.heroicgameslauncher.hgl"
    "com.discordapp.Discord"
    "com.obsproject.Studio"
    "com.github.tchx84.Flatseal"
  ];



  # VirtualBox configuration
  virtualisation.virtualbox.host = {
    enable = true;
    enableExtensionPack = true;
  };
    # Prevent KVM from loading so VirtualBox can use VT-x/AMD-V.
  boot.blacklistedKernelModules = [ "kvm" "kvm-intel" ];



  services.desktopManager.plasma6.enable = true;
  services.displayManager = {
    sddm.enable = true;
    sddm.wayland.enable = true;
    autoLogin = { enable = true; user = "adam"; };
  };

  

  # Fingerprint reader configuration
  services.fprintd.enable = true;
  security.pam.services = {
    #sudo.fprintAuth = true;
    sddm.fprintAuth = true;
  };

  systemd.services.my-auto-upgrade = {
    description = "Custom NixOS auto-upgrade (host-specific)";
    serviceConfig.Type = "oneshot";
    script = ''
      set -euxo pipefail
  ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --upgrade --refresh --flake github:adfitzhu/nixos#nixtop --no-write-lock-file --impure
    '';
  };
  systemd.timers.my-auto-upgrade = {
    description = "Run custom NixOS auto-upgrade weekly (host-specific)";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };


}
