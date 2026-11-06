# NAS (VAULT) storage on ALIS OS PCs and laptops. Two kinds of share:
#
#   mounted  — always there as a folder (/mnt/nas/<share>), connects the first
#              time it's opened, one shared NAS login kept on the machine.
#              Default for `stash`, the shared household drive.
#   link     — a sidebar link in the file explorer; each family member logs in
#              with their own NAS account the first time (remembered by KDE).
#
#   alis.nas.shares = {
#     stash = { };                    # mounted (default)
#     alan  = { mount = false; };     # personal, own login
#   };
#
# For mounted shares, put the shared login on the machine once:
#   sudo install -m 600 /dev/stdin /etc/alis/nas-credentials <<'EOF'
#   username=...
#   password=...
#   EOF
# If VAULT is off, nothing hangs: mounts time out after 10 s and links just fail to open.
{ config, lib, pkgs, ... }:
let
  cfg = config.alis.nas;
  isDesktop = lib.elem config.alis.role [ "desktop" "laptop" ];
  mounted = lib.filterAttrs (_: s: s.mount) cfg.shares;

  # Adds each share to the Dolphin sidebar once per user (a user can remove it
  # and it stays removed).
  places = pkgs.writeText "alis-nas-places.json" (builtins.toJSON (lib.mapAttrsToList (n: s: {
    name = s.label;
    url = if s.mount then "file://${cfg.mountRoot}/${n}" else "smb://${cfg.host}/${n}";
  }) cfg.shares));

  addPlaces = pkgs.writers.writePython3 "alis-nas-places" { flakeIgnore = [ "E501" ]; } ''
    import json
    import os
    import xml.etree.ElementTree as ET

    home = os.path.expanduser("~")
    xbel = os.path.join(home, ".local/share/user-places.xbel")
    done_file = os.path.join(home, ".config/alis-nas-places-added")
    done = set(open(done_file).read().split()) if os.path.exists(done_file) else set()
    wanted = [p for p in json.load(open("${places}")) if p["url"] not in done]
    if not wanted:
        raise SystemExit
    if os.path.exists(xbel):
        tree = ET.parse(xbel)
        root = tree.getroot()
    else:
        os.makedirs(os.path.dirname(xbel), exist_ok=True)
        root = ET.Element("xbel")
        tree = ET.ElementTree(root)
    have = {b.get("href") for b in root.iter("bookmark")}
    for p in wanted:
        if p["url"] not in have:
            b = ET.SubElement(root, "bookmark", href=p["url"])
            ET.SubElement(b, "title").text = p["name"]
        done.add(p["url"])
    tree.write(xbel, encoding="utf-8", xml_declaration=True)
    os.makedirs(os.path.dirname(done_file), exist_ok=True)
    open(done_file, "w").write("\n".join(sorted(done)))
  '';
in
{
  options.alis.nas = {
    host = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.252";
      description = "The NAS (VAULT). Use its Tailscale name to reach it away from home.";
    };
    mountRoot = lib.mkOption { type = lib.types.str; default = "/mnt/nas"; };
    credentialsFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/alis/nas-credentials";
      description = "Shared login for mounted shares (username=/password= lines). Placed by hand, never in git.";
    };
    shares = lib.mkOption {
      default = { stash = { }; };
      description = "SMB shares on the NAS, by share name.";
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          mount = lib.mkOption { type = lib.types.bool; default = true; description = "Always-mounted (true) or sidebar link with own login (false)."; };
          label = lib.mkOption { type = lib.types.str; default = "NAS · ${name}"; description = "Name shown in the file explorer."; };
        };
      }));
    };
  };

  # Mounted on PCs/laptops, and on any machine that backs up to stash.
  config = lib.mkIf (isDesktop || (config.alis.backup.enable && config.alis.machine != null)) {
    environment.systemPackages = [ pkgs.cifs-utils ];
    boot.supportedFilesystems = [ "cifs" ];

    fileSystems = lib.mapAttrs' (n: _: lib.nameValuePair "${cfg.mountRoot}/${n}" {
      device = "//${cfg.host}/${n}";
      fsType = "cifs";
      options = [
        "credentials=${cfg.credentialsFile}"
        "x-systemd.automount" "noauto" "_netdev"
        "x-systemd.idle-timeout=600" "x-systemd.mount-timeout=10s"
        "gid=users" "file_mode=0664" "dir_mode=0775" "nofail"
      ];
    }) mounted;

    environment.etc."xdg/autostart/alis-nas-places.desktop".enable = isDesktop;
    environment.etc."xdg/autostart/alis-nas-places.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=ALIS NAS links
      Exec=${addPlaces}
      NoDisplay=true
    '';
  };
}
