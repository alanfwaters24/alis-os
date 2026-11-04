# Desktop role — office PC (and the base for the laptop role).
# A login screen, then a light ALIS-coloured desktop (sway) whose first
# workspace is the dashboard. Terminal, browser and files on hand.
{ config, lib, pkgs, ... }:
let
  c = import ../artwork/colours.nix;
  isDesktop = lib.elem config.alis.role [ "desktop" "laptop" ];
  artwork = pkgs.callPackage ../artwork { };
in
{
  config = lib.mkIf isDesktop {
    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
      extraPackages = with pkgs; [ foot fuzzel swaylock swayidle grim slurp wl-clipboard mako ];
    };

    environment.etc."sway/config".source = lib.mkForce (pkgs.writeText "alis-sway-config" ''
      # ALIS OS desktop — ALIS Glass colours
      set $mod Mod4
      set $term foot
      set $menu fuzzel

      output * bg ${artwork}/splash.png fill
      default_border pixel 2
      gaps inner 10
      font pango:DejaVu Sans 11

      #                       border      bg        text     indicator  child_border
      client.focused          ${c.teal}   ${c.bg}   ${c.text} ${c.violet} ${c.teal}
      client.focused_inactive ${c.bg}     ${c.bg}   ${c.textDim} ${c.bg}  ${c.bg}
      client.unfocused        ${c.bg}     ${c.bg}   ${c.textDim} ${c.bg}  ${c.bg}

      input type:keyboard xkb_layout gb

      # Workspace 1 = the ALIS dashboard
      assign [app_id="^chrom"] workspace 1
      exec ${config.alis.kiosk.command}

      bindsym $mod+Return exec $term
      bindsym $mod+d exec $menu
      bindsym $mod+a exec ${config.alis.kiosk.command}
      bindsym $mod+q kill
      bindsym $mod+f fullscreen toggle
      bindsym $mod+l exec swaylock -c ${lib.removePrefix "#" c.bg}
      bindsym $mod+Shift+e exec swaynag -t warning -m 'Leave ALIS OS?' -B 'Log out' 'swaymsg exit'
      bindsym $mod+Left focus left
      bindsym $mod+Right focus right
      bindsym $mod+Up focus up
      bindsym $mod+Down focus down
      ${lib.concatMapStrings (n: ''
        bindsym $mod+${n} workspace number ${n}
        bindsym $mod+Shift+${n} move container to workspace number ${n}
      '') [ "1" "2" "3" "4" "5" ]}

      bar {
        position top
        status_command while date +'%a %d %b  %H:%M'; do sleep 30; done
        colors {
          background ${c.bg}
          statusline ${c.text}
          focused_workspace  ${c.teal} ${c.teal} ${c.bg}
          inactive_workspace ${c.bg} ${c.bg} ${c.textDim}
        }
      }

      exec mako --background-color '${c.bg}' --border-color '${c.teal}' --text-color '${c.text}'
      include /etc/sway/config.d/*
    '');

    # Text login screen that starts the ALIS desktop.
    services.greetd = {
      enable = true;
      settings.default_session.command =
        "${pkgs.tuigreet}/bin/tuigreet --time --remember --asterisks --greeting 'Welcome to A.L.I.S OS' --cmd sway";
    };

    environment.systemPackages = with pkgs; [ chromium firefox nautilus ];
    fonts.packages = with pkgs; [ noto-fonts noto-fonts-color-emoji dejavu_fonts ];
    hardware.graphics.enable = true;
    services.pipewire = { enable = true; pulse.enable = true; };
    security.polkit.enable = true;
  };
}
