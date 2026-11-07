# ALIS Assistant, built into every ALIS OS PC and laptop: say "Hey ALIS" (or
# press Win+A) and the ALIS orb pops up, listens, answers and does things —
# house control and questions through the shared brain on NEST, plus PC
# actions (apps, folders, volume, media, brightness, screenshots, lock, web).
#
#   Win+A          talk to ALIS (no wake word needed)
#   Win+Shift+A    microphone on/off (hard off: the mic isn't opened at all)
#   Stop button    (slides in by the dock while she's active) or "ALIS · Stop" in the menu
#   Mic button     mute / unmute; stays in the corner, red, while muted
#
# The orb balloons out of the top-right corner (see-through overlay, no
# window frame) and shrinks away when she's done. Everything goes to NEST (alis.modules.nest): home network first, Tailscale
# when away (laptops). Settings: alis.assistant.*
{ config, lib, pkgs, ... }:
let
  cfg = config.alis.assistant;
  nest = config.alis.modules.nest;
  pkg = pkgs.callPackage ../pkgs/alis-assistant { port = cfg.port; };
  nestUrls = lib.filter (u: u != null) [ nest.effectiveUrl nest.fallbackUrl ];

  control = { name, label, cmd, shortcut ? null, comment, icon ? "alis-assistant" }: pkgs.writeTextDir "share/applications/${name}.desktop" ''
    [Desktop Entry]
    Type=Application
    Name=${label}
    Comment=${comment}
    Exec=${pkg}/bin/alis-assistant-ctl ${cmd}
    Icon=${icon}
    Categories=Utility;
    ${lib.optionalString (shortcut != null) "X-KDE-Shortcuts=${shortcut}"}
  '';
in
{
  options.alis.assistant = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = lib.elem config.alis.role [ "desktop" "laptop" ] && nest.mode != "off";
      description = "ALIS Assistant ('Hey ALIS') on this machine.";
    };
    startMuted = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Start with the microphone off each time someone logs in.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 47100;
      description = "Local-only control port (127.0.0.1) for the orb and shortcuts.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkg
      (control { name = "alis-assistant-talk"; label = "ALIS · Talk to ALIS"; cmd = "talk"; shortcut = "Meta+A"; comment = "Ask ALIS something"; })
      (control { name = "alis-assistant-mute"; label = "ALIS · Microphone on/off"; cmd = "toggle-mute"; shortcut = "Meta+Shift+A"; comment = "Stop or start ALIS listening"; icon = "microphone-sensitivity-muted"; })
      (control { name = "alis-assistant-stop"; label = "ALIS · Stop"; cmd = "stop"; comment = "Stop ALIS talking"; icon = "media-playback-stop"; })
    ];

    # Her service runs in each person's desktop session (their mic, their apps).
    systemd.user.services.alis-assistant = {
      description = "ALIS Assistant (Hey ALIS)";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" "pipewire.service" "pipewire-pulse.service" ];
      environment = {
        ALIS_NEST_URLS = lib.concatStringsSep " " nestUrls;
        ALIS_DEVICE = config.networking.hostName;
        ALIS_ASSISTANT_PORT = toString cfg.port;
        ALIS_START_MUTED = if cfg.startMuted then "1" else "0";
        # The same programs a logged-in person has, so "open Dolphin" etc. work.
        PATH = lib.mkForce "/run/wrappers/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin";
      };
      serviceConfig = {
        ExecStart = "${pkg}/bin/alis-assistant";
        Restart = "always";
        RestartSec = 5;
      };
    };

    # Her on-screen overlay: the orb balloons out of the top-right corner,
    # Mic/Stop slide in just above the dock on the right (alis-ui.qml).
    systemd.user.services.alis-assistant-ui = {
      description = "ALIS Assistant on screen (orb + controls)";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" "alis-assistant.service" ];
      serviceConfig = {
        ExecStart = "${pkg}/bin/alis-assistant-ui";
        Restart = "always";
        RestartSec = 3;
      };
    };

    # Default keyboard shortcuts (people can change them in System Settings).
    environment.etc."xdg/kglobalshortcutsrc".text = ''
      [services][alis-assistant-talk.desktop]
      _launch=Meta+A

      [services][alis-assistant-mute.desktop]
      _launch=Meta+Shift+A
    '';

    # Brightness control without a password.
    services.udev.packages = [ pkgs.brightnessctl ];
    users.users.alan.extraGroups = [ "video" ];
  };
}
