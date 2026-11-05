# Machines

One folder per real ALIS OS machine. The folder name is what you pick in the
installer and what you rebuild with:

    sudo nixos-rebuild switch --flake /etc/alis-os#spare-laptop

- `default.nix` — the role and anything special about this machine.
- `hardware-configuration.nix` — written by the installer for that exact
  hardware. Copy it back into this repo after installing (the installer
  prints how).

To add a machine: copy `spare-laptop/` to a new folder name and change the
role/hostname, or pick "new machine" in the installer.
