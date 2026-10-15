#!/bin/bash
# A key that moves the view: whose is the keyboard afterwards? (collab/BOARD.md, 1.65.) With real keys and witnesses:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-moves-of-the-view.sh
#
# Arbor takes the keyboard only from a window that it takes out of view. With no window focused that it knows, a move of the view that names no
# place (Show Everything, Home, Back, Out, Desktop, a neighbour) leaves the keyboard where it is: in an app Arbor does not look at, and in a sheet
# whose window stays in view. A sheet whose window the move takes away hands it on, and what names a place takes it there.
#
# Who has the keyboard cannot be read from Arbor, so a plain x is typed and whoever gets it has it: the test windows, their sheet and their panel
# count their keys, and the app Arbor does not look at writes every key down (keys.swift, as in check-keyboard-returns.sh).
#
# It also WRITES DOWN what nobody had recorded: what Accessibility names as an app's focused window while the keyboard is in a sheet, in a
# free-standing panel, and in an app that is not observed; of test windows and of TextEdit. Those lines begin with "names:". Arbor's own layer passes that
# number on as it comes, and each session leaves a trace with what it answered.
#
# A rehearsal plays the sheet and the panel and ends where the first tool is compiled that the fake Mac lacks.
#
# Only on GitHub's Macs: it types plain letters, which land in whatever has the keyboard if Arbor has a fault here.
source "$(dirname "$0")/lib-apps.sh"
needs_throwaway_mac "type plain letters, which land in whichever app has the keyboard"

export ARBOR_RECORD=1
ARBOR_TEST_WINDOWS_ARGS="--regular"

# names "<when>" <pid>
names() {
  [ -z "${ARBOR_REHEARSAL:-}" ] || return 0
  echo "names: $1 (in front: $(apptool front)):"
  apptool names "$2" | sed 's/^/names:   /'
}
keys_of() { events_of "$1" key; }
# types <id> "<when>": a plain x gets to that window.
types() {
  local before
  before=$(keys_of "$1")
  key x
  check "$2: an x reaches it" eventually received "$1" key -gt "$before"
}
# deaf <id> "<when>": it does not.
deaf() {
  local before
  before=$(keys_of "$1")
  key x
  sleep 0.5
  check "$2: an x does not reach it" received "$1" key -eq "$before"
}

if [ -n "${ARBOR_REHEARSAL:-}" ]; then arbor_build; else apps_build; fi

# [1 | Desktop | 2], and 3 floats on the Desktop.
three_windows() {
  arbor_start 3
  ctl dock "$W1" left
  ctl dock "$W2" right
  sleep 3  # a regular app joining the Dock resizes it, and with it every slot
}

step "a sheet on a docked window"
three_windows
open_window S1 kind=sheet:"$W1" size=220x120
summary

claim "a sheet whose window stays in view keeps the keyboard when the view moves"
ctl zoom "$W1"
click_window "$S1"
types "$S1" "before"
names "the keyboard is in a sheet of test window $W1, the sheet is $S1" "$ARBOR_WINDOWS_PID"
ctl show-all
sleep 1
check "its window is in view" eventually in_view "$W1"
types "$S1" "after show-all"
shot sheet-1-stays

claim "a sheet whose window the move takes out of view hands the keyboard on to a window in view"
ctl zoom "$W1"
click_window "$S1"
types "$S1" "before"
ctl neighbor right
sleep 1
check "its window is out of view" eventually out_of_view "$W1"
deaf "$S1" "after neighbor right"
types "$W3" "the window on the Desktop, which is in view"
shot sheet-2-leaves
forget_window "$S1"
arbor_stop sheet-3-quit

step "a free-standing panel of the same app"
three_windows
open_window P1 kind=panel size=220x140
summary

claim "a panel keeps the keyboard while its app's window used last stays in view"
ctl zoom "$W1"
click_window "$W1"
click_window "$P1"
types "$P1" "before"
names "the keyboard is in a free-standing panel, $P1, of the app of test window $W1" "$ARBOR_WINDOWS_PID"
ctl show-all
sleep 1
types "$P1" "after show-all"

step "the panel, when that window leaves the view: written down, not judged"
ctl zoom "$W1"
click_window "$W1"
click_window "$P1"
types "$P1" "before"
panel_before=$(keys_of "$P1")
desk_before=$(keys_of "$W3")
ctl neighbor right
sleep 1
key x
sleep 0.5
echo "names: after neighbor right took window $W1 away, of one x the panel got $(($(keys_of "$P1") - panel_before)) events and the window in view $(($(keys_of "$W3") - desk_before))"
shot panel-1-its-window-left
forget_window "$P1"
arbor_stop panel-2-quit

# MARK: An app Arbor does not look at

KEYS="$ARBOR_ROOT/.build/mac-shell/keys"
KEYS_APP="$ARBOR_ROOT/.build/mac-shell/ArborKeys.app"
KEYS_ID=dev.arbor.test.keys
KEYS_LOG="$ARBOR_OUT/keys.log"
KEYS_PID=""
KEYS_X=0
KEYS_Y=0
# The key where a US keyboard has X.
X=7

witness_in_front() { [ "$("$KEYS" frontmost)" = "$KEYS_ID" ]; }
seen() { grep -c "down code=$1 " "$KEYS_LOG"; }
seen_is() { [ "$(seen "$1")" = "$2" ]; }
resigned() { grep -c "resigned" "$KEYS_LOG"; }
resigned_is() { [ "$(resigned)" = "$1" ]; }
keys_ready() { grep -q "ready pid=$KEYS_PID " "$KEYS_LOG" 2>/dev/null; }
# Its window, as the window server has it: id x y w h.
witness_window() { "$ARBOR_POINTER" windows --pid "$KEYS_PID" | awk '$3 == 0 && $8 == "on" { print $1, int($4), int($5), int($6), int($7); exit }'; }
is_managed() { is managed "$1"; }
unknown() { ! "$@" > /dev/null 2>&1; }

# reaches "<when>": a plain x gets to the app, which is in front.
reaches() {
  local before
  before=$(seen $X)
  key x
  check "$1: an x reaches the app" eventually seen_is $X $((before + 1))
  check "$1: the app is in front" witness_in_front
}
# begin [<where the view is to be>]: the view is on the Desktop, where nothing lies over the app's window (a framed window would: the first run on a Mac
# clicked that instead), and the app has the keyboard, by a click in its window, and shows it.
begin() {
  FROM=${1:-desktop}
  if [ "$FROM" = root ]; then ctl show-all; else ctl desktop; fi
  sleep 0.5
  click "$KEYS_X" "$KEYS_Y"
  eventually witness_in_front
  reaches "before"
}
# leaves_it "<what moves the view>" <from where> <command…>
leaves_it() {
  local what=$1 from=$2 left
  shift 2
  claim "$what moves the view and leaves the keyboard with an app Arbor does not look at"
  begin "$from"
  left=$(resigned)
  "$@"
  sleep 1
  check "the view has moved" fails camera_on "$from"
  reaches "after $what"
  check "the app never left the front" resigned_is "$left"
}

swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/keys.swift" -o "$KEYS" > "$ARBOR_OUT/build-keys.log" 2>&1 || {
  cat "$ARBOR_OUT/build-keys.log"
  die "scripts/mac-shell/keys.swift did not compile"
}

step "an app with a bundle id that writes down its keys, and that Arbor is not pointed at"
rm -rf "$KEYS_APP"
mkdir -p "$KEYS_APP/Contents/MacOS"
cp "$KEYS" "$KEYS_APP/Contents/MacOS/keys"
cat > "$KEYS_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$KEYS_ID</string>
  <key>CFBundleExecutable</key><string>keys</string>
  <key>CFBundleName</key><string>ArborKeys</string>
  <key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
at_exit 'kill_started $KEYS_PID; rm -rf "$KEYS_APP"'

# Low in the middle of the display, over the Desktop of [1 | Desktop | 2]. Arbor does not move it, so it is there whatever the view shows.
read -r _ display_x display_y display_w display_h _ <<< "$(pointer displays | head -n 1)"
rm -f "$KEYS_LOG"
"$KEYS_APP/Contents/MacOS/keys" app "$KEYS_LOG" $((display_x + display_w / 2 - 130)) $((display_y + display_h - 260)) 260 160 9>&- &
KEYS_PID=$!
started "$KEYS_PID"
eventually keys_ready || die "the key-logging app did not start"

ARBOR_EXTRA_PIDS=""
arbor_start 2 ARBOR_NO_HOTKEYS=0
ctl dock "$W1" left
ctl dock "$W2" right
sleep 3
read -r witness witness_x witness_y witness_w witness_h <<< "$(witness_window)"
[ -n "${witness_h:-}" ] || die "the key-logging app shows no window"
KEYS_X=$((witness_x + witness_w / 2))
KEYS_Y=$((witness_y + witness_h / 2))
check "Arbor does not know the app's window" unknown is_managed "$witness"
summary
shot unseen-0-the-witness

leaves_it "show-all" desktop ctl show-all
names "the keyboard is in the window of an app that Arbor does not observe" "$KEYS_PID"
leaves_it "home" desktop ctl home
leaves_it "neighbor right" desktop ctl neighbor right
leaves_it "out" desktop ctl out
leaves_it "desktop" root ctl desktop
# Back wants somewhere to go back to.
ctl zoom "$W1"
leaves_it "back" desktop ctl back
leaves_it "⌃⌥Space" desktop key ctrl+opt+space
leaves_it "⌃⌥→" desktop key ctrl+opt+right
leaves_it "⌃⌥0" desktop key ctrl+opt+0
shot unseen-1-after-the-moves

# The control: that this witness can see the keyboard being taken.
claim "what names a place takes the keyboard there, whoever had it"
ctl zoom "$W2"
ctl save-view 1
begin
before=$(seen $X)
ctl view 1
sleep 1
check "the view is on window 2" eventually camera_on "$W2"
key x
sleep 0.5
check "an x does not reach the app" seen_is $X "$before"
check "the test windows' app is in front" front_is "$ARBOR_WINDOWS_PID"

echo "what the app wrote down about coming to the front and leaving it:"
grep -v " code=" "$KEYS_LOG" | tail -n 60
arbor_stop unseen-2-quit
kill_started "$KEYS_PID"

# MARK: TextEdit. Written down, not judged: a stock app's sheets and panels come as macOS pleases.

step "TextEdit: its Save sheet and its Open panel"
apps_scratch
if app_open com.apple.TextEdit "$APPS_SCRATCH/oak.txt"; then
  app_dismiss "$APP_PID"
  companions_start 2
  arbor_start_apps "$APP_PID" "$COMPANIONS_PID"
  ctl dock "$APP_WINDOW" left
  ctl dock "$C1" right
  sleep 2
  app_focus "$APP_WINDOW"
  names "TextEdit, the keyboard in its document window $APP_WINDOW" "$APP_PID"

  # Save As…, which comes down from the title bar as a sheet.
  key cmd+shift+opt+s
  sleep 2
  echo "TextEdit lists (id role subrole x y w h flags):"
  apptool windows "$APP_PID" | sed 's/^/  /'
  names "TextEdit, Save As… is up over window $APP_WINDOW" "$APP_PID"
  snap textedit-1-sheet
  ctl show-all
  sleep 1
  names "TextEdit, after show-all, with its window in view" "$APP_PID"
  ctl zoom "$APP_WINDOW"
  sleep 1
  names "TextEdit, after zoom on its window" "$APP_PID"
  ctl neighbor right
  sleep 1
  names "TextEdit, after neighbor right took its window away" "$APP_PID"
  snap textedit-2-sheet-left
  ctl show-all
  sleep 1
  app_focus "$APP_WINDOW"
  key escape
  sleep 1

  key cmd+o
  sleep 2
  echo "TextEdit lists (id role subrole x y w h flags):"
  apptool windows "$APP_PID" | sed 's/^/  /'
  names "TextEdit, Open… is up, free-standing" "$APP_PID"
  snap textedit-3-panel
  ctl show-all
  sleep 1
  names "TextEdit, after show-all" "$APP_PID"
  ctl zoom "$C1"
  sleep 1
  names "TextEdit, after zoom on another app's window, which names a window" "$APP_PID"
  snap textedit-4-panel-left
  apptool activate "$APP_PID"
  sleep 0.5
  key escape
  sleep 1
  arbor_stop
  companions_stop
  app_quit "$APP_PID"
else
  echo "TextEdit did not open: nothing is written down about it"
fi
