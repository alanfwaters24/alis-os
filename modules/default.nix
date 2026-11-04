# ALIS OS — everything ALIS adds on top of NixOS.
#
# A machine picks ONE role and the rest follows:
#
#   alis.role = "kiosk";    # wall / fridge tablets — boots straight into the dashboard
#   alis.role = "desktop";  # office PC — full ALIS desktop with the dashboard as home screen
#   alis.role = "laptop";   # spare laptops — desktop + battery / Wi-Fi / Bluetooth
#   alis.role = "server";   # mini PC / VMs — no screen, runs ALIS modules as services
{ lib, ... }:
{
  imports = [
    ./base.nix
    ./branding.nix
    ./dashboard.nix
    ./apps.nix
    ./home-assistant.nix
    ../roles/kiosk.nix
    ../roles/desktop.nix
    ../roles/laptop.nix
    ../roles/server.nix
  ];

  options.alis.role = lib.mkOption {
    type = lib.types.enum [ "kiosk" "desktop" "laptop" "server" ];
    description = "What kind of ALIS machine this is.";
  };
}
