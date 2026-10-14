#!/bin/bash
# Tiles: what stands in for a window that cannot be shown in its slot.
# T20 windows that cannot shrink do not overlap, T50 tiles, T51 group tiles, A05 minimum sizes learned from apps,
# A69 room before tiles.
source "$(dirname "$0")/../lib.sh"
arbor_build
# The third window refuses to be smaller than seven tenths of the screen each way: too big for half of it, small enough
# to be framed on its own.
read -r _ _ _ screen_w screen_h _ <<< "$(pointer displays | head -n 1)"
[ -n "$screen_h" ] || die "the pointer tool lists no display"
ARBOR_TEST_WINDOWS_ARGS="--min-size 3:$((screen_w * 7 / 10))x$((screen_h * 7 / 10))"
# On a large screen Arbor would move the gaps and make room for it. That is the last session's subject; these are about tiles.
arbor_settings '{"makeRoom": false}'
arbor_start 4
ctl dock "$W1" left

claim "drop a window that refuses to shrink into a slot too small for it: a tile takes its place"
proves A05 T20 T50
# shellcheck disable=SC2046
drag_window "$W3" $(zone_of "$W1" bottom)
check "the window is docked" eventually is docked "$W3"
check "a tile stands in for it" eventually is tile "$W3"
check "it is a window's tile" tile_is "$W3" window
check "Arbor draws the tile where the slot is" eventually tile_shown "$W3"
check "the window itself is out of view" eventually out_of_view "$W3"
check "the camera stayed where it was" camera_on root
check "the window above it is in view" eventually in_view "$W1"
check "nothing overlaps" eventually no_overlaps
settled

claim "click the tile: the camera frames its window"
proves T50
# shellcheck disable=SC2046
click $(tile_of "$W3")
check "the window fills the screen" eventually fills "$W3"
check "the camera is on it" camera_on "$W3"
check "the other docked window is out of view" eventually out_of_view "$W1"
check "it has the keyboard" eventually is focused "$W3"

claim "go back from a tile's window: the tile returns"
proves T50
ctl back
check "a tile stands in for it again" eventually is tile "$W3"
check "Arbor draws it" eventually tile_shown "$W3"
check "the window is out of view" eventually out_of_view "$W3"
check "the window above it is back" eventually in_view "$W1"
settled

claim "dock a window that refuses to shrink by command: the camera stays and a tile takes its place"
ctl float "$W3"
check "the window floats" eventually is floating "$W3"
ctl dock "$W3" beside "$W1" bottom
check "a tile stands in for it" eventually is tile "$W3"
check "the camera stays on everything" stays camera_on root
check "the window above it stays in view" in_view "$W1"

claim "shrink a space below the smallest usable size: one tile stands in for the whole group"
proves T51
ctl show-all
read -r x y <<< "$(seam_right_of "$W1")"
# To 190 points, under the 240 that count as usable.
drag "$x" "$y" "$((x - $(width_of "$W1") + 190))" "$y"
check "a tile stands in for the first window" eventually is tile "$W1"
check "it is a group's tile" tile_is "$W1" group
check "the same tile holds the other window" tile_is "$W3" group
check "there is one tile" count tiles 1
check "Arbor draws it" eventually tile_shown "$W1"
check "both windows are out of view" eventually out_of_view "$W1"

claim "click the group's tile: the camera goes into the group"
proves T51
# shellcheck disable=SC2046
click $(tile_of "$W1")
check "the first window is in view" eventually in_view "$W1"
check "it is as wide as the screen" eventually at_edge "$W1" right
check "the floating windows left with the Desktop" eventually out_of_view "$W2"
ctl show-all

claim "a floating window that cannot shrink stays on the screen when the Desktop gets narrow"
ctl float-all
ctl dock "$W1" left
check "the window floats" is floating "$W3"
check "all of it is on the screen" eventually in_view "$W3"

claim "a window made to refuse its slot while docked becomes a tile at the next layout"
proves A05
ctl float-all
ctl dock "$W2" left
ctl dock "$W4" beside "$W2" bottom
check "it fits its slot at first" eventually in_slot "$W4"
tw min-size "$W4" "$((screen_w * 7 / 10))" "$((screen_h * 7 / 10))"
ctl zoom "$W4"
ctl back
check "a tile stands in for it" eventually is tile "$W4"
check "nothing overlaps" eventually no_overlaps

# Docked, so that what quitting does with a window too big for the Desktop (the claim above) is not mixed up with
# what it does with every other.
step "before quitting"
ctl dock "$W3" right
ctl show-all
arbor_stop

# The second window refuses to be narrower than 45 hundredths of the screen: more than the third it would get.
ARBOR_TEST_WINDOWS_ARGS="--min-size 2:$((screen_w * 45 / 100))x200"
arbor_start 3
ctl dock "$W1" left

claim "drag a window too wide for a third of the screen to the edge: the gaps move to make room, and it is no tile"
proves A69
# shellcheck disable=SC2046
drag_window "$W2" $(edge_point right)
check "the window is docked" eventually is docked "$W2"
check "no tile stands in for it" stays fails is tile "$W2"
check "it is in view" eventually in_view "$W2"
check "in its slot" eventually in_slot "$W2"
check "which is as wide as the window needs" eventually wider_than "$W2" "$((screen_w * 45 / 100 - 4))"
check "it reaches the right edge of the screen" eventually at_edge "$W2" right
check "the Desktop is still between the two" eventually desktop_between "$W1" "$W2"
check "nothing overlaps" eventually no_overlaps
check "the log says that it made room" logged "made room for"
settled
arbor_stop
