# ALIS Assistant for ALIS OS (see assistant.py). Wraps the plain-Python
# assistant with the desktop tools it drives.
{ lib, stdenvNoCC, makeWrapper, python3, pulseaudio, chromium, playerctl, wireplumber
, brightnessctl, kdePackages, systemd, xdg-utils, libnotify, bluez, curl
, port ? 47100 }:
stdenvNoCC.mkDerivation {
  pname = "alis-assistant";
  version = "0.1.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/share/alis-assistant $out/bin
    cp assistant.py orb.html $out/share/alis-assistant/
    makeWrapper ${python3}/bin/python3 $out/bin/alis-assistant \
      --add-flags $out/share/alis-assistant/assistant.py \
      --prefix PATH : ${lib.makeBinPath [ pulseaudio chromium playerctl wireplumber brightnessctl
        kdePackages.spectacle kdePackages.systemsettings systemd xdg-utils libnotify bluez ]}
    # alis-assistant-ctl talk | stop | mute | unmute | toggle-mute | status
    cat > $out/bin/alis-assistant-ctl <<SH
    #!/bin/sh
    case "\$1" in
      status) exec ${curl}/bin/curl -s http://127.0.0.1:${toString port}/api/status ;;
      talk|stop|mute|unmute|toggle-mute) exec ${curl}/bin/curl -s -X POST http://127.0.0.1:${toString port}/api/\$1 >/dev/null ;;
      *) echo "usage: alis-assistant-ctl talk|stop|mute|unmute|toggle-mute|status" >&2; exit 2 ;;
    esac
    SH
    chmod +x $out/bin/alis-assistant-ctl
  '';
  meta.mainProgram = "alis-assistant";
}
