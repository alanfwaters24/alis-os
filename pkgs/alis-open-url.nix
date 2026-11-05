# alis-open-url [--wait SECONDS] URL [URL...] [-- chromium flags...]
#
# Opens the first address that answers as an app window. The last address is
# used if none answer (e.g. the dashboard's built-in copy). Lets laptops try
# the home network first and fall back to Tailscale when away.
{ writeShellScriptBin, curl, chromium }:
writeShellScriptBin "alis-open-url" ''
  wait=4
  urls=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --wait) wait=$2; shift 2 ;;
      --) shift; break ;;
      *) urls+=("$1"); shift ;;
    esac
  done
  [ "''${#urls[@]}" -gt 0 ] || { echo "alis-open-url: no address given" >&2; exit 1; }
  pick=''${urls[-1]}
  for u in "''${urls[@]:0:''${#urls[@]}-1}"; do
    if ${curl}/bin/curl -sk -o /dev/null --max-time "$wait" "$u"; then pick=$u; break; fi
    echo "alis-open-url: $u not answering, trying the next address" >&2
  done
  exec ${chromium}/bin/chromium --app="$pick" --password-store=basic "$@"
''
