#!/bin/bash
# Resizing: the seams between docked windows, a docked window's own edges and corners, and the resize command.
# T05 resize at the seams, A09 resize by command, A11 resize docked windows by their own edges.
source "$(dirname "$0")/../lib.sh"
arbor_build
arbor_start 3
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W1" bottom
summary

claim "drag the seam beside a column to the right: the whole column grows and the Desktop gives way"
proves T05
width=$(width_of "$W1")
other=$(width_of "$W2")
read -r x y <<< "$(seam_right_of "$W1")"
drag "$x" "$y" "$((x + 80))" "$y"
check "the window beside the seam is 80 points wider" eventually width_is "$W1" "$((width + 80))" 6
check "so is the one below it" eventually same_column "$W1" "$W3"
check "the window beyond the Desktop kept its width" eventually width_is "$W2" "$other"
check "it still reaches the right edge" eventually at_edge "$W2" right
check "nothing overlaps" eventually no_overlaps
settled

claim "drag the seam between two stacked windows down: the upper grows and the lower shrinks"
proves T05
upper=$(height_of "$W1")
lower=$(height_of "$W3")
read -r x y <<< "$(seam_below "$W1")"
drag "$x" "$y" "$x" "$((y + 60))"
check "the upper window is 60 points taller" eventually height_is "$W1" "$((upper + 60))" 6
check "the lower one 60 points shorter" eventually height_is "$W3" "$((lower - 60))" 6
check "the lower one still reaches the bottom edge" eventually at_edge "$W3" bottom
settled

claim "drag a seam back to the left: it follows the pointer both ways"
proves T05
width=$(width_of "$W1")
read -r x y <<< "$(seam_right_of "$W1")"
drag "$x" "$y" "$((x - 80))" "$y"
check "the window beside the seam is 80 points narrower" eventually width_is "$W1" "$((width - 80))" 6
settled

claim "drag a docked window's inner edge: on release its neighbour gives up the space"
proves A11 A73
take "x y w h" real_frame_of "$W2"
drag "$((x + 1))" "$((y + h / 2))" "$((x - 39))" "$((y + h / 2))"
check "the window is 40 points wider" eventually width_is "$W2" "$((w + 40))" 8
check "it still reaches the right edge" eventually at_edge "$W2" right
check "it is in its slot: the layout followed the window" eventually in_slot "$W2"
check "the Desktop is still between the columns" eventually desktop_between "$W1" "$W2"
settled

claim "drag a docked window's outer edge, against the screen: it springs back on release"
proves A11
take "x y w h" real_frame_of "$W2"
drag "$((x + w - 1))" "$((y + h / 2))" "$((x + w - 71))" "$((y + h / 2))" --no-release
check "the window follows the pointer while the button is held" eventually narrower_than "$W2" "$((w - 40))"
release
check "it has its width back" eventually width_is "$W2" "$w"
check "it reaches the right edge again" eventually at_edge "$W2" right
settled

claim "drag a docked window's corner: both seams move"
proves A11
take "x y w h" real_frame_of "$W1"
drag "$((x + w - 2))" "$((y + h - 2))" "$((x + w + 38))" "$((y + h - 32))"
check "the window is 40 points wider" eventually width_is "$W1" "$((w + 40))" 8
check "and 30 points shorter" eventually height_is "$W1" "$((h - 30))" 8
check "the window below took the height and the width" eventually same_column "$W1" "$W3"
check "and reaches the bottom edge" eventually at_edge "$W3" bottom
check "nothing overlaps" eventually no_overlaps
settled

claim "move a docked window without the mouse: Arbor puts it back"
proves A11
take "x y w h" real_frame_of "$W3"
tw move "$W3" "$((x + 120))" "$((y - 90))" "$w" "$h"
check "it is back in its slot" eventually in_slot "$W3"
settled

claim "resize a docked window by command"
proves A09
width=$(width_of "$W1")
check "the command succeeds" ctl resize "$W1" right -40
check "the window is 40 points narrower" eventually width_is "$W1" "$((width - 40))"
check "an edge with nothing beside it is refused" fails ctl resize "$W1" left 40
settled

arbor_stop
