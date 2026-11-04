# ALIS OS artwork — logo + boot splash, drawn from SVG at build time so the
# ALIS Glass colours live in one place (matches alis-core/alis_glass_theme.css).
{ runCommand, librsvg, makeFontsConf, dejavu_fonts }:

let
  c = import ./colours.nix;

  logo = ''
    <defs>
      <linearGradient id="ring" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="${c.teal}"/>
        <stop offset="0.5" stop-color="${c.cyan}"/>
        <stop offset="1" stop-color="${c.violet}"/>
      </linearGradient>
      <radialGradient id="blobTeal"><stop offset="0" stop-color="${c.teal}" stop-opacity="0.14"/><stop offset="1" stop-color="${c.teal}" stop-opacity="0"/></radialGradient>
      <radialGradient id="blobViolet"><stop offset="0" stop-color="${c.violet}" stop-opacity="0.14"/><stop offset="1" stop-color="${c.violet}" stop-opacity="0"/></radialGradient>
      <radialGradient id="glow" cx="0.5" cy="0.5" r="0.5">
        <stop offset="0" stop-color="${c.teal}" stop-opacity="0.35"/>
        <stop offset="1" stop-color="${c.teal}" stop-opacity="0"/>
      </radialGradient>
    </defs>
  '';

  # A glowing double ring with "A.L.I.S" in the middle.
  emblem = cx: cy: r: ''
    <circle cx="${toString cx}" cy="${toString cy}" r="${toString (r * 1.6)}" fill="url(#glow)"/>
    <circle cx="${toString cx}" cy="${toString cy}" r="${toString r}" fill="none" stroke="url(#ring)" stroke-width="${toString (r / 14)}"/>
    <circle cx="${toString cx}" cy="${toString cy}" r="${toString (r * 0.82)}" fill="none" stroke="url(#ring)" stroke-width="${toString (r / 40)}" stroke-opacity="0.6"/>
    <text x="${toString cx}" y="${toString (cy + r * 0.13)}" text-anchor="middle"
          font-family="DejaVu Sans" font-weight="bold" font-size="${toString (r * 0.36)}"
          letter-spacing="${toString (r * 0.03)}" fill="${c.text}">A.L.I.S</text>
  '';

  svg = w: h: body: ''
    <svg xmlns="http://www.w3.org/2000/svg" width="${toString w}" height="${toString h}" viewBox="0 0 ${toString w} ${toString h}">
      ${logo}
      ${body}
    </svg>
  '';

  logoSvg = svg 256 256 (emblem 128 128 96);

  splash = w: h: svg w h ''
    <rect width="100%" height="100%" fill="${c.bg}"/>
    <circle cx="${toString (w * 0.15)}" cy="${toString (h * 0.2)}" r="${toString (h * 0.5)}" fill="url(#blobTeal)"/>
    <circle cx="${toString (w * 0.85)}" cy="${toString (h * 0.85)}" r="${toString (h * 0.55)}" fill="url(#blobViolet)"/>
    ${emblem (w / 2) (h * 0.45) (h * 0.2)}
    <text x="${toString (w / 2)}" y="${toString (h * 0.8)}" text-anchor="middle"
          font-family="DejaVu Sans" font-size="${toString (h * 0.035)}" letter-spacing="${toString (h * 0.01)}"
          fill="${c.textDim}">ALIS OS</text>
  '';
in
runCommand "alis-artwork" {
  nativeBuildInputs = [ librsvg ];
  FONTCONFIG_FILE = makeFontsConf { fontDirectories = [ dejavu_fonts ]; };
  passAsFile = [ "logo" "splashHd" "splashSmall" ];
  logo = logoSvg;
  splashHd = splash 1920 1080;
  splashSmall = splash 640 480;
} ''
  mkdir -p $out
  cp $logoPath $out/logo.svg
  cp $splashHdPath $out/splash.svg
  rsvg-convert $logoPath -o $out/logo.png
  rsvg-convert $splashHdPath -o $out/splash.png
  rsvg-convert $splashSmallPath -o $out/splash-640x480.png
''
