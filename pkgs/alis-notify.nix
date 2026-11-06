# alis-notify "Title" "Message" [icon]
# Pops a desktop notification for everyone logged in (used by the nightly
# update and backup jobs, which run as root in the background).
{ writeShellApplication, systemd, libnotify, util-linux, gawk, coreutils }:
writeShellApplication {
  name = "alis-notify";
  runtimeInputs = [ systemd libnotify util-linux gawk coreutils ];
  text = ''
    title=$1 body=$2 icon=''${3:-dialog-information}
    loginctl list-sessions --no-legend 2>/dev/null | awk '{print $3}' | sort -u | while read -r user; do
      [ -n "$user" ] && [ "$user" != root ] || continue
      uid=$(id -u "$user" 2>/dev/null) || continue
      [ -S "/run/user/$uid/bus" ] || continue
      runuser -u "$user" -- env DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        notify-send --app-name=ALIS --icon="$icon" "$title" "$body" || true
    done
  '';
}
