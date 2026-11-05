# The ALIS dashboard, baked into the OS and served locally — the same
# python3 http.server setup as alis-dashboard/install.sh, but managed by NixOS.
#
# Screens open the dashboard through `alis-open-dashboard`: it tries the
# live NEST first, then (laptops) NEST over Tailscale, and if neither answers
# within a few seconds opens the built-in copy — so there's never a blank window.
{ config, lib, pkgs, ... }:
let
  cfg = config.alis.dashboard;
  localUrl = "http://localhost:${toString cfg.port}";

  nest = config.alis.modules.nest;
  # Live NEST → its Tailscale address (laptops away from home) → built-in copy.
  candidates = lib.unique ([ cfg.url ]
    ++ lib.optional (cfg.url == nest.effectiveUrl && nest.fallbackUrl != null) nest.fallbackUrl
    ++ lib.optional cfg.serveLocally localUrl);
  openUrl = pkgs.callPackage ../pkgs/alis-open-url.nix { };

  # alis-open-dashboard [extra chromium flags...]
  openDashboard = pkgs.writeShellScriptBin "alis-open-dashboard" ''
    exec ${openUrl}/bin/alis-open-url --wait ${toString cfg.fallbackAfter} ${lib.escapeShellArgs candidates} -- "$@"
  '';
in
{
  options.alis.dashboard = {
    src = lib.mkOption {
      type = lib.types.path;
      description = "The alis-dashboard folder (comes from the flake input).";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Local port the bundled dashboard is served on.";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default =
        let nest = config.alis.modules.nest; in
        if nest.mode != "off" then nest.effectiveUrl else "http://localhost:${toString cfg.port}";
      description = ''
        What the screen shows: NEST (built in or linked, see alis.modules.nest),
        or the copy of alis-dashboard baked into this machine when NEST is off.
      '';
    };
    serveLocally = lib.mkOption {
      type = lib.types.bool;
      default = !(lib.elem config.alis.role [ "server" "brain" ]) && config.alis.modules.nest.mode != "builtin";
      description = "Run the built-in dashboard copy on this machine (shown when NEST is off or unreachable).";
    };
    fallbackAfter = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Seconds to wait for the live NEST before showing the built-in copy.";
    };
    localUrl = lib.mkOption { type = lib.types.str; default = localUrl; readOnly = true; };
    allUrls = lib.mkOption { type = lib.types.listOf lib.types.str; default = candidates; readOnly = true; description = "Every address the dashboard may open, in order."; };
    openCommand = lib.mkOption {
      type = lib.types.package;
      default = openDashboard;
      readOnly = true;
      description = "Opens the dashboard (live NEST, or the built-in copy as fallback).";
    };
  };

  config = lib.mkIf cfg.serveLocally {
    environment.systemPackages = [ openDashboard ];
    systemd.services.alis-dashboard = {
      description = "ALIS Dashboard (bundled copy)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 -m http.server ${toString cfg.port} --bind 127.0.0.1 --directory ${cfg.src}";
        DynamicUser = true;
        Restart = "always";
      };
    };
  };
}
