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
