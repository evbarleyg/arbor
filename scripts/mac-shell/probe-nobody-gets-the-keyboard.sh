#!/bin/bash
# With an accessory app in front that has no window for the keyboard: what do ⌘W, ⌘H, ⌘M, ⌘N and ⌘Q do, whose is the menu bar, and how does one leave?
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-nobody-gets-the-keyboard.sh
#
# probe-finder-gets-the-keyboard.sh found no clean way to give Finder the keyboard, and one to give it to nobody: an accessory app, which is what
# Arbor is, activates itself. Nothing rises, nothing moves, no Space changes, a letter reaches no window. But the menu bar goes on showing the
# name and the menus of the app before. The product owner's three conditions before anything is built on it:
#   1. ⌘Q, ⌘W and ⌘H do nothing: whoever thinks the app they just left is in front must lose nothing by it, and must not quit Arbor
#   2. the menu bar is looked at in a picture
#   3. the next click, or ⌘Tab, leaves that state as from any app
#
# Nothing here is a check of Arbor, which does not run. The output is the point: nobody-keyboard.txt in the output folder, a RESULT line a round.
# EVERY KEY IS PRESSED TWICE: alone, with TextEdit in front, which is the control (it must do what it does on every Mac, or the round says
# nothing), and with the accessory app in front. Of TextEdit, before and after: alive, hidden, how many windows it lists and how many are
# on screen. Of the accessory app: alive.
#
# It opens TextEdit on a throwaway document, closes, hides and quits it: only on GitHub's Macs.
source "$(dirname "$0")/lib-apps.sh"

needs_throwaway_mac "open, hide and quit TextEdit and click in the menu bar"
# 64 is what a rehearsal ends with where the fake Mac lacks something: it has no TextEdit and no compiler.
if [ -n "${ARBOR_REHEARSAL_DIR:-}" ]; then
  echo "cannot be rehearsed: the fake Mac has no apps of macOS's"
  exit 64
fi

apps_build
WHO="$ARBOR_ROOT/.build/mac-shell/whohaskeys"
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/whohaskeys.swift" -o "$WHO" > "$ARBOR_OUT/build-whohaskeys.log" 2>&1 || {
  cat "$ARBOR_OUT/build-whohaskeys.log"
  die "scripts/mac-shell/whohaskeys.swift did not compile"
}
NOTES="$ARBOR_OUT/nobody-keyboard.txt"
say() { echo "$*" | tee -a "$NOTES"; }

apps_scratch
arbor_make_room || exit 77
# A window that counts the letters it gets.
arbor_open_app 1 "$ARBOR_TEST_WINDOWS" 1 --regular
tw move "$W1" 700 300 420 300
T=""
TAKER=""

# TextEdit in front, not hidden, with its one document in one window on screen.
ready() {
  local id
  app_open com.apple.TextEdit "$APPS_SCRATCH/oak.txt" > /dev/null
  T=$APP_PID
  apptool unhide "$T" > /dev/null 2>&1
  DOCUMENT=""
  for id in $(app_windows "$T"); do
    # The first is the one in front, which `open` has just brought there. What ⌘N left is empty, and closes without a question.
    if [ -z "$DOCUMENT" ]; then DOCUMENT=$id; else apptool close "$id" > /dev/null 2>&1; fi
  done
  apptool unminimize "$DOCUMENT" > /dev/null 2>&1
  sleep 1.5
  apptool set-frame "$DOCUMENT" 120 120 520 400 > /dev/null
  app_focus "$DOCUMENT" > /dev/null
  NAMES="test-windows=$ARBOR_WINDOWS_PID TextEdit=$T"
  check "$ROUND: it begins with TextEdit in front, with one window" test "$(facts) $(front)" = "alive, 1 listed, 1 on screen front=TextEdit"
}
facts() {
  kill -0 "$T" 2> /dev/null || { echo "GONE"; return; }
  local hidden=""
  apptool apps | awk -v pid="$T" '$1 == pid && $3 ~ /hidden/ { found = 1 } END { exit !found }' && hidden=" HIDDEN,"
  echo "alive,$hidden $(app_windows "$T" | wc -w | tr -d ' ') listed, $("$ARBOR_POINTER" windows --pid "$T" --on-screen | awk '$3 == 0' | wc -l | tr -d ' ') on screen"
}
# shellcheck disable=SC2086
report() { "$WHO" report $NAMES ${TAKER:+the-accessory-app=$TAKER} | sed -E 's/ keys-go-to=.*//'; }
front() { report | cut -d ' ' -f 1; }
# takes <seconds> [politely]: what it sees for itself goes into the notes.
# shellcheck disable=SC2086
takes() {
  "$WHO" take "$@" $NAMES >> "$NOTES" 2>&1 9>&- 8>&- 3>&- &
  TAKER=$!
  started "$TAKER"
  sleep 1
}
ends() {
  [ -z "$TAKER" ] || wait "$TAKER" 2> /dev/null
  TAKER=""
}
lives() { kill -0 "$TAKER" 2> /dev/null && echo alive || echo GONE; }
# The bystander: the test windows' app, which is behind TextEdit all the while.
bystander() {
  kill -0 "$ARBOR_WINDOWS_PID" 2> /dev/null || { echo GONE; return; }
  echo "alive, $("$ARBOR_POINTER" windows --pid "$ARBOR_WINDOWS_PID" --on-screen | awk '$3 == 0' | wc -l | tr -d ' ') on screen"
}

# press <chord> <what it does on every Mac>
press() {
  local chord=$1 before after
  ROUND="$chord alone, the control"
  step "$ROUND"
  ready
  before=$(facts)
  key "$chord" > /dev/null
  sleep 1.5
  after=$(facts)
  say "RESULT | $ROUND | TextEdit: $before -> $after | $(report)"
  check "$ROUND: it does what it does on every Mac: $2" test "$before" != "$after"

  ROUND="$chord with the accessory app in front"
  step "$ROUND"
  ready
  before=$(facts)
  say "--- $ROUND"
  takes 6
  say "  before the key: $(report)"
  key "$chord" > /dev/null
  sleep 1.5
  after=$(facts)
  say "RESULT | $ROUND | TextEdit: $before -> $after | the accessory app: $(lives) | the test windows' app: $(bystander) | $(report)"
  ends
  say "  once it has ended: $(report); TextEdit: $(facts)"
}

say "# probe-nobody-gets-the-keyboard.sh $(date -u +%Y-%m-%dT%H:%MZ) on macOS $(sw_vers -productVersion), commit $(git rev-parse --short HEAD). Arbor is not running."
press cmd+w "the window closes"
press cmd+h "the app is hidden"
press cmd+m "the window goes to the Dock"
press cmd+n "a window opens"
press cmd+q "the app quits"

ROUND="the menu bar with the accessory app in front"
step "$ROUND"
ready
say "--- $ROUND"
takes 9
shot 1-the-menu-bar
read -r x y <<< "$(apptool menu "$T" File 2> /dev/null)"
say "  TextEdit's File menu stands at ${x:-nowhere} ${y:-}"
if [ -n "${x:-}" ]; then
  click "$x" "$y" > /dev/null
  sleep 1
  shot 2-a-click-on-its-file-menu
  say "RESULT | a click on File in the menu bar | $(report) | windows above the ordinary ones, by owner: $("$ARBOR_POINTER" windows --on-screen | awk '$3 > 20 && $3 < 200 { print $NF }' | sort | uniq -c | tr -s ' \n' ' ')"
  key escape > /dev/null
  sleep 0.5
  say "  after ⎋: $(report)"
fi
ends

ROUND="a click on a window leaves it"
step "$ROUND"
ready
say "--- $ROUND"
takes 6
say "  before: $(report)"
click_window "$W1" > /dev/null
sleep 0.7
count=$(events_of "$W1" key)
key j > /dev/null
sleep 0.5
say "RESULT | $ROUND | $(report) | a j: the window clicked +$(($(events_of "$W1" key) - count)) | the accessory app: $(lives)"
ends

ROUND="⌘Tab leaves it"
step "$ROUND"
click_window "$W1" > /dev/null
ready
say "--- $ROUND (used before TextEdit: the test windows' app)"
takes 6
say "  before: $(report)"
key cmd+tab > /dev/null
sleep 1
say "RESULT | $ROUND | $(report)"
ends

ROUND="the newer activate(), which is a request"
step "$ROUND"
ready
say "--- $ROUND"
takes 4 politely
say "RESULT | $ROUND | $(report)"
ends

# said <words>: how often the accessory app has written that down so far.
said() { grep -c -- "$1" "$NOTES"; }
# letters <picture> [swallowing]: the test window had the keyboard, for it counts what it gets.
letters() {
  local picture=$1 given count shown
  shift
  ROUND="a plain letter and ↩ with the accessory app in front${1:+, which lets them go no further}"
  step "$ROUND"
  click_window "$W1" > /dev/null
  sleep 0.5
  say "--- $ROUND"
  takes 6 "$@"
  given=$(said "it is given a key")
  count=$(events_of "$W1" key)
  shown=$("$ARBOR_POINTER" windows --on-screen | wc -l | tr -d ' ')
  key j > /dev/null
  key return > /dev/null
  sleep 0.7
  say "RESULT | $ROUND | its own event loop was given $(($(said "it is given a key") - given)) of 2 | the test window +$(($(events_of "$W1" key) - count)) | windows on screen: $shown -> $("$ARBOR_POINTER" windows --on-screen | wc -l | tr -d ' ') | $(report)"
  shot "$picture"
  ends
}
NAMES="test-windows=$ARBOR_WINDOWS_PID TextEdit=$T"
letters 3-a-letter-and-return
letters 4-swallowed swallowing

# hot_key <quietly|>: ⌃⌥K, which the accessory app holds.
hot_key() {
  local fired
  ROUND="its own hot key, ${1:+the control: with the accessory app in the background}${1:-with the accessory app in front}"
  ROUND=${ROUND%quietly}
  step "$ROUND"
  click_window "$W1" > /dev/null
  sleep 0.5
  say "--- $ROUND"
  takes 5 "$@"
  fired=$(said "its hot key fired")
  key ctrl+opt+k > /dev/null
  sleep 0.7
  say "RESULT | $ROUND | fired $(($(said "its hot key fired") - fired)) time(s) | $(report)"
  ends
}
hot_key quietly
hot_key

ROUND="how long it holds"
step "$ROUND"
click_window "$W1" > /dev/null
sleep 0.5
say "--- $ROUND: the test window had the keyboard"
NAMES="test-windows=$ARBOR_WINDOWS_PID TextEdit=$T"
takes 34
for after in 1 10 30; do
  while [ "$SECONDS" -lt $((${began:=$SECONDS} + after - 1)) ]; do sleep 0.5; done
  count=$(events_of "$W1" key)
  key j > /dev/null
  sleep 0.4
  say "RESULT | $ROUND: after $after s | $(report) | a j: the test window +$(($(events_of "$W1" key) - count))"
done
ends
say "  once it has ended: $(report)"

step "What it leaves"
app_quit "$T"
arbor_close_windows
echo
echo "=== nobody-keyboard.txt, its RESULT lines"
grep "^RESULT" "$NOTES"
