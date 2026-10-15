#!/bin/bash
# One jump of a window under a press below its top is no hand; a window that goes on with the pointer is in one.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-one-jump.sh
#
# Whatever Arbor takes for a drag of a docked window takes the window out of the arrangement. A hand takes a window along by its top. Below that it
# selects text, and a window that moves under it has most likely moved by itself: a stubborn one goes back to where it was before Arbor moved
# it, in one jump, a quarter of a second after. On the model of a Mac that was taken for a drag, and cost a tile. But some windows can be taken
# along by their background, and those must go on being dragged.
#
#   - the button goes down in the middle of a stubborn tile and the pointer sets out; Arbor sends the tile 80 points; it goes back while the pointer
#     goes on, each way: no drag, both stay tiles. That the tile did move under the button is checked, or the claim would ask nothing;
#   - the control: the same tile taken by its title bar is dragged;
#   - a window that is taken along by its background: a drag, seen while the hand is still on its way.
source "$(dirname "$0")/lib.sh"

seen_as_a_drag() { logged "$1 is being dragged"; }
not_seen_as_a_drag() { ! logged "$1 is being dragged" > /dev/null 2>&1; }
no_preview() { ! has_overlay 3; }
said_of_the_press() { arbor_log_since "$ARBOR_STEP_MARK" | grep "the button went down at" | tail -1 | sed 's/^.*DEBUG /    (/; s/$/)/' || true; }

moved_under_the_button() { logged "$1 has moved under a press below its top" || logged "$1 was moved or resized while the button was down"; }

arbor_build
arbor_start 3
# Side by side, with no Desktop between: what the first gains the second gives.
ctl dock "$W1" left
ctl dock "$W2" beside "$W1" right
sleep 1
# Room enough that 80 points less do not make a tile of it: Arbor would send it out of view, 755 points away, and that is another story. (So it
# went on a hosted Mac, 1024 points wide, with a column for the Desktop: 244 points each.)
take "x y w h" real_frame_of "$W2"
[ "$w" -ge 360 ] || ctl resize "$W2" right $((360 - w))
sleep 1
summary

for way in -120 120; do
  if [ "$way" -lt 0 ]; then words="the way it goes back"; else words="the way Arbor sent it"; fi
  claim "a stubborn tile goes back while the pointer goes 120 points in the middle of it, $words"
  take "x y w h" real_frame_of "$W2"
  tw insist "$W2" "$x" "$y" "$w" "$h"
  sleep 0.5
  take "cx cy" center_of "$W2"
  # The pointer tool takes half a second to get anywhere on a hosted Mac, and the window goes back a quarter of a second after it is moved. So
  # the button goes down first.
  drag "$cx" "$cy" "$((cx + way / 2))" "$((cy + 2))" --steps 6 --duration 0.3 --hold 0 --no-release
  ctl resize "$W1" right 80
  drag_on "$((cx + way))" "$((cy + 4))" --steps 12 --duration 0.8 --hold 0.5
  release
  said_of_the_press
  # Or the claim is about something else than it says.
  check "Arbor sent it 80 points, and not out of view" arbor_close "$(slot_of "$W2")" "$((x + 80)) $y $((w - 80)) $h"
  # The lines are the real Accessibility layer's, which a rehearsal has not got.
  [ -n "${ARBOR_REHEARSAL:-}" ] || check "the tile did move under the button" eventually moved_under_the_button "$W2"
  [ -n "${ARBOR_REHEARSAL:-}" ] || check "nothing is taken for a drag" not_seen_as_a_drag "$W2"
  check "no drop preview is left" eventually no_preview
  check "the stubborn one is a tile still" eventually is docked "$W2"
  check "and so is its neighbor" eventually is docked "$W1"
  tw relent "$W2"
  summary
  ctl resize "$W1" right -80
  sleep 1
done

claim "the control: the same tile taken by its title bar is dragged"
take "tx ty" titlebar_of "$W2"
drag "$tx" "$ty" "$((tx - 60))" "$((ty + 120))" --steps 24 --duration 0.7
said_of_the_press
[ -n "${ARBOR_REHEARSAL:-}" ] || check "Arbor sees a drag" eventually seen_as_a_drag "$W2"
summary

claim "a window that is taken along by its background is dragged"
tw by-background "$W3"
take "fx fy fw fh" real_frame_of "$W3"
click_window "$W3"
take "cx cy" center_of "$W3"
drag "$cx" "$cy" "$((cx + 90))" "$((cy + 60))" --steps 24 --duration 0.7 --no-release
[ -n "${ARBOR_REHEARSAL:-}" ] || check "Arbor sees a drag while the button is down" eventually seen_as_a_drag "$W3"
# In the hand: what becomes of it at the release is another rule's (it lies over the tiles, and whether a plain drag docks has changed).
check "the window went along" arbor_close "$(real_frame_of "$W3")" "$((fx + 90)) $((fy + 60)) $fw $fh"
release
said_of_the_press
summary
arbor_stop
