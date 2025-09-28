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
      let
        # Build a list of host-specific nixosSystem values once and reuse it.
        hostSystems = map (hostName: {
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
              # Home Manager integration is available; hosts should opt-in and
              # register specific users in their own modules.
              home-manager.nixosModules.home-manager
            ];
          };
        }) hosts;
      in
      {
        # Keep the canonical `nixosConfigurations` mapping (for compatibility)
        nixosConfigurations = lib.listToAttrs hostSystems;

        # Also expose a `hosts` mapping so you can reference a single host
        # directly: `nix build .#hosts.<hostname>` (system defaults will apply).
        hosts = lib.listToAttrs hostSystems;
      }
  );
}

