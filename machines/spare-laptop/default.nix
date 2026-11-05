# A spare / repurposed laptop — the first real ALIS OS install.
{ lib, ... }:
{
  imports = lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

  alis.role = "laptop";
  networking.hostName = "alis-laptop";
  system.stateVersion = "26.05";

  # Example: a personal NAS share as well as stash.
  # alis.nas.shares = { stash = { }; alan = { mount = false; }; };
}
