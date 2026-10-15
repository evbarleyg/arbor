#!/bin/bash
# A window's own size: the one it had before Arbor stretched it, the one Arbor believes it cannot go below, and the one it
# gives up for a while when it floats alone.
# A48 a window that leaves the arrangement gets its own size back, A16 what Arbor learns about a window's size can be
# unlearned, T21 a single floating window fills the Desktop.
source "$(dirname "$0")/../lib.sh"
arbor_build
# Where macOS tiles at the screen's edges they are macOS's, and what is docked there below is docked by command.
if screen_edges_dock; then edges=ours; else edges=""; fi

# has_size <id> <w> <h> | is_at <id> <x> <y> <w> <h>: by the window server, which also answers while Arbor is not running.
has_size() { width_is "$1" "$2" && height_is "$1" "$3"; }
is_at() {
  local id=$1
  shift
  arbor_close "$(real_frame_of "$id")" "$*" || { echo "it is at $(real_frame_of "$id"), not at $*"; return 1; }
}
# Arbor has heard of a move that the app made itself. What it gives back to a window is what it last saw of it.
seen_where_it_is() { arbor_close "$(frame_of "$1")" "$(real_frame_of "$1")"; }
# grip <id>: dx dy w: the pointer from the window's corner, and the window's width, by the window server.
grip() {
  local place frame
  place=$(pointer where) && frame=$(real_frame_of "$1") || { echo "no answer from the pointer tool"; return 1; }
  # shellcheck disable=SC2086
  set -- $place $frame
  [ $# -eq 7 ] || { echo "the pointer is at $place, the window at $frame"; return 1; }
  echo "$((${1%.*} - ${4%.*})) $((${2%.*} - ${5%.*})) ${6%.*}"
}
# keeps_grip <id> <dx> <dy> <w>: the pointer is as far down the window, and as far along its width, as it was then. A window trails
# a posted pointer (docs/TESTING.md), so where the pointer was on it with the button still down is measured, not assumed.
keeps_grip() {
  local id=$1 dx=$2 dy=$3 w=$4 now
  now=$(grip "$id") || { echo "$now"; return 1; }
  # shellcheck disable=SC2086
  set -- $now
  about "$2" "$dy" 3 > /dev/null && about "$(($1 * 100 / $3))" "$((dx * 100 / w))" 2 > /dev/null \
    || { echo "it was held $dx $dy from the corner of a window $w wide; now the pointer is $1 $2 from the corner of one $3 wide"; return 1; }
}
# The window server has the window where Arbor's layout has the Desktop.
takes_desktop() {
  local desktop
  desktop=$(arbor_ask desktop) || { echo "$desktop"; return 1; }
  # shellcheck disable=SC2086
  is_at "$1" $desktop
}

ARBOR_SECOND_APP=1
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
# The test windows all open at one size. The first gets one of its own, so that no other window's can be taken for it.
all_w=$(width_of "$W2")
all_h=$(height_of "$W2")
own_w=$((all_w - 80))
own_h=$((all_h - 50))
take "x y _ _" real_frame_of "$W1"
tw move "$W1" "$x" "$y" "$own_w" "$own_h"
eventually seen_where_it_is "$W1"
ctl dock "$W1" left
ctl dock "$W2" right
summary

claim "⌃⌥F on a docked window: it floats at the size it had before it was docked"
proves A48
check "docked, it is taller than it was" eventually taller_than "$W1" "$((own_h + 40))"
click_window "$W1"
check "⌃⌥F reaches Arbor" pressed ctrl+opt+f toggle-float
check "the window floats" eventually is floating "$W1"
check "it has its own size again" eventually has_size "$W1" "$own_w" "$own_h"
check "all of it is in view" in_view "$W1"
check "Arbor leaves it that size" stays has_size "$W1" "$own_w" "$own_h"
check "the other docked window is in its slot" eventually in_slot "$W2"
settled

claim "⌃⌥F on the window the camera frames: its own size again, in a view that shows the Desktop"
proves A48
ctl dock "$W1" left
ctl zoom "$W1"
check "framed, it fills the screen" eventually fills "$W1"
check "the floating windows left with the Desktop" eventually out_of_view "$W3"
check "⌃⌥F reaches Arbor" pressed ctrl+opt+f toggle-float
check "the window floats" eventually is floating "$W1"
check "it has its own size again" eventually has_size "$W1" "$own_w" "$own_h"
check "all of it is in view" in_view "$W1"
check "the Desktop is in view" eventually desktop_point
check "and the windows that float on it" eventually in_view "$W3"
settled

claim "drag a docked window out of its slot and drop it on the Desktop: it shrinks back to its own size under the pointer"
proves A48
ctl dock "$W1" left
check "docked, it is taller than it was" eventually taller_than "$W1" "$((own_h + 40))"
# shellcheck disable=SC2046
drag_window "$W1" $(desktop_point) --no-release
take "dx dy w" grip "$W1"
release
# From further down than a title bar reaches (`Controller.titleBarReach`) the window comes up to the pointer.
[ "$dy" -gt 60 ] && dy=60
check "the window floats" eventually is floating "$W1"
check "it has its own size again" eventually has_size "$W1" "$own_w" "$own_h"
check "the pointer is where it was on the window" eventually keeps_grip "$W1" "$dx" "$dy" "$w"
check "the layout that follows the drop leaves it there" stays keeps_grip "$W1" "$dx" "$dy" "$w"
settled

step "where every window is before Arbor arranges them all"
ctl float-all
first=$(real_frame_of "$W1")
second=$(real_frame_of "$W2")
third=$(real_frame_of "$W3")
other=$(real_frame_of "$V1")
echo "$first | $second | $third | $other"
# everything_is_back: four checks, for the claims that end with "as it was".
everything_is_back() {
  # shellcheck disable=SC2086
  check "the first window is exactly where it was, at its own size" eventually is_at "$W1" $first
  # shellcheck disable=SC2086
  check "the second" eventually is_at "$W2" $second
  # shellcheck disable=SC2086
  check "the third" eventually is_at "$W3" $third
  # shellcheck disable=SC2086
  check "the other app's" eventually is_at "$V1" $other
}

claim "⌃⌥A arranges every window, ⌃⌥⇧F floats them all: each is back exactly where it was"
proves A48
click_window "$W2"
check "⌃⌥A reaches Arbor" pressed ctrl+opt+a arrange
check "all four are docked" eventually count docked 4
# shellcheck disable=SC2086
check "the first window has left its place" eventually fails is_at "$W1" $first
check "⌃⌥↩ frames the focused window" pressed ctrl+opt+return zoom
check "⌃⌥⇧F reaches Arbor" pressed ctrl+opt+shift+f float-all
check "nothing is docked" eventually count docked 0
everything_is_back

claim "choose Arrange Windows and then Float All Windows from the menu: each window is back exactly where it was"
proves A48
check "Arrange Windows can be clicked" click_menu "Arrange Windows"
check "all four are docked" eventually count docked 4
# shellcheck disable=SC2086
check "the other app's window has left its place" eventually fails is_at "$V1" $other
check "Float All Windows can be clicked" click_menu "Float All Windows"
check "nothing is docked" eventually count docked 0
everything_is_back

claim "choose Don’t Arrange for an app whose window is docked: the window goes back to where it was"
proves A48
ctl dock "$W1" left
ctl dock "$V1" right
check "docked, it reaches the right edge of the screen" eventually at_edge "$V1" right
click_window "$V1"
check "the item can be clicked" click_menu "Don’t Arrange"
check "Arbor ran exclude" eventually ran exclude "$ARBOR_TEST_BUNDLE_2"
check "Arbor no longer arranges it" eventually fails is managed "$V1"
# shellcheck disable=SC2086
check "it is exactly where it was, at its own size" eventually is_at "$V1" $other
ctl include "$ARBOR_TEST_BUNDLE_2"
ctl float-all

claim "choose Quit Arbor with every window docked and one framed: each is back exactly where it was"
proves A48
ctl arrange
ctl zoom "$W3"
check "the framed window fills the screen" eventually fills "$W3"
check "the others are out of view" eventually out_of_view "$W1"
check "the item can be clicked" click_menu "Quit Arbor"
check "Arbor exits" arbor_await_exit "$ARBOR_PID" 50
arbor_ended
everything_is_back

claim "start Arbor again: the windows dock again, and ⌃⌥F still gives one its own size"
proves A48
arbor_relaunch
check "all four are docked again" eventually count docked 4
ctl show-all
click_window "$W2"
check "⌃⌥F reaches Arbor" pressed ctrl+opt+f toggle-float
check "the window floats" eventually is floating "$W2"
check "it has its own size" eventually has_size "$W2" "$all_w" "$all_h"
settled
arbor_stop

# A good second instead of ten minutes. Without makeRoom: on a large screen Arbor would move the gaps instead of
# showing a tile (60-tiles.sh).
arbor_settings '{"makeRoom": false, "tileRetryMinutes": 0.02}'
ARBOR_SECOND_APP=0
arbor_start 3 ARBOR_NO_HOTKEYS=0
take "_ _ screen_w screen_h" screen_of 1
ctl dock "$W1" left
ctl dock "$W2" beside "$W1" bottom
# Seven tenths of the screen each way: too big for a quarter of it, small enough to be framed on its own.
tw min-size "$W2" "$((screen_w * 7 / 10))" "$((screen_h * 7 / 10))"
ctl zoom "$W2"
ctl back
first=$(real_frame_of "$W1")
summary

claim "a window that goes on refusing its slot is asked again out of view: it stays a tile, and nothing else moves"
proves A16
check "a tile stands in for it" eventually is tile "$W2"
check "the window itself is out of view" eventually out_of_view "$W2"
sleep 2
click_window "$W1"
check "⌃⌥0, which lays the screen out again" pressed ctrl+opt+0 home
check "Arbor asked it again" eventually logged "still refuses the size of its slot"
check "it is still a tile" is tile "$W2"
check "and out of view" out_of_view "$W2"
# shellcheck disable=SC2086
check "the window above it has not moved" is_at "$W1" $first
settled

claim "its app allows a smaller size: after tileRetryMinutes the next layout makes the tile a window in its slot again"
proves A16
tw min-size "$W2" 200 150
sleep 2
check "time alone changes nothing" is tile "$W2"
check "⌃⌥0, which lays the screen out again" pressed ctrl+opt+0 home
check "no tile stands in for it" eventually fails is tile "$W2"
check "it is in its slot" eventually in_slot "$W2"
check "in view" in_view "$W2"
check "below the first window" above "$W1" "$W2"
# shellcheck disable=SC2086
check "which has not moved" is_at "$W1" $first
check "nothing overlaps" no_overlaps
settled

claim "relayout by command asks at once: a tile whose app has relented is a window again without waiting"
proves A16
# Never by itself, so that what brings the window back can only be the command.
arbor_settings '{"makeRoom": false, "tileRetryMinutes": 0}'
ctl reload-settings
tw min-size "$W2" "$((screen_w * 7 / 10))" "$((screen_h * 7 / 10))"
ctl zoom "$W2"
ctl back
check "a tile stands in for it again" eventually is tile "$W2"
tw min-size "$W2" 200 150
sleep 2
check "⌃⌥0, which lays the screen out again" pressed ctrl+opt+0 home
check "it stays a tile" stays is tile "$W2"
check "relayout succeeds" ctl relayout
check "no tile stands in for it" eventually fails is tile "$W2"
check "it is in its slot" eventually in_slot "$W2"
check "nothing overlaps" no_overlaps
settled
arbor_stop

arbor_settings '{"soleFloatTakesDesktop": true}'
arbor_start 3 ARBOR_NO_HOTKEYS=0
own_w=$all_w
own_h=$all_h

claim "dock every window but one: the one that floats alone takes the Desktop"
proves T21
# shellcheck disable=SC2046
if [ -n "$edges" ]; then drag_window "$W1" $(edge_point left); else ctl dock "$W1" left; fi
check "the first window is docked" eventually is docked "$W1"
check "with another floating beside it, the third keeps its size" stays has_size "$W3" "$own_w" "$own_h"
# shellcheck disable=SC2046
drag_window "$W2" $(zone_of "$W1" bottom)
check "the second window is docked" eventually is docked "$W2"
check "alone, the third has the Desktop's place and size" eventually takes_desktop "$W3"
check "it reaches the right edge of the screen" at_edge "$W3" right
check "it still floats" is floating "$W3"
check "nothing overlaps" no_overlaps
settled

claim "drag the gap beside the Desktop: the window that fills it follows"
proves T21
width=$(width_of "$W3")
docked_width=$(width_of "$W1")
take "x y" seam_right_of "$W1"
drag "$x" "$y" "$((x - 80))" "$y"
check "the docked window is narrower" eventually narrower_than "$W1" "$((docked_width - 40))"
check "the window is wider" eventually wider_than "$W3" "$((width + 40))"
check "it has the Desktop's place and size" eventually takes_desktop "$W3"
settled

claim "frame a docked window and come back: the window that fills the Desktop leaves and returns with it"
proves T21
click_window "$W1"
check "⌃⌥↩ reaches Arbor" pressed ctrl+opt+return zoom
check "the docked window fills the screen" eventually fills "$W1"
check "the floating one is out of view" eventually out_of_view "$W3"
check "⌃⌥0 reaches Arbor" pressed ctrl+opt+0 home
check "it has the Desktop's place and size again" eventually takes_desktop "$W3"
settled

claim "⌃⌥F gives it company: it has its own size back, and takes the Desktop again once it is alone"
proves T21
click_window "$W2"
check "⌃⌥F reaches Arbor" pressed ctrl+opt+f toggle-float
check "the second window floats" eventually is floating "$W2"
check "the third has its own size back" eventually has_size "$W3" "$own_w" "$own_h"
check "the second has its own too" eventually has_size "$W2" "$own_w" "$own_h"
# shellcheck disable=SC2046
drag_window "$W2" $(zone_of "$W1" bottom)
check "the second window is docked again" eventually is docked "$W2"
check "the third has the Desktop's place and size again" eventually takes_desktop "$W3"
settled

claim "drag the window that fills the Desktop by its title bar: its own size under the pointer, and it stays that size"
proves T21
take "x y" titlebar_of "$W3"
drag "$x" "$y" "$((x - 30))" "$((y + 80))" --no-release
take "dx dy w" grip "$W3"
release
check "it has its own size back" eventually has_size "$W3" "$own_w" "$own_h"
check "the pointer is where it was on the window" eventually keeps_grip "$W3" "$dx" "$dy" "$w"
check "it still floats" is floating "$W3"
check "⌃⌥0, which lays the screen out again" pressed ctrl+opt+0 home
check "the hand wins: it keeps that size" stays has_size "$W3" "$own_w" "$own_h"
settled

claim "switch soleFloatTakesDesktop off in settings.json: the window has its own size back"
proves T21
# Docked and floated again, which is a new beginning after the drag.
ctl dock "$W3" right
ctl float "$W3"
check "it has the Desktop's place and size" eventually takes_desktop "$W3"
arbor_settings '{"soleFloatTakesDesktop": false}'
ctl reload-settings
check "it has its own size back" eventually has_size "$W3" "$own_w" "$own_h"
settled

claim "quit Arbor while a window fills the Desktop: it has its own size back"
proves T21
arbor_settings '{"soleFloatTakesDesktop": true}'
ctl reload-settings
check "it has the Desktop's place and size" eventually takes_desktop "$W3"
arbor_quit
check "it has its own size back" eventually has_size "$W3" "$own_w" "$own_h"
check "all of it is in view" in_view "$W3"
