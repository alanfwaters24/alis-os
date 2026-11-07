# One switch per ALIS module: run it here, link to the one you already
# have, or leave it off.
#
#   alis.modules.glance.mode = "builtin";   # run on this machine
#   alis.modules.fuel.mode   = "link";      # use the existing one (address from registry.nix)
#   alis.modules.fuel.url    = "http://192.168.1.240:3501";   # ...or a different address
#   alis.modules.arcade.mode = "off";
#
# Defaults: the brain role runs everything it can build in and links the
# rest; PCs/laptops/kiosks link every module that's live today; servers
# start with everything off.
#
# Every module that's on is written to /etc/alis/connect.json and given to
# every ALIS app as ALIS_<NAME>_URL. On PCs/laptops each one with a web page
# also gets an app in the start menu. Laptops ("auto" network) try the home
# address first and Tailscale when away.
{ config, lib, pkgs, ... }:
let
  registry = import ./registry.nix;
  cfg = config.alis.modules;
  role = config.alis.role;
  network = config.alis.network;
  openUrl = pkgs.callPackage ../pkgs/alis-open-url.nix { };

  lanUrl = r: if r.port != null then "${r.scheme or "http"}://${r.host.lan}:${toString r.port}" else null;
  tsUrl = r:
    if r.host.ts == null || r.tsPort == null then null
    else if r.tsPort == 443 then "https://${r.host.ts}"
    else "https://${r.host.ts}:${toString r.tsPort}";

  # "tailscale": Tailscale first. "lan" and "auto": home network first
  # ("auto" then falls back to Tailscale, see fallbackUrl).
  defaultUrl = r:
    let lan = lanUrl r; ts = tsUrl r; in
    if network == "tailscale" then (if ts != null then ts else lan)
    else (if lan != null then lan else ts);

  builtinUrl = r: "${r.scheme or "http"}://127.0.0.1:${toString r.port}";

  defaultMode = r:
    if role == "brain" then (if r.builtin then "builtin" else if r.live then "link" else "off")
    else if lib.elem role [ "desktop" "laptop" "kiosk" ] then (if r.live then "link" else "off")
    else "off";

  on = lib.filterAttrs (_: m: m.mode != "off") cfg;
  envName = n: "ALIS_${lib.toUpper n}_URL";

  # Each app opens in its own Chromium profile so KDE can tell the windows
  # apart and show the right icon (lib/chrome-app-id.nix); a hidden entry
  # covers the fallback address.
  appId = import ../lib/chrome-app-id.nix { inherit lib; };
  launcherFor = n: m: name: extra: pkgs.makeDesktopItem ({
    inherit name;
    desktopName = "ALIS · ${m.title}";
    comment = m.about;
    exec = "${openUrl}/bin/alis-open-url --profile alis-${n} ${m.effectiveUrl} ${lib.optionalString (m.fallbackUrl != null) m.fallbackUrl}";
    # The app's own icon (artwork/apps) if there is one, else the ALIS logo.
    icon = if builtins.pathExists ../artwork/apps/alis-${n}.png || builtins.pathExists ../artwork/apps/alis-${n}.svg
      then "alis-${n}" else "alis-logo";
    categories = [ "Utility" ];
  } // extra);
  launchers = lib.concatLists (lib.mapAttrsToList (n: m:
    [ (launcherFor n m "alis-${n}" { startupWMClass = appId m.effectiveUrl "alis-${n}"; }) ]
    ++ lib.optional (m.fallbackUrl != null)
      (launcherFor n m (appId m.fallbackUrl "alis-${n}") { noDisplay = true; })
  ) (lib.filterAttrs (n: m: m.ui && n != "nest") on)); # NEST already has the "ALIS Dashboard" app
in
{
  options.alis.network = lib.mkOption {
    type = lib.types.enum [ "lan" "tailscale" "auto" ];
    default = if role == "laptop" then "auto" else "lan";
    description = ''
      How linked modules are reached: "lan" (home network), "tailscale"
      (works anywhere, needs `tailscale up` once), or "auto" (home network
      first, Tailscale when that doesn't answer — the laptop default).
    '';
  };

  options.alis.modules = lib.mapAttrs (n: r: {
    mode = lib.mkOption {
      type = lib.types.enum [ "builtin" "link" "off" ];
      default = defaultMode r;
      description = "${r.title}: run it here (builtin), use an existing one (link), or off.";
    };
    url = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = defaultUrl r;
      description = "Address of the existing ${r.title} (for link mode).";
    };
    effectiveUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      readOnly = true;
      default = if cfg.${n}.mode == "builtin" then builtinUrl r else cfg.${n}.url;
      description = "Where this machine finds ${r.title}.";
    };
    fallbackUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      readOnly = true;
      default =
        let m = cfg.${n}; ts = tsUrl r; in
        if network == "auto" && m.mode == "link" && m.url == lanUrl r && ts != null && ts != m.url then ts else null;
      description = "Second address tried when the first doesn't answer (auto network mode).";
    };
    title = lib.mkOption { type = lib.types.str; default = r.title; readOnly = true; };
    about = lib.mkOption { type = lib.types.str; default = r.about; readOnly = true; };
    ui = lib.mkOption { type = lib.types.bool; default = r.ui; readOnly = true; };
  }) registry;

  config = {
    assertions =
      lib.mapAttrsToList (n: m: {
        assertion = m.mode != "builtin" || registry.${n}.builtin;
        message = "alis.modules.${n}: ${m.title} can't be built in yet (no recipe in ALIS OS). Use mode = \"link\" to the existing one.";
      }) cfg
      ++ lib.mapAttrsToList (n: m: {
        assertion = m.mode != "link" || m.url != null;
        message = "alis.modules.${n}: link mode needs a url (no default address known).";
      }) cfg;

    environment.etc."alis/connect.json".text =
      builtins.toJSON (lib.mapAttrs (_: m: { inherit (m) mode; url = m.effectiveUrl; } // lib.optionalAttrs (m.fallbackUrl != null) { fallback = m.fallbackUrl; }) on);
    environment.variables = lib.mapAttrs' (n: m: lib.nameValuePair (envName n) m.effectiveUrl) on;
    alis.appsEnvironment = lib.mapAttrs' (n: m: lib.nameValuePair (envName n) m.effectiveUrl) on;

    environment.systemPackages = lib.optionals (lib.elem role [ "desktop" "laptop" ]) (launchers ++ [ openUrl ]);
  };
}
