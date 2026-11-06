#!/usr/bin/env bash
# ALIS OS weekly version update — runs on dev-automation (Sunday 04:15).
#
# Moves nixpkgs + the ALIS module repos to their latest versions, checks that
# EVERY ALIS OS machine still builds (for real, not just on paper) and the
# assistant test passes, and only then pushes to GitHub. The machines pick it
# up on their next nightly update. If anything fails, nothing is pushed and
# your phone gets an alis-push notification.
#
#   install:  tools/install-weekly-update.sh   (on dev-automation, once)
#   run now:  systemctl --user start alis-os-weekly
#   log:      journalctl --user -u alis-os-weekly
set -euo pipefail
repo=${ALIS_OS_REPO:-$HOME/alis-os}
nix=(nix --extra-experimental-features "nix-command flakes")
cd "$repo"

push() {   # phone notification via alis-push on this VM (localhost only)
  curl -s -m 10 -X POST http://127.0.0.1:8091/api/notify -H 'Content-Type: application/json' \
    -d "{\"title\": \"$1\", \"body\": \"$2\", \"tag\": \"alis-os-weekly\"}" >/dev/null || true
}
fail() { echo "FAILED: $1"; git checkout -- flake.lock 2>/dev/null || true; push "ALIS OS weekly update stopped" "$1 — nothing was pushed, machines stay as they are."; exit 1; }
trap 'fail "unexpected error (journalctl --user -u alis-os-weekly)"' ERR

git pull --ff-only --quiet
"${nix[@]}" flake update 2>&1 | grep -v '^warning' || true
if git diff --quiet flake.lock; then echo "Nothing new this week."; exit 0; fi
git --no-pager diff --stat flake.lock

echo "Checking every machine still builds..."
for m in machines/*/; do
  m=$(basename "$m")
  echo "  - $m"
  "${nix[@]}" build --no-link ".#nixosConfigurations.$m.config.system.build.toplevel" 2>&1 | tail -n 3 \
    || fail "$m doesn't build with the new versions"
done
"${nix[@]}" flake check --no-build 2>&1 | grep -v '^warning' || fail "the ALIS OS recipe has an error"
python3 tests/assistant_test.py >/tmp/alis-assistant-test.log 2>&1 || fail "the ALIS Assistant test failed"

git add flake.lock
git commit -q -m "Weekly update $(date +%F): newer nixpkgs and ALIS modules (all machines build)"
git push -q
"${nix[@]}" store gc --max 20G >/dev/null 2>&1 || true   # keep dev-automation's disk in check
echo "Pushed. Machines pick it up on their next nightly update."
push "ALIS OS weekly update ready" "New versions checked on every machine and pushed; they'll install overnight and apply on restart."
