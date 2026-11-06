// ALIS Glass desktop layout: ALIS wallpaper + a floating glass dock.
// Each setting is tried on its own, so one unsupported option can't stop the rest.
function attempt(fn) { try { fn(); } catch (e) { print("ALIS layout: " + e); } }

var all = desktops();
for (var i = 0; i < all.length; i++) {
  var d = all[i];
  attempt(function () {
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file:///etc/alis/artwork/splash.png");
  });
}

var panel = new Panel;
attempt(function () { panel.location = "bottom"; });
attempt(function () { panel.height = 2 * Math.floor(gridUnit * 2.75 / 2); });
attempt(function () { panel.floating = true; });            // lifted off the screen edge
attempt(function () { panel.lengthMode = "fit"; });         // only as wide as its icons: a dock
attempt(function () { panel.alignment = "center"; });
attempt(function () { panel.opacity = "translucent"; });    // glass (Breeze Dark blurs behind it)

var kickoff = panel.addWidget("org.kde.plasma.kickoff");
attempt(function () {
  kickoff.currentConfigGroup = ["General"];
  kickoff.writeConfig("icon", "/etc/alis/artwork/logo.png"); // ALIS logo as the start button
});

var tasks = panel.addWidget("org.kde.plasma.icontasks");
attempt(function () {
  tasks.currentConfigGroup = ["General"];
  tasks.writeConfig("launchers", [
    "applications:alis-dashboard.desktop",
    "applications:chromium-browser.desktop",
    "applications:org.kde.dolphin.desktop",
    "applications:onlyoffice-desktopeditors.desktop",
    "applications:org.kde.kate.desktop",
    "applications:systemsettings.desktop"
  ]);
});

panel.addWidget("org.kde.plasma.marginsseparator");
panel.addWidget("org.kde.plasma.systemtray");
panel.addWidget("org.kde.plasma.digitalclock");
