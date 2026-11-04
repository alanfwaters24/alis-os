# Kiosk role — wall / fridge tablets and the live test image.
# Powers on, logs itself in, shows the ALIS dashboard full-screen. Nothing else.
{ config, lib, pkgs, ... }:
let
  cfg = config.alis.kiosk;
in
{
  options.alis.kiosk = {
    browserFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "--disable-gpu" ];
      description = "Extra Chromium flags (e.g. --disable-gpu on hardware with broken graphics drivers).";
    };
    command = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "The full-screen dashboard command (also used by the desktop role).";
    };
  };

  config = lib.mkMerge [
    {
      alis.kiosk.command = lib.concatStringsSep " " ([
        "${pkgs.chromium}/bin/chromium"
        "--app=${config.alis.dashboard.url}"
        "--kiosk"
        "--no-first-run"
        "--noerrdialogs"
        "--disable-infobars"
        "--disable-session-crashed-bubble"
        "--password-store=basic"
        "--ozone-platform=wayland"
      ] ++ cfg.browserFlags);
    }

    # Screens with a browser: the ALIS dashboard may use the microphone
    # ("Hey ALIS") without a pop-up. Other sites still ask as normal.
    (lib.mkIf (!(lib.elem config.alis.role [ "server" "brain" ])) {
      programs.chromium = {
        enable = true;
        extraOpts.AudioCaptureAllowedUrls = [ config.alis.dashboard.url ];
      };
    })

    (lib.mkIf (config.alis.role == "kiosk") {
      # Kiosks have nobody to tap pop-ups. Kiosk mode can't leave the
      # dashboard, so "allow location" here only ever reaches the dashboard;
      # the mic is blocked for anything that isn't the dashboard address.
      programs.chromium.extraOpts = {
        DefaultGeolocationSetting = 1;
        AudioCaptureAllowed = false;
        VideoCaptureAllowed = false;
        DefaultNotificationsSetting = 2;
      };

      # Unprivileged screen user — can't sudo, can't change the system.
      users.users.alis-screen = {
        isNormalUser = true;
        description = "ALIS screen";
        extraGroups = [ "video" "audio" ];
      };

      # cage = a tiny Wayland compositor that runs exactly one app full-screen.
      services.cage = {
        enable = true;
        user = "alis-screen";
        program = cfg.command;
        extraArguments = [ "-d" ]; # no window decorations
      };
      # Bring the dashboard back if it ever crashes or is closed.
      systemd.services."cage-tty1" = {
        after = [ "alis-dashboard.service" "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig.Restart = lib.mkForce "always";
      };

      fonts.packages = with pkgs; [ noto-fonts noto-fonts-color-emoji dejavu_fonts ];
      hardware.graphics.enable = true;
      # Never blank the screen.
      boot.kernelParams = [ "consoleblank=0" ];
      services.logind.settings.Login.HandleLidSwitch = "ignore";
    })
  ];
}
