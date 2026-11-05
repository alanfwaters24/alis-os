# The ALIS OS installer USB. Boots to a text screen and starts the guided
# installer (installer/alis-install.sh) automatically.
{ config, lib, pkgs, modulesPath, alisFlake, alisInputs, preinstalled ? [ ], ... }:
let
  artwork = pkgs.callPackage ../artwork { };
  alis-install = pkgs.writeShellApplication {
    name = "alis-install";
    runtimeInputs = with pkgs; [ parted dosfstools e2fsprogs util-linux curl gawk gnugrep gnused coreutils
      nixos-install-tools
      config.nix.package networkmanager ];
    text = builtins.readFile ../installer/alis-install.sh;
    checkPhase = "";
  };
in
{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  # Branding only — the installer itself isn't an ALIS "role" machine.
  system.nixos.distroName = "ALIS OS";
  console.keyMap = "uk";
  console.colors = map (lib.removePrefix "#") [
    "05100D" "F87171" "2DD4BF" "FBBF24" "22D3EE" "A78BFA" "5EEAD4" "8A9A96"
    "3A4A46" "F87171" "5EEAD4" "FBBF24" "22D3EE" "C4B5FD" "5EEAD4" "E8F5F0"
  ];
  networking.hostName = "alis-installer";
  boot.zfs.forceImportRoot = false;
  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = [ alis-install pkgs.git ];
  environment.etc."alis-os".source = alisFlake;

  # Software already on the USB (lets the VM test install with no internet).
  isoImage.storeContents = preinstalled;
  # The exact source versions flake.lock pins, kept on the USB so the
  # recipe can be worked out with no internet.
  system.extraDependencies = map (p: p.outPath) (lib.attrValues alisInputs);

  # Start the installer on the first screen.
  programs.bash.interactiveShellInit = ''
    if [ "$(tty)" = /dev/tty1 ] && [ -z "''${ALIS_NO_AUTOSTART:-}" ] && [ ! -e /tmp/.alis-install-started ]; then
      touch /tmp/.alis-install-started
      sudo alis-install || true
      echo; echo "  Type 'alis-install' to start again."
    fi
  '';

  image.baseName = lib.mkForce "alis-os-installer";
  isoImage = {
    volumeID = "ALIS_OS_INSTALL";
    splashImage = "${artwork}/splash-640x480.png";
    efiSplashImage = "${artwork}/splash.png";
    prependToMenuLabel = "A.L.I.S OS installer ";
  };
}
