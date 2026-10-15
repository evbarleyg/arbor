#!/bin/bash
# Tiles: what stands in for a window that cannot be shown in its slot, and whose a click is where a floating window lies over one.
# T20 windows that cannot shrink do not overlap, T50 tiles, T51 group tiles, A05 minimum sizes learned from apps,
# A69 room before tiles.
source "$(dirname "$0")/../lib.sh"
arbor_build
# Where macOS tiles at the screen's edges they are macOS's, and the last session, which docks there, skips itself.
if screen_edges_dock; then edges=ours; else edges=""; fi
# The third window refuses to be smaller than seven tenths of the screen each way: too big for half of it, small enough
# to be framed on its own.
read -r _ _ _ screen_w screen_h _ <<< "$(pointer displays | head -n 1)"
[ -n "$screen_h" ] || die "the pointer tool lists no display"
ARBOR_TEST_WINDOWS_ARGS="--min-size 3:$((screen_w * 7 / 10))x$((screen_h * 7 / 10))"
# On a large screen Arbor would move the gaps and make room for it. That is the last session's subject; these are about tiles.
arbor_settings '{"makeRoom": false}'

# in_front_at <id> x y: of all that lies at that point, the window is the first to get a press: no panel of Arbor's at the windows'
# own level comes before it in the window server's list, which goes from front to back. The focus ring's panel is passed
# over: it holds the whole window, is meant to lie in front of it, and lets presses through.
in_front_at() {
  local frame
  frame=$(real_frame_of "$1") || { echo "the window server has no such window"; return 1; }
  "$ARBOR_POINTER" windows --on-screen | awk -v id="$1" -v arbor="$ARBOR_PID" -v x="$2" -v y="$3" -v frame="$frame" '
    BEGIN { split(frame, f, " ") }
    $1 == id { found = 1; exit }
    $2 != arbor || $3 != 0 || x < $4 || x >= $4 + $6 || y < $5 || y >= $5 + $7 { next }
    $4 <= f[1] && $5 <= f[2] && $4 + $6 >= f[1] + f[3] && $5 + $7 >= f[2] + f[4] { next }
    { print "a panel of Arbor\047s lies in front of it, at", $4, $5, $6, $7; exit }
    END { exit !found }'
}
# shared <id> <id of a window with a tile>: x y, the middle of what the first window's content and the tile have in common. Fails
# when that is under 40 points either way: too little to aim at.
shared() {
  local fx fy fw fh kx ky kw kh left right top bottom
  take "fx fy fw fh" real_frame_of "$1"
  take "kx ky kw kh" arbor_ask tile "$2"
  left=$((fx > kx ? fx : kx)); right=$((fx + fw < kx + kw ? fx + fw : kx + kw))
  # Below its title bar.
  top=$((fy + 40 > ky ? fy + 40 : ky)); bottom=$((fy + fh < ky + kh ? fy + fh : ky + kh))
  [ "$((right - left))" -ge 40 ] && [ "$((bottom - top))" -ge 40 ] \
    || { echo "the window is at $fx $fy $fw $fh, the tile at $kx $ky $kw $kh"; return 1; }
  echo "$(((left + right) / 2)) $(((top + bottom) / 2))"
}

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

claim "drag a floating window over a tile and resize under it by command: it stays in front, and a click where the tile lies is the window's"
take "x y" desktop_point
open_window F1 size=300x160 "at=$((x - 150)),$((y - 80))" title=Over the tile
# By hand: where a person puts a window it stays. Onto the tile's middle, because its edges are places to dock at.
# shellcheck disable=SC2046
drag_window "$F1" $(tile_of "$W3") --steps 60
check "the window floats" eventually is floating "$F1"
# With nothing in common there is no point to click at, and `take` would end the section.
if check "it lies over the tile" shared "$F1" "$W3"; then
  # It trails the pointer, so where the two overlap is measured.
  take "x y" shared "$F1" "$W3"
  place=$(real_frame_of "$F1")
  # There and back: the tile is where it was, and has been shown anew twice.
  check "the first resize succeeds" ctl resize "$W1" right -20
  check "and the one that takes it back" ctl resize "$W1" right 20
  # shellcheck disable=SC2086
  check "the floating window has stayed where it was put" stays frame_is "$F1" ${place:-0 0 0 0}
  check "Arbor still draws the tile" eventually tile_shown "$W3"
  check "the window is in front of the tile" in_front_at "$F1" "$x" "$y"
  downs=$(events_of "$F1" down)
  click "$x" "$y"
  check "the floating window got the click" eventually received "$F1" down -gt "$downs"
  check "the camera has not gone to the tile's window" stays camera_on root
  check "a tile still stands in for it" is tile "$W3"
fi
settled
tw close "$F1"
forget_window "$F1"

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

if [ -n "$edges" ]; then
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
fi
