#!/bin/bash
# ⌃⌥G, Go to…: the palette that finds any window, named space or saved view by typing, with real keys and clicks. It takes the
# keyboard without Arbor becoming the app in front: who gets each key, who has the keyboard afterwards, and which row ↩, ↓, ⌘2 and a
# click choose is what only real windows can tell. 46-goto-places.sh goes to whatever keeps a window out of view,
# 46-goto-closes.sh leaves the palette in every other way: three sections, because each has a time limit.
# A27 Go to…: find any window, named space or saved view by typing.
source "$(dirname "$0")/../lib.sh"
arbor_build

# The palette's level is floating (3) plus 2. The minimap and the panel of shortcuts share it; neither is asked for in here.
palette_open() { has_overlay 5 || { echo "Arbor shows no palette"; return 1; }; }
palette_closed() { fails has_overlay 5 || { echo "the palette is on screen, at $(overlay_frame 5)"; return 1; }; }
types() {
  local one
  for one in "$@"; do key "$one" || return 1; done
}
# As far from the display's left edge as from its right, and its top a quarter of the way down what the menu bar and the Dock leave. On a
# display too low for the longest list below that (464 points with the margin: FinderLayout) it begins higher.
palette_in_its_place() {
  local screen shown
  screen=$(screen_of 1) || return 1
  shown=$(overlay_frame 5) || { echo "Arbor shows no palette"; return 1; }
  echo "$screen $shown" | awk '
    function near(a, b) { return a - b <= 3 && b - a <= 3 }
    near($5 + $7 / 2, $1 + $3 / 2) && (near($6, $2 + $4 / 4) || ($6 >= $2 && $6 < $2 + $4 / 4 && $4 * 3 / 4 < 464)) { found = 1 }
    END { exit !found }' && return 0
  echo "the palette is at $shown, the screen is $screen"
  return 1
}
# The list under the field grows and shrinks with what matches, and the palette with it.
palette_height() { overlay_frame 5 | awk '{ print int($4) }'; }
palette_is_lower_than() { arbor_compare high "$(palette_height)" -lt "$1"; }
palette_is_high() { arbor_compare high "$(palette_height)" -eq "$1"; }
# palette_row <n>: the middle of that row, from FinderLayout: a band of 56 for the field, 8 of padding, rows of 38.
palette_row() {
  local shown
  shown=$(overlay_frame 5) || return 1
  echo "$shown" | awk -v row="$1" '{ print int($1 + $3 / 2), int($2 + 56 + 8 + 38 * (row - 1) + 19) }'
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
# A click, and Arbor has heard that the window has the keyboard: the list goes by who had it last.
visit() { click_window "$1" && eventually is focused "$1" > /dev/null; }
# only_shows <id>: it fills the screen, and another window is out of view.
only_shows() {
  local other=$W1
  [ "$1" = "$W1" ] && other=$W2
  fills "$1" && out_of_view "$other"
}
everything_shows() { camera_on root && layout_matches && in_view "$W1" && in_view "$W3"; }
# Any command but a query closes a palette that was left open, which is one claim's failure and should not be the next one's.
show_everything() {
  ctl show-all
  eventually everything_shows > /dev/null
}
# The first window framed and with the keyboard.
frame_the_first() {
  show_everything
  ctl zoom "$W1"
  eventually only_shows "$W1" > /dev/null
  visit "$W1"
}

ARBOR_SECOND_APP=1
# With an icon in the Dock and a name in the menu bar, like a person's apps. Not on a person's Mac, whose Dock would grow.
if on_throwaway_mac; then
  ARBOR_TEST_WINDOWS_ARGS="--regular"
  ARBOR_SECOND_APP_ARGS="--regular"
fi
# The first window above the other app's | the Desktop, where the fourth floats | the second above the third.
arbor_start 4 ARBOR_NO_HOTKEYS=0
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W2" bottom
ctl dock "$V1" beside "$W1" bottom
# The first app's windows are called Arbor Test and a number. A word for the other app's, whose name ends in a digit.
tw2 title "$V1" Ledger
summary

frame_the_first
claim "⌃⌥G while typing in a window, letters, ⎋: the palette comes a quarter of the way down and takes the letters, the app stays in front, and after ⎋ typing goes on in the window"
proves A27
check "what is typed reaches the window" reaches "$W1" a
keys=$(events_of "$W1" key)
check "⌃⌥G reaches Arbor" pressed ctrl+opt+g find
check "the palette is on screen" eventually palette_open
check "in the middle, a quarter of the way down" palette_in_its_place
check "the app in front stays in front" front_is "$ARBOR_WINDOWS_PID"
check "its window is still the focused window" is focused "$W1"
tall=$(palette_height)
types l e d g e r
check "the list shrinks to what the letters match" eventually palette_is_lower_than "$tall"
check "the palette's top stays where it was" palette_in_its_place
check "the window saw none of the letters" received "$W1" key -eq "$keys"
key escape
check "⎋ closes the palette" eventually palette_closed
check "the window did not see that either" received "$W1" key -eq "$keys"
check "the view has not moved" only_shows "$W1"
check "the app is still in front" front_is "$ARBOR_WINDOWS_PID"
check "the next letter goes to the window, without a click" reaches "$W1" b
settled

frame_the_first
claim "⌃⌥G, a part of a title, ↩: the window found is framed as the one before was and has the keyboard, and the pointer stays where it is"
proves A27
keys=$(events_of "$W1" key)
where=$(pointer where)
check "⌃⌥G opens the palette" opens_the_palette
types 3
key return
check "↩ closes the palette" eventually palette_closed
check "the window found fills the screen, alone" eventually only_shows "$W3"
check "Arbor says that it is focused" eventually is focused "$W3"
check "the next letter goes to it, without a click" reaches "$W3" x
check "the window left behind saw none of the typing" received "$W1" key -eq "$keys"
check "the pointer has not moved" test "$(pointer where)" = "$where"
check "⌃⌥[ reaches Arbor" pressed "ctrl+opt+[" back
check "and leads back to the window before" eventually only_shows "$W1"
settled

show_everything
visit "$W2"
visit "$V1"
visit "$W1"
claim "⌃⌥G and ↩ at once: the keyboard goes to the window used before this one, another app's; again, and it comes back; with ↓, to the one before that"
proves A27
check "⌃⌥G opens the palette" opens_the_palette
key return
check "the window used before has the keyboard" eventually is focused "$V1"
check "its app is in front" eventually front_is "$ARBOR_WINDOWS_PID_2"
check "the palette is gone" eventually palette_closed
check "⌃⌥G opens the palette from the other app too" opens_the_palette
check "the other app stays in front" front_is "$ARBOR_WINDOWS_PID_2"
key return
check "the keyboard is back in the first window" eventually is focused "$W1"
check "its app is in front" eventually front_is "$ARBOR_WINDOWS_PID"
check "⌃⌥G opens the palette once more" opens_the_palette
types down
key return
check "the second row is the window used before those two" eventually is focused "$W2"
check "the palette is gone" eventually palette_closed
check "all were in view, so nothing moved" everything_shows

show_everything
# Most recently used first, the focused window after the others: the second, the other app's, the third, then the first.
visit "$W3"
visit "$V1"
visit "$W2"
visit "$W1"
claim "⌘2 in the palette goes to the second row's window, a click on a row to that row's, and pointing at a row chooses nothing"
proves A27
check "⌃⌥G opens the palette" opens_the_palette
key cmd+2
check "⌘2 closes the palette" eventually palette_closed
check "the second row's window has the keyboard" eventually is focused "$V1"
# Now the first, the second, the third, then the other app's.
check "⌃⌥G opens the palette" opens_the_palette
at click palette_row 3
check "the click closes the palette" eventually palette_closed
check "the third row's window has the keyboard" eventually is focused "$W3"
# Now the other app's, the first, the second, then the third.
check "⌃⌥G opens the palette" opens_the_palette
at move palette_row 2
check "the palette stays open under the pointer" stays palette_open
key return
check "↩ goes to the first row's window, not to the one pointed at" eventually is focused "$V1"
check "the palette is gone" eventually palette_closed

show_everything
# All five have had the keyboard now: the second, the other app's, the third, the fourth, then the first, which has it.
visit "$W4"
visit "$W3"
visit "$V1"
visit "$W2"
visit "$W1"
claim "↑ in the palette goes round from the first row to the last, and ⇥ and ⇧⇥ step as ↓ and ↑ do"
proves A27
check "⌃⌥G opens the palette" opens_the_palette
types up up
key return
check "two rows up from the first is the last but one" eventually is focused "$W4"
check "the palette is gone" eventually palette_closed
# Now the first, the second, the other app's, the third, then the fourth.
check "⌃⌥G opens the palette" opens_the_palette
types tab tab shift+tab
key return
check "two steps on and one back is the second row" eventually is focused "$W2"
check "the palette is gone" eventually palette_closed
check "all were in view, so nothing moved" everything_shows

frame_the_first
claim "type what nothing matches and press ↩: the palette stays open and nothing moves; ⌫ brings the list back"
proves A27
check "⌃⌥G opens the palette" opens_the_palette
tall=$(palette_height)
types z z
check "the list is gone" eventually palette_is_lower_than "$tall"
key return
check "the palette stays" stays palette_open
check "the view has not moved" only_shows "$W1"
types delete delete
check "the whole list is back" eventually palette_is_high "$tall"
key escape
check "⎋ closes the palette" eventually palette_closed

ctl show-all
arbor_stop
