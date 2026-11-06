# PANE — Personal ALIS Network Explorer. Chromium dressed as ALIS:
# ALIS Glass theme, ALIS icon and name, dark mode, ALIS start page.
# The browser engine is unchanged Chromium (same updates, same extensions).
{ lib, runCommand, makeWrapper, chromium, librsvg }:
runCommand "pane-${chromium.version}" {
  nativeBuildInputs = [ makeWrapper librsvg ];
  passthru = { inherit chromium; };
  meta.mainProgram = "pane";
} ''
  mkdir -p $out/bin $out/share/pane $out/share/applications
  cp -r ${./theme} $out/share/pane/theme
  cp ${./start.html} $out/share/pane/start.html
  cp ${./alis_glass_theme.css} $out/share/pane/alis_glass_theme.css

  for s in 16 32 48 64 128 256; do
    mkdir -p $out/share/icons/hicolor/''${s}x''${s}/apps
    rsvg-convert -w $s -h $s ${./icon.svg} -o $out/share/icons/hicolor/''${s}x''${s}/apps/pane.png
  done
  mkdir -p $out/share/icons/hicolor/scalable/apps
  cp ${./icon.svg} $out/share/icons/hicolor/scalable/apps/pane.svg

  # `pane` (and plain `chromium`, so every link opens in PANE)
  makeWrapper ${chromium}/bin/chromium $out/bin/pane \
    --add-flags "--load-extension=$out/share/pane/theme --force-dark-mode"
  ln -s pane $out/bin/chromium

  # Same desktop-file name as Chromium so the taskbar shows PANE's name and icon
  # for its windows; renamed and re-pointed at the wrapper.
  sed -e 's/^Name=.*/Name=PANE/' \
      -e 's/^GenericName=.*/GenericName=Personal ALIS Network Explorer/' \
      -e 's/^Comment=.*/Comment=Browse the web, the ALIS way/' \
      -e "s|^Exec=[^ ]*chromium|Exec=$out/bin/pane|" \
      -e 's/^Icon=.*/Icon=pane/' \
      ${chromium}/share/applications/chromium-browser.desktop > $out/share/applications/chromium-browser.desktop
''
