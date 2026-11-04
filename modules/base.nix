# What every ALIS machine gets, whatever its role.
{ lib, pkgs, ... }:
{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  # Old system versions pile up otherwise; keep two weeks for rollback.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # UK household (Stowmarket).
  time.timeZone = lib.mkDefault "Europe/London";
  i18n.defaultLocale = lib.mkDefault "en_GB.UTF-8";
  console.keyMap = lib.mkDefault "uk";
  services.xserver.xkb.layout = lib.mkDefault "gb";

  # Remote access: SSH on the LAN, Tailscale for everywhere else.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = lib.mkDefault false;
  };
  services.tailscale.enable = true;

  # NetworkManager handles wired + Wi-Fi on every role.
  networking.networkmanager.enable = true;

  users.users.alan = {
    isNormalUser = true;
    description = "Alan";
    extraGroups = [ "wheel" "networkmanager" ];
  };

  environment.systemPackages = with pkgs; [ git vim gh curl htop ];

  # Plain-English motd when you SSH in.
  users.motd = ''

      A.L.I.S OS — part of the ALIS ecosystem
      Change this machine: edit the alis-os repo, then
        sudo nixos-rebuild switch --flake github:alanfwaters24/alis-os#<host>

  '';
}
