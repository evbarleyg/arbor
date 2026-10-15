#!/bin/bash
# Go to… always closes. A palette left floating over everything, deaf, is the one failure the feature must not have, so here it is
# left in every way a person leaves it: its own shortcut, a click on a window and on a gap handle, another shortcut, a pause, an
# app that comes forward, ⌘Tab. Each time it goes, and the keyboard is where the person went.
# 46-goto.sh has what is typed and chosen in it. A section of its own, because each has a time limit.
# A27 Go to…: find any window, named space or saved view by typing.
source "$(dirname "$0")/../lib.sh"
arbor_build

# The palette's level is floating (3) plus 2. The minimap and the panel of shortcuts share it; neither is asked for in here.
palette_open() { has_overlay 5 || { echo "Arbor shows no palette"; return 1; }; }
palette_closed() { fails has_overlay 5 || { echo "the palette is on screen, at $(overlay_frame 5)"; return 1; }; }
running() { "$ARBOR_BIN/arborctl" status | grep "^running" > /dev/null || { echo "Arbor is not running"; return 1; }; }
paused() { "$ARBOR_BIN/arborctl" status | grep "^paused" > /dev/null || { echo "Arbor is not paused"; return 1; }; }
# beside_the_palette <id>: a point in that window's content which the palette does not cover. `click_window` looks at ordinary windows only.
beside_the_palette() {
  local frame shown
  frame=$(real_frame_of "$1") || return 1
  shown=$(overlay_frame 5) || return 1
  echo "$frame $shown" | awk '
    function clear(x, y) { return x < $5 - 10 || x > $5 + $7 + 10 || y < $6 - 10 || y > $6 + $8 + 10 }
    function try(x, y) { if (!found && clear(x, y)) { print int(x), int(y); found = 1 } }
    { try($1 + 40, $2 + $4 - 40); try($1 + $3 - 40, $2 + $4 - 40); try($1 + 40, $2 + 60); try($1 + $3 - 40, $2 + 60) }
    END { exit !found }'
}
# at <click|move> <command…>: there, if that command names a place. With no palette up it names none, which is the claim's failure and not the script's end.
at() {
  local verb=$1 point
  shift
  point=$("$@") || { check "there is a place to $verb at" false; return 1; }
  # shellcheck disable=SC2086
  "$verb" $point
}
# reaches <id> <key>: a key pressed now arrives in that window, with no click before it.
reaches() {
  local keys
  keys=$(events_of "$1" key) || return 1
  key_to "$1" "$2" || return 1
  eventually received "$1" key -gt "$keys"
}
# The shortcut made Arbor run the command, and the window server shows the palette.
opens_the_palette() { pressed ctrl+opt+g find && eventually palette_open; }
visit() { click_window "$1" && eventually is focused "$1" > /dev/null; }
only_the_first_shows() { fills "$W1" && out_of_view "$W2"; }
everything_shows() { camera_on root && layout_matches && in_view "$W1" && in_view "$W3"; }
# Any command but a query closes a palette that was left open, which is one claim's failure and should not be the next one's.
show_everything() {
  running > /dev/null || ctl resume
  ctl show-all
  eventually everything_shows > /dev/null
  visit "$W1"
}
frame_the_first() {
  show_everything
  ctl zoom "$W1"
  eventually only_the_first_shows > /dev/null
  visit "$W1"
}

ARBOR_SECOND_APP=1
# In the Dock and in ⌘Tab, like a person's apps, which only the claim about ⌘Tab needs. Not on a person's Mac, whose Dock would grow.
if on_throwaway_mac; then
  ARBOR_TEST_WINDOWS_ARGS="--regular"
  ARBOR_SECOND_APP_ARGS="--regular"
fi
arbor_start 4 ARBOR_NO_HOTKEYS=0
# The first window above the other app's | the Desktop, where the fourth floats | the second above the third.
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W2" bottom
ctl dock "$V1" beside "$W1" bottom
summary

frame_the_first
claim "⌃⌥G with the palette open closes it, and changes nothing"
proves A27
check "⌃⌥G opens the palette" opens_the_palette
key 3
keys=$(events_of "$W1" key)
# Arbor logs nothing when the palette is put away, so what shows is all there is to go by.
key ctrl+opt+g
check "⌃⌥G again closes the palette" eventually palette_closed
check "and it stays away: the key did not open another" stays palette_closed
check "the window behind did not see the key" received "$W1" key -eq "$keys"
check "the view has not moved" only_the_first_shows
check "the next letter goes to the window" reaches "$W1" x

show_everything
claim "click another window with the palette open: the palette closes and the click reaches the window"
proves A27
check "⌃⌥G opens the palette" opens_the_palette
downs=$(events_of "$W3" down)
at click beside_the_palette "$W3"
check "the palette is gone" eventually palette_closed
check "the clicked window got the press" eventually received "$W3" down -gt "$downs"
check "and has the keyboard" eventually is focused "$W3"
check "nothing moved" everything_shows

visit "$W1"
claim "click a gap handle with the palette open: the palette closes, though the handle takes no keyboard"
proves A27
check "⌃⌥G opens the palette" opens_the_palette
# The gap under the first window, near its left end: clear of the palette.
take "x y w h" real_frame_of "$W1"
click "$((x + 30))" "$((y + h + ARBOR_GAP / 2))"
check "the palette is gone" eventually palette_closed
check "and stays away" stays palette_closed
check "the next letter goes to the window that had the keyboard" reaches "$W1" x
settled

frame_the_first
claim "another shortcut of Arbor's with the palette open: the palette closes and the shortcut does its work"
proves A27
check "⌃⌥G opens the palette" opens_the_palette
check "⌃⌥↑ reaches Arbor, not the palette" pressed ctrl+opt+up out
check "the palette is gone" eventually palette_closed
check "the view stepped out to the column" eventually in_view "$V1"
check "and no further" out_of_view "$W2"
settled

frame_the_first
claim "⌃⌥⎋ with the palette open: Arbor pauses and the palette closes, and resuming does not bring it back"
proves A27
check "⌃⌥G opens the palette" opens_the_palette
key ctrl+opt+escape
check "Arbor is paused" eventually paused
check "the palette is gone" eventually palette_closed
key ctrl+opt+escape
check "Arbor runs again" eventually running
check "the palette stays away" stays palette_closed

show_everything
claim "another app comes forward by itself with the palette open: the palette closes, and typing goes to that app"
proves A27
check "⌃⌥G opens the palette" opens_the_palette
tw2 activate "$V1"
check "the other app is in front" eventually front_is "$ARBOR_WINDOWS_PID_2"
check "the palette is gone" eventually palette_closed
check "the next letter goes to the other app's window" reaches "$V1" x

show_everything
claim "⌃⌥G while a window is held by its title bar: no palette opens until the window is let go"
proves A27
take "x y" desktop_point
drag_window "$W4" "$((x + 40))" "$((y + 40))" --no-release
key ctrl+opt+g
check "no palette shows while the button is down" stays palette_closed
release
check "with the button up ⌃⌥G opens the palette" opens_the_palette
key escape
check "⎋ closes it" eventually palette_closed

# On a person's Mac ⌘Tab leads to whichever app of theirs was in front last.
if on_throwaway_mac; then
  visit "$V1"
  visit "$W1"
  claim "⌘Tab with the palette open: the palette closes, and typing goes to the app that came forward"
  proves A27
  check "the first app is in front" eventually front_is "$ARBOR_WINDOWS_PID"
  check "⌃⌥G opens the palette" opens_the_palette
  key cmd+tab
  check "⌘Tab switched to the other app" eventually front_is "$ARBOR_WINDOWS_PID_2"
  check "the palette is gone" eventually palette_closed
  check "the next letter goes to the other app's window" reaches "$V1" x
fi

ctl show-all
arbor_stop
