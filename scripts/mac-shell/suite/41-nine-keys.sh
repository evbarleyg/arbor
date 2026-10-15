#!/bin/bash
# The nine keys Arbor ships with, pressed for real with a window of another app in front as the witness: each acts, and none reaches
# the app. What the whole map took besides is the app's again: it arrives there, and Arbor does nothing.
# A122 nine keys.
ARBOR_SWITCHES=shipped  # it is about the keys that ship
source "$(dirname "$0")/../lib.sh"
arbor_build
arbor_start 3 ARBOR_NO_HOTKEYS=0

# acts <window with the keyboard> <keys> <command…>: Arbor runs the command, and the window hears nothing of the key.
acts() {
  local witness=$1 chord=$2 before
  shift 2
  before=$(events_of "$witness" key)
  pressed "$chord" "$@" || return 1
  sleep 0.3
  received "$witness" key -eq "$before"
}
# arrives <window with the keyboard> <keys>: the window gets the key, and Arbor runs nothing. Whether it has the keyboard is not asked of Arbor,
# which knows no window during a pause: a window that counts the key had it.
arrives() {
  local before mark
  before=$(events_of "$1" key)
  mark=$(arbor_log_lines)
  key "$2" || return 1
  eventually received "$1" key -gt "$before" || return 1
  if arbor_log_since "$mark" | grep -E "INFO  [a-z-]+( [a-z0-9-]+)*: |DEBUG .* failed: "; then echo "Arbor ran something"; return 1; fi
}

claim "as it ships Arbor registers nine shortcuts, each ⌃⌥ and one key"
proves A122
shortcuts=$(ctl bindings | grep -c "^[a-z].* → ")
check "arborctl bindings lists nine" test "$shortcuts" = 9
check "none has a third modifier" test "$(arborctl bindings | grep -cE "^ctrl\+opt\+(shift|cmd)\+")" = 0
check "all of them were registered with macOS" grep -q "registered 9 shortcuts" "$ARBOR_HOME/arbor.log"

claim "⌃⌥← and ⌃⌥→ dock the window in front, and the app hears nothing"
proves A122
click_window "$W1"
check "the click gave the window the keyboard" eventually is focused "$W1"
check "⌃⌥← is Arbor's alone" acts "$W1" ctrl+opt+left dock left
check "the window is docked at the left edge" eventually at_edge "$W1" left
click_window "$W2"
check "⌃⌥→ is Arbor's alone" acts "$W2" ctrl+opt+right dock right
check "the other window is docked at the right edge" eventually at_edge "$W2" right
check "nobody asked for the third" is floating "$W3"
settled

claim "⌃⌥↩ frames and goes back, ⌃⌥Space shows everything, ⌃⌥[ goes back"
proves A122
check "⌃⌥↩ is Arbor's alone" acts "$W2" ctrl+opt+return zoom
check "the window fills the screen" eventually fills "$W2"
check "⌃⌥↩ again" acts "$W2" ctrl+opt+return zoom
check "the first window is back in view" eventually in_view "$W1"
check "⌃⌥↩ once more" acts "$W2" ctrl+opt+return zoom
check "⌃⌥Space is Arbor's alone" acts "$W2" ctrl+opt+space show-all
check "the camera is on everything" eventually camera_on root
check "⌃⌥[ is Arbor's alone" acts "$W2" "ctrl+opt+[" back
check "the window fills the screen again" eventually fills "$W2"
check "⌃⌥Space" acts "$W2" ctrl+opt+space show-all
settled

claim "⌃⌥F floats, ⌃⌥Z takes it back, ⌃⌥G is Go to…"
proves A122
check "⌃⌥F is Arbor's alone" acts "$W2" ctrl+opt+f toggle-float
check "the window floats" eventually is floating "$W2"
check "⌃⌥Z is Arbor's alone" acts "$W2" ctrl+opt+z undo
check "the window is docked again" eventually is docked "$W2"
check "⌃⌥G is Arbor's alone" acts "$W2" ctrl+opt+g find
shot nine-keys-go-to
key escape
click_window "$W2"
settled

claim "⌃⌥⎋ pauses and resumes; in the pause the others are the app's"
proves A122
keys=$(events_of "$W2" key)
key ctrl+opt+escape
check "⌃⌥⎋ reaches Arbor" eventually logged "INFO  paused"
check "Arbor is paused" eventually says "paused" arborctl status
check "and not the app" received "$W2" key -eq "$keys"
click_window "$W2"
# Not ⌃⌥Space: where several input sources are on it is macOS's then, and arrives nowhere.
for chord in ctrl+opt+left ctrl+opt+right ctrl+opt+return "ctrl+opt+[" ctrl+opt+z ctrl+opt+f ctrl+opt+g; do
  check "$chord arrives in the app" arrives "$W2" "$chord"
done
keys=$(events_of "$W2" key)
key ctrl+opt+escape
check "⌃⌥⎋ still reaches Arbor" eventually logged "INFO  resumed"
check "Arbor runs again" eventually fails says "paused" arborctl status
check "and not the app" received "$W2" key -eq "$keys"
check "the window is docked as before" eventually is docked "$W2"
settled

claim "what the whole map took besides is the app's again"
proves A122
click_window "$W2"
for chord in ctrl+opt+a ctrl+opt+d ctrl+opt+up ctrl+opt+down "ctrl+opt+]" ctrl+opt+0 ctrl+opt+1 ctrl+opt+m ctrl+opt+n ctrl+opt+r \
  ctrl+opt+, ctrl+opt+shift+1 ctrl+opt+shift+f ctrl+opt+shift+z ctrl+opt+shift+/ ctrl+opt+shift+left ctrl+opt+cmd+left \
  ctrl+opt+cmd+right ctrl+opt+cmd+0; do
  check "$chord arrives in the app" arrives "$W2" "$chord"
done
check "nothing moved" is docked "$W2"
settled

claim "the panel of shortcuts has the nine, and says where the rest is"
proves A122
panel=$(arborctl show-shortcuts)
echo "$panel"
check "nine lines begin with ⌃⌥" test "$(echo "$panel" | grep -c "^  ⌃⌥")" = 9
check "none has ⇧ or ⌘" test "$(echo "$panel" | grep -cE "^  ⌃⌥(⇧|⌘)")" = 0
check "⌃⌥← docks" says "⌃⌥←" echo "$panel"
shot nine-keys-panel
key escape

claim "held, ⌃⌥Space peeks: all four arrows are Arbor's for as long, dock nothing, and ⌃⌥↑ is the app's again afterwards"
proves A122
click_window "$W2"
check "⌃⌥↩ frames the window" pressed ctrl+opt+return zoom
check "it fills the screen" eventually fills "$W2"
keys=$(events_of "$W2" key)
key ctrl+opt+space --down
sleep 0.6
key ctrl+opt+up --held
key ctrl+opt+left --held
key ctrl+opt+left --held
check "Arbor docked nothing" stays fails ran dock
key ctrl+opt+space --up
check "letting go frames the window two to the left" eventually fills "$W1"
check "the app heard none of it" received "$W2" key -eq "$keys"
click_window "$W1"
check "⌃⌥↑ arrives in the app" arrives "$W1" ctrl+opt+up
check "⌃⌥Space" pressed ctrl+opt+space show-all
settled

claim "one setting brings the whole map back, at once, and takes it away again"
proves A122
check "set shortcuts all succeeds" ctl set shortcuts all
click_window "$W1"
check "⌃⌥D is Arbor's alone" acts "$W1" ctrl+opt+d desktop
check "⌃⌥Space" pressed ctrl+opt+space show-all
click_window "$W1"
check "⌃⌥A is the app's there too" arrives "$W1" ctrl+opt+a
check "set shortcuts core succeeds" ctl set shortcuts core
check "⌃⌥D arrives in the app" arrives "$W1" ctrl+opt+d

arbor_stop
