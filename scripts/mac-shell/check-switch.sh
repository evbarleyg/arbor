#!/bin/bash
# Switching apps on real windows, with a real pointer and real keys: the view follows the window that gets the keyboard, and only that one.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-switch.sh
#
# What only a Mac can say. macOS tells of a switch of apps that the app is active, and no more; Arbor asks the app for its focused window
# (`AppThatCameForward`, `AXWindowSystem.appCameForward`). So:
#   - ⌘Tab to an app whose focused window is out of view: the view goes there, every time (one switch in three used to be dropped);
#   - a click on a window IN view, of an app in the background whose focused window is OUT of view: the app comes forward at the press, and may
#     still name the window it had before. The view must stay: the person clicked on what they were looking at.
# Each is tried several times, because what goes wrong here goes wrong by milliseconds. The end prints how often macOS was behind.
#
# Safe on a person's Mac: it touches its own test windows and the pointer, and changes no setting. ⌘Tab is left out there.
source "$(dirname "$0")/lib.sh"

ROUNDS=6

arbor_build

step "two apps: the first has two windows, the other one"
mkfifo "$ARBOR_SESSION_DIR/stdin2"
"$ARBOR_BIN/ArborTestWindows" --count 1 --regular < "$ARBOR_SESSION_DIR/stdin2" > "$ARBOR_SESSION_DIR/hello2" 2>> "$ARBOR_OUT/test-windows.log" &
SECOND=$!
started "$SECOND"
at_exit "kill_started $SECOND"
exec 8> "$ARBOR_SESSION_DIR/stdin2"
sleep 2
hello2=$(head -n 1 "$ARBOR_SESSION_DIR/hello2")
P2=$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["pid"])' "$hello2") || die "no second process: $hello2"
X1=$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["windows"][0])' "$hello2")
ARBOR_EXTRA_PIDS=$P2
ARBOR_TEST_WINDOWS_ARGS="--regular"
arbor_start 2
check "Arbor manages the other app's window too" eventually is managed "$X1"
# Two apps have just joined the Dock, which changes the visible frame for a second or so.
sleep 3

# [W1 | Desktop | (W2 / X1)]: the column is a space of its own, with a window of each app in it.
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$X1" beside "$W2" bottom
summary

view() { state | python3 -c 'import json, sys; print(json.load(sys.stdin)["displays"][0]["camera"])'; }
view_is() { [ "$(view)" = "$1" ]; }
not() { ! "$@"; }
behind() { grep -c "macOS still names another app as the one in front" "$ARBOR_HOME/arbor.log"; }

# The view on the column, the keyboard in the other app's window, and W1, out of view, still the first app's focused window.
start_over() {
  ctl show-all > /dev/null
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  eventually is focused "$W1" || return 1
  # shellcheck disable=SC2046
  click $(center_of "$X1")
  eventually is focused "$X1" || return 1
  ctl zoom "$X1" > /dev/null
  ctl step-out > /dev/null
  eventually is parked "$W1" && not is parked "$W2" && not is parked "$X1" && is focused "$X1"
}

round=1
while [ "$round" -le "$ROUNDS" ]; do
  step "a click on a window in view, of an app whose focused window is out of view ($round of $ROUNDS)"
  check "the view is on the column, the keyboard in the other app" start_over || summary
  COLUMN=$(view)
  # shellcheck disable=SC2046
  click $(center_of "$W2")
  check "the window that was clicked has the keyboard" eventually is focused "$W2"
  # Long enough for every look Arbor takes at a focus report (a second).
  sleep 1.5
  check "the view did not move" view_is "$COLUMN" || summary
  check "the first app's other window is still out of view" is parked "$W1"
  round=$((round + 1))
done

if on_throwaway_mac; then
  round=1
  while [ "$round" -le "$ROUNDS" ]; do
    step "⌘Tab to an app whose focused window is out of view ($round of $ROUNDS)"
    check "the view is on the column, the keyboard in the other app" start_over || summary
    key cmd+tab
    check "the first app's window has the keyboard" eventually is focused "$W1"
    check "and is in view" eventually is on_screen "$W1" || summary
    round=$((round + 1))
  done
else
  echo "⌘Tab is left out on a person's own Mac: the app used before may be theirs"
fi

echo
echo "macOS named the app in front late $(behind) time(s) in this session"
grep -c "was never named as the app in front" "$ARBOR_HOME/arbor.log" | sed 's/^/given up on: /'

arbor_stop
exec 8>&-
