# Nightly backups of installed ALIS OS machines to VAULT, with restic
# (encrypted, de-duplicated, keeps history). Goes to
#   stash/ALIS backups/<machine>     (the stash share, mounted at /mnt/nas/stash)
# which VAULT's Backblaze B2 copy of DataKeeper also covers off-site.
#
#   What:    /home minus Downloads, caches, Trash and games;
#            plus ALIS module data (/var/lib/alis) and Home Assistant (if here)
#   When:    02:30, or soon after start-up if the machine was off
#   Keeps:   7 daily, 4 weekly, 6 monthly
#
# One-time setup per machine (asks for the backup password, which you must
# keep somewhere safe — without it backups can't be opened):
#   sudo alis-backup-setup
# Get files back:
#   sudo alis-backup-browse        (opens every backup as folders in Dolphin)
{ config, lib, pkgs, ... }:
let
  cfg = config.alis.backup;
  notify = pkgs.callPackage ../pkgs/alis-notify.nix { };
  repo = "${config.alis.nas.mountRoot}/stash/ALIS backups/${config.alis.machine}";
  passwordFile = "/etc/alis/backup-password";

  setup = pkgs.writeShellApplication {
    name = "alis-backup-setup";
    runtimeInputs = with pkgs; [ coreutils openssl ];
    text = ''
      [ "$(id -u)" = 0 ] || exec sudo "$0" "$@"
      echo
      echo "  ALIS backups for ${config.alis.machine}"
      echo "  Backups are encrypted. Use the SAME backup password on every ALIS machine,"
      echo "  and keep it in your password manager: without it, backups can't be opened."
      echo
      if [ -s ${passwordFile} ]; then echo "  A backup password is already set. (Delete ${passwordFile} to change it.)"; exit 0; fi
      read -r -s -p "  Backup password (or press Enter to make one up for you): " p1; echo
      if [ -z "$p1" ]; then
        p1=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)
        echo "  Your new backup password is:   $p1"
        echo "  Write it down / save it in your password manager NOW."
      else
        read -r -s -p "  Same again: " p2; echo
        [ "$p1" = "$p2" ] || { echo "  They didn't match. Nothing saved."; exit 1; }
      fi
      install -d -m 700 /etc/alis
      ( umask 077; printf '%s' "$p1" > ${passwordFile} )
      [ -s /etc/alis/nas-credentials ] || echo "  Also needed: the stash login in /etc/alis/nas-credentials (see the ALIS OS README, 'NAS storage')."
      echo "  Saved. The first backup runs tonight (or: sudo systemctl start restic-backups-alis)."
    '';
  };

  browse = pkgs.writeShellApplication {
    name = "alis-backup-browse";
    runtimeInputs = with pkgs; [ restic coreutils ];
    text = ''
      [ "$(id -u)" = 0 ] || exec sudo "$0" "$@"
      m=/run/alis-backups
      mkdir -p "$m"
      echo "  Opening the backups at $m (one folder per night)."
      echo "  Open that folder in Dolphin and copy back what you need. Press Ctrl+C here when done."
      restic -r ${lib.escapeShellArg repo} --password-file ${passwordFile} mount --allow-other "$m"
    '';
  };
in
{
  options.alis.backup = {
    enable = lib.mkEnableOption "nightly backups to VAULT (stash/ALIS backups/<machine>)";
    time = lib.mkOption { type = lib.types.str; default = "02:30"; };
    extraPaths = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
    extraExcludes = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
  };

  config = lib.mkIf (cfg.enable && config.alis.machine != null) {
    environment.systemPackages = [ setup browse pkgs.restic ];
    programs.fuse.userAllowOther = true;      # lets Dolphin see the browsed backups

    services.restic.backups.alis = {
      repository = repo;
      inherit passwordFile;
      initialize = true;
      paths = [ "/home" "/var/lib/alis" ]
        ++ lib.optional config.services.home-assistant.enable config.services.home-assistant.configDir
        ++ cfg.extraPaths;
      exclude = [
        "/home/*/Downloads" "/home/*/.cache" "/home/*/.local/share/Trash"
        "/home/*/.local/share/Steam" "/home/*/.steam" "/home/*/Games" "/home/*/.local/share/lutris"
        "/home/*/.local/share/baloo" "/home/*/.config/chromium/*/Cache" "/home/*/.config/chromium/*/Code Cache"
        "/home/*/.npm" "/home/*/.cargo/registry" "**/node_modules" "*.iso"
      ] ++ cfg.extraExcludes;
      extraBackupArgs = [ "--exclude-caches" "--one-file-system" "--tag" "alis-nightly" ];
      pruneOpts = [ "--keep-daily 7" "--keep-weekly 4" "--keep-monthly 6" ];
      timerConfig = { OnCalendar = cfg.time; Persistent = true; RandomizedDelaySec = "20m"; };
      # Clear reasons instead of a cryptic restic error.
      backupPrepareCommand = ''
        if [ ! -s ${passwordFile} ]; then
          ${notify}/bin/alis-notify "ALIS backups aren't set up" "Run: sudo alis-backup-setup" dialog-warning
          echo "No backup password yet: run sudo alis-backup-setup"; exit 1
        fi
        mkdir -p ${lib.escapeShellArg repo} 2>/dev/null || true
        if [ ! -d ${lib.escapeShellArg repo} ]; then
          ${notify}/bin/alis-notify "ALIS backup skipped" "VAULT (stash) isn't reachable. It'll try again tomorrow." dialog-warning
          echo "stash not reachable"; exit 1
        fi
      '';
    };
    systemd.services.restic-backups-alis = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = { Nice = 10; IOSchedulingClass = "idle"; };
    };
  };
}
