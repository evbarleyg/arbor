#!/bin/bash
# settings.json: shortcuts of one's own, rules for new windows, and reload-settings.
# A03 configurable shortcuts, A04 rules for new windows per app.
source "$(dirname "$0")/../lib.sh"
arbor_build
arbor_start 2 ARBOR_NO_HOTKEYS=0

claim "add a shortcut to settings.json and reload: it works"
proves A03
click_window "$W1"
key_to "$W1" ctrl+opt+cmd+h
check "before, ⌃⌥⌘H means nothing to Arbor" stays fails ran dock left
arbor_settings '{"bindings": {"ctrl+opt+cmd+h": "dock left", "ctrl+opt+d": null, "ctrl+opt+space": "desktop"}}'
check "reload-settings succeeds" ctl reload-settings
check "⌃⌥⌘H runs dock left" pressed ctrl+opt+cmd+h dock left
check "the focused window docked at the left edge" eventually at_edge "$W1" left
settled

claim "remove a default shortcut with null: Arbor no longer takes the key"
proves A03
keys=$(events_of "$W1" key)
# Arbor does not take it, so it goes to whatever has the keyboard: that has to be the test window.
key_to "$W1" ctrl+opt+d
check "⌃⌥D does not reach Arbor" stays fails ran desktop
check "the app with the keyboard gets the key instead" eventually received "$W1" key -gt "$keys"
check "the camera stayed" camera_on root

claim "give a default shortcut another command"
proves A03
check "⌃⌥Space runs desktop now" pressed ctrl+opt+space desktop
check "the docked window left the screen" eventually out_of_view "$W1"
ctl show-all

claim "arborctl bindings lists the shortcuts in effect"
proves A03
"$ARBOR_BIN/arborctl" bindings > "$ARBOR_SESSION_DIR/bindings"
check "the new one" grep -q "ctrl+opt+cmd+h *→ dock left" "$ARBOR_SESSION_DIR/bindings"
check "the changed one" grep -q "ctrl+opt+space *→ desktop" "$ARBOR_SESSION_DIR/bindings"
check "not the removed one" fails grep -q "ctrl+opt+d " "$ARBOR_SESSION_DIR/bindings"

claim "an entry that cannot be used is reported, and the rest still apply"
proves A03
arbor_settings '{"bindings": {"ctrl+opt+cmd+j": "frobnicate", "ctrl+opt+cmd+k": "dock right", "x": "quit"}}'
ctl reload-settings
check "arborctl bindings says which was skipped" eventually sh -c "'$ARBOR_BIN/arborctl' bindings | grep -q 'skipped ctrl+opt+cmd+j'"
check "and the one that would get in the way of typing" sh -c "'$ARBOR_BIN/arborctl' bindings | grep -q 'skipped x'"
check "the log says so too" logged "bindings: skipped ctrl+opt+cmd+j"
click_window "$W1"
check "the good entry works" pressed ctrl+opt+cmd+k dock right
check "the focused window moved to the right edge" eventually at_edge "$W1" right
check "the default that had been removed is back" pressed ctrl+opt+d desktop
ctl show-all

claim "change the gap in settings.json and reload: the windows are laid out again"
arbor_settings '{"gap": 30}'
ctl reload-settings
check "the docked window is 30 points from the edge" eventually at_edge "$W1" right
check "and from the top" eventually at_edge "$W1" top
settled

claim "settings.json with a typo: reloading says where it is, and the settings in use stay"
proves T72
printf '{"gap": ' > "$ARBOR_HOME/settings.json"
check "reload-settings fails" fails ctl reload-settings
check "it says where the typo is" says "line 1, column 9" arborctl reload-settings
check "the gap stays as it was" stays at_edge "$W1" right
check "the file is left as the person wrote it" test "$(cat "$ARBOR_HOME/settings.json")" = '{"gap": '
arbor_stop

arbor_settings "{\"rules\": [
  {\"app\": \"$ARBOR_TEST_BUNDLE\", \"title\": \"Inbox\", \"action\": \"dock left\"},
  {\"app\": \"$ARBOR_TEST_BUNDLE\", \"title\": \"notes\", \"action\": \"dock beside $ARBOR_TEST_BUNDLE bottom\"},
  {\"app\": \"$ARBOR_TEST_BUNDLE\", \"title\": \"Palette\", \"action\": \"ignore\"},
  {\"app\": \"$ARBOR_TEST_BUNDLE\", \"title\": \"Scratch\", \"action\": \"float\"},
  {\"app\": \"$ARBOR_TEST_BUNDLE\", \"action\": \"sideways\"},
  {\"app\": \"$ARBOR_TEST_BUNDLE\", \"title\": \"Arbor Test\", \"action\": \"dock right\"}
]}"
arbor_start 2

claim "windows that were open when Arbor started are not touched by rules"
proves A04
check "the first floats, though a rule matches its title" is floating "$W1"
check "the second too" is floating "$W2"
check "nothing is docked" count docked 0

claim "a new window whose title matches a dock rule docks at that edge"
proves A04
open_window N1 size=400x300 title=Inbox - 3 unread
check "it is docked" eventually is docked "$N1"
check "at the left edge" eventually at_edge "$N1" left
check "the log says which rule" logged "rule 1 ($ARBOR_TEST_BUNDLE: dock left)"
settled

claim "a new window with a dock beside rule docks beside that app's docked window"
proves A04
open_window N2 size=400x300 title=My Notes
check "it is docked" eventually is docked "$N2"
check "below the docked window" eventually above "$N1" "$N2"
check "in its column" eventually same_column "$N1" "$N2"
settled

claim "a new window with an ignore rule is left alone"
proves A04
take "x y" desktop_point
open_window N3 size=300x200 "at=$((x - 150)),$((y - 200))" title=Palette
check "Arbor does not arrange it" stays fails is managed "$N3"
ctl arrange
check "arranging everything leaves it where it was" stays corner_is "$N3" "$((x - 150))" "$((y - 200))"
ctl float-all

claim "a new window with a float rule, or with no rule, floats"
proves A04
open_window N4 size=300x200 title=Scratch
check "the one with the float rule floats" eventually is floating "$N4"
open_window N5 size=300x200 title=Something else
check "the one no rule matches floats" eventually is floating "$N5"

claim "the first matching rule wins, and a later window of a kind open at launch is docked"
proves A04
open_window N6 size=300x200 title=Arbor Test 9
check "it is docked" eventually is docked "$N6"
check "at the right edge" eventually at_edge "$N6" right
settled

claim "arborctl rules lists the rules and what was skipped"
proves A04
"$ARBOR_BIN/arborctl" rules > "$ARBOR_SESSION_DIR/rules"
cat "$ARBOR_SESSION_DIR/rules"
check "the rules in order" grep -q "1. $ARBOR_TEST_BUNDLE, title contains \"Inbox\" → dock left" "$ARBOR_SESSION_DIR/rules"
check "the entry with an unknown action, and why" grep -q "entry 5 ($ARBOR_TEST_BUNDLE): unknown action" "$ARBOR_SESSION_DIR/rules"

arbor_stop
