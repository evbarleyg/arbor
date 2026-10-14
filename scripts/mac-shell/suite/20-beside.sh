#!/bin/bash
# Docking beside a window by dropping on each of its edge zones, and nesting spaces by doing it again and again.
# T02 dock beside another window, T04 unlimited nesting.
source "$(dirname "$0")/../lib.sh"
arbor_build
# Docking beside a window halves its slot, and on a 1024-point screen the halves of halves are tiles by default. This
# section is about where windows land, so slots may be small.
arbor_settings '{"minimumUsableWidth": 200, "minimumUsableHeight": 120}'
arbor_start 5
ctl dock "$W1" left

claim "drop a window on the bottom part of a docked window: it docks below it, in a space of their own"
proves T02
# shellcheck disable=SC2046
drag_window "$W5" $(zone_of "$W1" bottom) --no-release
check "the preview shows while the button is held" eventually has_overlay 3
preview=$(overlay_frame 3)
release
check "the window is docked" eventually is docked "$W5"
check "it is below the other" eventually above "$W1" "$W5"
check "in the same column" eventually same_column "$W1" "$W5"
check "the two are nested one level deeper than the Desktop beside them" depth_is "$W5" 2
# shellcheck disable=SC2086
check "it landed exactly where the preview was" eventually frame_is "$W5" ${preview:-0 0 0 0}
settled

claim "drop a window on the right part of a docked window: it docks on its right"
proves T02 T11
column=$(width_of "$W5")
# shellcheck disable=SC2046
drag_window "$W4" $(zone_of "$W1" right)
check "the window is docked" eventually is docked "$W4"
check "it is to the right of the other" eventually left_of "$W1" "$W4"
check "in the same row" eventually same_row "$W1" "$W4"
check "both are above the window below" eventually above "$W4" "$W5"
check "which kept the whole width" eventually width_is "$W5" "$column"
settled

claim "drop a window on the left part of a docked window: it docks on its left"
proves T02
# shellcheck disable=SC2046
drag_window "$W3" $(zone_of "$W5" left)
check "the window is docked" eventually is docked "$W3"
check "it is to the left of the other" eventually left_of "$W3" "$W5"
check "in the same row" eventually same_row "$W3" "$W5"
check "it took over the left edge of the screen" eventually at_edge "$W3" left
settled

claim "drop a window on the top part of a docked window: it docks above it"
proves T02
# shellcheck disable=SC2046
drag_window "$W2" $(zone_of "$W4" top)
check "the window is docked" eventually is docked "$W2"
check "it is above the other" eventually above "$W2" "$W4"
check "in the same column" eventually same_column "$W2" "$W4"
check "it took over the top edge of the screen" eventually at_edge "$W2" top
check "nothing overlaps" eventually no_overlaps
check "all five are docked" count docked 5
check "none of them became a tile" count tiles 0
settled

claim "drop a window on the middle of a docked window: it floats there"
ctl float "$W2"
# One in the upper row: the window has its own size back, and dropped further down it would hang off the screen.
# shellcheck disable=SC2046
drag_window "$W2" $(center_of "$W4")
check "the window floats" eventually is floating "$W2"
check "four are docked" count docked 4
arbor_stop

# Small slots are tiles by default; this session is about depth, so they are allowed to be small.
arbor_settings '{"minimumUsableWidth": 120, "minimumUsableHeight": 90}'
arbor_start 4

claim "nest spaces four levels deep by dragging alone"
proves T04
# shellcheck disable=SC2046
drag_window "$W4" $(edge_point left)
check "level 1: a column at the left edge" eventually depth_is "$W4" 1
# shellcheck disable=SC2046
drag_window "$W3" $(zone_of "$W4" bottom)
check "level 2: a window below it" eventually depth_is "$W3" 2
# shellcheck disable=SC2046
drag_window "$W2" $(zone_of "$W3" right)
check "level 3: a window beside that one" eventually depth_is "$W2" 3
# shellcheck disable=SC2046
drag_window "$W1" $(zone_of "$W2" bottom)
check "level 4: a window below that one" eventually depth_is "$W1" 4
check "the first is above the second" eventually above "$W4" "$W3"
check "the second is left of the third" eventually left_of "$W3" "$W2"
check "the third is above the fourth" eventually above "$W2" "$W1"
check "the third and the fourth share a column" eventually same_column "$W2" "$W1"
check "nothing overlaps" eventually no_overlaps
check "none of them became a tile" count tiles 0
settled

claim "step out of the innermost space level by level"
proves T04
ctl zoom "$W1"
check "the innermost window fills the screen" eventually fills "$W1"
ctl out
check "one level out: it shares the screen with the one above it" eventually above "$W2" "$W1"
check "the others are out of view" eventually out_of_view "$W3"
ctl out
check "two levels out: the one beside them is back" eventually left_of "$W3" "$W2"
check "the top one is still out of view" eventually out_of_view "$W4"
ctl out
check "three levels out: the whole column" eventually above "$W4" "$W3"
ctl out
check "four levels out: everything" eventually camera_on root
check "there is nothing further out" fails ctl out
settled

arbor_stop
