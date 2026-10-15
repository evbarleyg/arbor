#!/bin/bash
# Which of three steps of CI's Mac job raises the system alert that then lies over the test windows' title bars, and what does it say?
# For GitHub's Macs only, which are thrown away: it takes pictures of the whole screen.
[ "${GITHUB_ACTIONS:-}" = true ] && [ "$(id -un)" = runner ] || { echo "skipped: for one of GitHub's Macs only"; exit 77; }
cd "$(dirname "$0")/../.." || exit 2
mkdir -p mac-shell
alerts() { .build/mac-shell/pointer windows 2>/dev/null | grep -E " on (UserNotificationCenter|CoreServicesUIAgent|SecurityAgent|universalAccessAuthWarn|loginwindow)" ; }
look() {
  echo "-- after $1: $(alerts | wc -l | tr -d ' ') alert(s) on screen"
  alerts
  # safe anywhere: the script has ended by now anywhere but on one of GitHub's Macs, where nobody has anything open
  screencapture -x "mac-shell/after-$1.png"
}
look nothing
for step in sim-smoke scenarios release-tools-test; do
  began=$SECONDS
  "./scripts/$step.sh" > "mac-shell/$step.log" 2>&1
  echo "$step.sh: exit $?, $((SECONDS - began)) s"
  sleep 2
  look "$step"
done
# What macOS itself wrote down about asking.
log show --last 5m --style compact --predicate 'subsystem == "com.apple.TCC" AND eventMessage CONTAINS[c] "prompt"' 2>/dev/null | tail -n 12 | cut -c 1-260
