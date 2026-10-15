#!/bin/bash
# Undo and redo for the arrangement: ⌃⌥Z, ⌃⌥⇧Z and the menu's two rows, after real drags, drops and shortcuts.
# What only real windows can say: whether a drag of a gap (dozens of events) is one step, whether a dropped window goes back to where it
# was picked up, and whether what macOS reports of Arbor's own moves adds steps of its own.
# A31 undo and redo for the arrangement.
source "$(dirname "$0")/../lib.sh"
arbor_build
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0

# The rows as `arborctl menu` prints them: title, two spaces, shortcut, and "(gray)" on one that cannot be chosen.
undo_row() { says "    $1  ⌃⌥Z$2" arborctl menu; }
redo_row() { says "    $1  ⌃⌥⇧Z$2" arborctl menu; }

claim "with nothing to undo the menu's Undo and Redo are grey, a click on Undo does nothing, and ⌃⌥Z moves nothing"
proves A31
click_window "$W1"
start1=$(real_frame_of "$W1")
start2=$(real_frame_of "$W2")
check "Undo names no step and is grey" undo_row "Undo" "  (gray)"
check "so is Redo" redo_row "Redo" "  (gray)"
check "the open menu has the row" click_menu "Undo"
check "the click on it runs nothing" stays fails ran undo
key escape
# The menu takes every key until it has closed.
sleep 0.5
check "⌃⌥Z reaches Arbor" pressed ctrl+opt+z undo
check "Arbor says that there is nothing to undo" eventually logged "nothing to undo"
# shellcheck disable=SC2086
check "the window with the keyboard has not moved" stays frame_is "$W1" $start1
check "nothing is docked" count docked 0

ctl dock "$W1" left
ctl dock "$W2" right
# The third floats on the Desktop between them. Small, so that none of its edges is flush with a docked window's, where macOS holds a
# dragged edge back. And put there by hand, which is the place undo promises to give back: a window that is still where its app opened
# it may be put elsewhere.
take "x y" desktop_point
tw move "$W3" "$((x - 120))" "$((y - 160))" 240 200
take "x y" titlebar_of "$W3"
drag "$x" "$y" "$x" "$((y + 60))"
click_window "$W1"
summary
first=$(real_frame_of "$W1")
second=$(real_frame_of "$W2")
third=$(real_frame_of "$W3")

claim "drag a gap forth and part of the way back, let go, press ⌃⌥Z once: the gap is back where it was before the drag"
proves A31
width=$(width_of "$W1")
take "x y" seam_right_of "$W1"
drag "$x" "$y" "$((x + 90))" "$y" --no-release
check "the window beside the gap follows the pointer out" eventually wider_than "$W1" "$((width + 70))"
release "$((x + 50))" "$y"
check "and back: let go, it is 50 points wider than it was" eventually width_is "$W1" "$((width + 50))" 6
check "the menu offers to undo a resize" eventually undo_row "Undo Resize" ""
check "⌃⌥Z reaches Arbor" pressed ctrl+opt+z undo
check "Arbor says that it took the drag of the gap back" eventually logged "undid drag the gap between"
# shellcheck disable=SC2086
check "one press puts the gap back: the window is exactly where it was" eventually frame_is "$W1" $first
# shellcheck disable=SC2086
check "so is the window that floats on the Desktop" eventually frame_is "$W3" $third
check "the whole drag was one step: the next to undo is the dock before it" undo_row "Undo Dock" ""
settled

claim "⌃⌥⇧Z after ⌃⌥Z: the gap is where the drag left it, and ⌃⌥Z takes it back again"
proves A31
check "the menu offers to redo the resize" redo_row "Redo Resize" ""
check "⌃⌥⇧Z reaches Arbor" pressed ctrl+opt+shift+z redo
check "the window is 50 points wider again" eventually width_is "$W1" "$((width + 50))" 6
check "there is nothing left to redo" eventually redo_row "Redo" "  (gray)"
settled
check "⌃⌥Z reaches Arbor" pressed ctrl+opt+z undo
check "the gap is back" eventually width_is "$W1" "$width"
settled

claim "drag a docked window's inner edge, then ⌃⌥Z: window and neighbour have their sizes back"
proves A31
take "x y w h" real_frame_of "$W2"
drag "$((x + 1))" "$((y + h / 2))" "$((x - 59))" "$((y + h / 2))"
check "the window is wider" eventually wider_than "$W2" "$((w + 20))"
check "it is in its slot: the layout followed the window" eventually in_slot "$W2"
check "the menu offers to undo a resize" eventually undo_row "Undo Resize" ""
check "⌃⌥Z reaches Arbor" pressed ctrl+opt+z undo
check "the window is exactly where it was" eventually frame_is "$W2" "$x" "$y" "$w" "$h"
check "that was one step too" undo_row "Undo Dock" ""
settled

claim "drop a floating window on the wrong screen edge, then ⌃⌥Z: it floats again where it was picked up, and the others have their places back"
proves A31
# The bottom one, which is Arbor's whatever macOS does at the others.
# shellcheck disable=SC2046
drag_window "$W3" $(edge_point bottom)
check "the window docked at the bottom edge" eventually at_edge "$W3" bottom
check "the others made room above it" eventually above "$W1" "$W3"
check "⌃⌥Z reaches Arbor" pressed ctrl+opt+z undo
check "it floats again" eventually is floating "$W3"
# shellcheck disable=SC2086
check "exactly where it was picked up" eventually frame_is "$W3" $third
# shellcheck disable=SC2086
check "the first window is back" eventually frame_is "$W1" $first
# shellcheck disable=SC2086
check "the second window is back" eventually frame_is "$W2" $second
settled

claim "⌃⌥Z while a docked window is held over the Desktop: refused, and the window stays in the hand; let go and pressed again, it is back in its slot"
proves A31
# shellcheck disable=SC2046
drag_window "$W1" $(desktop_point) --no-release
check "the window follows the pointer" eventually fails in_slot "$W1"
check "⌃⌥Z reaches Arbor" pressed ctrl+opt+z undo
check "Arbor says why not" eventually logged "cannot undo while a window is being dragged"
check "the window is not pulled out of the hand" stays fails in_slot "$W1"
release
check "let go, it floats" eventually is floating "$W1"
check "the menu offers to undo that" eventually undo_row "Undo Float" ""
check "⌃⌥Z reaches Arbor" pressed ctrl+opt+z undo
# shellcheck disable=SC2086
check "it is docked where it was" eventually frame_is "$W1" $first
check "Arbor says that it is docked" is docked "$W1"
settled

claim "Arrange Windows by mistake, then ⌃⌥Z: everything is back, the floating window included"
proves A31
click_window "$W1"
check "arrange succeeds" ctl arrange
check "all three are docked" eventually count docked 3
check "⌃⌥Z reaches Arbor" pressed ctrl+opt+z undo
check "two are docked" eventually count docked 2
# shellcheck disable=SC2086
check "the floating window is exactly where it was" eventually frame_is "$W3" $third
# shellcheck disable=SC2086
check "so is the first window" eventually frame_is "$W1" $first
# shellcheck disable=SC2086
check "and the second" eventually frame_is "$W2" $second
settled

claim "the menu names the step: choose Redo Arrange, then Undo Arrange, and the arrangement goes forth and back"
proves A31
check "Redo Arrange can be clicked" click_menu "Redo Arrange"
check "Arbor ran redo" eventually ran redo
check "all three are docked" eventually count docked 3
check "Undo Arrange can be clicked" click_menu "Undo Arrange"
check "Arbor ran undo" eventually ran undo
check "two are docked" eventually count docked 2
# shellcheck disable=SC2086
check "the floating window is exactly where it was" eventually frame_is "$W3" $third
settled

claim "⌃⌥↩ frames a window, ⌃⌥F floats it out of its frame, ⌃⌥Z: it fills the screen again and the others are out of view"
proves A31
click_window "$W1"
check "⌃⌥↩ reaches Arbor" pressed ctrl+opt+return zoom
check "the window fills the screen" eventually fills "$W1"
check "⌃⌥F reaches Arbor" pressed ctrl+opt+f toggle-float
check "the window floats" eventually is floating "$W1"
check "⌃⌥Z reaches Arbor" pressed ctrl+opt+z undo
check "it fills the screen again: the view is undone with the change that moved it" eventually fills "$W1"
check "the second window is out of view again" eventually out_of_view "$W2"
check "⌃⌥Space reaches Arbor" pressed ctrl+opt+space show-all
# shellcheck disable=SC2086
check "everything is where it was" eventually frame_is "$W1" $first
settled

claim "close a docked window with its red button, then ⌃⌥Z: Arbor says once that it cannot bring the window back, and the next ⌃⌥Z goes on with the step before"
proves A31
open_window N1 size=400x300 title=Short lived
ctl dock "$N1" beside "$W1" bottom
check "it is docked below the first window" eventually above "$W1" "$N1"
click_button "$N1" close
forget_window "$N1"
check "the window above has the whole column again" eventually at_edge "$W1" bottom
click_window "$W1"
check "⌃⌥Z reaches Arbor" pressed ctrl+opt+z undo
check "Arbor says what it cannot undo" eventually logged "cannot undo the closing of a window"
check "nothing has changed" stays count docked 2
check "⌃⌥Z again" pressed ctrl+opt+z undo
check "the second window, docked last, floats" eventually is floating "$W2"
check "the first is still docked" is docked "$W1"

claim "one more ⌃⌥Z takes back the first dock and nothing is left to undo: what macOS reported of Arbor's own moves added no step"
proves A31
check "one step is left, the first dock" undo_row "Undo Dock" ""
check "⌃⌥Z reaches Arbor" pressed ctrl+opt+z undo
check "nothing is docked" eventually count docked 0
check "Undo is grey again" eventually undo_row "Undo" "  (gray)"
# shellcheck disable=SC2086
check "the first window floats where it was before it was docked" eventually frame_is "$W1" $start1
# shellcheck disable=SC2086
check "so does the second" eventually frame_is "$W2" $start2
check "the third is in view" in_view "$W3"

arbor_stop
