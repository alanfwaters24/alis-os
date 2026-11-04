# Home Assistant + Matter, as already set up in alis-os-home — moved here
# as an on/off switch so any ALIS server can carry it.
{ config, lib, ... }:
{
  options.alis.homeAssistant.enable = lib.mkEnableOption "Home Assistant (+ Matter server)";

  config = lib.mkIf config.alis.homeAssistant.enable {
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
