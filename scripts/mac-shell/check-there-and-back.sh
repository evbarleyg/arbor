#!/bin/bash
# There and back in one breath, between two framed neighbours of different apps: who has the keyboard in the end, and how often did the view move?
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-there-and-back.sh
#
# macOS alone, measured (probe-taken-back.sh): an activation lands 0 to 40 ms after it was asked for, and until then the old app is named as the one in front. A request for
# a window of that app made meanwhile activates nobody, and the first activation lands all the same: the request that was taken back comes true, 6 of 6.
# Does that happen with Arbor? Its second command lays out before it looks who has the keyboard, which takes time. Three ways there and back, ten rounds each, the second
# command sent as soon as the first is answered (`arborctl a , b`). W1 is one app's window, V1 another's.
#
# On somebody's own Mac it touches only its test windows and the keyboard focus.
ARBOR_RECORD=1
source "$(dirname "$0")/lib.sh"

arbor_build
ARBOR_TEST_WINDOWS_ARGS="--regular"
ARBOR_SECOND_APP=1
ARBOR_SECOND_APP_ARGS="--regular"
arbor_start 1
ctl dock "$W1" left
ctl dock "$V1" right
tw activate "$W1"
ctl zoom "$W1"
check "W1 is framed, V1 is out of view" eventually is parked "$V1"


there_and_back() {
  local name=$1 round
  shift
  step "$name"
  for round in 1 2 3 4 5 6 7 8 9 10; do
    eventually is focused "$W1" > /dev/null 2>&1 || { tw activate "$W1"; ctl zoom "$W1" > /dev/null; sleep 1; }
    echo "> arborctl $*"
    "$ARBOR_BIN/arborctl" "$@" > /dev/null
    sleep 1.5
    check "$name, round $round: W1 has the keyboard" is focused "$W1"
    check "$name, round $round: its app is in front" front_is "$ARBOR_WINDOWS_PID"
    check "$name, round $round: the view is on W1" camera_on "$W1"
  done
}

there_and_back "the view goes to the neighbour and back" neighbor right , neighbor left
there_and_back "the keyboard goes right and left" focus right , focus left
there_and_back "V1 is framed by its number, then W1" zoom "$V1" , zoom "$W1"

arbor_stop
