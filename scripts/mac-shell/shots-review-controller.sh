#!/bin/bash
# Real-window checks for the controller review of 2026-10-14:
# what the camera does about focus, minimizing and macOS's own full screen, and where floating windows go.
# These depend on which Accessibility notifications macOS sends and in what order, which the fakes only assume.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-review-controller.sh
#
# Two processes with test windows: W1 W2 W3 (W3 refuses to be smaller than 700×500) and X1 X2.
source "$(dirname "$0")/lib.sh"

arbor_build
AXTOOL="$ARBOR_ROOT/.build/mac-shell/axtool"
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/axtool.swift" -o "$AXTOOL" > "$ARBOR_OUT/build-axtool.log" 2>&1 \
  || { cat "$ARBOR_OUT/build-axtool.log"; die "scripts/mac-shell/axtool.swift did not compile"; }
ax() {
  echo "> axtool $*"
  "$AXTOOL" "$@"
}

# What Arbor logged since the last call, without the date.
LOG_MARK=0
log_since() {
  tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | cut -c 26- | tail -n "${1:-25}"
  LOG_MARK=$(wc -l < "$ARBOR_HOME/arbor.log")
}

not() { ! "$@"; }
# left_of <a> <b>: a ends before b begins
left_of() {
  local ax aw bx
  read -r ax _ aw _ <<< "$(frame_of "$1")"
  read -r bx _ _ _ <<< "$(frame_of "$2")"
  [ "$((ax + aw))" -le "$bx" ]
}
# in_slot <id>: the window server has the window where Arbor's layout wants it, give or take 3 points
in_slot() {
  local sx sy sw sh rx ry rw rh
  read -r sx sy sw sh <<< "$(arbor_ask slot "$1")" || return 1
  read -r rx ry rw rh <<< "$(real_frame_of "$1")"
  python3 -c 'import sys; v = [float(x) for x in sys.argv[1:]]; sys.exit(0 if all(abs(a - b) <= 3 for a, b in zip(v[:4], v[4:])) else 1)' \
    "$sx" "$sy" "$sw" "$sh" "$rx" "$ry" "$rw" "$rh"
}

step "a second process with two windows"
mkfifo "$ARBOR_SESSION_DIR/stdin2"
"$ARBOR_BIN/ArborTestWindows" --count 2 < "$ARBOR_SESSION_DIR/stdin2" > "$ARBOR_SESSION_DIR/hello2" 2>> "$ARBOR_OUT/test-windows.log" &
OTHER_JOB=$!
started "$OTHER_JOB"
at_exit 'kill_started $OTHER_JOB'
exec 8> "$ARBOR_SESSION_DIR/stdin2"
tries=0
hello2=""
while [ -z "$hello2" ] && [ "$tries" -lt 100 ]; do
  sleep 0.1
  hello2=$(head -n 1 "$ARBOR_SESSION_DIR/hello2" 2>/dev/null)
  tries=$((tries + 1))
done
P2=$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["pid"])' "$hello2") || die "no second process: $hello2"
read -r X1 X2 <<< "$(python3 -c 'import json, sys; print(*json.loads(sys.argv[1])["windows"])' "$hello2")"
echo "second process $P2 with windows $X1 $X2"

ARBOR_TEST_WINDOWS_ARGS="--min-size 3:700x500"
ARBOR_EXTRA_PIDS=$P2
arbor_start 3
ARBOR_EXTRA_PIDS=""
P1=$ARBOR_WINDOWS_PID
check "Arbor manages the second process's windows too" eventually is managed "$X1"
summary
shot 01-start

step "1. docking a window that cannot fit its slot leaves a tile and the camera where it was"
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W2" bottom
sleep 1.5
check "not focused before: it is a tile" is tile "$W3"
check "not focused before: the other windows are still in view" is on_screen "$W1"
shot 02-dock-too-big
ctl float "$W3"
sleep 0.5
check "floating again, it is wholly on the screen although the Desktop is too narrow for it" is on_screen "$W3"
echo "the window server has it at: $(real_frame_of "$W3"); the Desktop is at: $(arbor_ask desktop)"
shot 03-float-too-big
# shellcheck disable=SC2046
click $(titlebar_of "$W3")
check "the click focused it" eventually is focused "$W3"
ctl dock "$W3" beside "$W2" bottom
sleep 1.5
check "focused before: it is a tile" is tile "$W3"
check "focused before: the other windows are still in view" is on_screen "$W1"
summary
log_since 30

step "2. floating windows are pushed off docked space, wherever they were"
ctl float-all
sleep 0.5
summary
ctl dock "$W1" left
sleep 0.5
for id in "$W2" "$X1" "$X2"; do
  check "window $id is beside the docked window, not under or over it" left_of "$W1" "$id"
done
shot 04-pushed
summary

step "3. giving a parked window of the frontmost app the keyboard reveals it"
ctl dock "$W2" right
# Out of the way as a tile: floating, it is wider than the Desktop and could cover a title bar.
ctl dock "$W3" beside "$W2" bottom
# shellcheck disable=SC2046
click $(titlebar_of "$W1")
check "the click focused the first window" eventually is focused "$W1"
ctl zoom "$W1"
check "the second window is parked" eventually is parked "$W2"
log_since 0 > /dev/null
ax raise "$P1" "$W2"
check "the camera moved to show it" eventually is on_screen "$W2"
ax front
log_since
summary
shot 05-revealed

step "4. an app in the background changing its focused window does not move the camera"
# shellcheck disable=SC2046
click $(titlebar_of "$W1")
check "the click focused the first window" eventually is focused "$W1"
ctl zoom "$W1"
check "the other process's windows are parked" eventually is parked "$X2"
ax list "$P2"
log_since 0 > /dev/null
ax set "$P2" "$X1" AXMain yes
sleep 0.4
ax set "$P2" "$X2" AXMain yes
sleep 1.6
ax front
echo "what Arbor heard (no focus report at all means macOS does not send one for this, and the check proves nothing):"
log_since
check "the camera is still on the first window" is parked "$X2"
check "the first window still has the keyboard" is focused "$W1"
shot 06-background-focus

step "5. bringing an app to the front whose focused window did not change (⌘Tab, a click in the Dock)"
log_since 0 > /dev/null
ax activate "$P2"
sleep 2
ax front
log_since
# Not a check: the review expects this to fail until the Accessibility layer also reports app activation.
if is parked "$X1" && is parked "$X2"; then
  echo "note: the app came to the front and both of its windows are still parked: activation is not reported"
else
  echo "note: a window of the app was revealed"
fi
summary
shot 07-activated

step "6. minimizing and restoring a docked window"
ctl show-all
# shellcheck disable=SC2046
click $(titlebar_of "$W1")
sleep 0.3
log_since 0 > /dev/null
ax set "$P1" "$W2" AXMinimized yes
check "Arbor sees it minimized" eventually is minimized "$W2"
sleep 1
summary
ax set "$P1" "$W2" AXMinimized no
check "Arbor sees it restored" eventually not is minimized "$W2"
sleep 2
log_since
check "it is back in its slot" eventually in_slot "$W2"
check "the camera did not zoom onto it: the first window is still in view" is on_screen "$W1"
summary
shot 08-restored

step "7. macOS's own full screen"
log_since 0 > /dev/null
ax set "$P1" "$W1" AXFullScreen yes
sleep 3
ax list "$P1"
echo "the window server has it at: $(real_frame_of "$W1")"
summary
echo "Arbor's own windows:"
overlays
shot 09-full-screen
log_since 40
if is fullScreen "$W1"; then
  check "Arbor does not count it as parked" not is parked "$W1"
  check "it keeps its slot in the tree" is docked "$W1"
  check "no tile stands in for it" not is tile "$W1"
  ax set "$P1" "$W1" AXFullScreen no
  sleep 3
  ax list "$P1"
  log_since 40
  check "Arbor sees that it left full screen" eventually not is fullScreen "$W1"
  check "it is back in its slot" eventually in_slot "$W1"
  check "it is not taken for a window that refuses to shrink" not is tile "$W1"
  # macOS 26 moves the app's parked windows onto the screen when one of its windows leaves full screen.
  check "the window that was parked all along is out of view again" eventually not is on_screen "$W3"
  summary
  shot 10-left-full-screen
else
  echo "note: the window did not go into full screen, or Arbor did not notice; see the list and the log above"
fi

arbor_stop 11-after-quit
# Never `wait` for it alone: on the first run it did not see its stdin close, and the script hung until it was cancelled.
exec 8>&-
arbor_await_exit "$OTHER_JOB" 20 || kill -TERM "$OTHER_JOB" 2>/dev/null
arbor_await_exit "$OTHER_JOB" 20 || kill -KILL "$OTHER_JOB" 2>/dev/null
