{ config, pkgs, lib, unstable, ... }:

let
  secretsPath = "/vol/secrets/secrets.nix";
  secrets = if builtins.pathExists secretsPath then import secretsPath else {};
  syncthingId = secrets.syncthingServerId or "N/A";
in
{
  nixpkgs.config.allowUnfree = true;
  home.stateVersion = "25.05";

  home.activation.flatpakRuntimeOverride = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    override_dir="$HOME/.local/share/flatpak/overrides"
    override_file="$override_dir/global"
    override_tmp="$override_dir/global.hm-tmp"

    run mkdir -p $VERBOSE_ARG "$override_dir"

    if [[ ! -v DRY_RUN ]]; then
      cat > "$override_tmp" <<EOF
[Context]
filesystems=home;/run/user/$UID:ro
EOF
      mv "$override_tmp" "$override_file"
    fi
  '';

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
  # programs.vscode = {
  #   enable = true;
  #   package = pkgs.vscode;
  #   profiles = {
  #     default = {
  #       extensions = [
  #         pkgs.vscode-extensions.continue.continue
  #       ];
  #       userSettings = {
  #         # Skip GPU blacklist check and use GPU compositing immediately
  #         "disable-hardware-acceleration" = false;
  #         "update.mode" = "none";
  #       };
  #     };
  #   };
  # };

}

