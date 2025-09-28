{
  description = "Minimal flake: exports only hosts found in ./hosts and user home configs in ./users";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, home-manager, nix-flatpak, unstable, ... }:
    let
  # Discover hosts by listing the `hosts/` directory. Each directory
  # under `hosts/` is treated as a host name with a `default.nix` file.
  lib = nixpkgs.lib;
  hosts = builtins.attrNames (builtins.readDir ./hosts);

      mkHost = system: hostName: let
  pkgsBase = import nixpkgs { inherit system; };
  unstablePkgs = import unstable { inherit system; config = pkgsBase.config or {}; };
  # Expose unstable as an attribute on pkgs so modules can refer to
  # `pkgs.unstable.<pkg>` without needing an extra injected variable.
  pkgs = pkgsBase // { unstable = unstablePkgs; };
        hostFilePath = builtins.toString ./hosts + "/" + hostName + "/default.nix";
      in nixpkgs.lib.nixosSystem {
        inherit system;
        # Make `unstablePkgs` available to imported modules as the
        # `unstable` argument via `specialArgs`. Module functions can
        # accept `unstable` in their argument set and use it directly.
        specialArgs = { unstable = unstablePkgs; };
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
          (import hostFilePath)
        ];
      };

  hostAttrs = lib.listToAttrs (map (h: { name = h; value = mkHost "x86_64-linux" h; }) hosts);
    in
    {
      nixosConfigurations = hostAttrs;
      hosts = hostAttrs;

  # Default host: prefer 'generic' if present, otherwise fall back to
  # the first host in `hostAttrs` to avoid errors when a host folder
  # hasn't been discovered yet.
  default = if hostAttrs ? generic then hostAttrs.generic
        else builtins.elemAt (lib.attrValues hostAttrs) 0;
    };
}

