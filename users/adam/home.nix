{ config, pkgs, lib, unstable, ... }:

let
  secretsPath = "/vol/secrets/secrets.nix";
  secrets = if builtins.pathExists secretsPath then import secretsPath else {};
  syncthingId = secrets.syncthingServerId or "N/A";
in
{
  home.stateVersion = "25.05";

 # services.nextcloud-client.enable = true;

  services.syncthing = {
    enable = true;
    tray.enable = false;
    overrideFolders = false;
    overrideDevices = false;
    settings = {
      options = {
        extraFlags = [ "--no-default-folder" ];
        urAccepted = -1;
        urSeen = 9999;
        crashReportingEnabled = false;
      };
      devices = {
        server = {
          id = syncthingId;
          introducer = true; # Allow this device to introduce new devices
        };
      };
      folders = {
        "adam_documents" = {
          path = "/home/adam/Documents";
          devices = [ "server" ];
          label = "Adam's Documents"; # This is the friendly name shown in the UI

        };
        "adam_music" = {
          path = "/home/adam/Music";
          devices = [ "server" ];
          label = "Adam's Music"; # This is the friendly name shown in the UI

        };
        "pictures" = {
          path = "/home/adam/Pictures";
          devices = [ "server" ];
          label = "Pictures"; # This is the friendly name shown in the UI

        };
      };
    };
  };
}
