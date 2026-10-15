#!/bin/bash
# Windows that stay: a floating window that does not live on the Desktop.
# A49 pin a window so that it stays in view.
# On a window of a second app: raising a window of the app that is in front anyway would prove little.
source "$(dirname "$0")/../lib.sh"
arbor_build

# is_at <id> <x> <y> <w> <h>: what the window server says, which it also says while Arbor is not running.
is_at() {
  local id=$1
  shift
  arbor_close "$(real_frame_of "$id")" "$*" || { echo "it is at $(real_frame_of "$id"), not at $*"; return 1; }
}
# Arbor has heard of a move that the app made itself. What it keeps of a window's place is what it last saw of it.
seen_where_it_is() { arbor_close "$(frame_of "$1")" "$(real_frame_of "$1")"; }
# uncovered <id>: of the windows the window server has in front of it, none that belongs to the test apps overlaps it.
# (Arbor raises a window only when something covers it, so it need not be the frontmost.)
uncovered() {
  local frame
  frame=$(real_frame_of "$1") || { echo "the window server has no such window"; return 1; }
  # shellcheck disable=SC2086
  set -- "$1" $frame
  pointer windows --on-screen | awk -v id="$1" -v x="$2" -v y="$3" -v w="$4" -v h="$5" \
    -v apps=" $ARBOR_WINDOWS_PID $ARBOR_WINDOWS_PID_2 " '
    $1 == id { found = 1; exit }
    index(apps, " " $2 " ") && $4 < x + w && $4 + $6 > x && $5 < y + h && $5 + $7 > y { covered = 1 }
    END { exit !found || covered }' || { echo "another window lies over it, or it is not on screen"; return 1; }
}
marked() { [ "$(pointer menu-mark "$ARBOR_PID" "$1" 2>&1)" = "$2" ]; }

ARBOR_SECOND_APP=1
# A call is an ordinary app's window, with an icon in the Dock. A person's Dock stays as it is.
if on_throwaway_mac; then ARBOR_SECOND_APP_ARGS="--regular"; fi
# No shortcut is bound to it; ⌃⌥⇧D is the one docs/KEYBOARD.md keeps free for it.
arbor_settings '{"bindings": {"ctrl+opt+shift+d": "toggle-pin"}}'
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
# The call, as small as calls are kept.
take "x y _ _" real_frame_of "$V1"
tw2 move "$V1" "$x" "$y" 300 220
eventually seen_where_it_is "$V1"
ctl dock "$W1" left
ctl dock "$W2" right
summary

claim "choose Keep … in View from the menu: the focused floating window is pinned where it is, and the item is ticked"
proves A49
click_window "$V1"
check "the other app's window has the keyboard" eventually is focused "$V1"
place=$(real_frame_of "$V1")
check "the item can be clicked" click_menu "Keep This Window"
check "Arbor ran toggle-pin" eventually ran toggle-pin
check "Arbor calls it pinned" eventually is pinned "$V1"
check "it still floats" is floating "$V1"
# shellcheck disable=SC2086
check "it has not moved" is_at "$V1" $place
open_menu
check "the item is ticked" eventually marked "Keep This Window" "✓"
key escape

claim "drag a pinned window over a docked one: no preview shows, and it lies where it was dropped, still pinned"
proves A49
# shellcheck disable=SC2046
drag_window "$V1" $(zone_of "$W2" left) --no-release
check "no drop preview shows" stays fails has_overlay 3
release
check "it still floats" eventually is floating "$V1"
check "it is still pinned" is pinned "$V1"
check "two are docked, as before" count docked 2
check "it lies over the docked window" eventually fails left_of "$V1" "$W2"
check "the docked window has not made way" eventually in_slot "$W2"
place=$(real_frame_of "$V1")
settled

# still_there "<when>" <window with the keyboard>: the four things a pin promises after the view has moved.
still_there() {
  # shellcheck disable=SC2086
  check "$1: the pinned window has not moved" eventually is_at "$V1" $place
  check "$1: it is in view" in_view "$V1"
  check "$1: nothing covers it" eventually uncovered "$V1"
  check "$1: it has not taken the keyboard" eventually is focused "$2"
}

claim "⌃⌥↩, ⌃⌥→ and ⌃⌥0 move the view: the pinned window keeps its place in front, other floating windows leave"
proves A49
known "a pinned window of another app stays behind the window that has the keyboard: the Accessibility raise does not lift it over that one; reported, nobody has it yet"
click_window "$W1"
check "⌃⌥↩ reaches Arbor" pressed ctrl+opt+return zoom
check "the first window fills the screen" eventually fills "$W1"
check "the floating window that is not pinned left with the Desktop" eventually out_of_view "$W3"
still_there "framed on the first window" "$W1"
check "⌃⌥→ reaches Arbor" pressed ctrl+opt+right neighbor right
check "⌃⌥→ again" pressed ctrl+opt+right neighbor right
check "the second window fills the screen" eventually fills "$W2"
still_there "framed on the second window" "$W2"
check "⌃⌥0 reaches Arbor" pressed ctrl+opt+0 home
check "the camera is on everything" eventually camera_on root
still_there "showing everything" "$W2"
settled

claim "click the docked window under a pinned one: the pinned window is in front again, the keyboard stays in the other"
proves A49
known "a pinned window of another app stays behind the window that has the keyboard: the Accessibility raise does not lift it over that one; reported, nobody has it yet"
click_window "$W1"
check "the first window has the keyboard" eventually is focused "$W1"
click_window "$W2"
check "the window under it has the keyboard" eventually is focused "$W2"
check "nothing covers the pinned window" eventually uncovered "$V1"
check "it stays so" stays uncovered "$V1"
check "the keyboard is still in the clicked window" is focused "$W2"
check "its app is still the one in front" front_is "$ARBOR_WINDOWS_PID"
# shellcheck disable=SC2086
check "the pinned window has not moved" is_at "$V1" $place
settled

claim "⌃⌥⇧D, bound to toggle-pin in settings.json, unpins: the window leaves with the Desktop when the view next moves"
proves A49
click_window "$V1"
check "the pinned window has the keyboard" eventually is focused "$V1"
check "⌃⌥⇧D reaches Arbor" pressed ctrl+opt+shift+d toggle-pin
check "it is no longer pinned" eventually fails is pinned "$V1"
# shellcheck disable=SC2086
check "it has not moved" is_at "$V1" $place
open_menu
check "the menu's item is no longer ticked" eventually marked "Keep This Window" "-"
key escape
click_window "$W2"
check "a click on the docked window under it now leaves it covered" stays fails uncovered "$V1"
click_window "$W1"
check "⌃⌥↩ reaches Arbor" pressed ctrl+opt+return zoom
check "the first window fills the screen" eventually fills "$W1"
check "the window that was pinned is out of view" eventually out_of_view "$V1"
check "⌃⌥0 reaches Arbor" pressed ctrl+opt+0 home
check "it comes back with the Desktop" eventually in_view "$V1"
settled

claim "⌃⌥⇧D pins again; quit Arbor and start it again: the window is still pinned, in the same place"
proves A49
known "a pinned window of another app stays behind the window that has the keyboard: the Accessibility raise does not lift it over that one; reported, nobody has it yet"
click_window "$V1"
check "⌃⌥⇧D reaches Arbor" pressed ctrl+opt+shift+d toggle-pin
check "it is pinned" eventually is pinned "$V1"
place=$(real_frame_of "$V1")
ctl zoom "$W1"
check "the first window fills the screen" eventually fills "$W1"
arbor_quit
# shellcheck disable=SC2086
check "quitting leaves it where it is" is_at "$V1" $place
arbor_relaunch
check "it is still pinned" eventually is pinned "$V1"
# A start shows everything; the view Arbor stopped in is one step back.
check "the camera shows everything" eventually camera_on root
ctl back
check "one step back the first window fills the screen" eventually fills "$W1"
# shellcheck disable=SC2086
check "the pinned window has not moved" eventually is_at "$V1" $place
check "it is in view" in_view "$V1"
check "nothing covers it" eventually uncovered "$V1"
ctl show-all
settled

claim "dock a pinned window by command and the pin ends; pin a docked window by command and it floats, pinned"
proves A49
check "dock succeeds" ctl dock "$V1" beside "$W2" bottom
check "it is docked" eventually in_slot "$V1"
check "it is no longer pinned" fails is pinned "$V1"
check "pin succeeds" ctl pin "$V1"
check "it floats" eventually is floating "$V1"
check "it is pinned" is pinned "$V1"
check "at its own size" eventually width_is "$V1" 300
check "its slot has closed: the window above has the whole column" eventually at_edge "$W2" bottom
check "unpin succeeds" ctl unpin "$V1"
check "it is no longer pinned" fails is pinned "$V1"
settled
arbor_stop
