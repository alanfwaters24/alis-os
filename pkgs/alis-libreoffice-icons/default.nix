# LibreOffice "ALIS" icon style (Tools → Options → View → Icon Theme): its
# Breeze Dark toolbar icons recoloured to ALIS duotone (make.py). Shapes from
# LibreOffice's Breeze set (LGPL/MPL); colours from alis-core.
#
# LibreOffice is told about the extra folder per person (roles/desktop.nix,
# its Iconset UserPaths setting), so LibreOffice itself isn't rebuilt.
{ runCommand, python3, libreoffice-unwrapped }:
runCommand "alis-libreoffice-icons" { nativeBuildInputs = [ python3 ]; } ''
  mkdir -p $out/share/alis-libreoffice
  python3 ${./make.py} \
    ${libreoffice-unwrapped}/lib/libreoffice/share/config/images_breeze_dark_svg.zip \
    ${../alis-icons} $out/share/alis-libreoffice/images_alis_svg.zip
''
