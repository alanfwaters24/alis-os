# Home Assistant for ALIS OS — either:
#
#   use the one you already have:   alis.homeAssistant.url = "http://192.168.1.251:8123";
#   or run one on this machine:     alis.homeAssistant.enable = true;   (brain role does this
#                                   by default, unless a url is set)
#
# The url is given to every ALIS module as ALIS_HA_URL and written to
# /etc/alis/ha-url. NEST (alis-live) still reads `ha_url` from its own
# config.json — which already defaults to http://192.168.1.251:8123.
{ config, lib, ... }:
let
  cfg = config.alis.homeAssistant;
in
{
  options.alis.homeAssistant = {
    enable = lib.mkEnableOption "Home Assistant (+ Matter server) on this machine";
    url = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "http://192.168.1.251:8123";
      description = "An existing Home Assistant to use instead of running one here.";
    };
  };

  config = lib.mkMerge [
    {
      assertions = [{
        assertion = !(cfg.enable && cfg.url != null);
        message = "alis.homeAssistant: set either `enable` (run HA here) or `url` (use an existing HA), not both.";
      }];
    }

    (lib.mkIf (cfg.url != null) {
      environment.etc."alis/ha-url".text = cfg.url;
    })

    (lib.mkIf cfg.enable {
      services.home-assistant = {
        enable = true;
        extraComponents = [ "hue" "tplink" "hive" "met" "matter" ];
        config = {
          default_config = { };
          http.server_host = "0.0.0.0";
        };
      };
      services.matter-server.enable = true;

      networking.firewall.allowedTCPPorts = [ 8123 ];
      networking.firewall.allowedUDPPorts = [ 5353 ];
    })
  ];
}
