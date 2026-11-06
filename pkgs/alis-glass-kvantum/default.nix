# ALIS Glass for Qt/KDE apps: a Kvantum theme generated from Kvantum's KvFlat
# (make-theme.py), recoloured to the ALIS palette with frosted translucency.
{ runCommand, python3, kdePackages }:
runCommand "alis-glass-kvantum" { nativeBuildInputs = [ python3 ]; } ''
  python3 ${./make-theme.py} ${kdePackages.qtstyleplugin-kvantum}/share/Kvantum/KvFlat $out/share/Kvantum/ALISGlass
''
