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

  dashboardApp = pkgs.makeDesktopItem {
    name = "alis-dashboard";
    desktopName = "ALIS Dashboard";
    genericName = "ALIS home";
    exec = "${config.alis.dashboard.openCommand}/bin/alis-open-dashboard --class=alis-dashboard";
    icon = "${artwork}/logo.png";
    categories = [ "Utility" ];
    startupWMClass = "alis-dashboard";
  };

  # Runs once per person per ALIS look version (modules/theme.nix): applies
  # the ALIS Glass Global Theme (dock, colours, glass style) and the fonts.
  # After that they can change anything in System Settings and it sticks.
  firstLogin = pkgs.writeShellScript "alis-first-login" ''
    marker="$HOME/.config/alis-theme-applied-v${toString config.alis.theme.version}"
    [ -e "$marker" ] && exit 0
    sleep 3
    plasma-apply-lookandfeel --apply org.alis.glass.desktop --resetLayout || true
    plasma-apply-colorscheme ALISGlass || true
    plasma-apply-wallpaperimage ${theme}/share/wallpapers/ALIS || true
    plasma-apply-desktoptheme breeze-dark || true
    mkdir -p "$HOME/.config/Kvantum"
    [ -e "$HOME/.config/Kvantum/kvantum.kvconfig" ] || printf '[General]\ntheme=ALISGlass\n' > "$HOME/.config/Kvantum/kvantum.kvconfig"
    kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum || true
    # OnlyOffice: its own dark theme (it doesn't follow system themes).
    oo="$HOME/.config/onlyoffice/DesktopEditors.conf"
    if [ ! -e "$oo" ]; then mkdir -p "$(dirname "$oo")"; printf '[General]\nUITheme=theme-dark\n' > "$oo"; fi
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
      dashboardApp
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
    ]) ++ [
      (pkgs.makeAutostartItem { name = "alis-dashboard"; package = dashboardApp; })
      (pkgs.writeTextDir "etc/xdg/autostart/alis-first-login.desktop" ''
        [Desktop Entry]
        Type=Application
        Name=ALIS look
        Exec=${firstLogin}
        X-KDE-autostart-phase=2
        NoDisplay=true
      '')
    ];

    # Defaults for new users: see modules/theme.nix.

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
    services.printing.enable = true;
    hardware.bluetooth.enable = true;
    xdg.portal.enable = true;
  };
}
