# Nightly upkeep test: backups (restic to "stash") and the update job's
# safety paths, on an installed-style machine in a VM.
#   nix build .#checks.x86_64-linux.upkeep -L
{ pkgs, alisModule }:
pkgs.testers.runNixOSTest {
  name = "alis-upkeep";

  nodes.machine = { lib, ... }: {
    imports = [ alisModule ../modules/machine.nix ];
    alis.machine = "vm-test";
    alis.role = "server";
    networking.hostName = "alis-upkeep-test";
    system.stateVersion = "26.05";
    virtualisation.memorySize = 2048;
    # No VAULT in a test VM: a local folder stands in for the stash share.
    fileSystems."/mnt/nas/stash" = lib.mkForce { device = "tmpfs"; fsType = "tmpfs"; options = [ "size=512m" ]; };
    users.users.alan.createHome = true;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    repo = "/mnt/nas/stash/ALIS backups/vm-test"

    with subtest("timers are set"):
        machine.succeed("systemctl list-timers | grep -q restic-backups-alis")
        machine.succeed("systemctl list-timers | grep -q alis-update")

    with subtest("no backup password yet -> refuses with a clear reason"):
        machine.fail("systemctl start restic-backups-alis.service")
        machine.succeed("journalctl -u restic-backups-alis | grep -q 'No backup password yet'")

    with subtest("set up, then back up"):
        machine.succeed("install -d -m 700 /etc/alis && (umask 077; printf 'test-backup-pass' > /etc/alis/backup-password)")
        machine.succeed("install -d -o alan /home/alan/Documents /home/alan/Downloads /home/alan/.cache")
        machine.succeed("echo 'ALIS keeps this' > /home/alan/Documents/note.txt")
        machine.succeed("head -c 5000000 /dev/urandom > /home/alan/Downloads/big.iso; echo junk > /home/alan/.cache/c")
        machine.succeed("mkdir -p /var/lib/alis/glance && echo state > /var/lib/alis/glance/state.json")
        machine.succeed("systemctl start restic-backups-alis.service")
        snaps = machine.succeed(f"restic -r '{repo}' --password-file /etc/alis/backup-password snapshots --json")
        assert snaps.count('"id"') >= 1, snaps
        listing = machine.succeed(f"restic -r '{repo}' --password-file /etc/alis/backup-password ls latest")
        assert "/home/alan/Documents/note.txt" in listing, listing
        assert "/var/lib/alis/glance/state.json" in listing, listing
        assert "Downloads/big.iso" not in listing and ".cache/c" not in listing, listing

    with subtest("restore a file"):
        machine.succeed(f"restic -r '{repo}' --password-file /etc/alis/backup-password restore latest --target /tmp/r --include /home/alan/Documents/note.txt")
        machine.succeed("cmp /tmp/r/home/alan/Documents/note.txt /home/alan/Documents/note.txt")

    with subtest("second night: de-duplicated, history kept"):
        machine.succeed("echo more >> /home/alan/Documents/note.txt; systemctl start restic-backups-alis.service")
        snaps = machine.succeed(f"restic -r '{repo}' --password-file /etc/alis/backup-password snapshots --json")
        assert snaps.count('"id"') >= 2, snaps

    with subtest("update job without a repo clone explains instead of failing"):
        machine.succeed("systemctl start alis-update.service")
        machine.succeed("journalctl -u alis-update | grep -q 'No ALIS OS repo'")
  '';
}
