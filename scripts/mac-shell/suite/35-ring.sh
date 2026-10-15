#!/bin/bash
# The focus ring: a line around the window that will take what is typed.
# A15 focus ring around the focused window.
source "$(dirname "$0")/../lib.sh"
arbor_build
# Where macOS tiles at the screen's edges they are macOS's, and what is docked there below is docked by command.
if screen_edges_dock; then edges=ours; else edges=""; fi

# The ring is a panel of Arbor's own that spans its window and a little more: the line, which lies in the gap, and room for
# the flash. Seams are at the ordinary level too, but a gap wide; there are no tiles in this section.
rings() { overlays | awk '$3 == 0 && $8 == "on" && $6 > 60 && $7 > 60'; }
no_ring() {
  local shown
  shown=$(rings)
  [ -z "$shown" ] || { echo "Arbor shows: $(echo "$shown" | head -n 1)"; return 1; }
}
# ring_around <id>: there is one ring, it holds all of the window as the window server has it, and reaches at most 20 points
# beyond it on any side.
ring_around() {
  local frame shown
  frame=$(real_frame_of "$1") || { echo "the window server has no such window"; return 1; }
  shown=$(rings)
  [ "$(printf '%s' "$shown" | grep -c .)" -eq 1 ] || { echo "not one ring: ${shown:-none}"; return 1; }
  printf '%s\n' "$shown" | awk -v frame="$frame" '
    function near(beyond) { return beyond >= 0 && beyond <= 20 }
    BEGIN { split(frame, f, " ") }
    near(f[1] - $4) && near(f[2] - $5) && near($4 + $6 - f[1] - f[3]) && near($5 + $7 - f[2] - f[4]) { found = 1 }
    END { exit !found }' && return 0
  echo "the window is at $frame, the ring at $(echo "$shown" | awk '{ print $4, $5, $6, $7 }')"
  return 1
}
# Directly in front of its window, as if it were part of it: further back it could not be seen, further forward it would
# cut across whatever covers the window.
ring_in_front_of() {
  local ring
  ring=$(rings | awk '{ print $1; exit }')
  [ -n "$ring" ] || { echo "there is no ring"; return 1; }
  "$ARBOR_POINTER" windows --on-screen | awk -v ring="$ring" -v window="$1" \
    '$3 == 0 { if ($1 == window) { ok = (previous == ring); exit } previous = $1 } END { exit !ok }' \
    || { echo "something else is directly in front of the window"; return 1; }
}
nothing_of() {
  local left
  left=$("$ARBOR_POINTER" windows --pid "$1")
  [ -z "$left" ] || { echo "still there: $(echo "$left" | head -n 1)"; return 1; }
}
# at_rest <id>…: none of them has moved for a third of a second, by the window server.
at_rest() {
  local id before="" after=""
  for id in "$@"; do before="$before$(real_frame_of "$id");"; done
  sleep 0.35
  for id in "$@"; do after="$after$(real_frame_of "$id");"; done
  [ "$before" = "$after" ] || { echo "they were at $before and are at $after"; return 1; }
}
paused() { "$ARBOR_BIN/arborctl" status | grep "^paused" > /dev/null || { echo "Arbor is not paused"; return 1; }; }
running() { "$ARBOR_BIN/arborctl" status | grep "^running" > /dev/null || { echo "Arbor is not running"; return 1; }; }
# types_into <id>: a letter typed now arrives in that window.
types_into() {
  local keys
  keys=$(events_of "$1" key) || return 1
  key_to "$1" x || return 1
  eventually received "$1" key -gt "$keys"
}

# A short session of its own with two apps, for what moves the keyboard without any doing of Arbor's.
ARBOR_SECOND_APP=1
if on_throwaway_mac; then
  # In the Dock and in ⌘Tab, like a person's apps. On a person's Mac they could stay among the Dock's recent apps.
  ARBOR_TEST_WINDOWS_ARGS="--regular"
  ARBOR_SECOND_APP_ARGS="--regular"
  # By default a click on the wallpaper sweeps every window aside, and the next one only brings them back.
  macos_click_wallpaper off
  at_exit 'macos_click_wallpaper on > /dev/null'
fi
arbor_start 2
ctl dock "$W1" left
ctl dock "$W2" beside "$W1" bottom
ctl dock "$V1" right
summary

claim "another app brings its window forward: the focus ring goes to it, and back with a click"
proves A15
click_window "$W1"
check "the ring is around the first app's window" eventually ring_around "$W1"
tw2 activate "$V1"
check "the other app is in front" eventually front_is "$ARBOR_WINDOWS_PID_2"
check "the ring is around its window" eventually ring_around "$V1"
check "directly in front of it" eventually ring_in_front_of "$V1"
check "that is the window that takes the typing" types_into "$V1"
click_window "$W1"
check "the ring is back around the first app's window" eventually ring_around "$W1"
check "no window moved for it" layout_matches

# On a person's Mac ⌘Tab leads to whichever app of theirs was in front last, and a click on the wallpaper sweeps their windows aside.
if on_throwaway_mac; then
  claim "⌘Tab to another app and back: the focus ring is around the window that takes the typing"
  proves A15
  click_window "$V1"
  click_window "$W1"
  check "the ring is around the first app's window" eventually ring_around "$W1"
  key cmd+tab
  check "the other app is in front" eventually front_is "$ARBOR_WINDOWS_PID_2"
  check "the ring is around its window" eventually ring_around "$V1"
  check "which takes the typing" types_into "$V1"
  key cmd+tab
  check "the first app is in front again" eventually front_is "$ARBOR_WINDOWS_PID"
  check "the ring is back around its window" eventually ring_around "$W1"
  check "which takes the typing" types_into "$W1"

  # The fake Mac does not know ⌘`: in a rehearsal the app brings the window forward itself, and only the key goes unplayed.
  next_window() { if [ -n "${ARBOR_REHEARSAL:-}" ]; then tw activate "$2"; else key_to "$1" 'cmd+`'; fi; }
  claim "⌘ and the key above Tab, to the app's other window and back: the focus ring goes along"
  proves A15
  next_window "$W1" "$W2"
  check "the app's other window has the keyboard" eventually is focused "$W2"
  check "the ring is around it" eventually ring_around "$W2"
  check "the first has lost it" fails ring_around "$W1"
  next_window "$W2" "$W1"
  check "the first window has the keyboard again" eventually is focused "$W1"
  check "the ring is back around it" eventually ring_around "$W1"

  claim "click the Desktop: no window takes the typing and the focus ring is gone, and a click on a window brings it back"
  proves A15
  check "the ring is around the window that has the keyboard" eventually ring_around "$W1"
  # shellcheck disable=SC2046
  click $(desktop_point)
  check "the app that had the keyboard is no longer in front" eventually fails front_is "$ARBOR_WINDOWS_PID"
  check "nor is the other" fails front_is "$ARBOR_WINDOWS_PID_2"
  check "there is no ring" eventually no_ring
  check "and none comes back" stays no_ring
  check "no window moved for it" layout_matches
  click_window "$W1"
  check "the ring is around the clicked window" eventually ring_around "$W1"
fi

arbor_stop
ARBOR_SECOND_APP=0
ARBOR_TEST_WINDOWS_ARGS=""
ARBOR_SECOND_APP_ARGS=""

arbor_start 4 ARBOR_NO_HOTKEYS=0

claim "click a window before anything is docked: there is no focus ring"
proves A15
click_window "$W3"
check "the window has the keyboard" eventually is focused "$W3"
check "Arbor draws nothing around it" stays no_ring

claim "dock the window that has the keyboard: once docked it wears the focus ring"
proves A15
# shellcheck disable=SC2046
if [ -n "$edges" ]; then drag_window "$W1" $(edge_point left); else click_window "$W1"; ctl dock "$W1" left; fi
check "it docked at the left edge" eventually at_edge "$W1" left
check "the ring is around it" eventually ring_around "$W1"
check "directly in front of it" eventually ring_in_front_of "$W1"
settled

ctl dock "$W2" right
ctl dock "$W3" beside "$W2" bottom
summary

claim "click another docked window: the focus ring follows the click"
proves A15
click_window "$W1"
check "the ring is around the first window" eventually ring_around "$W1"
click_window "$W2"
check "the ring is around the second window" eventually ring_around "$W2"
check "directly in front of it" eventually ring_in_front_of "$W2"
check "the first window has lost it" fails ring_around "$W1"
check "no window moved for it" layout_matches

claim "click a floating window: it gets the focus ring too"
proves A15
click_window "$W4"
check "it floats" is floating "$W4"
check "the ring is around it" eventually ring_around "$W4"
check "directly in front of it" eventually ring_in_front_of "$W4"
# It would be in view with the Desktop, further down, and take the keyboard there.
tw close "$W4"
forget_window "$W4"

claim "⌃⌥↩ and ⌃⌥⇧↓ take the keyboard from window to window: the focus ring goes along"
proves A15
click_window "$W2"
check "⌃⌥↩ reaches Arbor" pressed ctrl+opt+return zoom
check "the framed window fills the screen" eventually fills "$W2"
check "the ring is around it there" eventually ring_around "$W2"
check "⌃⌥⇧↓ reaches Arbor" pressed ctrl+opt+shift+down focus down
check "the window below fills the screen" eventually fills "$W3"
check "it has the keyboard" eventually is focused "$W3"
check "the ring is around it" eventually ring_around "$W3"
check "⌃⌥Space reaches Arbor" pressed ctrl+opt+space show-all
check "the ring shrinks with its window" eventually ring_around "$W3"
settled

claim "⌃⌥⌘← moves the focused window: the focus ring moves with it"
proves A15
check "⌃⌥⌘← reaches Arbor" pressed ctrl+opt+cmd+left dock left
check "the window has left its column" eventually fails same_column "$W2" "$W3"
check "the ring is around it in its new place" eventually ring_around "$W3"
ctl dock "$W3" beside "$W2" bottom
settled

claim "click into the window that wears the focus ring, and on its yellow button: the ring lets both clicks through"
proves A15
click_window "$W1"
check "the ring is around the window" eventually ring_around "$W1"
downs=$(events_of "$W1" down)
click_window "$W1"
check "the app got the click into its window" eventually received "$W1" down -gt "$downs"
check "the ring is still directly in front of it" eventually ring_in_front_of "$W1"
click_button "$W1" minimize
check "the app got the click on the button: the window is minimized" eventually is minimized "$W1"
check "the ring has left it" eventually fails ring_around "$W1"
tw restore "$W1"
check "it is back in its slot" eventually in_slot "$W1"
settled

claim "drag the window that wears the focus ring: the ring hides while the button is down and comes back"
proves A15
click_window "$W1"
check "the ring is around the window" eventually ring_around "$W1"
# shellcheck disable=SC2046
drag_window "$W1" $(desktop_point) --no-release
check "the press got through the ring: the window follows the pointer" eventually fails in_slot "$W1"
check "there is no ring during the drag" stays no_ring
release
check "the ring is around the window where it was dropped" eventually ring_around "$W1"
ctl dock "$W1" left
settled

claim "⌃⌥D sends the focused window out of view: the focus ring goes with it, and ⌃⌥Space brings both back"
proves A15
click_window "$W1"
check "the ring is around the window" eventually ring_around "$W1"
check "⌃⌥D reaches Arbor" pressed ctrl+opt+d desktop
check "the window is out of view" eventually out_of_view "$W1"
check "there is no ring" eventually no_ring
check "and none comes back" stays no_ring
check "⌃⌥Space reaches Arbor" pressed ctrl+opt+space show-all
check "the window is back in view" eventually in_view "$W1"
check "the ring is around it again" eventually ring_around "$W1"
settled

claim "switch focusRing off by command: the ring is gone, and switching it on brings it back"
proves A15
click_window "$W2"
check "the ring is around the window" eventually ring_around "$W2"
second=$(real_frame_of "$W2")
check "set focusRing false succeeds" ctl set focusRing false
check "there is no ring" eventually no_ring
click_window "$W1"
check "a click on another window brings none" stays no_ring
# shellcheck disable=SC2086
check "the windows are where they were" frame_is "$W2" $second
check "set focusRing true succeeds" ctl set focusRing true
check "the ring is around the window that has the keyboard now" eventually ring_around "$W1"
settled

claim "⌃⌥⎋ pauses Arbor: the focus ring is gone, and back when Arbor resumes"
proves A15
key ctrl+opt+escape
check "Arbor is paused" eventually paused
check "there is no ring" eventually no_ring
# A pause gives the windows their own sizes and places back, where they lie over each other: a place to click is looked for once they rest.
check "the windows have come to rest" eventually at_rest "$W1" "$W2" "$W3"
downs=$(events_of "$W2" down)
click_window "$W2"
check "the click arrives in the second window" eventually received "$W2" down -gt "$downs"
check "a click on another window brings none" stays no_ring
key ctrl+opt+escape
check "Arbor runs again" eventually running
check "the ring is around the window that got the keyboard meanwhile" eventually ring_around "$W2"
settled

claim "quit Arbor: nothing is left of the focus ring"
proves A15
arbor=$ARBOR_PID
arbor_quit
check "the window server has no window of Arbor's any more" eventually nothing_of "$arbor"
check "the window that wore it is in view" eventually in_view "$W2"
