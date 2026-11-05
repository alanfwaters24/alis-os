# Laptop role — spare / repurposed laptops. Everything the desktop role has
# (see desktop.nix, which switches on for "laptop" too) plus laptop care.
# Battery modes come from KDE's own power settings (power-profiles-daemon).
{ config, lib, ... }:
{
  config = lib.mkIf (config.alis.role == "laptop") {
    services.power-profiles-daemon.enable = true;
    services.logind.settings.Login.HandleLidSwitch = "suspend";
    services.fwupd.enable = true; # firmware updates via Discover

    # Compressed memory: squeezes what's in RAM so a 4 GB laptop behaves more
    # like ~6 GB (small CPU cost). Used before the slower swap file on disk.
    zramSwap = {
      enable = lib.mkDefault true;
      memoryPercent = lib.mkDefault 50;
      algorithm = lib.mkDefault "zstd";
      priority = 100;
    };
    boot.kernel.sysctl."vm.swappiness" = lib.mkDefault 150; # prefer zram over dropping app data
  };
}
