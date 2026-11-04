# Laptop role — spare / repurposed laptops. Everything the desktop role has
# (see desktop.nix, which switches on for "laptop" too) plus laptop care.
# Battery modes come from KDE's own power settings (power-profiles-daemon).
{ config, lib, ... }:
{
  config = lib.mkIf (config.alis.role == "laptop") {
    services.power-profiles-daemon.enable = true;
    services.logind.settings.Login.HandleLidSwitch = "suspend";
    services.fwupd.enable = true; # firmware updates via Discover
  };
}
