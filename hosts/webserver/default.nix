{ config, pkgs, lib, ... }:

{
  imports = [ ../../bundles/server.nix ];

  networking.hostName = "webserver";

  # Example server-specific settings
  users.users.www = {
    isNormalUser = false;
    description = "Web service user";
  };

  services.nginx.enable = true;
