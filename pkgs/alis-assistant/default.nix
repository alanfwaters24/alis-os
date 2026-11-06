# ALIS Assistant for ALIS OS (see assistant.py). Wraps the plain-Python
# assistant with the desktop tools it drives.
{ lib, stdenvNoCC, makeWrapper, python3, pulseaudio, playerctl, wireplumber
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
    cp assistant.py orb.html alis-ui.qml orb-icon.svg $out/share/alis-assistant/
    makeWrapper ${python3}/bin/python3 $out/bin/alis-assistant \
      --add-flags $out/share/alis-assistant/assistant.py \
      --prefix PATH : ${lib.makeBinPath [ pulseaudio playerctl wireplumber brightnessctl
        kdePackages.spectacle kdePackages.systemsettings systemd xdg-utils libnotify bluez ]}
    # The on-screen overlay: orb in the top-right corner, Mic/Stop by the dock.
    makeWrapper ${kdePackages.qtdeclarative}/bin/qml $out/bin/alis-assistant-ui \
      --add-flags "$out/share/alis-assistant/alis-ui.qml -- ${toString port}" \
      --prefix QML_IMPORT_PATH : ${kdePackages.layer-shell-qt}/lib/qt-6/qml:${kdePackages.qtdeclarative}/lib/qt-6/qml \
      --prefix QT_PLUGIN_PATH : ${kdePackages.qtsvg}/lib/qt-6/plugins:${kdePackages.qtwayland}/lib/qt-6/plugins:${kdePackages.qtbase}/lib/qt-6/plugins
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
