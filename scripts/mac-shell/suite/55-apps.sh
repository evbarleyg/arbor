#!/bin/bash
# What real apps do to a window manager: they open native tabs, put their windows where they like, stop answering,
# change their focus behind the person's back, and are out of sight when Arbor starts.
# A70 a native tab group is one window, A71 an app that hangs does not hold Arbor up, A72 no fight with an app that
# places its own window, A74 the camera follows the app you switch to, and only that, A75 minimized windows and hidden
# apps keep their places across a restart.
source "$(dirname "$0")/../lib.sh"
arbor_build

# `eventually`, twice over: for what takes Arbor itself a few seconds.
patiently() { eventually "$@" > /dev/null 2>&1 || eventually "$@"; }

ARBOR_SECOND_APP=2
# Four columns on a 1024-point screen are 241 points each, a point above where slots become tiles.
arbor_settings '{"minimumUsableWidth": 200}'
arbor_start 3 ARBOR_NO_HOTKEYS=0
# Each at the left edge of the view, so that all share the row evenly: the first, the second, the other app's two one
# above the other, the Desktop. The first app's third window floats there.
ctl dock "$V1" left
ctl dock "$W2" left
ctl dock "$W1" left
ctl dock "$V2" beside "$V1" bottom
summary
first=$(real_frame_of "$W1")
second=$(real_frame_of "$W2")
other=$(real_frame_of "$V1")
width=$(width_of "$W1")

claim "a docked window gets a new native tab: the tab has the window's slot and nothing else moves"
proves A70
open_tab T1 "$W1"
check "the tab is docked" eventually is docked "$T1"
# shellcheck disable=SC2086
check "where the window was" eventually frame_is "$T1" $first
check "the tab it covers has no place of its own" eventually fails is docked "$W1"
check "as many windows are docked as before" count docked 4
# shellcheck disable=SC2086
check "the window beside it has not moved" stays frame_is "$W2" $second
# shellcheck disable=SC2086
check "nor has the other app's" frame_is "$V1" $other
settled

claim "choose the first tab again: it has the slot back and the other tab leaves nothing behind"
proves A70
tw select "$W1"
check "the first tab is docked" eventually is docked "$W1"
# shellcheck disable=SC2086
check "in the same place" eventually frame_is "$W1" $first
check "the other tab has no place of its own" eventually fails is docked "$T1"
check "as many windows are docked as before" count docked 4
# shellcheck disable=SC2086
check "the window beside it has not moved" frame_is "$W2" $second
settled

claim "close the tab in front with ⌘W: the tab behind it inherits the slot"
proves A70
tw select "$T1"
check "the second tab is in the slot" eventually in_slot "$T1"
click_window "$T1"
key_to "$T1" cmd+w
forget_window "$T1"
check "Arbor has forgotten the closed tab" eventually fails is known "$T1"
check "the first tab is docked" eventually is docked "$W1"
# shellcheck disable=SC2086
check "in the same place" eventually frame_is "$W1" $first
check "as many windows are docked as before" count docked 4
# shellcheck disable=SC2086
check "the window beside it has not moved" frame_is "$W2" $second
settled

claim "a new tab in the window the camera frames, closed again with ⌘W: the camera stays on the group"
proves A70
ctl zoom "$W1"
check "the window fills the screen" eventually fills "$W1"
open_tab T2 "$W1"
check "the tab fills the screen" eventually fills "$T2"
check "the camera is on it" eventually camera_on "$T2"
check "the others stay out of view" stays out_of_view "$W2"
click_window "$T2"
key_to "$T2" cmd+w
forget_window "$T2"
check "the first tab fills the screen again" eventually fills "$W1"
check "the camera is on it" eventually camera_on "$W1"
check "the others are still out of view" out_of_view "$W2"
ctl show-all
settled

# Inside the window's own slot, so that it covers nobody.
take "x y w h" slot_of "$W1"
own="$((x + 30)) $((y + 30)) $((w - 60)) $((h - 60))"

claim "an app moves its docked window once: Arbor puts it back"
proves A72
# shellcheck disable=SC2086
check "the app moves it" tw move "$W1" $own
# shellcheck disable=SC2086
check "it is back in its slot" eventually frame_is "$W1" $first
settled

claim "an app insists on a place of its own for a docked window: Arbor puts it back a few times, then leaves it alone"
proves A72
# shellcheck disable=SC2086
tw insist "$W1" $own
check "Arbor gives up on it" patiently logged "keeps moving itself"
# shellcheck disable=SC2086
check "the window stays where its app wants it" stays frame_is "$W1" $own
check "it is still docked" is docked "$W1"
check "the window beside it is in its slot" in_slot "$W2"

claim "the app relents and the neighbour is minimized: with the new layout the window is in its slot again"
proves A72
tw relent "$W1"
# shellcheck disable=SC2086
check "until the layout changes it is left where it is" stays frame_is "$W1" $own
click_button "$W2" minimize
check "Arbor sees the neighbour minimized" eventually is minimized "$W2"
check "the window is in its slot" eventually in_slot "$W1"
check "which has grown" eventually wider_than "$W1" "$((width + 40))"
settled
tw restore "$W2"
# shellcheck disable=SC2086
check "with the neighbour back it is where it was at first" eventually frame_is "$W1" $first
settled

claim "an app stops answering and ⌃⌥↩ frames another app's window: the camera moves all the same"
proves A71
# `tw` waits for the app's answer, which will be a while: it does so in the background, and gives up by itself. By the
# time the click has landed the app has read the request, so the shortcut finds it hanging.
tw hang 7 > /dev/null 2>&1 &
click_window "$V1"
check "the other app's window has the keyboard" eventually is focused "$V1"
check "⌃⌥↩ reaches Arbor" pressed ctrl+opt+return zoom
# shellcheck disable=SC2086
check "nobody can move the windows of the app that hangs" frame_is "$W1" $first
check "the other app's window fills the screen" eventually fills "$V1"
check "its second window is out of view" eventually out_of_view "$V2"

claim "the app answers again: its docked windows go where the layout has them"
proves A71
# The rest of the hang.
sleep 6
check "the first is out of view" eventually out_of_view "$W1"
check "the second is out of view" eventually out_of_view "$W2"
check "the other app's window still fills the screen" fills "$V1"
settled

claim "the app answers again: its floating window leaves the view too"
proves A71
check "it is out of view" eventually out_of_view "$W3"

claim "⌃⌥0 after the hang: every window is back where it was"
proves A71
check "⌃⌥0 reaches Arbor" pressed ctrl+opt+0 home
# shellcheck disable=SC2086
check "the first" eventually frame_is "$W1" $first
# shellcheck disable=SC2086
check "the second" eventually frame_is "$W2" $second
# shellcheck disable=SC2086
check "the other app's" eventually frame_is "$V1" $other
check "the one that floats is in view" eventually in_view "$W3"
settled

claim "an app hangs with its windows out of view and ⌃⌥⎋ pauses Arbor: once it answers, its windows are back in view"
proves A71
click_window "$V1"
check "⌃⌥↩ frames the other app's window" pressed ctrl+opt+return zoom
check "the first app's window is out of view" eventually out_of_view "$W1"
tw hang 6 > /dev/null 2>&1 &
click_window "$V1"
check "the other app's window has the keyboard" eventually is focused "$V1"
key ctrl+opt+escape
check "Arbor is paused" eventually says "paused" arborctl status
# The rest of the hang.
sleep 6
check "the first is in view" eventually in_view "$W1"
check "the second is in view" eventually in_view "$W2"
key ctrl+opt+escape
check "Arbor runs again" eventually says "running" arborctl status
ctl show-all
settled

claim "click another app's window that is in view: it gets the keyboard and the camera stays"
proves A74
click_window "$W1"
check "the first app has the keyboard" eventually front_is "$ARBOR_WINDOWS_PID"
click_window "$V1"
check "the other app has the keyboard" eventually front_is "$ARBOR_WINDOWS_PID_2"
check "Arbor says its window is focused" eventually is focused "$V1"
check "the camera stays on everything" stays camera_on root
settled

claim "switch to another app's second window, which is out of view: the camera follows"
proves A74
ctl zoom "$W1"
check "the first app has the keyboard" eventually front_is "$ARBOR_WINDOWS_PID"
check "the other app's second window is out of view" eventually out_of_view "$V2"
tw2 activate "$V2"
check "the other app has the keyboard" eventually front_is "$ARBOR_WINDOWS_PID_2"
check "Arbor says its second window is focused" eventually is focused "$V2"
check "which comes into view" eventually in_view "$V2"
settled

claim "an app in the background changes its focused window: nothing moves"
proves A74
ctl zoom "$W1"
check "the first app's window fills the screen" eventually fills "$W1"
check "the first app has the keyboard" eventually front_is "$ARBOR_WINDOWS_PID"
tw2 key "$V1"
check "the camera stays where the person is" stays camera_on "$W1"
check "the window still fills the screen" fills "$W1"
check "the window the other app chose is still out of view" out_of_view "$V1"
check "the first app still has the keyboard" front_is "$ARBOR_WINDOWS_PID"
check "Arbor says its window is focused" is focused "$W1"
ctl show-all
settled

claim "quit Arbor with a docked window minimized and an app hidden, and start it again: they have kept their places"
proves A75
click_button "$W2" minimize
check "Arbor sees the window minimized" eventually is minimized "$W2"
click_window "$V1"
key_to "$V1" cmd+h
check "Arbor sees the other app's windows hidden" eventually is hidden "$V1"
arbor_quit
arbor_relaunch
check "the window is still minimized" is minimized "$W2"
check "and docked" is docked "$W2"
check "the other app is still hidden" is hidden "$V1"
check "its first window is docked" is docked "$V1"
check "and its second" is docked "$V2"
check "the one window in sight has their space meanwhile" eventually wider_than "$W1" "$((width + 40))"
settled

claim "restore the window that was minimized when Arbor started: it is back in its slot"
proves A75
tw restore "$W2"
check "Arbor sees it restored" eventually fails is minimized "$W2"
check "it is in its slot" eventually in_slot "$W2"
check "and stays there" stays in_slot "$W2"
check "right of the first" left_of "$W1" "$W2"
settled

claim "show the app that was hidden when Arbor started: every window is between the same neighbours as before"
proves A75
tw2 unhide
check "Arbor sees it shown" eventually fails is hidden "$V1"
check "its first window is in its slot" eventually in_slot "$V1"
check "right of the window that was minimized" left_of "$W2" "$V1"
check "above its second" above "$V1" "$V2"
# shellcheck disable=SC2086
check "the first window is where it was before the restart" eventually frame_is "$W1" $first
# shellcheck disable=SC2086
check "the one that was minimized too" frame_is "$W2" $second
# shellcheck disable=SC2086
check "and the other app's" frame_is "$V1" $other
settled

arbor_stop
