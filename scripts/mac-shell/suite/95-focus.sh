#!/bin/bash
# Giving the keyboard to a window that is out of view brings it into view: what ⌘Tab, the Dock, a notification
# or `open` do all day. A floating window is never out of view (F64): it only comes to the front. Part of T52 (windows outside the view).
source "$(dirname "$0")/../lib.sh"
arbor_build
ARBOR_SECOND_APP=1
# In the Dock and in ⌘Tab, like a person's apps, which only the claim about ⌘Tab needs. On a person's Mac they could stay among the
# Dock's recent apps.
if on_throwaway_mac; then
  ARBOR_TEST_WINDOWS_ARGS="--regular"
  ARBOR_SECOND_APP_ARGS="--regular"
fi
# The three docked windows as the window server lists them, which is from front to back.
order_of_docked() {
  "$ARBOR_POINTER" windows --on-screen | awk -v ids=" $W1 $W2 $V1 " 'index(ids, " " $1 " ") { printf "%s ", $1 }'
}
order_is() {
  local now
  now=$(order_of_docked)
  [ "$now" = "$1" ] || { echo "front to back they are $now, not $1"; return 1; }
}
# uncovered <id>: of the windows the window server has in front of it, none that belongs to the test apps overlaps it.
uncovered() {
  local frame
  frame=$(real_frame_of "$1") || { echo "the window server has no such window"; return 1; }
  # shellcheck disable=SC2086
  set -- "$1" $frame
  pointer windows --on-screen | awk -v id="$1" -v x="$2" -v y="$3" -v w="$4" -v h="$5" \
    -v apps=" $ARBOR_WINDOWS_PID $ARBOR_WINDOWS_PID_2 " '
    $1 == id { found = 1; exit }
    index(apps, " " $2 " ") && $4 < x + w && $4 + $6 > x && $5 < y + h && $5 + $7 > y { covered = 1 }
    END { exit !found || covered }' || { echo "another window lies over it, or it is not on screen"; return 1; }
}

arbor_start 3
ctl dock "$W1" left
ctl dock "$W2" beside "$W1" bottom
ctl dock "$V1" right
summary

claim "frame another app's window: it gets the keyboard"
click_window "$W1"
check "the first app has the keyboard" eventually front_is "$ARBOR_WINDOWS_PID"
ctl zoom "$V1"
check "the other app's window fills the screen" eventually fills "$V1"
check "the other app has the keyboard" eventually front_is "$ARBOR_WINDOWS_PID_2"
check "Arbor says its window is focused" eventually is focused "$V1"
ctl show-all
click_window "$W1"
check "a click brings the first app back" eventually front_is "$ARBOR_WINDOWS_PID"

claim "with one window framed, a docked window out of view gets the keyboard: the camera frames that one instead"
ctl zoom "$W1"
check "the window below it is out of view" eventually out_of_view "$W2"
tw activate "$W2"
check "it fills the screen: the level is kept" eventually fills "$W2"
check "the one the camera was on is out of view" eventually out_of_view "$W1"
settled
ctl show-all

claim "with a column framed, a docked window outside it gets the keyboard: the camera steps out just far enough to show it"
ctl zoom "$W1"
ctl out
check "the column is in view" eventually in_view "$W2"
check "the other app's window is out of view" eventually out_of_view "$V1"
tw2 activate "$V1"
check "it comes into view" eventually in_view "$V1"
check "together with the column the camera was on" eventually in_view "$W1"
settled
ctl show-all

claim "a floating window behind the framed one gets the keyboard: it comes to the front where it was, and the camera stays"
click_window "$W1"
floating=$(resting_frame_of "$W3")
ctl zoom "$W1"
check "the floating window lies behind the framed one" eventually fails uncovered "$W3"
tw activate "$W3"
check "it has the keyboard" eventually is focused "$W3"
check "nothing covers it" eventually uncovered "$W3"
# shellcheck disable=SC2086
check "it is where it was" stays frame_is "$W3" $floating
check "the camera stayed on the framed window" camera_on "$W1"
check "which still fills the screen" fills "$W1"
settled

claim "with the keyboard in a floating window, out only moves the view and leaves it there; zoom names a window and takes it along"
ctl out
check "the column is in view" eventually in_view "$W2"
check "the keyboard is still in the floating window" stays is focused "$W3"
check "nothing was raised over it" uncovered "$W3"
ctl zoom "$W2"
check "the window that was named fills the screen" eventually fills "$W2"
check "it has the keyboard" eventually is focused "$W2"
# shellcheck disable=SC2086
check "the floating window has not moved" frame_is "$W3" $floating
settled
ctl show-all

claim "another app's window out of view is brought forward by its app: the camera shows it"
ctl zoom "$W1"
check "the other app's window is out of view" eventually out_of_view "$V1"
tw2 activate "$V1"
check "the other app has the keyboard" eventually front_is "$ARBOR_WINDOWS_PID_2"
check "its window comes into view" eventually in_view "$V1"
settled
ctl show-all

claim "frame a window and show everything again: the docked windows lie in the order they had, front to back"
# Arbor raises none of them. What is asked is whether macOS keeps a window's place in its order while Accessibility moves it out of
# view and back.
click_window "$V1"
click_window "$W2"
click_window "$W1"
check "the first window has the keyboard" eventually is focused "$W1"
order=$(order_of_docked)
echo "front to back: $order"
ctl zoom "$W1"
check "the others are out of view" eventually out_of_view "$V1"
check "out of view they are in the same order" order_is "$order"
ctl show-all
check "everything is back in view" eventually in_view "$V1"
check "and in the same order" stays order_is "$order"
settled

# On a person's Mac ⌘Tab leads to whichever app of theirs was in front last.
if on_throwaway_mac; then
  claim "⌘Tab to an app whose window is out of view: the camera shows it"
  click_window "$V1"
  click_window "$W1"
  check "the first app has the keyboard" eventually front_is "$ARBOR_WINDOWS_PID"
  ctl zoom "$W1"
  check "the other app's window is out of view" eventually out_of_view "$V1"
  key cmd+tab
  sleep 0.5
  echo "the app in front is $(pointer front); the test apps are $ARBOR_WINDOWS_PID and $ARBOR_WINDOWS_PID_2"
  check "⌘Tab switched to the other app" eventually front_is "$ARBOR_WINDOWS_PID_2"
  check "its window comes into view" eventually in_view "$V1"
  settled
  ctl show-all
fi

claim "click a window in view: the camera stays"
click_window "$W2"
check "it has the keyboard" eventually is focused "$W2"
check "the camera stayed" stays camera_on root

arbor_stop

# The way back: with `floatingWindowsMakeWay`, which ships off, floating windows live on the Desktop and leave the view with it, as until F64.
arbor_settings '{"floatingWindowsMakeWay": true}'
ARBOR_SECOND_APP=0
arbor_start 2
ctl dock "$W1" left

claim "with floatingWindowsMakeWay on: a floating window out of view gets the keyboard: the camera steps out until the Desktop shows"
ctl zoom "$W1"
check "the floating window is out of view" eventually out_of_view "$W2"
tw activate "$W2"
check "it comes into view" eventually in_view "$W2"
settled
ctl show-all

arbor_stop
