{ pkgs, ... }: 
  
{
  home.stateVersion = "25.05";

 # services.nextcloud-client.enable = true;

  services.syncthing = {
    enable = true;
    tray.enable = true;
    overrideFolders = true;
    overrideDevices = false;
    settings = {
      options = {
        extraFlags = [ "--no-default-folder" ];
      };
      devices = {
        server = {
          id = "MRRPBZ3-VNO336P-4MBXUJC-265FSLR-UTRAQHR-QWVKXAK-4AQGXHE-5XWTDAH";
          introducer = true; # Allow this device to introduce new devices
        };
      };
      folders = {
        "beth_documents" = {
          path = "/home/beth/Documents";
          devices = [ "server" ];
          label = "Beth's Documents"; # This is the friendly name shown in the UI

        };
        "beth_music" = {
          path = "/home/beth/Music";
          devices = [ "server" ];
          label = "Beth's Music"; # This is the friendly name shown in the UI

        };
        #"pictures" = {
        #  path = "/home/beth/Pictures";
        #  devices = [ "server" ];
         # label = "Pictures"; # This is the friendly name shown in the UI

        #};
        "upload" = {
        path = "/home/beth/InstantUpload";
        devices = [ "server" ];
        label = "Instant Upload"; # This is the friendly name shown in the UI

        };
      };
    };
  };
}
