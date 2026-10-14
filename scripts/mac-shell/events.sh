#!/bin/bash
# Writes down what macOS really tells an Accessibility client, and in what order, after each thing Arbor or a
# person does to a window. FakeWindowSystem claims to "emit the same events macOS would"; this is the record
# it is held to. Nothing here is a check: the output is the point.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/events.sh      # then read events.txt in the output folder
#
# Each action is a `---` line in mac-shell/events.txt, followed by what scripts/mac-shell/axwatch.swift saw until
# the next one: seconds, source (ax <pid>, workspace, mouse), name, window, details. Commit it as
# collab/evidence/ax-events.txt when it has something new to say.
source "$(dirname "$0")/lib.sh"

arbor_build
for tool in ax axwatch; do
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/$tool.swift" -o "$ARBOR_ROOT/.build/mac-shell/$tool" \
    > "$ARBOR_OUT/build-$tool.log" 2>&1 || {
    cat "$ARBOR_OUT/build-$tool.log"
    die "scripts/mac-shell/$tool.swift did not compile"
  }
done
ARBOR_AX="$ARBOR_ROOT/.build/mac-shell/ax"
EVENTS="$ARBOR_OUT/events.txt"
# A setting of the person's, not of the session: only on a throwaway Mac.
if on_throwaway_mac; then macos_tiling off; fi

mkfifo "$ARBOR_SESSION_DIR/stdin2"
"$ARBOR_BIN/ArborTestWindows" --count 2 < "$ARBOR_SESSION_DIR/stdin2" > "$ARBOR_SESSION_DIR/hello2" 2>> "$ARBOR_OUT/test-windows.log" &
OTHER_PID=$!
started "$OTHER_PID"
exec 8> "$ARBOR_SESSION_DIR/stdin2"
sleep 2
read -r X1 X2 <<< "$(python3 -c 'import json, sys; print(*json.loads(sys.argv[1])["windows"])' "$(head -n 1 "$ARBOR_SESSION_DIR/hello2")")"
ARBOR_EXTRA_PIDS=$OTHER_PID
arbor_start 3
ARBOR_EXTRA_PIDS=""
P=$ARBOR_WINDOWS_PID

echo "# events.sh $(date -u +%Y-%m-%dT%H:%MZ) on macOS $(sw_vers -productVersion), commit $(git rev-parse --short HEAD)" > "$EVENTS"
echo "# app A: pid $P, windows $W1 $W2 $W3. app B: pid $OTHER_PID, windows $X1 $X2. Arbor arranges both." >> "$EVENTS"
"$ARBOR_ROOT/.build/mac-shell/axwatch" "$P" "$OTHER_PID" >> "$EVENTS" 2>&1 &
WATCHER=$!
started "$WATCHER"
# It runs until it is killed, and writes down every app that comes forward and every press.
at_exit 'kill_started $WATCHER $OTHER_PID'
sleep 1

# act "<what happens>" <command…>: a heading, the action, and time for everything that follows it to arrive
act() {
  echo "--- $1" >> "$EVENTS"
  echo "--- $1"
  shift
  "$@" > /dev/null 2>&1
  sleep "${WAIT:-1.5}"
}
arborctl() { "$ARBOR_BIN/arborctl" "$@"; }
tool() { "$ARBOR_AX" "$@"; }
# shellcheck disable=SC2046
click_on() { pointer click $(center_of "$1"); }

act "a person clicks A's window $W1 (floating, behind the others)" pointer click $(arbor_point $(frame_of "$W1") "x + 20" "y + h - 20")
act "Arbor: dock $W1 left (setFrame, then focus of a window that already has it)" arborctl dock "$W1" left
act "Arbor: dock $W2 right (setFrame, then focus of another window of the same app)" arborctl dock "$W2" right
act "Arbor: dock $X1 beside $W2 bottom (setFrame, then focus of ANOTHER app's window)" arborctl dock "$X1" beside "$W2" bottom
act "Arbor: zoom $W1 (one window grows, the others are parked, focus crosses apps)" arborctl zoom "$W1"
act "Arbor: back" arborctl back
act "a person clicks $W2 (same app as the focused window)" click_on "$W2"
act "a person clicks $X1 (the other app)" click_on "$X1"
act "a person clicks $W1" click_on "$W1"
act "minimize $W2 (not the focused window)" tool minimize "$P" "$W2" on
act "un-minimize $W2" tool minimize "$P" "$W2" off
act "Arbor: show-all (to undo what that did to the camera)" arborctl show-all
act "a person clicks $W1" click_on "$W1"
act "minimize $W1 (the focused window)" tool minimize "$P" "$W1" on
act "un-minimize $W1" tool minimize "$P" "$W1" off
act "Arbor: show-all" arborctl show-all
act "hide app A (it is in front)" tool hide "$P"
act "unhide app A" tool unhide "$P"
act "app B comes forward by itself (as with cmd-Tab or its Dock icon)" kill -USR1 "$OTHER_PID"
act "app A comes forward by itself" kill -USR1 "$P"
act "a person drags floating $W3 by its title bar, 60 points, within the Desktop" \
  pointer drag $(titlebar_of "$W3") $(arbor_point $(frame_of "$W3") "x + w / 2 + 10" "y + 72")
act "a person drags docked $W1's right edge 40 points" \
  pointer drag $(arbor_point $(frame_of "$W1") "x + w - 1" "y + h / 2") $(arbor_point $(frame_of "$W1") "x + w + 39" "y + h / 2")
act "a person double-clicks docked $W1's title bar" pointer click $(titlebar_of "$W1") 2
act "app A opens a new window (as with cmd-N)" kill -USR2 "$P"
act "close $W3 (floating; not the focused window)" tool close "$P" "$W3"
act "a person clicks $W2" click_on "$W2"
act "close $W2 (docked, focused; the app has other windows)" tool close "$P" "$W2"
WAIT=4
act "docked $W1 goes full screen" tool fullscreen "$P" "$W1" on
act "it leaves full screen" tool fullscreen "$P" "$W1" off
WAIT=1.5
act "Arbor: show-all" arborctl show-all
act "app B quits" kill -TERM "$OTHER_PID"
act "Arbor: float-all" arborctl float-all

kill -TERM "$WATCHER" 2> /dev/null
exec 8>&-
ARBOR_WINDOW_IDS=$W1
summary
arbor_stop
echo
cat "$EVENTS"
