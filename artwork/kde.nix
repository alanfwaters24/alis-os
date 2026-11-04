# ALIS Glass for KDE Plasma: colour scheme, wallpaper, login-screen background.
{ runCommand, callPackage, lib }:
let
  artwork = callPackage ./default.nix { };
  rgb = hex:
    let
      h = lib.removePrefix "#" hex;
      byte = i: (lib.fromHexString (builtins.substring i 2 h));
    in "${toString (byte 0)},${toString (byte 2)},${toString (byte 4)}";
  c = import ./colours.nix;
  surface = "#0C1C18";
  surfaceAlt = "#10241F";
  raised = "#14302A";

  section = name: bg: alt: ''
    [Colors:${name}]
    BackgroundNormal=${rgb bg}
    BackgroundAlternate=${rgb alt}
    ForegroundNormal=${rgb c.text}
    ForegroundInactive=${rgb c.textDim}
    ForegroundActive=${rgb c.cyan}
    ForegroundLink=${rgb c.teal}
    ForegroundVisited=${rgb c.violet}
    ForegroundNegative=${rgb c.danger}
    ForegroundNeutral=${rgb c.warn}
    ForegroundPositive=${rgb c.tealBright}
    DecorationFocus=${rgb c.teal}
    DecorationHover=${rgb c.violet}

  '';

  colors = ''
    [General]
    Name=ALIS Glass
    ColorScheme=ALISGlass
    shadeSortColumn=true

    [KDE]
    contrast=4

    ${section "Window" c.bg surface}
    ${section "View" surface surfaceAlt}
    ${section "Button" raised surface}
    ${section "Header" c.bg surface}
    ${section "Tooltip" surface c.bg}
    ${section "Complementary" c.bg surface}
    [Colors:Selection]
    BackgroundNormal=${rgb c.teal}
    BackgroundAlternate=${rgb c.violet}
    ForegroundNormal=${rgb c.bg}
    ForegroundInactive=${rgb c.bg}
    ForegroundActive=${rgb c.bg}
    ForegroundLink=${rgb c.bg}
    ForegroundVisited=${rgb c.bg}
    ForegroundNegative=${rgb c.danger}
    ForegroundNeutral=${rgb c.warn}
    ForegroundPositive=${rgb c.bg}
    DecorationFocus=${rgb c.teal}
    DecorationHover=${rgb c.violet}

    [WM]
    activeBackground=${rgb c.bg}
    activeForeground=${rgb c.text}
    activeBlend=${rgb c.teal}
    inactiveBackground=${rgb c.bg}
    inactiveForeground=${rgb c.textDim}
    inactiveBlend=${rgb c.bg}
  '';
in
runCommand "alis-kde-theme" { passAsFile = [ "colors" ]; inherit colors; } ''
  mkdir -p $out/share/color-schemes $out/share/wallpapers/ALIS/contents/images
  cp $colorsPath $out/share/color-schemes/ALISGlass.colors
  cp ${artwork}/splash.png $out/share/wallpapers/ALIS/contents/images/1920x1080.png
  cat > $out/share/wallpapers/ALIS/metadata.json <<'EOF'
  { "KPlugin": { "Id": "ALIS", "Name": "ALIS Glass", "License": "CC-BY-SA-4.0" } }
  EOF
  # Login screen (SDDM Breeze) background
  mkdir -p $out/share/sddm/themes/breeze
  printf '[General]\nbackground=%s\ntype=image\n' ${artwork}/splash.png > $out/share/sddm/themes/breeze/theme.conf.user
''
