#!/bin/bash
# Peek: hold ⌃⌥Space to look, let go to land. The keys go down with one line and come up with a later one.
# A51 peek: hold to look, let go to land.
ARBOR_SWITCHES=shipped  # it is about the keys that ship
source "$(dirname "$0")/../lib.sh"
arbor_build

SPACE=ctrl+opt+space

no_outline() {
  local shown
  shown=$(overlay_frame 3) || return 0
  echo "Arbor shows a panel at $shown"
  return 1
}
# outline_around <id>: the outline holds all of the window as the window server has it, and reaches at most 20 points beyond it
# on any side: the line runs in the gap.
outline_around() {
  local frame shown
  frame=$(resting_frame_of "$1") || { echo "the window server has no such window"; return 1; }
  shown=$(overlay_frame 3) || { echo "there is no outline"; return 1; }
  echo "$shown" | awk -v frame="$frame" '
    function near(beyond) { return beyond >= 0 && beyond <= 20 }
    BEGIN { split(frame, f, " ") }
    near(f[1] - $1) && near(f[2] - $2) && near($1 + $3 - f[1] - f[3]) && near($2 + $4 - f[2] - f[4]) { found = 1 }
    END { exit !found }' && return 0
  echo "the window is at $frame, the outline at $shown"
  return 1
}
everything_shows() { in_slot "$W1" && in_slot "$W2" && in_slot "$W3" && in_view "$W1" && in_view "$W2" && in_view "$W3"; }
only_shows() {
  local id
  fills "$1" || return 1
  for id in "$W1" "$W2" "$W3"; do
    [ "$id" = "$1" ] || out_of_view "$id" || return 1
  done
}
running() { "$ARBOR_BIN/arborctl" status | grep "^running" > /dev/null || { echo "Arbor is not running"; return 1; }; }
# The first window framed and with the keyboard, the pointer at rest on it. A ⌃⌥⎋ that the peek did not take has paused Arbor:
# that is one claim's failure and should not be the next one's.
start_over() {
  running > /dev/null || ctl resume
  ctl show-all
  ctl zoom "$W1"
  eventually only_shows "$W1" > /dev/null
  click_window "$W1"
}

arbor_start 3 ARBOR_NO_HOTKEYS=0
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W1" bottom
summary

start_over
# Where macOS switches the keyboard layout with ⌃⌥Space the key is declined, and every claim here would read as a failure of Arbor's.
arbor_input_is_ours key "$SPACE" || exit 77
claim "tap ⌃⌥Space with a window framed: everything shows and stays, and nothing is outlined"
proves A51
check "⌃⌥Space reaches Arbor" pressed $SPACE show-all
check "every window is in view, in its slot" eventually everything_shows
check "there is no outline" stays no_outline
check "nothing sprang back" everything_shows
check "⌃⌥[ reaches Arbor" pressed "ctrl+opt+[" back
check "and leads to the window that was framed" eventually only_shows "$W1"
settled

start_over
claim "hold ⌃⌥Space for a good look and let go without pointing at anything: everything shows meanwhile, then the view that was left is back"
proves A51
key $SPACE --down
check "every window is in view while the keys are down" eventually everything_shows
check "the window that was framed is outlined" eventually outline_around "$W1"
# Also the good look: let go within a second with nothing chosen, it would have been a slow tap.
check "for as long as the keys are down" stays outline_around "$W1"
check "everything still shows" everything_shows
key $SPACE --up
check "the window that was framed fills the screen again, alone" eventually only_shows "$W1"
check "it has the keyboard" is focused "$W1"
check "the outline is gone" eventually no_outline
settled

start_over
claim "hold ⌃⌥Space and move the pointer from window to window: the outline follows, and letting go frames the outlined window"
proves A51
key $SPACE --down
check "the window that was framed is outlined" eventually outline_around "$W1"
# shellcheck disable=SC2046
move $(center_of "$W2")
check "the outline is around the window under the pointer" eventually outline_around "$W2"
# shellcheck disable=SC2046
move $(center_of "$W3")
check "and goes on to the next one" eventually outline_around "$W3"
check "no window moved for it" everything_shows
key $SPACE --up
check "the outlined window fills the screen, alone" eventually only_shows "$W3"
check "it has the keyboard" eventually is focused "$W3"
check "the outline is gone" eventually no_outline
check "⌃⌥[ reaches Arbor" pressed "ctrl+opt+[" back
check "one step back is the view before the peek" eventually only_shows "$W1"
settled

start_over
claim "hold ⌃⌥Space and press ↓: the outline moves to the window below while the view stays, and letting go frames that window"
proves A51
key $SPACE --down
check "the window that was framed is outlined" eventually outline_around "$W1"
key ctrl+opt+down --held
check "the outline is around the window below" eventually outline_around "$W3"
check "Arbor did not step in, as ⌃⌥↓ otherwise does" stays fails ran in
check "everything still shows" everything_shows
key $SPACE --up
check "the outlined window fills the screen, alone" eventually only_shows "$W3"
check "it has the keyboard" eventually is focused "$W3"
settled

start_over
claim "hold ⌃⌥Space, point at another window and press ⎋: the view that was left is back, and letting go changes nothing"
proves A51
key $SPACE --down
check "the window that was framed is outlined" eventually outline_around "$W1"
# shellcheck disable=SC2046
move $(center_of "$W2")
check "the outline is around the window under the pointer" eventually outline_around "$W2"
key ctrl+opt+escape --held
check "the window that was framed fills the screen again, alone" eventually only_shows "$W1"
check "the outline is gone" eventually no_outline
check "Arbor did not pause, as ⌃⌥⎋ otherwise makes it" running
key $SPACE --up
check "the view stays when the keys come up" stays only_shows "$W1"
settled

start_over
claim "switch peek off by command: ⌃⌥Space held is plain Show Everything, and letting go over another window frames nothing"
proves A51
check "set peek false succeeds" ctl set peek false
key $SPACE --down
check "every window is in view" eventually everything_shows
check "nothing is outlined, however long the keys are down" stays no_outline
# shellcheck disable=SC2046
move $(center_of "$W2")
check "nor under the pointer" stays no_outline
key $SPACE --up
check "everything stays in view when the keys come up" stays everything_shows
check "set peek true succeeds" ctl set peek true
settled

arbor_stop
