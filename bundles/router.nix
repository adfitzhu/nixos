{ config, pkgs, lib, ... }:

{
  # NixOS Router Configuration Bundle
  # This module configures a dual-NIC system as a home router with NAT, 
  # firewall, and port forwarding capabilities.
  # 
  # Assumes:
  # - WAN interface: enp2s0 (connects to ISP/modem)
  # - LAN interface: enp4s0 (connects to local switch/network)
  # - Router IP on LAN: 192.168.1.1
  # - DHCP provided by AdGuard Home (configured via web UI)

  # Enable IP forwarding for routing between interfaces
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  networking = {
    # Disable global DHCP since we're configuring interfaces individually
    useDHCP = false;
    
    # WAN interface - gets IP from ISP
    interfaces.enp2s0 = {
      useDHCP = true;  # Most ISPs use DHCP; change to static if needed
    };
    
    # LAN interface - router's internal IP
    interfaces.enp4s0 = {
      ipv4.addresses = [{
        address = "192.168.1.1";
        prefixLength = 24;
      }];
    };
    
    # NAT configuration
    nat = {
      enable = true;
      externalInterface = "enp2s0";  # WAN
      internalInterfaces = [ "enp4s0" ];  # LAN
      
      # Port forwarding rules to alphanix (192.168.1.20)
      forwardPorts = [
        # Immich photo management
        {
          destination = "192.168.1.20:2283";
          sourcePort = 2283;
          proto = "tcp";
        }
        
        # Minecraft servers
        {
          destination = "192.168.1.20:25565";
          sourcePort = 25565;
          proto = "tcp";
        }
        {
          destination = "192.168.1.20:25566";
          sourcePort = 25566;
          proto = "tcp";
        }
        {
          destination = "192.168.1.20:25567";
          sourcePort = 25567;
          proto = "tcp";
        }
        {
          destination = "192.168.1.20:25568";
          sourcePort = 25568;
          proto = "tcp";
        }
      ];
    };
    
    # Firewall configuration
    firewall = {
      enable = true;
      
      # Allow ping from anywhere for diagnostics
      allowPing = true;
      
      # LAN interface - allow local services
      interfaces.enp4s0 = {
        allowedTCPPorts = [
          53    # DNS (AdGuard Home)
          80    # HTTP (Caddy)
          443   # HTTPS (Caddy)
          3000  # AdGuard Home web UI
          3001  # Additional web service
          8080  # Additional web service
          9090  # Cockpit management UI
        ];
        allowedUDPPorts = [
          53    # DNS (AdGuard Home)
          67    # DHCP server (AdGuard Home)
        ];
      };
      
      # WAN interface - minimal exposure, only forwarded services
      interfaces.enp2s0 = {
        allowedTCPPorts = [
          80    # HTTP (for Let's Encrypt, web services)
          443   # HTTPS (for web services)
          2283  # Immich (forwarded to alphanix)
          25565 25566 25567 25568  # Minecraft (forwarded to alphanix)
        ];
        allowedUDPPorts = [
        ];
      };
      
      # Allow established and related connections
      extraCommands = ''
        # Allow established connections from any interface
        iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        
        # Allow all traffic on loopback
        iptables -A INPUT -i lo -j ACCEPT
        
        # Allow all from LAN to router
        iptables -A INPUT -i enp4s0 -j ACCEPT
        
        # Allow all from Tailscale to router
        iptables -A INPUT -i tailscale0 -j ACCEPT
      '';
      
      extraStopCommands = ''
        iptables -D INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
        iptables -D INPUT -i lo -j ACCEPT 2>/dev/null || true
        iptables -D INPUT -i enp4s0 -j ACCEPT 2>/dev/null || true
        iptables -D INPUT -i tailscale0 -j ACCEPT 2>/dev/null || true
      '';
    };
  };
  
  # DNS configuration - use localhost (AdGuard Home) and fallback to Cloudflare
  networking.nameservers = [ "127.0.0.1" "1.1.1.1" ];
  
  # Cockpit web-based management interface
  services.cockpit = {
    enable = true;
    port = 9090;
    settings = {
      WebService = {
        AllowUnencrypted = true;
      };
    };
  };
  
}
