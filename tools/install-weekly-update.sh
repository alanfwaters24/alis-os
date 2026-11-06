#!/usr/bin/env bash
# One-time: install the weekly ALIS OS version update on dev-automation
# (a user timer, Sundays 04:15; runs even if you're not logged in).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/alis-os-weekly.service" <<UNIT
[Unit]
Description=ALIS OS weekly version update (build-checked)
After=network-online.target

[Service]
Type=oneshot
Environment=PATH=$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$here/weekly-update.sh
Nice=10
UNIT
cat > "$HOME/.config/systemd/user/alis-os-weekly.timer" <<UNIT
[Unit]
Description=Weekly ALIS OS version update

[Timer]
OnCalendar=Sun 04:15
Persistent=true

[Install]
WantedBy=timers.target
UNIT
systemctl --user daemon-reload
systemctl --user enable --now alis-os-weekly.timer
loginctl enable-linger "$USER" 2>/dev/null || sudo loginctl enable-linger "$USER"
systemctl --user list-timers alis-os-weekly.timer --no-pager
echo "Installed. Run it now with: systemctl --user start alis-os-weekly"
