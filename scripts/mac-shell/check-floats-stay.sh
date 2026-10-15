#!/bin/bash
# No view takes a floating window out of view (F64; collab/QUESTIONS.md, Q29, 4), on real windows, as Arbor ships: one window docked with
# a key, three floating. ⌃⌥↩ fills the screen with the docked one and ⌃⌥↩ goes back; ⌃⌥↩ and ⌃⌥Space; typing in a floating one meanwhile.
# By what the window server says: each floating window is where it was to the point, on screen, and in the order it was in.
#
#   scripts/mac-shell/run.sh --priority 1 scripts/mac-shell/check-floats-stay.sh
#   scripts/mac-shell/rehearse.sh scripts/mac-shell/check-floats-stay.sh
source "$(dirname "$0")/lib.sh"
arbor_build

# is_at <id> <x> <y> <w> <h>: what the window server says.
is_at() {
  local id=$1
  shift
  arbor_close "$(real_frame_of "$id")" "$*" || { echo "it is at $(real_frame_of "$id"), not at $*"; return 1; }
}
# The three floating windows from front to back, as the window server has them.
order() { pointer windows --on-screen | awk -v ids=" $W2 $W3 $W4 " 'index(ids, " " $1 " ") { printf "%s ", $1 }'; }
in_the_order() { [ "$(order)" = "$1" ] || { echo "front to back they are $(order), not $1"; return 1; }; }
# all_where_they_were <when>
all_where_they_were() {
  # shellcheck disable=SC2086
  check "$1: the second window is where it was" stays is_at "$W2" $second
  # shellcheck disable=SC2086
  check "$1: the third window is where it was" stays is_at "$W3" $third
  # shellcheck disable=SC2086
  check "$1: the fourth window is where it was" stays is_at "$W4" $fourth
  check "$1: all three are on screen, in the order they were in" in_the_order "$before"
}

arbor_start 4 ARBOR_NO_HOTKEYS=0
click_window "$W1"
check "the first window has the keyboard" eventually is focused "$W1"
check "⌃⌥← reaches Arbor" pressed ctrl+opt+left dock left
check "the first window is docked" eventually is docked "$W1"
settled
second=$(real_frame_of "$W2")
third=$(real_frame_of "$W3")
fourth=$(real_frame_of "$W4")
before=$(order)
summary

claim "⌃⌥↩ on a docked window with three floating ones, and ⌃⌥↩ again: no floating window is moved, sized, hidden or raised"
check "⌃⌥↩ reaches Arbor" pressed ctrl+opt+return zoom
check "the docked window fills the screen" eventually fills "$W1"
all_where_they_were "with the docked window filling the screen"
check "⌃⌥↩ again" pressed ctrl+opt+return zoom
check "the camera is on everything" eventually camera_on root
all_where_they_were "back"
settled

claim "⌃⌥↩ and then ⌃⌥Space: the same"
check "⌃⌥↩ reaches Arbor" pressed ctrl+opt+return zoom
check "the docked window fills the screen" eventually fills "$W1"
all_where_they_were "with the docked window filling the screen"
check "⌃⌥Space reaches Arbor" pressed ctrl+opt+space show-all
check "the camera is on everything" eventually camera_on root
all_where_they_were "with everything showing"
settled

claim "click a floating window and press ⌃⌥[ and ⌃⌥Space: the view moves, the window keeps the keyboard and its place in front"
click_window "$W2"
check "the floating window has the keyboard" eventually is focused "$W2"
before=$(order)
check "⌃⌥[ reaches Arbor" pressed ctrl+opt+[ back
check "the docked window fills the screen" eventually fills "$W1"
check "the floating window still has the keyboard" stays is focused "$W2"
all_where_they_were "back on the docked window"
check "⌃⌥Space reaches Arbor" pressed ctrl+opt+space show-all
check "the camera is on everything" eventually camera_on root
check "the floating window still has the keyboard" stays is focused "$W2"
all_where_they_were "with everything showing"
settled

arbor_quit
