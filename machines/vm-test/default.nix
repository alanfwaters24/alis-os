# Used only to test the installer in a virtual machine (tests/installer.sh).
# A small server so the whole system fits on the installer image offline.
{ lib, ... }:
{
  imports = lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

  alis.role = "server";
  networking.hostName = "alis-vm-test";
  system.stateVersion = "26.05";
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_blk" "virtio_scsi" "ahci" "sd_mod" ];
}
