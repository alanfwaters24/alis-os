# Home Assistant + Matter when alis.modules.homeassistant.mode = "builtin"
# (the brain role's default). Settings carried over from alis-os-home.
#
# Already have Home Assistant? Link to it instead:
#   alis.modules.homeassistant.mode = "link";   # → http://192.168.1.251:8123
# NEST (alis-live) reads `ha_url` from its own config.json, which already
# defaults to http://192.168.1.251:8123.
{ config, lib, ... }:
{
  config = lib.mkIf (config.alis.modules.homeassistant.mode == "builtin") {
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
  };
}
