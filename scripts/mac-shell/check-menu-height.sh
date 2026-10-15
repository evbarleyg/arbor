#!/bin/bash
# The menu on a small display (docs/MENU.md, rule 3): how high macOS makes it in each state, held against what the headless model
# says (`MenuModel.height`, which `MenuHeightTests` bounds on Linux), with a picture of each, and a real click on each of the ways
# out: Show Everything, Float All Windows, Pause Arbor, Quit Arbor, and Release and Resume, which take their places.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-menu-height.sh scripts/mac-shell/shots-F10.sh
#
# shots-F10.sh has the menu of an Arbor without the permission. An update that waits changes one title in Help and no height.
#
# THE QUESTION ONLY A MAC CAN ANSWER: are a row, a separator and the room above and below as high as the model takes them to be? Rows are
# found by those sizes and nothing else, so a click lands on its row only if they are right.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "click in the menu bar, and quit, pause and hold an Arbor from its menu"

# MenuModel.Metrics.macOS26, by hand: whoever changes them there changes them here, or the clicks below miss.
row=24 separator=11 heading=24 padding=5

# The ids of Arbor's open menus: windows at level 101, and Arbor's own on macOS 26 too (shots-F10.sh's pictures of them show it). A
# submenu is a window of its own.
menu_ids() { overlays | awk '$3 == 101 && $8 == "on" { print $1 }'; }
menu_is_open() { [ -n "$(menu_ids)" ]; }
menu_is_closed() { ! menu_is_open; }
# x y w h of the window with that id.
frame_of_menu() { overlays | awk -v id="$1" '$1 == id { print $4, $5, $6, $7; found = 1 } END { exit !found }'; }
# With a submenu open the first Escape may close only that.
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
  before=$(status_item)
  sleep 0.5
  [ "$before" = "$(status_item)" ]
}

# open_menu: asks the model first (an open menu may keep Arbor from answering), then opens the menu as a right click does whatever the
# item shows. Sets MENU_TEXT, MENU_SAYS (points), MENU_ID and mx my mw mh: so never under `check`, which runs what it checks in a shell of
# its own.
open_menu() {
  MENU_TEXT=$("$ARBOR_BIN/arborctl" menu)
  MENU_SAYS=$("$ARBOR_BIN/arborctl" --json menu | sed -n 's/.* \([0-9][0-9]*\) points high.*/\1/p')
  # The item is as wide as what it shows, and a hold or a pause changes that: for a moment macOS still says where it was, and a click
  # there opened nothing (the first run on a Mac).
  eventually item_is_at_rest
  # shellcheck disable=SC2046
  rightclick $(status_item)
  eventually menu_is_open || return 1
  MENU_ID=$(menu_ids | head -n 1)
  read -r mx my mw mh <<< "$(frame_of_menu "$MENU_ID")"
}

# row_at <title>: x y, the middle of the row of the open menu whose title starts so. By the model's text and the sizes above.
row_at() {
  echo "$MENU_TEXT" | awk -v title="$1" -v x="$mx" -v y="$my" -v w="$mw" -v row="$row" -v separator="$separator" \
    -v heading="$heading" -v padding="$padding" '
    BEGIN { at = y + padding }
    { sub(/^  ✓ /, "    ") }
    /^-----/ { at += separator; next }
    # `menu` prints no dashes above a heading; macOS draws the separator all the same, but for the first.
    /^[^ ]/ { at += heading + (NR > 1 ? separator : 0); next }
    # Four spaces and no more: a row of the menu itself. What is further in belongs to a submenu, and so does a line of dashes.
    /^    [^ ]/ && !/^    -----/ {
      if (index($0, "    " title) == 1) { printf "%d %d\n", x + w / 2, at + row / 2; found = 1; exit }
      at += row
    }
    END { exit !found }'
}

# measure <name>: the menu's height against the model's, against 600 points and against the display, and its picture. Leaves it open.
measure() {
  open_menu
  check "$1: the menu opens" menu_is_open || return 1
  echo "$1: the menu is at $mx $my, $mw wide and $mh high; the model says $MENU_SAYS; the display shows down to $foot"
  check "$1: macOS makes it as high as the model says" test "$mh" = "$MENU_SAYS"
  check "$1: at most 600 points" test "$mh" -le 600
  check "$1: it ends above the Dock" test "$((my + mh))" -le "$foot"
  shot "$1"
  look "$1-own" "$MENU_ID"
}

# submenu <name> <title>: with the menu open, rests on that row, and takes a picture of what opens. Its height is for reading: headings and
# separators in submenus are the one thing here that the fake Mac leaves out.
submenu() {
  local at id
  at=$(row_at "$2") || { check "$2 is a row of the menu" false; return 1; }
  # shellcheck disable=SC2086
  move $at
  sleep 1
  id=$(menu_ids | grep -v "^$MENU_ID\$" | head -n 1)
  check "$2 opens a submenu" test -n "$id"
  echo "$2: its submenu is at $(frame_of_menu "$id")"
  shot "$1"
}

# choose <title>: opens the menu and clicks that row.
choose() {
  local at
  open_menu
  check "the menu opens" menu_is_open || return 1
  at=$(row_at "$1") || { check "$1 is a row of the menu" false; close_menu; return 1; }
  echo "$1 is at $at; the menu ends at $((my + mh)), the display shows down to $foot"
  # shellcheck disable=SC2086
  click $at
  # A click that missed its row leaves the menu open, and every step after it would fail for that alone.
  check "the click on $1 closed the menu" eventually menu_is_closed || close_menu
}

in_view() { ! is parked "$1"; }
says_status() { "$ARBOR_BIN/arborctl" status | grep -q "$1"; }
says_menu() { "$ARBOR_BIN/arborctl" menu | grep -q "$1"; }
not_held() { ! says_menu "The view is held"; }

arbor_build
arbor_start 3 ARBOR_NO_STATUS_ITEM=0 ARBOR_NO_HOTKEYS=0
read -r _ sy _ sh <<< "$(screen_of 1)"
foot=$((sy + sh))
echo "the display: $(display_frame_of 1); between the menu bar and the Dock: $(screen_of 1)"
ctl trace on menu-height
# A test window has the keyboard, so that the menu speaks of that app.
# shellcheck disable=SC2046
click $(center_of "$W1")

step "nothing docked"
measure 10-nothing-docked
close_menu

step "an ordinary day, and every submenu"
ctl dock "$W1" left
ctl dock "$W2" right
measure 20-ordinary
submenu 21-saved-views "Saved Views"
submenu 22-view "View"
submenu 23-dock "Dock Focused Window"
submenu 24-focused-window "Focused Window"
submenu 25-arrangement "Arrangement"
submenu 26-help "Help"
close_menu

step "much of everything: nine saved views, three named spaces, twelve apps that are not arranged"
for slot in 1 2 3 4 5 6 7 8 9; do "$ARBOR_BIN/arborctl" save-view "$slot" > /dev/null; done
for window in "$W1" "$W2"; do
  ctl zoom "$window"
  ctl name "Space $window"
done
ctl show-all
ctl name "All of it"
for app in 1 2 3 4 5 6 7 8 9 10 11 12; do "$ARBOR_BIN/arborctl" exclude "com.example.other$app" > /dev/null; done
measure 30-much
submenu 31-much-saved-views "Saved Views"
submenu 32-much-arrangement "Arrangement"
close_menu

step "the state with the most lines: the view is held and settings.json has a mistake"
cp "$ARBOR_HOME/settings.json" "$ARBOR_HOME/settings.good"
printf '{ "gap": 8,\n  oops\n}\n' > "$ARBOR_HOME/settings.json"
ctl reload-settings
check "the menu says that settings.json has a mistake" eventually says_menu "Settings.json has a mistake"
ctl hold
check "and that the view is held" eventually says_menu "The view is held"
measure 40-most-lines
close_menu
choose "The view is held"
check "Release let go of the view" eventually says_menu "Hold This View"
check "and the line is gone" eventually not_held
cp "$ARBOR_HOME/settings.good" "$ARBOR_HOME/settings.json"
ctl reload-settings

step "the first way out: Show Everything"
ctl zoom "$W1"
check "the second window is out of view" eventually is parked "$W2"
choose "Show Everything"
check "it is back in view" eventually in_view "$W2"

step "the second: Float All Windows"
ctl zoom "$W1"
check "the second window is out of view" eventually is parked "$W2"
choose "Float All Windows"
check "the first window floats" eventually is floating "$W1"
check "the second window floats" eventually is floating "$W2"
check "and is in view" eventually in_view "$W2"

step "the third: Pause Arbor, and Resume"
ctl dock "$W1" left
ctl dock "$W2" right
choose "Pause Arbor"
check "Arbor is paused" eventually says_status "^paused"
measure 50-paused
close_menu
choose "Arbor is paused"
check "Arbor runs again" eventually says_status "^running"

step "the fourth: Quit Arbor, with a window out of view"
ctl dock "$W1" left
ctl dock "$W2" right
ctl zoom "$W1"
check "the second window is out of view" eventually is parked "$W2"
ctl trace off
cp "$ARBOR_HOME"/traces/*.jsonl "$ARBOR_OUT/" 2> /dev/null
choose "Quit Arbor"
check "Arbor exits" arbor_await_exit "$ARBOR_PID" 50
# Finds Arbor gone, and checks that every window is back on screen.
arbor_stop 60-after-quit
