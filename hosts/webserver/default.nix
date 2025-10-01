{ config, pkgs, lib, unstable, ... }:

{
  imports = [
   #../../bundles/desktop.nix
   ../../bundles/server.nix
   ../../users/adam/user.nix
   #../../users/guest/user.nix
  ];

  networking.hostName = "webserver";

  # Enable Docker runtime for app containers managed via docker-compose in this host folder
  virtualisation.docker.enable = true;

  environment.systemPackages = with pkgs; [ 
    docker-compose


   ];

  services.flatpak.packages = [

  ];

  # Caddy reverse proxy (recommended to run as a NixOS service for ACME + systemd integration)
  services.caddy = {
    enable = true;
    # Set your email for ACME/Let’s Encrypt notifications
    # email = "you@example.com";
    virtualHosts = {
      # Nextcloud (AIO behind Caddy). Replace with your real domain.
      "cloud.example.com".extraConfig = ''
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

      # WordPress example site
      "wp1.example.com".extraConfig = ''
        encode zstd gzip
        reverse_proxy 127.0.0.1:8001
      '';

      # Optional: expose the AIO admin UI behind auth; otherwise keep it on 127.0.0.1:8080 only.
      # "aio.example.com".extraConfig = ''
      #   encode zstd gzip
      #   basicauth {
      #     # user: bcrypt hash (generate with "caddy hash-password --plaintext <pwd>")
      #     admin $2a$14$exampleexampleexampleexampleexampleexampleexample
      #   }
      #   reverse_proxy 127.0.0.1:8080
      # '';

      # AdGuard Home admin UI (if enabled as a host service on port 3000)
      "adguard.example.com".extraConfig = ''
        reverse_proxy 127.0.0.1:3000
      '';
    };
  };

  # Open HTTP/HTTPS for Caddy
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # Ensure host secrets directory exists for docker-compose env files
  systemd.tmpfiles.rules = [
    "d /etc/secrets 0750 root root -"
  ];

  # If you want to run AdGuard Home on the host (recommended for DNS on port 53),
  # uncomment this and complete initial setup via the web UI at adguard.example.com.
  # services.adguardhome = {
  #   enable = true;
  #   openFirewall = true; # opens 53/udp+tcp and the UI port
  # };

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
