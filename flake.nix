{
  description = "Minimal flake: exports only hosts found in ./hosts and user home configs in ./users";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, home-manager, nix-flatpak, ... }:
    let
  # Discover hosts by listing the `hosts/` directory. Each directory
  # under `hosts/` is treated as a host name with a `default.nix` file.
  lib = nixpkgs.lib;
  hosts = builtins.attrNames (builtins.readDir ./hosts);

      mkHost = system: hostName: let
        pkgs = import nixpkgs { inherit system; };
      in nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          # Ensure Home Manager's NixOS module is available first so its
          # option declarations are registered before host modules run.
          home-manager.nixosModules.home-manager
          ./hardware-configuration.nix
          ({ config, pkgs, ... }: {
            nix.settings.experimental-features = [ "nix-command" "flakes" ];
            system.stateVersion = "25.05";
          })
          # Provide nix-flatpak module so services.flatpak.* options exist
          nix-flatpak.nixosModules.nix-flatpak
          (import (builtins.toString ./hosts + "/" + hostName + "/default.nix"))
        ];
      };

  hostAttrs = lib.listToAttrs (map (h: { name = h; value = mkHost "x86_64-linux" h; }) hosts);
    in
    {
      nixosConfigurations = hostAttrs;
      hosts = hostAttrs;
    };
}

