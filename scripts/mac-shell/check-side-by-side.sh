#!/bin/bash
# Board 0.12 (IDEAS I18; QUESTIONS Q29, 9): tick two to four windows in Go to…, ↩, and they are docked side by side. On real windows, with
# real keys and clicks:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-side-by-side.sh
#
# What only a Mac can tell: whether ⌘↩ reaches a panel of an app that is never active, and ⌘-click and ⇧-click a row of it; whether a window
# asked out of the Dock lands in the place kept open for it, and its neighbours stay where they went; whether all of the group ends in
# front; and what the circles look like. LOOK AT THE PICTURES: the number in its circle, on the selected row too; the note beside it;
# the line under the rows.
#
# Safe on a person's Mac: it touches only its own test windows and changes no setting. It does move the pointer and press keys, always
# with the test app in front, so a key the palette misses lands in a test window, which ignores it.
source "$(dirname "$0")/lib.sh"

# The palette's level is floating (3) plus 2.
palette() { has_overlay 5; }
no_palette() { ! has_overlay 5; }
palette_frame() { overlays | awk '$3 == 5 && $8 == "on" { print int($4), int($5), int($6), int($7); exit }'; }
# The middle of the n-th row, from FinderLayout: a band of 56 for the field, 8 of padding, rows of 38.
palette_row() {
  local x y w h
  read -r x y w h <<< "$(palette_frame)"
  [ -n "$x" ] || return 1
  echo "$((x + w / 2)) $((y + 56 + 8 + 38 * ($1 - 1) + 19))"
}
front() { pointer front 2>/dev/null; }
test_app_in_front() { [ "$(front)" = "$ARBOR_WINDOWS_PID" ]; }
is_not_minimized() { ! is minimized "$1"; }
is_not_docked() { ! is docked "$1"; }
# Every test window is called "Arbor Test <n>": its number finds it.
tick() {
  key "$1"
  key cmd+return
}
docked_count() { arbor_ask json | python3 -c 'import json, sys; print(sum(1 for w in json.load(sys.stdin)["windows"] if w.get("docked")))'; }
docked_are() { [ "$(docked_count)" = "$1" ]; }

arbor_build
step "five floating windows, shortcuts on"
ARBOR_TEST_WINDOWS_ARGS="--regular"
arbor_start 5 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0 ARBOR_PANELS_IN_PICTURES=1
# shellcheck disable=SC2046
click $(center_of "$W5")
check "the test app is the active one" eventually test_app_in_front
for n in 1 2 3 4 5; do eval "own$n=\$(frame_of \"\$W$n\")"; done
summary

step "the line under the rows says how"
key ctrl+opt+g
check "⌃⌥G opens the palette" eventually palette
shot 01-the-hint

step "⌘↩ ticks: 3, then 1, then 4"
tick 3
shot 02-one-ticked
tick 1
tick 4
shot 03-three-ticked
check "the palette is still open" palette
check "nothing has moved yet: window 3 is where it was" arbor_close "$(frame_of "$W3")" "$own3"

step "↩ docks them, in that order, and they fill the screen"
key return
check "the palette closes" eventually no_palette
check "3 is docked" eventually is docked "$W3"
check "three windows are docked" eventually docked_are 3
check "3 is left of 1" eventually left_of "$W3" "$W1"
check "1 is left of 4" left_of "$W1" "$W4"
check "each is in its slot: 3" eventually is in_slot "$W3"
check "1" is in_slot "$W1"
check "4" is in_slot "$W4"
check "the first ticked has the keyboard" eventually is focused "$W3"
check "the test app is still the active one" test_app_in_front
shot 04-side-by-side
summary
ctl ascii

step "⌃⌥Z takes all of it back"
key ctrl+opt+z
check "nothing is docked" eventually docked_are 0
check "3 has its own frame again" eventually arbor_close "$(frame_of "$W3")" "$own3"
check "1" arbor_close "$(frame_of "$W1")" "$own1"
check "4" arbor_close "$(frame_of "$W4")" "$own4"
shot 05-undone

step "⌘-click and ⇧-click tick a row; again takes the tick off"
key ctrl+opt+g
check "the palette is open" eventually palette
# shellcheck disable=SC2046
click $(palette_row 2) --mods cmd
# shellcheck disable=SC2046
click $(palette_row 4) --mods shift
shot 06-ticked-by-clicks
check "a click with a modifier chooses nothing: the palette is still open" palette
# shellcheck disable=SC2046
click $(palette_row 4) --mods cmd
shot 07-one-tick-taken-off
key escape
check "⎋ closes it, and nothing is docked" eventually docked_are 0

step "a fifth is refused"
key ctrl+opt+g
check "the palette is open" eventually palette
for n in 1 2 3 4 5; do tick "$n"; done
shot 08-four-at-the-most
key escape
check "closed" eventually no_palette

step "one of them is in the Dock: it comes back into the place kept open for it"
tw minimize "$W2" > /dev/null
check "2 is minimized" eventually is minimized "$W2"
key ctrl+opt+g
check "the palette is open" eventually palette
tick 5
tick 2
shot 09-one-in-the-dock-ticked
key return
# At once: window 5 is already in its half, with the other half open.
shot_after 0 10-the-place-is-kept-open
read -r _ _ half _ <<< "$(frame_of "$W5")"
check "2 is out of the Dock" eventually is_not_minimized "$W2"
check "5 is left of 2" eventually left_of "$W5" "$W2"
check "2 is in its slot" eventually is in_slot "$W2"
check "5 is in its slot" is in_slot "$W5"
read -r _ _ now _ <<< "$(frame_of "$W5")"
check "5 was never wider than its half ($half then, $now now)" [ "$((half - now))" -le 3 ] 
shot 11-both-there
summary

step "nothing of a title is in the log"
check "no title in the log" bash -c "! grep -q 'Arbor Test' '$ARBOR_HOME/arbor.log'"
arbor_quit
