{ config, pkgs, lib, unstable, ... }:

{
  imports = [
    ../../bundles/desktop.nix
    ../../bundles/gaming.nix
    ../../users/adam/user.nix
    ../../users/eli/user.nix
  ];

  networking.hostName = "crushix";
  networking.networkmanager.connectionConfig."connection.mdns" = 2;

  home-manager.users = {
    adam = import ../../users/adam/home.nix;
    eli = import ../../users/eli/home.nix;
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
    pkgs.high-tide
    pkgs.clonehero
    pkgs.discord
    pkgs.obs-studio
    pkgs.intel-gpu-tools
  ];

  services.flatpak.packages = [
    "com.usebottles.bottles"
    "com.heroicgameslauncher.hgl"
    "com.github.tchx84.Flatseal"
    "org.mozilla.Thunderbird"
    "com.lunarclient.LunarClient"
    "com.mojang.Minecraft"
    "app.zen_browser.zen"
  ];

  hardware.graphics.extraPackages = with pkgs; [
    vpl-gpu-rt
  ];

  boot.loader.systemd-boot.extraEntries = {
    "windows.conf" = ''
      title Windows
      efi /EFI/Microsoft/Boot/bootmgfw.efi
    '';
  };

  virtualisation.virtualbox.host = {
    enable = false;
    enableExtensionPack = true;
  };
  boot.blacklistedKernelModules = [ "kvm" "kvm-intel" ];

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
            target = "ssh://192.168.1.10/mnt/backup-hdd/crushix/snapshots/home";
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
  ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --upgrade --refresh --flake github:adfitzhu/nixos#crushix --no-write-lock-file --impure
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
