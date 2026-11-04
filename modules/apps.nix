# The shared ALIS service template (deployment standard, 21 Oct 2026):
# every ALIS module runs as a systemd service from ONE template, keeps its
# data locally, and gets its own port. Declare a module like this:
#
#   alis.apps.stall = {
#     enable = true;
#     port = 3514;
#     command = "${pkgs.nodejs}/bin/node server.js";
#     workingDirectory = "/srv/alis/stall";
#   };
#
# Two modules on the same port is a BUILD error here — so the STALL /
# alis-speak 3513 clash can't happen on an ALIS OS machine.
{ config, lib, ... }:
let
  enabledApps = lib.filterAttrs (_: a: a.enable) config.alis.apps;
  byPort = lib.groupBy (a: toString a.port) (lib.attrValues enabledApps);
  clashes = lib.filterAttrs (_: apps: lib.length apps > 1) byPort;
in
{
  options.alis.apps = lib.mkOption {
    default = { };
    description = "ALIS modules (FUEL, NOVA, STALL...) run as systemd services.";
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      options = {
        enable = lib.mkEnableOption "the ALIS module ${name}";
        name = lib.mkOption { type = lib.types.str; default = name; readOnly = true; };
        port = lib.mkOption { type = lib.types.port; description = "Local listen port (35xx range)."; };
        command = lib.mkOption { type = lib.types.str; description = "Command that starts the module."; };
        workingDirectory = lib.mkOption { type = lib.types.str; default = "/var/lib/alis/${name}"; };
        environment = lib.mkOption { type = lib.types.attrsOf lib.types.str; default = { }; };
        openFirewall = lib.mkOption { type = lib.types.bool; default = false; };
      };
    }));
  };

  config = {
    assertions = lib.mapAttrsToList (port: apps: {
      assertion = false;
      message = "ALIS port clash: ${lib.concatMapStringsSep " and " (a: a.name) apps} both want port ${port}. Check alis-core/ports_and_env.json.";
    }) clashes;

    users.groups.alis = { };
    users.users.alis-apps = { isSystemUser = true; group = "alis"; };

    systemd.tmpfiles.rules = lib.mapAttrsToList
      (_: a: "d ${a.workingDirectory} 0750 alis-apps alis - -") enabledApps;

    systemd.services = lib.mapAttrs' (n: a: lib.nameValuePair "alis-${n}" {
      description = "ALIS module ${lib.toUpper n}";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment = { PORT = toString a.port; } // a.environment;
      serviceConfig = {
        ExecStart = a.command;
        WorkingDirectory = a.workingDirectory;
        User = "alis-apps";
        Group = "alis";
        Restart = "always";
        RestartSec = 5;
      };
    }) enabledApps;

    networking.firewall.allowedTCPPorts =
      lib.mapAttrsToList (_: a: a.port) (lib.filterAttrs (_: a: a.openFirewall) enabledApps);
  };
}
