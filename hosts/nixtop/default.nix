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
  boot.blacklistedKernelModules = [ "kvm" "kvm-intel" "vboxsf" ];



  services.desktopManager.plasma6.enable = true;
  services.displayManager = {
    sddm.enable = true;
    sddm.wayland.enable = true;
    autoLogin = { enable = true; user = "adam"; };
  };

  # Quiet boot and splash (Plymouth)
  boot = {
    plymouth = {
      enable = true;
      # BGRT shows the vendor logo with a spinner when firmware supports it
      theme = "bgrt";
    };
    # Reduce verbosity in initrd and kernel console
    initrd.verbose = false;
    consoleLogLevel = 3;
    kernelParams = [
      "quiet"
      # Lower udev/systemd chatter during boot
      "udev.log_priority=3"
      "systemd.show_status=false"
      # Hide blinking cursor on VT during splash
      "vt.global_cursor_default=0"
    ];
  };
  # Keep firmware (vendor) logo resolution so BGRT looks nice
  boot.loader.systemd-boot.consoleMode = "keep";

  # Trim long systemd waits during activation/restart
  systemd.extraConfig = ''
    DefaultTimeoutStartSec=15s
    DefaultTimeoutStopSec=15s
  '';
  systemd.user.extraConfig = ''
    DefaultTimeoutStartSec=15s
    DefaultTimeoutStopSec=15s
  '';

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
