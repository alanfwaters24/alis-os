# The ALIS Glass theme pack for PCs and laptops (roadmap Stage 5):
#   5a  ALIS fonts everywhere: Rajdhani (text), Exo 2 (titles), Share Tech Mono
#   5c  frosted-glass apps: Kvantum "ALIS Glass" + KWin blur; ALIS glow edge
#       on the active window (teal window shadow)
#   5d  ALIS Glass Global Theme: floating glass dock, ALIS logo start button,
#       ALIS wallpaper, Breeze Dark glass panels
#   5e  apps with their own look: OnlyOffice set to its dark theme;
#       LibreOffice (follows the ALIS look) installed alongside
# Applied once per person on first login (roles/desktop.nix); anyone can
# change it afterwards in System Settings → Appearance.
{ config, lib, pkgs, ... }:
let
  isDesktop = lib.elem config.alis.role [ "desktop" "laptop" ];
  fonts = pkgs.callPackage ../pkgs/alis-fonts { };
  kvantumTheme = pkgs.callPackage ../pkgs/alis-glass-kvantum { };
  lookandfeel = pkgs.callPackage ../pkgs/alis-lookandfeel { };
  icons = pkgs.callPackage ../pkgs/alis-icons { };
  # LibreOffice's own toolbar icons, recoloured (pkgs/alis-libreoffice-icons).
  libreoffice = pkgs.libreoffice-qt6-fresh;
  loIcons = pkgs.callPackage ../pkgs/alis-libreoffice-icons { libreoffice-unwrapped = libreoffice.unwrapped; };
  loIconsSetup = pkgs.writeShellScript "alis-libreoffice-icons" ''
    ${pkgs.procps}/bin/pgrep -u "$(id -u)" -f soffice.bin >/dev/null && exit 0   # not while LibreOffice is open
    exec ${pkgs.python3}/bin/python3 ${../pkgs/alis-libreoffice-icons/setup.py} /run/current-system/sw/share/alis-libreoffice
  '';
in
{
  options.alis.theme.version = lib.mkOption {
    type = lib.types.int;
    default = 2;
    readOnly = true;
    description = "Bumped when the ALIS look changes, so each person gets the new look once on their next login.";
  };

  config = lib.mkIf isDesktop {
    fonts.packages = [ fonts ];
    environment.systemPackages = [
      kvantumTheme
      lookandfeel
      icons
      pkgs.kdePackages.qtstyleplugin-kvantum
      libreoffice
      loIcons
      (pkgs.writeTextDir "etc/xdg/autostart/alis-libreoffice-icons.desktop" ''
        [Desktop Entry]
        Type=Application
        Name=ALIS LibreOffice icons
        Exec=${loIconsSetup}
        NoDisplay=true
      '')
      pkgs.hunspellDicts.en_GB-ise
    ];
    # /run/current-system/sw/share/alis-libreoffice stays put across updates.
    environment.pathsToLink = [ "/share/Kvantum" "/share/alis-libreoffice" ];

    # Defaults for everyone (KDE reads these until a person changes them).
    environment.etc."xdg/kdeglobals".text = ''
      [General]
      ColorScheme=ALISGlass
      font=Rajdhani,11,-1,5,500,0,0,0,0,0
      menuFont=Rajdhani,11,-1,5,500,0,0,0,0,0
      toolBarFont=Rajdhani,10,-1,5,500,0,0,0,0,0
      smallestReadableFont=Rajdhani,9,-1,5,500,0,0,0,0,0
      fixed=Share Tech Mono,10,-1,5,400,0,0,0,0,0

      [WM]
      activeFont=Exo 2,10,-1,5,700,0,0,0,0,0

      [KDE]
      LookAndFeelPackage=org.alis.glass.desktop
      widgetStyle=kvantum

      [Icons]
      Theme=ALIS
    '';

    # Blur behind see-through windows, menus and the dock.
    environment.etc."xdg/kwinrc".text = ''
      [Plugins]
      blurEnabled=true
      contrastEnabled=true

      [Effect-blur]
      BlurStrength=8
      NoiseStrength=2

      [org.kde.kdecoration2]
      library=org.kde.breeze
      theme=Breeze
    '';

    # Calculator: KCalc paints its own buttons, so give it ALIS colours directly.
    environment.etc."xdg/kcalcrc".text = ''
      [Colors]
      BackColor=12,28,24
      ForeColor=94,234,212
      NumberButtonsColor=20,48,42
      FunctionButtonsColor=14,32,27
      StatButtonsColor=14,32,27
      HexButtonsColor=14,32,27
      MemoryButtonsColor=42,37,80
      OperationButtonsColor=23,143,130
      NumberFontsColor=232,245,240
      FunctionFontsColor=232,245,240
      StatFontsColor=232,245,240
      HexFontsColor=232,245,240
      MemoryFontsColor=232,245,240
      OperationFontsColor=232,245,240

      [Font]
      DisplayFont=Share Tech Mono,22,-1,5,400,0,0,0,0,0
      ButtonFont=Rajdhani,12,-1,5,600,0,0,0,0,0
    '';

    # Lock screen: the ALIS wallpaper too.
    environment.etc."xdg/kscreenlockerrc".text = ''
      [Greeter]
      WallpaperPlugin=org.kde.image

      [Greeter][Wallpaper][org.kde.image][General]
      Image=file:///etc/alis/artwork/splash.png
      PreviewImage=file:///etc/alis/artwork/splash.png
    '';

    # ALIS glow edge: a soft teal glow around the active window.
    environment.etc."xdg/breezerc".text = ''
      [Common]
      ShadowColor=45,212,191
      ShadowSize=ShadowLarge
      ShadowStrength=110
      OutlineIntensity=OutlineHigh

      [Windeco]
      TitleAlignment=AlignCenterFullWidth
      ButtonSize=ButtonDefault
    '';
  };
}
