#!/bin/bash
# F22, the keyboard tiling tools, on real windows: does focus really move (by command and by the real
# shortcuts), do the echoes macOS sends back leave the camera alone, does a window whose app refuses to
# shrink stay a window, is ⌃⌥R its own way back, and what does the menu look like.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-F22.sh
#
# Nothing here crosses displays: the runner has one, and on a Mac with two the test windows stay where they opened.
source "$(dirname "$0")/lib.sh"
arbor_build

# The camera's node, to see that it stays where it should.
camera() { summary | sed -n 's/.*camera \(n[0-9]*\),.*/\1/p' | head -n 1; }
width_of() { frame_of "$1" | cut -d ' ' -f 3; }
height_of() { frame_of "$1" | cut -d ' ' -f 4; }
# Whether two numbers are within $3 of each other.
about() { [ "$(($1 - $2))" -le "$3" ] && [ "$(($2 - $1))" -le "$3" ]; }
focus_is() { check "$2" eventually is focused "$1"; }

# The second window refuses to be narrower than 300 points, which is more than Arbor's own limit of 240.
ARBOR_TEST_WINDOWS_ARGS="--min-size 2:300x200"
step "session 1: [ 1 / 3 | Desktop with 4 floating | 2 ], shortcuts and the menu bar item on"
arbor_start 4 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W1" bottom
sleep 0.5
root=$(camera)
summary
# shellcheck disable=SC2046
click $(center_of "$W1")
focus_is "$W1" "a click focused window 1"
shot 01-start

step "focus by command"
ctl focus right; focus_is "$W4" "focus right went to the floating window in between"
ctl focus right; focus_is "$W2" "focus right went on to window 2"
ctl focus right
ctl focus left;  focus_is "$W4" "focus left came back to the floating window"
ctl focus left;  focus_is "$W1" "focus left came back to window 1, in focus more recently than 3"
ctl focus down;  focus_is "$W3" "focus down went to window 3"
ctl focus next;  focus_is "$W2" "focus next follows the tree"
ctl focus next;  focus_is "$W4" "and then the floating windows"
ctl focus previous; focus_is "$W2" "focus previous goes back"
ctl focus "$W1"; focus_is "$W1" "focus by id"
sleep 0.5
check "the camera has not moved" test "$(camera)" = "$root"
shot 02-focus

step "focus by the real shortcuts"
key ctrl+opt+shift+down;  focus_is "$W3" "⌃⌥⇧↓ went to window 3"
key ctrl+opt+shift+up;    focus_is "$W1" "⌃⌥⇧↑ went to window 1"
key ctrl+opt+shift+right; focus_is "$W4" "⌃⌥⇧→ went to the floating window"
key ctrl+opt+shift+left;  focus_is "$W1" "⌃⌥⇧← went back"

step "framed on one window, the same keys walk from space to space"
ctl zoom "$W1"
key ctrl+opt+shift+down; focus_is "$W3" "⌃⌥⇧↓ went to window 3"
check "window 3 is in view" eventually is on_screen "$W3"
check "window 1 is tucked away" eventually is parked "$W1"
shot 03-framed-down
key ctrl+opt+shift+right; focus_is "$W4" "⌃⌥⇧→ went to the Desktop and its floating window"
shot 04-framed-desktop
key ctrl+opt+shift+right; focus_is "$W2" "⌃⌥⇧→ went on to window 2"
sleep 1
check "and it stays there once macOS has reported the change" is focused "$W2"
check "window 2 is in view" is on_screen "$W2"
summary
ctl show-all

step "swap: the slots keep their sizes"
ctl resize "$W1" right 60
# shellcheck disable=SC2046
click $(center_of "$W1")
focus_is "$W1" "a click focused window 1"
wide=$(width_of "$W1"); narrow=$(width_of "$W2")
ctl swap right
sleep 0.7
echo "window 1 was $wide wide and is $(width_of "$W1"); window 2 was $narrow and is $(width_of "$W2")"
check "window 1 took the narrow slot" about "$(width_of "$W1")" "$narrow" 2
check "window 2 took the wide slot" about "$(width_of "$W2")" "$wide" 2
focus_is "$W1" "focus stayed with window 1"
check "the camera has not moved" test "$(camera)" = "$root"
shot 05-swapped
ctl swap left
ctl balance

step "grow, shrink and balance by the real shortcuts"
sleep 0.5
before=$(width_of "$W1"); tall=$(height_of "$W1")
key ctrl+opt+cmd+=
sleep 0.7
echo "window 1 was ${before}x$tall and is $(width_of "$W1")x$(height_of "$W1")"
check "⌃⌥⌘= made it 40 points wider" about "$(width_of "$W1")" "$((before + 40))" 2
check "and 40 points taller" about "$(height_of "$W1")" "$((tall + 40))" 2
shot 06-grown
key ctrl+opt+cmd+-
sleep 0.7
check "⌃⌥⌘- took them back" about "$(width_of "$W1")" "$before" 2
ctl grow 90
key ctrl+opt+cmd+0
sleep 0.7
check "⌃⌥⌘0 evened the sizes out" about "$(width_of "$W1")" "$before" 2

step "a window whose app refuses to shrink stays a window"
# shellcheck disable=SC2046
click $(center_of "$W2")
focus_is "$W2" "a click focused window 2"
ctl shrink 200
sleep 1
summary
check "window 2 is not a tile" fails is tile "$W2"
check "it is in view" is on_screen "$W2"
check "it stopped at the 300 points its app insists on" about "$(width_of "$W2")" 301 3
focus_is "$W2" "it still has focus"
check "the camera has not moved" test "$(camera)" = "$root"
shot 07-shrunk-to-the-minimum
ctl shrink
ctl balance

step "rotate and mirror by the real shortcuts"
key ctrl+opt+r
sleep 0.7
summary
shot 08-rotated
read -r _ y1 _ _ <<< "$(frame_of "$W1")"; read -r _ y2 _ _ <<< "$(frame_of "$W2")"; read -r x1 _ _ _ <<< "$(frame_of "$W1")"; read -r x3 _ _ _ <<< "$(frame_of "$W3")"
check "⌃⌥R stacked the row: window 1 is above window 2" test "$y1" -lt "$y2"
check "and the column inside became a row: window 1 is left of window 3" test "$x1" -lt "$x3"
key ctrl+opt+shift+r
sleep 0.7
read -r _ y1 _ _ <<< "$(frame_of "$W1")"; read -r _ y2 _ _ <<< "$(frame_of "$W2")"
check "⌃⌥⇧R mirrored it: window 2 is above window 1" test "$y2" -lt "$y1"
shot 09-mirrored
key ctrl+opt+shift+r
key ctrl+opt+r
sleep 0.7
read -r x1 _ _ _ <<< "$(frame_of "$W1")"; read -r x2 _ _ _ <<< "$(frame_of "$W2")"
check "and back: window 1 is left of window 2" test "$x1" -lt "$x2"

step "⌃⌥R on a pair inside the row is its own way back"
# Room for the two side by side: on this display a third of the width would make them tiles, and ⌃⌥R would refuse.
ctl resize "$W1" right 200
# shellcheck disable=SC2046
click $(center_of "$W1")
focus_is "$W1" "a click focused window 1"
one=$(frame_of "$W1"); two=$(frame_of "$W2"); three=$(frame_of "$W3")
key ctrl+opt+r
sleep 0.7
summary
shot 09b-pair-rotated
read -r x1 y1 _ _ <<< "$(frame_of "$W1")"; read -r x3 y3 _ _ <<< "$(frame_of "$W3")"
check "windows 1 and 3 are side by side" test "$x1" -lt "$x3" -a "$y1" -eq "$y3"
check "window 2 has not moved" test "$(frame_of "$W2")" = "$two"
key ctrl+opt+r
sleep 0.7
check "the second press put window 1 back" test "$(frame_of "$W1")" = "$one"
check "and window 3" test "$(frame_of "$W3")" = "$three"
check "and left window 2 alone" test "$(frame_of "$W2")" = "$two"
ctl balance

step "the pointer stays where the hand left it"
move 20 400
ctl focus-display 1
sleep 0.3
read -r px py _ <<< "$(pointer where)"
check "focus-display did not move the pointer" about "${px%.*}" 20 2
check "in either direction" about "${py%.*}" 400 2

step "the menu"
if item=$(status_item); then
  # shellcheck disable=SC2086
  rightclick $item
  shot 10-menu
  key escape
fi
arbor_stop 11-after-quit

# The third window refuses to be smaller than 700×500, so half a column turns it into a tile.
ARBOR_TEST_WINDOWS_ARGS="--min-size 3:700x500"
step "session 2: a tile in the way is entered"
arbor_start 3
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W2" bottom
sleep 1
ctl show-all
sleep 0.5
summary
check "window 3 is a tile" is tile "$W3"
# shellcheck disable=SC2046
click $(center_of "$W2")
focus_is "$W2" "a click focused window 2"
shot 20-tile
ctl focus down
focus_is "$W3" "focus down entered the tile"
check "window 3 is in view" eventually is on_screen "$W3"
shot 21-tile-entered
ctl back
sleep 0.5
step "swapping into a slot too small leaves a tile, and the view where it was"
ctl show-all
sleep 0.5
root=$(camera)
# shellcheck disable=SC2046
click $(center_of "$W1")
focus_is "$W1" "a click focused window 1"
ctl swap "$W1" "$W3"
sleep 1
summary
check "the camera has not moved" test "$(camera)" = "$root"
shot 22-swapped-with-a-tile
arbor_stop 23-after-quit
