#!/bin/bash
# The claims in collab/parity.json that a person makes true with a mouse, a keyboard, a title-bar button or
# another app, tried on real windows with real input. arbor-e2e proves the commands; this proves the
# gestures TrellisWM's own documentation describes.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/proof.sh
#
# Each `claim` is a step in the form scripts/parity.py reads, so an item's "e2e" list can name it once the
# run's output.txt has been committed as collab/evidence/gestures-latest.txt. A ✘ is a finding, not a
# broken script: the run then exits with 1 and the step counts as failed.
#
# Session 1  drags (screen edge, a window's edge, out onto the Desktop), minimize, hide, close, windows that
#            are not standard windows, a restart, arbor:// URLs
# Session 2  every shortcut TrellisWM publishes, pressed on a real keyboard; then a tile, a seam, a window's
#            own edge, a ⌃⌥ rectangle, float-all
# Session 3  two apps: Arbor focusing the other app's window, and the other app coming forward by itself
#            while its window is out of view
# Session 4  a docked window goes full screen and comes back (docs/features/F30-full-screen-windows.md)
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/lib-gestures.sh"

echo "# proof.sh $(date -u +%Y-%m-%dT%H:%MZ) on macOS $(sw_vers -productVersion), commit $(git rev-parse --short HEAD), real pointer and keys"
arbor_build
ARBOR_AX="$ARBOR_ROOT/.build/mac-shell/ax"
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/ax.swift" -o "$ARBOR_AX" > "$ARBOR_OUT/build-ax.log" 2>&1 || {
  cat "$ARBOR_OUT/build-ax.log"
  die "scripts/mac-shell/ax.swift did not compile"
}
# A setting of the person's, not of the session: only on a throwaway Mac.
if on_throwaway_mac; then macos_tiling off; fi

claim() { echo; echo "▸ $*"; }
ax() {
  echo "> ax $*"
  "$ARBOR_AX" "$@"
}
not() { ! "$@"; }
in_view() { arbor_ask slot "$1" > /dev/null 2>&1; }
gone() { not arbor_ask frame "$1" > /dev/null 2>&1; }

# near "x y w h" "x y w h": both are there and no number differs by more than two points
near() {
  echo "$1 $2" | awk '{ if (NF != 8) exit 1; for (i = 1; i <= 4; i++) { d = $i - $(i + 4); if (d < -2 || d > 2) exit 1 } }'
}
inside_the_gaps() {
  local x y w h
  read -r x y w h <<< "$(arbor_ask screen)"
  echo "$((x + ARBOR_GAP)) $((y + ARBOR_GAP)) $((w - 2 * ARBOR_GAP)) $((h - 2 * ARBOR_GAP))"
}
# The window server has the window where Arbor's layout puts it.
in_its_slot() { near "$(real_frame_of "$1")" "$(arbor_ask slot "$1" 2> /dev/null)"; }
fills() { near "$(real_frame_of "$1")" "$(inside_the_gaps)" && in_its_slot "$1"; }
desktop_fills() { near "$(arbor_ask desktop 2> /dev/null)" "$(inside_the_gaps)"; }
height_of() { real_frame_of "$1" | awk '{ print int($4) }'; }
taller_than() { [ "$(height_of "$1")" -gt "$2" ]; }
shorter_than() { [ "$(height_of "$1")" -lt "$2" ]; }
is_at() { near "$(real_frame_of "$1")" "$2"; }
forget_window() { ARBOR_WINDOW_IDS=$(for id in $ARBOR_WINDOW_IDS; do [ "$id" = "$1" ] || printf '%s ' "$id"; done); }
arbor_ready() { "$ARBOR_BIN/arborctl" state 2> /dev/null | python3 "$ARBOR_STATE_PY" ready "$1" 2> /dev/null; }

# Quits Arbor and starts it again ($2: another binary) on the same windows and the same home folder.
# Not under `check`, which runs what it checks in a shell of its own: ARBOR_PID would stay that of the Arbor that has quit.
arbor_relaunch() {
  "$ARBOR_BIN/arborctl" quit > /dev/null
  arbor_await_exit "$ARBOR_PID" 50 || kill -KILL "$ARBOR_PID" 2> /dev/null
  wait "$ARBOR_PID" 2> /dev/null
  env ARBOR_ONLY_PIDS="$ARBOR_WINDOWS_PID" ARBOR_NO_PROMPT=1 ARBOR_DEBUG=1 ARBOR_NO_HOTKEYS=1 ARBOR_NO_STATUS_ITEM=1 ARBOR_NO_WATCHDOG=1 \
    "${2:-$ARBOR_BIN/Arbor}" >> "$ARBOR_OUT/arbor-stderr-relaunch.log" 2>&1 9>&- &
  ARBOR_PID=$!
  started "$ARBOR_PID"
  eventually arbor_ready "$1" || eventually arbor_ready "$1"
}

# MARK: Session 1

step "session 1: four windows, a utility panel and a sheet"
ARBOR_TEST_WINDOWS_ARGS="--extras"
arbor_start 4
read -r sx sy sw sh <<< "$(arbor_ask screen)"
edge_y=$((sy + sh / 2))
summary
echo "what Accessibility lists for the test process (id role subrole minimized full-screen x y w h):"
"$ARBOR_AX" list "$ARBOR_WINDOWS_PID"
echo "what the window server lists for it (id pid layer x y w h on owner):"
pointer windows --pid "$ARBOR_WINDOWS_PID"

claim "windows that are not standard windows are left alone"
managed=$(state | python3 -c 'import json, sys; print(sum(1 for w in json.load(sys.stdin)["windows"] if w["managed"]))')
server=$(pointer windows --pid "$ARBOR_WINDOWS_PID" | awk '$3 == 0 || $3 == 3' | wc -l | tr -d ' ')
echo "Arbor manages $managed windows; the window server has $server at the normal and floating levels"
check "the test process has more windows than the four standard ones" test "$server" -gt 4
check "Arbor manages exactly the four standard windows" test "$managed" -eq 4
panel=$("$ARBOR_AX" list "$ARBOR_WINDOWS_PID" | awk '$3 != "AXStandardWindow" { print $1; exit }')
panel_before=""
[ -n "$panel" ] && panel_before=$(real_frame_of "$panel")
echo "the first window Accessibility lists that is not standard: ${panel:-none} at ${panel_before:-nowhere}"

claim "drag a window to the left screen edge"
# shellcheck disable=SC2046
drag $(titlebar_of "$W4") "$((sx + 3))" "$edge_y" --no-release
check "a drop preview shows while the button is held" has_overlay 3
release
check "the window is docked" eventually is docked "$W4"
check "the window server has it in its slot" eventually in_its_slot "$W4"
shot 01-edge-drag
summary

claim "drop a window on another window's lower edge"
read -r x y w h <<< "$(frame_of "$W4")"
# shellcheck disable=SC2046
drag $(titlebar_of "$W3") "$((x + w / 2))" "$((y + h - 30))" --no-release
check "a drop preview shows while the button is held" has_overlay 3
shot 02-window-edge-held
release
check "the window is docked" eventually is docked "$W3"
check "the window server has it in its slot" eventually in_its_slot "$W3"
read -r x3 y3 _ _ <<< "$(frame_of "$W3")"
read -r x4 y4 _ h4 <<< "$(frame_of "$W4")"
check "it sits below the window it was dropped on, in the same column" test "$x3" -eq "$x4" -a "$y3" -ge "$((y4 + h4))"
summary

claim "drag a docked window out onto the Desktop"
read -r dx dy dw dh <<< "$(arbor_ask desktop)"
# shellcheck disable=SC2046
drag $(titlebar_of "$W3") "$((dx + dw / 2))" "$((dy + dh / 2))"
check "the window floats" eventually is floating "$W3"
check "its old neighbour takes the whole column" eventually taller_than "$W4" "$((sh - 60))"
summary

claim "minimize a docked window and bring it back"
ctl dock "$W3" beside "$W4" bottom
check "two windows share the column" eventually shorter_than "$W4" "$((sh / 2 + 20))"
slot3=$(arbor_ask slot "$W3")
ax minimize "$ARBOR_WINDOWS_PID" "$W3" on
check "Arbor sees it minimized" eventually is minimized "$W3"
check "its neighbour takes the space" eventually taller_than "$W4" "$((sh - 60))"
ax minimize "$ARBOR_WINDOWS_PID" "$W3" off
check "the neighbour gives the space back" eventually shorter_than "$W4" "$((sh / 2 + 20))"
check "the window is back in the same slot" eventually is_at "$W3" "$slot3"
check "the camera stayed where it was" in_view "$W4"
summary
ctl show-all

claim "hide the app and show it again"
slot4=$(arbor_ask slot "$W4")
ax hide "$ARBOR_WINDOWS_PID"
check "Arbor sees its windows hidden" eventually is hidden "$W4"
ax unhide "$ARBOR_WINDOWS_PID"
check "Arbor sees them again" eventually not is hidden "$W4"
check "the docked windows are back in their slots" eventually is_at "$W4" "$slot4"
check "and so is the second one" eventually is_at "$W3" "$slot3"
summary

claim "the panel and the sheet stayed out of it"
ctl dock "$W1" right
if [ -n "$panel" ]; then
  check "the panel is where it was before anything was arranged" is_at "$panel" "$panel_before"
else
  check "Accessibility lists a window that is not standard" false
fi
echo "the window server now (the sheet is 220 wide and belongs to the first window):"
pointer windows --pid "$ARBOR_WINDOWS_PID"
read -r x1 y1 w1 h1 <<< "$(frame_of "$W1")"
sheet_inside=$(pointer windows --pid "$ARBOR_WINDOWS_PID" \
  | awk -v x="$x1" -v y="$y1" -v w="$w1" -v h="$h1" '$6 == 220 { cx = $4 + $6 / 2; cy = $5 + $7 / 2; if (cx > x && cx < x + w && cy > y && cy < y + h) print "yes" }')
check "the sheet moved with its window" test "$sheet_inside" = yes
shot 03-panel-and-sheet

claim "close a docked window"
ax close "$ARBOR_WINDOWS_PID" "$W3"
forget_window "$W3"
check "Arbor forgets it" eventually gone "$W3"
check "its neighbour takes the space" eventually taller_than "$W4" "$((sh - 60))"
summary
ctl show-all

claim "the arrangement survives a restart"
ctl zoom "$W4"
check "one window is framed and the other docked one is out of view" eventually is parked "$W1"
arbor_relaunch 3
check "Arbor comes up again on the same windows" [ $? -eq 0 ]
summary
check "the left window is docked again" is docked "$W4"
check "the right window is docked again" is docked "$W1"
check "a launch shows everything: the window that was out of view is in its slot" eventually in_its_slot "$W1"
check "and so is the one that was framed" eventually in_its_slot "$W4"
ctl back
check "the view of last time is one step back: the framed window fills the screen" eventually fills "$W4"
check "and the other one is out of view" eventually is parked "$W1"
ctl show-all
check "everything comes back into its slot" eventually in_its_slot "$W1"

# It installs a bundle where `make install` puts the person's own, registers it and later removes it, so: only on a
# throwaway Mac.
if on_throwaway_mac; then
  claim "a URL runs a command"
  # Where `make install` puts it: LaunchServices does not register what lies under /tmp.
  app="$HOME/Applications/Arbor.app"
  rm -rf "$app"
  mkdir -p "$app/Contents/MacOS"
  cp "$ARBOR_BIN/Arbor" "$app/Contents/MacOS/Arbor"
  cp "$ARBOR_ROOT/Resources/Info.plist" "$app/Contents/Info.plist"
  codesign --force --sign - "$app" 2>&1 | tail -n 1
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R -trusted "$app"
  arbor_relaunch 3 "$app/Contents/MacOS/Arbor"
  check "Arbor comes up from a bundle" [ $? -eq 0 ]
  echo "> open arbor://zoom/$W1"
  open "arbor://zoom/$W1"
  check "arbor://zoom/<id> framed the window" eventually fills "$W1"
  check "so the other docked window is out of view" eventually not in_view "$W4"
  echo "> open arbor://show-all"
  open "arbor://show-all"
  check "arbor://show-all showed everything" eventually in_view "$W4"
  echo "> open arbor://zoom-out (TrellisWM's spelling), from a framed window"
  "$ARBOR_BIN/arborctl" zoom "$W1" > /dev/null
  open "arbor://zoom-out"
  check "arbor://zoom-out stepped out" eventually in_view "$W4"
  instances=$(pgrep -f "$app/Contents/MacOS/Arbor" | wc -l | tr -d ' ')
  check "the URLs went to the running Arbor, not to a second one" test "$instances" -eq 1
  grep -i "url" "$ARBOR_HOME/arbor.log" | tail -n 5
else
  echo
  echo "skipped: a URL runs a command (it would replace ~/Applications/Arbor.app; runs only on GitHub's Macs)"
fi

claim "quitting puts every window back in view"
arbor_stop 04-after-quit
if on_throwaway_mac; then
  pkill -f "$app/Contents/MacOS/Arbor" 2> /dev/null
  rm -rf "$app"
fi

# MARK: Session 2

step "session 2: the published keyboard, on [ [W1 / W3] | Desktop | W2 ] with W4 floating"
# The fourth window refuses to be smaller than 700×500, for the tile further down.
ARBOR_TEST_WINDOWS_ARGS="--min-size 4:700x500"
# For the ⌃⌥ rectangle further down.
arbor_settings "{$ARBOR_GESTURES_ON}"
arbor_start 4 ARBOR_NO_HOTKEYS=0
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W1" bottom
# shellcheck disable=SC2046
click $(center_of "$W1")
check "a click focuses the first window" eventually is focused "$W1"
summary

claim "⌃⌥↩ frames the focused window"
key ctrl+opt+return
check "it fills the screen" eventually fills "$W1"
check "the others are out of view" eventually is parked "$W2"

claim "⌃⌥→ and ⌃⌥← move to the neighbouring space"
key ctrl+opt+right
check "right of the first column is the Desktop" eventually desktop_fills
key ctrl+opt+right
check "right of the Desktop is the second window" eventually fills "$W2"
key ctrl+opt+left
check "and back to the left is the Desktop" eventually desktop_fills

claim "⌃⌥[ and ⌃⌥] go back and forward"
key "ctrl+opt+["
check "back is the second window" eventually fills "$W2"
key "ctrl+opt+]"
check "forward is the Desktop again" eventually desktop_fills

claim "⌃⌥⇧1 saves the view, ⌃⌥Space shows everything, ⌃⌥1 returns"
key "ctrl+opt+["
check "the second window is framed" eventually fills "$W2"
key ctrl+opt+shift+1
key ctrl+opt+space
check "⌃⌥Space brings the first window into its slot" eventually in_its_slot "$W1"
check "and the second" eventually in_its_slot "$W2"
check "and the third" eventually in_its_slot "$W3"
key ctrl+opt+1
check "⌃⌥1 frames the second window again" eventually fills "$W2"

claim "⌃⌥↑ steps out and ⌃⌥↓ steps in toward the pointer"
key ctrl+opt+up
check "out of the second window is everything" eventually in_its_slot "$W1"
# shellcheck disable=SC2046
move $(center_of "$W3")
key ctrl+opt+down
check "in, with the pointer over the third window, is its column" eventually is parked "$W2"
check "which shows both of its windows" in_view "$W1"
# shellcheck disable=SC2046
move $(center_of "$W3")
key ctrl+opt+down
check "in again is the third window on its own" eventually fills "$W3"
key ctrl+opt+space
check "and ⌃⌥Space shows everything again" eventually in_its_slot "$W2"
shot 05-after-the-keys

claim "a window that cannot shrink to its slot becomes a tile, and a click on the tile goes in"
ctl dock "$W4" beside "$W2" bottom
# Known: the dock command's own focus call echoes back and moves the camera (screenshots report, finding 2).
sleep 0.7
ctl show-all
check "it is a tile" eventually is tile "$W4"
check "and out of view" eventually not is on_screen "$W4"
shot 06-tile
# shellcheck disable=SC2046
click $(tile_of "$W4")
check "the click framed it" eventually is on_screen "$W4"
check "and put the others out of view" eventually is parked "$W1"
ctl show-all

claim "drag the gap between two windows"
read -r _ _ before _ <<< "$(frame_of "$W1")"
other=$(real_frame_of "$W2")
read -r seam_x seam_y <<< "$(seam_right_of "$W1")"
drag "$seam_x" "$seam_y" "$((seam_x + 60))" "$seam_y"
sleep 0.5
read -r _ _ after _ <<< "$(frame_of "$W1")"
echo "the window left of the gap was $before wide and is now $after"
check "the window left of the gap is about 60 points wider" test "$((after - before))" -ge 45 -a "$((after - before))" -le 75
check "the window server agrees" eventually in_its_slot "$W1"
check "the window on the far side did not move" is_at "$W2" "$other"

claim "drag a docked window's own edge"
read -r x y w h <<< "$(frame_of "$W2")"
drag "$((x + 1))" "$((y + h / 2))" "$((x - 39))" "$((y + h / 2))"
sleep 0.5
read -r _ _ after _ <<< "$(frame_of "$W2")"
echo "the window was $w wide and is now $after"
check "it is about 40 points wider" test "$((after - w))" -ge 25 -a "$((after - w))" -le 55
check "the window server agrees" eventually in_its_slot "$W2"

claim "⌃⌥-drag a rectangle around a window"
read -r x y w h <<< "$(frame_of "$W1")"
drag "$((x + 20))" "$((y + 50))" "$((x + w - 20))" "$((y + h - 20))" --mods ctrl+opt --no-release
check "a band shows while the button is held" has_overlay 3
release --mods ctrl+opt
check "the camera frames the window inside it" eventually fills "$W1"
ctl show-all

claim "float everything"
ctl zoom "$W1"
ctl float-all
for id in $ARBOR_WINDOW_IDS; do
  check "window $id floats" is floating "$id"
  check "window $id is on screen" eventually is on_screen "$id"
done
shot 07-float-all

claim "quitting puts every window back in view"
arbor_stop

# MARK: Session 3

step "session 3: two apps"
mkfifo "$ARBOR_SESSION_DIR/stdin2"
"$ARBOR_BIN/ArborTestWindows" --count 1 < "$ARBOR_SESSION_DIR/stdin2" > "$ARBOR_SESSION_DIR/hello2" 2>> "$ARBOR_OUT/test-windows.log" &
OTHER_PID=$!
started "$OTHER_PID"
at_exit 'kill_started $OTHER_PID'
exec 8> "$ARBOR_SESSION_DIR/stdin2"
sleep 2
X1=$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["windows"][0])' "$(head -n 1 "$ARBOR_SESSION_DIR/hello2")")
echo "the other app: pid $OTHER_PID, window $X1"
ARBOR_EXTRA_PIDS=$OTHER_PID
arbor_start 2
ARBOR_EXTRA_PIDS=""
ctl dock "$W1" left
ctl dock "$X1" right
# shellcheck disable=SC2046
click $(center_of "$W1")
check "a click focuses the first app's window" eventually is focused "$W1"
in_front() { [ "$("$ARBOR_AX" frontmost)" = "$1" ]; }
echo "in front: $("$ARBOR_AX" frontmost)"

claim "framing another app's window gives it the keyboard"
check "the first app is in front" in_front "$ARBOR_WINDOWS_PID"
ctl zoom "$X1"
check "the other app's window fills the screen" eventually fills "$X1"
check "the other app is in front" eventually in_front "$OTHER_PID"
echo "in front: $("$ARBOR_AX" frontmost)"
ctl show-all
# shellcheck disable=SC2046
click $(center_of "$W1")
check "a click brings the first app back" eventually in_front "$ARBOR_WINDOWS_PID"

claim "switching to an app whose window is out of view brings it into view"
ctl zoom "$W1"
check "the other app's window is out of view" eventually is parked "$X1"
# shellcheck disable=SC2046
click $(center_of "$W1")
check "the first app is in front" eventually in_front "$ARBOR_WINDOWS_PID"
mark=$(wc -l < "$ARBOR_HOME/arbor.log")
ax activate "$OTHER_PID"
sleep 1
echo "in front after asking from outside: $("$ARBOR_AX" frontmost)"
if ! in_front "$OTHER_PID"; then
  echo "> kill -USR1 $OTHER_PID (the app brings itself forward)"
  kill -USR1 "$OTHER_PID"
  sleep 1
  echo "in front after that: $("$ARBOR_AX" frontmost)"
fi
check "the other app came to the front" in_front "$OTHER_PID"
check "the camera moved to show its window" eventually is on_screen "$X1"
echo "what Arbor logged meanwhile:"
tail -n "+$((mark + 1))" "$ARBOR_HOME/arbor.log" | cut -c 26-
summary
shot 08-other-app
ctl show-all
check "show-all brings it back whatever happened" eventually is on_screen "$X1"

claim "quitting puts every window back in view"
check "the other app's window too" eventually is on_screen "$X1"
arbor_stop
exec 8>&-
kill -TERM "$OTHER_PID" 2> /dev/null

# MARK: Session 4

step "session 4: full screen"
arbor_start 3
ctl dock "$W1" left
ctl dock "$W2" right
slot1=$(arbor_ask slot "$W1")
display=$(pointer displays | awk 'NR == 1 { print $2, $3, $4, $5 }')

claim "a docked window goes full screen and comes back"
mark=$(wc -l < "$ARBOR_HOME/arbor.log")
ax fullscreen "$ARBOR_WINDOWS_PID" "$W1" on
sleep 4
"$ARBOR_AX" list "$ARBOR_WINDOWS_PID"
echo "the window server has it at $(real_frame_of "$W1"); the display is $display"
shot 09-full-screen
summary
check "the window has the whole display" is_at "$W1" "$display"
check "Arbor does not count it as parked" not is parked "$W1"
check "Arbor does not turn it into a tile" not is tile "$W1"
echo "what Arbor logged meanwhile:"
tail -n "+$((mark + 1))" "$ARBOR_HOME/arbor.log" | cut -c 26- | tail -n 20
ax fullscreen "$ARBOR_WINDOWS_PID" "$W1" off
sleep 4
summary
shot 10-after-full-screen
check "it is still docked" is docked "$W1"
check "it is a window again, not a tile" not is tile "$W1"
check "it is back in its slot" eventually is_at "$W1" "$slot1"
check "its neighbour is in its slot" eventually in_its_slot "$W2"

claim "quitting puts every window back in view"
arbor_stop 11-after-quit
