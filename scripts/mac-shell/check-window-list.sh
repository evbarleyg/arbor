#!/bin/bash
# The menu lists every open window (docs/MENU.md, Windows ▸), on real windows of two apps, with a real pointer:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-window-list.sh
#
# THE QUESTIONS ONLY A MAC CAN ANSWER:
# - what do the rows look like: the app's icon at 16 points, the title, the tick, the mark at the right end (the pictures)? Is a row with an icon
#   and a mark as high as any other (24 points)?
# - a real click on a row of each kind (docked in view, docked out of view, a tile, floating behind another window, floating over the
#   screen's corner, minimized, hidden with its app): is the window then the frontmost by the window server's own order, wholly on the
#   display, and does its app have the keyboard? A menu's tracking has only just ended when Arbor asks for the keyboard.
# - does a window in the Dock, or one hidden with its app, take a frame where nobody sees it, and come back there?
# - no title in arbor.log or in the trace.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "click in the menu bar and choose rows of Arbor's menu"

# This script's windows, from the frontmost to the one at the back, as the window server has them.
mine() { echo " $W1 $W2 $W3 $W4 $W5 $V1 $V2 "; }
front_window() { "$ARBOR_POINTER" windows --on-screen | awk -v mine="$(mine)" 'index(mine, " " $1 " ") { print $1; exit }'; }
in_front() {
  local front
  front=$(front_window)
  [ "$front" = "$1" ] || { echo "the frontmost of the windows is $front, not $1"; return 1; }
}
# All of it is on a display, and between the menu bar and the Dock: as they are, or as they were when Arbor was asked ($ROOM_WHEN_ASKED).
ROOM_WHEN_ASKED=""
whole() {
  local room=${ROOM_WHEN_ASKED:-$(screen_of 1)}
  [ "$("$ARBOR_POINTER" visible "$1")" = "1.00" ] || { echo "$("$ARBOR_POINTER" visible "$1") of it is on a display"; return 1; }
  inside "$(real_frame_of "$1")" "$room" || { echo "it is at $(real_frame_of "$1"), the screen is $room"; return 1; }
}
# How many points of it lie lower than the room above the Dock.
below_the_room() {
  local wy wh sy sh _x _w
  read -r _x wy _w wh <<< "$(real_frame_of "$1")"
  read -r _x sy _w sh <<< "$(screen_of 1)"
  echo $((${wy%.*} + ${wh%.*} - ${sy%.*} - ${sh%.*}))
}
row_of() { "$ARBOR_BIN/arborctl" menu | grep -F -e "$1"; }
# As the menu has it: without the tick before it and the mark after it.
title_of() { row_of "$1" | head -n 1 | sed 's/^[ ✓]*//; s/  \[.*//'; }
# click_row <word of its title>: opens the menu, then the list, and clicks the row.
click_row() { click_menu "Windows" "$(title_of "$1")"; }
row_says() { row_of "$1" | grep -q -F -e "[$2]" || { echo "its row reads: $(row_of "$1")"; return 1; }; }
row_has_no_mark() {
  row_of "$1" > /dev/null || { echo "no row reads $1"; return 1; }
  ! row_of "$1" | grep -q -F -e "[" || { echo "it reads: $(row_of "$1")"; return 1; }
}
row_is_cut() { row_of "$1" | grep -q -F -e "…"; }
row_is_ticked() { row_of "$1" | grep -q "✓"; }
first_row_is() { "$ARBOR_BIN/arborctl" menu | grep -A 1 "^    Windows ▸" | tail -n 1 | grep -q -F -e "$1"; }
menu_ids() { overlays | awk '$3 == 101 && $8 == "on" { print $1 }'; }

# fetched <id> <pid> <title>: after a click on its row.
fetched() {
  check "Arbor ran reveal for it" eventually ran reveal "$1"
  check "it is in view" eventually in_view "$1"
  check "all of it is on the screen" eventually whole "$1"
  check "it is the frontmost window" eventually in_front "$1"
  check "its app is in front" eventually front_is "$2"
  check "it has the keyboard" eventually is focused "$1"
  check "its row has no mark" eventually row_has_no_mark "$3"
  check "its row is ticked" eventually row_is_ticked "$3"
  check "and is the first of the list" eventually first_row_is "$3"
}

arbor_build
ARBOR_SECOND_APP=2
arbor_settings "{$ARBOR_TILES_ON}"
arbor_start 5 ARBOR_NO_STATUS_ITEM=0 ARBOR_NO_HOTKEYS=0
# Titles that occur nowhere else, to look for afterwards in what people pass on.
tw title "$W1" zqxalpha report
tw title "$W2" zqxbravo inbox
tw title "$W3" zqxcharlie notes
tw title "$W4" zqxdelta shell
tw title "$W5" zqxecho a title that goes on and on, far beyond what the row of a menu has room for
tw2 title "$V1" zqxfoxtrot chat
tw2 title "$V2" zqxgolf music
ctl trace on window-list
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W2" bottom
click_window "$W1"

claim "the menu's second row opens a list of every open window, by app and title"
proves A240
for title in zqxalpha zqxbravo zqxcharlie zqxdelta zqxecho zqxfoxtrot zqxgolf; do
  check "$title is in the list" eventually row_of "$title"
done
check "the window with the keyboard is ticked" eventually row_is_ticked zqxalpha
check "and first" first_row_is zqxalpha
check "with everything in view no row has a mark" row_has_no_mark zqx
check "a long title is cut" eventually row_is_cut zqxecho
open_menu
sleep 0.4
check "the menu has a row Windows" eventually pointer menu-item "$ARBOR_PID" "Windows"
# shellcheck disable=SC2046
move $(pointer menu-item "$ARBOR_PID" "Windows")
sleep 1
check "resting on it opens the list" test "$(menu_ids | wc -l | tr -d ' ')" = 2
echo "Arbor's menus (id pid level x y w h on owner):"
overlays | awk '$3 == 101'
# Seven rows of 24 points and 5 above and below: an icon or a mark that made a row higher would show here.
check "seven rows with icons are 178 points high" test "$(overlays | awk '$3 == 101 && $8 == "on" { print $7 }' | sort -n | head -n 1)" = 178
shot 10-everything-in-view
for id in $(menu_ids); do look "11-menu-$id" "$id"; done
key escape
key escape

claim "what cannot be seen says why at the end of its row"
proves A240
ctl zoom "$W1"
tw minimize "$W4"
tw2 hide
check "a docked window out of view: out of view" eventually row_says zqxbravo "out of view"
check "a window in the Dock: minimized" eventually row_says zqxdelta "minimized"
check "a window of a hidden app: hidden" eventually row_says zqxfoxtrot "hidden"
check "the framed window: nothing" row_has_no_mark zqxalpha
open_menu
sleep 0.4
# shellcheck disable=SC2046
move $(pointer menu-item "$ARBOR_PID" "Windows")
sleep 1
check "marks make no row higher" test "$(overlays | awk '$3 == 101 && $8 == "on" { print $7 }' | sort -n | head -n 1)" = 178
shot 20-with-marks
for id in $(menu_ids); do look "21-menu-$id" "$id"; done
key escape
key escape

claim "click a docked window that is out of view: in front and whole"
proves A240
check "it is out of view" eventually out_of_view "$W2"
check "its row can be clicked" click_row zqxbravo
fetched "$W2" "$ARBOR_WINDOWS_PID" zqxbravo
settled
shot 30-docked-out-of-view

claim "click a window in the Dock: in front and whole"
proves A240
check "its row can be clicked" click_row zqxdelta
fetched "$W4" "$ARBOR_WINDOWS_PID" zqxdelta
shot 31-minimized

claim "click a window of a hidden app: in front and whole"
proves A240
check "its row can be clicked" click_row zqxfoxtrot
fetched "$V1" "$ARBOR_WINDOWS_PID_2" zqxfoxtrot
shot 32-hidden

claim "click a docked window in view that lies under a floating one: in front, and nothing moves"
proves A240
ctl show-all
take "x y w h" frame_of "$W3"
tw move "$W5" "$((x + 20))" "$((y + 20))" 300 200
click_window "$W5"
before=$(real_frame_of "$W3")
check "its row can be clicked" click_row zqxcharlie
fetched "$W3" "$ARBOR_WINDOWS_PID" zqxcharlie
check "it has not moved" test "$(real_frame_of "$W3")" = "$before"
settled

claim "click a floating window that lies behind another: in front, where it was"
proves A240
take "x y w h" screen_of 1
tw move "$W5" "$((x + w / 2 - 150))" "$((y + h / 2 - 100))" 300 200
tw move "$W4" "$((x + w / 2 - 200))" "$((y + h / 2 - 150))" 400 300
click_window "$W4"
before=$(real_frame_of "$W5")
check "its row can be clicked" click_row zqxecho
fetched "$W5" "$ARBOR_WINDOWS_PID" zqxecho
check "it has not moved" test "$(real_frame_of "$W5")" = "$before"

claim "click a floating window that hangs over the corner of the screen: it comes in whole, at its own size"
proves A240
tw move "$W5" "$((x + w - 60))" "$((y + h - 60))" 300 200
click_window "$W1"
echo "it hangs at $(real_frame_of "$W5"); $("$ARBOR_POINTER" visible "$W5") of it is on the display"
check "it hangs over the corner" fails whole "$W5"
check "its row says out of view" eventually row_says zqxecho "out of view"
shot 40-over-the-corner
check "its row can be clicked" click_row zqxecho
fetched "$W5" "$ARBOR_WINDOWS_PID" zqxecho
check "it is as wide as it was" width_is "$W5" 300
check "and as high" height_is "$W5" 200
shot 41-whole

claim "the same out of the Dock: it comes back whole"
proves A240
tw move "$W5" "$((x + w - 60))" "$((y + h - 60))" 300 200
check "it hangs over the corner" eventually fails whole "$W5"
tw minimize "$W5"
click_window "$W1"
check "it is in the Dock" eventually is minimized "$W5"
# A Dock that fills a small display is lower while it holds one thing more, and grows again as the window leaves it: 2 points on a hosted Mac,
# where this check failed at its first run (docs/REALITY.md, the-dock-resizes-and-the-visible-frame-with-it). Arbor moves the window once,
# where nobody sees it, so whole is what is whole when it is asked. In the picture nothing covers it: the room ends above the Dock.
sleep 1
ROOM_WHEN_ASKED=$(screen_of 1)
check "its row can be clicked" click_row zqxecho
fetched "$W5" "$ARBOR_WINDOWS_PID" zqxecho
sleep 1
echo "asked with the screen at $ROOM_WHEN_ASKED; it is $(screen_of 1) now, and the window at $(real_frame_of "$W5")"
ROOM_WHEN_ASKED=""
check "the Dock, as it grows again, takes no more than 4 points of it" test "$(below_the_room "$W5")" -le 4
check "it is as wide as it was" width_is "$W5" 300
shot 42-out-of-the-dock

claim "the same of a hidden app: it comes back whole"
proves A240
tw2 move "$V2" "$((x - 240))" "$((y + 100))" 300 200
echo "it hangs at $(real_frame_of "$V2")"
check "it hangs over the left edge" eventually fails whole "$V2"
tw2 hide
click_window "$W1"
check "it is hidden" eventually is hidden "$V2"
check "its row can be clicked" click_row zqxgolf
fetched "$V2" "$ARBOR_WINDOWS_PID_2" zqxgolf
check "it is as wide as it was" width_is "$V2" 300

claim "click a window too small to show, which is a tile: in front and whole"
proves A240
tw min-size "$W4" 900 600
ctl dock "$W4" beside "$W3" bottom
click_window "$W1"
check "it is a tile" eventually is tile "$W4"
check "its row says out of view" eventually row_says zqxdelta "out of view"
shot 50-a-tile
check "its row can be clicked" click_row zqxdelta
fetched "$W4" "$ARBOR_WINDOWS_PID" zqxdelta
shot 51-the-tile-fetched

claim "titles are shown and never passed on"
proves A240
ctl show-all
ctl trace off
cp "$ARBOR_HOME"/traces/*.jsonl "$ARBOR_OUT/" 2> /dev/null
check "the clicks are in arbor.log" grep -q "reveal $W2" "$ARBOR_HOME/arbor.log"
check "no title is" fails grep -i -q zqx "$ARBOR_HOME/arbor.log"
check "the clicks are in the trace" grep -q -r "reveal $W2" "$ARBOR_HOME/traces"
check "no title is" fails grep -i -q -r zqx "$ARBOR_HOME/traces"
check "state knows the window" says "$W2" "$ARBOR_BIN/arborctl" state
check "and not its title" fails says zqx "$ARBOR_BIN/arborctl" state

arbor_stop 90-after
