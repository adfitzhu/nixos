{ pkgs, ... }:
{
  # Shared runtime libraries for bundled binaries (AppImages, vendor JDKs, etc.)
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      fontconfig
      freetype
      alsa-lib
      libGL
      xorg.libX11
      xorg.libXext
      xorg.libXrender
      xorg.libXtst
      xorg.libXi
      xorg.libXrandr
      xorg.libXcursor
      xorg.libXfixes
      xorg.libXinerama
      xorg.libxcb
    ];
  };
}