# Secure Boot for ALIS OS, so Windows games that need it (e.g. Fortnite
# tournaments) work on a PC that dual-boots ALIS.
#
#   alis.secureBoot.enable = true;      # machines/<name>/default.nix
#
# How it works: Lanzaboote (nix-community) signs ALIS's boot files with this
# PC's own Secure Boot key, made on the PC (/var/lib/sbctl, never in git).
# That key is added to the firmware's list *next to* Microsoft's keys, so
# Windows, the graphics card and other add-in cards stay trusted and Windows
# sees Secure Boot as on. The ALIS boot picker is signed with the same key.
#
# One-time setup (see README "Secure Boot"):
#   1. rebuild with this on, restart          (ALIS now boots signed files)
#   2. BIOS: Secure Boot → Key Management → Clear Secure Boot keys ("Setup Mode")
#   3. in ALIS:  sudo alis-secure-boot enroll  (adds this PC's key + Microsoft's)
#   4. restart: Secure Boot is on for both ALIS and Windows
# Way back at any time: BIOS → Key Management → Install default Secure Boot keys.
#
#   alis-secure-boot            # status: Secure Boot on/off, setup mode, files signed?
#   sudo alis-secure-boot sign  # (re)sign everything now
{ config, lib, pkgs, ... }:
let
  cfg = config.alis.secureBoot;
  pki = "/var/lib/sbctl";

  command = pkgs.writeShellScriptBin "alis-secure-boot" ''
    export PATH=${lib.makeBinPath (with pkgs; [ sbctl coreutils gnugrep systemd ])}:$PATH
    need_root() { [ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo alis-secure-boot $1" >&2; exit 1; }; }

    sign_all() {
      [ -e ${pki}/keys/db/db.key ] || { echo "Making this PC's Secure Boot keys..."; sbctl create-keys || exit 1; }
      echo "Signing ALIS's boot files..."
      /run/current-system/bin/switch-to-configuration boot || exit 1
      systemctl restart alis-boot-picker.service 2>/dev/null || true
      echo
      sbctl verify 2>&1 | grep -E "EFI/(systemd|Linux|alis-picker|nixos|BOOT)" || sbctl verify
    }

    case "''${1:-status}" in
      status)
        sbctl status
        echo
        [ "$(id -u)" = 0 ] && sbctl verify 2>&1 | grep -E "EFI/(systemd|Linux|alis-picker|nixos|BOOT)" \
          || echo "(run 'sudo alis-secure-boot' to also check every ALIS boot file is signed)" ;;
      sign)
        need_root sign; sign_all ;;
      enroll)
        need_root enroll
        if ! sbctl status 2>/dev/null | grep -qi "setup mode:.*enabled"; then
          echo "The PC isn't in Setup Mode yet." >&2
          echo "Restart into the BIOS: Secure Boot → Key Management → Clear Secure Boot keys," >&2
          echo "save and exit, start ALIS OS, then run this again." >&2
          exit 1
        fi
        sign_all
        echo
        echo "Adding this PC's key together with Microsoft's keys (Windows, graphics card)..."
        sbctl enroll-keys --microsoft || exit 1
        echo
        echo "Done. Restart: Secure Boot is now on for ALIS OS and Windows."
        echo "If the BIOS shows Secure Boot as 'Disabled', turn it on there (Secure Boot → Enabled)." ;;
      *) echo "Use: alis-secure-boot [status|sign|enroll]" >&2; exit 1 ;;
    esac
  '';
in
{
  options.alis.secureBoot.enable = lib.mkEnableOption "Secure Boot: ALIS's boot files signed with this PC's own key (Lanzaboote)";

  config = lib.mkIf cfg.enable {
    # Lanzaboote takes over from plain systemd-boot: same boot menu, signed.
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.lanzaboote = {
      enable = true;
      pkiBundle = pki;
      # Keys are made on first start if missing (until then files go on unsigned,
      # which only matters once Secure Boot is switched on).
      autoGenerateKeys.enable = true;
    };
    environment.systemPackages = [ pkgs.sbctl command ];
  };
}
