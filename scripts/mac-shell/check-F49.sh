#!/bin/bash
# F49, pinned windows, on real windows of two apps, with a real pointer and real keys:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-F49.sh
#
# What only a Mac can say, and this asks:
# - does kAXRaiseAction alone bring a window of an app that is NOT in front above the windows of the app that is,
#   and does the keyboard stay where it was?
# - is the pinned window in front again after a command that focuses a window, after a real click on the
#   window under it, and after a click in the window that has the keyboard already? How long is it covered (the film)?
# - does raising make its app report focus changes that move Arbor's camera or start a loop (the log)?
# - a real drag over a docked window's edge and to the screen edge: no preview, no dock.
# - the menu item and its tick; a shortcut from `bindings`; pause, quit and a relaunch leave it where it is.
# - a display unplugged and plugged in again (a virtual one, on GitHub's throwaway Macs only).
#
# Safe on a person's Mac: it changes no setting, touches only windows it opened, and moves the pointer and
# presses keys. The part with the second display is left out there.
source "$(dirname "$0")/lib.sh"

# This script's windows, from the frontmost to the one at the back, as the window server has them.
stack() { "$ARBOR_POINTER" windows --on-screen | awk '{ print $1 }' | grep -E "^($W1|$W2|$CALL)$"; }
front_window() { stack | head -n 1; }
in_front() { [ "$(front_window)" = "$1" ]; }
# None of this script's windows that lie in front of window $1 overlaps it. (Arbor raises a pinned window only
# when something covers it, so after a click on a window beside it, it need not be the frontmost.)
uncovered() {
  local x y w h
  read -r x y w h <<< "$(real_frame_of "$1")"
  "$ARBOR_POINTER" windows --on-screen | awk -v id="$1" -v x="$x" -v y="$y" -v w="$w" -v h="$h" -v mine=" $W1 $W2 $CALL " '
    $1 == id { exit }
    index(mine, " " $1 " ") && $4 < x + w && $4 + $6 > x && $5 < y + h && $5 + $7 > y { covered = 1 }
    END { exit covered }'
}
# Windows $1 and $2 overlap, so that one can cover the other.
overlap() {
  echo "$(real_frame_of "$1") $(real_frame_of "$2")" \
    | awk '{ exit !($1 < $5 + $7 && $5 < $1 + $3 && $2 < $6 + $8 && $6 < $2 + $4) }'
}
do_not_overlap() { ! overlap "$@"; }
# Where the call's title bar has to go for the call to be in the top right corner of the main display, which is
# over the browser whatever the display's size.
corner() {
  local sx sy sw sh x y w h
  read -r sx sy sw sh <<< "$(screen_of 1)"
  read -r x y w h <<< "$(frame_of "$CALL")"
  [ -n "$h" ] || die "the call has no frame"
  echo "$((sx + sw - w / 2 - 40)) $((sy + 32))"
}
same_place() { [ "$(real_frame_of "$CALL")" = "$1" ]; }
camera() { arbor_ask json | python3 -c 'import json, sys; print(json.load(sys.stdin)["displays"][0]["camera"])'; }
camera_is() { [ "$(camera)" = "$1" ]; }
running() { "$ARBOR_BIN/arborctl" status | grep -q "^running"; }
raises() { grep -c "raised" "$ARBOR_HOME/arbor.log"; }
# The pinned window is where it was, wholly on screen, in front, and $1 has the keyboard.
call_is_fine() {
  check "$2: the call has not moved" eventually same_place "$home_frame"
  check "$2: the call is not out of view" is on_screen "$CALL"
  check "$2: Arbor does not count it as out of view" eventually is_not parked "$CALL"
  check "$2: nothing covers the call" eventually uncovered "$CALL"
  check "$2: the keyboard is in $1" eventually is focused "$1"
}
is_not() { ! is "$@"; }
two_displays() { [ "$(arbor_ask displays)" = 2 ]; }
is_not_shown() { ! has_overlay "$1"; }

# A second app with one window, because raising a window of the app that is in front anyway proves little.
open_call() {
  local hello="" tries=0
  mkfifo "$ARBOR_SESSION_DIR/call-stdin"
  "${ARBOR_TEST_WINDOWS_2:-$ARBOR_BIN/ArborTestWindows}" --count 1 < "$ARBOR_SESSION_DIR/call-stdin" > "$ARBOR_SESSION_DIR/call-hello" \
    2>> "$ARBOR_OUT/test-windows.log" &
  CALL_PID=$!
  started "$CALL_PID"
  at_exit 'kill_started $CALL_PID'
  exec 8> "$ARBOR_SESSION_DIR/call-stdin"
  while [ -z "$hello" ] && [ "$tries" -lt 100 ]; do
    sleep 0.1
    hello=$(head -n 1 "$ARBOR_SESSION_DIR/call-hello" 2>/dev/null)
    tries=$((tries + 1))
  done
  CALL=$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["windows"][0])' "$hello") \
    || die "the second ArborTestWindows did not report its window (got: $hello)"
  ARBOR_EXTRA_PIDS=$CALL_PID
}
close_call() {
  exec 8>&-
  arbor_await_exit "$CALL_PID" 30 || kill -TERM "$CALL_PID" 2>/dev/null
}

arbor_build

step "an editor and a browser from one app, a call from another; shortcuts and the menu bar item on"
arbor_settings '{"bindings": {"ctrl+opt+shift+d": "toggle-pin"}}'
open_call
arbor_start 2 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
check "Arbor arranges the other app's window too" eventually is managed "$CALL"
echo "front to back before anything: $(stack | tr '\n' ' ')"
# It opened first and lies right under the editor, which opened at the same place.
ctl pin "$CALL"
check "state says pinned" eventually is pinned "$CALL"
check "pinning alone brings it in front of the other app's windows" eventually in_front "$CALL"
check "and does not give it the keyboard" is_not focused "$CALL"
# To the top right corner, where it will lie over the browser.
# shellcheck disable=SC2046
drag $(titlebar_of "$CALL") $(corner)
ctl dock "$W1" left
ctl dock "$W2" right
sleep 1
home_frame=$(real_frame_of "$CALL")
echo "the call is at $home_frame"
summary
# Or "nothing covers the call" could not fail, and the clicks below would prove nothing.
check "the call lies over the browser" overlap "$CALL" "$W2"
check "and not over the editor" do_not_overlap "$CALL" "$W1"
call_is_fine "$W2" "after docking two windows under it"
shot 01-docked-under-the-call

step "1 and 2: camera moves"
ctl zoom "$W1"
check "the browser went out of view" eventually is parked "$W2"
call_is_fine "$W1" "framed on the editor"
shot 02-editor-framed
ctl neighbor right
call_is_fine "$W1" "on the Desktop (the keyboard stays in the editor, which is out of view)"
ctl neighbor right
check "the editor went out of view" eventually is parked "$W1"
call_is_fine "$W2" "framed on the browser"
shot 03-browser-framed
# The window that has the keyboard already: macOS reports no focus change, but Arbor's focus call raises it.
ctl zoom "$W2"
call_is_fine "$W2" "framed again on the window that has the keyboard"
ctl show-all
call_is_fine "$W2" "showing everything"

step "real clicks on the window under it"
# The browser has the keyboard by now. It goes to the editor first, so that the click that is filmed moves it.
read -r x y w h <<< "$(frame_of "$W1")"
[ -n "$h" ] || die "the editor has no frame"
click $((x + w / 2)) $((y + h - 40))
call_is_fine "$W1" "after clicking the editor, beside it"
read -r x y w h <<< "$(frame_of "$W2")"
[ -n "$h" ] || die "the browser has no frame"
# Near the bottom of the browser, clear of the call.
click $((x + w / 2)) $((y + h - 40)) &
clicker=$!
film 04-click 6
wait "$clicker"
call_is_fine "$W2" "after clicking the browser, under it"
# The window that has the keyboard already: no focus change is reported, only the press tells Arbor to look.
click $((x + w / 2)) $((y + h - 80))
sleep 1
call_is_fine "$W2" "after clicking the browser again"

step "a real click on the call itself"
ctl zoom "$W1"
check "framed" eventually is parked "$W2"
view=$(camera)
# shellcheck disable=SC2046
click $(center_of "$CALL")
check "the call has the keyboard" eventually is focused "$CALL"
sleep 1.5
check "the view did not move" camera_is "$view"
check "the call has not moved" same_place "$home_frame"
ctl neighbor right
sleep 1
check "on the empty Desktop, where nothing arrives, the keyboard stays in it" is focused "$CALL"
ctl neighbor right
check "the next move of the view takes the keyboard along to the browser" eventually is focused "$W2"
check "and the call has not moved" same_place "$home_frame"
ctl show-all

step "no storm: a second of rest raises nothing"
sleep 1
before=$(raises)
sleep 1.5
check "nothing was raised meanwhile ($before so far)" test "$(raises)" = "$before"

step "3: a real drag never docks it"
# shellcheck disable=SC2046
drag $(titlebar_of "$CALL") 60 300 --no-release
check "over the editor's left edge: no preview" is_not_shown 3
shot 05-dragged-over-an-edge
release
check "dropped there it still floats" eventually is floating "$CALL"
check "and is still pinned" is pinned "$CALL"
# shellcheck disable=SC2046
drag $(titlebar_of "$CALL") 2 300 --no-release
check "at the screen edge: no preview" is_not_shown 3
release
check "dropped there it still floats" eventually is floating "$CALL"
check "and is still pinned" is pinned "$CALL"
# shellcheck disable=SC2046
drag $(titlebar_of "$CALL") $(corner)
sleep 1
home_frame=$(real_frame_of "$CALL")
ctl zoom "$W1"
call_is_fine "$W1" "where it was dropped, after the next camera move"
ctl show-all

step "the shortcut and the menu"
# shellcheck disable=SC2046
click $(center_of "$CALL")
check "the call has the keyboard" eventually is focused "$CALL"
read -r item_x item_y <<< "$(status_item)"
click "$item_x" "$item_y"
shot 06-menu-with-a-tick
key escape
key ctrl+opt+shift+d
check "⌃⌥⇧D (from bindings) unpins" eventually is_not pinned "$CALL"
check "and moves nothing" same_place "$home_frame"
click "$item_x" "$item_y"
shot 07-menu-without-a-tick
key escape
key ctrl+opt+shift+d
check "again pins" eventually is pinned "$CALL"

step "3: dock unpins, pin floats"
ctl dock "$CALL" beside "$W2" bottom
check "docked" eventually is docked "$CALL"
check "no longer pinned" is_not pinned "$CALL"
ctl pin "$CALL"
check "pinning floats it" eventually is floating "$CALL"
check "pinned" is pinned "$CALL"
summary
shot 08-pinned-from-docked
# shellcheck disable=SC2046
drag $(titlebar_of "$CALL") $(corner)
sleep 1
home_frame=$(real_frame_of "$CALL")

step "float-all and pause leave it exactly where it is"
ctl zoom "$W1"
ctl float-all
check "float-all: the call has not moved" eventually same_place "$home_frame"
check "float-all: still pinned" is pinned "$CALL"
ctl dock "$W1" left
ctl dock "$W2" right
ctl zoom "$W1"
check "framed" eventually is parked "$W2"
ctl pause
sleep 1
check "paused: the call has not moved" same_place "$home_frame"
ctl resume
check "running again" eventually running
check "resumed: still pinned" eventually is pinned "$CALL"
check "resumed: the call has not moved" same_place "$home_frame"

step "a second display: the pin goes along, comes to the main display when it is unplugged, and goes back"
if [ -n "${ARBOR_REHEARSAL:-}" ]; then
  echo "skipped: the rehearsal's Mac has one display"
elif display_add 800 600 right; then
  check "Arbor arranges two displays" eventually two_displays
  read -r x y w h <<< "$(screen_of 2)"
  ctl show-all
  # shellcheck disable=SC2046
  drag $(titlebar_of "$CALL") $((x + w - 200)) $((y + 60)) --duration 1
  check "dragged there, the second display's workspace holds it" eventually is display2 "$CALL"
  check "still pinned" is pinned "$CALL"
  sleep 1
  there=$(real_frame_of "$CALL")
  ctl zoom "$W1"
  check "framed on the main display" eventually is parked "$W2"
  panorama 09-call-on-the-second-display
  display_remove
  check "unplugged: the main display's workspace holds it" eventually is display1 "$CALL"
  check "unplugged: still pinned" is pinned "$CALL"
  check "unplugged: in view, though the Desktop is not" eventually is on_screen "$CALL"
  check "unplugged: Arbor does not count it as out of view" is_not parked "$CALL"
  check "unplugged: nothing covers it" eventually uncovered "$CALL"
  shot 10-unplugged
  display_add 800 600 right
  check "plugged in again: back on the second display" eventually is display2 "$CALL"
  check "plugged in again: still pinned" is pinned "$CALL"
  check "plugged in again: exactly where it was ($there)" eventually same_place "$there"
  panorama 11-plugged-in-again
  # shellcheck disable=SC2046
  drag $(titlebar_of "$CALL") $(corner) --duration 1
  check "dragged back" eventually is display1 "$CALL"
  display_remove
  # Arbor hears of it a second and a half after the displays have settled.
  sleep 3
  home_frame=$(real_frame_of "$CALL")
  ctl show-all
fi

step "5: quit and launch again on the same windows"
ctl zoom "$W1"
check "framed" eventually is parked "$W2"
echo "> quit"
"$ARBOR_BIN/arborctl" quit
check "Arbor exits" arbor_await_exit "$ARBOR_PID" 50
# Or the wait would never end.
kill -0 "$ARBOR_PID" 2>/dev/null && kill -KILL "$ARBOR_PID"
wait "$ARBOR_PID" 2>/dev/null
check "quit: the call has not moved" same_place "$home_frame"
shot 12-after-quit
cp "$ARBOR_HOME/arbor.log" "$ARBOR_OUT/arbor-first-run.log"
env ARBOR_ONLY_PIDS="$ARBOR_WINDOWS_PID,$CALL_PID" ARBOR_NO_PROMPT=1 ARBOR_DEBUG=1 ARBOR_NO_HOTKEYS=1 \
  ARBOR_NO_STATUS_ITEM=1 ARBOR_NO_WATCHDOG=1 "$ARBOR_BIN/Arbor" > "$ARBOR_OUT/arbor-stderr-relaunch.log" 2>&1 8>&- 9>&- &
ARBOR_PID=$!
started "$ARBOR_PID"
check "running again" eventually running
check "relaunched: still pinned" eventually is pinned "$CALL"
check "relaunched: the call has not moved" same_place "$home_frame"
ctl zoom "$W1"
call_is_fine "$W1" "relaunched and framed on the editor"
shot 13-relaunched

step "what the log says about raising and focus"
grep -c "raised" "$ARBOR_OUT/arbor-first-run.log"
grep -E "raised|has the keyboard|focus report" "$ARBOR_OUT/arbor-first-run.log" | tail -n 40

arbor_stop 14-quit
close_call
