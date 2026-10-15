#!/bin/bash
# All frames of one act in one breath, with real apps. Test windows answer a new frame in 2 to 4 ms, and asked side by side they
# arrive no closer together than asked one by one (scripts/mac-shell/probe-breath.sh, films-breath.sh). But real apps take 20 to 240 ms
# a move, and nine of them, asked one after the other, were seen to arrive over 0.6 to 0.7 s. There the sum and the longest differ.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-breath-apps.sh
#
# The question only a Mac can answer: seven stock apps, a window each, from a pile to a grid and back: how long from the first change
# to the last when they are asked one by one, and when they are asked side by side? Arbor does not run.
# The ways take turns, three times four rounds each, with a rest of a second and a half: a hosted Mac drifts within minutes.
# For GitHub's Macs (lib-apps.sh opens real apps). Four minutes after the build.
source "$(dirname "$0")/lib-apps.sh"

apps_watchdog 900
step "the Mac"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m), $(sysctl -n hw.ncpu) cores"
apps_build
BREATH="$ARBOR_ROOT/.build/mac-shell/breath"
if [ -z "${ARBOR_BUILT:-}" ]; then
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/breath.swift" -o "$BREATH" > "$ARBOR_OUT/build-breath.log" 2>&1 \
    || { cat "$ARBOR_OUT/build-breath.log"; die "scripts/mac-shell/breath.swift did not compile"; }
fi
display_mode 1920x1080 1680x1050 1600x900
apps_scratch

step "seven apps, a window each"
PIDS=""
open_one() {
  if app_open "$@"; then
    app_dismiss "$APP_PID"
    PIDS="$PIDS $APP_PID"
    echo "$1: pid $APP_PID, windows $APP_WINDOWS"
  else
    echo "$1 did not open a window: left out"
  fi
}
open_one com.apple.finder "$APPS_SCRATCH/grove"
open_one com.apple.Safari "$APPS_SCRATCH/page.html"
open_one com.apple.TextEdit "$APPS_SCRATCH/oak.txt"
open_one com.apple.Terminal
open_one com.apple.Notes
open_one com.apple.iCal
open_one com.apple.Preview "$APPS_SCRATCH/leaf.png"
echo "processes:$PIDS"
sleep 2

for turn in 1 2 3; do
  for way in one-by-one side-by-side; do
    step "$way, turn $turn"
    # shellcheck disable=SC2086
    BREATH_PILE=760x520 BREATH_REST=1.5 BREATH_EACH=1 limit 90 "$BREATH" "$way" 4 $PIDS
    sleep 1
  done
done
exit 0
