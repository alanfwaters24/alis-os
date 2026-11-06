# Automatic updates for installed ALIS OS machines (machines/<name>/).
#
# Nightly (03:30, or soon after start-up if the machine was off), as root:
#   1. as alan: git pull the ALIS OS repo (/home/alan/alis-os, the clone made
#      when the machine's hardware file was saved) and fetch its pinned
#      sources with alan's GitHub login
#   2. build the new version and set it for the NEXT RESTART
#      (nixos-rebuild boot) — nothing changes while someone's using it
#   3. tell whoever's logged in: "update ready, restart to use it"
# Laptops on battery skip the night. If anything fails, the running version
# is untouched and a notification says so. The software versions themselves
# move weekly on dev-automation after a build check (tools/weekly-update.sh).
{ config, lib, pkgs, ... }:
let
  cfg = config.alis.updates;
  notify = pkgs.callPackage ../pkgs/alis-notify.nix { };
  nixCmd = "${config.nix.package}/bin/nix --extra-experimental-features 'nix-command flakes'";
  update = pkgs.writeShellApplication {
    name = "alis-update";
    runtimeInputs = with pkgs; [ git util-linux coreutils gnugrep config.system.build.nixos-rebuild notify ];
    text = ''
      repo=${lib.escapeShellArg cfg.repo}
      user=${lib.escapeShellArg cfg.user}
      machine=${lib.escapeShellArg config.alis.machine}

      # Laptops: don't spend the battery on an update.
      for ac in /sys/class/power_supply/A{C,DP}*/online; do
        if [ -r "$ac" ] && [ "$(cat "$ac")" = 0 ] && [ "''${ALIS_UPDATE_ON_BATTERY:-0}" != 1 ]; then
          echo "On battery: skipping tonight's update."; exit 0
        fi
      done

      if [ ! -d "$repo/.git" ]; then
        echo "No ALIS OS repo at $repo (run the 'save to GitHub' steps once)."
        alis-notify "ALIS OS updates are off" "Save this machine to GitHub once (see the ALIS OS README) so it can update itself." dialog-warning
        exit 0
      fi

      as_user() { runuser -u "$user" -- env HOME="$(getent passwd "$user" | cut -d: -f6)" "$@"; }

      before=$(as_user git -C "$repo" rev-parse HEAD)
      if ! as_user git -C "$repo" pull --ff-only --quiet; then
        alis-notify "ALIS OS update didn't run" "Couldn't fetch the latest ALIS OS from GitHub. It'll try again tomorrow." dialog-warning
        exit 1
      fi
      after=$(as_user git -C "$repo" rev-parse HEAD)
      echo "ALIS OS repo: $before -> $after"

      # Fetch the pinned sources (private ALIS repos) with alan's GitHub login.
      as_user ${nixCmd} flake archive "$repo" >/dev/null

      current=$(readlink -f /nix/var/nix/profiles/system)
      if ! nixos-rebuild boot --flake "$repo#$machine"; then
        alis-notify "ALIS OS update failed" "The new version didn't build, so nothing changed. Details: journalctl -u alis-update" dialog-error
        exit 1
      fi
      new=$(readlink -f /nix/var/nix/profiles/system)
      if [ "$new" != "$current" ]; then
        echo "New version ready for next restart: $new"
        alis-notify "ALIS OS update ready" "Restart when it suits you to start using it." system-software-update
      else
        echo "Already up to date."
      fi
    '';
  };
in
{
  options.alis.machine = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = "This machine's folder name in machines/ (set automatically for installed machines).";
  };

  options.alis.updates = {
    enable = lib.mkEnableOption "nightly automatic ALIS OS updates (applied on next restart)";
    repo = lib.mkOption { type = lib.types.str; default = "/home/alan/alis-os"; description = "The machine's git clone of alis-os."; };
    user = lib.mkOption { type = lib.types.str; default = "alan"; description = "Whose GitHub login is used to fetch it."; };
    time = lib.mkOption { type = lib.types.str; default = "03:30"; description = "When to check (systemd time)."; };
  };

  config = lib.mkIf (cfg.enable && config.alis.machine != null) {
    environment.systemPackages = [ update notify ];

    systemd.services.alis-update = {
      description = "ALIS OS automatic update (applied on next restart)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ pkgs.git ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${update}/bin/alis-update";
        Nice = 10;
        IOSchedulingClass = "idle";
      };
    };
    systemd.timers.alis-update = {
      description = "Nightly ALIS OS update check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.time;
        Persistent = true;              # machine was off at 03:30? run soon after start-up
        RandomizedDelaySec = "30m";
      };
    };
  };
}
