#!/bin/bash
# The ways home: the frame shortcut pressed again, home, float all, and pausing Arbor altogether.
# A40 pause and resume, A41 home, A42 the frame shortcut pressed again returns, A43 windows that cannot grow,
# T17 Float All Windows.
source "$(dirname "$0")/../lib.sh"
arbor_build

paused() { "$ARBOR_BIN/arborctl" status | grep "^paused" > /dev/null || { echo "Arbor is not paused"; return 1; }; }
running() { "$ARBOR_BIN/arborctl" status | grep "^running" > /dev/null || { echo "Arbor is not running"; return 1; }; }
# But for the line that says what happened (F43, level 6: "Arbor is paused: its keys are the apps’ again · ⌃⌥⎋ resumes"), which stays four seconds and goes by itself.
no_overlays() {
  local shown
  shown=$(overlays | awk '$8 == "on" && $3 != 6')
  [ -z "$shown" ] || { echo "Arbor shows: $(echo "$shown" | head -n 1)"; return 1; }
}

arbor_start 3 ARBOR_NO_HOTKEYS=0
# Where each window is before Arbor touches it, and how large: what a pause gives back.
own1=$(resting_frame_of "$W1")
own2=$(resting_frame_of "$W2")
own3=$(resting_frame_of "$W3")
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W2" bottom
summary
shortcuts=$("$ARBOR_BIN/arborctl" bindings | grep -c "^[a-z].* → ")
left_edge=$(edge_point left)

claim "⌃⌥↩ pressed again returns to where the camera was"
proves A42
click_window "$W3"
check "⌃⌥↩ reaches Arbor" pressed ctrl+opt+return zoom
check "the focused window fills the screen" eventually fills "$W3"
check "the others are out of view" eventually out_of_view "$W1"
check "⌃⌥↩ again" pressed ctrl+opt+return zoom
check "the camera is back on everything" eventually camera_on root
check "the others are back in view" eventually in_view "$W1"
settled

claim "⌃⌥0 goes home: everything is in view"
proves A41
ctl zoom "$W1"
check "the others are out of view" eventually out_of_view "$W3"
check "⌃⌥0 reaches Arbor" pressed ctrl+opt+0 home
check "the camera is on everything" eventually camera_on root
check "the second window is in view" eventually in_view "$W2"
check "the third window is in view" eventually in_view "$W3"
settled

claim "⌃⌥⎋ pauses Arbor while zoomed in: every window comes back and Arbor lets go of the Mac"
proves A40
ctl zoom "$W3"
check "the others are out of view" eventually out_of_view "$W1"
key ctrl+opt+escape
check "⌃⌥⎋ reaches Arbor" eventually logged "INFO  paused"
check "status says paused" eventually paused
check "the first window is in view" eventually in_view "$W1"
check "the second window is in view" eventually in_view "$W2"
check "the third window is in view" eventually in_view "$W3"
# As after a quit: not in the shape of a slot, and the framed one no longer over the whole screen.
# shellcheck disable=SC2086
check "the first window is where it was before it was docked, in its own size" eventually frame_is "$W1" $own1
# shellcheck disable=SC2086
check "and so is the second" eventually frame_is "$W2" $own2
# shellcheck disable=SC2086
check "and the framed one" eventually frame_is "$W3" $own3
check "none of Arbor's own windows is on screen" eventually no_overlays
check "only the shortcut that ends the pause is still registered" eventually logged "registered 1 shortcuts"
check "a command is refused" fails ctl dock "$W1" right

claim "while paused Arbor reacts to nothing: no shortcut, no drag"
proves A40
second=$(resting_frame_of "$W2")
keys=$(events_of "$W3" key)
key ctrl+opt+space
check "⌃⌥Space does not reach Arbor" stays fails ran show-all
check "it goes to the window that was framed, which still has the keyboard" eventually received "$W3" key -gt "$keys"
# shellcheck disable=SC2086
drag_window "$W1" $left_edge --no-release
check "a drag to the left screen edge shows no preview" stays no_overlays
release
check "Arbor is still paused" paused
# shellcheck disable=SC2086
check "the second window has not moved" stays frame_is "$W2" $second

claim "⌃⌥⎋ again resumes: the arrangement and the view are back"
proves A40
# A resume ends with the focused window in view, so the keyboard goes back to the window that was framed.
click_window "$W3"
key ctrl+opt+escape
check "⌃⌥⎋ reaches Arbor" eventually logged "INFO  resumed"
check "status says running" eventually running
check "the view is back on the third window" eventually fills "$W3"
check "the first window is out of view again" eventually out_of_view "$W1"
check "the second window is out of view again" eventually out_of_view "$W2"
check "all the shortcuts are registered again" eventually logged "registered $shortcuts shortcuts"
check "⌃⌥Space works again" pressed ctrl+opt+space show-all
check "the window dragged away during the pause is back in its slot" eventually in_slot "$W1"
settled

claim "resume with the keyboard in a window the view left out: the view moves to show it"
proves A40
ctl zoom "$W3"
check "the first window is out of view" eventually out_of_view "$W1"
key ctrl+opt+escape
check "Arbor is paused" eventually paused
click_window "$W1"
key ctrl+opt+escape
check "Arbor runs again" eventually running
check "the window with the keyboard is in view" eventually in_view "$W1"
ctl show-all
settled

claim "pause for a while by command: Arbor resumes by itself"
proves A40
check "pause 0.05, three seconds, succeeds" ctl pause 0.05
check "status says paused" paused
sleep 4
check "it has resumed" eventually running
settled

claim "close a docked window and open another while paused: Arbor leaves both alone, and resumes without the one and with the other floating"
proves A40
open_window N1 size=300x200 title=Short lived
ctl dock "$N1" beside "$W1" bottom
check "the new window is docked below the first" eventually above "$W1" "$N1"
take "x y" desktop_point
click_window "$W1"
key ctrl+opt+escape
check "Arbor is paused" eventually paused
tw close "$N1"
forget_window "$N1"
open_window N2 size=300x200 "at=$((x - 150)),$((y - 100))" title=Opened meanwhile
check "the window opened meanwhile stays where its app put it" stays corner_is "$N2" "$((x - 150))" "$((y - 100))"
key ctrl+opt+escape
check "Arbor runs again" eventually running
check "Arbor no longer knows the closed window" eventually fails is known "$N1"
check "its neighbour has the whole column" eventually at_edge "$W1" bottom
check "three are docked, as before" count docked 3
check "the window opened meanwhile floats" eventually is floating "$N2"
settled
tw close "$N2"
forget_window "$N2"

claim "⌃⌥⇧F floats every window, from wherever the camera is"
proves T17
ctl zoom "$W1"
check "the others are out of view" eventually out_of_view "$W2"
check "⌃⌥⇧F reaches Arbor" pressed ctrl+opt+shift+f float-all
check "nothing is docked" eventually count docked 0
check "the first window is in view" eventually in_view "$W1"
check "the second window is in view" eventually in_view "$W2"
check "the third window is in view" eventually in_view "$W3"
check "the window that was framed no longer covers the screen" eventually fails fills "$W1"
arbor_stop

ARBOR_TEST_WINDOWS_ARGS="--max-size 1:300x240"
arbor_start 2

claim "a docked window that cannot grow sits in the middle of its slot"
proves A43
ctl dock "$W1" left
ctl dock "$W2" right
take "sx sy sw sh" slot_of "$W1"
take "x y w h" resting_frame_of "$W1"
echo "its slot is at $sx $sy $sw $sh, the window at $x $y $w $h"
check "it kept its own width" test "${w%.*}" -le 300
check "it is centred across" about "$((${x%.*} + ${w%.*} / 2))" "$((sx + sw / 2))"
check "it is centred down" about "$((${y%.*} + ${h%.*} / 2))" "$((sy + sh / 2))"
check "Arbor leaves it there" stays frame_is "$W1" "$x" "$y" "$w" "$h"
width=$(width_of "$W2")
ctl resize "$W2" left 60
check "its neighbour is resized by command" eventually wider_than "$W2" "$((width + 40))"
check "it does not twitch when a neighbour is resized" stays frame_is "$W1" "$x" "$y" "$w" "$h"
arbor_stop
