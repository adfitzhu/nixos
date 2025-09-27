{
  description = "Minimal flake: exports only hosts found in ./hosts and user home configs in ./users";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, home-manager, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
        hosts = builtins.attrNames (builtins.readDir ./hosts);
        users = builtins.attrNames (builtins.readDir ./users);
      in
      {
        nixosConfigurations = lib.listToAttrs (map (hostName: {
          name = hostName;
          value = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              ./hardware-configuration.nix
              # small baseline
              ({ config, pkgs, ... }: {
                nix.settings.experimental-features = [ "nix-command" "flakes" ];
                system.stateVersion = "25.05";
              })
              # host-specific module (import the host directory or file)
              (import (./hosts + "/" + hostName))
              # Home Manager integration and user imports
              home-manager.nixosModules.home-manager
              ({ config, pkgs, ... }: let
                  userAttrs = lib.listToAttrs (map (u: { name = u; value = import (./users + "/" + u + "/user.nix"); }) users);
                in {
                  home-manager.useGlobalPkgs = true;
                  home-manager.useUserPackages = true;
                  home-manager.users = userAttrs;
              })
            ];
          };
        }) hosts);
      }
  );
}

