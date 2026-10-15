#!/bin/bash
# F51 on real windows, with real keys that go down and come up later: hold ⌃⌥Space to look, let go to land.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-F51.sh
#
# What only a Mac can say:
#   - Carbon reports a hot key's release (kEventHotKeyReleased), with the modifiers still down and without;
#   - ⌃⌥ + arrow and ⌃⌥⎋ fire while Space is down;
#   - what a held key's auto-repeat does;
#   - CGEventSource.keyState and NSEvent.modifierFlags see a key that a hot key swallowed, WHEN THE APP ASKS: the shell's child is told more (lib-person.sh);
#   - what the outline looks like.
# arbor.log (debug) says "peek: held", "peek: the key came up" (Carbon said so) and "peek: the keys were found up" (the
# timer noticed first); the end of this script prints those lines.
#
# Safe on a person's Mac: it touches its own test windows, the pointer and the keyboard, and changes no setting. On GitHub's Macs alone it starts Arbor as a
# person does, which takes an entry in the permission database, removed at the end.
ARBOR_SHORTCUTS=all  # it presses keys of the whole map, of which nine ship
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/lib-person.sh"

SPACE=ctrl+opt+space

arbor_build
arbor_start_as_a_person 3 ARBOR_NO_HOTKEYS=0

framed() {
  local id
  is parked "$1" && return 1
  for id in $ARBOR_WINDOW_IDS; do
    [ "$id" = "$1" ] || is parked "$id" || return 1
  done
}
everything() {
  local id
  for id in $ARBOR_WINDOW_IDS; do
    is parked "$id" && return 1
  done
  return 0
}
not() { ! "$@"; }
running() { "$ARBOR_BIN/arborctl" status | grep -q running; }
# Back to w1 framed and focused, the pointer in the middle of it, nothing held.
start_over() {
  ctl show-all
  ctl zoom "$W1"
  eventually framed "$W1"
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  sleep 0.3
}
# Long enough for the outline to show.
hold() {
  key $SPACE --down
  sleep 0.6
}

ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W1" bottom

step "A tap shows everything, and it stays"
start_over
key $SPACE
check "everything shows" eventually everything
sleep 1
check "and still does a second later" everything
check "no outline" eventually not has_overlay 3
ctl back
check "back returns to w1" eventually framed "$W1"

step "A tap with ⌃⌥ kept down, as between two shortcuts"
start_over
key ctrl+opt --down
key $SPACE --held
sleep 1
check "everything shows a second after the tap" everything
check "no outline" not has_overlay 3
key ctrl+opt --up
sleep 0.6
check "and does not spring back when ⌃⌥ come up" everything

step "Hold, point, let go"
start_over
hold
check "everything shows while the keys are down" everything
check "an outline shows" eventually has_overlay 3
shot 01-held-outline-where-i-came-from
# shellcheck disable=SC2046
move $(center_of "$W2")
shot 02-outline-follows-the-pointer
key $SPACE --up
check "letting go frames the window under the pointer" eventually framed "$W2"
check "which has the keyboard" eventually is focused "$W2"
check "the outline is gone" eventually not has_overlay 3
ctl back
check "back returns to the view before the peek" eventually framed "$W1"

step "A slow press: held for half a second, nothing chosen"
start_over
hold
key $SPACE --up
check "everything stays" eventually everything
sleep 0.6
check "and does not spring back" everything

step "Hold for a good look and let go without moving"
start_over
hold
sleep 1
key $SPACE --up
check "the original view is back" eventually framed "$W1"
ctl back
check "and history has no entry for it: back goes to everything, where start_over came from" eventually everything

step "⎋"
start_over
hold
# shellcheck disable=SC2046
move $(center_of "$W2")
key ctrl+opt+escape --held
check "⌃⌥⎋ returns to the original view" eventually framed "$W1"
check "and does not pause" running
key $SPACE --up
sleep 0.5
check "letting go afterwards changes nothing" framed "$W1"

step "The arrow keys"
start_over
hold
key ctrl+opt+down --held
shot 03-outline-moved-by-an-arrow
check "⌃⌥↓ did not step in" everything
key $SPACE --up
check "letting go frames the window below" eventually framed "$W3"

step "⌃⌥ come up before Space"
start_over
hold
# shellcheck disable=SC2046
move $(center_of "$W2")
key ctrl+opt --up
check "that ends the hold" eventually framed "$W2"
key space --up
sleep 0.5
check "and Space coming up changes nothing" framed "$W2"

step "Auto-repeat"
start_over
key $SPACE --down
key $SPACE --repeat 40
check "everything shows" everything
check "the outline shows" eventually has_overlay 3
key $SPACE --up
check "letting go returns to the original view" eventually framed "$W1"

step "A click"
start_over
hold
# shellcheck disable=SC2046
click $(center_of "$W2")
check "the clicked window is framed with Space still down" eventually framed "$W2"
check "and no app was hidden by an ⌥-click" not is hidden "$W1"
key $SPACE --up
sleep 0.5
check "letting go afterwards changes nothing" framed "$W2"

step "Another shortcut during the hold"
start_over
hold
key ctrl+opt+d --held
sleep 0.5
key $SPACE --up
sleep 0.5
summary
check "nothing is left of the peek" not has_overlay 3

step "What the log says"
arbor_log
grep -n "peek" "$ARBOR_OUT/arbor.log" | tail -n 60
arbor_stop 04-after-quit
