# Office PC (conservatory): Asus ROG Strix Z590-E, i7-11700K, RX 6700 XT, 32 GB.
# Dual-boots with Windows 11, which has its own drive. ALIS OS replaces Ubuntu on
# its own 120 GB NVMe (ex-Surface Pro 4 M.2 2230); pick that disk ("has Linux")
# in the installer. At power-on the ALIS boot picker (modules/boot-picker.nix)
# shows big ALIS OS / Windows tiles; the F8 boot menu still works too.
{ lib, ... }:
{
  imports = lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

  alis.role = "desktop";
  networking.hostName = "alis-office";
  system.stateVersion = "26.05";

  # ALIS OS / Windows picker at power-on (kids pick Windows to game).
  # Starts the last one used after 30 s; change with `sudo alis-boot-picker`.
  alis.bootPicker.enable = true;

  # Not left on 24/7 (ALIS-CORE: electricity cost), so nothing always-on here.
}
