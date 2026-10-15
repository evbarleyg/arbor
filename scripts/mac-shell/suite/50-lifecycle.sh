#!/bin/bash
# What windows do on their own account: minimize, hide, close, open, and the kinds Arbor leaves alone.
# T06 a leaving window's space goes to the row, T07 minimized (and hidden) windows come back to their spot,
# T64 only standard windows are arranged, A45 a new window stays with the view it opened over,
# A76 no dialog opens out of view.
source "$(dirname "$0")/../lib.sh"
arbor_build
ARBOR_SECOND_APP=1
# ⌘H is for an ordinary app, with an icon in the Dock: one without did nothing for it on a real Mac. A person's Dock stays as it is,
# and there the app hides itself.
if on_throwaway_mac; then ARBOR_SECOND_APP_ARGS="--regular"; fi
hide_other_app() { if on_throwaway_mac; then key_to "$V1" cmd+h; else tw2 hide; fi; }
# Four columns on a 1024-point screen are 241 points each, a point above where slots become tiles.
arbor_settings '{"minimumUsableWidth": 200}'
arbor_start 4
# Each at the left edge of the view, so that all share the row evenly: the first, the second, the other app's, the Desktop.
ctl dock "$V1" left
ctl dock "$W2" left
ctl dock "$W1" left
summary
width=$(width_of "$W1")

claim "minimize a docked window with its yellow button: the neighbours take its space"
proves T07
click_button "$W2" minimize
check "Arbor sees it minimized" eventually is minimized "$W2"
check "it is still docked" is docked "$W2"
check "the window on its left grew" eventually wider_than "$W1" "$((width + 40))"
check "the window on its right moved up to it" eventually left_of "$W1" "$V1"
check "nothing overlaps" eventually no_overlaps
settled

claim "restore the minimized window: it returns to its slot between the same neighbours"
proves T07
tw restore "$W2"
check "Arbor sees it restored" eventually fails is minimized "$W2"
check "it is in its slot" eventually in_slot "$W2"
check "right of the first" eventually left_of "$W1" "$W2"
check "left of the third" eventually left_of "$W2" "$V1"
check "the first has its old width" eventually width_is "$W1" "$width"
check "the camera stayed on everything" camera_on root
settled

claim "⌘M minimizes the focused docked window, and it comes back the same way"
proves T07
ctl show-all
click_window "$W2"
key_to "$W2" cmd+m
check "Arbor sees it minimized" eventually is minimized "$W2"
check "the window on its left grew" eventually wider_than "$W1" "$((width + 40))"
tw restore "$W2"
check "it is back in its slot" eventually in_slot "$W2"
check "the first has its old width" eventually width_is "$W1" "$width"
settled

claim "hide an app with ⌘H: its docked window's space goes to the neighbours"
proves T07
ctl show-all
click_window "$V1"
check "the other app's window has the keyboard" eventually is focused "$V1"
hide_other_app
check "macOS hides the app" eventually out_of_view "$V1"
check "Arbor sees its window hidden" eventually is hidden "$V1"
check "it is still docked" is docked "$V1"
check "the windows of the first app grew" eventually wider_than "$W1" "$((width + 40))"
settled

claim "show the hidden app again: its window returns to its slot"
proves T07
tw2 unhide
check "Arbor sees it shown" eventually fails is hidden "$V1"
check "it is in its slot" eventually in_slot "$V1"
check "right of the second" eventually left_of "$W2" "$V1"
check "the first has its old width" eventually width_is "$W1" "$width"
settled

claim "close a docked window with its red button: the row shares its space"
proves T06
ctl show-all
click_button "$W2" close
forget_window "$W2"
check "Arbor has forgotten it" eventually fails is known "$W2"
check "two are docked" eventually count docked 2
check "the window on its left grew" eventually wider_than "$W1" "$((width + 40))"
check "the window on its right is beside it now" eventually left_of "$W1" "$V1"
check "the two have the same width" eventually width_is "$V1" "$(width_of "$W1")"
settled

claim "close the window the camera frames with ⌘W: the camera steps out to what is left"
ctl zoom "$V1"
check "the window fills the screen" eventually fills "$V1"
check "the other is out of view" eventually out_of_view "$W1"
key_to "$V1" cmd+w
forget_window "$V1"
check "Arbor has forgotten it" eventually fails is known "$V1"
check "the other window is back in view" eventually in_view "$W1"
settled

claim "a window opened while Arbor runs floats where its app put it"
take "x y" desktop_point
open_window N1 size=300x200 "at=$((x - 150)),$((y - 100))" title=A new window
check "Arbor arranges it" eventually is managed "$N1"
check "it floats" is floating "$N1"
check "it is where its app put it" stays corner_is "$N1" "$((x - 150))" "$((y - 100))"

claim "panels and sheets are left alone"
proves T64
open_window P1 kind=panel size=220x160 "at=$((x - 110)),$((y - 290))" title=A panel
echo "Accessibility calls the panel: $(pointer ax "$P1" 2>&1)"
open_window S1 "kind=sheet:$N1" size=200x100 title=A sheet
panel=$(real_frame_of "$P1")
check "Arbor does not list the panel" stays fails is known "$P1"
check "nor the sheet" fails is known "$S1"
sheet=$(real_frame_of "$S1")
ctl arrange
# shellcheck disable=SC2086
check "arranging everything leaves the panel where it was" stays frame_is "$P1" $panel
# shellcheck disable=SC2086
check "the sheet moved along with its window" eventually fails frame_is "$S1" $sheet
forget_window "$P1"
forget_window "$S1"
settled

claim "a window that opens while one window is framed stays with that view"
proves A45
ctl zoom "$W1"
check "the framed window fills the screen" eventually fills "$W1"
take "x y" center_of "$W1"
open_window G1 size=320x220 "at=$((x - 160)),$((y - 110))" title=A guest
check "it floats" eventually is floating "$G1"
check "over the framed window, where its app put it" stays corner_is "$G1" "$((x - 160))" "$((y - 110))"
ctl neighbor right
check "the view moves on and it goes out of view" eventually out_of_view "$G1"
ctl back
check "the view comes back" eventually fills "$W1"
check "and the window with it, in the same place" eventually corner_is "$G1" "$((x - 160))" "$((y - 110))"

claim "a dialog of a window that is out of view opens in the middle of the screen"
proves A76
check "the window it belongs to is out of view" eventually out_of_view "$W3"
open_dialog D1 "$W3"
check "the dialog is in view" eventually in_view "$D1"
tw close "$D1"
forget_window "$D1"
ctl show-all
settled

arbor_stop
