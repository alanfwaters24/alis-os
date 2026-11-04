# The ALIS dashboard, baked into the OS and served locally — the same
# python3 http.server setup as alis-dashboard/install.sh, but managed by NixOS.
{ config, lib, pkgs, ... }:
let
  cfg = config.alis.dashboard;
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
      default = if config.alis.brain.url != null then config.alis.brain.url else "http://localhost:${toString cfg.port}";
      description = ''
        What the screen shows. Defaults to the existing Brain's NEST if
        alis.brain.url is set, otherwise the copy baked into this machine.
      '';
    };
    serveLocally = lib.mkOption {
      type = lib.types.bool;
      default = !(lib.elem config.alis.role [ "server" "brain" ]) && config.alis.brain.url == null;
      description = "Run the bundled dashboard on this machine.";
    };
  };

  config = lib.mkIf cfg.serveLocally {
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
