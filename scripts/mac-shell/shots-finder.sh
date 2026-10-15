#!/bin/bash
# Go to… (docs/features/F27-window-finder.md) on real windows, with real keys and clicks, in pictures:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-finder.sh
#
# What only a Mac can tell: whether the palette gets the keyboard without Arbor becoming the active app, whether it
# closes when the keyboard goes elsewhere, whether a window comes back from the Dock to its place, and what it all
# looks like. LOOK AT THE PICTURES: the corners, the shadow, the text's baseline, the icon, the selected row, the note.
#
# Safe on a person's Mac: it touches only its own test windows and changes no setting. It does move the pointer and
# press keys. Every key is pressed while the test app is the active one, so a key the palette fails to catch
# lands in a test window, which ignores it.
source "$(dirname "$0")/lib.sh"

# The palette's level is floating (3) plus 2.
palette() { has_overlay 5; }
no_palette() { ! has_overlay 5; }
palette_frame() { overlays | awk '$3 == 5 && $8 == "on" { print int($4), int($5), int($6), int($7); exit }'; }
# The middle of the n-th row, from FinderLayout: a band of 56 for the field, 8 of padding, rows of 38.
palette_row() {
  local x y w h
  read -r x y w h <<< "$(palette_frame)"
  # With no palette up this would be a point at the left edge of the display, where somebody's Dock may be.
  [ -n "$x" ] || return 1
  echo "$((x + w / 2)) $((y + 56 + 8 + 38 * ($1 - 1) + 19))"
}
# A process id, never a name: on a person's Mac the app in front may be theirs.
front() { pointer front 2>/dev/null; }
test_app_in_front() { [ "$(front)" = "$ARBOR_WINDOWS_PID" ]; }
camera() { arbor_ask json | python3 -c 'import json, sys; print(json.load(sys.stdin)["displays"][0]["camera"])'; }
camera_is() { [ "$(camera)" = "$1" ]; }
keys() {
  local one
  for one in "$@"; do key "$one"; done
}
is_not_minimized() { ! is minimized "$1"; }
is_not_tile() { ! is tile "$1"; }
# Every test window is called "Arbor Test <n>", and one for a while something long about a committee.
log_has_no_titles() { ! grep -q -e "Arbor Test" -e committee "$ARBOR_HOME/arbor.log"; }

arbor_build
step "five windows: [1 / 5 | Desktop with 4 | 2 / 3], shortcuts and the menu bar item on"
# An ordinary app, so that it can be the active one.
ARBOR_TEST_WINDOWS_ARGS="--regular"
# The palette keeps out of shared screens and recordings (`sharingType`), and so out of these pictures unless told otherwise.
arbor_start 5 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0 ARBOR_PANELS_IN_PICTURES=1
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W2" bottom
ctl dock "$W5" beside "$W1" bottom
# shellcheck disable=SC2046
click $(center_of "$W2")
# shellcheck disable=SC2046
click $(center_of "$W1")
check "the test app is the active one" eventually test_app_in_front
check "window 1 is focused" eventually is focused "$W1"
summary
ctl zoom "$W1"
check "framed on 1: window 3 is out of view" eventually is parked "$W3"
framed=$(camera)

step "open it with the command"
ctl find
check "the palette is on screen" eventually palette
shot 01-open
echo "Arbor's own windows (the palette is at level 5):"
overlays
echo "in front: process $(front)"
check "the test app is still the active one: Arbor did not activate" test_app_in_front
check "window 1 is still what macOS calls focused" is focused "$W1"

step "type with real keys: 3 finds Arbor Test 3"
key 3
shot 02-typed
key return
check "Return closed the palette" eventually no_palette
check "window 3 is in view" eventually is on_screen "$W3"
check "window 3 is focused" eventually is focused "$W3"
check "window 1 is out of view: window 3 is framed as window 1 was" eventually is parked "$W1"
shot 03-went
summary

step "⌃⌥G, then Return at once: back to the window before"
key ctrl+opt+g
check "the shortcut opened the palette" eventually palette
shot 04-recent-first
key return
check "window 1 is focused again" eventually is focused "$W1"
check "the palette closed" eventually no_palette

step "arrows, Tab, Escape"
ctl zoom "$W1"
check "framed on 1" eventually camera_is "$framed"
key ctrl+opt+g
check "open" eventually palette
keys down down
shot 05-third-row
keys tab shift+tab up up up
shot 06-round-the-top
key escape
check "Escape closed the palette" eventually no_palette
check "and the view did not move" camera_is "$framed"
check "and window 1 still has the keyboard" is focused "$W1"

step "the shortcut again closes it"
key ctrl+opt+g
check "open" eventually palette
key ctrl+opt+g
check "closed" eventually no_palette

step "a click on another window closes it"
ctl show-all
key ctrl+opt+g
check "open" eventually palette
# Its lower left corner, clear of the palette.
# shellcheck disable=SC2046
click $(arbor_point $(frame_of "$W5") "x + 20" "y + h - 20")
check "the click elsewhere closed the palette" eventually no_palette
check "and reached the window" eventually is focused "$W5"

step "does it ALWAYS close? a click on one of Arbor's own tiles or gap handles"
key ctrl+opt+g
check "open" eventually palette
# The gap between windows 1 and 5: Arbor's own panel, which takes no keyboard.
# shellcheck disable=SC2046
click $(seam_below "$W1")
check "a click on a gap handle closed the palette" eventually no_palette

step "does it ALWAYS close? pause"
# shellcheck disable=SC2046
click $(center_of "$W1")
key ctrl+opt+g
check "open" eventually palette
ctl pause
check "pausing closed the palette" eventually no_palette
ctl resume

# ⌘Tab brings a person's own app, or its full-screen Space, in front of the curtain, and nothing here puts it back.
if on_throwaway_mac; then
  step "does it ALWAYS close? ⌘Tab"
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  check "the test app is the active one" eventually test_app_in_front
  key ctrl+opt+g
  check "open" eventually palette
  key cmd+tab
  check "⌘Tab closed the palette" eventually no_palette
  echo "in front: process $(front)"
  # Back to the test app before any other key is pressed.
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  check "the test app is the active one again" eventually test_app_in_front

  step "does it ALWAYS close? Mission Control"
  key ctrl+opt+g
  check "open" eventually palette
  key ctrl+up
  sleep 1
  shot 06a-mission-control
  key escape
  sleep 1
  check "no palette after Mission Control" eventually no_palette
  # shellcheck disable=SC2046
  click $(center_of "$W1")

  step "does it ALWAYS close? a swipe to another macOS Space"
  space_add
  key ctrl+opt+g
  check "open" eventually palette
  space_go right
  sleep 1
  shot 06b-other-space
  check "the palette did not come along" eventually no_palette
  space_go left
  sleep 1
  check "and is not waiting here" no_palette
  # shellcheck disable=SC2046
  click $(center_of "$W1")
fi
grep "the palette is up" "$ARBOR_HOME/arbor.log" | sort | uniq -c

step "⌘2, and a click on a row"
# The list is most recently used first, the focused window after the others: after these clicks 2, 3, 5, …, 1.
for one in "$W5" "$W3" "$W2" "$W1"; do
  # shellcheck disable=SC2046
  click $(center_of "$one")
done
check "window 1 is focused" eventually is focused "$W1"
key ctrl+opt+g
check "open" eventually palette
shot 07-before-cmd-2
key cmd+2
check "⌘2 closed the palette" eventually no_palette
check "and went to the second row's window" eventually is focused "$W3"
# Now 1, 2, 5, …, 3.
key ctrl+opt+g
check "open" eventually palette
if fourth=$(palette_row 4) && third=$(palette_row 3); then
  # shellcheck disable=SC2086
  move $fourth
  shot 08-hover-changes-nothing
  # shellcheck disable=SC2086
  click $third
fi
check "a click on the third row closed the palette" eventually no_palette
check "and went to its window" eventually is focused "$W5"

step "nothing matches"
key ctrl+opt+g
check "open" eventually palette
keys z z z
shot 09-nothing-matches
key return
check "Return with nothing to choose leaves it open" palette
keys delete delete delete
shot 10-text-deleted
key escape
check "closed" eventually no_palette

step "saved views, and a list longer than the palette"
ctl zoom "$W2"; ctl save-view 1
ctl out; ctl save-view 2
ctl desktop; ctl save-view 3
ctl show-all; ctl save-view 4
ctl zoom "$W5"; ctl save-view 5
column=$(arbor_ask json | python3 -c 'import json, sys; print(json.load(sys.stdin)["displays"][0]["savedViews"]["2"])')
key ctrl+opt+g
check "open" eventually palette
shot 11-nine-of-ten
key up
shot 12-scrolled-to-the-last
keys v 2
shot 13-view-2
key return
check "the view moved to saved view 2" eventually camera_is "$column"
check "closed" eventually no_palette
shot 14-at-view-2

step "a window in the Dock"
ctl show-all
read -r x y _ _ <<< "$(frame_of "$W2")"
slot=$(frame_of "$W2")
# Without a frame the click below would land on the Apple menu.
[ -n "$x" ] || die "no frame for window $W2"
# The yellow button, where Accessibility says it is.
# shellcheck disable=SC2046
click $(pointer button "$ARBOR_WINDOWS_PID" "$x" "$y" minimize)
if eventually is minimized "$W2"; then
  ctl zoom "$W1"
  key ctrl+opt+g
  check "open" eventually palette
  # Not 2 alone, which is View 2 first.
  keys t 2
  shot 15-minimised-note
  key return
  film 16-coming-back 4
  check "window 2 is no longer minimised" eventually is_not_minimized "$W2"
  check "it is in view" eventually is on_screen "$W2"
  check "it is focused" eventually is focused "$W2"
  check "window 1 is out of view: window 2 is framed as window 1 was" eventually is parked "$W1"
  shot 16a-framed
  ctl show-all
  sleep 1
  echo "its slot was $slot and it is at $(frame_of "$W2"); the window server has it at $(real_frame_of "$W2")"
  check "it is back in its own place" test "$(frame_of "$W2")" = "$slot"
  check "it did not become a tile" is_not_tile "$W2"
  shot 17-back-from-the-dock
  summary
else
  echo "the click did not minimise window 2; skipped"
  shot 15-not-minimised
fi

step "a title longer than its row"
ctl show-all
# shellcheck disable=SC2046
click $(center_of "$W1")
tw title "$W4" Minutes of the quarterly meeting of the committee on the naming of committees, third draft, with comments
key ctrl+opt+g
check "open" eventually palette
# LOOK: the title ends in … before the note at the right, and the letters typed are set off in it.
keys m i n
shot 17a-long-title
key escape
check "closed" eventually no_palette
tw title "$W4" Arbor Test 4

step "without the palette"
ctl zoom "$W1"
ctl find test 4
check "find <text> brought the floating window into view" eventually is on_screen "$W4"
check "and focused it" eventually is focused "$W4"
ctl find zebra
ctl reveal "$W3"
check "reveal focused window 3" eventually is focused "$W3"

step "it finds commands: real keys spell one, ⇥ picks it, Return runs it on the window behind the palette (board 0.14, 1.94)"
ctl show-all
# shellcheck disable=SC2046
click $(center_of "$W4")
check "the floating window has the keyboard" eventually is focused "$W4"
key ctrl+opt+g
check "open" eventually palette
keys w i n
# LOOK: windows first, one of them selected; then commands, each with its sign; and under them all the one line that says which key leads
# to the commands.
shot 15b-places-and-commands
keys delete delete delete
keys d o c k
# LOOK: the sign where an icon would be, the arrows in the names, the notes with their keys at the right, nothing cut off; NO ROW IS
# SELECTED, and the line under the rows says how to pick one.
shot 16-commands
keys space l e f t
shot 17-one-command
check "window 4 is still what macOS calls focused, with the palette up" is focused "$W4"
key return
check "Return alone runs nothing: the palette stays up" stays palette
check "and the window still floats" stays is floating "$W4"
key down
key return
check "nor after ↓, which is for places: the palette stays up" stays palette
check "and the window still floats" stays is floating "$W4"
key tab
shot 17b-picked
key return
check "picked with ⇥, Return closed the palette" eventually no_palette
check "the window behind it was docked" eventually is docked "$W4"
check "and still has the keyboard" eventually is focused "$W4"
key ctrl+opt+g
check "open" eventually palette
keys u n d o tab
key return
check "closed" eventually no_palette
check "Undo, by its name, took it back" eventually is floating "$W4"

step "the menu"
# A right click: with something docked the item is a row of buttons, and a plain click in its middle presses one, which moves the view.
if open_menu; then
  shot 18-menu
  key escape
fi

step "quitting with the palette open"
# shellcheck disable=SC2046
click $(center_of "$W3")
key ctrl+opt+g
check "open" eventually palette
arbor_log
check "no window title reached the log" log_has_no_titles
grep "find" "$ARBOR_HOME/arbor.log" | tail -n 12
arbor_stop 19-after-quit

step "the palette drawn dark"
# This Arbor's own windows alone: the Mac's appearance stays as it is.
arbor_start 5 ARBOR_NO_HOTKEYS=0 ARBOR_PANELS_IN_PICTURES=1 ARBOR_APPEARANCE=dark
ctl dock "$W1" left
ctl dock "$W2" right
# shellcheck disable=SC2046
click $(center_of "$W1")
key ctrl+opt+g
check "open" eventually palette
shot 20-dark-open
keys t 3
shot 21-dark-typed
keys z z
shot 22-dark-nothing-matches
key escape
check "closed" eventually no_palette
arbor_stop 23-dark-quit
