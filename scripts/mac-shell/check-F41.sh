#!/bin/bash
# F41, apps that keep their own ⌃⌥, with real keys and a real app in front:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-F41.sh
#
# An app that writes down every key it receives (keys.swift, in a bundle so that it has a bundle id) is put on
# `passThroughApps`. In front of it ⌃⌥F, ⌃⌥Space and ⌃⌥↩ must reach it and leave Arbor unmoved, both event taps must
# be gone, and ⌃⌥⎋ must still be Arbor's; one ⌘Tab away everything is back. Then the same app on `pauseForApps`.
# It also measures, without judging: what registering the shortcuts costs, how long after an app comes to the front
# Arbor has let go, who gets a key pressed straight after the switch, and what becomes of a press that a
# hot key's owner passes on with postToPid (the alternative to unregistering).
# Last, for F44: what the layouts' keys type and, on a throwaway Mac only, whether a script can switch layouts there.
#
# Safe on a person's Mac: it arranges only its own test windows, sends keys only while they or its own app are in front,
# and keeps that app in the build folder. It does move the pointer and take the keyboard. The two measurements that cannot
# afford the time lib.sh's nets take, and the switching of layouts, are left out there.
ARBOR_SHORTCUTS=all  # it presses keys of the whole map, of which nine ship
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/lib-gestures.sh"

KEYS="$ARBOR_ROOT/.build/mac-shell/keys"
KEYS_APP="$ARBOR_ROOT/.build/mac-shell/ArborKeys.app"
KEYS_ID=dev.arbor.test.keys
KEYS_LOG="$ARBOR_OUT/keys.log"
KEYS_PID=""
# The middle of the app's window, once it is open.
KEYS_X=0
KEYS_Y=0

status_has() { "$ARBOR_BIN/arborctl" status | grep -q "$1"; }
front_is() { [ "$("$KEYS" frontmost)" = "$1" ]; }
taps_are() { [ "$("$KEYS" taps "$ARBOR_PID")" = "$1" ]; }
# How many there are grows with the features; what matters here is some or none.
has_taps() { [ "$("$KEYS" taps "$ARBOR_PID")" -gt 0 ]; }
all_on_screen() { is on_screen "$W1" && is on_screen "$W2"; }
# How many key-downs with this key code the app has written down.
received() { grep -c "down code=$1 " "$KEYS_LOG"; }
received_is() { [ "$(received "$1")" = "$2" ]; }
# How many times a command ran, by the line each success leaves in the log; and whether the log mentions it at all.
ran() { grep -c "INFO  $1" "$ARBOR_HOME/arbor.log"; }
mentions_are() { [ "$(grep -c "$1" "$ARBOR_HOME/arbor.log")" = "$2" ]; }
last_registered_is() { grep "registered [0-9]* shortcuts" "$ARBOR_HOME/arbor.log" | tail -n 1 | grep -q "registered $1 shortcuts"; }
listed_is() {
  [ "$(python3 -c 'import json, sys; print(",".join(json.load(open(sys.argv[1])).get("passThroughApps", [])))' "$ARBOR_HOME/settings.json")" = "$1" ]
}
real_center_of() { real_frame_of "$1" | awk '{ print int($1 + $3 / 2), int($2 + $4 / 2) }'; }
to_keys_app() {
  click "$KEYS_X" "$KEYS_Y"
  eventually front_is "$KEYS_ID"
}
# For when a framed window covers the app's: a click there would land on that window.
summon_keys_app() {
  kill -USR1 "$KEYS_PID"
  eventually front_is "$KEYS_ID"
}
to_test_windows() {
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  eventually front_is "$ARBOR_TEST_BUNDLE"
}

arbor_build
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/keys.swift" -o "$KEYS" > "$ARBOR_OUT/build-keys.log" 2>&1 || {
  cat "$ARBOR_OUT/build-keys.log"
  die "scripts/mac-shell/keys.swift did not compile"
}

step "what hot keys cost, before anything else holds any"
"$KEYS" bench 45 30
"$KEYS" bench 1 30

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

step "[1 / 2 | Desktop], the app on passThroughApps, shortcuts, taps and the menu bar item on"
ARBOR_TEST_WINDOWS_ARGS="--regular"
arbor_settings "{$ARBOR_GESTURES_ON, \"passThroughApps\": [\"$KEYS_ID\"]}"
arbor_start 2 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
# One above the other in one half: a second dock at the far side would take all that is left over, and the Desktop is wanted as a bare place.
ctl dock "$W1" left
ctl dock "$W2" beside "$W1" bottom
sleep 3  # a regular app joining the Dock resizes it, and with it every slot

step "the app's window, in the middle of the Desktop beside them, where neither covers it"
read -r dx dy dw dh <<< "$(arbor_ask desktop)"
[ -n "$dh" ] || die "the Desktop has no room, and the app's window wants a bare place"
KEYS_X=$((dx + dw / 2))
KEYS_Y=$((dy + dh / 2))
# Started directly, not through `open`: a program inside a bundle has the bundle's id either way, and nothing gets registered.
# Not read from the log: an earlier run's log would name a process that is somebody else's by now.
rm -f "$KEYS_LOG"
# Without descriptor 9, the test windows' stdin: they quit when it closes, and would wait for this app as well.
"$KEYS_APP/Contents/MacOS/keys" app "$KEYS_LOG" $((KEYS_X - 130)) $((KEYS_Y - 80)) 260 160 9>&- &
KEYS_PID=$!
started "$KEYS_PID"
keys_ready() { grep -q "ready pid=$KEYS_PID " "$KEYS_LOG" 2>/dev/null; }
eventually keys_ready || die "the key-logging app did not start"
head -n 3 "$KEYS_LOG"

step "in an ordinary app the shortcuts are Arbor's"
check "the test windows' app is in front" to_test_windows
ctl status
ctl bindings | tail -n 1
check "the event taps are installed" eventually has_taps
key ctrl+opt+return
check "⌃⌥↩ frames window 1: 2 goes out of view" eventually is parked "$W2"
key ctrl+opt+space
check "⌃⌥Space shows everything" eventually all_on_screen

step "in the listed app they are the app's"
check "a click brings the app to the front" to_keys_app
check "status says that shortcuts are off, and why" eventually status_has "off in ArborKeys"
ctl status
ctl bindings | tail -n 1
check "one shortcut is left registered" eventually last_registered_is 1
check "no event tap is left" eventually taps_are 0
key ctrl+opt+f
key ctrl+opt+space
key ctrl+opt+return
key ctrl+opt+cmd+left
check "⌃⌥F reached the app" eventually received_is 3 1
check "⌃⌥Space reached the app" eventually received_is 49 1
check "⌃⌥↩ reached the app" eventually received_is 36 1
check "⌃⌥⌘← reached the app" eventually received_is 123 1
check "Arbor did not move: both windows docked and in view" all_on_screen
grep -E "code=(3|49|36|123) " "$KEYS_LOG"
shot 01-listed-app-in-front

step "a ⌃⌥-drag inside the app is the app's too"
drag $((KEYS_X - 60)) $((KEYS_Y - 20)) $((KEYS_X + 60)) $((KEYS_Y + 40)) --mods ctrl+opt
sleep 0.5
check "nothing was framed" all_on_screen
check "no frame-rect command ran" mentions_are "frame-rect" 0

step "the menu says so"
read -r item_x item_y <<< "$(status_item)"
rightclick "$item_x" "$item_y"
shot 02-menu-ticked
key escape
check "the app is still in front after the menu" front_is "$KEYS_ID"

step "⌃⌥⎋ answers everywhere"
key ctrl+opt+escape
check "⌃⌥⎋ pauses Arbor from inside the app" eventually status_has "^paused"
key ctrl+opt+escape
check "and resumes it" eventually status_has "^running"
check "the app never saw ⎋" received_is 53 0
check "after resuming the shortcuts are still off here" status_has "off in ArborKeys"
key ctrl+opt+space
check "⌃⌥Space still reaches the app" eventually received_is 49 2

step "⌘Tab away and they are back"
key cmd+tab
check "⌘Tab leads to the test windows" eventually front_is "$ARBOR_TEST_BUNDLE"
check "status no longer says off" eventually status_has "out of view$"
check "the event taps are back" eventually has_taps
# shellcheck disable=SC2046
click $(center_of "$W1")
key ctrl+opt+return
check "⌃⌥↩ frames window 1 again" eventually is parked "$W2"
key ctrl+opt+space
check "⌃⌥Space shows everything" eventually all_on_screen
check "the app saw neither" received_is 36 1

step "the command, with the app in front"
check "the app is in front" to_keys_app
ctl pass-through
check "settings.json no longer lists the app" listed_is ""
check "the shortcuts are registered again at once" eventually last_registered_is "[0-9][0-9]"
check "and the taps installed" eventually has_taps
key ctrl+opt+d
check "⌃⌥D shows the Desktop: the docked windows go out of view" eventually is parked "$W1"
check "the app did not see it" received_is 2 0
key ctrl+opt+space
check "⌃⌥Space shows everything" eventually all_on_screen
drag $((KEYS_X - 60)) $((KEYS_Y - 20)) $((KEYS_X + 60)) $((KEYS_Y + 40)) --mods ctrl+opt
check "the same ⌃⌥-drag is Arbor's now" eventually mentions_are "frame-rect" 1
ctl home
# ⌃⌥Space and `home` took the keyboard from the app, which Arbor does not look at here: whoever moves the view with "nobody" at the keyboard gets a docked
# window focused. At the first run on a Mac the command below therefore went to the test windows' app.
check "the app is in front again" to_keys_app
ctl pass-through
check "settings.json lists the app again" listed_is "$KEYS_ID"
check "and the taps are gone again" eventually taps_are 0

step "for the record: how soon after the switch Arbor has let go"
grep -E " (active|resigned)" "$KEYS_LOG" | tail -n 6
grep -E "shortcuts and gestures are|registered [0-9]+ shortcuts|event tap installed" "$ARBOR_HOME/arbor.log" | tail -n 16

step "for the record: a key pressed straight after the switch, ten times each way"
# Past lib.sh's nets, which take longer than the moment this is about: so only where nothing of anybody's can get in the way.
if on_throwaway_mac; then
  to_test_windows
  app_before=$(received 2)
  arbor_before=$(ran "desktop:")
  round=0
  while [ "$round" -lt 10 ]; do
    "$ARBOR_POINTER" click "$KEYS_X" "$KEYS_Y"
    "$ARBOR_POINTER" key ctrl+opt+d
    sleep 0.4
    # If Arbor got the key, window 1 is out of view and cannot be clicked.
    "$ARBOR_BIN/arborctl" home > /dev/null
    sleep 0.3
    # shellcheck disable=SC2046
    "$ARBOR_POINTER" click $(real_center_of "$W1")
    sleep 0.4
    round=$((round + 1))
  done
  echo "into the listed app: the app got $(($(received 2) - app_before)) of 10, Arbor $(($(ran "desktop:") - arbor_before))"
  ctl home
  to_keys_app
  arbor_before=$(ran "desktop:")
  round=0
  while [ "$round" -lt 10 ]; do
    # shellcheck disable=SC2046
    "$ARBOR_POINTER" click $(real_center_of "$W1")
    "$ARBOR_POINTER" key ctrl+opt+d
    sleep 0.4
    "$ARBOR_BIN/arborctl" home > /dev/null
    sleep 0.3
    "$ARBOR_POINTER" click "$KEYS_X" "$KEYS_Y"
    sleep 0.4
    round=$((round + 1))
  done
  echo "out of the listed app: Arbor got $(($(ran "desktop:") - arbor_before)) of 10; the rest went to the app just clicked"
  ctl home
else
  echo "skipped: it presses faster than anybody can look where, and this Mac is somebody's"
fi

step "for the record: keeping the hot key and passing the press on with postToPid"
check "the app is in front" to_keys_app
"$KEYS" repost 4 &
sleep 1
key ctrl+opt+j
sleep 0.5
key ctrl+opt+j
wait $!
echo "what the app saw of ⌃⌥J (key code 38):"
grep "code=38 " "$KEYS_LOG" || echo "nothing"
arbor_stop 03-after-quit

step "the same app on pauseForApps"
# Listed only once another app is in front: arbor_start waits for Arbor to arrange the test windows.
arbor_start 2 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
ctl dock "$W1" left
ctl dock "$W2" right
sleep 3
check "the test windows' app is in front" to_test_windows
arbor_settings "{$ARBOR_GESTURES_ON, \"pauseForApps\": [\"$KEYS_ID\"]}"
ctl reload-settings
check "running while another app is in front" eventually status_has "^running"
ctl zoom "$W1"
check "framed on 1: 2 is out of view" eventually is parked "$W2"
check "the app comes to the front" summon_keys_app
check "Arbor pauses" eventually status_has "^paused for ArborKeys"
check "every window is in view" eventually all_on_screen
check "no event tap is left" eventually taps_are 0
space_before=$(received 49)
key ctrl+opt+space
check "⌃⌥Space reaches the app" eventually received_is 49 $((space_before + 1))
read -r item_x item_y <<< "$(status_item)"
rightclick "$item_x" "$item_y"
shot 04-menu-paused-for-app
key escape
key cmd+tab
check "⌘Tab away resumes" eventually status_has "^running"
check "the view is back on 1: 2 is out of view again" eventually is parked "$W2"
check "1 is in view" eventually is on_screen "$W1"
ctl pause
check "the app comes to the front" summon_keys_app
key cmd+tab
sleep 1
check "a pause started by hand is not ended by leaving the app" status_has "^paused: "
ctl resume
grep -E "paused|resumed|registered" "$ARBOR_HOME/arbor.log" | tail -n 12
arbor_stop 05-after-quit

step "for F44: can a script switch the keyboard layout here?"
# Which layouts a person has switched on says where they come from, and this gets pasted into pull requests.
on_throwaway_mac && "$KEYS" layout
on_throwaway_mac && "$KEYS" layouts
"$KEYS" layouts all > "$ARBOR_OUT/layouts-installed.txt"
wc -l "$ARBOR_OUT/layouts-installed.txt"
if arbor_may "switch keyboard layouts and add two to the Input menu"; then
"$KEYS" watch 6 &
sleep 1
"$KEYS" select com.apple.keylayout.German
sleep 1
"$KEYS" layout
"$KEYS" select com.apple.keylayout.Russian
sleep 1
"$KEYS" layout
"$KEYS" select com.apple.keylayout.US
sleep 1
"$KEYS" layout
wait $!
"$KEYS" remove com.apple.keylayout.German
"$KEYS" remove com.apple.keylayout.Russian
"$KEYS" layouts
fi

step "for F44: what the keys type"
"$KEYS" dump com.apple.keylayout.US com.apple.keylayout.ABC com.apple.keylayout.British com.apple.keylayout.German \
  com.apple.keylayout.SwissGerman com.apple.keylayout.French com.apple.keylayout.ABC-AZERTY com.apple.keylayout.Dvorak \
  com.apple.keylayout.DVORAK-QWERTYCMD com.apple.keylayout.Colemak com.apple.keylayout.Spanish-ISO \
  com.apple.keylayout.Italian-Pro com.apple.keylayout.Swedish-Pro com.apple.keylayout.Czech com.apple.keylayout.Turkish-QWERTY-PC \
  com.apple.keylayout.Russian com.apple.keylayout.Greek > "$ARBOR_OUT/layouts.jsonl"
wc -l "$ARBOR_OUT/layouts.jsonl"
