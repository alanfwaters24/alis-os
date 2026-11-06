# The ALIS Glass fonts (alis-core/alis_glass_theme.css): Exo 2 (headings),
# Rajdhani (body text), Share Tech Mono (numbers/code). Open Font Licence,
# fetched from Google's font repository at a pinned version.
{ lib, stdenvNoCC, fetchurl }:
let
  rev = "24ddc1f324cac5d9f5aedca126d298f56e3f1640";
  font = path: name: hash: fetchurl { url = "https://raw.githubusercontent.com/google/fonts/${rev}/ofl/${path}"; inherit name hash; };
  files = [
    (font "exo2/Exo2%5Bwght%5D.ttf" "Exo2-Variable.ttf" "sha256-IFpEhnaiWG+cV8JfPVxYyo235s9e33UGeDoBDG/iv7U=")
    (font "exo2/Exo2-Italic%5Bwght%5D.ttf" "Exo2-Italic-Variable.ttf" "sha256-utVozqntI9auSupBrT93R3UpUqq92F1/AUdK85KiGzI=")
    (font "rajdhani/Rajdhani-Light.ttf" "Rajdhani-Light.ttf" "sha256-FA6fE69pU4FhxXgPz3+BWUwGmuqIfnv/1BeuHGQSE8M=")
    (font "rajdhani/Rajdhani-Regular.ttf" "Rajdhani-Regular.ttf" "sha256-bh/CKKgxglGm5WlQLsV7rB5GVsWC+S9ZzOzEaI4Dm5g=")
    (font "rajdhani/Rajdhani-Medium.ttf" "Rajdhani-Medium.ttf" "sha256-Ev99z+TCBuOHWsU7F2LqtX3movp/WobCa5e4jWWR6sI=")
    (font "rajdhani/Rajdhani-SemiBold.ttf" "Rajdhani-SemiBold.ttf" "sha256-lLvSWhjKZlmZ/rBaU33p/SuGDc+3i76coAJwglvyNdo=")
    (font "rajdhani/Rajdhani-Bold.ttf" "Rajdhani-Bold.ttf" "sha256-aRRw3TKGoU6Wd5QNC/dXlheYQbpSFcvaGiyJEKMiav0=")
    (font "sharetechmono/ShareTechMono-Regular.ttf" "ShareTechMono-Regular.ttf" "sha256-nOqx+HQUgpryWcD1N1c64D733TFHwLJ6NqGgvrZzJnc=")
  ];
in
stdenvNoCC.mkDerivation {
  pname = "alis-fonts";
  version = "2026.11";
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out/share/fonts/truetype/alis
    ${lib.concatMapStrings (f: "cp ${f} $out/share/fonts/truetype/alis/${f.name}\n") files}
  '';
  meta.license = lib.licenses.ofl;
}
