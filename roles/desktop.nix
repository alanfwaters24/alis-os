# Desktop role — office PC (and the base for the laptop role).
# A full desktop (KDE Plasma) dressed as ALIS: ALIS Glass colours, wallpaper
# and login screen, the dashboard opening as an app on login, and the usual
# PC apps built in.
#
#   Files .............. Dolphin              Settings ...... System Settings
#   Browser ............ PANE (modules/pane.nix) Themes ..... System Settings → Appearance (ALIS Glass)
#   Office ............. OnlyOffice + LibreOffice  Storage .. Filelight + Partition Manager
#   Notepad ............ KWrite / Kate        Calculator .... KCalc
#   Downloads/Archives . Ark                  App store ..... Discover (Flatpak)
#   Photos / PDFs ...... Gwenview / Okular    Screenshots ... Spectacle
{ config, lib, pkgs, ... }:
let
  isDesktop = lib.elem config.alis.role [ "desktop" "laptop" ];
  theme = pkgs.callPackage ../artwork/kde.nix { };
  artwork = pkgs.callPackage ../artwork { };

  # Its window is matched to this by Chromium's window name (StartupWMClass),
  # so the dock shows the DNA icon, not a generic "W". The other addresses it
  # can fall back to get hidden entries with the same name and icon.
  dashIds = config.alis.dashboard.appIds;
  dashboardEntry = name: extra: pkgs.makeDesktopItem ({
    inherit name;
    desktopName = "ALIS Dashboard";
    genericName = "ALIS home";
    exec = "${config.alis.dashboard.openCommand}/bin/alis-open-dashboard";
    icon = "alis-dashboard";
    categories = [ "Utility" ];
  } // extra);
  dashboardApp = dashboardEntry "alis-dashboard" { startupWMClass = lib.head dashIds; };
  dashboardFallbacks = map (id: dashboardEntry id { noDisplay = true; }) (lib.tail dashIds);

  # Runs once per person per ALIS look version (modules/theme.nix): applies
  # the ALIS Glass Global Theme (dock, colours, glass style) and the fonts.
  # After that they can change anything in System Settings and it sticks.
  firstLogin = pkgs.writeShellScript "alis-first-login" ''
    marker="$HOME/.config/alis-theme-applied-v${toString config.alis.theme.version}"
    [ -e "$marker" ] && exit 0
    sleep 3
    plasma-apply-lookandfeel --apply org.alis.glass.desktop --resetLayout || true
    plasma-apply-colorscheme ALISGlass || true
    plasma-apply-wallpaperimage /etc/alis/artwork/splash.png || true
    plasma-apply-desktoptheme breeze-dark || true
    mkdir -p "$HOME/.config/Kvantum"
    [ -e "$HOME/.config/Kvantum/kvantum.kvconfig" ] || printf '[General]\ntheme=ALISGlass\n' > "$HOME/.config/Kvantum/kvantum.kvconfig"
    kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum || true
    # Lock screen: ALIS wallpaper (also the system default, see modules/theme.nix).
    kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin org.kde.image || true
    kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General \
      --key Image file:///etc/alis/artwork/splash.png || true
    # OnlyOffice: its own dark theme (it doesn't follow system themes).
    oo="$HOME/.config/onlyoffice/DesktopEditors.conf"
    if [ ! -e "$oo" ]; then mkdir -p "$(dirname "$oo")"; printf '[General]\nUITheme=theme-dark\n' > "$oo"; fi
    mkdir -p "$(dirname "$marker")" && touch "$marker"
  '';

  # One-off repair (own marker, doesn't touch the dock or layout): earlier
  # builds could leave a desktop on the Plasma default picture, e.g. a
  # screen that came up after a restart. Puts the ALIS wallpaper on every
  # screen once; anything chosen afterwards in System Settings sticks.
  wallpaperFix = pkgs.writeShellScript "alis-wallpaper-fix" ''
    marker="$HOME/.config/alis-wallpaper-fix-v1"
    [ -e "$marker" ] && exit 0
    sleep 8
    plasma-apply-wallpaperimage /etc/alis/artwork/splash.png || exit 0
    mkdir -p "$(dirname "$marker")" && touch "$marker"
  '';

  # One-off switch to the ALIS icons (own marker, nothing else reset).
  # Picking other icons in System Settings afterwards sticks.
  iconsSwitch = pkgs.writeShellScript "alis-icons-switch" ''
    marker="$HOME/.config/alis-icons-v1"
    [ -e "$marker" ] && exit 0
    sleep 5
    kwriteconfig6 --file kdeglobals --group Icons --key Theme ALIS || exit 0
    ${pkgs.kdePackages.plasma-workspace}/libexec/plasma-changeicons ALIS || true
    mkdir -p "$(dirname "$marker")" && touch "$marker"
  '';

  # One-off: the dock's start button pointed at a picture file, which Plasma
  # drew blank; switch it to the named "alis-logo" icon. Only touches start
  # buttons still on the old ALIS file, so a person's own choice is kept.
  launcherFix = pkgs.writeShellScript "alis-launcher-icon" ''
    marker="$HOME/.config/alis-launcher-icon-v1"
    [ -e "$marker" ] && exit 0
    sleep 6
    ${pkgs.kdePackages.qttools}/bin/qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
      panels().forEach(function (p) {
        p.widgets("org.kde.plasma.kickoff").forEach(function (w) {
          w.currentConfigGroup = ["General"];
          var i = w.readConfig("icon", "");
          if (i === "" || i === "/etc/alis/artwork/logo.png") w.writeConfig("icon", "alis-logo");
        });
      });' || exit 0
    mkdir -p "$(dirname "$marker")" && touch "$marker"
  '';

  # One-off switch to the ALIS cursors (own marker; a later pick sticks).
  cursorsSwitch = pkgs.writeShellScript "alis-cursors-switch" ''
    marker="$HOME/.config/alis-cursors-v1"
    [ -e "$marker" ] && exit 0
    sleep 5
    plasma-apply-cursortheme ALIS-cursors || exit 0
    mkdir -p "$(dirname "$marker")" && touch "$marker"
  '';

  # One-off: the floating dock moves from the middle to the bottom-left.
  # Only touches the ALIS dock (bottom panel with the start button).
  dockLeft = pkgs.writeShellScript "alis-dock-left" ''
    marker="$HOME/.config/alis-dock-left-v1"
    [ -e "$marker" ] && exit 0
    sleep 6
    ${pkgs.kdePackages.qttools}/bin/qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
      panels().forEach(function (p) {
        if (p.location === "bottom" && p.widgets("org.kde.plasma.kickoff").length > 0) p.alignment = "left";
      });' || exit 0
    mkdir -p "$(dirname "$marker")" && touch "$marker"
  '';
in
{
  config = lib.mkIf isDesktop {
    services.desktopManager.plasma6.enable = true;
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
    services.displayManager.defaultSession = "plasma";
    # Unlock the KDE Wallet (saved passwords) with the login password, so
    # nothing pops up asking to set one up.
    security.pam.services.sddm.kwallet.enable = true;
    security.pam.services.login.kwallet.enable = true;

    environment.systemPackages = (with pkgs; [
      theme
      onlyoffice-desktopeditors
      kdePackages.kcalc
      kdePackages.kate
      kdePackages.filelight
      kdePackages.partitionmanager
      kdePackages.ark
      kdePackages.gwenview
      kdePackages.okular
      kdePackages.spectacle
      kdePackages.discover
      kdePackages.kdialog
    ]) ++ [ dashboardApp ] ++ dashboardFallbacks ++ [
      (pkgs.makeAutostartItem { name = "alis-dashboard"; package = dashboardApp; })
      (pkgs.writeTextDir "etc/xdg/autostart/alis-first-login.desktop" ''
        [Desktop Entry]
        Type=Application
        Name=ALIS look
        Exec=${firstLogin}
        X-KDE-autostart-phase=2
        NoDisplay=true
      '')
      (pkgs.writeTextDir "etc/xdg/autostart/alis-wallpaper-fix.desktop" ''
        [Desktop Entry]
        Type=Application
        Name=ALIS wallpaper
        Exec=${wallpaperFix}
        X-KDE-autostart-phase=2
        NoDisplay=true
      '')
      (pkgs.writeTextDir "etc/xdg/autostart/alis-icons-switch.desktop" ''
        [Desktop Entry]
        Type=Application
        Name=ALIS icons
        Exec=${iconsSwitch}
        X-KDE-autostart-phase=2
        NoDisplay=true
      '')
      (pkgs.writeTextDir "etc/xdg/autostart/alis-launcher-icon.desktop" ''
        [Desktop Entry]
        Type=Application
        Name=ALIS start button
        Exec=${launcherFix}
        X-KDE-autostart-phase=2
        NoDisplay=true
      '')
      (pkgs.writeTextDir "etc/xdg/autostart/alis-cursors-switch.desktop" ''
        [Desktop Entry]
        Type=Application
        Name=ALIS cursors
        Exec=${cursorsSwitch}
        X-KDE-autostart-phase=2
        NoDisplay=true
      '')
      (pkgs.writeTextDir "etc/xdg/autostart/alis-dock-left.desktop" ''
        [Desktop Entry]
        Type=Application
        Name=ALIS dock position
        Exec=${dockLeft}
        X-KDE-autostart-phase=2
        NoDisplay=true
      '')
    ];

    # Defaults for new users: see modules/theme.nix.
    # Start each login fresh (just the dashboard), instead of KDE reopening
    # whatever was open at log-out, e.g. a terminal. Changeable in System
    # Settings → Session → Desktop Session.
    environment.etc."xdg/ksmserverrc".text = ''
      [General]
      loginMode=emptySession
    '';

    # Extra apps from Flathub via Discover.
    services.flatpak.enable = true;
    systemd.services.alis-flathub = {
      description = "Add Flathub to the ALIS app store";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ pkgs.flatpak ];
      script = "flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo";
      serviceConfig = { Type = "oneshot"; Restart = "on-failure"; RestartSec = 60; };
    };

    fonts.packages = with pkgs; [ noto-fonts noto-fonts-color-emoji dejavu_fonts liberation_ttf ];
    hardware.graphics.enable = true;
    services.pipewire = { enable = true; pulse.enable = true; };
    # PipeWire's "X11 bell" add-on (old X beep sounds) crashes PipeWire when
    # Xwayland goes away at log-out (seen on the office PC). Not needed.
    services.pipewire.extraConfig.pipewire."99-alis-no-x11-bell" = {
      "context.properties" = { "module.x11.bell" = false; };
    };
    services.printing.enable = true;
    hardware.bluetooth.enable = true;
    xdg.portal.enable = true;
  };
}
