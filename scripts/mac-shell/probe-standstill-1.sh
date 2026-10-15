#!/bin/bash
# Who holds the display? Part 1: the instruments on something known, the fault as it was found, and THE CONTROL: the same windows moved the same way with
# no Arbor anywhere.
#
#   scripts/mac-shell/rehearse.sh scripts/mac-shell/probe-standstill-1.sh
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-standstill-1.sh scripts/mac-shell/probe-standstill-2.sh …
#   scripts/mac-shell/standstill.py table .mac-shell/<run>/1-probe-standstill-1
#
# Found in films of a hosted Mac: where the view comes back from the Desktop (⌃⌥D, then ⌃⌥[) the motion starts and the display then shows one
# picture for 0.4 to 1 s. THE QUESTION ONLY A MAC CAN ANSWER: does the display also stand still when a plain tool moves the same four windows back the
# same way (then it is macOS's doing, or the virtual machine's), and if not, with which of the things Arbor does besides does it begin?
#
# One cast, one Mac, one after the other: with Arbor; Arbor quits; the control and what is added to it, a step at a time; Arbor again.
ARBOR_TIME_LIMIT=1150
source "$(dirname "$0")/lib-standstill.sh"

still_build
still_begin
pulse_start

cast_start 4 $STILL_FACE
sleep 3
still_arrange
still_press "$W3"
summary
# Where Arbor has them, for the control to put them.
for n in 1 2 3 4; do
  eval "id=\$W$n"
  read -r x y w h <<< "$(frame_of "$id")"
  eval "X$n=${x:-0} Y$n=${y:-0} WIDE$n=${w:-300} HIGH$n=${h:-300}"
done
read -r dx dy dw dh <<< "$(display_frame_of 1)"
# Where Arbor asks a window to go that leaves the view: one point inside the bottom right corner. macOS stops it higher up.
PX=$((dx + dw - 1))
PY=$((dy + dh - 1))

step "0. the instruments: nothing is done; then holds that are known to be holds"
filmed rest-1 "nothing is done" sleep 0.5
filmed hold-1-300 "a tool holds screen updates for 0.3 s" mover wait:700 go hold:300
filmed hold-1-700 "a tool holds screen updates for 0.7 s" mover wait:700 go hold:700
filmed hold-1-1600 "a tool holds screen updates for 1.6 s" mover wait:700 go hold:1600

step "1. with Arbor, as it was found"
away_and_back arbor 3

step "1b. the same without the strip: whether looking changes it"
pulse_stop
away_and_back bare 2
pulse_start

step "2. THE CONTROL: no Arbor"
trace_ends
arbor_quit
sleep 1
for n in 1 2 3 4; do
  eval "tell $n \"move \$W$n \$X$n \$Y$n \$WIDE$n \$HIGH$n\""
done
sleep 1
click $((X3 + WIDE3 / 2)) $((Y3 + 12))
sleep 0.6
shot control-arranged

AWAY="move:$W1:$PX:$PY move:$W2:$PX:$PY move:$W3:$PX:$PY move:$W4:$PX:$PY"
BACK="move:$W1:$X1:$Y1 move:$W2:$X2:$Y2 move:$W3:$X3:$Y3 move:$W4:$X4:$Y4"
# control <name> <n> "<steps before the moves>" "<steps after the moves back>"
control() {
  local name=$1 times=$2 before=$3 after=$4 i=1
  while [ "$i" -le "$times" ]; do
    # shellcheck disable=SC2086
    filmed "$name-$i-away" "a tool sends the four windows to the corner" mover wait:700 go $before $AWAY
    # shellcheck disable=SC2086
    filmed "$name-$i-back" "a tool brings the four windows back" mover wait:700 go $before $BACK $after
    i=$((i + 1))
  done
}
control control 3 "" ""

step "3. the control under a cover like Arbor's stage"
control cover 3 cover:0.46 ""

step "4. and with panels ordered in meanwhile, as Arbor's tile of the Desktop and its focus ring are"
control panels 3 cover:0.46 "panel:$((X4 + WIDE4 + 12)):$Y4:$((X3 - X4 - WIDE4 - 24)):$((Y2 + HIGH2 - Y4)) ring:$W3"

step "5. the control, and the keyboard goes to another app's window (AXMain, AXRaise, activate)"
control keyboard 2 "" "focus:$W4"
click $((X3 + WIDE3 / 2)) $((Y3 + 12))
sleep 0.6
control cover-keyboard 2 cover:0.46 "focus:$W4"
click $((X3 + WIDE3 / 2)) $((Y3 + 12))
sleep 0.6

step "6. the control from 40 points in view instead of 1"
PX=$((dx + dw - 40))
AWAY="move:$W1:$PX:$PY move:$W2:$PX:$PY move:$W3:$PX:$PY move:$W4:$PX:$PY"
control forty 2 cover:0.46 ""

step "7. Arbor again, on the same windows"
arbor_relaunch
trace_begins
sleep 2
still_arrange
still_press "$W3"
away_and_back again 2

step "8. who waits for whom"
key ctrl+opt+d
sleep 3
watched watched-spindump-back key ctrl+opt+[
key ctrl+opt+d
sleep 3
STILL_WATCH=sample watched watched-sample-back key ctrl+opt+[
# macOS's own pictures, which come another way than the film, beside it.
key ctrl+opt+d
sleep 3
scene witnessed-back camera "presses ⌃⌥[, with macOS's own pictures taken beside the film"
key ctrl+opt+[ &
film witness 9
scene_end 0.5

cast_stop
still_end
system_log_of_the_worst 6
