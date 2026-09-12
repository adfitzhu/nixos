{ config, pkgs, lib, unstable, ... }:

let
  secretsPath = "/vol/secrets/secrets.nix";
  secrets = if builtins.pathExists secretsPath then import secretsPath else {};
  syncthingId = secrets.syncthingServerId or "N/A";
in
{
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
        "beth_documents" = {
          path = "/home/beth/Documents";
          label = "Beth's Documents";
        };
        "beth_music" = {
          path = "/home/beth/Music";
          label = "Beth's Music";
        };
        "upload" = {
          path = "/home/beth/InstantUpload";
          label = "Instant Upload";
        };
      };
    };
  };
}
