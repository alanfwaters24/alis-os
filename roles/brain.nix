# Brain role — the ALIS Brain (today: the Brain VM + the live apps on
# dev-automation, on one machine). A server (see server.nix) plus:
#
#   Home Assistant + Matter        :8123
#   Voice — Whisper (speech→text)  :10300   Wyoming
#           Piper   (text→speech)  :10200   Wyoming
#           openWakeWord ("Hey ALIS") :10400 Wyoming
#   Ollama (local AI)              :11434
#   NEST / alis-live + shared brain (/api/brain)   :8080 / :8443
#   alis-push (notifications)      :8091   · TS 10001
#   GLANCE (daily brief)           :3512   · TS 10006
#
# Ports match alis-core/ports_and_env.json. Every piece can be switched off
# on its own, e.g.  alis.brain.ollama.enable = false;
{ config, lib, pkgs, ... }:
let
  cfg = config.alis.brain;
  isBrain = config.alis.role == "brain";
  python = pkgs.python3;
in
{
  options.alis.brain = {
    sources = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "Module repos (filled in by flake.nix from its inputs).";
    };

    voice = {
      enable = lib.mkOption { type = lib.types.bool; default = true; description = "Whisper + Piper + openWakeWord."; };
      whisperModel = lib.mkOption { type = lib.types.str; default = "small-int8"; description = "Bigger = more accurate, slower on CPU."; };
      piperVoice = lib.mkOption { type = lib.types.str; default = "en_GB-southern_english_female-low"; description = "Current ALIS voice (ports_and_env.json)."; };
    };

    ollama = {
      enable = lib.mkOption { type = lib.types.bool; default = true; };
      models = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "minicpm-v" "llava" ];
        description = "Models downloaded on first start (several GB each — off by default).";
      };
    };

    nest.enable = lib.mkOption { type = lib.types.bool; default = true; description = "NEST dashboard server (alis-live) incl. the shared ALIS brain."; };
    push.enable = lib.mkOption { type = lib.types.bool; default = true; description = "alis-push notification server."; };
    glance.enable = lib.mkOption { type = lib.types.bool; default = true; description = "GLANCE daily brief."; };
  };

  config = lib.mkIf isBrain (lib.mkMerge [
    # Runs its own HA unless pointed at an existing one (alis.homeAssistant.url).
    { alis.homeAssistant.enable = lib.mkDefault (config.alis.homeAssistant.url == null); }

    (lib.mkIf cfg.voice.enable {
      services.wyoming.faster-whisper.servers.alis = {
        enable = true;
        uri = "tcp://0.0.0.0:10300";
        model = cfg.voice.whisperModel;
        language = "en";
      };
      services.wyoming.piper.servers.alis = {
        enable = true;
        uri = "tcp://0.0.0.0:10200";
        voice = cfg.voice.piperVoice;
      };
      services.wyoming.openwakeword = {
        enable = true;
        uri = "tcp://0.0.0.0:10400";
      };
      networking.firewall.allowedTCPPorts = [ 10200 10300 10400 ];
    })

    (lib.mkIf cfg.ollama.enable {
      services.ollama = {
        enable = true;
        host = "0.0.0.0";
        port = 11434;
        loadModels = cfg.ollama.models;
      };
      networking.firewall.allowedTCPPorts = [ 11434 ];
    })

    # NEST (alis-live): stdlib-only Python. Its config.json (HA token etc.)
    # is placed by hand in /var/lib/alis/live/ — never taken from git.
    (lib.mkIf cfg.nest.enable {
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

    (lib.mkIf cfg.push.enable {
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

    (lib.mkIf cfg.glance.enable {
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
  ]);
}
