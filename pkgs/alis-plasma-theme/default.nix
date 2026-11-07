# ALIS Plasma theme ("ALIS Glass" in System Settings → Colours & Themes →
# Plasma Style): the dock, tray icons, pop-ups and widgets in ALIS colours.
{ runCommand, python3, kdePackages, alisKdeTheme }:
runCommand "alis-plasma-theme" { nativeBuildInputs = [ python3 ]; } ''
  mkdir -p $out/share/plasma/desktoptheme
  python3 ${./make.py} ${kdePackages.libplasma}/share/plasma/desktoptheme ${../alis-icons} \
    ${alisKdeTheme}/share/color-schemes/ALISGlass.colors ${alisKdeTheme}/share/wallpapers/ALIS \
    $out/share/plasma/desktoptheme/alis
''
