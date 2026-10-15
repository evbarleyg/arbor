#!/bin/bash
# The menu's first rows in every state a hosted Mac can be put into, a picture of each, and where in the picture the words begin, for
# whoever measures them (scripts/polish/stills.py read <picture> x,y,w,16). docs/MENU.md, "States".
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-menu-states.sh
#
# THE QUESTIONS ONLY A MAC CAN ANSWER:
#   1. A state that a command ends is one row that can be chosen. Is it drawn at full strength, as any other row that can be?
#   2. With a mistake in settings.json the rows that change a setting cannot be chosen. Do they look it, under a first row that does not?
#   3. News cannot be chosen, and its title has a color of its own (`StatusMenu.news`). Does macOS draw it at full strength all the same?
# Measured on a hosted Mac before: words that are greyed out 1.85 to 1, a row that can be chosen 13.3 to 1.
#
# Not here: the menu without the permission (shots-F10.sh has it), and "Arbor is starting…", which is over before a click gets there.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "click in the menu bar, and pause and hold an Arbor"

# MenuModel.Metrics.macOS26, by hand, as in check-menu-height.sh, whose helpers these are.
row=24 separator=11 heading=24 padding=5

menu_ids() { overlays | awk '$3 == 101 && $8 == "on" { print $1 }'; }
menu_is_open() { [ -n "$(menu_ids)" ]; }
menu_is_closed() { ! menu_is_open; }
frame_of_menu() { overlays | awk -v id="$1" '$1 == id { print $4, $5, $6, $7; found = 1 } END { exit !found }'; }
close_menu() {
  local tries
  for tries in 1 2 3; do
    menu_is_open || return 0
    key escape
    sleep 0.3
  done
  eventually menu_is_closed
}
item_is_at_rest() {
  local before
  before=$(status_item) && [ -n "$before" ] || return 1
  sleep 0.5
  [ "$before" = "$(status_item)" ]
}
# Sets MENU_TEXT, MENU_ID and mx my mw mh: so never under `check`, which runs what it checks in a shell of its own.
open_menu() {
  MENU_TEXT=$("$ARBOR_BIN/arborctl" menu)
  eventually item_is_at_rest
  # shellcheck disable=SC2046
  rightclick $(status_item)
  eventually menu_is_open || return 1
  MENU_ID=$(menu_ids | head -n 1)
  read -r mx my mw mh <<< "$(frame_of_menu "$MENU_ID")"
}
# row_at <title>: x y, the middle of the row of the open menu whose title starts so.
row_at() {
  echo "$MENU_TEXT" | awk -v title="$1" -v x="$mx" -v y="$my" -v w="$mw" -v row="$row" -v separator="$separator" \
    -v heading="$heading" -v padding="$padding" '
    BEGIN { at = y + padding }
    { sub(/^  ✓ /, "    ") }
    /^-----/ { at += separator; next }
    /^[^ ]/ { at += heading + (NR > 1 ? separator : 0); next }
    /^    [^ ]/ && !/^    -----/ {
      if (index($0, "    " title) == 1) { printf "%d %d\n", x + w / 2, at + row / 2; found = 1; exit }
      at += row
    }
    END { exit !found }'
}

# picture <name> <title>…: opens the menu, takes its picture, and says where the words of those rows begin. Leaves it open.
picture() {
  local name=$1 title at
  shift
  open_menu
  check "$name: the menu opens" menu_is_open || return 1
  echo "$name: the menu is at $mx $my, $mw wide and $mh high. Its first rows, as the model has them:"
  echo "$MENU_TEXT" | head -n 3
  shot "$name"
  look "$name-own" "$MENU_ID"
  for title in "$@"; do
    at=$(row_at "$title") || { check "$name: $title is a row of the menu" false; continue; }
    # The words begin some 23 points in, and a row's are 16 high in its 24.
    echo "$name: MEASURE $name.png $((mx + 23)),$((${at#* } - 8)),$((mw - 60)),16   $title"
  done
}
# submenu <name> <title>: with the menu open, rests on that row, and takes a picture of what opens.
submenu() {
  local at id
  at=$(row_at "$2") || { check "$2 is a row of the menu" false; return 1; }
  # shellcheck disable=SC2086
  move $at
  sleep 1
  id=$(menu_ids | grep -v "^$MENU_ID\$" | head -n 1)
  check "$2 opens a submenu" test -n "$id"
  echo "$1: the submenu of $2 is at $(frame_of_menu "$id") (x y w h); rows of 24 from 5 below its top, words 23 in"
  shot "$1"
}
says_menu() { "$ARBOR_BIN/arborctl" menu | grep -q "$1"; }
# first_row <words>: the menu's first line, as the model has it, holds them.
first_row() { "$ARBOR_BIN/arborctl" menu | head -n 1 | grep -q "$1"; }
# can_be_chosen <words> / greyed_out <words>: of the one line of the model's menu that holds them.
can_be_chosen() { "$ARBOR_BIN/arborctl" menu | grep "$1" | head -n 1 | grep -vq "(gray)"; }
greyed_out() { "$ARBOR_BIN/arborctl" menu | grep "$1" | head -n 1 | grep -q "(gray)"; }
break_the_file() {
  cp "$ARBOR_HOME/settings.json" "$ARBOR_HOME/settings.good"
  printf '{ "gap": 8,\n  oops\n}\n' > "$ARBOR_HOME/settings.json"
  ctl reload-settings
  check "the menu says that settings.json has a mistake" eventually says_menu "Settings.json has a mistake"
}
mend_the_file() {
  cp "$ARBOR_HOME/settings.good" "$ARBOR_HOME/settings.json"
  ctl reload-settings
}

arbor_build
# The look a Mac comes with: the runners come with Reduce Transparency on. Apps read it as they start.
macos_reduce_transparency off
arbor_start 3 ARBOR_NO_STATUS_ITEM=0 ARBOR_NO_HOTKEYS=0
# A test window has the keyboard, so that the menu speaks of that app.
# shellcheck disable=SC2046
click $(center_of "$W1")
ctl dock "$W1" left
ctl dock "$W2" right

step "an ordinary day: what a row that can be chosen looks like, and one that cannot"
picture 10-ordinary "Pause Arbor" "Quit Arbor"
close_menu

step "the view is held"
ctl hold
check "the first row says so and can be chosen" eventually can_be_chosen "The view is held"
picture 20-held "The view is held"
close_menu
ctl release

step "holding still"
ctl hold still
check "the first row says so and can be chosen" eventually can_be_chosen "Holding still"
picture 21-holding-still "Holding still"
close_menu
ctl release

step "paused"
ctl pause
check "the first row says so and can be chosen" eventually can_be_chosen "Arbor is paused"
picture 30-paused "Arbor is paused"
close_menu
ctl resume

step "shortcuts are off in this app"
ctl pass-through "$ARBOR_TEST_BUNDLE" on
check "the first row says so and can be chosen" eventually can_be_chosen "Shortcuts are off in"
picture 40-shortcuts-off "Shortcuts are off in"
close_menu

step "and settings.json has a mistake: the file's row first, and Turn On, which changes a setting, greyed out under it"
"$ARBOR_BIN/arborctl" exclude com.example.somebodyelse > /dev/null
break_the_file
check "the file's row is the first" eventually first_row "Settings.json has a mistake"
check "and can be chosen" can_be_chosen "Settings.json has a mistake"
check "Turn On cannot" greyed_out "Shortcuts are off in"
picture 50-mistake-and-shortcuts-off "Settings.json has a mistake" "Shortcuts are off in"
check "Don’t Arrange cannot be chosen" greyed_out "Don’t Arrange “"
check "nor Shortcuts Off in" greyed_out "Shortcuts Off in “"
submenu 51-mistake-focused-window "Focused Window"
check "nor Dock New Windows" greyed_out "Dock New Windows"
check "nor the app under Arrange Again" greyed_out "   somebodyelse"
check "Reload Settings can" can_be_chosen "Reload Settings"
submenu 52-mistake-arrangement "Arrangement"
close_menu
mend_the_file
check "with the file mended Turn On is the first row again" eventually first_row "Shortcuts are off in"
check "and can be chosen" can_be_chosen "Shortcuts are off in"
ctl pass-through "$ARBOR_TEST_BUNDLE" off

step "news that no command ends: the saved arrangement could not be read"
arbor_quit
printf 'this is no arrangement\n' > "$ARBOR_HOME/state.json"
arbor_relaunch
# "(news)" with the news rows' change, "(gray)" without it: the picture is wanted either way, one is the other's control.
check "the menu's first row cannot be chosen" eventually first_row "(news)\|(gray)"
echo "60-news: the model marks it $("$ARBOR_BIN/arborctl" menu | head -n 1 | grep -o "(news)\|(gray)")"
NEWS=$("$ARBOR_BIN/arborctl" menu | head -n 1 | sed 's/^ *//; s/  (.*//' | cut -c1-24)
picture 60-news "$NEWS"
close_menu

arbor_stop 70-the-end
