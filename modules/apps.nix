# The shared ALIS service template (deployment standard, 21 Oct 2026):
# every ALIS module runs as a systemd service from ONE template, keeps its
# data locally, and gets its own port. Declare a module like this:
#
#   alis.apps.glance = {
#     enable = true;
#     src = inputs.glance;                       # the module's repo
#     port = 3512;
#     tailscalePort = 10006;                     # optional: tailscale serve --https=10006
#     command = "${pkgs.python3}/bin/python3 server.py";
#   };
#
# How existing apps run unchanged: most ALIS modules keep their data next to
# their code (data/, config.json...). So the repo's files are LINKED into the
# module's folder in /var/lib/alis/<name>, and the app runs from there. Data
# files the app writes are real files in that folder and survive updates;
# code files are links that move to the new version on every rebuild.
#
# Two modules on the same port is a BUILD error here — so the STALL /
# alis-speak 3513 clash can't happen on an ALIS OS machine.
{ config, lib, pkgs, ... }:
let
  enabledApps = lib.filterAttrs (_: a: a.enable) config.alis.apps;

  portUsers =
    lib.concatLists (lib.mapAttrsToList (n: a:
      map (p: { name = n; port = p; }) ([ a.port ] ++ a.extraPorts)
      ++ lib.optional (a.tailscalePort != null) { name = "${n} (tailscale)"; port = a.tailscalePort; }
    ) enabledApps)
    ++ lib.optional config.alis.dashboard.serveLocally { name = "bundled dashboard"; port = config.alis.dashboard.port; };
  byPort = lib.groupBy (u: toString u.port) portUsers;
  clashes = lib.filterAttrs (_: us: lib.length us > 1) byPort;

  # Link every top-level entry of the repo into the working folder, without
  # ever replacing a real file the app (or Alan) put there.
  linkSrc = a: pkgs.writeShellScript "alis-link-${a.name}" ''
    set -eu
    cd ${lib.escapeShellArg a.workingDirectory}
    for f in ${a.src}/* ${a.src}/.[!.]*; do
      [ -e "$f" ] || continue
      dest=$(basename "$f")
      case " ${lib.concatStringsSep " " a.keepOut} " in *" $dest "*) continue ;; esac
      if [ -L "$dest" ] || [ ! -e "$dest" ]; then ln -sfn "$f" "$dest"; fi
    done
    # Tidy links to files that no longer exist in the new version.
    find . -maxdepth 1 -xtype l -delete
  '';
in
{
  options.alis.apps = lib.mkOption {
    default = { };
    description = "ALIS modules (NEST, GLANCE, alis-push...) run as systemd services.";
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      options = {
        enable = lib.mkEnableOption "the ALIS module ${name}";
        name = lib.mkOption { type = lib.types.str; default = name; readOnly = true; };
        description = lib.mkOption { type = lib.types.str; default = "ALIS module ${lib.toUpper name}"; };
        src = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "The module's code (usually a flake input). Linked into workingDirectory.";
        };
        keepOut = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "config.json" ".env" "data" "cert.pem" "key.pem" ];
          description = "Repo files never linked in — local settings/secrets/data stay machine-only.";
        };
        port = lib.mkOption { type = lib.types.port; description = "Main local listen port."; };
        extraPorts = lib.mkOption { type = lib.types.listOf lib.types.port; default = [ ]; };
        tailscalePort = lib.mkOption {
          type = lib.types.nullOr lib.types.port;
          default = null;
          description = "Publish the module on the tailnet with `tailscale serve --https=<this>`.";
        };
        command = lib.mkOption { type = lib.types.str; description = "Command that starts the module (run inside workingDirectory)."; };
        workingDirectory = lib.mkOption { type = lib.types.str; default = "/var/lib/alis/${name}"; };
        environment = lib.mkOption { type = lib.types.attrsOf lib.types.str; default = { }; };
        openFirewall = lib.mkOption { type = lib.types.bool; default = false; };
      };
    }));
  };

  config = {
    assertions = lib.mapAttrsToList (port: us: {
      assertion = false;
      message = "ALIS port clash: ${lib.concatMapStringsSep " and " (u: u.name) us} both want port ${port}. Check alis-core/ports_and_env.json.";
    }) clashes;

    users.groups.alis = { };
    users.users.alis-apps = { isSystemUser = true; group = "alis"; };

    systemd.tmpfiles.rules = lib.mapAttrsToList
      (_: a: "d ${a.workingDirectory} 0750 alis-apps alis - -") enabledApps;

    systemd.services = lib.mapAttrs' (n: a: lib.nameValuePair "alis-${n}" {
      description = a.description;
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment = { PORT = toString a.port; } // a.environment;
      serviceConfig = {
        ExecStartPre = lib.optional (a.src != null) "${linkSrc a}";
        ExecStart = "${pkgs.bash}/bin/bash -c ${lib.escapeShellArg "exec ${a.command}"}";
        WorkingDirectory = a.workingDirectory;
        User = "alis-apps";
        Group = "alis";
        Restart = "always";
        RestartSec = 5;
      };
    }) enabledApps
    // lib.mapAttrs' (n: a: lib.nameValuePair "alis-${n}-tailscale" {
      description = "Publish ALIS module ${n} on Tailscale port ${toString a.tailscalePort}";
      wantedBy = [ "multi-user.target" ];
      after = [ "tailscaled.service" "alis-${n}.service" ];
      wants = [ "tailscaled.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${config.services.tailscale.package}/bin/tailscale serve --bg --https=${toString a.tailscalePort} http://127.0.0.1:${toString a.port}";
        Restart = "on-failure";
        RestartSec = 30;
      };
    }) (lib.filterAttrs (_: a: a.tailscalePort != null) enabledApps);

    networking.firewall.allowedTCPPorts = lib.concatLists (lib.mapAttrsToList
      (_: a: lib.optionals a.openFirewall ([ a.port ] ++ a.extraPorts))
      enabledApps);
  };
}
