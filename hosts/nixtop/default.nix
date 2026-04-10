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
    unstable.orca-slicer
    pkgs.clonehero
     ];

  services.flatpak.packages = [
    "com.usebottles.bottles"
    "com.heroicgameslauncher.hgl"
    "com.discordapp.Discord"
    "com.obsproject.Studio"
    "com.github.tchx84.Flatseal"
    "org.mozilla.Thunderbird"
    "org.freecad.FreeCAD"
  ];

  # Steam configuration
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  # VirtualBox configuration
  virtualisation.virtualbox.host = {
    enable = false;
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

  # Push /home snapshots to webserver weekly
  # Reuses snapshots already created by the 'home' instance in desktop.nix.
  # Requires: SSH key at /var/lib/btrbk/.ssh/btrbk_rsa (generate once, then add
  # the public key to webserver's users.users.btrbk.openssh.authorizedKeys.keys).
  services.btrbk.instances = {
    "home-to-webserver" = {
      onCalendar = "weekly";
      settings = {
        timestamp_format = "long";
        snapshot_create = "no";
        target_preserve_min = "1w";
        target_preserve = "4w 6m 2y";
        incremental = "yes";

        backend_remote = "btrfs-progs-sudo";
        ssh_identity = "/var/lib/btrbk/.ssh/btrbk_rsa";
        ssh_user = "btrbk";

        volume = {
          "/home" = {
            snapshot_dir = ".snapshots";
            subvolume = ".";
            target = "ssh://192.168.1.10/mnt/backup-hdd/nixtop/snapshots/home";
          };
        };
      };
    };
  };

  # SSH key directory for btrbk push (generate key once as root, then authorize on webserver)
  systemd.tmpfiles.rules = [
    "d /var/lib/btrbk/.ssh 0700 btrbk btrbk -"
  ];

  # Allow btrbk user to run btrfs commands via sudo
  security.sudo.extraRules = [
    {
      users = [ "btrbk" ];
      commands = [
        { command = "${pkgs.btrfs-progs}/bin/btrfs"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/btrfs";  options = [ "NOPASSWD" ]; }
      ];
    }
  ];

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
