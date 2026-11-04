# Boots a Brain-role machine in a VM and checks every service comes up.
#   nix build .#checks.x86_64-linux.brain-boot -L
#
# The test VM has no internet, so Whisper and Piper (which download their
# model / voice on first start) are only checked as "service exists"; the
# real Brain fetches them once and keeps them.
{ pkgs, alisModule }:
pkgs.testers.runNixOSTest {
  name = "alis-brain-boot";

  nodes.brain = { lib, ... }: {
    imports = [ alisModule ];
    alis.role = "brain";
    networking.hostName = "alis-brain-test";
    virtualisation.memorySize = 4096;
    virtualisation.cores = 2;

    # Stand-in NEST settings (the real config.json is placed by hand).
    systemd.tmpfiles.rules = [
      ''f /var/lib/alis/live/config.json 0640 alis-apps alis - {"token":"test-token","ha_url":"http://127.0.0.1:8123"}''
    ];
  };

  testScript = ''
    brain.start()
    brain.wait_for_unit("multi-user.target")

    with subtest("ALIS OS branding"):
        brain.succeed("grep -q 'ALIS OS' /etc/os-release")

    with subtest("alis-push (notifications)"):
        brain.wait_for_open_port(8091)
        brain.succeed("test -f /var/lib/alis/push/data/vapid_private.pem")

    with subtest("GLANCE"):
        brain.wait_for_open_port(3512)

    with subtest("NEST + shared brain"):
        brain.wait_for_open_port(8080)
        brain.succeed("curl -sf http://127.0.0.1:8080/ | grep -qi 'A.L.I.S'")

    with subtest("openWakeWord"):
        brain.wait_for_open_port(10400)

    with subtest("Ollama"):
        brain.wait_for_open_port(11434)

    with subtest("Home Assistant"):
        brain.wait_for_open_port(8123, timeout=1200)

    with subtest("Whisper + Piper services installed"):
        brain.succeed("systemctl cat wyoming-faster-whisper-alis.service")
        brain.succeed("systemctl cat wyoming-piper-alis.service")

    with subtest("data stays local, code is linked"):
        brain.succeed("test -L /var/lib/alis/push/server.py")
        brain.succeed("test -d /var/lib/alis/push/data -a ! -L /var/lib/alis/push/data")
        brain.succeed("test -f /var/lib/alis/live/config.json -a ! -L /var/lib/alis/live/config.json")
  '';
}
