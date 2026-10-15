#!/bin/bash
# Windows that stay: a floating window that does not live on the Desktop.
# A49 pin a window so that it stays in view.
# On a window of a second app. macOS lets nobody lift such a window over the one that has the keyboard, so docked windows make room for it
# instead (collab/QUESTIONS.md Q25): what is asked of the window server is that all of it is to be seen.
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
# (It need not be the frontmost, and seldom is.)
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
# apart <a> <b>: by the window server's frames the two do not overlap.
apart() {
  echo "$(real_frame_of "$1") $(real_frame_of "$2")" | awk 'NF == 8 { exit ($1 < $5 + $7 && $5 < $1 + $3 && $2 < $6 + $8 && $6 < $2 + $4) } { exit 1 }' \
    || { echo "$1 is at $(real_frame_of "$1"), $2 at $(real_frame_of "$2")"; return 1; }
}

ARBOR_SECOND_APP=1
# A call is an ordinary app's window, with an icon in the Dock. A person's Dock stays as it is.
if on_throwaway_mac; then ARBOR_SECOND_APP_ARGS="--regular"; fi
# No shortcut is bound to it; ⌃⌥⇧D is the one docs/KEYBOARD.md keeps free for it.
arbor_settings '{"bindings": {"ctrl+opt+shift+d": "toggle-pin"}}'
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
# The call, as small as calls are kept: beside a wider one three columns would be too narrow for a display of 1024 points, and tiles.
take "x y _ _" real_frame_of "$V1"
tw2 move "$V1" "$x" "$y" 180 140
eventually seen_where_it_is "$V1"
ctl dock "$W1" left
ctl dock "$W2" right
summary

claim "choose Keep … in View from the menu: the focused floating window is pinned where it is, and the item is ticked"
proves A49
click_window "$V1"
check "the other app's window has the keyboard" eventually is focused "$V1"
place=$(real_frame_of "$V1")
check "the submenu's item can be clicked" click_menu "Focused Window" "Keep This Window"
check "Arbor ran toggle-pin" eventually ran toggle-pin
check "Arbor calls it pinned" eventually is pinned "$V1"
check "it still floats" is floating "$V1"
# shellcheck disable=SC2086
check "it has not moved" is_at "$V1" $place
# A click on the row that opens a submenu opens it and leaves the menu open. The first Escape may close only the submenu.
check "its submenu opens" click_menu "Focused Window"
check "the item is ticked" eventually marked "Keep This Window" "✓"
key escape
key escape

claim "drag a pinned window over a docked one, far from every edge: no preview shows, it lies where it was dropped, still pinned, and no room is made"
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
check "which reaches the screen's own edge" at_edge "$W2" right
settled

claim "drag it to the top right corner: nothing else moves while it is in the hand, and when it is let go the docked windows make room beside it"
proves A49
take "sx sy sw _" screen_of 1
before=$(real_frame_of "$W2")
# The pointer takes a title bar where it is free of buttons, which is not its middle: the window goes where the grip goes. Its right
# edge is to end 10 points from the screen's: beside a strip of 190 points three columns are 262 wide, and no tiles (240).
take "x y w _" real_frame_of "$V1"
take "gx gy" titlebar_of "$V1"
# shellcheck disable=SC2046
drag_window "$V1" $(echo "$sx $sy $sw $x $y $w $gx $gy" | awk '{ printf "%d %d", $1 + $3 - 10 - $6 + ($7 - $4), $2 + 20 + ($8 - $5) }') --no-release
# shellcheck disable=SC2086
check "in the hand: the docked window has not moved" stays is_at "$W2" $before
release
check "it is still pinned" eventually is pinned "$V1"
check "the second docked window is in its place, in view" eventually in_slot "$W2"
check "and no tile" fails is tile "$W2"
check "it keeps clear of the pinned one" eventually apart "$V1" "$W2"
check "and so does the first" apart "$V1" "$W1"
check "the second reaches the edge of what is left" eventually at_edge "$W2" right
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

claim "⌃⌥↩, ⌃⌥→ and ⌃⌥0 move the view: the pinned window keeps its place, all of it to be seen beside every view; other floating windows leave"
proves A49
click_window "$W1"
check "⌃⌥↩ reaches Arbor" pressed ctrl+opt+return zoom
check "the first window fills what is left of the screen" eventually fills "$W1"
check "and keeps clear of the pinned one" apart "$V1" "$W1"
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

claim "click the docked windows beside a pinned one: nothing covers it, the keyboard stays in the window clicked"
proves A49
click_window "$W1"
check "the first window has the keyboard" eventually is focused "$W1"
click_window "$W2"
check "the window beside it has the keyboard" eventually is focused "$W2"
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
check "its submenu opens" click_menu "Focused Window"
check "the menu's item is no longer ticked" eventually marked "Keep This Window" "-"
key escape
key escape
check "the docked windows have its room back: the second reaches the screen's own edge, under it" eventually fails apart "$V1" "$W2"
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
check "at its own size" eventually width_is "$V1" 180
# (Beside the strip three columns may be too narrow for a small display, and are tiles then: where the others are is not asked here.)
check "its slot has closed: two are docked" eventually count docked 2
check "unpin succeeds" ctl unpin "$V1"
check "it is no longer pinned" fails is pinned "$V1"
settled
arbor_stop
