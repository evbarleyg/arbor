#!/bin/bash
# With the view held the keyboard can end up in a window that is out of view, and stay there. Does Arbor's line say so for as long as it is so, and only then?
# A probe, not a check (collab/BOARD.md, 1.71 and the row beside it).
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-held-keyboard.sh
#
# The line comes when two looks running, half a second apart, have found the keyboard in the same window out of view with nothing being sent back, and nothing looks while it
# stands. All of that goes by what macOS answers to "who has the keyboard", which the stand-ins answer at once and always rightly. After each act: Arbor's own
# lines about the hold, what it said on screen, and whether the line is on screen by the window server.
#
# Only on GitHub's Macs: it presses ⌘W and ⌘Tab and clicks on the Desktop.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "press ⌘W and ⌘Tab and click on the Desktop"

arbor_build
# The line's window level: three above floating panels.
LINE=6
LOG_MARK=0
mark() { LOG_MARK=$(wc -l < "$ARBOR_HOME/arbor.log"); }
# account: what Arbor heard, did and said since the mark, and how often it said where the keyboard is.
SAID=0
account() {
  tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | cut -c 12- | grep -E "hold: |said on |has the keyboard$" | tail -n 40 | sed 's/^/  log | /'
  SAID=$(tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | grep -c "said on .*has the keyboard, out of view")
  echo "  said where the keyboard is: $SAID time(s); the line is on screen: $(has_overlay $LINE && echo yes || echo no); in front: $(pointer front 2>&1)"
}
said_is() { [ "$SAID" -eq "$1" ] || { echo "said $SAID time(s), not $1"; return 1; }; }
hold_anew() {
  ctl release
  # shellcheck disable=SC2046
  click $(titlebar_of "$W1")
  sleep 1
  ctl zoom "$W1"
  ctl hold
  sleep 2
  mark
}

step "two apps, one window framed, four out of view"
ARBOR_TEST_WINDOWS_ARGS="--regular"
ARBOR_SECOND_APP=2
ARBOR_SECOND_APP_ARGS="--regular"
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
tw2 title "$V1" Other App One
tw2 title "$V2" Other App Two
sleep 3  # regular apps joining the Dock resize it, and with it every slot
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W2" bottom
ctl dock "$V1" beside "$W1" bottom
summary

step "1. the other app comes forward by itself, five times, six seconds apart: it is sent back, and never named"
hold_anew
for round in 1 2 3 4 5; do
  tw2 activate "$V1"
  if [ "$round" = 1 ]; then film 01-sent-back 5; sleep 1; else sleep 6; fi
done
account
check "nothing is said of where the keyboard is" said_is 0
check "no line is on screen" fails has_overlay $LINE
check "W1 has the keyboard" eventually is focused "$W1"

step "2. it takes the keyboard again and again, until Arbor leaves it there"
hold_anew
for round in 1 2 3 4 5 6; do
  tw2 activate "$V1"
  sleep 0.7
done
sleep 2
account
echo "  Other App One has the keyboard: $(is focused "$V1" > /dev/null 2>&1 && echo yes || echo no); in view: $(is on_screen "$V1" > /dev/null 2>&1 && echo yes || echo no)"
shot 02-left-there
if is focused "$V1" > /dev/null 2>&1; then
  check "the line is on screen" eventually has_overlay $LINE
  sleep 10
  account
  check "ten seconds on it still is" has_overlay $LINE
  check "and has been said once" said_is 1
  # shellcheck disable=SC2046
  click $(titlebar_of "$W1")
  check "a click on the window in view: the line goes" eventually fails has_overlay $LINE
else
  echo "  the keyboard went back every time: nothing to say, and nothing learned about the line"
fi

step "3. ⌘W on the only window in view: macOS hands the keyboard on, and nobody is in view to give it to"
hold_anew
key cmd+w
sleep 3
account
shot 03-after-cmd-w
check "the line is on screen" eventually has_overlay $LINE
sleep 10
account
check "ten seconds on it still is" has_overlay $LINE
check "and has been said once" said_is 1
shot 03-ten-seconds-on

step "4. ⌘Tab, blind: what is said then?"
mark
key cmd+tab
film 04-after-cmd-tab 8
sleep 4
account
shot 04-after-cmd-tab

step "5. a click on the Desktop: the keyboard is with the Finder"
mark
click 400 300
sleep 3
account
check "the line is gone" eventually fails has_overlay $LINE
shot 05-after-a-click-on-the-desktop

step "6. the other app comes forward, with nobody in view; then release"
mark
tw2 activate "$V1"
sleep 3
account
check "the line is on screen" eventually has_overlay $LINE
ctl release
check "released: the line is gone" eventually fails has_overlay $LINE
shot 06-released

arbor_stop 07-quit
