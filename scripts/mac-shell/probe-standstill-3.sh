#!/bin/bash
# Who holds the display? Part 3: the other scene in which it always stood still: back out of a window that is a tile in the view one returns to.
# Here the keyboard changes hands: the window that had it leaves the view, and another app's window, just back, gets it (part 1 has the story).
#
# THE QUESTION ONLY A MAC CAN ANSWER: is it the handing over of the keyboard (AXMain, AXRaise, activate) while the stage is up, and which part of it;
# and does a plain tool that does the same to the same windows get the same?
ARBOR_TIME_LIMIT=1150
source "$(dirname "$0")/lib-standstill.sh"
needs_throwaway_mac "film the whole display, change Accessibility settings and the test apps' defaults, and sample every process as root"

still_build
still_begin
pulse_start

# in_and_out <name> <n>: a click on the tile, a film; ⌃⌥[, a film
in_and_out() {
  local name=$1 times=${2:-3} i=1
  while [ "$i" -le "$times" ]; do
    # shellcheck disable=SC2046
    filmed "$name-$i-open" "clicks the tile" click $(tile_of "$W3")
    filmed "$name-$i-back" "presses ⌃⌥[" key ctrl+opt+[
    i=$((i + 1))
  done
}

# Two windows docked side by side and a third that cannot be as narrow as its slot: a tile.
tile_session() {
  ARBOR_TEST_WINDOWS_ARGS="--regular --min-size 3:700x500"
  cast_start 3 $STILL_FACE "$@"
  sleep 3
  ctl dock "$W1" left
  ctl dock "$W2" right
  sleep 1.5
  still_press "$W3"
  key ctrl+opt+cmd+right
  sleep 2
  summary
  check "the third window is a tile" is tile "$W3"
}

step "1. as it was found"
tile_session
in_and_out tile 3

step "1b. who waits for whom"
# shellcheck disable=SC2046
click $(tile_of "$W3")
sleep 3
watched watched-spindump-tile-back key ctrl+opt+[
# shellcheck disable=SC2046
click $(tile_of "$W3")
sleep 3
STILL_WATCH=sample watched watched-sample-tile-back key ctrl+opt+[

# Where things are in the two views, for the control.
read -r AX1 AY1 _ _ <<< "$(frame_of "$W1")"
read -r AX2 AY2 _ _ <<< "$(frame_of "$W2")"
# shellcheck disable=SC2046
click $(tile_of "$W3")
sleep 2
read -r BX3 BY3 _ _ <<< "$(frame_of "$W3")"
read -r dx dy dw dh <<< "$(display_frame_of 1)"
PX=$((dx + dw - 1))
PY=$((dy + dh - 1))

step "2. THE CONTROL: no Arbor; the view as it is with the large window open"
trace_ends
# Killed, not asked to quit: a quit gives every window its earlier size back, and the control wants them as they are.
arbor_kill
sleep 1
shot control-open
# control <name> <n> "<before the moves>" "<after the moves back>"
control() {
  local name=$1 times=$2 before=$3 after=$4 i=1
  while [ "$i" -le "$times" ]; do
    # shellcheck disable=SC2086
    filmed "$name-$i-back" "a tool brings two windows back and sends the third away" \
      mover wait:700 go $before "move:$W1:${AX1:-12}:${AY1:-43}" "move:$W2:${AX2:-518}:${AY2:-43}" "move:$W3:$PX:$PY" $after
    # shellcheck disable=SC2086
    filmed "$name-$i-open" "a tool does the opposite" \
      mover wait:700 go $before "move:$W3:${BX3:-12}:${BY3:-43}" "move:$W1:$PX:$PY" "move:$W2:$PX:$PY" "focus:$W3"
    i=$((i + 1))
  done
}
control moves 2 "" ""
control moves-keyboard 3 "" "focus:$W2"
control cover-moves 2 cover:0.46 ""
control cover-keyboard 3 cover:0.46 "focus:$W2"
step "2b. the parts of handing the keyboard over, under the cover"
control cover-main 2 cover:0.46 "main:$W2"
control cover-raise 2 cover:0.46 "main:$W2 raise:$W2"
control cover-activate 2 cover:0.46 "activate:$W2"
step "2c. the keyboard first, then the cover and the moves"
control keyboard-first 2 "focus:$W2 cover:0.46" ""
arbor_relaunch
cast_stop

step "3. Arbor, which asks for AXMain and AXRaise and leaves the app where it is"
tile_session ARBOR_PROBE=no-activate
in_and_out no-activate 3
cast_stop

step "4. Arbor, which leaves the keyboard where it is"
tile_session ARBOR_PROBE=no-focus
in_and_out no-focus 3
cast_stop

step "5. no stage"
tile_session
ctl set animationDuration 0
in_and_out tile-no-stage 3
cast_stop

step "6. all three windows one app's"
STILL_CAST=$FILM_CAST
FILM_CAST=""
tile_session
in_and_out tile-one-app 3
cast_stop
FILM_CAST=$STILL_CAST

still_end
system_log_of_the_worst 6
