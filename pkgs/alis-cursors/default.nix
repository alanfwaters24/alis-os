# ALIS cursor theme ("ALIS" in System Settings → Colours & Themes → Cursors):
# Breeze Dark cursors recoloured to ALIS (make-cursors.py).
{ runCommand, python3, librsvg, xorg, kdePackages }:
runCommand "alis-cursors" { nativeBuildInputs = [ python3 ]; } ''
  mkdir -p $out/share/icons
  python3 ${./make-cursors.py} ${kdePackages.breeze}/share/icons/breeze_cursors ${../alis-icons} \
    $out/share/icons/ALIS-cursors ${librsvg}/bin/rsvg-convert ${xorg.xcursorgen}/bin/xcursorgen
''
