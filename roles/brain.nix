# Brain role — the ALIS Brain (today: the Brain VM + the live apps on
# dev-automation, on one machine). A server (see server.nix) that runs every
# module ALIS OS can build in, and links to the rest:
#
#   homeassistant  Home Assistant + Matter     :8123
#   voice          Whisper :10300 · Piper :10200 · openWakeWord :10400 (Wyoming)
#   ollama         Local AI                    :11434
#   nest           NEST / alis-live + shared brain (/api/brain)   :8080 / :8443
#   push           alis-push                   :8091 · TS 10001
#   glance         GLANCE                      :3512 · TS 10006
#
# Already have one of these? Link to it instead, e.g.
#   alis.modules.homeassistant.mode = "link";        # uses 192.168.1.251:8123
#   alis.modules.voice = { mode = "link"; url = "tcp://192.168.1.251:10200"; };
#
# The recipes below also work on a server-role machine: set a module's mode
# to "builtin" there and it runs.
{ config, lib, pkgs, ... }:
let
  cfg = config.alis.brain;
  m = config.alis.modules;
  here = name: m.${name}.mode == "builtin";
  python = pkgs.python3;
in
{
  options.alis.brain = {
    sources = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "Module repos (filled in by flake.nix from its inputs).";
    };
    whisperModel = lib.mkOption { type = lib.types.str; default = "small-int8"; description = "Bigger = more accurate, slower on CPU."; };
    piperVoice = lib.mkOption { type = lib.types.str; default = "en_GB-southern_english_female-low"; description = "Current ALIS voice (ports_and_env.json)."; };
    ollamaModels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "minicpm-v" "llava" ];
      description = "Models downloaded on first start (several GB each — none by default).";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (here "voice") {
      services.wyoming.faster-whisper.servers.alis = {
        enable = true;
        uri = "tcp://0.0.0.0:10300";
        model = cfg.whisperModel;
        language = "en";
      };
      services.wyoming.piper.servers.alis = {
        enable = true;
        uri = "tcp://0.0.0.0:10200";
        voice = cfg.piperVoice;
      };
      services.wyoming.openwakeword = {
        enable = true;
        uri = "tcp://0.0.0.0:10400";
      };
      networking.firewall.allowedTCPPorts = [ 10200 10300 10400 ];
    })

    (lib.mkIf (here "ollama") {
      services.ollama = {
        enable = true;
        host = "0.0.0.0";
        port = 11434;
        loadModels = cfg.ollamaModels;
      };
      networking.firewall.allowedTCPPorts = [ 11434 ];
    })

    # NEST (alis-live): stdlib-only Python. Its config.json (HA token etc.)
    # is placed by hand in /var/lib/alis/live/ — never taken from git.
    (lib.mkIf (here "nest") {
      alis.apps.live = {
        enable = true;
        description = "ALIS NEST dashboard + shared brain (alis-live)";
        src = cfg.sources.alis-live;
        port = 8080;
        extraPorts = [ 8443 ];
        command = "${python}/bin/python3 server.py";
        openFirewall = true;
      };
    })

    (lib.mkIf (here "push") {
      alis.apps.push = {
        enable = true;
        description = "ALIS push notifications (alis-push)";
        src = cfg.sources.alis-push;
        port = 8091;
        tailscalePort = 10001;
        environment.ALIS_PUSH_PORT = "8091";
        command = "${python.withPackages (ps: with ps; [ pywebpush py-vapid cryptography google-auth requests ])}/bin/python3 server.py";
      };
    })

    (lib.mkIf (here "glance") {
      alis.apps.glance = {
        enable = true;
        description = "GLANCE daily brief";
        src = cfg.sources.glance;
        port = 3512;
        tailscalePort = 10006;
        environment.ALIS_GLANCE_PORT = "3512";
        command = "${python}/bin/python3 server.py";
      };
    })
  ];
}
