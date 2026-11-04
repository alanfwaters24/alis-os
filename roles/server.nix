# Server role — mini PC / VMs. No screen, no desktop. Runs ALIS modules
# (alis.apps.*) and optionally Home Assistant (alis.homeAssistant.enable).
{ config, lib, ... }:
{
  config = lib.mkIf (lib.elem config.alis.role [ "server" "brain" ]) {
    documentation.enable = lib.mkDefault false;
    networking.firewall.enable = true;
    # Come back up on its own after a power cut or a crash.
    systemd.settings.Manager.RuntimeWatchdogSec = lib.mkDefault "30s";
  };
}
