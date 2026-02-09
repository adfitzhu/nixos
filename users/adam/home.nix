{ config, pkgs, lib, unstable, ... }:

let
  secretsPath = "/vol/secrets/secrets.nix";
  secrets = if builtins.pathExists secretsPath then import secretsPath else {};
  syncthingId = secrets.syncthingServerId or "N/A";
in
{
  nixpkgs.config.allowUnfree = true;
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
      folders = {
        "adam_documents" = {
          path = "/home/adam/Documents";
          label = "Adam's Documents";
        };
        "adam_music" = {
          path = "/home/adam/Music";
          label = "Adam's Music";
        };
        "upload" = {
          path = "/home/adam/InstantUpload";
          label = "Instant Upload";
        };
        "localsync" = {
          path = "/home/adam/Sync";
          label = "Local Sync";
        };
      };
    };
  };
  programs.vscode = {
    enable = true;
    package = pkgs.vscode.fhs;
    profiles = {
      default = {
        extensions = [
          pkgs.vscode-extensions.continue.continue
        ];
      };
    };
  };
}

