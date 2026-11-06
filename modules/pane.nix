# PANE on PCs and laptops: the ALIS browser (pkgs/pane) plus its settings,
# applied as Chromium policies (people can't accidentally lose them):
#   - new tab + home = the ALIS start page, with a tile for every ALIS module
#   - DuckDuckGo search · "ALIS" bookmarks folder · uBlock Origin Lite
# Kiosks and the ALIS app windows keep using plain Chromium underneath.
{ config, lib, pkgs, ... }:
let
  isDesktop = lib.elem config.alis.role [ "desktop" "laptop" ];
  pane = pkgs.callPackage ../pkgs/pane { };
  mods = lib.filterAttrs (_: m: m.mode != "off" && m.ui) config.alis.modules;
  # NEST first, then the rest by name.
  order = lib.sort (a: b: if a.n == "nest" then true else if b.n == "nest" then false else a.title < b.title)
    (lib.mapAttrsToList (n: m: m // { inherit n; }) mods);
  links = map (m: { name = m.title; about = m.about; url = m.effectiveUrl; fallback = m.fallbackUrl; }) order;
  start = "file:///etc/pane/start.html";
in
{
  config = lib.mkIf isDesktop {
    environment.systemPackages = [ pane ];

    environment.etc."pane/start.html".source = "${pane}/share/pane/start.html";
    environment.etc."pane/alis_glass_theme.css".source = "${pane}/share/pane/alis_glass_theme.css";
    environment.etc."pane/links.js".text = "window.ALIS_LINKS = ${builtins.toJSON links};\n";

    programs.chromium.extraOpts = {
      # Start page
      HomepageLocation = start;
      HomepageIsNewTabPage = false;
      NewTabPageLocation = start;
      ShowHomeButton = true;
      RestoreOnStartup = 5;                      # open the start page
      # Search
      DefaultSearchProviderEnabled = true;
      DefaultSearchProviderName = "DuckDuckGo";
      DefaultSearchProviderKeyword = "ddg";
      DefaultSearchProviderSearchURL = "https://duckduckgo.com/?q={searchTerms}";
      DefaultSearchProviderSuggestURL = "https://duckduckgo.com/ac/?q={searchTerms}&type=list";
      DefaultSearchProviderIconURL = "https://duckduckgo.com/favicon.ico";
      # ALIS bookmarks (kept in step with the module list)
      BookmarkBarEnabled = true;
      ManagedBookmarks = [ { toplevel_name = "ALIS"; } ] ++ map (l: { inherit (l) name url; }) links;
      # Ad & tracker blocking (uBlock Origin Lite, kept updated from the Chrome Web Store)
      ExtensionInstallForcelist = [ "ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx" ];
      # Tidy first run
      PromotionsEnabled = false;
      BrowserSignin = 0;
      MetricsReportingEnabled = false;
    };
  };
}
