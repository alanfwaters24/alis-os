# Stage 1 — live test image. Boots from USB / DVD / a VM straight into the
# ALIS dashboard. Nothing is installed to disk; unplug it and the machine is
# untouched. Test-only logins (alan / alis) — never use this on a real machine.
{ lib, pkgs, modulesPath, ... }:
let
  artwork = pkgs.callPackage ../artwork { };
in
{
  imports = [
    (modulesPath + "/installer/cd-dvd/iso-image.nix")
    (modulesPath + "/profiles/all-hardware.nix")
  ];

  alis.role = "kiosk";
  # Test image: show the dashboard baked into the image, not the live NEST.
  alis.modules.nest.mode = "off";
  networking.hostName = "alis-live-test";
  system.stateVersion = "26.05";

  # Live image only: known password so you can SSH in / switch tty to poke around.
  users.users.alan.initialPassword = "alis";
  services.openssh.settings.PasswordAuthentication = true;

  image.baseName = lib.mkForce "alis-os-live-test";
  isoImage = {
    volumeID = "ALIS_OS";
    makeEfiBootable = true;
    makeUsbBootable = true;
    splashImage = "${artwork}/splash-640x480.png";
    efiSplashImage = "${artwork}/splash.png";
    prependToMenuLabel = "A.L.I.S OS ";
  };

  # Settings for `nix run .#vm` (virtual machine test).
  virtualisation.vmVariant.virtualisation = {
    memorySize = 4096;
    cores = 2;
    resolution = { x = 1280; y = 800; };
  };
}
