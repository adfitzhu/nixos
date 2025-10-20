{ config, pkgs, lib, ... }:

# Comprehensive Linux gaming bundle.
# Includes:
#  - Steam (enabled via programs.steam, package not redundantly listed)
#  - Gamescope (enabled via programs.gamescope)
#  - Heroic Games Launcher
#  - Bottles (Flatpak assumed if you manage flatpaks elsewhere; here we add native if desired)
#  - (Optional monitoring overlays can be added separately)
#  - (vkBasalt support removable; currently disabled / not included)
#  - GameMode + Power Profiles Daemon integration
#  - PipeWire low-latency tweaks (optional)
#  - Udev rules for common controllers (DualShock, DualSense, Xbox, Switch Pro)
#  - Kernel sysctl and scheduler tweaks geared for desktop responsiveness
#  - Environment variables for Proton / games
#  - Optionally Lutris (disabled by default, toggle below)

# To use: add `../../bundles/gaming.nix` in a host imports list.

let
  cfg = config.gaming;

in {
  options.gaming = {
    enable = lib.mkEnableOption "Enable the comprehensive gaming environment";
    enableLutris = lib.mkOption { type = lib.types.bool; default = false; description = "Include Lutris"; };
    lowLatencyAudio = lib.mkOption { type = lib.types.bool; default = true; description = "Apply PipeWire low latency settings"; };
  };

  config = lib.mkIf cfg.enable {

    ###########################################################################
    # Core Packages
    ###########################################################################
    environment.systemPackages = with pkgs; (
      [
        steam-run            # FHS wrapper for running external binaries
        heroic
        bottles
        protonup             # Manage Proton-GE versions
        # Tools / diagnostics
        pciutils lshw vulkan-tools glxinfo mesa-demos
        # Performance observation
        gpu-viewer
        gamemode
      ]
      ++ lib.optional cfg.enableLutris lutris
  # vkBasalt intentionally omitted (can be re-added later)
    );

    ###########################################################################
    # Steam & Proton
    ###########################################################################
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true; # Allow streaming (TCP/UDP ports)
      dedicatedServer.openFirewall = false;
      localNetworkGameTransfers.openFirewall = true;
    };

    # Provide common Proton / DXVK / vkd3d environment vars system-wide.
    environment.variables = {
      # Avoid Steam runtime locale surprises
      LC_ALL = lib.mkDefault "en_US.UTF-8";
      # Proton / DXVK tweaks
      PROTON_LOG = "1";                      # Create proton logs when debugging
      DXVK_STATE_CACHE_PATH = "$XDG_CACHE_HOME/dxvk";
      VKD3D_SHADER_CACHE_PATH = "$XDG_CACHE_HOME/vkd3d";
      # Gamescope FSR / scaling defaults (can be overridden per launch)
      GAMESCOPE_FRAME_PACING = "1";
    };

    ###########################################################################
    # Gamescope (compositor for Steam / fullscreen sessions)
    ###########################################################################
    programs.gamescope = {
      enable = true;
      # Could add a custom wrapper script if desired.
    };


    ###########################################################################
    # GameMode (Feral Interactive) integration
    ###########################################################################
    services.gamemode.enable = true;

    # Power profiles (on modern systems) - ensures power-profiles-daemon available
    services.power-profiles-daemon.enable = true;

    ###########################################################################
    # PipeWire low-latency audio (optional)
    ###########################################################################
    services.pipewire = lib.mkIf cfg.lowLatencyAudio {
      extraConfig.pipewire."context.properties" = {
        default.clock.rate = 48000;
        default.clock.quantum = 128;   # Lower = lower latency (64 or 128 typical)
        default.clock.min-quantum = 32;
        default.clock.max-quantum = 2048;
      };
      extraConfig.pipewire-pulse."context.properties" = {
        pulse.min.quantum = "32/48000";
        pulse.default.req = "128/48000";
        pulse.default.min.req = "32/48000";
        pulse.default.max.req = "256/48000";
      };
    };

    ###########################################################################
    # Udev rules for common controllers (some are already handled by upstream kernel)
    ###########################################################################
    services.udev.extraRules = ''
      # Improve DualShock 4 (maps it as a gamepad if not already)
      SUBSYSTEM=="input", ATTRS{name}=="*Wireless Controller", MODE="0660", GROUP="input"
      # Nintendo Switch Pro Controller permissions (if needed)
      SUBSYSTEM=="input", ATTRS{name}=="*Pro Controller*", MODE="0660", GROUP="input"
      # DualSense grant vibration / LEDs (already mostly handled, keep permissive)
      SUBSYSTEM=="hid", ATTRS{product}=="DualSense Wireless Controller", MODE="0660", GROUP="input"
    '';

    ###########################################################################
    # Kernel / sysctl tweaks (light-touch)
    ###########################################################################
    boot.kernel.sysctl = {
      # Allow slightly more inotify watchers (mod managers, Proton games scanning many dirs)
      "fs.inotify.max_user_watches" = 1048576;
      "fs.inotify.max_user_instances" = 1024;
      # Slightly increase file descriptors (some launchers open many files)
      "fs.file-max" = 2097152;
      # Swappiness lower for SSD setups to reduce paging during gameplay
      "vm.swappiness" = 10;
    };

    ###########################################################################
    # OpenGL / Vulkan / 32-bit support (Steam requires multilib)
    ###########################################################################
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [ mesa_drivers ];
    };

    ###########################################################################
    # Enable 32-bit libraries system-wide for proprietary stuff
    ###########################################################################
    environment.enableDebugInfo = lib.mkDefault false; # can be turned on if debugging drivers

    # vkBasalt layer not enabled (ENABLE_VKBASALT can be added later if desired)

    ###########################################################################
    # Polkit rule to allow GameMode adjusting nice/IO priorities without password
    ###########################################################################
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.policykit.exec" && subject.isInGroup("users")) {
          return polkit.Result.YES;
        }
      });
    '';

    ###########################################################################
    # Helpful systemd user service template for gamescope session (opt-in)
    ###########################################################################
    systemd.user.services.gamescope-session = {
      Unit = { Description = "Gamescope Session Wrapper"; }; 
      Service = {
        ExecStart = "${pkgs.gamescope}/bin/gamescope -f -- steam -bigpicture";
        Restart = "on-failure";
      };
      Install = { WantedBy = [ "default.target" ]; };
    };

    ###########################################################################
    # Ensure Gamemode D-Bus policies (provided by package) are usable
    ###########################################################################
    users.groups.input = { }; # ensure input group exists
  };
}
