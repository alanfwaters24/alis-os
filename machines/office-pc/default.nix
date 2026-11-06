# Office PC (conservatory): Asus ROG Strix Z590-E, i7-11700K, RX 6700 XT, 32 GB.
# Dual-boots with Windows 11, which has its own drive. ALIS OS replaces Ubuntu on
# its own 120 GB NVMe (ex-Surface Pro 4 M.2 2230); pick that disk ("has Linux")
# in the installer. Windows is chosen from the PC's boot menu (F8), as before.
{ lib, ... }:
{
  imports = lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

  alis.role = "desktop";
  networking.hostName = "alis-office";
  system.stateVersion = "26.05";

  # Not left on 24/7 (ALIS-CORE: electricity cost), so nothing always-on here.
}
