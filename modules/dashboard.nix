# The ALIS dashboard, baked into the OS and served locally — the same
# python3 http.server setup as alis-dashboard/install.sh, but managed by NixOS.
#
# Screens open the dashboard through `alis-open-dashboard`: it tries the
# live NEST first and, if that doesn't answer within a few seconds (VAULT/
# dev-automation down, laptop away from home), opens the built-in copy
# instead — so there's never a blank window.
{ config, lib, pkgs, ... }:
let
  cfg = config.alis.dashboard;
  localUrl = "http://localhost:${toString cfg.port}";

  # alis-open-dashboard [extra chromium flags...]
  openDashboard = pkgs.writeShellScriptBin "alis-open-dashboard" ''
    url=${lib.escapeShellArg cfg.url}
    ${lib.optionalString (cfg.url != localUrl && cfg.serveLocally) ''
      if ! ${pkgs.curl}/bin/curl -sk -o /dev/null --max-time ${toString cfg.fallbackAfter} "$url"; then
        echo "alis-open-dashboard: $url not answering, using the built-in copy" >&2
        url=${localUrl}
      fi
    ''}
    exec ${pkgs.chromium}/bin/chromium --app="$url" --password-store=basic "$@"
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
