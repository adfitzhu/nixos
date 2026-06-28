{ config, pkgs, lib, unstable, ... }:

{
  imports = [
    ../../bundles/desktop.nix
    ../../users/adam/user.nix
    ../../users/eli/user.nix
    ../../users/steven/user.nix
  ];

  networking.hostName = "Josh";

  home-manager.users = {
    adam = import ../../users/adam/home.nix;
    eli = import ../../users/eli/home.nix;
    steven = import ../../users/steven/home.nix;
  };

  services.desktopManager.plasma6.enable = true;
  services.displayManager = {
    sddm.enable = true;
    sddm.wayland.enable = true;
  };

  boot.kernelPackages = pkgs.linuxPackages_zen;

  fileSystems."/cloud" = {
    device = "192.168.1.20:/";
    fsType = "nfs4";
    options = [ "_netdev" "nofail" "soft" "timeo=5" "retrans=2" "actimeo=1" "x-systemd.automount" "x-systemd.idle-timeout=600" ];
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
    "com.lunarclient.LunarClient"
    "com.mojang.Minecraft"
    "app.zen_browser.zen"
  ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };
  hardware.steam-hardware.enable = true;

  virtualisation.virtualbox.host = {
    enable = false;
    enableExtensionPack = true;
  };
  boot.blacklistedKernelModules = [ "kvm" "kvm-intel" ];

  boot.resumeDevice = "/dev/disk/by-uuid/cc0e76e7-cbc6-4b63-888b-07e0b3914c04";

  services.fprintd.enable = true;
  security.pam.services = {
    sudo.fprintAuth = false;
    sddm.fprintAuth = true;
  };

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
            target = "ssh://192.168.1.10/mnt/backup-hdd/Josh/snapshots/home";
          };
        };
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/btrbk/.ssh 0700 btrbk btrbk -"
  ];

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
  ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --upgrade --refresh --flake github:adfitzhu/nixos#Josh --no-write-lock-file --impure
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
