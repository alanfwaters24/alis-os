# Makes the machine say "ALIS OS" everywhere it would say "NixOS":
# boot splash, os-release, console colours.
{ lib, pkgs, ... }:
let
  artwork = pkgs.callPackage ../artwork { };
in
{
  # Shows up in /etc/os-release, the boot menu, `hostnamectl` etc.
  system.nixos.distroName = "ALIS OS";
  system.nixos.distroId = "alis";

  # Graphical boot splash with the ALIS emblem instead of scrolling text.
  boot.plymouth = {
    enable = true;
    theme = "spinner";
    logo = "${artwork}/logo.png";
  };
  boot.consoleLogLevel = lib.mkDefault 3;
  boot.initrd.verbose = lib.mkDefault false;
  boot.kernelParams = [ "quiet" "splash" "udev.log_level=3" ];

  # ALIS Glass colours on the text console too (16 colours, no '#').
  console.colors = map (lib.removePrefix "#") [
    "05100D" "F87171" "2DD4BF" "FBBF24" "22D3EE" "A78BFA" "5EEAD4" "8A9A96"
    "3A4A46" "F87171" "5EEAD4" "FBBF24" "22D3EE" "C4B5FD" "5EEAD4" "E8F5F0"
  ];

  environment.etc."alis/artwork".source = artwork;
}
