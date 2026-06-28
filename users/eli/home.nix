{ config, pkgs, lib, unstable, ... }:

let
  secretsPath = "/vol/secrets/secrets.nix";
  secrets = if builtins.pathExists secretsPath then import secretsPath else {};
  syncthingId = secrets.syncthingServerId or "N/A";
in
{
  home.stateVersion = "25.05";

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
      folders = {
        "eli_documents" = {
          path = "/home/eli/Documents";
          label = "Eli's Documents";
        };
        "eli_music" = {
          path = "/home/eli/Music";
          label = "Eli's Music";
        };
        "upload" = {
          path = "/home/eli/InstantUpload";
          label = "Instant Upload";
        };
      };
    };
  };
}
