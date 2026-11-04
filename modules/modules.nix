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
# also gets an app in the start menu.
{ config, lib, pkgs, ... }:
let
  registry = import ./registry.nix;
  cfg = config.alis.modules;
  role = config.alis.role;
  useTailscale = config.alis.network == "tailscale";

  defaultUrl = name: r:
    let
      scheme = r.scheme or "http";
      lan = if r.port != null then "${scheme}://${r.host.lan}:${toString r.port}" else null;
      ts =
        if r.host.ts == null || r.tsPort == null then null
        else if r.tsPort == 443 then "https://${r.host.ts}"
        else "https://${r.host.ts}:${toString r.tsPort}";
    in
    if useTailscale then (if ts != null then ts else lan)
    else (if lan != null then lan else ts);

  builtinUrl = r: "${r.scheme or "http"}://127.0.0.1:${toString r.port}";

  defaultMode = r:
    if role == "brain" then (if r.builtin then "builtin" else if r.live then "link" else "off")
    else if lib.elem role [ "desktop" "laptop" "kiosk" ] then (if r.live then "link" else "off")
    else "off";

  on = lib.filterAttrs (_: m: m.mode != "off") cfg;
  envName = n: "ALIS_${lib.toUpper n}_URL";

  launchers = lib.mapAttrsToList (n: m: pkgs.makeDesktopItem {
    name = "alis-${n}";
    desktopName = "ALIS · ${m.title}";
    comment = m.about;
    exec = "${pkgs.chromium}/bin/chromium --app=${m.effectiveUrl} --class=alis-${n} --password-store=basic";
    icon = "${pkgs.callPackage ../artwork { }}/logo.png";
    categories = [ "Utility" ];
    startupWMClass = "alis-${n}";
  }) (lib.filterAttrs (n: m: m.ui && n != "nest") on); # NEST already has the "ALIS Dashboard" app
in
{
  options.alis.network = lib.mkOption {
    type = lib.types.enum [ "lan" "tailscale" ];
    default = if role == "laptop" then "tailscale" else "lan";
    description = "How linked modules are reached: home network addresses, or Tailscale (works away from home).";
  };

  options.alis.modules = lib.mapAttrs (n: r: {
    mode = lib.mkOption {
      type = lib.types.enum [ "builtin" "link" "off" ];
      default = defaultMode r;
      description = "${r.title}: run it here (builtin), use an existing one (link), or off.";
    };
    url = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = defaultUrl n r;
      description = "Address of the existing ${r.title} (for link mode).";
    };
    effectiveUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      readOnly = true;
      default = if cfg.${n}.mode == "builtin" then builtinUrl r else cfg.${n}.url;
      description = "Where this machine finds ${r.title}.";
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
      builtins.toJSON (lib.mapAttrs (_: m: { inherit (m) mode; url = m.effectiveUrl; }) on);
    environment.variables = lib.mapAttrs' (n: m: lib.nameValuePair (envName n) m.effectiveUrl) on;
    alis.appsEnvironment = lib.mapAttrs' (n: m: lib.nameValuePair (envName n) m.effectiveUrl) on;

    environment.systemPackages = lib.optionals (lib.elem role [ "desktop" "laptop" ]) launchers;
  };
}
