#!/bin/bash
# The first five minutes, as a newcomer has them: a Mac with macOS's settings as they come, an Arbor that has never run and has no
# permission, real clicks, real drags all the way to the screen's edge, real keys. In pictures, words and checks.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/first-five-minutes.sh
#
#   1  the launch: nothing moves, the welcome window opens, the menu bar says what is missing
#   2  the permission: Open Settings…, the grant, and whether the window is to be seen afterwards
#   3  somebody who passes the offer by: the four moves as the window words them with macOS's own tiling on, and no reminder afterwards
#   4  the one step: Switch Off macOS Tiling, and whether macOS obeys at once
#   5  the four moves as the window words them then, the drags ending at the very edge, where a hand ends them
#   6  afterwards: the menu, Check Setup…, Put Them Back
#   7  quitting: every window as it was found, and macOS's settings too
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
rests_right_of() {
  local frame wx wy ww wh x y w h
  frame=$(welcome_frame) || return 1
  read -r wx wy ww wh <<< "$frame"
  read -r x y w h <<< "$(real_frame_of "$1")"
  [ "$wx" -ge "$((${x%.*} + ${w%.*}))" ]
}
rests_in_the_middle() {
  local frame wx wy ww wh
  frame=$(welcome_frame) || return 1
  read -r wx wy ww wh <<< "$frame"
  [ "$((2 * wx + ww - screen_width))" -ge -4 ] && [ "$((2 * wx + ww - screen_width))" -le 4 ]
}
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
codesign --force --sign - --identifier "$BUNDLE_ID" "$app" || die "codesign failed"
tcc "DELETE FROM access WHERE client = '$BUNDLE_ID';"
at_exit "tcc \"DELETE FROM access WHERE client = '$BUNDLE_ID';\"; for name in $KEYS; do defaults delete $DOMAIN \$name 2>/dev/null; done; killall 'System Settings' 2>/dev/null"

step "1  the launch"
ARBOR_BUNDLE=$app ARBOR_MAY_LACK_PERMISSION=1 ARBOR_TEST_WINDOWS_ARGS="--regular" \
  arbor_start 4 ARBOR_NO_PROMPT=0 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0 ARBOR_MAC_SWITCHES=1
# The moves are made on three of them, front to back; the one at the back no hand touches.
FIRST=$W4 SECOND=$W3 THIRD=$W2
found=$(frames)
echo "the windows as they were found: $found"
ctl status
check "the welcome window opens by itself" eventually welcome_frame
see 10-launch
check "nothing has moved" nothing_moved
check "it names the permission" says "Accessibility"
check "and macOS's own tiling, before anything is arranged" says "macOS tiling"
"$ARBOR_BIN/arborctl" doctor 2>&1 | cut -c 1-240
if item=$(status_item); then
  # shellcheck disable=SC2086
  click $item
  check "a click on the menu bar item opens the menu" eventually menu_is_open
  shot 11-menu-without-permission
  "$ARBOR_BIN/arborctl" menu
  close_menu
fi

step "2  the permission"
press "Open Settings…"
sleep 8
shot 20-system-settings
echo "on the screen, front to back:"; pointer windows --on-screen | awk '$3 >= 0 && $3 < 20'
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
sleep 1.5
see 21-granted
echo "on the screen, front to back:"; pointer windows --on-screen | awk '$3 >= 0 && $3 < 20'
if [ "$took" = "a relaunch" ]; then
  echo "NOT ANSWERED HERE: whether a running Arbor notices the permission by itself, and whether its window then comes in front of System Settings"
else
  check "Arbor noticed the permission by itself" status_starts running
  check "the welcome window is in front of System Settings" welcome_is_in_front
fi
check "it has not gone on past the offer" says "Switch Off macOS Tiling"
check "and is headed by what Arbor is for" says "Arbor keeps your windows arranged"
check "nothing has moved" nothing_moved
killall "System Settings" 2>/dev/null
sleep 1
"$ARBOR_BIN/arborctl" doctor 2>&1 | cut -c 1-240

# The moves are made exactly as the window words them: what it says is read from the window, and a move it does not name is not made.
ticks() { ax tree 2>/dev/null | grep AXImage | grep -c '"Done"'; }
ticked() { [ "$(ticks)" = "$1" ]; }
frame_and_show_everything() {
  check "the third move is worded with the keys" says "Then press ⌃⌥↩"
  key ctrl+opt+return
  check "⌃⌥↩ framed the window docked last: the other is out of view" eventually is parked "$FIRST"
  check "and so is the one that was never docked" eventually is parked "$THIRD"
  check "the third move is ticked" eventually ticked 3
  see "$1-framed"
  check "the fourth move is worded with the keys" says "Then press ⌃⌥Space"
  key ctrl+opt+space
  check "⌃⌥Space showed everything" eventually is on_screen "$FIRST"
  check "the window that was never docked as well" eventually is on_screen "$THIRD"
  check "the fourth move is ticked" eventually ticked 4
  see "$1-everything"
}

step "3  somebody who passes the offer by: the four moves with macOS's tiling on"
ctl trace on first-five-minutes
press "Continue"
sleep 1
see 30-moves-with-tiling-on
check "nothing is ticked yet" ticked 0
check "the first move is one that works on this Mac as it is set" says "Click a window and press ⌃⌥⌘←"
check "and no drag to an edge is taught" says_not "Drag a window to the left edge of the screen"
# shellcheck disable=SC2046
uncover $(inside_of "$FIRST")
# shellcheck disable=SC2046
click $(inside_of "$FIRST")
key ctrl+opt+cmd+left
check "the window docked" eventually is docked "$FIRST"
check "the first move is ticked" eventually ticked 1
see 31-docked
[ "$pushed" -gt 0 ] || check "the welcome window has gone over the Desktop, beside the docked window" eventually rests_right_of "$FIRST"
check "the second move is made with the keys as well" says "Click another and press ⌃⌥⌘→"
echo "the second window is at $(real_frame_of "$SECOND"), the welcome window at $(welcome_frame)"
# shellcheck disable=SC2046
uncover $(grab_of "$SECOND")
# shellcheck disable=SC2046
click $(grab_of "$SECOND")
key ctrl+opt+cmd+right
check "the second window docked" eventually is docked "$SECOND"
check "the second move is ticked" eventually ticked 2
see 32-side-by-side
[ "$pushed" -gt 0 ] || check "the welcome window is between the two" eventually rests_in_the_middle
check "during the moves it says little but the moves" says_not "Can’t see the icon?"
frame_and_show_everything 33
check "after the last tick the offer is made once more, where it is understood" says "Want to dock with the mouse too?"
check "and one more move, for whoever likes" says "One more, if you like: drag a third onto the edge of a docked one"
check "and what to do when the icon cannot be seen" says "Can’t see the icon?"
# What a hand does that has read nothing: all the way to the edge. Also the control for step 5: here macOS must be seen to tile. The window
# in front, whose title bar nothing covers.
ctl float-all
sleep 1
held_from=$(real_frame_of "$FIRST")
# shellcheck disable=SC2046
uncover $(grab_of "$FIRST")
# shellcheck disable=SC2046
drag $(grab_of "$FIRST") 0 400 --hold 1.2 --no-release
check "the window came along" test "$(real_frame_of "$FIRST")" != "$held_from"
shot 34-held-at-the-edge-with-tiling-on
check "with its tiling on, macOS shows its preview at the edge" macos_preview
echo "Arbor shows a preview too: $(arbor_preview && echo yes || echo no)"
release
film 35-let-go 6
sleep 1.5
shot 36-let-go
echo "the window ended at $(real_frame_of "$FIRST"); Arbor says $(frame_of "$FIRST"), $(is docked "$FIRST" && echo docked || echo floating)"
tail -n 8 "$ARBOR_HOME/arbor.log" | cut -c 12-220
is docked "$FIRST" && ctl float "$FIRST"
# shellcheck disable=SC2046
uncover $(grab_of "$FIRST")
# shellcheck disable=SC2046
drag $(grab_of "$FIRST") 380 152
sleep 1
press "Done"
check "Done closes the window" eventually no_welcome_window
if item=$(status_item); then
  # shellcheck disable=SC2086
  click $item
  check "a click on the menu bar item opens the menu" eventually menu_is_open
  shot 37-menu-with-the-offer-declined
  "$ARBOR_BIN/arborctl" menu | head -n 6
  close_menu
fi

step "4  the one step"
ctl check-setup
check "Check Setup… opens the window" eventually welcome_frame
see 40-before-the-step
before_the_step=$(frames)
if press "Switch Off macOS Tiling"; then
  sleep 1.5
  see 41-after-the-step
  switches
  check "the three switches are off" all_switches_are 0
  check "and the click on the wallpaper is left as it was found" test -z "$(defaults read $DOMAIN EnableStandardClickToShowDesktop 2>/dev/null)"
  echo "what Arbor wrote down:"; cat "$ARBOR_HOME/macos-settings-before.json"; echo
  check "the window says what was done" says "While Arbor runs, 3 settings of macOS are off"
  check "and how to undo it" says "Put Them Back"
  "$ARBOR_BIN/arborctl" doctor 2>&1 | head -n 8 | cut -c 1-240
  # Only while Arbor runs. A pause is a quit that comes back.
  ctl pause
  check "a pause gives macOS its tiling back" eventually all_switches_are "not set"
  see 42-paused
  check "and the window says so" says "Arbor is paused, so macOS has its tiling back"
  ctl resume
  check "resuming takes it again, unasked" eventually all_switches_are 0
fi
check "no window moved for it" test "$(frames)" = "$before_the_step"

step "5  the four moves with the screen edges Arbor's"
press "Continue"
sleep 1
see 50-moves-with-tiling-off
check "nothing is ticked yet" ticked 0
check "the first move is the drag now" says "Drag a window to the left edge of the screen"
# shellcheck disable=SC2046
uncover $(grab_of "$FIRST")
# shellcheck disable=SC2046
drag $(grab_of "$FIRST") 0 400 --hold 1.2 --no-release
shot 51-held-at-the-edge
check "macOS is seen to have stopped tiling: it shows no preview" no_macos_preview
check "Arbor shows where the window will land" arbor_preview
release
film 52-let-go 6
check "the window docked" eventually is docked "$FIRST"
check "and is where Arbor put it" eventually is in_slot "$FIRST"
check "the first move is ticked" eventually ticked 1
see 53-docked
check "the second move is a drag as well" says "Drag another to the right edge"
echo "the second window is at $(real_frame_of "$SECOND"), the welcome window at $(welcome_frame)"
# shellcheck disable=SC2046
uncover $(grab_of "$SECOND")
# shellcheck disable=SC2046
drag $(grab_of "$SECOND") "$((screen_width - 1))" 400 --hold 1.2 --no-release
shot 54-held-at-the-right-edge
check "macOS shows no preview there either" no_macos_preview
check "Arbor shows where the window will land" arbor_preview
release
check "the second window docked" eventually is docked "$SECOND"
check "and is where Arbor put it" eventually is in_slot "$SECOND"
check "the second move is ticked" eventually ticked 2
see 55-side-by-side
frame_and_show_everything 56
check "the way back is at hand where the moves end" says "macOS tiling is off while Arbor runs: drag a window to a screen edge, and it docks."
# The fifth, for whoever likes: the window that was left lying, onto the lower edge of the one docked at the right.
echo "the third window is at $(real_frame_of "$THIRD"), the welcome window at $(welcome_frame)"
# shellcheck disable=SC2046
uncover $(grab_of "$THIRD")
read -r x y w h <<< "$(real_frame_of "$SECOND")"
# shellcheck disable=SC2046
drag $(grab_of "$THIRD") "$((${x%.*} + ${w%.*} / 2))" "$((${y%.*} + ${h%.*} - 20))" --hold 1.5 --no-release
shot 57-held-over-a-docked-windows-edge
check "Arbor shows where the window will land" arbor_preview
release
check "the third window docked" eventually is docked "$THIRD"
check "the fifth move is ticked" eventually ticked 5
see 58-three-docked
press "Done"
check "Done closes the window" eventually no_welcome_window
shot 59-after-the-window
echo "on a display of $screen_width by $screen_height the welcome window had to be pushed aside $pushed times"

step "6  afterwards"
if item=$(status_item); then
  # shellcheck disable=SC2086
  rightclick $item
  check "a right click on the menu bar item opens the menu" eventually menu_is_open
  shot 60-menu
  close_menu
fi
ctl check-setup
check "Check Setup… opens the window" eventually welcome_frame
see 61-check-setup
if press "Put Them Back"; then
  sleep 1.5
  see 62-put-back
  switches
  check "every switch is as it was found" all_switches_are "not set"
  check "and nothing is left written down" test ! -e "$ARBOR_HOME/macos-settings-before.json"
fi
# The words follow the switch on a window that is showing, whoever flips it.
press "Continue"
check "with the switches back on, the first move is made with the keys again" eventually says "Click a window and press ⌃⌥⌘←"
ctl fix-setup
check "flipped from a terminal while the moves are showing: the words change at once" eventually says "Drag a window to the left edge of the screen"
see 63-words-follow-the-switch
ctl fix-setup undo
check "and back" eventually says "Click a window and press ⌃⌥⌘←"
check "every switch is as it was found" all_switches_are "not set"
ctl trace off
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
# Arbor itself has moved it, onto the Desktop and out of view and back.
check "the window that no hand touched is exactly where it was found" test "$(real_frame_of "$W1")" = "${found%% | *}"
size_of() { real_frame_of "$1" | awk '{ print int($3), int($4) }'; }
# All three were opened at one size.
own_size=$(echo "${found##* | }" | awk '{ print int($3), int($4) }')
for id in "$FIRST" "$SECOND" "$THIRD"; do
  check "window $id, docked and dragged, has its own size back" test "$(size_of "$id")" = "$own_size"
done
arbor_stop 70-after-quit
