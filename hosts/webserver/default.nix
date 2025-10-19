{ config, pkgs, lib, unstable, ... }:

let
  secretsPath = "/vol/secrets/secrets.nix";
  secrets = if builtins.pathExists secretsPath then import secretsPath else {};

  dynDnsDomains = secrets.dyndnsDomains or "";
  dynDnsApiKey = secrets.dyndnsApiKey or "";
  domainNextcloud = secrets.nextcloud or "";
  domainTyac = secrets.theyoungartistsclub or "";
  domainAllergy = secrets.allergy or "";

  # Path to docker-compose file (used by the systemd service restartTriggers and scripts)
  composeFile = ./compose/docker-compose.yml;

  # Helper to build a virtualHost attr only if domain provided
  mkVHost = domain: cfg: lib.optionalAttrs (domain != "") { "${domain}" = { extraConfig = cfg; }; };
in
{
  imports = [
   #../../bundles/desktop.nix
   ../../bundles/server.nix
   ../../users/adam/user.nix
   #../../users/guest/user.nix
  ];

  # Enable VirtualBox guest additions when this system runs as a VirtualBox VM
  virtualisation.virtualbox.guest.enable = true;
  services.xserver.videoDrivers = [ "virtualbox" ];



  networking.hostName = "webserver";

  environment.systemPackages = with pkgs; [ ];

  services.flatpak.packages = [

  ];

  # Caddy reverse proxy (recommended to run as a NixOS service for ACME + systemd integration)
  services.caddy = {
    enable = true;
  # ACME/Let’s Encrypt email (read from /vol/secrets/secrets.nix)
    email = secrets.caddyEmail or null;
    # Build virtualHosts dynamically from secrets; hosts omitted if domain not set.
    virtualHosts =
      (mkVHost domainNextcloud ''
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
      '') //
      (mkVHost domainTyac ''
        encode zstd gzip
        reverse_proxy 127.0.0.1:8002 {
          header_up Host {host}
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-For {remote}
        }
      '') //
      (mkVHost domainAllergy ''
        encode zstd gzip
        reverse_proxy 127.0.0.1:8003 {
          header_up Host {host}
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-For {remote}
        }
      '');
  };

  # Open HTTP/HTTPS for Caddy
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # Ensure host secrets directory exists for docker-compose env files
  systemd.tmpfiles.rules = [
  "d /vol/secrets 0750 root root -"
    "d /var/lib/dyndns 0750 root root -"
    # Docker compose stack volume roots (ensure exist with sane perms)
    "d /vol 0755 root root -"
    "d /vol/nextcloud 0750 root root -"
    "d /vol/nextcloud/aio-config 0750 root root -"
    "d /vol/artists 0750 root root -"
    "d /vol/artists/theyoungartistsclub-db 0750 root root -"
    "d /vol/artists/theyoungartistsclub 0750 root root -"
    "d /vol/allergy 0750 root root -"
    "d /vol/allergy/allergy-db 0750 root root -"
    "d /vol/allergy/allergy 0750 root root -"
    # uploads.ini host file placeholder (Compose maps /vol/uploads.ini)
    "f /vol/uploads.ini 0644 root root -"
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

  # Watchtower container: auto-updates only labeled containers (skips Nextcloud AIO by omitting label)
  virtualisation.oci-containers.backend = "docker";
  virtualisation.oci-containers.containers.watchtower = {
    image = "containrrr/watchtower:latest";
    autoStart = true;
    volumes = [ "/var/run/docker.sock:/var/run/docker.sock" ];
    cmd = [
      "--interval" "3600"          # check hourly
      "--label-enable"              # only update containers with enable label
      "--cleanup"                   # remove old images after update
      "--rolling-restart"           # restart sequentially
    ];
    restartPolicy = "unless-stopped";
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

  # Dynamic DNS updater (checks external IP every 5m and updates when changed)
  systemd.services.dyndns-update = {
    description = "Dynamic DNS update";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''
        ${pkgs.curl}/bin/curl "https://api.dnsexit.com/dns/ud/?apikey=${dynDnsApiKey}" -d "host=${dynDnsDomains}"
      '';
    };
    path = [ pkgs.curl ];
  };

  systemd.timers.dyndns-update = {
    description = "Run Dynamic DNS update every 5 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "5m";
    };
  };

  # Systemd-managed docker compose stack (declarative start). This runs `docker compose up -d`
  # using the compose file embedded in the Nix store so changes trigger restarts.
  systemd.services.docker-compose-webstack = {
    description = "Docker Compose web stack (Nextcloud AIO + WordPress sites)";
    after = [ "docker.service" "network-online.target" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [ composeFile ];
    path = [ pkgs.docker pkgs.coreutils pkgs.bash ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true; # So systemd thinks it's active after the up -d completes
    };
    script = ''
      set -euo pipefail
      echo "[compose-webstack] Bringing stack up" >&2
      docker compose -f ${composeFile} up -d --remove-orphans
    '';
    preStop = ''
      set -euo pipefail
      echo "[compose-webstack] Stopping stack" >&2
      docker compose -f ${composeFile} down
    '';
  };

}
