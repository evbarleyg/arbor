#!/bin/bash
# Keys follow the keyboard, gestures follow the pointer: which way ⌃⌥↓ steps in when the window being typed in and the
# window under the pointer are two. On one display; which display a shortcut acts on needs a second one.
# A56 keys follow the keyboard, gestures follow the pointer.
source "$(dirname "$0")/../lib.sh"
source "$(dirname "$0")/../lib-gestures.sh"
arbor_build

only_shows() { fills "$1" && out_of_view "$2"; }
both_show() { in_slot "$W1" && in_slot "$W2" && in_view "$W1" && in_view "$W2"; }
# types_into <id>: a few letters, as someone writing does, and they arrive.
types_into() {
  local keys letter
  keys=$(events_of "$1" key) || return 1
  for letter in a r b o r; do key_to "$1" "$letter" || return 1; done
  eventually received "$1" key -ge "$((keys + 5))"
}
# points_at <id>: the pointer moves onto the window, from wherever it is. Not to the very middle every time: a move to where
# the pointer already is may not count as one.
nudge=0
points_at() {
  take "x y" center_of "$1"
  nudge=$((nudge + 6))
  move "$((x + nudge))" "$((y + nudge))"
}

# The pinch and the rectangle need event taps, which Arbor asks for only where its person has asked for the gestures.
arbor_settings "{$ARBOR_GESTURES_ON}"
arbor_start 2 ARBOR_NO_HOTKEYS=0
ctl dock "$W1" left
ctl dock "$W2" right
summary

claim "click a window, push the pointer aside onto another and type: ⌃⌥↓ steps in toward the window being typed in"
proves A56
click_window "$W2"
check "the clicked window has the keyboard" eventually is focused "$W2"
points_at "$W1"
check "what is typed reaches the clicked window" types_into "$W2"
check "⌃⌥↓ reaches Arbor" pressed ctrl+opt+down in
check "the window being typed in fills the screen, the one under the pointer is out of view" eventually only_shows "$W2" "$W1"
check "⌃⌥↑ reaches Arbor" pressed ctrl+opt+up out
check "both are back" eventually both_show
settled

claim "point at the other window and press ⌃⌥↓: the pointer moved last, so the view steps in toward the window under it"
proves A56
check "the keyboard is still in the window that was typed in" is focused "$W2"
points_at "$W1"
check "⌃⌥↓ reaches Arbor" pressed ctrl+opt+down in
check "the window under the pointer fills the screen, the one that was typed in is out of view" eventually only_shows "$W1" "$W2"
check "⌃⌥↑ reaches Arbor" pressed ctrl+opt+up out
check "both are back" eventually both_show
settled

claim "type in the other window and run arborctl in, by command: it chooses as the shortcut does"
proves A56
click_window "$W1"
points_at "$W2"
check "what is typed reaches the clicked window" types_into "$W1"
check "in succeeds" ctl in
check "the window being typed in fills the screen" eventually only_shows "$W1" "$W2"
ctl show-all
settled

claim "set stepInToward to focus by command: ⌃⌥↓ steps in toward the focused window even straight after pointing at another"
proves A56
check "set stepInToward focus succeeds" ctl set stepInToward focus
click_window "$W2"
check "the clicked window has the keyboard" eventually is focused "$W2"
points_at "$W1"
check "⌃⌥↓ reaches Arbor" pressed ctrl+opt+down in
check "the focused window fills the screen, the one under the pointer is out of view" eventually only_shows "$W2" "$W1"
check "⌃⌥↑ reaches Arbor" pressed ctrl+opt+up out
check "both are back" eventually both_show
settled

claim "with stepInToward on focus, hold ⌥ and spread two fingers over the other window: a pinch follows the pointer all the same"
proves A56
check "the keyboard is in the window that was clicked" is focused "$W2"
# shellcheck disable=SC2046
pinch $(center_of "$W1") 0.3 --mods opt
check "Arbor stepped in" eventually ran in
check "the window under the fingers fills the screen, the focused one is out of view" eventually only_shows "$W1" "$W2"
ctl show-all
settled

claim "set stepInToward to pointer by command: ⌃⌥↓ steps in toward the window under the pointer even straight after typing in another"
proves A56
check "set stepInToward pointer succeeds" ctl set stepInToward pointer
click_window "$W2"
points_at "$W1"
check "what is typed reaches the clicked window" types_into "$W2"
check "⌃⌥↓ reaches Arbor" pressed ctrl+opt+down in
check "the window under the pointer fills the screen, the one being typed in is out of view" eventually only_shows "$W1" "$W2"
ctl show-all
check "set stepInToward auto succeeds" ctl set stepInToward auto
settled

arbor_stop
