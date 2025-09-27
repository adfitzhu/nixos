{ pkgs, ... }:

pkgs.stdenv.mkDerivation {
  pname = "dolphin-versions";
  version = "1.0";

  src = ./.;

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/kio/servicemenus

    cp dolphin-versions.py $out/bin/dolphin-versions.py
    chmod +x $out/bin/dolphin-versions.py

    cp Versions.desktop $out/share/kio/servicemenus/Versions.desktop
  '';

  meta = {
    description = "Dolphin Versions integration";
    platforms = pkgs.lib.platforms.linux;
  };
}
