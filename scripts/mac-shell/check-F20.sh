#!/bin/bash
# F20, named spaces, on real windows and with real key presses:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-F20.sh
#
# What only a Mac can settle is the field (NamePanel): that a borderless panel of an app that is never active gets
# the keys, that ↩, ⎋, ⌃⌥N and a click elsewhere do what the model says, that the app in front stays in front and has
# the keyboard again afterwards, and what it looks like. Names, `go` and the menu are checked on the way.
#
# Safe on a person's Mac: it touches only its own test windows and changes no setting. It moves the pointer and
# presses keys, always with the test app in front, so a key the field misses lands in a test window.
source "$(dirname "$0")/lib.sh"

# The field is the only one of Arbor's windows at the level of a modal panel.
field_open() { has_overlay 8; }
field_closed() { ! has_overlay 8; }
named() { "$ARBOR_BIN/arborctl" spaces | grep -q "^$1 "; }
not_named() { ! named "$1"; }
in_view() { "$ARBOR_BIN/arborctl" spaces | grep "^$1 " | grep -q "in view"; }
# The process, not the name: on a person's Mac that may be an app of theirs.
front() { pointer front 2>/dev/null; }
type_keys() {
  local word
  for word in "$@"; do key "$word"; done
}

arbor_build
step "three windows: [1 | Desktop | 2 / 3], shortcuts and the menu bar item on"
# An ordinary app, so that it can be the app in front.
ARBOR_TEST_WINDOWS_ARGS="--regular"
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0 ARBOR_PANELS_IN_PICTURES=1
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W2" bottom
# shellcheck disable=SC2046
click $(center_of "$W3")
ctl zoom "$W3"
ctl out
summary
before=$(front)

step "⌃⌥N, type, ↩"
key ctrl+opt+n
check "⌃⌥N shows the field" eventually field_open
shot 01-field-empty
check "the app in front stays in front" [ "$(front)" = "$before" ]
check "its window is still the focused window" is focused "$W3"
type_keys shift+p a i r
shot 02-field-typed
key return
check "↩ closes the field" eventually field_closed
check "and names the space, with the capital" eventually named Pair
check "no window moved: 2 and 3 are in their slots" is in_slot "$W2"
check "the app in front is the same as before" [ "$(front)" = "$before" ]
ctl spaces
ctl ascii

step "the keyboard is back with the app"
# ⌃⌥↩ frames the focused window: it still has to be window 3.
key ctrl+opt+return
check "⌃⌥↩ frames window 3, which has the keyboard again" eventually is parked "$W2"
ctl back

step "a name that is refused keeps the field open; ⎋ closes it"
key ctrl+opt+n
check "the field is open" eventually field_open
shot 03-field-rename
type_keys u p
shot 04-field-refused
key return
check "the name up is refused and the field stays" field_open
key escape
check "⎋ closes it" eventually field_closed
check "the name is as it was" named Pair

step "⌃⌥N again, and a click elsewhere, close it"
key ctrl+opt+n
check "open" eventually field_open
key ctrl+opt+n
check "⌃⌥N again closes it" eventually field_closed
key ctrl+opt+n
check "open" eventually field_open
# shellcheck disable=SC2046
click $(center_of "$W2")
check "a click in a window closes it" eventually field_closed

step "it closes when the view leaves its space"
key ctrl+opt+n
check "open" eventually field_open
key ctrl+opt+space
check "⌃⌥Space shows everything and the field is gone" eventually field_closed
check "everything is in view" eventually is on_screen "$W1"

step "go, by the beginning of the name"
ctl go pa
check "the view is on Pair" eventually in_view Pair
check "window 1 is out of view" eventually is parked "$W1"

step "the menu"
# A right click: with something docked the item is a row of buttons, and a plain click in its middle presses Show the Desktop.
open_menu
shot 05-menu
key escape

step "an empty field removes the name"
key ctrl+opt+n
check "open, with the name selected" eventually field_open
key delete
shot 06-field-emptied
key return
check "↩ on an empty field closes it" eventually field_closed
check "and the name is gone" eventually not_named Pair

step "pause closes it"
key ctrl+opt+n
check "open" eventually field_open
ctl pause
check "pausing closes the field" eventually field_closed
ctl resume
check "and it does not come back" field_closed

arbor_stop 07-quit

step "the field drawn dark: empty, with a name, and with the red line under a name that is refused"
# This Arbor's own windows alone: the Mac's appearance stays as it is.
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_APPEARANCE=dark
ctl dock "$W1" left
ctl dock "$W2" right
# shellcheck disable=SC2046
click $(center_of "$W2")
key ctrl+opt+n
check "⌃⌥N shows the field" eventually field_open
shot 08-dark-empty
type_keys shift+p a i r
shot 09-dark-typed
key return
check "↩ names the space" eventually named Pair
key ctrl+opt+n
check "the field is open again, with the name" eventually field_open
type_keys u p
shot 10-dark-refused
key escape
check "⎋ closes it" eventually field_closed
arbor_stop 11-dark-quit
