# An app's own Window menu, picked from with the real pointer. Read in after lib.sh (or lib-day.sh), by scripts that ask macOS to move a window.
#
# System Events is asked only where a menu and its items are; the clicks are the pointer's, so that what macOS and Arbor hear is what they hear of
# a person. Only on a throwaway Mac: System Events asks for a permission of its own, which GitHub's Macs have given.
needs_throwaway_mac "ask System Events where an app's menus are, and pick from them with the pointer"

# place_of <process> <what, in System Events' words>: the middle of it, in whole points. Only looks.
place_of() {
  arbor_within 10 osascript -e "tell application \"System Events\" to tell process \"$1\" to get {position, size} of $2" 2> /dev/null \
    | awk -F', *' 'NF == 4 { printf "%d %d\n", $1 + $3 / 2, $2 + $4 / 2 }'
}

# menu_pick <process> <item> [<item of its submenu>]: in the Window menu, with the real pointer, as a hand does it.
menu_pick() {
  local process=$1 item=$2 sub=${3:-} bar="menu bar item \"Window\" of menu bar 1" at
  at=$(place_of "$process" "$bar")
  [ -n "$at" ] || { echo "$process has no Window menu"; return 1; }
  # shellcheck disable=SC2086
  click $at
  sleep 0.5
  at=$(place_of "$process" "menu item \"$item\" of menu 1 of $bar")
  if [ -z "$at" ]; then
    echo "its Window menu has no \"$item\""
    key escape
    return 1
  fi
  if [ -z "$sub" ]; then
    # shellcheck disable=SC2086
    click $at
    return
  fi
  # shellcheck disable=SC2086
  move $at
  sleep 0.7
  at=$(place_of "$process" "menu item \"$sub\" of menu 1 of menu item \"$item\" of menu 1 of $bar")
  if [ -z "$at" ]; then
    echo "\"$item\" has no \"$sub\""
    key escape
    key escape
    return 1
  fi
  # shellcheck disable=SC2086
  click $at
}
