#!/bin/bash
# Windows that come: an app summoned over whatever is in view.
# A53 summon an app over any view.
source "$(dirname "$0")/../lib.sh"
arbor_build

# is_at <id> <x> <y> <w> <h>: what the window server says, which it also says while Arbor is not running.
is_at() {
  local id=$1
  shift
  arbor_close "$(real_frame_of "$id")" "$*" || { echo "it is at $(real_frame_of "$id"), not at $*"; return 1; }
}
# Arbor has heard of a move that the app made itself. What it keeps of a window's place is what it last saw of it.
seen_where_it_is() { arbor_close "$(frame_of "$1")" "$(real_frame_of "$1")"; }
# uncovered <id>: of the windows the window server has in front of it, none that belongs to the test apps overlaps it.
# (Arbor raises a window only when something covers it, so it need not be the frontmost.)
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
# role_is <id> summoned|stashed: what Arbor's state says of a window that comes and goes.
role_is() {
  state | python3 -c '
import json, sys
window = [w for w in json.load(sys.stdin)["windows"] if w["id"] == int(sys.argv[1])]
sys.exit(0 if window and window[0].get(sys.argv[2]) else 1)' "$1" "$2" || { echo "Arbor does not call it $2"; return 1; }
}

ARBOR_SECOND_APP=1
# `summon` opens the app when Arbor knows no window of it that can show (AXWindowSystem+Opening.swift). So an app is named
# by the test apps' bundle ids only, which no other app has, and only while Arbor has a window of that app to bring: a
# second copy of the test app, started by macOS, would be nobody's to stop.
there_to_summon() {
  is managed "$1" && fails is minimized "$1" && fails is hidden "$1" \
    || { echo "Arbor has no window to bring, and would open the app"; return 1; }
}
summon_key() { there_to_summon "$V1" && pressed 'ctrl+opt+`' summon "$ARBOR_TEST_BUNDLE_2"; }
docked_says() { there_to_summon "$W1" && says "is docked" arborctl summon "$ARBOR_TEST_BUNDLE"; }

# Nothing is bound to it either; ⌃⌥` is one of the two keys kept free for it.
arbor_settings "{\"bindings\": {\"ctrl+opt+\`\": \"summon $ARBOR_TEST_BUNDLE_2\"}}"
arbor_start 2 ARBOR_NO_HOTKEYS=0
# Half as wide as the screen: more than the third of it that the Desktop keeps between two docked windows.
take "_ _ screen_w _" screen_of 1
take "x y _ own_h" real_frame_of "$V1"
own_w=$((screen_w / 2))
tw2 move "$V1" "$x" "$y" "$own_w" "$own_h"
eventually seen_where_it_is "$V1"
ctl dock "$W1" left
ctl dock "$W2" right
click_window "$W1"
squeezed_w=$(width_of "$V1")
ctl zoom "$W1"
summary

claim "press the shortcut bound to summon: the other app's window comes over the framed window with the keyboard in it"
proves A53
check "the framed window fills the screen" eventually fills "$W1"
check "the other app's window is out of view with the Desktop" eventually out_of_view "$V1"
check "the framed window has the keyboard" eventually is focused "$W1"
check "⌃⌥\` reaches Arbor" summon_key
check "the other app's window is in view" eventually in_view "$V1"
check "it has the keyboard" eventually is focused "$V1"
check "its app is the one in front" eventually front_is "$ARBOR_WINDOWS_PID_2"
check "nothing covers it" eventually uncovered "$V1"
check "Arbor calls it summoned, and it stays" stays role_is "$V1" summoned
check "the view has not moved" camera_on "$W1"
check "the framed window still fills the screen" fills "$W1"
check "the other docked window is still out of view" out_of_view "$W2"

claim "summoned for the first time, a window that a narrow Desktop had squeezed comes at its own size"
proves A53
check "the Desktop between two docked windows had squeezed it" test "$squeezed_w" -lt "$((own_w - 40))"
check "over the view it is as wide as it was before anything was docked" width_is "$V1" "$own_w"
check "and as high" height_is "$V1" "${own_h%.*}"

claim "press the summon shortcut again: the window goes out of view, and the keyboard back to the window that had it"
proves A53
check "⌃⌥\` reaches Arbor" summon_key
check "the other app's window is out of view" eventually out_of_view "$V1"
check "the framed window has the keyboard again" eventually is focused "$W1"
check "its app is the one in front" eventually front_is "$ARBOR_WINDOWS_PID"
check "the view has not moved" camera_on "$W1"
check "the framed window still fills the screen" fills "$W1"

claim "drag the summoned window, click another window: it goes; summoned again, it comes back to where it was put"
proves A53
check "⌃⌥\` reaches Arbor" summon_key
check "the other app's window is in view" eventually in_view "$V1"
take "x y" titlebar_of "$V1"
drag "$x" "$y" "$((x - 90))" "$((y + 70))" --no-release
check "no drop preview shows" fails has_overlay 3
release
check "it is still summoned" eventually role_is "$V1" summoned
place=$(real_frame_of "$V1")
click_window "$W1"
check "the clicked window has the keyboard" eventually is focused "$W1"
check "the summoned window is out of view" eventually out_of_view "$V1"
check "the view has not moved" camera_on "$W1"
check "⌃⌥\` reaches Arbor" summon_key
# shellcheck disable=SC2086
check "it is where it was put" eventually is_at "$V1" $place
check "it has the keyboard" eventually is focused "$V1"

claim "a window sent away stays out of view where the Desktop shows, and ⌃⌥0 brings it home as an ordinary window"
proves A53
check "⌃⌥\` reaches Arbor" summon_key
check "it is out of view" eventually out_of_view "$V1"
ctl show-all
check "the camera is on everything" eventually camera_on root
check "it is still out of view" stays out_of_view "$V1"
check "⌃⌥\` brings it over this view too" summon_key
# shellcheck disable=SC2086
check "where it was put" eventually is_at "$V1" $place
check "⌃⌥\` sends it away" summon_key
check "it is out of view" eventually out_of_view "$V1"
check "⌃⌥0 reaches Arbor" pressed ctrl+opt+0 home
check "it is in view" eventually in_view "$V1"
check "Arbor no longer keeps it away" fails role_is "$V1" stashed
check "it floats" is floating "$V1"
settled

claim "quit Arbor and start it again: the summoned window still comes to where it was put"
proves A53
arbor_quit
check "quitting leaves it in view" eventually in_view "$V1"
arbor_relaunch
click_window "$W1"
check "⌃⌥↩ reaches Arbor" pressed ctrl+opt+return zoom
check "the first window fills the screen" eventually fills "$W1"
check "the other app's window is out of view" eventually out_of_view "$V1"
check "⌃⌥\` reaches Arbor" summon_key
# shellcheck disable=SC2086
check "it is where it was put before" eventually is_at "$V1" $place
check "it has the keyboard" eventually is focused "$V1"
check "the view has not moved" camera_on "$W1"

claim "with summonStays a click on another window leaves the summoned window in view until it is summoned away; the clicked window lies over it, and Arbor says so"
proves A53
arbor_settings "{\"bindings\": {\"ctrl+opt+\`\": \"summon $ARBOR_TEST_BUNDLE_2\"}, \"summonStays\": true}"
ctl reload-settings
click_window "$W1"
check "the clicked window has the keyboard" eventually is focused "$W1"
check "the summoned window is still summoned" stays role_is "$V1" summoned
# shellcheck disable=SC2086
check "where it was" is_at "$V1" $place
check "the window that was clicked lies over it" eventually fails uncovered "$V1"
check "state says covered" eventually is covered "$V1"
check "⌃⌥\` reaches Arbor" summon_key
check "it is out of view" eventually out_of_view "$V1"
check "the keyboard stays where it was" is focused "$W1"
arbor_settings "{\"bindings\": {\"ctrl+opt+\`\": \"summon $ARBOR_TEST_BUNDLE_2\"}}"
ctl reload-settings

claim "summon an app whose windows are docked, by command: the view goes to the one used last, which stays in its slot"
proves A53
ctl desktop
check "the docked windows are out of view" eventually out_of_view "$W1"
check "summon says that it is docked" docked_says
check "the window used last is in view" eventually in_view "$W1"
check "in its slot" eventually in_slot "$W1"
check "it has the keyboard" eventually is focused "$W1"
check "both are still docked" count docked 2
settled

claim "summon an app that is not installed, by command: Arbor says so and nothing moves"
proves A53
# A name that is nobody's bundle id, no running app's name and no app's file name, so there is nothing that it could open.
check "it fails" exits_with 1 arborctl summon dev.arbor.no-such-app
check "and says why" says "no app called" arborctl summon dev.arbor.no-such-app
check "the window in view is still in view" in_view "$W1"
ctl home
settled
arbor_stop
