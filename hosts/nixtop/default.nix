{ config, pkgs, lib, unstable, ... }:

{
  imports = [
    ../../bundles/desktop.nix
   # ../../bundles/plasma.nix
    ../../users/adam/user.nix
  #  ../../users/guest/user.nix
  ];


  networking.hostName = "nixtop";

  home-manager.users = {
    adam = import ../../users/adam/home.nix;
  };
  
  services.displayManager.autoLogin = { 
    enable = true; 
    user = "adam"; 
  };

  # KDE Plasma 6 with display stability fixes
  services.desktopManager.plasma6.enable = true;
  
  # Display manager configuration
  services.displayManager = {
    sddm.enable = true;
    sddm.wayland.enable = true;
  };

  # Kernel choice:
  # boot.kernelPackages = unstable.linuxPackages_zen;       # Newest zen
  # boot.kernelPackages = unstable.linuxPackages_lqx;     # Gaming optimized
  boot.kernelPackages = pkgs.linuxPackages_zen;         # Stable zen
  # boot.kernelPackages = unstable.linuxPackages_latest;  # Bleeding edge (may have issues) 


  # Mount NFS share from alphanix
  fileSystems."/cloud" = {
    device = "192.168.1.20:/";
    fsType = "nfs4";
    options = [ "defaults" "_netdev" "nofail" "actimeo=1" ];
  };


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
    "org.mozilla.Thunderbird"
    "org.freecadweb.FreeCAD"
  ];

  # Steam configuration
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  # VirtualBox configuration
  virtualisation.virtualbox.host = {
    enable = true;
    enableExtensionPack = true;
  };
    # Prevent KVM from loading so VirtualBox can use VT-x/AMD-V.
  boot.blacklistedKernelModules = [ "kvm" "kvm-intel" ];


  # Fingerprint reader configuration
  services.fprintd.enable = true;
  security.pam.services = {
    sudo.fprintAuth = false;
    sddm.fprintAuth = true;
  };

  systemd.services.my-auto-upgrade = {
    description = "Custom NixOS auto-upgrade (host-specific)";
    serviceConfig.Type = "oneshot";
    script = ''
      set -euxo pipefail
  ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --upgrade --refresh --flake github:adfitzhu/nixos/testing#nixtop --no-write-lock-file --impure
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
