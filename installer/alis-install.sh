#!/usr/bin/env bash
# ALIS OS installer — run from the ALIS installer USB.
#
#   alis-install
#
# Asks which machine this is and which disk to use, ERASES that disk, and
# installs ALIS OS on it. Nothing is changed until you type ERASE.
#
# Can be driven without questions (used by the VM test):
#   ALIS_MACHINE=vm-test ALIS_DISK=/dev/vda ALIS_CONFIRM=ERASE ALIS_PASSWORD=... alis-install
set -euo pipefail

FLAKE_SRC=/etc/alis-os            # this repo, as it was when the USB was built
NIX=(nix --extra-experimental-features "nix-command flakes")

teal=$'\e[38;2;45;212;191m'; violet=$'\e[38;2;167;139;250m'; dim=$'\e[38;2;138;154;150m'
red=$'\e[38;2;248;113;113m'; bold=$'\e[1m'; off=$'\e[0m'

say()  { printf '%s\n' "$*"; }
step() { printf '\n%s%s▸ %s%s\n' "$teal" "$bold" "$*" "$off"; }
warn() { printf '%s%s%s\n' "$red" "$*" "$off"; }
die()  { warn "  [x] $*"; exit 1; }
ask()  { # ask VAR "question" [default]
  local __var=$1 __q=$2 __def=${3:-} __ans
  if [ -n "${!__var:-}" ]; then return; fi
  read -r -p "  $__q${__def:+ [$__def]}: " __ans </dev/tty
  printf -v "$__var" '%s' "${__ans:-$__def}"
}

[ "$(id -u)" = 0 ] || exec sudo -E "$0" "$@"
pick="" dpick="" NEW_ROLE="" NEW_MACHINE=0

clear || true
printf '%s%s' "$teal" "$bold"
cat <<'BANNER'

        ╭───────────────────────────╮
        │        A . L . I . S      │
        │     ALIS OS installer     │
        ╰───────────────────────────╯
BANNER
printf '%s\n' "$off"
say "  ${dim}This puts ALIS OS on this computer. It takes 10–30 minutes.${off}"

# ---- 1. Checks -------------------------------------------------------------
step "1/6  Checking this computer"
[ -d /sys/firmware/efi ] || die "This computer started in old 'BIOS/Legacy' mode. Turn on UEFI in its firmware settings and boot the USB again."
say "  [ok] UEFI start-up"
if curl -s -o /dev/null --max-time 8 https://cache.nixos.org/nix-cache-info; then
  say "  [ok] Internet connection"
  ONLINE=1
else
  ONLINE=0
  if [ -z "${ALIS_MACHINE:-}" ]; then
    warn "  No internet. Plug in a network cable, or connect to Wi-Fi now."
    read -r -p "  Open the Wi-Fi menu? [Y/n]: " w </dev/tty
    [ "${w:-y}" = n ] || nmtui connect || true
    curl -s -o /dev/null --max-time 8 https://cache.nixos.org/nix-cache-info && ONLINE=1
  fi
  [ "$ONLINE" = 1 ] && say "  [ok] Internet connection" || say "  ${dim}! Still offline — only works for machines whose software is already on this USB.${off}"
fi

# ---- 2. Which machine ------------------------------------------------------
step "2/6  Which machine is this?"
mapfile -t machines < <(cd "$FLAKE_SRC/machines" && for d in */; do d=${d%/}; [ "$d" = vm-test ] && [ -z "${ALIS_MACHINE:-}" ] && continue; echo "$d"; done)
if [ -z "${ALIS_MACHINE:-}" ]; then
  i=1
  for m in "${machines[@]}"; do
    role=$(grep -o 'alis.role = "[a-z]*"' "$FLAKE_SRC/machines/$m/default.nix" | cut -d'"' -f2 || true)
    printf '   %s%d)%s %-20s %s%s%s\n' "$violet" "$i" "$off" "$m" "$dim" "$role" "$off"
    i=$((i + 1))
  done
  printf '   %s%d)%s %s\n' "$violet" "$i" "$off" "A new machine"
  ask pick "Number"
  if [ "$pick" = "$i" ]; then
    ask ALIS_MACHINE "Short name for it (e.g. katie-laptop)"
    [[ "$ALIS_MACHINE" =~ ^[a-z0-9-]+$ ]] || die "Use lower-case letters, numbers and dashes only."
    say "   Roles: laptop · desktop · kiosk · server · brain"
    ask NEW_ROLE "Role" "laptop"
    NEW_MACHINE=1
  else
    ALIS_MACHINE=${machines[$((pick - 1))]:-}
  fi
fi
[ -n "${ALIS_MACHINE:-}" ] || die "No machine picked."
say "  [ok] ${bold}$ALIS_MACHINE${off}"

# ---- 3. Which disk ---------------------------------------------------------
step "3/6  Which disk should ALIS OS go on?"
usb=$(lsblk -no PKNAME "$(findmnt -no SOURCE /iso 2>/dev/null || echo none)" 2>/dev/null || true)
# Real disks only: no USB stick we booted from, no floppy/CD/RAM disks, nothing under 8 GB.
mapfile -t disks < <(lsblk -dpnbo NAME,TYPE,SIZE | awk '$2=="disk" && $3>=8000000000 {print $1}' \
  | grep -v -e "^/dev/${usb:-none}\$" -e '^/dev/fd' -e '^/dev/loop' -e '^/dev/sr' -e '^/dev/zram' || true)
[ "${#disks[@]}" -gt 0 ] || die "No disks found (other than the USB stick)."
if [ -z "${ALIS_DISK:-}" ]; then
  i=1
  for d in "${disks[@]}"; do
    printf '   %s%d)%s %-14s %8s  %s\n' "$violet" "$i" "$off" "$d" "$(lsblk -dno SIZE "$d")" "$(lsblk -dno MODEL "$d" | xargs)"
    lsblk -no NAME,SIZE,FSTYPE,LABEL "$d" | tail -n +2 | sed "s/^/        ${dim}/;s/\$/${off}/"
    i=$((i + 1))
  done
  ask dpick "Number"
  ALIS_DISK=${disks[$((dpick - 1))]:-}
fi
[ -b "${ALIS_DISK:-}" ] || die "That isn't a disk."

# ---- 4. Confirm ------------------------------------------------------------
step "4/6  Last check"
warn "  EVERYTHING on $ALIS_DISK ($(lsblk -dno SIZE "$ALIS_DISK" | xargs)$(m=$(lsblk -dno MODEL "$ALIS_DISK" | xargs); [ -n "$m" ] && printf ' %s' "$m")) will be deleted."
warn "  Windows, files, photos — all of it. This can't be undone."
ask ALIS_CONFIRM "Type ERASE to continue, anything else to stop"
[ "$ALIS_CONFIRM" = ERASE ] || { say "  Stopped. Nothing was changed."; exit 0; }

# ---- 5. Install ------------------------------------------------------------
step "5/6  Installing (this is the long bit)"
say "  • Preparing the disk"
umount -R /mnt 2>/dev/null || true
wipefs -af "$ALIS_DISK" >/dev/null
parted -s "$ALIS_DISK" -- mklabel gpt \
  mkpart ALIS-BOOT fat32 1MiB 1025MiB set 1 esp on \
  mkpart alis-root ext4 1025MiB 100%
udevadm settle; sleep 2
mapfile -t parts < <(lsblk -lnpo NAME,TYPE "$ALIS_DISK" | awk '$2=="part"{print $1}')
mkfs.fat -F 32 -n ALIS-BOOT "${parts[0]}" >/dev/null
mkfs.ext4 -F -q -L alis-root "${parts[1]}"
udevadm settle
mount "${parts[1]}" /mnt
mkdir -p /mnt/boot && mount -o umask=077 "${parts[0]}" /mnt/boot

say "  • Copying the ALIS OS recipe to /etc/alis-os"
mkdir -p /mnt/etc
cp -rL "$FLAKE_SRC" /mnt/etc/alis-os
chmod -R u+w /mnt/etc/alis-os
work=/mnt/etc/alis-os
mdir="$work/machines/$ALIS_MACHINE"

if [ "$NEW_MACHINE" = 1 ]; then
  mkdir -p "$mdir"
  sed -e "s/alis.role = \"laptop\"/alis.role = \"$NEW_ROLE\"/" \
      -e "s/networking.hostName = \"alis-laptop\"/networking.hostName = \"$ALIS_MACHINE\"/" \
      -e "s/^# A spare.*/# $ALIS_MACHINE — added by the ALIS installer./" \
      "$work/machines/spare-laptop/default.nix" > "$mdir/default.nix"
fi
[ -f "$mdir/default.nix" ] || die "machines/$ALIS_MACHINE/default.nix is missing."

if [ "${ALIS_SKIP_HWCONF:-0}" != 1 ]; then
  say "  • Detecting this computer's hardware"
  nixos-generate-config --root /mnt --no-filesystems --dir "$mdir" >/dev/null 2>&1
  rm -f "$mdir/configuration.nix"
fi

say "  • Building ALIS OS for $ALIS_MACHINE (downloads ~2–6 GB)"
# flake.lock pins every source and the USB holds those exact versions, so
# working out which system this machine needs works with no internet.
target="path:$work#nixosConfigurations.$ALIS_MACHINE.config.system.build.toplevel"
system=$("${NIX[@]}" eval --raw "$target.outPath" 2> >(grep -v '^warning' >&2))
if "${NIX[@]}" path-info "$system" >/dev/null 2>&1; then
  # Already on this USB: copy it straight onto the disk.
  "${NIX[@]}" copy --no-check-sigs --to "local?root=/mnt" "$system"
else
  [ "$ONLINE" = 1 ] || die "This machine's software isn't on the USB and there's no internet. Connect to the internet and run alis-install again."
  # Build into the new disk (not the USB's memory), downloading what's needed
  # and reusing anything already on the USB.
  "${NIX[@]}" build --eval-store auto --store /mnt --no-link --extra-substituters "auto?trusted=1" "$target" \
    2> >(grep -v '^warning' >&2)
fi

say "  • Installing"
nixos-install --root /mnt --system "$system" --no-root-passwd --no-channel-copy >/dev/null

# ---- 6. Password -----------------------------------------------------------
step "6/6  Password for alan"
if [ -n "${ALIS_PASSWORD:-}" ]; then
  echo "alan:$ALIS_PASSWORD" | nixos-enter --root /mnt -c chpasswd >/dev/null 2>&1
else
  until nixos-enter --root /mnt -c "passwd alan" </dev/tty; do warn "  Try again."; done
fi

umount -R /mnt
printf '\n%s%s  [ok] ALIS OS is installed on %s as "%s".%s\n' "$teal" "$bold" "$ALIS_DISK" "$ALIS_MACHINE" "$off"
cat <<EOF

  Next:
   1. Take out the USB stick and restart.
   2. Log in as alan.
   3. Save this machine's hardware file to GitHub so it can always be
      rebuilt. On the new machine, open a terminal and run:
        gh auth login
        gh repo clone alanfwaters24/alis-os ~/alis-os
        cp -r /etc/alis-os/machines/$ALIS_MACHINE ~/alis-os/machines/
        cd ~/alis-os && git add machines/$ALIS_MACHINE
        git commit -m "Add $ALIS_MACHINE hardware" && git push

EOF
