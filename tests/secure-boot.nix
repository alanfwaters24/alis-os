# Secure Boot end to end, like the office PC: UEFI firmware with Secure
# Boot (starting in Setup Mode, as after "Clear Secure Boot keys" in the
# BIOS), a TPM, ALIS with the boot picker + alis.secureBoot, and a second
# "Windows" drive with its own Windows Boot Manager entry.
#   nix build .#checks.x86_64-linux.secure-boot -L
# Follows the real steps (sudo alis-secure-boot enroll), then checks that
# Secure Boot is enforcing and both tiles still start their system.
{ pkgs, alisModule }:
let
  fakeWindowsConf = pkgs.writeText "refind.conf" ''
    use_nvram false
    timeout 0
    textonly
    scanfor manual
    menuentry "THIS IS WINDOWS" {
      loader /nothing.efi
    }
  '';
in
pkgs.testers.runNixOSTest {
  name = "alis-secure-boot";
  extraPythonPackages = p: [ p.pillow ];

  nodes.machine = { lib, ... }: {
    imports = [ alisModule ../modules/machine.nix ];
    alis.machine = "vm-test";
    alis.role = "server";
    alis.bootPicker.enable = true;
    alis.secureBoot.enable = true;
    networking.hostName = "alis-sb-test";
    system.stateVersion = "26.05";
    virtualisation.memorySize = 2048;
    virtualisation.useBootLoader = true;
    virtualisation.useEFIBoot = true;
    virtualisation.useSecureBoot = true;
    virtualisation.efi.keepVariables = true;
    virtualisation.tpm.enable = true;
    virtualisation.emptyDiskImages = [ { size = 64; driveConfig.deviceExtraOpts.bootindex = "3"; } ];
    alis.updates.enable = false;
    alis.backup.enable = false;
    swapDevices = lib.mkForce [ ];
    environment.systemPackages = with pkgs; [ dosfstools util-linux efibootmgr ];
    environment.etc."fakewin/bootmgfw.efi".source = "${pkgs.refind}/share/refind/refind_x64.efi";
    environment.etc."fakewin/refind.conf".source = fakeWindowsConf;
  };

  testScript = ''
    import time

    def picker_up(timeout=600):
        end = time.time() + timeout
        while time.time() < end:
            machine.screenshot("probe")
            from PIL import Image
            im = Image.open(f"{machine.out_dir}/probe.png").convert("RGB")
            w, h = im.size
            x, y = w // 6, h // 5
            r, g, b = im.crop((x, y, x + 1, y + 1)).tobytes()[:3]
            if g > r + 8 and g > 20:
                return
            time.sleep(5)
        raise Exception("boot picker never appeared")

    machine.start()
    machine.wait_for_unit("multi-user.target")

    with subtest("starts in Setup Mode, keys made automatically"):
        print(machine.succeed("alis-secure-boot status"))
        machine.wait_for_unit("generate-sb-keys.service")
        machine.succeed("test -e /var/lib/sbctl/keys/db/db.key")

    with subtest("a Windows drive with its own boot entry (signed, like Microsoft's)"):
        machine.succeed("printf 'label: gpt\\n,,C12A7328-F81F-11D2-BA4B-00A0C93EC93B\\n' | sfdisk /dev/vdb")
        machine.succeed("udevadm settle; mkfs.vfat -n SYSTEM /dev/vdb1")
        machine.succeed("mkdir -p /mnt/win && mount /dev/vdb1 /mnt/win && mkdir -p /mnt/win/EFI/Microsoft/Boot")
        machine.succeed("cp /etc/fakewin/bootmgfw.efi /etc/fakewin/refind.conf /mnt/win/EFI/Microsoft/Boot/")
        machine.succeed("sbctl sign /mnt/win/EFI/Microsoft/Boot/bootmgfw.efi && umount /mnt/win")
        machine.succeed("efibootmgr -q -c -d /dev/vdb -p 1 -l '\\\\EFI\\\\Microsoft\\\\Boot\\\\bootmgfw.efi' -L 'Windows Boot Manager'")

    with subtest("sudo alis-secure-boot enroll"):
        out = machine.succeed("alis-secure-boot enroll 2>&1")
        print(out)
        assert "Done." in out, out
        print(machine.succeed("sbctl verify 2>&1"))
        print(machine.succeed("cat /boot/EFI/alis-picker/refind.conf | grep -v '^showtools'"))

    with subtest("restart: Secure Boot on, picker -> ALIS OS"):
        machine.shutdown()
        machine.start()
        picker_up()
        time.sleep(3)
        machine.screenshot("sb-picker")
        machine.send_key("ret")
        machine.wait_for_unit("multi-user.target")
        status = machine.succeed("bootctl status 2>&1")
        print(status)
        assert "Secure Boot: enabled" in status, status
        print(machine.succeed("alis-secure-boot status"))

    with subtest("picker -> Windows with Secure Boot on"):
        machine.shutdown()
        machine.start()
        picker_up()
        time.sleep(3)
        machine.send_key("right")
        time.sleep(2)
        machine.send_key("ret")
        machine.wait_for_shutdown()
        machine.start()
        machine.wait_for_console_text('starting Boot[0-9A-F]+ "Windows Boot Manager"')
        time.sleep(15)
        machine.screenshot("sb-windows")
  '';
}
