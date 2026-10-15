#!/bin/bash
# Holding the view, for a shared screen: nothing moves it, not even the person's own keys, until it is released. And holding still, for
# calls: Arbor moves nothing by itself, the person's own keys still work.
# A58 hold the view on a shared screen, A59 hold still during calls.
source "$(dirname "$0")/../lib.sh"
arbor_build

paused() { "$ARBOR_BIN/arborctl" status | grep "^paused" > /dev/null || { echo "Arbor is not paused"; return 1; }; }
running() { "$ARBOR_BIN/arborctl" status | grep "^running" > /dev/null || { echo "Arbor is not running"; return 1; }; }
held() { says "the view is held" arborctl status; }
still() { says "holding still" arborctl status; }
marked() { [ "$(pointer menu-mark "$ARBOR_PID" "$1")" = "$2" ] || { echo "$1 is not marked $2"; return 1; }; }
# How often Arbor has said that on screen since the claim began (the debug log has every line it shows).
said_times() {
  local times
  times=$(arbor_log_since "$ARBOR_STEP_MARK" | grep -F "said on " | grep -c -F -e "$1")
  [ "$times" -eq "$2" ] || { echo "said $times times, not $2: $1"; return 1; }
}
# How often Arbor has sent the keyboard back since the claim began, and whether that is more often than <n> times.
turned_away() { arbor_log_since "$ARBOR_STEP_MARK" | grep -c -F "took the keyboard out of view; sending it back"; }
turned_away_more_than() {
  [ "$(turned_away)" -gt "$1" ] || { echo "Arbor has sent the keyboard back $(turned_away) times, not more than $1"; return 1; }
}
ARBOR_SECOND_APP=1
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
# A column of the first app's first two windows, the Desktop with its third window floating on it, and the other app's window.
ctl dock "$W1" left
ctl dock "$W2" beside "$W1" bottom
ctl dock "$V1" right
click_window "$W1"
ctl zoom "$W1"
summary

claim "choose Hold This View from the menu with a window framed: no shortcut moves the view, and a line says why and what releases it"
proves A58
check "the others are out of view" eventually out_of_view "$V1"
check "the submenu's item can be clicked" click_menu "View" "Hold This View"
check "Arbor ran hold" eventually ran hold
check "status says that the view is held" eventually held
check "the framed window has the keyboard" eventually is focused "$W1"
check "⌃⌥Space reaches Arbor" pressed ctrl+opt+space show-all
check "Arbor says on screen why nothing happened" eventually logged "The view is held · ⌃⌥⎋ releases it"
check "⌃⌥↑ reaches Arbor" pressed ctrl+opt+up out
check "⌃⌥D reaches Arbor" pressed ctrl+opt+d desktop
check "⌃⌥⇧F reaches Arbor" pressed ctrl+opt+shift+f float-all
check "the framed window still fills the screen" stays fills "$W1"
check "the other app's window is still out of view" out_of_view "$V1"
check "and so is the floating one" out_of_view "$W3"
check "all three are still docked" count docked 3
open_menu
check "the menu's first line says that the view is held" eventually pointer menu-item "$ARBOR_PID" "The view is held: nothing moves it"
key escape
check "its submenu opens" click_menu "View"
check "Hold This View is ticked" eventually marked "Hold This View" "✓"
key escape
key escape

claim "an app comes forward by itself while the view is held: its window stays out of view and the keyboard goes back"
proves A58
tw2 activate "$V1"
check "Arbor saw it take the keyboard" eventually logged "took the keyboard out of view; sending it back"
check "the keyboard is back in the framed window" eventually is focused "$W1"
check "its app is in front again" eventually front_is "$ARBOR_WINDOWS_PID"
check "the window that came forward stays out of view" stays out_of_view "$V1"
check "the framed window still fills the screen" fills "$W1"
check "nothing is said about it on the shared screen" fails logged "said on "

claim "⌃⌥F on the only window of a held view, which would float it and widen the view: it stays docked, and a line says why"
proves A58
check "⌃⌥F reaches Arbor" pressed ctrl+opt+f toggle-float
check "Arbor says on screen why nothing happened" eventually said_times "That would bring windows that are out of view into it" 1
check "it is still docked" stays is docked "$W1"
check "it still fills the screen" fills "$W1"
check "the other app's window is still out of view" out_of_view "$V1"

claim "⌘-drag the only window of a held view out of its slot: nothing else comes into view"
proves A58
# With ⌘ held a docked window floats wherever it is let go. Without a hold the window below it would take its place in the view.
take "x y" titlebar_of "$W1"
drag "$x" "$y" "$((x + 60))" "$((y + 80))" --mods cmd --no-release
check "it follows the pointer while the button is held" eventually fails fills "$W1"
check "the window below it stays out of view meanwhile" stays out_of_view "$W2"
release --mods cmd
check "let go, the window below it stays out of view" stays out_of_view "$W2"
check "and so does the other app's" out_of_view "$V1"
check "and the floating one" out_of_view "$W3"
check "the dragged window is in view" in_view "$W1"
check "the view is still held" held
ctl release
ctl dock "$W1" beside "$W2" top
click_window "$W1"
ctl zoom "$W1"

claim "hold a column of two windows: they can still be dragged beside and below each other, and nothing else comes into view"
proves A58
ctl out
check "the column is in view" eventually in_view "$W2"
check "the other app's window is not" eventually out_of_view "$V1"
ctl hold
check "the view is held" eventually held
# shellcheck disable=SC2046
drag_window "$W1" $(zone_of "$W2" left) --no-release
check "over the left part of the other window a preview shows" eventually has_overlay 3
release
check "it docks on the left of the other" eventually left_of "$W1" "$W2"
check "the other app's window is still out of view" stays out_of_view "$V1"
# shellcheck disable=SC2046
drag_window "$W1" $(zone_of "$W2" bottom) --no-release
check "over the lower part of the other window a preview shows" eventually has_overlay 3
release
check "it docks below the other" eventually above "$W2" "$W1"
check "the other app's window is out of view as before" stays out_of_view "$V1"
check "and so is the floating one" out_of_view "$W3"
check "the view is still held" held
settled
ctl release
click_window "$W1"
ctl zoom "$W1"
ctl hold

claim "⌘M on the only window of a held view: nothing else comes into view, and the menu says that nothing is in it"
proves A58
key_to "$W1" cmd+m
check "it is minimized" eventually is minimized "$W1"
# Without a hold the view shows the nearest space around it that has something in it: the other window of its column.
check "the other window of its column stays out of view" stays out_of_view "$W2"
check "and so does the other app's" out_of_view "$V1"
check "and the floating one" out_of_view "$W3"
check "the view is still held" held
open_menu
check "the menu says that nothing is in the view" eventually pointer menu-item "$ARBOR_PID" "The view is held: nothing is in it"
key escape
tw restore "$W1"
check "restored, it fills the screen as before" eventually fills "$W1"
check "the other app's window is still out of view" out_of_view "$V1"

claim "⌃⌥⎋ on a held view releases it and moves nothing; pressed again it pauses"
proves A58
click_window "$W1"
key ctrl+opt+escape
check "⌃⌥⎋ reaches Arbor" eventually logged "hold: view → none"
check "the view is no longer held" eventually fails held
check "Arbor is not paused" stays running
check "Arbor says on screen that the same key again pauses" eventually said_times "Released; the same key again pauses Arbor" 1
check "the framed window still fills the screen" fills "$W1"
check "the other app's window is still out of view" out_of_view "$V1"
key ctrl+opt+escape
check "pressed again, it pauses" eventually paused
check "and every window comes into view" eventually in_view "$V1"
key ctrl+opt+escape
check "a third press resumes" eventually running
check "with the view it had" eventually fills "$W1"
check "⌃⌥Space works again" pressed ctrl+opt+space show-all
check "everything is in view" eventually in_view "$V1"
settled

claim "choose Hold Still from the menu: an app that comes forward by itself is turned away, said once; one's own keys still move the view"
proves A59
click_window "$W1"
check "⌃⌥↩ frames the focused window" pressed ctrl+opt+return zoom
check "the other app's window is out of view" eventually out_of_view "$V1"
check "the submenu's item can be clicked" click_menu "View" "Hold Still"
check "Arbor ran hold still" eventually ran hold still
check "status says that Arbor holds still" eventually still
# What takes the keyboard within half a second of a click or a modifier key counts as the person's own doing: let that run out.
sleep 1
tw2 activate "$V1"
check "Arbor saw it take the keyboard" eventually logged "took the keyboard out of view; sending it back"
check "the keyboard is back in the framed window" eventually is focused "$W1"
check "the window that came forward stays out of view" stays out_of_view "$V1"
check "Arbor says on screen what it turned away" eventually said_times "is out of view: holding still" 1
# An app that takes the keyboard again and again within five seconds is left with it in the end: this is not that.
sleep 5
times=$(turned_away)
tw2 activate "$V1"
check "it comes forward again, and is turned away again" eventually turned_away_more_than "$times"
check "the keyboard goes back once more" eventually is focused "$W1"
check "it still is out of view" stays out_of_view "$V1"
check "and that is not said again" said_times "is out of view: holding still" 1
check "⌃⌥Space reaches Arbor" pressed ctrl+opt+space show-all
check "and shows everything" eventually in_view "$V1"
check "Arbor still holds still" still
check "its submenu opens" click_menu "View"
check "Hold Still is ticked" eventually marked "Hold Still" "✓"
key escape
key escape
check "Release can be clicked" click_menu "Release"
check "it ends" eventually fails still
settled

claim "put a window on holdStillFor in settings.json: Arbor holds still while it is open, and no longer"
proves A59
arbor_settings "{\"holdStillFor\": [\"$ARBOR_TEST_BUNDLE_2 Meeting\"]}"
check "reload-settings succeeds" ctl reload-settings
check "the app's other window does not count" stays fails still
open_window2 M1 size=400x300 title=Weekly Meeting
check "status says why Arbor holds still" eventually says "holding still while" arborctl status
open_menu
check "so does the menu" eventually pointer menu-item "$ARBOR_PID" "Holding still while"
key escape
tw2 close "$M1"
forget_window "$M1"
check "closed, it ends" eventually fails still
settled

arbor_stop
