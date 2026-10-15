#!/bin/bash
# What survives Arbor ending, however it ends.
# T60 the arrangement is restored, T61 quitting puts every window in view, T62 float-all,
# A06 windows left off screen by a crash are recovered, A07 reused window numbers are ignored,
# A14 a state file Arbor cannot use is set aside.
source "$(dirname "$0")/../lib.sh"
arbor_build
arbor_start 4
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W1" bottom
ctl resize "$W1" right 60
ctl zoom "$W2"
ctl save-view 4
ctl show-all
first=$(real_frame_of "$W1")
second=$(real_frame_of "$W2")
third=$(real_frame_of "$W3")
summary

claim "quit Arbor, move the windows about, start it again: the arrangement is back"
proves T60
arbor_quit
tw move "$W1" 300 200 400 300
tw move "$W3" 100 80 500 260
arbor_relaunch
check "three are docked" count docked 3
# shellcheck disable=SC2086
check "the first window is back in its place, seam and all" eventually frame_is "$W1" $first
# shellcheck disable=SC2086
check "the second" eventually frame_is "$W2" $second
# shellcheck disable=SC2086
check "the third" eventually frame_is "$W3" $third
check "the fourth still floats" is floating "$W4"
check "the camera shows everything" camera_on root
check "the saved view is still there" ctl view 4
check "and frames the same window" eventually fills "$W2"
ctl show-all
settled

claim "quit Arbor while zoomed in and start it again: it shows everything, takes no window out of view, and Back returns to the old view"
proves T60
ctl zoom "$W3"
check "the window fills the screen" eventually fills "$W3"
arbor_quit
check "quitting brought the others back into view" eventually in_view "$W1"
arbor_relaunch
check "the camera shows everything" eventually camera_on root
check "the first window stays in view" stays in_view "$W1"
check "the window that was framed is in its slot" eventually in_slot "$W3"
check "the one that floats is in view" in_view "$W4"
check "there is a view to go back to" can back
ctl back
check "which is the one Arbor stopped in" eventually fills "$W3"
check "the others are out of view there" eventually out_of_view "$W1"
ctl show-all
check "and come back with show-all" eventually in_view "$W1"
settled

claim "the apps restarted too: their new windows are matched by app and title"
proves T60
arbor_quit
reopen_test_windows 4
arbor_relaunch
check "three are docked" count docked 3
# shellcheck disable=SC2086
check "the window with the first title has the first place" eventually frame_is "$W1" $first
# shellcheck disable=SC2086
check "the second" eventually frame_is "$W2" $second
# shellcheck disable=SC2086
check "the third" eventually frame_is "$W3" $third
settled

claim "a saved window number that now belongs to another app is not trusted"
proves A07
arbor_quit
python3 - "$ARBOR_HOME/state.json" "$W2" <<'PYTHON'
import json, sys
path, window = sys.argv[1:]
state = json.load(open(path))
# As after a reboot: the number is in use again, by a window of some other app with some other title.
state["hints"][window] = {"bundleID": "com.example.other", "title": "Something else"}
json.dump(state, open(path, "w"))
PYTHON
arbor_relaunch
check "the window with the reused number is not docked" is floating "$W2"
check "the others are" count docked 2
check "it was left where it was" in_view "$W2"
ctl dock "$W2" right
settled

claim "kill Arbor while zoomed in: the windows it had moved away are stranded"
proves A06
ctl zoom "$W1"
check "the others are out of view" eventually out_of_view "$W2"
check "the floating one too" eventually out_of_view "$W4"
sleep 1
arbor_kill KILL
check "nothing brought them back" stays out_of_view "$W2"

claim "start Arbor after the crash: every window is within reach again"
proves A06
arbor_relaunch
check "Arbor arranges all four" count managed 4
ctl show-all
check "the first window is in view" eventually in_view "$W1"
check "the second window is in view" eventually in_view "$W2"
check "the third window is in view" eventually in_view "$W3"
check "the floating window is in view" eventually in_view "$W4"
settled

claim "kill Arbor the moment it zooms in, before it has saved: the next launch still strands nothing"
proves A06
ctl zoom "$W1"
arbor_kill KILL
arbor_relaunch
ctl show-all
check "the first window is in view" eventually in_view "$W1"
check "the second window is in view" eventually in_view "$W2"
check "the third window is in view" eventually in_view "$W3"
check "the floating window is in view" eventually in_view "$W4"
settled

claim "kill Arbor while zoomed in and lose its saved state: the next launch rescues the stranded windows"
proves A06
ctl zoom "$W1"
check "the others are out of view" eventually out_of_view "$W2"
arbor_kill KILL
rm -f "$ARBOR_HOME/state.json"
arbor_relaunch
check "the log says it rescued windows" logged "rescued off-screen window"
check "the first window is in view" eventually in_view "$W1"
check "the second window is in view" eventually in_view "$W2"
check "the third window is in view" eventually in_view "$W3"
check "the floating window is in view" eventually in_view "$W4"
check "nothing is docked: there was no arrangement to restore" count docked 0

claim "a damaged state file cannot stop Arbor, and is kept for whoever wants to look"
proves A14
ctl arrange
arbor_quit
printf '{"version": 1, "workspaces": [{' > "$ARBOR_HOME/state.json"
arbor_relaunch
check "Arbor runs and arranges all four" count managed 4
check "it starts afresh: nothing is docked" count docked 0
check "the damaged file was set aside" test -s "$ARBOR_HOME/state.unreadable.json"
check "every window is in view" eventually in_view "$W1"

claim "a state file from a newer Arbor is not overwritten"
proves A14
arbor_quit
rm -f "$ARBOR_HOME/state.unreadable.json"
printf '{"version": 9999, "somethingNew": true}' > "$ARBOR_HOME/state.json"
arbor_relaunch
check "Arbor runs" count managed 4
check "the newer file was set aside as it was" grep -q somethingNew "$ARBOR_HOME/state.unreadable.json"
check "the log says why" logged "from a newer Arbor"

claim "end Arbor with SIGTERM while zoomed in: it puts every window back first"
proves T61
ctl arrange
ctl zoom "$W2"
check "the others are out of view" eventually out_of_view "$W1"
arbor_kill TERM
check "the first window is in view" eventually in_view "$W1"
check "the second window is in view" eventually in_view "$W2"
check "the third window is in view" eventually in_view "$W3"
check "the fourth window is in view" eventually in_view "$W4"
check "the log says so" logged "all windows returned to view"
arbor_relaunch

claim "float-all while zoomed in: every window is in view and nothing is docked"
proves T62
ctl zoom "$W2"
check "the others are out of view" eventually out_of_view "$W1"
check "float-all succeeds" ctl float-all
check "nothing is docked" count docked 0
check "the first window is in view" eventually in_view "$W1"
check "the second window is in view" eventually in_view "$W2"
check "the third window is in view" eventually in_view "$W3"
check "the fourth window is in view" eventually in_view "$W4"

arbor_stop
