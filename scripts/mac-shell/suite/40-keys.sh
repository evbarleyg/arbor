#!/bin/bash
# Every keyboard shortcut of the whole map, pressed for real, with the shortcuts switched on. The nine that ship: 41-nine-keys.sh.
# T30 show everything, T31 step out and in, T32 frame one window, T33 neighbouring space, T34 back and forward,
# T35 saved views, T52 windows outside the view, T16 arrange, A01 keyboard docking and moving.
source "$(dirname "$0")/../lib.sh"
arbor_build
arbor_start 3 ARBOR_NO_HOTKEYS=0

claim "Arbor registers every shortcut it lists"
shortcuts=$(ctl bindings | grep -c "^[a-z].* → ")
echo "arborctl bindings lists $shortcuts"
check "there are at least the 35 defaults" test "$shortcuts" -ge 35
check "all of them were registered with macOS" grep -q "registered $shortcuts shortcuts" "$ARBOR_HOME/arbor.log"

claim "⌃⌥⌘← and ⌃⌥⌘→ dock the focused window at that edge"
proves A01
click_window "$W1"
check "the click gave the window the keyboard" eventually is focused "$W1"
check "⌃⌥⌘← reaches Arbor" pressed ctrl+opt+cmd+left dock left
check "the window is docked at the left edge" eventually at_edge "$W1" left
click_window "$W2"
check "⌃⌥⌘→ reaches Arbor" pressed ctrl+opt+cmd+right dock right
check "the other window is docked at the right edge" eventually at_edge "$W2" right
check "the Desktop stays between them" eventually desktop_between "$W1" "$W2"
settled

claim "⌃⌥⌘ and an arrow move a docked window one place at a time"
proves A01
click_window "$W3"
check "⌃⌥⌘← docks the third window at the left edge" pressed ctrl+opt+cmd+left dock left
check "it is left of the first" eventually left_of "$W3" "$W1"
check "⌃⌥⌘→ again" pressed ctrl+opt+cmd+right dock right
check "it traded places with the first" eventually left_of "$W1" "$W3"
check "the first is at the left edge now" eventually at_edge "$W1" left
settled

claim "⌃⌥⌘↓ and ⌃⌥⌘↑ take a docked window to the bottom and the top of the view"
proves A01
check "⌃⌥⌘↓ reaches Arbor" pressed ctrl+opt+cmd+down dock bottom
check "the window is at the bottom edge" eventually at_edge "$W3" bottom
check "below the others" eventually above "$W1" "$W3"
check "⌃⌥⌘↑ reaches Arbor" pressed ctrl+opt+cmd+up dock top
summary
check "⌃⌥⌘↓ brings it back down" pressed ctrl+opt+cmd+down dock bottom
check "the window is at the bottom edge again" eventually at_edge "$W3" bottom
settled

claim "⌃⌥↩ frames the focused window, and the others leave the screen"
proves T32 T52
check "⌃⌥↩ reaches Arbor" pressed ctrl+opt+return zoom
check "the focused window fills the screen" eventually fills "$W3"
check "the first window is out of view" eventually out_of_view "$W1"
check "the second window is out of view" eventually out_of_view "$W2"
check "Arbor says they are parked" is parked "$W1"

claim "⌃⌥[ goes back and ⌃⌥] forward"
proves T34
check "⌃⌥[ reaches Arbor" pressed "ctrl+opt+[" back
check "everything is back in view" eventually in_view "$W1"
check "the second window too" eventually in_view "$W2"
settled
check "⌃⌥] reaches Arbor" pressed "ctrl+opt+]" forward
check "the window fills the screen again" eventually fills "$W3"
check "the others are out of view again" eventually out_of_view "$W1"

claim "⌃⌥Space shows everything"
proves T30
check "⌃⌥Space reaches Arbor" pressed ctrl+opt+space show-all
check "the camera is on everything" eventually camera_on root
check "the first window is in view" eventually in_view "$W1"
check "the second window is in view" eventually in_view "$W2"
check "the third window is in view" eventually in_view "$W3"
settled

claim "⌃⌥↓ steps in toward the pointer and ⌃⌥↑ steps out"
proves T31
# shellcheck disable=SC2046
move $(center_of "$W1")
check "⌃⌥↓ reaches Arbor" pressed ctrl+opt+down in
check "the row under the pointer fills the screen: the window below it left" eventually out_of_view "$W3"
check "the row's windows are in view" eventually in_view "$W2"
# shellcheck disable=SC2046
move $(center_of "$W1")
check "⌃⌥↓ again" pressed ctrl+opt+down in
check "the window under the pointer fills the screen" eventually fills "$W1"
check "⌃⌥↑ reaches Arbor" pressed ctrl+opt+up out
check "its row is back" eventually in_view "$W2"
check "⌃⌥↑ again" pressed ctrl+opt+up out
check "everything is back" eventually camera_on root
settled

claim "⌃⌥→ and ⌃⌥← go to the neighbouring space, ⌃⌥⇧↓ and ⌃⌥⇧↑ to the one below and above"
proves T33
ctl zoom "$W1"
check "the first window fills the screen" eventually fills "$W1"
check "⌃⌥→ reaches Arbor" pressed ctrl+opt+right neighbor right
check "the camera is on the Desktop, its neighbour" eventually camera_on desktop
check "⌃⌥→ again" pressed ctrl+opt+right neighbor right
check "the second window fills the screen" eventually fills "$W2"
check "⌃⌥← reaches Arbor" pressed ctrl+opt+left neighbor left
check "the camera is back on the Desktop" eventually camera_on desktop
# With no window that way in view they go to the neighbouring space.
check "⌃⌥⇧↓ reaches Arbor" pressed ctrl+opt+shift+down focus down
check "the window below fills the screen" eventually fills "$W3"
check "⌃⌥⇧↑ reaches Arbor" pressed ctrl+opt+shift+up focus up
check "the window below has left again" eventually out_of_view "$W3"
ctl show-all

claim "⌃⌥⇧ and a digit save a view, ⌃⌥ and the digit recall it"
proves T35
ctl zoom "$W2"
check "⌃⌥⇧1 reaches Arbor" pressed ctrl+opt+shift+1 save-view 1
ctl show-all
check "⌃⌥⇧2 reaches Arbor" pressed ctrl+opt+shift+2 save-view 2
check "⌃⌥1 reaches Arbor" pressed ctrl+opt+1 view 1
check "the saved window fills the screen" eventually fills "$W2"
check "the others are out of view" eventually out_of_view "$W1"
check "⌃⌥2 reaches Arbor" pressed ctrl+opt+2 view 2
check "everything is in view" eventually camera_on root
check "the first window is back" eventually in_view "$W1"
settled

claim "⌃⌥D shows the Desktop alone"
proves T52
check "⌃⌥D reaches Arbor" pressed ctrl+opt+d desktop
check "the first window is out of view" eventually out_of_view "$W1"
check "the second window is out of view" eventually out_of_view "$W2"
check "the third window is out of view" eventually out_of_view "$W3"
ctl show-all
check "they all come back" eventually in_view "$W3"

claim "⌃⌥F floats the focused window and docks it again"
click_window "$W2"
check "⌃⌥F reaches Arbor" pressed ctrl+opt+f toggle-float
check "the window floats" eventually is floating "$W2"
check "⌃⌥F again" pressed ctrl+opt+f toggle-float
check "the window is docked" eventually is docked "$W2"
settled

claim "Arrange Windows docks every window"
proves T16
ctl float-all
check "nothing is docked" eventually count docked 0
check "arrange succeeds" ctl arrange
check "all three are docked" eventually count docked 3
check "nothing overlaps" eventually no_overlaps
check "the first window is in view" eventually in_view "$W1"
settled

claim "the app with the keyboard sees none of Arbor's shortcuts"
check "the first window got no key press" test "$(events_of "$W1" key)" = 0
check "the second window got no key press" test "$(events_of "$W2" key)" = 0
check "the third window got no key press" test "$(events_of "$W3" key)" = 0

claim "⌃⌥A is the app's, in the whole map too"
click_window "$W1"
key_to "$W1" ctrl+opt+a
check "the app with the keyboard gets the key" eventually received "$W1" key -gt 0
check "Arbor arranges nothing" stays fails ran arrange

# Whatever features add to the defaults is pressed too. Only that Arbor runs the command is checked: what each
# does has its own step, here or in its feature's section.
# Blind, so not on a person's Mac: a new default may open a panel, summon an app or show a file.
if on_throwaway_mac; then
  claim "every shortcut in arborctl bindings reaches Arbor"
  proves A03
  click_window "$W1"
  "$ARBOR_BIN/arborctl" bindings | grep "^[a-z].* → " | sed 's/ *→ */ /' > "$ARBOR_SESSION_DIR/bindings"
  # Descriptor 4, so that nothing inside the loop can read the list away.
  while read -r chord command <&4; do
    # Paused, Arbor would let go of all the others: 45-pause.sh presses that one.
    # What is about settings is logged in words of its own, and opens a window: 82-settings-commands.sh.
    case "$command" in quit | toggle-pause | pause* | resume | settings*) continue ;; esac
    # shellcheck disable=SC2086
    check "$chord runs $command" pressed "$chord" $command
  done 4< "$ARBOR_SESSION_DIR/bindings"
fi
ctl show-all

arbor_stop
