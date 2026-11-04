# Laptop role — spare / repurposed laptops. Everything the desktop role has
# (see desktop.nix, which switches on for "laptop" too) plus battery care.
{ config, lib, ... }:
{
  config = lib.mkIf (config.alis.role == "laptop") {
    services.tlp.enable = true;
    hardware.bluetooth.enable = true;
    services.blueman.enable = true;
    services.logind.settings.Login.HandleLidSwitch = "suspend";
  };
}
