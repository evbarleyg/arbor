#!/bin/bash
# A window goes and macOS names one that Arbor keeps out of view: who gets the keyboard, which view moves, and whose display the next
# key means.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-a-going-on-two-displays.sh
#
# What only a Mac can say: whom macOS names after ⌘W; whether an app on the other display comes forward when Arbor asks for it; and
# whether macOS's count of key presses tells Arbor's own shortcut from a letter typed into the window that got the keyboard.
#
# Who has the keyboard is taken neither from Arbor's word nor from who is in front: a plain j is typed, and the test window that
# counted it had the keyboard. A letter typed there also ends "the next key, once", so in those stories the j comes after the shortcut,
# and until then Arbor is only asked, which ends nothing. The shortcut is ⌃⌥Space, tapped: of the nine keys that ship, the one about the view.
#
# The first part has one display and touches nothing but its own test windows, the pointer and the keyboard. The rest plugs in a
# virtual display, so it runs only on GitHub's Macs.
source "$(dirname "$0")/lib.sh"

arbor_build

# By the window server's word, not by Arbor's.
framed() { in_view "$1" && out_of_view "$2"; }
both_in_view() { in_view "$1" && in_view "$2"; }
runs() {
  local status
  status=$(arborctl status) || { echo "arborctl does not answer"; return 1; }
  case "$status" in running:*) ;; *) echo "it says: ${status%%$'\n'*}"; return 1 ;; esac
}
shortcut() {
  echo "  $(pointer activity)"
  key "$1"
}
# keyboard_in <id>: types a j. That window counted it, and no other did. Once: under `eventually` it would type again and again.
keyboard_in() {
  local id count before got
  before=$(for id in $ARBOR_WINDOW_IDS; do echo "$id $(events_of "$id" key)"; done)
  key j > /dev/null
  sleep 0.5
  got=$(echo "$before" | while read -r id count; do [ "$(events_of "$id" key)" -eq "$count" ] || printf '%s ' "$id"; done)
  [ "$got" = "$1 " ] || { echo "the j went to ${got:-nobody }and not to $1"; return 1; }
}
# ⌘W on the window that has the keyboard, which is then nobody's to ask.
closes() {
  key_to "$1" cmd+w || return 1
  forget_window "$1"
}

# One display. w1 is docked and out of view, the view is on the Desktop. On it: w3, v1 (the other app's) and w2, which has the keyboard.
# In their own app's order w1 comes right behind w2, so it is w1 that macOS names. Of the two in view v1 was used last.
one_display() {
  ARBOR_SECOND_APP=1
  arbor_start 3 ARBOR_NO_HOTKEYS=0
  ctl dock "$W1" left
  click_window "$W3"
  click_window "$W1"
  click_window "$W2"
  check "w2 has the keyboard" eventually is focused "$W2"
  ctl desktop
  check "w1 is out of view" eventually out_of_view "$W1"
  click_window "$V1"
  check "the other app's window has been used" eventually is focused "$V1"
  click_window "$W2"
  check "w2 has the keyboard again" eventually is focused "$W2"
}

step "One display, both lists empty: the window in view that was used last gets the keyboard. The control for what follows"
one_display
closes "$W2"
check "w1 stays out of view" stays out_of_view "$W1"
check "a j lands in the other app's window" keyboard_in "$V1"
shot 01-the-one-used-last
arbor_stop

step "The same, and Arbor pauses for the other app: it is nobody's heir"
one_display
ctl set pauseForApps add "$ARBOR_TEST_BUNDLE_2"
closes "$W2"
check "w1 stays out of view" stays out_of_view "$W1"
check "Arbor goes on running" runs
check "a j lands in w3, the next in the order" keyboard_in "$W3"
shot 02-not-the-app-arbor-pauses-for

step "A key of Arbor's held down: were it to repeat, the first press would be the next key and each repeat the key after it"
mark=$(arbor_log_lines)
key "ctrl+opt+[" --down
key "ctrl+opt+[" --repeat 10
key "ctrl+opt+[" --up
sleep 0.5
times=$(arbor_log_since "$mark" | grep -c -e "INFO  back: " -e "DEBUG back failed: ")
echo "⌃⌥[ down, ten auto-repeats, up: back ran $times time(s)"
check "it runs its command once" test "$times" -eq 1
arbor_stop

echo
# Not needs_throwaway_mac: its exit code would hide a check that failed above.
if ! on_throwaway_mac; then
  echo "skipped: the rest would plug in a virtual second display, and this Mac is somebody's."
  exit 0
fi

# 64 is what a rehearsal ends with where the fake Mac lacks something. It has one display.
if [ -n "${ARBOR_REHEARSAL_DIR:-}" ]; then
  echo "the rest cannot be rehearsed: the fake Mac has no second display"
  exit 64
fi

display_add 1280 800 right

# Two displays. On the main one v1 is framed and v2 out of view beside it. On the second w2 floats and has the keyboard. w1, which macOS will
# name, is docked and out of view: beside v1 and v2 (`main`), or on the second display, whose view is on its Desktop (`second`).
# The pointer is left to rest on the display that the story does not expect, so that it is not the pointer that says which.
two_displays() {
  local pick=$1 pointer_rests=$2
  ARBOR_SECOND_APP=2
  arbor_start 2 ARBOR_NO_HOTKEYS=0
  ctl dock "$V1" left
  ctl dock "$V2" right
  # shellcheck disable=SC2046
  drag_window "$W2" $(arbor_point $(screen_of 2) "x + w / 3" "y + 120")
  check "w2 is on the second display" eventually is display2 "$W2"
  if [ "$pick" = second ]; then
    # shellcheck disable=SC2046
    drag_window "$W1" $(arbor_point $(screen_of 2) "x + 2 * w / 3" "y + 200")
    check "w1 is on the second display" eventually is display2 "$W1"
    ctl dock "$W1" left
    click_window "$W2"
    check "w2 has the keyboard" eventually is focused "$W2"
    ctl desktop
  else
    ctl dock "$W1" beside "$V2" bottom
  fi
  ctl zoom "$V1"
  check "v1 is framed on the main display" eventually framed "$V1" "$V2"
  check "w1 is out of view" eventually out_of_view "$W1"
  click_window "$W2"
  check "w2 has the keyboard" eventually is focused "$W2"
  # shellcheck disable=SC2046
  [ "$pointer_rests" = second ] || move $(center_of "$V1")
  # Whichever was touched last leads, and the pointer has just been.
  key j
  sleep 0.3
}

step "Two displays: the last window on one goes, and no view moves on the other"
two_displays main main
closes "$W2"
check "the main display's view stays: v1 framed, v2 out of view" stays framed "$V1" "$V2"
check "w1, which macOS named, stays out of view" out_of_view "$W1"
check "a j lands in v1, on the other display" keyboard_in "$V1"
panorama 03-no-view-moves
arbor_stop

step "The next key means the display where the window went, and the window it brings into view there gets the keyboard"
two_displays second main
closes "$W2"
check "v1 has the keyboard, by Arbor's word" eventually is focused "$V1"
shortcut ctrl+opt+space
check "⌃⌥Space shows everything on the second display: w1 is in view" eventually in_view "$W1"
check "the main display's view stays" stays framed "$V1" "$V2"
check "a j lands in w1" keyboard_in "$W1"
panorama 04-the-display-where-the-window-went
arbor_stop

step "Once: the key after it means the display the keyboard is on"
two_displays main second
closes "$W2"
check "v1 has the keyboard, by Arbor's word" eventually is focused "$V1"
shortcut ctrl+opt+space
check "⌃⌥Space finds nothing to show on the second display, and the main display's view stays" stays framed "$V1" "$V2"
shortcut ctrl+opt+space
check "⌃⌥Space again shows everything on the main display" eventually both_in_view "$V1" "$V2"
check "a j lands in v1" keyboard_in "$V1"
panorama 05-once
arbor_stop

step "A letter typed into the window that got the keyboard ends it"
two_displays second second
closes "$W2"
# Not before the keyboard is there: a j on its way would land elsewhere, or be counted before the hand-over.
check "v1 has the keyboard, by Arbor's word" eventually is focused "$V1"
check "a j lands in v1" keyboard_in "$V1"
shortcut ctrl+opt+space
check "⌃⌥Space shows everything on the main display" eventually both_in_view "$V1" "$V2"
check "and w1 stays out of view on the second" stays out_of_view "$W1"
panorama 06-a-letter-ends-it
arbor_stop
