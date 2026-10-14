#!/bin/bash
# F56 on real windows, with real keys: shortcuts follow the keyboard, unless the pointer moved last.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-F56.sh
#
# What only a Mac can say: whether macOS's own figures (how long the pointer has been still, how long since a
# key was released, how many keys were pressed) tell typing, pointing and Arbor's own shortcuts apart as
# InputLead expects. `pointer activity` prints them before every shortcut, and arbor.log (debug) has a line
# each time the lead changes hands.
#
# The part on two displays plugs in a virtual display, so it runs only on GitHub's Macs. The rest touches nothing but
# its own test windows, the pointer and the keyboard: it types a few letters into a test window.
source "$(dirname "$0")/lib.sh"

arbor_build
arbor_start 2 ARBOR_NO_HOTKEYS=0

framed() { ! is parked "$1" && is parked "$2"; }
both_in_view() { ! is parked "$1" && ! is parked "$2"; }
# Letters into whatever has the keyboard, as someone writing does.
type_a_word() {
  local letter
  for letter in a r b o r; do pointer key "$letter"; done
  echo "> typed a word"
}
shortcut() {
  echo "  $(pointer activity)"
  key "$1"
}

step "One display: which way ⌃⌥↓ steps"
ctl dock "$W1" left
ctl dock "$W2" right
# shellcheck disable=SC2046
click $(center_of "$W2")
check "the clicked window has the keyboard" eventually is focused "$W2"
# shellcheck disable=SC2046
move $(center_of "$W1")
type_a_word
sleep 0.3
shortcut ctrl+opt+down
check "typing in w2 with the pointer pushed aside over w1: ⌃⌥↓ frames w2" eventually framed "$W2" "$W1"
shot 01-toward-the-keyboard
shortcut ctrl+opt+up
check "⌃⌥↑ shows both again" eventually both_in_view "$W1" "$W2"

step "Pointing at a window and pressing ⌃⌥↓ means that window, and so do the shortcuts after it"
sleep 1
# Not to the centre, where the pointer already is: moves of distance zero may not count as moving.
# shellcheck disable=SC2046
move $(arbor_point $(center_of "$W1") 0 0 "x + 20" "y + 20")
sleep 0.3
shortcut ctrl+opt+down
check "the pointer moved last: ⌃⌥↓ frames w1" eventually framed "$W1" "$W2"
sleep 1.5
shortcut ctrl+opt+up
check "⌃⌥↑ shows both again" eventually both_in_view "$W1" "$W2"
summary

step "arborctl chooses as a shortcut does"
# shellcheck disable=SC2046
click $(center_of "$W2")
# shellcheck disable=SC2046
move $(center_of "$W1")
type_a_word
sleep 0.3
echo "  $(pointer activity)"
ctl in
check "arborctl in, after typing in w2: w2 is framed" eventually framed "$W2" "$W1"
ctl show-all

step "stepInToward: pointer is how it was before"
arbor_stop
arbor_settings '{"stepInToward": "pointer"}'
arbor_start 2 ARBOR_NO_HOTKEYS=0
ctl dock "$W1" left
ctl dock "$W2" right
# shellcheck disable=SC2046
click $(center_of "$W2")
# shellcheck disable=SC2046
move $(center_of "$W1")
type_a_word
sleep 0.3
shortcut ctrl+opt+down
check "with stepInToward pointer, ⌃⌥↓ frames the window under the pointer" eventually framed "$W1" "$W2"
arbor_stop

echo
# Not needs_throwaway_mac: its exit code would hide a check that failed above.
if ! on_throwaway_mac; then
  echo "skipped: the rest would plug in a virtual second display, and this Mac is somebody's."
  exit 0
fi

step "Two displays: the trap"
display_add 1280 800 right
arbor_start 4 ARBOR_NO_HOTKEYS=0
ctl dock "$W1" left
ctl dock "$W2" right
# The test windows open in a cascade with the last one in front, so w4 covers w3's title bar: front to back.
# shellcheck disable=SC2046
drag $(titlebar_of "$W4") $(arbor_point $(screen_of 2) "x + w - 3" "y + h / 2")
check "w4 docked on the second display" eventually is display2 "$W4"
ctl dock "$W3" beside "$W4" left
ctl zoom "$W1"
ctl zoom "$W3"
check "a window is framed on each display" eventually framed "$W1" "$W2"
check "a window is framed on each display" eventually framed "$W3" "$W4"
# shellcheck disable=SC2046
click $(center_of "$W3")
# shellcheck disable=SC2046
move $(center_of "$W1")
type_a_word
sleep 0.3
shortcut ctrl+opt+up
check "typing on the second display, the pointer at rest on the first: ⌃⌥↑ zooms the second out" \
  eventually both_in_view "$W3" "$W4"
check "and the first display stays as it was" framed "$W1" "$W2"
panorama 02-the-display-being-typed-on
shortcut ctrl+opt+return
check "⌃⌥↩, pressed next, acts on the same display" eventually framed "$W3" "$W4"

step "Two displays: pointing"
sleep 1
# shellcheck disable=SC2046
move $(arbor_point $(center_of "$W1") 0 0 "x + 20" "y + 20")
sleep 0.3
shortcut ctrl+opt+up
check "the pointer moved last: ⌃⌥↑ zooms the display under it out" eventually both_in_view "$W1" "$W2"
check "and the display with the keyboard stays as it was" framed "$W3" "$W4"
panorama 03-the-display-pointed-at
arbor_stop 04-after-quit
