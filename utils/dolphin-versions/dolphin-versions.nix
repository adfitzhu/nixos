{ pkgs, ... }:

let
  pythonWithTk = pkgs.python3.withPackages (ps: [ ps.tkinter ]);
in

pkgs.stdenv.mkDerivation {
  pname = "dolphin-versions";
  version = "1.0";

  src = ./.;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/kio/servicemenus

    makeWrapper ${pythonWithTk}/bin/python3 $out/bin/dolphin-versions \
      --add-flags $out/share/dolphin-versions/dolphin-versions.py

    mkdir -p $out/share/dolphin-versions
    cp dolphin-versions.py $out/share/dolphin-versions/dolphin-versions.py

    substituteAll ${./Versions.desktop} $out/share/kio/servicemenus/Versions.desktop
  '';

  meta = {
    description = "Dolphin Versions integration";
    platforms = pkgs.lib.platforms.linux;
  };
}
