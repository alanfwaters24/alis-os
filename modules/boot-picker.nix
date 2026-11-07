# ALIS boot picker: a full-screen ALIS menu at power-on with one big tile per
# system (ALIS OS, Windows). For dual-boot PCs, e.g. the office PC where the
# kids pick Windows to game.
#
#   alis.bootPicker.enable = true;      # machines/<name>/default.nix
#
# It's rEFInd (a graphical boot menu) in front of ALIS's normal boot loader:
#   power on → ALIS picker → ALIS OS  (systemd-boot, as before)
#                          → Windows  (Windows Boot Manager, found on its own drive)
# Nothing on the Windows drive is changed: the picker only lives on ALIS's
# boot partition (ALIS-BOOT), and the PC's own boot menu (F8) still works.
#
# Change the wait, or turn the menu off, without a rebuild:
#   sudo alis-boot-picker 30        # wait 30 seconds, then start the last one used
#   sudo alis-boot-picker forever   # wait until someone picks
#   sudo alis-boot-picker off       # start the last one used straight away
#                                   # (hold any key at power-on to get the menu)
#   alis-boot-picker                # show the current setting
#
# Older ALIS versions: after picking ALIS OS, hold Space to see them.
#
# Tested in a UEFI virtual PC (OVMF) with an ALIS drive + a Windows-style drive:
# both tiles show, arrows + Enter start the right one. Two rEFInd 0.14.2 quirks
# handled below: `showtools` only replaces as many default buttons as it lists
# (so the list is padded with tools that don't exist here), and `enable_mouse`
# hides the keyboard highlight and made arrows + Enter start the wrong tile in
# testing, so the mouse is opt-in.
{ config, lib, pkgs, ... }:
let
  cfg = config.alis.bootPicker;
  theme = pkgs.callPackage ../artwork/boot-picker.nix { inherit (cfg) mouse; };
  refind = pkgs.refind;
  esp = config.boot.loader.efi.efiSysMountPoint;
  dir = "${esp}/EFI/alis-picker";
  conf = "${dir}/refind.conf";

  timeoutValue = t: { off = "-1"; forever = "0"; }.${toString t} or (toString t);

  # Runs after every rebuild's boot-loader install (as root, ESP mounted).
  install = pkgs.writeShellScript "alis-boot-picker-install" ''
    set -u
    export PATH=${lib.makeBinPath (with pkgs; [ coreutils util-linux efibootmgr gnugrep gnused gawk ])}
    mkdir -p ${dir}/alis ${dir}/icons ${dir}/fonts

    cp ${refind}/share/refind/refind_x64.efi ${dir}/refind_x64.efi
    cp ${refind}/share/refind/icons/func_*.png ${refind}/share/refind/icons/mouse.png ${dir}/icons/
    cp ${refind}/share/refind/fonts/ubuntu-mono-24.png ${dir}/fonts/
    cp ${theme}/*.png ${dir}/alis/
    # rEFInd finds Windows by itself and shows its icon: make that the ALIS tile.
    cp ${theme}/os_windows.png ${dir}/icons/os_win8.png
    cp ${theme}/os_windows.png ${dir}/icons/os_win.png

    # Keep the wait chosen with `alis-boot-picker`; first time, use the default.
    timeout=$(sed -n 's/^timeout //p' ${conf} 2>/dev/null)
    [ -n "$timeout" ] || timeout=${timeoutValue cfg.timeout}

    {
      echo "# Written by ALIS OS (modules/boot-picker.nix) on every rebuild."
      echo "# Change the wait with: sudo alis-boot-picker 30|forever|off"
      echo "timeout $timeout"
      echo "default_selection +"
      # Windows is found by scanning the other drives; ALIS's own boot
      # partition isn't scanned (ALIS OS is the entry below).
      echo "scanfor manual,internal"
      echo 'dont_scan_volumes "ALIS-BOOT"'
      echo "dont_scan_dirs EFI/boot,EFI/systemd,EFI/nixos,EFI/Linux"
      echo "resolution max"
      ${lib.optionalString cfg.mouse ''echo "enable_mouse"; echo "mouse_size 24"''}
      echo "showtools shutdown,reboot,gdisk,memtest,mok_tool,apple_recovery,fwupdate,netboot,gdisk,memtest,mok_tool,apple_recovery,fwupdate,netboot"
      cat ${theme}/theme.conf
      echo
      echo 'menuentry "ALIS OS" {'
      echo '  icon /EFI/alis-picker/alis/os_alis.png'
      echo '  loader /EFI/systemd/systemd-bootx64.efi'
      echo '}'
    } > ${conf}.tmp && mv ${conf}.tmp ${conf}

    # Make the picker the first thing the PC starts (re-checked every rebuild,
    # e.g. after a Windows update has put itself first again).
    own=$(findmnt -no SOURCE ${esp})
    disk=/dev/$(lsblk -no PKNAME "$own")
    part=$(lsblk -no PARTN "$own" | tr -d ' ')
    entry() { efibootmgr | awk '/ ALIS boot picker/ { sub(/^Boot/, "", $1); sub(/\*$/, "", $1); print $1; exit }'; }
    num=$(entry)
    if [ -z "$num" ]; then
      efibootmgr -q -c -d "$disk" -p "$part" -l '\EFI\alis-picker\refind_x64.efi' -L "ALIS boot picker" || exit 0
      num=$(entry)
    fi
    order=$(efibootmgr | awk '/^BootOrder:/ { print $2 }')
    case "$order" in
      "$num"|"$num",*) ;;
      *) efibootmgr -q -o "$(echo "$num,$order" | tr ',' '\n' | awk 'NF && !seen[$0]++' | paste -sd,)" ;;
    esac
    exit 0
  '';

  command = pkgs.writeShellScriptBin "alis-boot-picker" ''
    f=${conf}
    case "''${1:-}" in
      "")
        t=$(sed -n 's/^timeout //p' "$f" 2>/dev/null)
        case "$t" in
          -1) echo "Boot picker: off (starts the last one used; hold a key at power-on for the menu)" ;;
          0) echo "Boot picker: waits until someone picks" ;;
          "") echo "Boot picker: not set up on this PC (needs sudo to read, or a rebuild)" ;;
          *) echo "Boot picker: waits $t seconds, then starts the last one used" ;;
        esac
        exit 0 ;;
      off) v=-1 ;;
      forever) v=0 ;;
      *[!0-9]*) echo "Use: alis-boot-picker [SECONDS|forever|off]" >&2; exit 1 ;;
      *) v=$1 ;;
    esac
    [ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo alis-boot-picker $1" >&2; exit 1; }
    [ -e "$f" ] || { echo "The boot picker isn't installed on this PC." >&2; exit 1; }
    ${pkgs.gnused}/bin/sed -i "s/^timeout .*/timeout $v/" "$f" && sync && echo "Done." && exec "$0"
  '';
in
{
  options.alis.bootPicker = {
    enable = lib.mkEnableOption "the ALIS boot picker (graphical ALIS OS / Windows menu at power-on)";
    timeout = lib.mkOption {
      type = lib.types.either lib.types.ints.positive (lib.types.enum [ "off" "forever" ]);
      default = 30;
      description = ''
        First-time wait before starting the last system used: seconds,
        "forever" or "off". After that, change it with `sudo alis-boot-picker`.
      '';
    };
    mouse = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Mouse pointer in the picker. Off by default: in testing it hid the
        keyboard highlight and arrows + Enter could start the wrong tile.
        Some PCs' firmware has no mouse support at all.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = config.boot.loader.systemd-boot.enable;
      message = "alis.bootPicker sits in front of systemd-boot, which must stay enabled.";
    }];
    # The picker is the menu now; ALIS's own menu only shows if Space is held.
    boot.loader.timeout = lib.mkDefault 0;
    boot.loader.systemd-boot.extraInstallCommands = "${install}";
    environment.systemPackages = [ command ];
  };
}
