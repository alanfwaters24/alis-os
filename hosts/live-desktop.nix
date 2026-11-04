# Live test image of the DESKTOP role (office PC / laptops): boots into the
# ALIS-themed KDE desktop, logged in as a test user. Nothing touches the disk.
{ lib, pkgs, modulesPath, ... }:
let
  artwork = pkgs.callPackage ../artwork { };
in
{
  imports = [
    (modulesPath + "/installer/cd-dvd/iso-image.nix")
    (modulesPath + "/profiles/all-hardware.nix")
  ];

  alis.role = "desktop";
  networking.hostName = "alis-desktop-test";
  system.stateVersion = "26.05";

  users.users.alan.initialPassword = "alis";
  services.displayManager.autoLogin = { enable = true; user = "alan"; };

  image.baseName = lib.mkForce "alis-os-desktop-test";
  isoImage = {
    volumeID = "ALIS_OS_DESKTOP";
    makeEfiBootable = true;
    makeUsbBootable = true;
    splashImage = "${artwork}/splash-640x480.png";
    efiSplashImage = "${artwork}/splash.png";
    prependToMenuLabel = "A.L.I.S OS Desktop ";
  };
}
