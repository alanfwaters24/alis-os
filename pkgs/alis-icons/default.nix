# ALIS icon theme: every Papirus-Dark icon recoloured to ALIS duotone
# (make-icons.py). Shapes from Papirus (GPL-3.0); colours from alis-core.
{ runCommand, python3, papirus-icon-theme }:
runCommand "alis-icons" { nativeBuildInputs = [ python3 ]; } ''
  mkdir -p $out/share/icons
  python3 ${./.}/make-icons.py ${papirus-icon-theme}/share/icons $out/share/icons/ALIS
''
