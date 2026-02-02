{ config, pkgs, lib, unstable, ... }:

{
  # KDE Plasma 6 with display stability fixes
  services.desktopManager.plasma6.enable = true;
  
  # Display manager configuration
  services.displayManager = {
    sddm.enable = true;
    sddm.wayland.enable = true;
  };

  # Display management and crash prevention
  services.xserver = {
    enable = true;
    # Enable better multi-monitor support
    displayManager.setupCommands = ''
      # Reset display configuration on login to prevent crashes
      ${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor --reset
    '';
  };

  # KDE/Plasma crash prevention for dock disconnection
  environment.sessionVariables = {
    # Disable compositor crash recovery that can cause loops
    KWIN_DRM_NO_AMS = "1";
    # More stable Wayland backend
    QT_QPA_PLATFORM = "wayland;xcb";  # Fallback to X11 if Wayland fails
    # Prevent kwin crashes on display changes
    KWIN_COMPOSE = "O2";
    # Enable Intel GPU monitoring for Plasma System Monitor
    ZES_ENABLE_SYSMAN = "1";
  };

  # Hardware-specific fixes for display hotplug
  boot.kernelParams = [
    # Better USB-C/Thunderbolt display handling
    "drm.debug=0x0"
    # Prevent display driver crashes
    "i915.enable_psr=0"  # Disable panel self refresh if Intel graphics
    # More stable display mode changes
    "video=efifb:off"
  ];

  # System-level display management
  services.udev.extraRules = ''
    # Handle USB-C dock connect/disconnect more gracefully
    SUBSYSTEM=="drm", ACTION=="change", RUN+="${pkgs.systemd}/bin/systemctl --user restart plasma-kwin_wayland.service"
    
    # Reset KScreen configuration on dock changes
    SUBSYSTEM=="drm", ACTION=="change", RUN+="${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor --reset"
  '';

  # Display management tools
  environment.systemPackages = with pkgs; [
    kdePackages.libkscreen  # For kscreen-doctor
    autorandr               # Automatic display configuration
    xorg.xrandr            # Display configuration utility
  ];

  # KDE Plasma configuration for stability
  programs.dconf.profiles.user.databases = [{
    lockAll = false;
    settings = {
      "org/kde/kwin" = {
        # Prevent compositor crashes on display changes
        "backend" = "wayland";
        # More conservative display management
        "overview_mode" = false;
      };
    };
  }];

  # Systemd services to help with display stability
  systemd.user.services.kscreen-reset-on-change = {
    description = "Reset KScreen on display changes";
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
      ExecStart = "${pkgs.kdePackages.libkscreen}/bin/kscreen-doctor --reset";
    };
  };
}