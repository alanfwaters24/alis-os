# ALIS boot picker artwork (rEFInd theme, modules/boot-picker.nix):
# full-screen background, one big glass tile per system, and the glowing
# frame drawn behind whichever tile is selected.
{ runCommand, librsvg, makeFontsConf, callPackage, mouse ? false }:
let
  c = import ./colours.nix;
  fonts = callPackage ../pkgs/alis-fonts { };

  # Sizes rEFInd is told to use (no scaling = crisp edges).
  icon = 192;
  sel = 216;   # rEFInd's selection frame is 144/128 of the icon size

  defs = ''
    <defs>
      <linearGradient id="tile" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="#10241F"/><stop offset="1" stop-color="${c.bg}"/>
      </linearGradient>
      <linearGradient id="edge" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="${c.cyan}" stop-opacity="0.55"/>
        <stop offset="1" stop-color="${c.violet}" stop-opacity="0.55"/>
      </linearGradient>
      <linearGradient id="ring" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="${c.teal}"/><stop offset="0.5" stop-color="${c.cyan}"/><stop offset="1" stop-color="${c.violet}"/>
      </linearGradient>
      <radialGradient id="blobTeal"><stop offset="0" stop-color="${c.teal}" stop-opacity="0.16"/><stop offset="1" stop-color="${c.teal}" stop-opacity="0"/></radialGradient>
      <radialGradient id="blobViolet"><stop offset="0" stop-color="${c.violet}" stop-opacity="0.16"/><stop offset="1" stop-color="${c.violet}" stop-opacity="0"/></radialGradient>
    </defs>
  '';

  svg = w: h: body: ''
    <svg xmlns="http://www.w3.org/2000/svg" width="${toString w}" height="${toString h}" viewBox="0 0 ${toString w} ${toString h}">
      ${defs}
      ${body}
    </svg>
  '';

  # A glass tile (192 x 192) with a picture and the system's name under it.
  tile = name: picture: svg icon icon ''
    <rect x="6" y="6" width="180" height="180" rx="34" fill="url(#tile)" stroke="url(#edge)" stroke-width="3"/>
    <rect x="9" y="9" width="174" height="60" rx="31" fill="#ffffff" fill-opacity="0.05"/>
    ${picture}
    <text x="96" y="168" text-anchor="middle" font-family="Rajdhani" font-weight="700"
          font-size="30" letter-spacing="1.5" fill="${c.text}">${name}</text>
  '';

  # ALIS OS: the ALIS double ring.
  alisPicture = ''
    <circle cx="96" cy="80" r="50" fill="none" stroke="url(#ring)" stroke-width="7"/>
    <circle cx="96" cy="80" r="40" fill="none" stroke="url(#ring)" stroke-width="2.5" stroke-opacity="0.6"/>
    <text x="96" y="88" text-anchor="middle" font-family="Exo 2" font-weight="700"
          font-size="21" letter-spacing="1" fill="${c.text}">A.L.I.S</text>
  '';

  # Windows: four window panes, in ALIS colours.
  windowsPicture = ''
    <g transform="translate(56 40)">
      <rect x="0"  y="0"  width="38" height="38" rx="4" fill="${c.cyan}"/>
      <rect x="42" y="0"  width="38" height="38" rx="4" fill="${c.teal}"/>
      <rect x="0"  y="42" width="38" height="38" rx="4" fill="${c.violet}"/>
      <rect x="42" y="42" width="38" height="38" rx="4" fill="${c.violetBright}"/>
    </g>
  '';

  # Drawn behind the selected tile: a bright glow frame.
  selectionBig = svg sel sel ''
    <rect x="4" y="4" width="208" height="208" rx="44" fill="${c.teal}" fill-opacity="0.10"
          stroke="url(#ring)" stroke-width="6"/>
  '';
  selectionSmall = svg 64 64 ''
    <rect x="3" y="3" width="58" height="58" rx="16" fill="${c.teal}" fill-opacity="0.12"
          stroke="url(#ring)" stroke-width="3"/>
  '';

  background = w: h: svg w h ''
    <rect width="100%" height="100%" fill="${c.bg}"/>
    <circle cx="${toString (w * 0.15)}" cy="${toString (h * 0.2)}" r="${toString (h * 0.55)}" fill="url(#blobTeal)"/>
    <circle cx="${toString (w * 0.85)}" cy="${toString (h * 0.85)}" r="${toString (h * 0.6)}" fill="url(#blobViolet)"/>
    <text x="${toString (w / 2)}" y="${toString (h * 0.17)}" text-anchor="middle" font-family="Exo 2" font-weight="700"
          font-size="${toString (h * 0.06)}" letter-spacing="${toString (h * 0.012)}" fill="${c.text}">A.L.I.S</text>
    <text x="${toString (w / 2)}" y="${toString (h * 0.235)}" text-anchor="middle" font-family="Rajdhani" font-weight="600"
          font-size="${toString (h * 0.034)}" letter-spacing="${toString (h * 0.004)}" fill="${c.teal}">What do you want to start?</text>
    <text x="${toString (w / 2)}" y="${toString (h * 0.93)}" text-anchor="middle" font-family="Rajdhani" font-weight="500"
          font-size="${toString (h * 0.024)}" fill="${c.textDim}">${if mouse then "Click one, or use the arrow keys and press Enter" else "Use the arrow keys, then press Enter"}</text>
  '';
in
runCommand "alis-boot-picker-theme" {
  nativeBuildInputs = [ librsvg ];
  FONTCONFIG_FILE = makeFontsConf { fontDirectories = [ fonts ]; };
  passAsFile = [ "alis" "windows" "selBig" "selSmall" "bg" ];
  alis = tile "ALIS OS" alisPicture;
  windows = tile "Windows" windowsPicture;
  selBig = selectionBig;
  selSmall = selectionSmall;
  bg = background 1920 1080;
} ''
  mkdir -p $out
  rsvg-convert $alisPath -o $out/os_alis.png
  rsvg-convert $windowsPath -o $out/os_windows.png
  rsvg-convert $selBigPath -o $out/selection_big.png
  rsvg-convert $selSmallPath -o $out/selection_small.png
  rsvg-convert $bgPath -o $out/background.png
  cat > $out/theme.conf <<'EOF'
  banner alis/background.png
  banner_scale fillscreen
  big_icon_size ${toString icon}
  small_icon_size 48
  selection_big alis/selection_big.png
  selection_small alis/selection_small.png
  font fonts/ubuntu-mono-24.png
  hideui label,hints,badges,arrows,editor,singleuser,safemode,hwtest
  EOF
''
