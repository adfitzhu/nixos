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
      libx11
      libxext
      libxrender
      libxtst
      libxi
      libxrandr
      libxcursor
      libxfixes
      libxinerama
      libxcb
    ];
  };
}