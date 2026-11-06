# The name Chromium gives an --app window on Wayland (KDE matches it to an
# app's .desktop file to show the right icon instead of a generic "W"):
#   chrome-<host>_<path with / -> _>-<profile directory>
# The port is left out, so ALIS apps on one host only differ by profile.
# Checked against Chromium 156 under sway:
#   http://localhost:8080 + profile alis-nest   -> chrome-localhost__-alis-nest
#   http://127.0.0.1:8080/x/y + Default          -> chrome-127.0.0.1__x_y-Default
#   file:///etc/pane/start.html + Default        -> chrome-__etc_pane_start.html-Default
{ lib }:
url: profile:
let
  m = builtins.match "[a-z]+://([^/:?#]*)(:[0-9]+)?(/[^?#]*)?.*" url;
  host = builtins.elemAt m 0;
  path = let p = builtins.elemAt m 2; in if p == null then "/" else p;
in
assert lib.assertMsg (m != null) "chrome-app-id: can't read ${url}";
"chrome-${host}_${lib.replaceStrings [ "/" ] [ "_" ] path}-${profile}"
