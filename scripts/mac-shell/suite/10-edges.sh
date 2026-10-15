#!/bin/bash
# Docking by dragging a window to each edge of the screen, the preview on the way, and dragging it off again.
# T01 dock at a screen edge, T03 the Desktop stays, T06 a leaving window's space, T10 what is no target,
# T11 the drop preview, A229 a floating window's frame is its person's.
source "$(dirname "$0")/../lib.sh"
arbor_build
if ! screen_edges_dock; then
  echo "skipped: macOS tiles at the screen's edges on this Mac, and Arbor stands aside there"
  exit 77
fi
# is_at <id> <x> <y> <w> <h>: by the window server.
is_at() {
  local id=$1
  shift
  arbor_close "$(real_frame_of "$id")" "$*" || { echo "it is at $(real_frame_of "$id"), not at $*"; return 1; }
}
arbor_start 4
first=$(real_frame_of "$W1") second=$(real_frame_of "$W2") third=$(real_frame_of "$W3")

claim "drag a window to the left screen edge: a preview shows where it will land, and it docks there"
proves T01 T11
# shellcheck disable=SC2046
drag_window "$W4" $(edge_point left) --no-release
check "a drop preview is on screen while the button is held" eventually has_overlay 3
preview=$(overlay_frame 3)
echo "the preview is at ${preview:-nowhere}"
release
check "the window is docked" eventually is docked "$W4"
check "it reaches the left edge of the screen" eventually at_edge "$W4" left
check "it reaches the top and the bottom too" eventually at_edge "$W4" top
check "it reaches the bottom" eventually at_edge "$W4" bottom
# shellcheck disable=SC2086
check "it landed exactly where the preview was" eventually frame_is "$W4" ${preview:-0 0 0 0}
check "the preview is gone" eventually fails has_overlay 3
settled

claim "a dock moves no floating window: each is exactly where it was, over the docked window or behind it"
proves A229
# shellcheck disable=SC2086
check "the first floating window is where it was, at its size" stays is_at "$W1" $first
# shellcheck disable=SC2086
check "the second" is_at "$W2" $second
# shellcheck disable=SC2086
check "the third" is_at "$W3" $third

claim "drag a window to the right screen edge: it docks there and the Desktop stays between the two"
proves T01 T03
# shellcheck disable=SC2046
drag_window "$W3" $(edge_point right)
check "the window is docked" eventually is docked "$W3"
check "it reaches the right edge of the screen" eventually at_edge "$W3" right
check "the Desktop stays between them" eventually desktop_between "$W4" "$W3"
# shellcheck disable=SC2086
check "the floating windows are still where they were" stays is_at "$W1" $first
# shellcheck disable=SC2086
check "both of them" is_at "$W2" $second
settled

claim "drag a window to the top screen edge: it docks above everything"
proves T01
# shellcheck disable=SC2046
drag_window "$W2" $(edge_point top)
check "the window is docked" eventually is docked "$W2"
check "it reaches the top edge of the screen" eventually at_edge "$W2" top
check "it is as wide as the screen" eventually at_edge "$W2" left
check "to the right edge" eventually at_edge "$W2" right
check "the others are below it" eventually above "$W2" "$W4"
check "both of them" eventually above "$W2" "$W3"
settled

claim "drag a window to the bottom screen edge: it docks below everything"
proves T01
# shellcheck disable=SC2046
drag_window "$W1" $(edge_point bottom)
check "the window is docked" eventually is docked "$W1"
check "it reaches the bottom edge of the screen" eventually at_edge "$W1" bottom
check "the others are above it" eventually above "$W4" "$W1"
check "nothing overlaps" eventually no_overlaps
check "all four are docked" count docked 4
settled

claim "drop a docked window on its own place: it goes back into its slot"
proves A73
take "x y" titlebar_of "$W4"
drag "$x" "$y" "$((x + 25))" "$((y + 30))"
check "it is still docked" eventually is docked "$W4"
check "it is back in its slot" eventually in_slot "$W4"
settled

claim "let go of a docked window over the middle of another: no preview shows, and it goes back into its slot"
proves T10
place=$(real_frame_of "$W4")
other=$(real_frame_of "$W3")
# All the way across the Desktop, which on a wide screen is further than thirty steps can take a window that Arbor is to notice.
# shellcheck disable=SC2046
drag_window "$W4" $(center_of "$W3") --steps 60 --no-release
check "the window has left its slot with the pointer" fails in_slot "$W4"
check "nothing is promised while the button is held" stays fails has_overlay 3
release
# shellcheck disable=SC2086
check "it is back exactly where it was" eventually frame_is "$W4" ${place:-0 0 0 0}
check "it is still docked" is docked "$W4"
# shellcheck disable=SC2086
check "the window it was let go over has not moved" frame_is "$W3" ${other:-0 0 0 0}
check "all four are docked" count docked 4
settled

claim "drag a docked window out onto the Desktop: it floats, and its space goes to the others"
proves T06
height_before=$(height_of "$W4")
# shellcheck disable=SC2046
drag_window "$W2" $(desktop_point)
check "the window floats" eventually is floating "$W2"
check "it is in view" eventually in_view "$W2"
check "the row below moved up to the top edge" eventually at_edge "$W4" top
check "and grew" eventually taller_than "$W4" "$height_before"
check "three are docked" count docked 3
settled

arbor_stop

# The way back: `floatingWindowsMakeWay`, which ships off, keeps floating windows on the Desktop's part of the screen, as until F64.
arbor_settings '{"floatingWindowsMakeWay": true}'
arbor_start 4

claim "with floatingWindowsMakeWay on, floating windows make way for a docked one: none is left behind it"
# shellcheck disable=SC2046
drag_window "$W4" $(edge_point left)
check "the window is docked" eventually is docked "$W4"
check "the first floating window is beside the docked one" eventually left_of "$W4" "$W1"
check "the second" eventually left_of "$W4" "$W2"
check "the third" eventually left_of "$W4" "$W3"
# shellcheck disable=SC2046
drag_window "$W3" $(edge_point right)
check "the window is docked" eventually is docked "$W3"
check "the floating windows are on the Desktop's part of the screen" eventually left_of "$W4" "$W2"
check "and clear of the window on the right" eventually left_of "$W2" "$W3"
settled

arbor_stop
