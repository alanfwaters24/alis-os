# Office PC (conservatory): Asus ROG Strix Z590-E, i7-11700K, RX 6700 XT, 32 GB.
# Dual-boots with Windows 11: ALIS OS replaces Ubuntu, Windows stays (decided
# 5 Nov 2026). Installed with the installer's "keep Windows" mode (Stage 2b,
# not built yet — don't install with the whole-disk mode on this machine).
{ lib, ... }:
{
  imports = lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

  alis.role = "desktop";
  networking.hostName = "alis-office";
  system.stateVersion = "26.05";

  # Not left on 24/7 (ALIS-CORE: electricity cost), so nothing always-on here.
}
