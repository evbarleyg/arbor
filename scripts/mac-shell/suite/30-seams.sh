#!/bin/bash
# Resizing: the seams between docked windows, a docked window's own edges and corners, the resize command, and whose a press is where
# a floating window lies across a gap, in front of the windows beside it or behind them.
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
# astride <id> y: the same for a gap that runs from left to right: all of the gap's height at y is the window's.
astride() {
  local fx fy fw fh
  take "fx fy fw fh" resting_frame_of "$1"
  [ "$fy" -le "$(($2 - ARBOR_GAP / 2))" ] && [ "$((fy + fh))" -ge "$(($2 + ARBOR_GAP / 2))" ] \
    || { echo "the window is at $fx $fy $fw $fh, the gap at y $2"; return 1; }
}
# behind <id> <other>…: the window server, whose list goes from front to back, has it after each of the others.
behind() {
  local id=$1 other order
  shift
  order=" $("$ARBOR_POINTER" windows --on-screen | cut -d " " -f 1 | tr "\n" " ")"
  for other in "$@"; do
    # What comes after the other, with the blank that parted them: the two may be neighbours in the list.
    case "$order" in *" $other "*) ;; *) echo "$other is not on screen; front to back:$order"; return 1 ;; esac
    case " ${order#*" $other "}" in *" $id "*) ;; *) echo "$id is not behind $other; front to back:$order"; return 1 ;; esac
  done
}
# The gap's handle at a point: the panel of Arbor's there that is as thin as a gap. The focus ring's reaches into the gap as well, and is not.
IS_THE_HANDLE='$2 == arbor && $3 == 0 && x >= $4 && x < $4 + $6 && y >= $5 && y < $5 + $7 && ($6 <= gap + 1 || $7 <= gap + 1)'
# under_both x y: it lies under both windows beside the gap: it has not stayed in front of them, where it would take the clicks of whatever lies
# across the gap in front of them.
under_both() {
  "$ARBOR_POINTER" windows --on-screen | awk -v a="$W1" -v b="$W3" -v arbor="$ARBOR_PID" -v x="$1" -v y="$2" -v gap="$ARBOR_GAP" '
    $1 == a || $1 == b { seen++ }
    '"$IS_THE_HANDLE"' { found = 1; exit }
    END {
      if (!found) print "there is no handle at", x, y
      else if (seen != 2) print "of the two windows", seen + 0, "lie in front of the handle"
      exit !(found && seen == 2)
    }'
}
# handle_over <id> x y: it lies in front of the window, and gets the press there.
handle_over() {
  "$ARBOR_POINTER" windows --on-screen | awk -v id="$1" -v arbor="$ARBOR_PID" -v x="$2" -v y="$3" -v gap="$ARBOR_GAP" '
    $1 == id { exit }
    '"$IS_THE_HANDLE"' { found = 1; exit }
    END { if (!found) print "the window comes before any handle at", x, y; exit !found }'
}
# What lies on what at the windows' own level, front first, for whoever reads this afterwards: only a Mac knows.
stacking() {
  echo "  front to back, $*:"
  "$ARBOR_POINTER" windows --on-screen | awk -v arbor="$ARBOR_PID" '$3 == 0 { print "    " ($2 == arbor ? "Arbor " : "      ") $1, "at", $4, $5, $6, $7 }'
}
# Points of the two docked windows that the floating one, which lies across the gap between them, does not reach: near the top of the upper
# one and near the bottom of the lower one.
clear_of_it() {
  if [ "$1" = "$W1" ]; then arbor_point_on "$1" "x + w - 20" "y + 60"; else arbor_point_on "$1" "x + w - 20" "y + h - 20"; fi
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

# Behind both windows beside a gap, all that shows of it is what shows through the gap, and nobody who presses there means it: it would come
# forward over both, and no gap would move. The gap between two docked windows is the arrangement's.
claim "a floating window lies behind both windows beside a gap: a press in the gap moves the gap, and the window stays behind"
take "x y" desktop_point
open_window F2 size=300x200 "at=$((x - 150)),$((y - 100))" title=Behind the gap
take "x y" seam_below "$W1"
drag_window "$F2" "$x" "$y"
check "the window floats" eventually is floating "$F2"
take "fx fy fw fh" resting_frame_of "$F2"
x=$((fx + fw / 2))
check "it lies across the gap" astride "$F2" "$y"
check "in front of the gap's handle, as long as it is in front of the windows" eventually in_front_at "$F2" "$x" "$y"
# By clicks, as a person brings a window forward. Of a window that its app brings forward by itself macOS tells nobody.
# shellcheck disable=SC2046
click $(clear_of_it "$W1")
# shellcheck disable=SC2046
click $(clear_of_it "$W3")
check "the two windows have come forward over it" eventually behind "$F2" "$W1" "$W3"
check "and the gap's handle with them" eventually handle_over "$F2" "$x" "$y"
check "under the two, not over them" under_both "$x" "$y"
stacking "the handle never pressed"
upper=$(height_of "$W1")
lower=$(height_of "$W3")
downs=$(events_of "$F2" down)
drag "$x" "$y" "$x" "$((y + 40))"
check "the upper window is 40 points taller" eventually height_is "$W1" "$((upper + 40))" 6
check "the lower one 40 points shorter" eventually height_is "$W3" "$((lower - 40))" 6
check "the floating window got no press" stays received "$F2" down -eq "$downs"
check "it has stayed where it was" frame_is "$F2" "$fx" "$fy" "$fw" "$fh"
check "and behind both" behind "$F2" "$W1" "$W3"
settled

# A press brings forward what it lands on, a panel that takes no keyboard too.
claim "a handle that was pressed goes back to its place: under the two windows, over what is behind them"
take "_ y" seam_below "$W1"
stacking "after the drag"
check "after the drag it is under the two" eventually under_both "$x" "$y"
check "and over the floating window" handle_over "$F2" "$x" "$y"
upper=$(height_of "$W1")
click "$x" "$y"
stacking "after a click on the handle"
check "after a click that drags nothing too" eventually under_both "$x" "$y"
check "and over the floating window" handle_over "$F2" "$x" "$y"
check "the floating window got no press" received "$F2" down -eq "$downs"
check "no docked window was resized" stays height_is "$W1" "$upper"

claim "brought forward, it has its presses back; and loses them again when the two come forward over it"
tw front "$F2"
check "it is in front of the gap's handle" eventually in_front_at "$F2" "$x" "$y"
upper=$(height_of "$W1")
click "$x" "$y"
check "it got the press" eventually received "$F2" down -gt "$downs"
check "no docked window was resized" stays height_is "$W1" "$upper"
# The other way round this time: whichever of the two is further back, the handle lies below that one.
# shellcheck disable=SC2046
click $(clear_of_it "$W3")
# shellcheck disable=SC2046
click $(clear_of_it "$W1")
check "the two windows have come forward over it" eventually behind "$F2" "$W1" "$W3"
check "and the gap's handle with them" eventually handle_over "$F2" "$x" "$y"
check "under the two, not over them" under_both "$x" "$y"
stacking "at the end"
settled
tw close "$F2"
forget_window "$F2"

arbor_stop
