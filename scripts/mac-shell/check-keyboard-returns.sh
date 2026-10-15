#!/bin/bash
# After one of Arbor's panels has closed, has the app from before the keyboard again? (collab/BOARD.md, 1.13.) With real keys and a witness:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-keyboard-returns.sh
#
# The name field, Go to…, the panel of shortcuts, the minimap and the settings window each take the keyboard, or lie over whoever has it. The
# scripts about them (check-F20.sh, shots-finder.sh, shots-F43.sh, shots-minimap.sh) ran on hosted Macs on 2026-10-15 and could not say whether it goes
# back: every key they pressed after a panel had closed was one of Arbor's own shortcuts, which macOS hands to Arbor whoever has the keyboard, and
# what Accessibility calls the focused window never changed while a panel had the keys.
#
# So here the app in front is one that writes down every key it is given (keys.swift, as in check-F41.sh). Before each panel a plain x
# must reach it: the control. With the panel up an x must not. After each way of closing it, an x must again, and the app must still be in front.
#
# Only on GitHub's Macs: it types plain letters, which land in whatever has the keyboard if Arbor has a fault here.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "type plain letters, which land in whichever app has the keyboard"

KEYS="$ARBOR_ROOT/.build/mac-shell/keys"
KEYS_APP="$ARBOR_ROOT/.build/mac-shell/ArborKeys.app"
KEYS_ID=dev.arbor.test.keys
KEYS_LOG="$ARBOR_OUT/keys.log"
KEYS_PID=""
KEYS_X=0
KEYS_Y=0
# The key where a US keyboard has X.
X=7

front_is() { [ "$("$KEYS" frontmost)" = "$1" ]; }
received() { grep -c "down code=$1 " "$KEYS_LOG"; }
received_is() { [ "$(received "$1")" = "$2" ]; }
# Window levels: the field is the only one of Arbor's windows at the level of a modal panel; Go to…, the panel of shortcuts and the minimap share one.
field() { has_overlay 8; }
panel() { has_overlay 5; }
# The settings window is an ordinary window of Arbor's.
window() { has_overlay 0; }
gone() { ! "$1"; }

# reaches "<when>": a plain x gets to the app, which is in front.
reaches() {
  local before
  before=$(received $X)
  key x
  check "$1: an x reaches the app" eventually received_is $X $((before + 1))
  check "$1: the app is in front" front_is "$KEYS_ID"
}
# kept "<when>": a plain x does not get to the app.
kept() {
  local before
  before=$(received $X)
  key x
  sleep 0.5
  check "$1: an x does not reach the app" received_is $X "$before"
}
# The app has the keyboard, by a click in its window, and shows it.
begin() {
  step "$1"
  click "$KEYS_X" "$KEYS_Y"
  eventually front_is "$KEYS_ID"
  reaches "before"
}

arbor_build
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/keys.swift" -o "$KEYS" > "$ARBOR_OUT/build-keys.log" 2>&1 || {
  cat "$ARBOR_OUT/build-keys.log"
  die "scripts/mac-shell/keys.swift did not compile"
}

step "an app with a bundle id that writes down its keys"
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

step "[1 | Desktop | 2], shortcuts and the menu bar item on, the app's window on the Desktop between them"
ARBOR_TEST_WINDOWS_ARGS="--regular"
arbor_start 2 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
ctl dock "$W1" left
ctl dock "$W2" right
sleep 3  # a regular app joining the Dock resizes it, and with it every slot
read -r dx dy dw dh <<< "$(arbor_ask desktop)"
KEYS_X=$((dx + dw / 2))
# Low on the Desktop: the field, the palette and the panel of shortcuts come up in the middle of the display, and a click has to find the window.
KEYS_Y=$((dy + dh - 100))
rm -f "$KEYS_LOG"
# Without descriptor 9, the test windows' stdin: they quit when it closes, and would wait for this app as well.
"$KEYS_APP/Contents/MacOS/keys" app "$KEYS_LOG" $((KEYS_X - 130)) $((KEYS_Y - 80)) 260 160 9>&- &
KEYS_PID=$!
started "$KEYS_PID"
keys_ready() { grep -q "ready pid=$KEYS_PID " "$KEYS_LOG" 2>/dev/null; }
eventually keys_ready || die "the key-logging app did not start"
shot 00-the-witness

begin "the name field, closed with ⎋"
key ctrl+opt+n
check "the field is up" eventually field
kept "with the field up"
shot 01-field
key escape
check "⎋ closes it" eventually gone field
reaches "after ⎋"

begin "the name field, closed with ↩"
key ctrl+opt+n
check "the field is up" eventually field
kept "with the field up"
key return
check "↩ closes it" eventually gone field
reaches "after ↩"

begin "the name field, closed with its own shortcut"
key ctrl+opt+n
check "the field is up" eventually field
key ctrl+opt+n
check "⌃⌥N again closes it" eventually gone field
reaches "after ⌃⌥N"

begin "Go to…, closed with ⎋"
key ctrl+opt+g
check "the palette is up" eventually panel
kept "with the palette up"
shot 02-palette
key escape
check "⎋ closes it" eventually gone panel
reaches "after ⎋"

begin "Go to…, closed with its own shortcut"
key ctrl+opt+g
check "the palette is up" eventually panel
key ctrl+opt+g
check "⌃⌥G again closes it" eventually gone panel
reaches "after ⌃⌥G"

begin "the panel of shortcuts, closed with ⎋"
key ctrl+opt+shift+/
check "the panel is up" eventually panel
shot 03-shortcuts
key escape
check "⎋ puts it away" eventually gone panel
reaches "after ⎋"

begin "the panel of shortcuts, put away by any key"
key ctrl+opt+shift+/
check "the panel is up" eventually panel
before=$(received $X)
key x
check "an x puts it away" eventually gone panel
# Whose that x was is the spec's to say. It is written down, not judged.
echo "the x that put the panel away: $(($(received $X) - before)) reached the app"
reaches "after that key"

begin "the minimap, tapped"
key ctrl+opt+m
check "the map is up" eventually panel
shot 04-minimap
# It takes clicks, never keys.
reaches "with the map up"
key ctrl+opt+m
check "⌃⌥M again puts it away" eventually gone panel
reaches "after ⌃⌥M"

begin "the settings window, closed with ⌘W"
key ctrl+opt+,
check "the window is up" eventually window
shot 05-settings
kept "with the window up"
key cmd+w
check "⌘W closes it" eventually gone window
reaches "after ⌘W"

step "what the app wrote down about coming to the front and leaving it"
grep -v " code=" "$KEYS_LOG" | tail -n 40

arbor_stop 06-quit
