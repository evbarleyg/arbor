#!/bin/bash
# Giving the keyboard to a window that is out of view brings it into view: what ⌘Tab, the Dock, a notification
# or `open` do all day. Part of T52 (windows outside the view) and of the manual checks in docs/TESTING.md.
source "$(dirname "$0")/../lib.sh"
arbor_build
ARBOR_SECOND_APP=1
# In the Dock and in ⌘Tab, like a person's apps, which only the claim about ⌘Tab needs. On a person's Mac they could stay among the
# Dock's recent apps.
if on_throwaway_mac; then
  ARBOR_TEST_WINDOWS_ARGS="--regular"
  ARBOR_SECOND_APP_ARGS="--regular"
fi
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

claim "a floating window out of view gets the keyboard: the camera steps out until the Desktop shows"
ctl zoom "$W1"
check "the floating window is out of view" eventually out_of_view "$W3"
tw activate "$W3"
check "it comes into view" eventually in_view "$W3"
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
