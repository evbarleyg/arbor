#!/bin/bash
# Runs a dock/zoom/back script through arbor-sim and checks the result, so
# `make check` exercises the real controller end to end without permissions.
set -euo pipefail
cd "$(dirname "$0")/.."

output=$(.build/debug/arbor-sim \
  "open Safari" "open Notes" "open Mail" \
  "dock 101 left" "dock 102 right" "dock 103 beside 101 bottom" \
  "zoom 101" "back" "quiet" "state")

fail() {
  echo "sim smoke test failed: $1"
  echo "$output"
  exit 1
}

grep -q "docked w103 below w101" <<<"$output" || fail "docking beside did not report success"
grep -q "framed w101" <<<"$output" || fail "zoom did not report success"
grep -q "hidden: w102 Notes w103 Mail" <<<"$output" || fail "zoom did not hide the other windows"
grep -q "back to everything" <<<"$output" || fail "back did not return to the overview"
grep -q "n0 desktop" <<<"$output" || fail "state is missing the Desktop"

# Numbers no window or pointer ever has. The simulator and the commands refuse them, which `expect fail` says is
# meant (arbor-sim exits with 1 for a failure nobody expected, and with more than that when it crashes).
output=$(.build/debug/arbor-sim quiet "open Safari" "dock 101 left" \
  "resize 101 right 1e300" "expect fail" "resize 101 right nan" "expect fail" "frame-rect 0 0 inf 5" "expect fail" \
  "cursor 1e300 0" "expect fail" "drag 101 1e300 0" "expect fail" "seam 1e300 0" "expect fail" "seam 0 inf" "expect fail" \
  "pull 101 right -inf" "expect fail" "move 101 0 0 nan 5" "expect fail" \
  "open Notes 500x-inf" "ascii") || fail "an absurd number was accepted, or crashed the simulator"
[ "$(grep -c "at most ±1000000" <<<"$output")" = 3 ] || fail "a command accepted an absurd number"
[ "$(grep -c "^usage: " <<<"$output")" = 6 ] || fail "the simulator accepted an absurd number"
grep -q "w101 Safari" <<<"$output" || fail "the layout did not survive absurd numbers"

# The settings commands on a real file, as the app wires it. The words `settings` and `rule` are the product's: the
# simulator must pass them on (it once had commands of its own by those names).
folder=$(mktemp -d) || fail "no temporary folder"
trap 'rm -rf "$folder"' EXIT
printf '{\n  "gap": 8.0,\n  "myNote": "mine"\n}\n' > "$folder/settings.json"
output=$(.build/debug/arbor-sim quiet "settings-file $folder/settings.json" "set gap 20" "get gap" \
  "rule add com.example.mail dock left title Inbox" "rules" "settings") || fail "a settings command failed"
grep -q "^\* gap = 20 " <<<"$output" || fail "settings does not list the changed gap"
[ "$(head -n 3 "$folder/settings.json")" = "$(printf '{\n  "gap": 20,\n  "myNote": "mine",')" ] \
  || fail "set changed more of settings.json than the gap"
echo "sim smoke test passed"

# The same for the control socket: the real arborctl against the simulator.
./scripts/watch-smoke.sh
./scripts/cli-smoke.sh

# On a Mac, the one commit that is the release candidate is also built the way `make install` builds it. The script says why.
if [ "$(uname)" = Darwin ] && ./scripts/candidate-check.sh --is-candidate; then ./scripts/candidate-check.sh; fi
