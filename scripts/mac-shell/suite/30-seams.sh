#!/bin/bash
# Resizing: the seams between docked windows, a docked window's own edges and corners, the resize command, and whose a press is where
# a floating window lies across a gap.
# T05 resize at the seams, A09 resize by command, A11 resize docked windows by their own edges.
source "$(dirname "$0")/../lib.sh"
arbor_build

# in_front_at <id> x y: of all that lies at that point, the window is the first to get a press: no panel of Arbor's at the windows'
# own level comes before it in the window server's list, which goes from front to back. The focus ring's panel is passed
# over: it holds the whole window, is meant to lie in front of it, and lets presses through.
in_front_at() {
  local frame
  frame=$(resting_frame_of "$1") || { echo "the window server has no such window"; return 1; }
  "$ARBOR_POINTER" windows --on-screen | awk -v id="$1" -v arbor="$ARBOR_PID" -v x="$2" -v y="$3" -v frame="$frame" '
    BEGIN { split(frame, f, " ") }
    $1 == id { found = 1; exit }
    $2 != arbor || $3 != 0 || x < $4 || x >= $4 + $6 || y < $5 || y >= $5 + $7 { next }
    $4 <= f[1] && $5 <= f[2] && $4 + $6 >= f[1] + f[3] && $5 + $7 >= f[2] + f[4] { next }
    { print "a panel of Arbor\047s lies in front of it, at", $4, $5, $6, $7; exit }
    END { exit !found }'
}
# across <id> x: the window reaches at least a gap's width beyond x on either side.
across() {
  local fx fy fw fh
  take "fx fy fw fh" resting_frame_of "$1"
  [ "$fx" -lt "$(($2 - ARBOR_GAP))" ] && [ "$((fx + fw))" -gt "$(($2 + ARBOR_GAP))" ] \
    || { echo "the window is at $fx $fy $fw $fh, the gap at x $2"; return 1; }
}

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
take "x y w h" resting_frame_of "$W2"
drag "$((x + 1))" "$((y + h / 2))" "$((x - 39))" "$((y + h / 2))"
check "the window is 40 points wider" eventually width_is "$W2" "$((w + 40))" 8
check "it still reaches the right edge" eventually at_edge "$W2" right
check "it is in its slot: the layout followed the window" eventually in_slot "$W2"
check "the Desktop is still between the columns" eventually desktop_between "$W1" "$W2"
settled

claim "drag a docked window's lower edge toward the window below: nothing else moves until the button is let go"
proves A11
take "x y w h" resting_frame_of "$W1"
below=$(resting_frame_of "$W3")
beside=$(resting_frame_of "$W2")
lower=$(height_of "$W3")
drag "$((x + w / 2))" "$((y + h - 1))" "$((x + w / 2))" "$((y + h + 39))" --no-release
# How much of the 40 points arrives is macOS's business (see the corner, below): what the window has while it is held is what counts.
held_h=$(height_of "$W1")
echo "held: the window is at $(real_frame_of "$W1"), the pointer at $(pointer where)"
check "the window grew under the pointer" taller_than "$W1" "$((h + 5))"
# shellcheck disable=SC2086
check "the window below has not moved" stays frame_is "$W3" ${below:-0 0 0 0}
# shellcheck disable=SC2086
check "nor the one beyond the Desktop" frame_is "$W2" ${beside:-0 0 0 0}
check "the window still has what it was given" height_is "$W1" "$held_h"
release
check "released, it keeps the height it was given" eventually height_is "$W1" "$held_h" 4
check "the window below gives up that much" eventually height_is "$W3" "$((lower - held_h + h))" 4
check "and still reaches the bottom edge" eventually at_edge "$W3" bottom
check "it is in its slot: the layout followed the window" eventually in_slot "$W1"
check "nothing overlaps" eventually no_overlaps
settled

claim "drag a docked window's outer edge, against the screen: it springs back on release"
proves A11
take "x y w h" resting_frame_of "$W2"
drag "$((x + w - 1))" "$((y + h / 2))" "$((x + w - 71))" "$((y + h / 2))" --no-release
check "the window follows the pointer while the button is held" eventually narrower_than "$W2" "$((w - 40))"
release
check "it has its width back" eventually width_is "$W2" "$w"
check "it reaches the right edge again" eventually at_edge "$W2" right
settled

claim "drag a docked window's corner: both seams move"
proves A11
take "x y w h" resting_frame_of "$W1"
drag "$((x + w - 2))" "$((y + h - 2))" "$((x + w + 38))" "$((y + h - 32))" --no-release
# macOS holds back an edge that is flush with a neighbour's, as this one is with the window's below, and does not give the points
# back: on a hosted Mac 9 of 40 arrived. What Arbor promises is that the seams go where the window's edges are when it is let go.
held_w=$(width_of "$W1")
held_h=$(height_of "$W1")
echo "held: the window is at $(real_frame_of "$W1"), the pointer at $(pointer where)"
check "the window grew wider under the pointer" wider_than "$W1" "$((w + 5))"
check "and shorter" shorter_than "$W1" "$((h - 5))"
release
check "released, it keeps the width it was given" eventually width_is "$W1" "$held_w" 4
check "and the height" eventually height_is "$W1" "$held_h" 4
check "it is in its slot: the layout followed the window" eventually in_slot "$W1"
check "the window below took the height and the width" eventually same_column "$W1" "$W3"
check "and reaches the bottom edge" eventually at_edge "$W3" bottom
check "nothing overlaps" eventually no_overlaps
settled

claim "move a docked window without the mouse: Arbor puts it back"
proves A11
take "x y w h" resting_frame_of "$W3"
# Longer than the second within which a docked window's new frame is taken for its person's asking macOS, and let be (Controller+AskedOfMacOS.swift):
# the claim before this one ends with the pointer's release. On a Mac the move came 0.79 s after it, and the window was rightly left as it was.
sleep 1.5
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

# A gap's handle cannot be seen and takes presses: in front of a floating window it would take a strip of that window's.
claim "drag a floating window across a gap and resize under it by command: it stays in front, and a press where the gap runs is the window's"
take "x y" desktop_point
open_window F1 size=300x200 "at=$((x - 150)),$((y - 100))" title=Across the gap
take "x y" seam_right_of "$W1"
# By hand: where a person puts a window it stays, and one that merely opened there is moved onto the Desktop by the next layout.
drag_window "$F1" "$x" "$y"
check "the window floats" eventually is floating "$F1"
# It trails the pointer, so where it lies is measured. The press goes where the gap runs, halfway down the window.
take "fx fy fw fh" resting_frame_of "$F1"
y=$((fy + fh / 2))
check "it lies across the gap" across "$F1" "$x"
# There and back: the gap is where it was, and its handle has been shown anew twice.
check "the first resize succeeds" ctl resize "$W1" right -20
check "and the one that takes it back" ctl resize "$W1" right 20
check "the floating window has stayed where it was put" stays frame_is "$F1" "$fx" "$fy" "$fw" "$fh"
check "the gap runs under it as before" about "$(seam_right_of "$W1" | cut -d " " -f 1)" "$x" 2
check "it is in front of the gap's handle" in_front_at "$F1" "$x" "$y"
width=$(width_of "$W1")
downs=$(events_of "$F1" down)
dragged=$(events_of "$F1" dragged)
drag "$x" "$y" "$((x + 50))" "$y"
check "the floating window got the press" eventually received "$F1" down -gt "$downs"
check "and the drag that followed" eventually received "$F1" dragged -gt "$dragged"
check "no docked window was resized" stays width_is "$W1" "$width"
settled
tw close "$F1"
forget_window "$F1"

arbor_stop
