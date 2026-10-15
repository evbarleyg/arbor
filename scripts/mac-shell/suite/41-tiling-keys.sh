#!/bin/bash
# The keyboard tiling tools, with real keys on the windows of two apps: the keyboard walks from window to window, and the focused window
# grows, shrinks, is balanced, rotated, mirrored and trades places.
# What only real windows can say: whether the other app really comes forward, whether what macOS reports of that moves the view, and
# whether a window whose app refuses to shrink stays a window.
# A220 move focus with the keyboard, A221 trade places, A222 grow, shrink and balance, A223 rotate and mirror a group.
source "$(dirname "$0")/../lib.sh"
arbor_build

same_width() { about "$(width_of "$1")" "$(width_of "$2")"; }

ARBOR_SECOND_APP=1
# The first window refuses to be narrower than 300 points, which is more than the 240 at which Arbor itself stops shrinking one.
ARBOR_TEST_WINDOWS_ARGS="--min-size 1:300x200"
# `swap` has no shortcut of its own: these are the README's.
arbor_settings '{"bindings": {"ctrl+opt+shift+h": "swap left", "ctrl+opt+shift+l": "swap right"}}'
arbor_start 2 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
ctl dock "$W1" left
ctl dock "$V1" right
# The second window floats between them, clear of both.
take "x y" desktop_point
tw move "$W2" "$((x - 120))" "$((y - 100))" 240 200
summary

claim "⌃⌥⇧→ walks from window to window across two apps, by way of the one that floats between them, and ⌃⌥⇧← walks back"
proves A220
click_window "$W1"
check "the click gave the first window the keyboard" eventually is focused "$W1"
between=$(resting_frame_of "$W2")
hand=$(pointer where)
check "⌃⌥⇧→ reaches Arbor" pressed ctrl+opt+shift+right focus right
check "the floating window has the keyboard" eventually is focused "$W2"
keys=$(events_of "$W2" key)
key_to "$W2" x
check "a letter typed now arrives in it" eventually received "$W2" key -gt "$keys"
check "⌃⌥⇧→ again" pressed ctrl+opt+shift+right focus right
check "the other app's window has it" eventually is focused "$V1"
check "its app is the one in front" eventually front_is "$ARBOR_WINDOWS_PID_2"
keys=$(events_of "$V1" key)
key_to "$V1" x
check "a letter typed now arrives in it" eventually received "$V1" key -gt "$keys"
check "⌃⌥⇧→ at the last window" pressed ctrl+opt+shift+right focus right
check "there is nothing further that way: the keyboard stays" stays is focused "$V1"
check "⌃⌥⇧← reaches Arbor" pressed ctrl+opt+shift+left focus left
check "back on the floating window" eventually is focused "$W2"
check "the first app is in front again" eventually front_is "$ARBOR_WINDOWS_PID"
check "⌃⌥⇧← again" pressed ctrl+opt+shift+left focus left
check "back on the first window" eventually is focused "$W1"
check "the camera has not moved" stays camera_on root
# shellcheck disable=SC2086
check "nor has the floating window" frame_is "$W2" $between
check "the pointer is where the hand left it" test "$(pointer where)" = "$hand"
settled

claim "with one window framed, ⌃⌥⇧→ takes the camera to the next space and the keyboard to what is there"
proves A220
check "⌃⌥↩ reaches Arbor" pressed ctrl+opt+return zoom
check "the first window fills the screen" eventually fills "$W1"
check "⌃⌥⇧→ reaches Arbor" pressed ctrl+opt+shift+right focus right
check "the camera is on the Desktop" eventually camera_on desktop
check "the window that floats there has the keyboard" eventually is focused "$W2"
check "the first window is out of view" eventually out_of_view "$W1"
check "⌃⌥⇧→ again" pressed ctrl+opt+shift+right focus right
check "the other app's window fills the screen" eventually fills "$V1"
check "it has the keyboard" eventually is focused "$V1"
check "its app is the one in front" eventually front_is "$ARBOR_WINDOWS_PID_2"
check "the view stays there once macOS has reported the change" stays fills "$V1"
check "⌃⌥Space reaches Arbor" pressed ctrl+opt+space show-all
check "everything is back in view" eventually in_view "$W1"
settled

claim "⌃⌥⌘= makes the focused window 40 points wider and ⌃⌥⌘- takes them back"
proves A222
click_window "$W1"
width=$(width_of "$W1")
other=$(resting_frame_of "$V1")
check "⌃⌥⌘= reaches Arbor" pressed ctrl+opt+cmd+= grow
check "the window is 40 points wider" eventually width_is "$W1" "$((width + 40))"
check "it still reaches the left edge" at_edge "$W1" left
# shellcheck disable=SC2086
check "the Desktop gave the room: the other app's window has not moved" frame_is "$V1" $other
settled
check "⌃⌥⌘- reaches Arbor" pressed ctrl+opt+cmd+- shrink
check "the window has its width back" eventually width_is "$W1" "$width"
settled

claim "⌃⌥⌘- again and again on a window whose app refuses to shrink: it stops at the size the app allows and never turns into a tile"
proves A222
# However wide the screen is: until Arbor says that it is enough, and twice more.
presses=0
enough=0
while [ "$presses" -lt 60 ] && [ "$enough" -lt 3 ]; do
  key ctrl+opt+cmd+-
  presses=$((presses + 1))
  if logged "cannot shrink any further" > /dev/null; then enough=$((enough + 1)); fi
done
check "Arbor ran shrink" eventually ran shrink
check "in the end it says that the window cannot shrink any further" eventually logged "cannot shrink any further"
check "the window is as narrow as its app allows" eventually width_is "$W1" 300
check "it stays so" stays width_is "$W1" 300
check "it is no tile" fails is tile "$W1"
check "it is in view" in_view "$W1"
check "it is in its slot" in_slot "$W1"
check "it still has the keyboard" is focused "$W1"
check "the camera has not moved" camera_on root
settled

claim "⌃⌥⌘0 balances the sizes: the two docked windows are equally wide again"
proves A222
check "at first they are not: the first was shrunk" fails same_width "$W1" "$V1"
check "⌃⌥⌘0 reaches Arbor" pressed ctrl+opt+cmd+0 balance
check "now they are" eventually same_width "$W1" "$V1"
check "the first is as wide as it was when it was docked" width_is "$W1" "$width"
check "the Desktop is still between them" desktop_between "$W1" "$V1"
settled

claim "⌃⌥R turns the row into a column, and ⌃⌥R again turns it back to the point"
proves A223
one=$(resting_frame_of "$W1")
two=$(resting_frame_of "$V1")
check "⌃⌥R reaches Arbor" pressed ctrl+opt+r rotate
check "the first window is above the other app's" eventually above "$W1" "$V1"
check "it is as wide as the screen" eventually at_edge "$W1" right
check "it keeps the keyboard" is focused "$W1"
settled
check "⌃⌥R again" pressed ctrl+opt+r rotate
# shellcheck disable=SC2086
check "the first window is exactly where it was" eventually frame_is "$W1" $one
# shellcheck disable=SC2086
check "so is the other app's" eventually frame_is "$V1" $two
settled

claim "⌃⌥⇧R mirrors the row, and again mirrors it back"
proves A223
check "⌃⌥⇧R reaches Arbor" pressed ctrl+opt+shift+r mirror
check "the other app's window is on the left now" eventually left_of "$V1" "$W1"
check "at the left edge" eventually at_edge "$V1" left
check "the first window is at the right edge" eventually at_edge "$W1" right
check "it keeps the keyboard" is focused "$W1"
settled
check "⌃⌥⇧R again" pressed ctrl+opt+shift+r mirror
# shellcheck disable=SC2086
check "the first window is exactly where it was" eventually frame_is "$W1" $one
settled

claim "a shortcut bound to swap right in settings.json: the focused window trades places with the other app's, and the places keep their sizes"
proves A221
ctl grow 60
check "the first window is the wider one" eventually wider_than "$W1" "$(($(width_of "$V1") + 40))"
wide=$(resting_frame_of "$W1")
narrow=$(resting_frame_of "$V1")
check "⌃⌥⇧L reaches Arbor" pressed ctrl+opt+shift+l swap right
# shellcheck disable=SC2086
check "the first window has the narrow place on the right" eventually frame_is "$W1" $narrow
# shellcheck disable=SC2086
check "the other app's has the wide one on the left" eventually frame_is "$V1" $wide
check "the keyboard went along with the first window" eventually is focused "$W1"
check "the camera has not moved" camera_on root
settled
check "⌃⌥⇧H reaches Arbor" pressed ctrl+opt+shift+h swap left
# shellcheck disable=SC2086
check "they have traded back" eventually frame_is "$W1" $wide
settled

# Adjust ▸ has gone into Arrangement ▸. The claim keeps its words: collab/parity.json and the evidence of the last run on a Mac go by them.
claim "choose Adjust, Balance Sizes and Adjust, Mirror Group from the menu: they do what the shortcuts do"
proves A222 A223
check "Balance Sizes can be clicked" click_menu "Arrangement" "Balance Sizes"
check "Arbor ran balance" eventually ran balance
check "the two docked windows are equally wide" eventually same_width "$W1" "$V1"
check "Mirror Group can be clicked" click_menu "Arrangement" "Mirror Group"
check "Arbor ran mirror" eventually ran mirror
check "the other app's window is on the left" eventually left_of "$V1" "$W1"
settled

arbor_stop

# The third window refuses to be smaller than seven tenths of the screen each way: too big for half a column, small enough to be framed.
read -r _ _ _ screen_w screen_h _ <<< "$(pointer displays | head -n 1)"
[ -n "$screen_h" ] || die "the pointer tool lists no display"
ARBOR_SECOND_APP=0
ARBOR_TEST_WINDOWS_ARGS="--min-size 3:$((screen_w * 7 / 10))x$((screen_h * 7 / 10))"
# On a large screen Arbor would move the gaps and make room for it.
arbor_settings '{"makeRoom": false}'
arbor_start 3 ARBOR_NO_HOTKEYS=0
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W2" bottom
summary

claim "⌃⌥⇧↓ toward a tile: the camera goes onto it, its window has the keyboard, and ⌃⌥[ goes back"
proves A220
check "a tile stands in for the third window" eventually is tile "$W3"
click_window "$W2"
check "the window above the tile has the keyboard" eventually is focused "$W2"
check "⌃⌥⇧↓ reaches Arbor" pressed ctrl+opt+shift+down focus down
check "the tile's window fills the screen" eventually fills "$W3"
check "it has the keyboard" eventually is focused "$W3"
check "the window above it is out of view" eventually out_of_view "$W2"
check "the view stays there once macOS has reported the change" stays fills "$W3"
check "⌃⌥[ reaches Arbor" pressed "ctrl+opt+[" back
check "the tile is back" eventually is tile "$W3"
check "so is the window above it" eventually in_view "$W2"
settled

arbor_stop
