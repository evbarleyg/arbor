#!/bin/bash
# Docking by dragging a window to each edge of the screen, the preview on the way, and dragging it off again.
# T01 dock at a screen edge, T03 the Desktop stays, T06 a leaving window's space, T11 the drop preview.
source "$(dirname "$0")/../lib.sh"
arbor_build
arbor_start 4

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

claim "floating windows make way for a docked one: none is left behind it"
check "the first floating window is beside the docked one" eventually left_of "$W4" "$W1"
check "the second" eventually left_of "$W4" "$W2"
check "the third" eventually left_of "$W4" "$W3"

claim "drag a window to the right screen edge: it docks there and the Desktop stays between the two"
proves T01 T03
# shellcheck disable=SC2046
drag_window "$W3" $(edge_point right)
check "the window is docked" eventually is docked "$W3"
check "it reaches the right edge of the screen" eventually at_edge "$W3" right
check "the Desktop stays between them" eventually desktop_between "$W4" "$W3"
check "the floating windows are on the Desktop's part of the screen" eventually left_of "$W4" "$W2"
check "and clear of the window on the right" eventually left_of "$W2" "$W3"
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
