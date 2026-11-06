# Shared settings for a real, installed ALIS OS machine (machines/<name>/).
#
# The ALIS installer formats disks the same way every time, by label:
#   ALIS-BOOT  (1 GB, FAT32)  → /boot
#   alis-root  (rest, ext4)   → /
# so a machine's config doesn't need disk IDs. The installer also writes
# machines/<name>/hardware-configuration.nix (drivers for that hardware).
{ lib, ... }:
{
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.systemd-boot.configurationLimit = lib.mkDefault 10; # last 10 versions in the boot menu
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  fileSystems."/" = lib.mkDefault { device = "/dev/disk/by-label/alis-root"; fsType = "ext4"; };
  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/ALIS-BOOT";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };
  swapDevices = lib.mkDefault [{ device = "/var/swapfile"; size = 4096; }];

  # Installed machines look after themselves (modules/updates.nix, backup.nix).
  alis.updates.enable = lib.mkDefault true;
  alis.backup.enable = lib.mkDefault true;
}
