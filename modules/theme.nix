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
      pkgs.kdePackages.qtstyleplugin-kvantum
      pkgs.libreoffice-qt6-fresh
      pkgs.hunspellDicts.en_GB-ise
    ];
    environment.pathsToLink = [ "/share/Kvantum" ];

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
      Theme=breeze-dark
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
