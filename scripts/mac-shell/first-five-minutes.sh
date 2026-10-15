#!/bin/bash
# The first five minutes, as a newcomer has them: a Mac with macOS's settings as they come, an Arbor that has never run and has no
# permission, real clicks, real drags all the way to the screen's edge, real keys. In pictures, words and checks.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/first-five-minutes.sh
#
#   1  the launch: nothing moves, the welcome window opens and asks for the permission and nothing else
#   2  the permission: Open Settings…, macOS's own dialog and what becomes of it, the grant, whether the window is to be seen afterwards
#   3  the four moves as the window words them, all keys, with macOS's settings as they come; the one way back it names
#   4  a hand that drags to the edge all the same: macOS takes the window, and Arbor says who did and where that can be changed
#   5  Check Setup…: Switch Off macOS Tiling, whether macOS obeys at once; a pause, a resume; Put Them Back
#   6  the menu
#   7  quitting with the choice standing: every window as it was found, and macOS's settings too
#
# Arbor is a copy of the app under an identifier of its own, opened as Finder opens it, so that it answers for its own permissions.
# The grant is written into the permission database, which is what the switch in System Settings does.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "write to the permission database with sudo, restart tccd, open and quit System Settings, and have Arbor change Desktop & Dock settings"
case "${ARBOR_SESSION_DIR:-}" in /tmp/arbor-shell.*) ;; *) die "no session folder of this run's" ;; esac

BUNDLE_ID=com.evbarleyg.arbor.first-five-minutes
DOMAIN=com.apple.WindowManager
KEYS="EnableTilingByEdgeDrag EnableTopTilingByEdgeDrag EnableTilingOptionAccelerator"
TCC="/Library/Application Support/com.apple.TCC/TCC.db"
AXFIND="$ARBOR_ROOT/.build/mac-shell/axfind"

tcc() { sudo sqlite3 "$TCC" "$1"; }
ax() { "$AXFIND" "$ARBOR_PID" "$@"; }
status_starts() { case "$("$ARBOR_BIN/arborctl" status 2>&1)" in "$1"*) return 0 ;; *) return 1 ;; esac; }
switches() { for name in $KEYS; do echo "  $name: $(defaults read $DOMAIN "$name" 2>/dev/null || echo "not set")"; done; }
all_switches_are() { for name in $KEYS; do [ "$(defaults read $DOMAIN "$name" 2>/dev/null || echo "not set")" = "$1" ] || return 1; done; }
frames() { echo "$(real_frame_of "$W1") | $(real_frame_of "$W2") | $(real_frame_of "$W3") | $(real_frame_of "$W4")"; }
nothing_moved() { [ "$(frames)" = "$found" ]; }

# The welcome window, by its title: its width changes with the page, and glides.
welcome_id() { ax window Arbor 2>/dev/null; }
welcome_frame() {
  local id
  id=$(welcome_id) || return 1
  overlays | awk -v id="$id" '$1 == id && $8 == "on" { printf "%d %d %d %d\n", $4, $5, $6, $7; found = 1 } END { exit !found }'
}
# Where it has come to rest: two looks that agree.
settled_frame() {
  local before now tries=0
  before=$(welcome_frame) || return 1
  while [ "$tries" -lt 10 ]; do
    sleep 0.3
    now=$(welcome_frame) || return 1
    [ "$now" = "$before" ] && break
    before=$now
    tries=$((tries + 1))
  done
  echo "$now"
}
no_welcome_window() { ! welcome_frame > /dev/null; }
says() { ax point - "$1" > /dev/null 2>&1; }
says_not() { ! says "$1"; }
# What the window says, as VoiceOver would read it.
words() { ax tree 2>/dev/null | grep -E "AXStaticText|AXButton|AXImage" | sed 's/^ *//' | cut -c 1-260 > "$ARBOR_OUT/$1.txt"; echo "words: mac-shell/$1.txt"; }
see() { shot "$1"; look "$1-window" "$(welcome_id)"; words "$1"; }
# press <title>: a real click on the button of that title in a window of Arbor's.
press() {
  local where
  where=$(ax point AXButton "$1" 2>/dev/null) || { check "there is a button “$1” to press" false; return 1; }
  # shellcheck disable=SC2086
  click $where
}
# Whether the welcome window is the first of the ordinary windows on the screen, front to back.
welcome_is_in_front() {
  [ "$(pointer windows --on-screen | awk '$3 >= 0 && $3 < 20 && $6 > 100 && $7 > 100 { print $1; exit }')" = "$(welcome_id)" ]
}
# macOS's own preview of a tile.
macos_preview() { pointer windows | awk '$8 == "on" && $9 == "WindowManager" { found = 1 } END { exit !found }'; }
no_macos_preview() { ! macos_preview; }
# Arbor's own. For the moves the welcome window is at the preview's level, so has_overlay 3 would say yes to it.
arbor_preview() { overlays | awk -v welcome="$(welcome_id)" '$3 == 3 && $8 == "on" && $1 != welcome { found = 1 } END { exit !found }'; }
# Where to take hold of a window, and where to click in it: towards its left.
grab_of() {
  local x y w h
  read -r x y w h <<< "$(real_frame_of "$1")"
  x=${x%.*}; y=${y%.*}
  [ "$x" -lt 0 ] && x=0
  echo "$((x + 110)) $((y + 12))"
}
inside_of() {
  local x y w h
  read -r x y w h <<< "$(real_frame_of "$1")"
  x=${x%.*}; y=${y%.*}; h=${h%.*}
  echo "$((x + 60)) $((y + h / 2))"
}
# window_at <x> <y>: the frontmost window there that takes a click. Arbor's own panels but the welcome window let clicks through, and above
# level 20 lie layers of macOS's own as large as the display (seen on a hosted Mac: with them counted, nothing is ever to be seen).
window_at() {
  pointer windows --on-screen | awk -v x="$1" -v y="$2" -v arbor="$ARBOR_PID" -v welcome="$(welcome_id)" \
    '$3 >= 0 && $3 < 20 && ($2 != arbor || $1 == welcome) && $4 <= x && x < $4 + $6 && $5 <= y && y < $5 + $7 { print $1; exit }'
}
# seen_point_of <id>: a point of its title bar that nothing lies over.
seen_point_of() {
  local x y w h at
  read -r x y w h <<< "$(real_frame_of "$1")"
  for at in 110 $((w / 2)) $((w - 60)) $((w - 20)); do
    if [ "$(window_at $((x + at)) $((y + 12)))" = "$1" ]; then
      echo "$((x + at)) $((y + 12))"
      return 0
    fi
  done
  return 1
}
# uncover <x> <y>: on a small display the welcome window, which floats above everything, may lie over the point. A person would push it
# aside, and so does this, to the top corner further from the point, and counts it: from then on the window stays where it was put.
pushed=0
uncover() {
  local frame wx wy ww wh
  frame=$(settled_frame) || return 0
  read -r wx wy ww wh <<< "$frame"
  [ "$1" -ge "$wx" ] && [ "$1" -le "$((wx + ww))" ] && [ "$2" -ge "$wy" ] && [ "$2" -le "$((wy + wh))" ] || return 0
  echo "the welcome window ($wx $wy $ww $wh) lies over ($1 $2): pushed aside by hand"
  pushed=$((pushed + 1))
  if [ "$1" -lt "$((screen_width / 2))" ]; then
    drag "$((wx + ww / 2))" "$((wy + 14))" "$((screen_width - ww / 2 - 8))" 50
  else
    drag "$((wx + ww / 2))" "$((wy + 14))" "$((ww / 2 + 8))" 50
  fi
  sleep 0.5
}
# Where the window rests, while nobody has pushed it: it glides there.
rests_in_the_right_corner() {
  local frame wx wy ww wh
  frame=$(welcome_frame) || return 1
  read -r wx wy ww wh <<< "$frame"
  [ "$((wx + ww))" -eq "$((screen_width - 12))" ]
}
# The moves are made exactly as the window words them: the keys are read from the window, so they are whatever keys ship.
ticks() { ax tree 2>/dev/null | grep AXImage | grep -c '"Done"'; }
ticked() { [ "$(ticks)" = "$1" ]; }
# keys_after <words>: the shortcut that follows those words in the window, as `key` wants it: "⌃⌥⌘←" as ctrl+opt+cmd+left.
keys_after() {
  ax tree 2>/dev/null | grep -o "$1 [^ \"]*" | head -n 1 | sed "s/^$1 //" \
    | sed 's/⌃/ctrl+/; s/⌥/opt+/; s/⇧/shift+/; s/⌘/cmd+/; s/←/left/; s/→/right/; s/↩/return/; s/⎋/escape/; s/Space/space/' | tr 'A-Z' 'a-z'
}
make_move() {
  local keys
  keys=$(keys_after "$1")
  check "the window names the keys after “$1”" test -n "$keys"
  [ -n "$keys" ] && key "$keys"
}

# macOS's own dialog, a window of a process of its own.
asking_pid() { pointer windows --on-screen | awk '$9 == "universalAccessAuthWarn" { print $2; found = 1; exit } END { exit !found }'; }
macos_asks() { asking_pid > /dev/null; }
macos_asks_no_more() { ! macos_asks; }
menu_is_open() { pointer windows | awk '$3 == 101 && $8 == "on" { found = 1 } END { exit !found }'; }
menu_is_closed() { ! menu_is_open; }
close_menu() { menu_is_open || return 0; key escape; eventually menu_is_closed; }

arbor_build
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/axfind.swift" -o "$AXFIND" > "$ARBOR_OUT/build-axfind.log" 2>&1 \
  || { cat "$ARBOR_OUT/build-axfind.log"; die "scripts/mac-shell/axfind.swift did not compile"; }
# What System Settings posts when its switch is flipped.
cat > "$ARBOR_SESSION_DIR/notice.swift" << 'SWIFT'
import Foundation
DistributedNotificationCenter.default().postNotificationName(
  Notification.Name("com.apple.accessibility.api"), object: nil, userInfo: nil, deliverImmediately: true)
SWIFT
swiftc -O -swift-version 5 "$ARBOR_SESSION_DIR/notice.swift" -o "$ARBOR_SESSION_DIR/notice" > "$ARBOR_OUT/build-notice.log" 2>&1 \
  || { cat "$ARBOR_OUT/build-notice.log"; die "the tool that posts the notice did not compile"; }
read -r _ _ _ screen_width screen_height _ <<< "$(pointer displays | head -n 1)"

step "the Mac, as it comes"
sw_vers | tr '\n' ' '; echo
echo "the display is $screen_width by $screen_height points"
switches
check "every switch is as macOS comes" all_switches_are "not set"
tcc "SELECT count(*) FROM access;" > /dev/null 2>&1 || die "the permission database cannot be read here"

app="$ARBOR_SESSION_DIR/Arbor.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$ARBOR_BIN/Arbor" "$app/Contents/MacOS/Arbor"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" -c "Delete :CFBundleURLTypes" "$app/Contents/Info.plist" || die "could not edit Info.plist"
# As scripts/sign.sh stamps what it signs without a certificate, which is how this copy is signed two lines on.
/usr/libexec/PlistBuddy -c "Add :ArborSignature string adhoc" "$app/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :ArborSignature adhoc" "$app/Contents/Info.plist"
codesign --force --sign - --identifier "$BUNDLE_ID" "$app" || die "codesign failed"
tcc "DELETE FROM access WHERE client = '$BUNDLE_ID';"
at_exit "tcc \"DELETE FROM access WHERE client = '$BUNDLE_ID';\"; for name in $KEYS; do defaults delete $DOMAIN \$name 2>/dev/null; done; killall 'System Settings' 2>/dev/null"

# The witness: an app that writes down the keys it is given (keys.swift). Low on the left: the welcome window comes up in the middle of the
# display, System Settings beside it, the moves at the right.
# (Not KEYS, which is the list of macOS's three settings above.)
WITNESS="$ARBOR_ROOT/.build/mac-shell/keys" KEYS_APP="$ARBOR_SESSION_DIR/ArborKeys.app" KEYS_LOG="$ARBOR_OUT/keys.log" KEYS_PID=""
# Where the other scripts that use it put it, so that whichever comes second on a Mac finds it made.
if [ ! -x "$WITNESS" ] || [ "$ARBOR_ROOT/scripts/mac-shell/keys.swift" -nt "$WITNESS" ]; then
  mkdir -p "${WITNESS%/*}"
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/keys.swift" -o "$WITNESS" > "$ARBOR_OUT/build-keys.log" 2>&1 \
    || die "scripts/mac-shell/keys.swift did not compile"
fi
mkdir -p "$KEYS_APP/Contents/MacOS"
cp "$WITNESS" "$KEYS_APP/Contents/MacOS/keys"
at_exit 'kill_started $KEYS_PID'
cat > "$KEYS_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>dev.arbor.test.keys</string>
  <key>CFBundleExecutable</key><string>keys</string>
  <key>CFBundleName</key><string>ArborKeys</string>
  <key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
# How often the witness has been given a plain J (key code 38).
js() { grep -c "^[0-9:.]* down code=38 " "$KEYS_LOG" 2>/dev/null || true; }
# A J is typed once, and looked for for two seconds: a hosted Mac's window server stands still for a second now and then.
j_arrives() {
  local before tries
  before=$(js)
  key j || return 1
  for tries in 1 2 3 4 5 6 7 8 9 10; do
    [ "$(js)" -gt "$before" ] && return 0
    sleep 0.2
  done
  return 1
}
# Typed, and not there after the same two seconds. That nothing could be typed at all, or the log not read, is no answer.
j_does_not_arrive() {
  local before
  before=$(js)
  [ -r "$KEYS_LOG" ] && key j || return 1
  sleep 2
  [ "$(js)" -eq "$before" ]
}

step "1  the launch"
ARBOR_BUNDLE=$app ARBOR_MAY_LACK_PERMISSION=1 ARBOR_TEST_WINDOWS_ARGS="--regular" \
  arbor_start 4 ARBOR_NO_PROMPT=0 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0 ARBOR_MAC_SWITCHES=1
# The moves are made on two of them, front to back; the two at the back no hand touches.
FIRST=$W4 SECOND=$W3
found=$(frames)
echo "the windows as they were found: $found"
ctl status
check "the welcome window opens by itself" eventually welcome_frame
see 10-launch
check "nothing has moved" nothing_moved
check "it names the permission" says "Accessibility"
check "and nothing else: not macOS's own tiling" says_not "macOS tiling"
check "what Arbor is for, and what it has over macOS's tiling" says "Arbor keeps it."
check "the keys, in a sentence" says "put a window left or right"
check "and what to do where the switch is on already: another build over an old grant" says "Already on? Switch it off and on again"
check "“under this icon” is the warning sign, which is what the menu bar shows while Arbor waits" says "Arbor needs Accessibility permission"
"$ARBOR_BIN/arborctl" doctor 2>&1 | cut -c 1-240
if item=$(status_item); then
  # shellcheck disable=SC2086
  click $item
  check "a click on the menu bar item opens the menu" eventually menu_is_open
  shot 11-menu-without-permission
  "$ARBOR_BIN/arborctl" menu
  close_menu
fi
# A newcomer who has read the keys presses one before granting anything.
early=$(keys_after "until you ask\.")
check "the welcome names a key" test -n "$early"
if [ -n "$early" ]; then
  key "$early"
  sleep 0.3
  shot 12-a-key-before-the-grant
  check "Arbor takes the key and says why, on screen" grep -q "said on .*Arbor needs the Accessibility permission" "$ARBOR_HOME/arbor.log"
  check "nothing has moved" nothing_moved
  check "and macOS has not been made to ask" macos_asks_no_more
fi

step "2  the permission"
settings_are_open() { pointer windows --on-screen | awk '$9 == "System" && $10 == "Settings" { found = 1 } END { exit !found }'; }
press "Open Settings…"
check "macOS asks, with its own dialog" eventually macos_asks
sleep 2.5
shot 20-macos-asks
settings_are_closed() { ! settings_are_open; }
check "and Arbor has not opened System Settings over it" settings_are_closed
if where=$("$AXFIND" "$(asking_pid)" point AXButton "Open System Settings" 2>/dev/null); then
  # shellcheck disable=SC2086
  click $where
else
  check "the dialog has a button Open System Settings" false
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
fi
sleep 8
shot 21-system-settings
check "its button opens System Settings" settings_are_open
check "and the dialog is gone: nothing is left lying over the person's windows" eventually macos_asks_no_more
echo "on the screen, front to back:"; pointer windows --on-screen | awk '$3 >= 0 && $3 < 20'
# Whose the keyboard is. The person is in another app when the permission arrives: System Settings mostly, here one that writes down what
# it is given. Arbor's window comes forward and turns its page by itself then, and what is typed goes on arriving where it did.
# Without descriptor 9, the test windows' stdin: they quit when it closes, and would wait for this app as well.
"$KEYS_APP/Contents/MacOS/keys" app "$KEYS_LOG" 20 520 260 160 9>&- &
KEYS_PID=$!
started "$KEYS_PID"
keys_ready() { grep -q "ready pid=$KEYS_PID " "$KEYS_LOG" 2>/dev/null; }
eventually keys_ready || die "the key-logging app did not start"
click 80 620
sleep 0.5
check "typed before the grant, a plain J arrives in the app the person is in" j_arrives
codesign --display --requirements - "$app" 2>/dev/null | sed -n 's/^\(# \)\{0,1\}designated => //p' | csreq -r- -b "$ARBOR_SESSION_DIR/requirement.bin"
hex=$(xxd -p "$ARBOR_SESSION_DIR/requirement.bin" | tr -d '\n')
tcc "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, indirect_object_identifier, flags, last_modified) VALUES ('kTCCServiceAccessibility', '$BUNDLE_ID', 0, 2, 3, 1, X'$hex', 'UNUSED', 0, strftime('%s', 'now'));" \
  || die "the grant could not be written"
# The switch in System Settings does more than write the row: it posts a notice, and a running process learns of a grant through nothing else
# (seen on a hosted Mac: neither the row nor a restart of tccd is noticed). In this order: announced before tccd has read the row, the flag
# says yes and event taps stay refused in that process. A relaunch is the last resort, and then the script cannot say whether a running Arbor
# hears of the grant: it says so instead of calling it a fault.
noticed() { eventually status_starts running || eventually status_starts running; }
took="the row, a restart of tccd, and the notice System Settings posts"
sudo killall -9 tccd 2>/dev/null
sleep 3
"$ARBOR_SESSION_DIR/notice"
if ! noticed; then
  took="a relaunch"
  grep -i "accessibility" "$ARBOR_HOME/arbor.log" | tail -n 3 | cut -c 12-220
  "$ARBOR_BIN/arborctl" quit
  sleep 2.5
  kill -0 "$ARBOR_PID" 2>/dev/null && kill -9 "$ARBOR_PID"
  ARBOR_BUNDLE=$app
  arbor_open_bundle ARBOR_ONLY_PIDS="$ARBOR_WINDOWS_PID" ARBOR_NO_PROMPT=0 ARBOR_DEBUG=1 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0 \
    ARBOR_NO_WATCHDOG=1 ARBOR_MAC_SWITCHES=1
  started "$ARBOR_PID"
  noticed || die "Arbor does not see the grant even after a relaunch"
  # The window has been seen, so this launch does not open it by itself.
  ctl check-setup
fi
echo "what it took for Arbor to see the grant: $took"
[ "$took" = "a relaunch" ] || check "typed just after the grant, it arrives there" j_arrives
sleep 1.5
see 22-granted
echo "on the screen, front to back:"; pointer windows --on-screen | awk '$3 >= 0 && $3 < 20'
if [ "$took" = "a relaunch" ]; then
  echo "NOT ANSWERED HERE: whether a running Arbor notices the permission by itself, and whether its window then comes in front of System Settings"
  ctl welcome
else
  check "Arbor noticed the permission by itself" status_starts running
  check "the welcome window is in front of System Settings" welcome_is_in_front
fi
check "with nothing else to decide it has gone on to the moves" eventually says "Four moves to try"
check "nothing has moved" nothing_moved
if [ "$took" != "a relaunch" ]; then
  check "typed after the page has turned, it arrives there still: the window has not taken the keyboard" j_arrives
  shot 23-the-keyboard-stays
  # The control, and the other half of the rule: whoever asks for the window gets the keyboard in it. By the command, which is what the
  # menu's Welcome… runs; the menu itself is not opened here.
  ctl welcome
  sleep 0.6
  check "after the window has been asked for, by the command welcome, it does not: the keyboard is in the window" j_does_not_arrive
  shot 24-asked-for
  # And the control's control: the tool still types and the witness still writes.
  click 80 620
  sleep 0.5
  check "clicked again, the app has the keyboard back" j_arrives
fi
kill_started "$KEYS_PID"
killall "System Settings" 2>/dev/null
sleep 1

step "3  the four moves, with macOS's settings as they come"
ctl trace on first-five-minutes-moves
see 30-moves
check "nothing is ticked yet" ticked 0
check "no drag is taught" says_not "Drag"
# shellcheck disable=SC2046
uncover $(inside_of "$FIRST")
# shellcheck disable=SC2046
click $(inside_of "$FIRST")
make_move "Click a window and press"
check "the window docked" eventually is docked "$FIRST"
check "the first move is ticked" eventually ticked 1
see 31-docked
[ "$pushed" -gt 0 ] || check "the welcome window is in the corner away from the docked window" eventually rests_in_the_right_corner
echo "the second window is at $(real_frame_of "$SECOND"), the welcome window at $(welcome_frame)"
# A dock touches only what is docked, so the others lie where they lay, partly under the docked window. A person clicks what they see.
if where=$(seen_point_of "$SECOND"); then
  # shellcheck disable=SC2086
  click $where
else
  check "something of the second window's title bar is to be seen, to click on" false
fi
make_move "Click another and press"
check "the second window docked" eventually is docked "$SECOND"
check "the second move is ticked" eventually ticked 2
see 32-side-by-side
arranged=$(frames)
third=$(keys_after "Then press")
make_move "Then press"
check "it fills the screen: the other is out of view" eventually is parked "$FIRST"
check "the third move is ticked" eventually ticked 3
see 33-fills-the-screen
keys=$(keys_after "Press")
check "the fourth move is the same key again" test -n "$keys" -a "$keys" = "$third"
[ -n "$keys" ] && key "$keys"
check "the other is back" eventually is on_screen "$FIRST"
check "the fourth move is ticked" eventually ticked 4
sleep 1
check "the arrangement is back, to the point" test "$(frames)" = "$arranged"
see 34-back
check "after the last tick: what to do when the icon cannot be seen" says "Can’t see the icon?"
check "macOS's settings have not been touched" all_switches_are "not set"
check "and nothing is written down" test ! -e "$ARBOR_HOME/macos-settings-before.json"
# The one way back the window names.
make_move_back=$(ax tree 2>/dev/null | grep -o '[^ "]* pauses Arbor' | head -n 1 | sed 's/ pauses Arbor//' \
  | sed 's/⌃/ctrl+/; s/⌥/opt+/; s/⇧/shift+/; s/⌘/cmd+/; s/⎋/escape/' | tr 'A-Z' 'a-z')
check "it names one way back, with its key" test -n "$make_move_back"
[ -n "$make_move_back" ] && key "$make_move_back"
check "the key pauses Arbor" eventually status_starts paused
sleep 1
echo "paused: $(frames)"
echo "found:  $found"
check "and every window is as it was" nothing_moved
shot 35-paused
[ -n "$make_move_back" ] && key "$make_move_back"
check "the same key resumes" eventually status_starts running
# A trace ends when Arbor stops.
cp "$ARBOR_HOME"/traces/*.jsonl "$ARBOR_OUT/" 2>/dev/null
ctl trace on first-five-minutes-drags
ctl float-all
sleep 1
press "Done"
check "Done closes the window" eventually no_welcome_window

step "4  a hand that drags to the edge all the same"
# Also the control for step 5: here macOS must be seen to tile.
held_from=$(real_frame_of "$FIRST")
# shellcheck disable=SC2046
drag $(grab_of "$FIRST") 0 400 --hold 1.2 --no-release
check "the window came along" test "$(real_frame_of "$FIRST")" != "$held_from"
shot 40-held-at-the-edge
check "with its tiling on, macOS shows its preview at the edge" macos_preview
echo "Arbor shows a preview too: $(arbor_preview && echo yes || echo no)"
release
film 41-let-go 6
sleep 1.5
shot 42-let-go
echo "the window ended at $(real_frame_of "$FIRST"); Arbor says $(frame_of "$FIRST"), $(is docked "$FIRST" && echo docked || echo floating)"
tail -n 8 "$ARBOR_HOME/arbor.log" | cut -c 12-220
check "Arbor says on screen who took the window, and where that can be changed" grep -q "said on .*macOS tiled this window; Arbor stood aside.*Check Setup" "$ARBOR_HOME/arbor.log"
is docked "$FIRST" && ctl float "$FIRST"
# shellcheck disable=SC2046
drag $(grab_of "$FIRST") 430 112
# macOS gives the window its size back with a motion of its own.
sleep 2

step "5  Check Setup…"
ctl check-setup
check "Check Setup… opens the window" eventually welcome_frame
see 50-check-setup
check "here macOS's tiling is spoken of" says "Your Mac tiles a window dragged to a screen edge, before Arbor gets it."
check "with the three settings by their names" says "Drag windows to menu bar to fill screen"
before_the_step=$(frames)
if press "Switch Off macOS Tiling"; then
  sleep 1.5
  see 51-after-the-step
  switches
  check "the three switches are off" all_switches_are 0
  check "and the click on the wallpaper is left as it was found" test -z "$(defaults read $DOMAIN EnableStandardClickToShowDesktop 2>/dev/null)"
  echo "what Arbor wrote down:"; cat "$ARBOR_HOME/macos-settings-before.json"; echo
  check "the window says what was done" says "While Arbor runs, 3 settings of macOS are off"
  check "and how to undo it" says "Put Them Back"
  "$ARBOR_BIN/arborctl" doctor 2>&1 | head -n 8 | cut -c 1-240
fi
check "no window moved for it" test "$(frames)" = "$before_the_step"
# shellcheck disable=SC2046
uncover $(grab_of "$FIRST")
# shellcheck disable=SC2046
drag $(grab_of "$FIRST") 0 400 --hold 1.2 --no-release
shot 52-held-at-the-edge
check "macOS is seen to have stopped tiling: it shows no preview" no_macos_preview
# "A window dragged to a screen edge docks now", says the row.
check "Arbor shows where the window will land" arbor_preview
release
check "the window docked" eventually is docked "$FIRST"
check "and is where Arbor put it" eventually is in_slot "$FIRST"
shot 53-let-go
# With something docked this is no newcomer's Mac any more: what Check Setup… says then.
ctl check-setup
see 53-check-setup-with-something-docked
ctl float-all
sleep 1
# Only while Arbor arranges windows. A pause is a quit that comes back.
before_the_pause=$(frames)
ctl pause
check "a pause gives macOS its tiling back" eventually all_switches_are "not set"
see 54-paused
check "and the window says so" says "Arbor is paused, so macOS has its tiling back"
check "a pause moves no floating window" test "$(frames)" = "$before_the_pause"
ctl resume
check "resuming takes it again, unasked" eventually all_switches_are 0
# Check Setup… is an ordinary window, and the window that was dragged lies over it by now. A person would fetch it from the menu.
ctl check-setup
check "asked for again, Check Setup… comes to the front" eventually welcome_is_in_front
if press "Put Them Back"; then
  sleep 1.5
  see 55-put-back
  switches
  check "every switch is as it was found" all_switches_are "not set"
  check "and nothing is left written down" test ! -e "$ARBOR_HOME/macos-settings-before.json"
fi
press "Done"
check "Done closes the window" eventually no_welcome_window

step "6  the menu"
if item=$(status_item); then
  # shellcheck disable=SC2086
  click $item
  check "a click on the menu bar item opens the menu" eventually menu_is_open
  shot 60-menu
  "$ARBOR_BIN/arborctl" menu | head -n 12
  close_menu
fi
mkdir -p "$ARBOR_OUT/traces"
cp "$ARBOR_HOME"/traces/*.jsonl "$ARBOR_OUT/traces/" 2>/dev/null

step "7  quitting"
# With the choice standing: back to normal is one thing.
ctl fix-setup
check "the three switches are off" all_switches_are 0
echo "before: $(frames)"
"$ARBOR_BIN/arborctl" quit
sleep 2.5
switches
check "quitting leaves macOS's settings as they were found" all_switches_are "not set"
echo "what stays written down is the choice:"; cat "$ARBOR_HOME/macos-settings-before.json"; echo
echo "after:  $(frames)"
echo "found:  $found"
# Arbor itself has moved them, onto the Desktop and out of view and back.
check "the two windows that no hand touched are exactly where they were found" test "$(real_frame_of "$W1") | $(real_frame_of "$W2")" = "$(echo "$found" | cut -d '|' -f 1-2 | sed 's/ $//')"
# All four were opened at one size. To a point: dragged off macOS's own tile, a window of 480 by 348 is left at 481 by 349 by macOS itself.
own_size=$(echo "${found##* | }" | awk '{ print int($3), int($4) }')
has_its_own_size() {
  real_frame_of "$1" | awk -v own="$own_size" '{ split(own, o, " "); w = $3 - o[1]; h = $4 - o[2]; exit !(w >= -1 && w <= 1 && h >= -1 && h <= 1) }'
}
for id in "$FIRST" "$SECOND"; do
  check "window $id, docked and dragged, has its own size back — it is at $(real_frame_of "$id")" has_its_own_size "$id"
done
arbor_stop 70-after-quit
