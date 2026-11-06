# "ALIS Glass" Plasma Global Theme (System Settings → Appearance → Global
# Theme): colours, Kvantum frosted style, icons, window decoration, and the
# desktop layout (ALIS wallpaper + floating glass dock).
{ runCommand, callPackage }:
let artwork = callPackage ../../artwork { }; in
runCommand "alis-lookandfeel" { } ''
  d=$out/share/plasma/look-and-feel/org.alis.glass.desktop
  mkdir -p $d
  cp -r ${./contents} $d/contents
  chmod -R u+w $d
  cp ${./metadata.json} $d/metadata.json
  mkdir -p $d/contents/previews
  cp ${artwork}/splash.png $d/contents/previews/preview.png
  cp ${artwork}/splash.png $d/contents/previews/fullscreenpreview.jpg
''
