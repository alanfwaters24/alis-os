# ALIS boot picker, end to end, on an installed-style UEFI machine with a
# second "Windows" drive (an EFI partition holding a stand-in
# EFI/Microsoft/Boot/bootmgfw.efi). Runs the real rebuild step, then
# restarts through the picker:
#   nix build .#checks.x86_64-linux.boot-picker -L
# Screenshots land in the result folder (picker.png, windows.png, ...).
{ pkgs, alisModule }:
let
  # Stand-in "Windows": a copy of rEFInd that just shows THIS IS WINDOWS.
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
  name = "alis-boot-picker";
  extraPythonPackages = p: [ p.pillow ];

  nodes.machine = { lib, ... }: {
    imports = [ alisModule ../modules/machine.nix ];
    alis.machine = "vm-test";
    alis.role = "server";
    alis.bootPicker.enable = true;
    networking.hostName = "alis-picker-test";
    system.stateVersion = "26.05";
    virtualisation.memorySize = 2048;
    virtualisation.useBootLoader = true;
    virtualisation.useEFIBoot = true;
    virtualisation.efi.keepVariables = true;
    virtualisation.emptyDiskImages = [ 64 ];   # becomes the "Windows" drive
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
        # The picker's background is dark green; the firmware/text screens are black.
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

    with subtest("make the Windows drive"):
        machine.succeed("printf 'label: gpt\\n,,C12A7328-F81F-11D2-BA4B-00A0C93EC93B\\n' | sfdisk /dev/vdb")
        machine.succeed("udevadm settle; mkfs.vfat -n SYSTEM /dev/vdb1")
        machine.succeed("mkdir -p /mnt/win && mount /dev/vdb1 /mnt/win && mkdir -p /mnt/win/EFI/Microsoft/Boot")
        machine.succeed("cp /etc/fakewin/bootmgfw.efi /etc/fakewin/refind.conf /mnt/win/EFI/Microsoft/Boot/ && umount /mnt/win")
        # Like a real Windows install: its own entry in the PC's boot list.
        machine.succeed("efibootmgr -q -c -d /dev/vdb -p 1 -l '\\EFI\\Microsoft\\Boot\\bootmgfw.efi' -L 'Windows Boot Manager'")
        print(machine.succeed("efibootmgr -v"))

    with subtest("a rebuild installs the picker and puts it first"):
        machine.succeed("/run/current-system/bin/switch-to-configuration boot")
        drives = machine.succeed("alis-boot-picker drives")
        print(drives)
        assert "not found" not in drives, drives
        conf = machine.succeed("cat /boot/EFI/alis-picker/refind.conf")
        print(conf)
        assert "firmware_bootnum" in conf, conf
        order = machine.succeed("efibootmgr")
        print(order)
        first = order.split("BootOrder: ")[1].split(",")[0].strip()
        assert f"Boot{first}* ALIS boot picker" in order or f"Boot{first} ALIS boot picker" in order, order
        machine.succeed("alis-boot-picker log on")

    with subtest("power on -> picker -> ALIS OS"):
        machine.shutdown()
        machine.start()
        picker_up()
        time.sleep(3)
        machine.screenshot("picker")
        machine.send_key("ret")
        machine.wait_for_unit("multi-user.target")
        print(machine.succeed("alis-boot-picker log | grep -i -E 'driver|connect|volume|manual|SYSTEM|Error' | head -60"))

    with subtest("picker -> Windows"):
        machine.shutdown()
        machine.start()
        picker_up()
        time.sleep(3)
        machine.send_key("right")
        time.sleep(2)
        machine.screenshot("picker-windows-selected")
        machine.send_key("ret")
        # The Windows tile restarts the PC into Windows' own boot entry (the
        # firmware wakes the Windows drive). Test VMs stop instead of
        # restarting, so power it back on: the firmware then starts Windows.
        machine.wait_for_shutdown()
        machine.start()
        time.sleep(40)
        machine.screenshot("windows")

    with subtest("next power on remembers Windows"):
        machine.crash()
        machine.start()
        picker_up()
        time.sleep(3)
        machine.screenshot("picker-after-windows")
  '';
}
