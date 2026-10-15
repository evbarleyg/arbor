#!/bin/bash
# Where Go to… goes: to a window in the Dock, of a hidden app, floating out of view, to a saved view and a named space, each chosen in the
# palette with real keys; then the other ways to ask, the menu and the command line; and what the log keeps of it all.
# 46-goto.sh has the typing and choosing itself. A section of its own, because each has a time limit.
# A27 Go to…: find any window, named space or saved view by typing; with it A20, named spaces, as far as the palette goes to them.
source "$(dirname "$0")/../lib.sh"
arbor_build

# The palette's level is floating (3) plus 2. The minimap and the panel of shortcuts share it; neither is asked for in here.
palette_open() { has_overlay 5 || { echo "Arbor shows no palette"; return 1; }; }
palette_closed() { fails has_overlay 5 || { echo "the palette is on screen, at $(overlay_frame 5)"; return 1; }; }
types() {
  local one
  for one in "$@"; do key "$one" || return 1; done
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
# In the Dock and in ⌘Tab, like a person's apps: ⌘H did nothing for an app without an icon there on a real Mac. A person's Dock stays as
# it is, and there the app hides itself.
if on_throwaway_mac; then
  ARBOR_TEST_WINDOWS_ARGS="--regular"
  ARBOR_SECOND_APP_ARGS="--regular"
fi
hide_other_app() { if on_throwaway_mac; then key_to "$V1" cmd+h; else tw2 hide; fi; }
# The first window above the other app's | the Desktop, where the fourth floats | the second above the third.
arbor_start 4 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W2" bottom
ctl dock "$V1" beside "$W1" bottom
# The first app's windows are called Arbor Test and a number. A word for the other app's, whose name ends in a digit.
tw2 title "$V1" Ledger
summary

show_everything
place=$(real_frame_of "$W3")
claim "go to a window that is in the Dock: it comes back framed, with the keyboard, and its own place is still its own"
proves A27
click_button "$W3" minimize
check "Arbor sees the window minimized" eventually is minimized "$W3"
ctl zoom "$W1"
visit "$W1"
where=$(pointer where)
check "⌃⌥G opens the palette" opens_the_palette
types 3
key return
check "the palette is gone" eventually palette_closed
check "the window is out of the Dock" eventually fails is minimized "$W3"
check "it fills the screen, alone, as the first window did" eventually only_shows "$W3"
check "the next letter goes to it, without a click" reaches "$W3" x
check "the pointer has not moved" test "$(pointer where)" = "$where"
ctl show-all
# shellcheck disable=SC2086
check "with everything in view it is where it was" eventually frame_is "$W3" $place
check "to be seen there" in_view "$W3"
check "as a window, not as a tile" fails is tile "$W3"
settled
# Still in the Dock, it would be the next claims' failure too.
if is minimized "$W3" > /dev/null 2>&1; then tw restore "$W3"; fi

show_everything
visit "$W1"
visit "$V1"
place=$(real_frame_of "$V1")
claim "go to a window of a hidden app: the app comes back, and the window has its own place and the keyboard"
proves A27
check "Arbor knows the window by the title its app gave it since" eventually says Ledger arborctl state --titles
hide_other_app
check "macOS hides the app" eventually out_of_view "$V1"
check "Arbor sees the other app's window hidden" eventually is hidden "$V1"
visit "$W1"
check "the first app is in front" eventually front_is "$ARBOR_WINDOWS_PID"
check "⌃⌥G opens the palette" opens_the_palette
types l e d
key return
check "the palette is gone" eventually palette_closed
check "the app is no longer hidden" eventually fails is hidden "$V1"
# shellcheck disable=SC2086
check "its window is where it was" eventually frame_is "$V1" $place
check "to be seen there" eventually in_view "$V1"
check "its app is in front" eventually front_is "$ARBOR_WINDOWS_PID_2"
check "the next letter goes to the window, without a click" reaches "$V1" x
check "the camera stayed on everything" camera_on root
settled
# Still hidden, it would be the next claims' failure too.
if is hidden "$V1" > /dev/null 2>&1; then tw2 unhide; fi

frame_the_first
claim "go to a floating window from a framed one: the Desktop is framed, with the window on it and the keyboard in it"
proves A27
check "the floating window is out of view" eventually out_of_view "$W4"
check "⌃⌥G opens the palette" opens_the_palette
types 4
key return
check "the palette is gone" eventually palette_closed
check "the camera is on the Desktop" eventually camera_on desktop
check "the floating window is in view" eventually in_view "$W4"
check "the framed window has left" eventually out_of_view "$W1"
check "the next letter goes to the floating window" reaches "$W4" x

show_everything
# View 1 is the column of the second and the third window, Books the column of the first and the other app's.
ctl zoom "$W2"
ctl out
ctl save-view 1
ctl zoom "$W1"
ctl out
ctl name Books
frame_the_first
claim "go to a saved view by its number and to a named space by its name: the view moves there"
proves A27 A20
check "⌃⌥G opens the palette" opens_the_palette
types v 1
key return
check "the palette is gone" eventually palette_closed
check "the saved view's windows are in view" eventually in_view "$W2"
check "both of them" in_view "$W3"
check "the framed window has left" eventually out_of_view "$W1"
settled
visit "$W2"
check "⌃⌥G opens the palette" opens_the_palette
types b o o k s
key return
check "the palette is gone" eventually palette_closed
check "the named space's windows are in view" eventually in_view "$W1"
check "both of them" in_view "$V1"
check "the saved view's have left" eventually out_of_view "$W2"
check "spaces says that it is in view" says "in view" arborctl spaces
settled
ctl unname Books

frame_the_first
claim "choose Go to… from the menu: the palette opens with the keyboard, and what is typed finds a window"
proves A27
keys=$(events_of "$W1" key)
check "the row can be clicked" click_menu "Go to"
check "Arbor ran find" eventually ran find
check "the palette is on screen" eventually palette_open
check "the app in front stays in front" front_is "$ARBOR_WINDOWS_PID"
types 3
key return
check "the palette is gone" eventually palette_closed
check "the window found fills the screen, alone" eventually only_shows "$W3"
check "the window left behind saw none of the typing" received "$W1" key -eq "$keys"
settled

frame_the_first
claim "find and reveal, by command: the best match comes into view with the keyboard and no palette, and what matches nothing is refused"
proves A27
check "find with a part of a title succeeds" ctl find led
check "no palette shows" palette_closed
check "the window found fills the screen, alone" eventually only_shows "$V1"
check "it has the keyboard" eventually is focused "$V1"
check "what matches nothing is refused, in words" says "no window, space or saved view matches" arborctl find zebra
check "with exit code 1" exits_with 1 arborctl find zebra
check "the view stayed" stays only_shows "$V1"
check "reveal succeeds" ctl reveal "$W2"
check "the window asked for fills the screen, alone" eventually only_shows "$W2"
check "it has the keyboard" eventually is focused "$W2"
settled

claim "after all that finding, no title and nothing that was typed is in Arbor's log"
proves A27
check "the log has lines about Go to…" grep -q "find: " "$ARBOR_HOME/arbor.log"
check "none of the first app's titles" fails grep -q "Arbor Test" "$ARBOR_HOME/arbor.log"
check "nor the other app's" fails grep -q -i "ledger" "$ARBOR_HOME/arbor.log"
check "nor what was looked for by command" fails grep -q -e "find led" -e zebra "$ARBOR_HOME/arbor.log"

ctl show-all
arbor_stop
