{ config, pkgs, lib, unstable, ... }:

let
  secretsPath = "/etc/secrets/secrets.nix";
  secrets = if builtins.pathExists secretsPath then import secretsPath else {};
in
{
  imports = [
   #../../bundles/desktop.nix
   ../../bundles/server.nix
   ../../users/adam/user.nix
   #../../users/guest/user.nix
  ];

  networking.hostName = "webserver";

  # Docker is configured centrally in bundles/server.nix

  environment.systemPackages = with pkgs; [ ];

  services.flatpak.packages = [

  ];

  # Caddy reverse proxy (recommended to run as a NixOS service for ACME + systemd integration)
  services.caddy = {
    enable = true;
    # ACME/Let’s Encrypt email (read from /etc/secrets/secrets.nix)
    email = secrets.caddyEmail or null;
    virtualHosts = {
      "cloud.fitzworks.net".extraConfig = ''
        encode zstd gzip
        # Well-known redirects required by Nextcloud
        redir /.well-known/carddav /remote.php/dav 301
        redir /.well-known/caldav /remote.php/dav 301

        @websockets {
          header Connection *Upgrade*
          header Upgrade    websocket
        }

        reverse_proxy 127.0.0.1:11000 {
          header_up X-Forwarded-Host {host}
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-For {remote}
        }
      '';

      "theyoungartistsclub.com".extraConfig = ''
        encode zstd gzip
        reverse_proxy 127.0.0.1:8002 {
          header_up Host {host}
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-For {remote}
        }
      '';

      "eliandthefoodallergies.fitzworks.net".extraConfig = ''
        encode zstd gzip
        reverse_proxy 127.0.0.1:8003 {
          header_up Host {host}
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-For {remote}
        }
      '';

    };
  };

  # Open HTTP/HTTPS for Caddy
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # Ensure host secrets directory exists for docker-compose env files
  systemd.tmpfiles.rules = [
    "d /etc/secrets 0750 root root -"
  ];

  services.adguardhome = {
    enable = true;
    openFirewall = true; # opens 53/udp+tcp and the UI port
  };

  services.desktopManager.plasma6.enable = true;
  services.displayManager = {
    sddm.enable = true;
    sddm.wayland.enable = true;
    autoLogin = { enable = true; user = "adam"; };
  };

    systemd.services.my-auto-upgrade = {
      description = "Custom NixOS auto-upgrade (host-specific)";
      serviceConfig.Type = "oneshot";
      script = ''
        set -euxo pipefail
    ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --upgrade --refresh --flake github:adfitzhu/nixos#webserver --no-write-lock-file --impure
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
