#!/bin/bash
# ⌃⌥N: the field a space's name is typed into, with real keys and clicks, and where a name given there shows afterwards.
# The field is the one panel of Arbor's, with the palette of Go to…, that takes the keyboard, and it does so without Arbor
# becoming the app in front: who gets each letter, and who has the keyboard afterwards, is what only real windows can tell.
# A22 ⌃⌥N: a field to type a space's name into, A20 named spaces: name a space, go to it by name,
# A21 a name stays with its windows.
source "$(dirname "$0")/../lib.sh"
arbor_build

# The field is the only one of Arbor's windows at the level of a modal panel.
field_open() { has_overlay 8 || { echo "Arbor shows no field"; return 1; }; }
field_closed() { fails has_overlay 8 || { echo "the field is on screen, at $(overlay_frame 8)"; return 1; }; }
# `spaces` has a line for each name, which begins with it.
named() { "$ARBOR_BIN/arborctl" spaces | grep "^$1 " > /dev/null || { echo "no space is called $1"; return 1; }; }
named_in_view() { "$ARBOR_BIN/arborctl" spaces | grep "^$1 .*in view" > /dev/null || { echo "no space in view is called $1"; return 1; }; }
no_names() { says "no space has a name yet" arborctl spaces; }
running() { "$ARBOR_BIN/arborctl" status | grep "^running" > /dev/null || { echo "Arbor is not running"; return 1; }; }
paused() { "$ARBOR_BIN/arborctl" status | grep "^paused" > /dev/null || { echo "Arbor is not paused"; return 1; }; }
marked() { [ "$(pointer menu-mark "$ARBOR_PID" "$1")" = "$2" ] || { echo "its mark is $(pointer menu-mark "$ARBOR_PID" "$1" 2>&1)"; return 1; }; }
types() {
  local one
  for one in "$@"; do key "$one" || return 1; done
}
# In the upper middle of the display: as far from its left edge as from its right, all of it in the upper half, below the menu bar.
field_in_the_upper_middle() {
  local screen shown
  screen=$(screen_of 1) || return 1
  shown=$(overlay_frame 8) || { echo "Arbor shows no field"; return 1; }
  echo "$screen $shown" | awk '
    function near(a, b) { return a - b <= 3 && b - a <= 3 }
    near($5 + $7 / 2, $1 + $3 / 2) && $6 >= $2 && $6 + $8 <= $2 + $4 / 2 { found = 1 }
    END { exit !found }' && return 0
  echo "the field is at $shown, the screen is $screen"
  return 1
}
# beside_the_field <id>: a point in that window's content which the field does not cover. `click_window` looks at ordinary windows only.
beside_the_field() {
  local frame shown
  frame=$(real_frame_of "$1") || return 1
  shown=$(overlay_frame 8) || return 1
  echo "$frame $shown" | awk '
    function clear(x, y) { return x < $5 - 10 || x > $5 + $7 + 10 || y < $6 - 10 || y > $6 + $8 + 10 }
    function try(x, y) { if (!found && clear(x, y)) { print int(x), int(y); found = 1 } }
    { try($1 + $3 / 2, $2 + $4 - 40); try($1 + 40, $2 + $4 - 40); try($1 + $3 - 40, $2 + $4 - 40); try($1 + 40, $2 + 60) }
    END { exit !found }'
}
# at <click|move> <command…>: there, if that command names a place. With no field up it names none, which is the claim's failure and not the script's end.
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
# in_slot is about where a window is, in_view about how much of it shows: a slot of this view is all on the screen.
column_shows() { in_slot "$W2" && in_slot "$V1" && in_view "$V1" && out_of_view "$W1"; }
# The column of the second window and the other app's fills the view, the second window has the keyboard and no field is open.
start_over() {
  running > /dev/null || ctl resume
  field_closed > /dev/null || ctl ask-name cancel
  ctl zoom "$W2"
  ctl out
  eventually column_shows > /dev/null
  click_window "$W2"
}

ARBOR_SECOND_APP=1
# In the Dock and in ⌘Tab, like a person's apps, which only the claim about ⌘Tab needs. Not on a person's Mac, whose Dock would grow.
if on_throwaway_mac; then
  ARBOR_TEST_WINDOWS_ARGS="--regular"
  ARBOR_SECOND_APP_ARGS="--regular"
fi
arbor_start 2 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
# The first window | the Desktop | the second window above the other app's.
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$V1" beside "$W2" bottom
summary

start_over
claim "⌃⌥N, a name, ↩: a field in the upper middle takes the typing and the space in view has the name; the app behind stays in front, sees no letter and has the keyboard again"
proves A22 A20
check "the second window has the keyboard" eventually is focused "$W2"
keys=$(events_of "$W2" key)
check "⌃⌥N reaches Arbor" pressed ctrl+opt+n ask-name
check "the field is on screen" eventually field_open
check "in the upper middle of the display" field_in_the_upper_middle
check "the app in front stays in front" front_is "$ARBOR_WINDOWS_PID"
check "its window is still the focused window" is focused "$W2"
check "no window moved for it" column_shows
types shift+p a i r
check "nothing has a name before ↩" no_names
key return
check "↩ closes the field" eventually field_closed
check "the space in view has the name, capital and all" eventually named_in_view Pair
check "the app behind saw none of it" received "$W2" key -eq "$keys"
check "it is still in front" front_is "$ARBOR_WINDOWS_PID"
check "the next letter goes to its window, without a click" reaches "$W2" x
check "the name is not in the log" fails grep -q Pair "$ARBOR_HOME/arbor.log"
check "no window moved" column_shows
settled

start_over
claim "⌃⌥N on a space that has a name, other letters, ⎋: the field closes, the name stays and the app has the keyboard again"
proves A22
keys=$(events_of "$W2" key)
check "⌃⌥N reaches Arbor" pressed ctrl+opt+n ask-name
check "the field is on screen" eventually field_open
types d u o
key escape
check "⎋ closes the field" eventually field_closed
check "the name is as it was" named_in_view Pair
check "nothing is called what was typed" fails named duo
check "the app behind saw none of it" received "$W2" key -eq "$keys"
check "the next letter goes to its window, without a click" reaches "$W2" x

start_over
claim "type a direction for a name and press ↩: it is refused, the field stays open and takes a better name"
proves A22
check "⌃⌥N reaches Arbor" pressed ctrl+opt+n ask-name
check "the field is on screen" eventually field_open
# What is typed replaces the name the field opens with, which is selected.
types u p
key return
check "the field stays" stays field_open
check "nothing is called up" fails named up
check "the name is as it was" named_in_view Pair
types p e r
key return
check "↩ closes the field now" eventually field_closed
check "the space is renamed to all that was typed" eventually named_in_view upper
check "the old name is gone" fails named Pair

start_over
claim "⌃⌥N with the field open closes it, and changes nothing"
proves A22
check "⌃⌥N reaches Arbor" pressed ctrl+opt+n ask-name
check "the field is on screen" eventually field_open
types x
check "⌃⌥N again reaches Arbor, not the field" pressed ctrl+opt+n ask-name
check "the field is gone" eventually field_closed
check "the name is as it was" named_in_view upper
check "the next letter goes to the app's window" reaches "$W2" x

start_over
claim "click another window with the field open: the field closes, nothing is named and the click reaches the window"
proves A22
check "⌃⌥N reaches Arbor" pressed ctrl+opt+n ask-name
check "the field is on screen" eventually field_open
types x
downs=$(events_of "$V1" down)
at click beside_the_field "$V1"
check "the field is gone" eventually field_closed
check "the clicked window got the press" eventually received "$V1" down -gt "$downs"
check "and has the keyboard" eventually is focused "$V1"
check "the name is as it was" named_in_view upper
check "nothing is called what was typed" fails named x
check "the view stayed" column_shows

start_over
claim "another app comes forward by itself with the field open: the field closes, and typing goes to that app"
proves A22
check "⌃⌥N reaches Arbor" pressed ctrl+opt+n ask-name
check "the field is on screen" eventually field_open
tw2 activate "$V1"
check "the other app is in front" eventually front_is "$ARBOR_WINDOWS_PID_2"
check "the field is gone" eventually field_closed
check "the next letter goes to the other app's window" reaches "$V1" x
check "the name is as it was" named_in_view upper

# On a person's Mac ⌘Tab leads to whichever app of theirs was in front last.
if on_throwaway_mac; then
  click_window "$V1"
  start_over
  claim "⌘Tab with the field open: the field closes, and typing goes to the app that came forward"
  proves A22
  check "the first app is in front" eventually front_is "$ARBOR_WINDOWS_PID"
  check "⌃⌥N reaches Arbor" pressed ctrl+opt+n ask-name
  check "the field is on screen" eventually field_open
  key cmd+tab
  check "⌘Tab switched to the other app" eventually front_is "$ARBOR_WINDOWS_PID_2"
  check "the field is gone" eventually field_closed
  check "the next letter goes to the other app's window" reaches "$V1" x
  check "the name is as it was" named_in_view upper
fi

start_over
claim "⌃⌥↑ with the field open: the view leaves the space and the field goes with it"
proves A22
check "⌃⌥N reaches Arbor" pressed ctrl+opt+n ask-name
check "the field is on screen" eventually field_open
check "⌃⌥↑ reaches Arbor, not the field" pressed ctrl+opt+up out
check "everything is in view" eventually in_view "$W1"
check "the field is gone" eventually field_closed
check "and stays away" stays field_closed
check "the space keeps its name" named upper
settled

start_over
claim "⌃⌥⎋ with the field open: Arbor pauses and the field closes, and resuming does not bring it back"
proves A22
check "⌃⌥N reaches Arbor" pressed ctrl+opt+n ask-name
check "the field is on screen" eventually field_open
key ctrl+opt+escape
check "Arbor is paused" eventually paused
check "the field is gone" eventually field_closed
key ctrl+opt+escape
check "Arbor runs again" eventually running
check "the field stays away" stays field_closed
check "the name outlived the pause" named upper

start_over
claim "choose the named space under Saved Views in the menu: it is ticked while in view, and from elsewhere the view goes there"
proves A20
open_menu
check "the menu has Saved Views" eventually pointer menu-item "$ARBOR_PID" "Saved Views"
# shellcheck disable=SC2046
click $(pointer menu-item "$ARBOR_PID" "Saved Views")
check "its submenu lists the name" eventually pointer menu-item "$ARBOR_PID" upper
check "ticked, because that space is in view" marked upper "✓"
key escape
# Should ⎋ have closed the submenu alone.
if has_overlay 101; then key escape; fi
ctl zoom "$W1"
check "from the first window's view the column is out of view" eventually out_of_view "$V1"
check "the row can be clicked" click_menu "Saved Views" upper
check "Arbor went there, and its log has the command without the name" eventually logged "go ‹name›: moved to ‹name›"
check "the column fills the view" eventually column_shows
check "spaces says that it is in view" named_in_view upper
settled

start_over
claim "choose Name This Space… from the menu: the field opens with the keyboard, and emptied, ↩ takes the name off"
proves A22
check "the row can be clicked" click_menu "Saved Views" "Name This Space"
check "Arbor ran ask-name" eventually ran ask-name
check "the field is on screen" eventually field_open
check "the app in front stays in front" front_is "$ARBOR_WINDOWS_PID"
keys=$(events_of "$W2" key)
# The name it opens with is selected, so one ⌫ empties the field.
key delete
key return
check "↩ closes the field" eventually field_closed
check "no space has a name any more" eventually no_names
check "the app behind saw neither key" received "$W2" key -eq "$keys"
check "the next letter goes to its window, without a click" reaches "$W2" x

start_over
claim "name a space, go to it by the beginning of its name and take the name off, by command"
proves A20
check "name succeeds" ctl name Reading Room
check "the space in view has the name" named_in_view "Reading Room"
check "no window moved" column_shows
ctl zoom "$W1"
check "from the first window's view the column is out of view" eventually out_of_view "$W2"
check "go finds it by its first letters, whatever their case" says "moved to Reading Room" arborctl go read
check "the column fills the view" eventually column_shows
check "⌃⌥[ reaches Arbor" pressed "ctrl+opt+[" back
check "and leads back to the first window" eventually fills "$W1"
check "a name nobody has is refused" fails ctl go kitchen
check "the view stayed" stays fills "$W1"
check "unname needs the whole name" fails ctl unname read
check "and takes it off from anywhere" ctl unname reading room
check "no space has a name any more" no_names
settled

start_over
claim "quit Arbor and start it again: the space has its name back, and go leads to the same windows"
proves A21
check "⌃⌥N reaches Arbor" pressed ctrl+opt+n ask-name
check "the field is on screen" eventually field_open
types shift+p a i r
key return
check "the space in view has the name" eventually named_in_view Pair
arbor_quit
arbor_relaunch
check "the name is there again" eventually named Pair
ctl zoom "$W1"
check "from the first window's view the column is out of view" eventually out_of_view "$V1"
check "go succeeds" ctl go pair
check "the column fills the view" eventually column_shows
settled

arbor_stop
