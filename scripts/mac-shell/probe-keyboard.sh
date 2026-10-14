#!/bin/bash
# Who has the keyboard when the window that had it goes out of view, and what if Arbor took it itself?
#
# On an empty Desktop (⌃⌥D with nothing floating) the keyboard stays in the window that has just left: ⌘W would close it
# unseen. The product owner's decision (collab/QUESTIONS.md): the remedy to try is that Arbor activates itself, so that
# keys go to nobody, and nothing is built before this has been seen on a Mac. Nothing here is a check of Arbor: the
# output is the point. Read keyboard.txt in the output folder; commit it as collab/evidence/keyboard.txt.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-keyboard.sh
#
# It answers:
#   1. Does the keyboard really stay in a window out of view?                       (section "the Desktop, empty")
#   2. With an accessory app active that has no window for the keyboard: who is in front, whose menus does the menu bar
#      show, where do keys go? Does the other app's window stop being the one keys go to?   ("the probe takes the keyboard")
#   3. Who gets the keyboard when that app ends, and does Arbor's ordinary focus bring it back?   ("afterwards", "back")
#   4. At which level is a popover that goes away by itself, and does it go when another app is activated? (F60 wants to know:
#      a click on the wallpaper that is kept from everybody leaves such a popover open if only leaving the app closes it.)
# It cannot say whether keys beep: that takes ears.
#
# SAFE ON SOMEBODY'S MAC: it presses nothing and clicks nothing there, takes no pictures, reads no titles, and calls every process
# but its own "other". It does bring its test windows forward, so the keyboard leaves the person's app for ten seconds;
# at the end the app that was in front is brought forward again. Only on a throwaway Mac does it also press ⌘W, through
# `key`, which declines unless the app in front is one this script started.
source "$(dirname "$0")/lib.sh"

arbor_build
WHO="$ARBOR_ROOT/.build/mac-shell/whohaskeys"
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/whohaskeys.swift" -o "$WHO" > "$ARBOR_OUT/build-whohaskeys.log" 2>&1 || {
  cat "$ARBOR_OUT/build-whohaskeys.log"
  die "scripts/mac-shell/whohaskeys.swift did not compile"
}
NOTES="$ARBOR_OUT/keyboard.txt"
# Theirs again at the end.
# safe anywhere: only the process's number is kept, in a variable that is never printed, to bring that app forward again
WAS_IN_FRONT=$(lsappinfo info -only pid "$(lsappinfo front 2> /dev/null)" 2> /dev/null | tr -dc 0-9)

# An ordinary app: an accessory app never owns the menu bar, and only with menus does ⌘W mean anything.
ARBOR_TEST_WINDOWS_ARGS=--regular
arbor_start 3
NAMES="test-windows=$ARBOR_WINDOWS_PID Arbor=$ARBOR_PID"

say() { echo "$*" | tee -a "$NOTES"; }
# shellcheck disable=SC2086
who() { say "  $1: $("$WHO" report $NAMES)"; }
# The test app's windows as the window server lists them, without their owner's name: id level x y w h on|off
listed() { "$ARBOR_POINTER" windows --pid "$ARBOR_WINDOWS_PID" | awk '{ print "    window", $1, "level", $3, "at", $4, $5, $6, $7, $8 }' | tee -a "$NOTES"; }
on_screen() { "$ARBOR_POINTER" windows --pid "$ARBOR_WINDOWS_PID" --on-screen | wc -l | tr -d ' '; }
# Which of the test windows are still open.
open_windows() {
  local id
  for id in $W1 $W2 $W3; do "$ARBOR_POINTER" windows --pid "$ARBOR_WINDOWS_PID" | awk -v id="$id" '$1 == id { printf "%s ", id }'; done
}
tell() { echo "$*" >&9; }
# shellcheck disable=SC2086
take() { "$WHO" take "$1" $NAMES | tee -a "$NOTES"; }

say "# probe-keyboard.sh $(date -u +%Y-%m-%dT%H:%MZ) on macOS $(sw_vers -productVersion), commit $(git rev-parse --short HEAD)"
say "# test windows $W1 $W2 $W3; keys-go-to is Accessibility's focused application, its-window that application's focused window"

step "a popover that goes away by itself"
say "--- a popover over floating $W2"
tell "activate"
tell "key $W2"
sleep 1
BEFORE=$(on_screen)
tell "popover $W2"
sleep 1
say "  windows of the test app on screen: $BEFORE before, $(on_screen) with the popover"
listed
who "with the popover open"
say "--- another app is activated (the probe, for 2 s)"
take 2
say "  windows of the test app on screen now: $(on_screen) (as many as before: the popover went when its app was left)"
tell "activate"
sleep 1

step "the Desktop, empty"
say "--- all three docked, $W1 has the keyboard"
ctl dock "$W1" left > /dev/null
ctl dock "$W2" right > /dev/null
ctl dock "$W3" right > /dev/null
tell "activate"
tell "key $W1"
sleep 1
who "docked"
say "--- Arbor: desktop (nothing floats, so nothing is in view)"
ctl desktop > /dev/null
sleep 1.5
say "  $W1 is at $(real_frame_of "$W1"), $W2 at $(real_frame_of "$W2"), $W3 at $(real_frame_of "$W3")"
who "on the empty Desktop"
if on_throwaway_mac; then
  say "--- ⌘W is pressed (only on a throwaway Mac)"
  key cmd+w
  sleep 1
  say "  still open: $(open_windows)(one missing: it was closed unseen)"
  who "after ⌘W"
fi

step "the probe takes the keyboard"
say "--- an accessory app without a window for the keyboard activates itself, for 4 s"
if on_throwaway_mac; then
  # Half way through, with the probe in front. `key` declines if anybody else's app is.
  (sleep 2 && key cmd+w > /dev/null) &
fi
take 4
if on_throwaway_mac; then
  say "  ⌘W was pressed after 2 s; still open: $(open_windows)(as many as before: the key went to nobody)"
fi

step "afterwards"
sleep 0.5
who "the probe has ended"

step "back"
say "--- Arbor: back (its ordinary focus: main, raise, activate)"
ctl back > /dev/null
sleep 1.5
who "back in the view with the windows"

# What ⌘W closed cannot come back on screen.
ARBOR_WINDOW_IDS=$(open_windows)
arbor_stop
if [ -n "$WAS_IN_FRONT" ]; then "$WHO" activate "$WAS_IN_FRONT"; fi
echo "Done: read $NOTES"
