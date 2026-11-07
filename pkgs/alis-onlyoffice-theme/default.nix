# OnlyOffice "ALIS" interface theme (Settings → Interface theme): its Dark
# theme in ALIS colours (make.py). Copied into each person's OnlyOffice
# theme folder at login (modules/theme.nix).
{ lib, pkgs, runCommand, python3, onlyoffice-desktopeditors }:
let
  # The app itself sits inside OnlyOffice's sandbox wrapper.
  app = lib.findFirst (p: lib.hasPrefix "onlyoffice-desktopeditors-" (p.name or ""))
    (throw "alis-onlyoffice-theme: OnlyOffice app not found in its wrapper")
    (onlyoffice-desktopeditors.args.targetPkgs pkgs);
in
runCommand "alis-onlyoffice-theme" { nativeBuildInputs = [ python3 ]; } ''
  mkdir -p $out/share/alis-onlyoffice
  python3 ${./make.py} \
    ${app}/share/desktopeditors/editors/web-apps/apps/documenteditor/main/resources/css/app.css \
    ${../alis-icons} $out/share/alis-onlyoffice/theme-alis.json
''
