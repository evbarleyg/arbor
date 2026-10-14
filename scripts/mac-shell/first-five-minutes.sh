#!/bin/bash
# The first five minutes, as a newcomer has them: a Mac with macOS's settings as they come, an Arbor that has never run and has no
# permission, real clicks, real drags all the way to the screen's edge, real keys. In pictures, words and checks.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/first-five-minutes.sh
#
#   1  the launch: nothing moves, the welcome window opens, the menu bar says what is missing
#   2  the permission: Open Settings…, the grant, and whether the window is to be seen afterwards
#   3  somebody who passes the advice by: the first move, with macOS's own tiling still on
#   4  the one step: Switch Them Off, and whether macOS obeys at once
#   5  the three moves, with the drag ending at the very edge, where a hand ends it
#   6  afterwards: the menu, Check Setup…, Put Them Back
#   7  quitting: every window as it was found
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
frames() { echo "$(real_frame_of "$W1") | $(real_frame_of "$W2") | $(real_frame_of "$W3")"; }
nothing_moved() { [ "$(frames)" = "$found" ]; }

# The welcome window is 560 points wide.
welcome_id() { overlays | awk '$8 == "on" && $6 == 560 { print $1; exit }'; }
welcome_frame() { overlays | awk '$8 == "on" && $6 == 560 { print $4, $5, $6, $7; found = 1; exit } END { exit !found }'; }
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
grab_of() {
  local x y w h left right
  read -r x y w h <<< "$(real_frame_of "$1")"
  x=${x%.*}; y=${y%.*}; w=${w%.*}
  left=$x; right=$((x + w))
  [ "$left" -lt 0 ] && left=0
  [ "$right" -gt "$screen_width" ] && right=$screen_width
  echo "$(((left + right) / 2)) $((y + 12))"
}
menu_is_open() { pointer windows | awk '$3 == 101 && $8 == "on" { found = 1 } END { exit !found }'; }
menu_is_closed() { ! menu_is_open; }
close_menu() { menu_is_open || return 0; key escape; eventually menu_is_closed; }

arbor_build
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/axfind.swift" -o "$AXFIND" > "$ARBOR_OUT/build-axfind.log" 2>&1 \
  || { cat "$ARBOR_OUT/build-axfind.log"; die "scripts/mac-shell/axfind.swift did not compile"; }
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
  arbor_start 3 ARBOR_NO_PROMPT=0 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0 ARBOR_MAC_SWITCHES=1
found=$(frames)
echo "the windows as they were found: $found"
ctl status
check "the welcome window opens by itself" eventually welcome_frame
see 10-launch
check "nothing has moved" nothing_moved
check "it names the permission" says "Accessibility"
check "and macOS's own settings, before anything is arranged" says "Desktop & Dock settings"
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
if ! eventually status_starts running; then
  sudo killall -9 tccd 2>/dev/null
  sleep 3
fi
check "Arbor notices the permission by itself" eventually status_starts running
sleep 1.5
see 21-granted
echo "on the screen, front to back:"; pointer windows --on-screen | awk '$3 >= 0 && $3 < 20'
check "the welcome window is in front of System Settings" welcome_is_in_front
check "it has not gone on past what is in the way" says "Desktop & Dock settings"
check "nothing has moved" nothing_moved
killall "System Settings" 2>/dev/null
sleep 1
"$ARBOR_BIN/arborctl" doctor 2>&1 | cut -c 1-240

step "3  somebody who passes the advice by"
press "Continue"
sleep 1
see 30-moves-with-tiling-on
# shellcheck disable=SC2046
drag $(grab_of "$W3") 0 400 --hold 1.2 --no-release
shot 31-held-at-the-edge
echo "macOS shows a preview: $(macos_preview && echo yes || echo no); Arbor shows one: $(has_overlay 3 && echo yes || echo no)"
release
film 32-let-go 6
sleep 1.5
see 33-let-go
echo "the window ended at $(real_frame_of "$W3"); Arbor says $(frame_of "$W3"), $(is docked "$W3" && echo docked || echo floating)"
summary
tail -n 12 "$ARBOR_HOME/arbor.log" | cut -c 12-220
# Back to where it was.
is docked "$W3" && ctl float "$W3"
# shellcheck disable=SC2046
drag $(grab_of "$W3") 512 300
sleep 1

step "4  the one step"
press "Back"
sleep 1
see 40-before-the-step
if press "Switch Them Off"; then
  sleep 1.5
  see 41-after-the-step
  switches
  check "the three switches are off" all_switches_are 0
  check "and the click on the wallpaper is left as it was found" test -z "$(defaults read $DOMAIN EnableStandardClickToShowDesktop 2>/dev/null)"
  echo "what Arbor wrote down:"; cat "$ARBOR_HOME/macos-settings-before.json"; echo
  check "the window says how to undo it" says "Put Them Back"
  "$ARBOR_BIN/arborctl" doctor 2>&1 | head -n 8 | cut -c 1-240
fi
check "nothing has moved but what was dragged" test "$(real_frame_of "$W1") | $(real_frame_of "$W2")" = "${found% | *}"

step "5  the three moves"
press "Continue"
sleep 1
# shellcheck disable=SC2046
drag $(grab_of "$W3") 0 400 --hold 1.2 --no-release
shot 50-held-at-the-edge
check "macOS shows no preview" no_macos_preview
check "Arbor shows where the window will land" has_overlay 3
release
film 51-let-go 6
check "the window docked" eventually is docked "$W3"
check "and is where Arbor put it" eventually is in_slot "$W3"
see 52-docked
# shellcheck disable=SC2046
click $(center_of "$W3")
key ctrl+opt+return
check "⌃⌥↩ framed it" eventually is parked "$W1"
see 53-framed
key ctrl+opt+space
check "⌃⌥Space showed everything" eventually is on_screen "$W1"
see 54-everything
press "Done"
check "Done closes the window" eventually no_welcome_window
shot 55-after-the-window

step "6  afterwards"
if item=$(status_item); then
  # shellcheck disable=SC2086
  rightclick $item
  check "a right click on the menu bar item opens the menu" eventually menu_is_open
  shot 60-menu
  "$ARBOR_BIN/arborctl" menu | head -n 12
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

step "7  quitting"
echo "before: $(frames)"
"$ARBOR_BIN/arborctl" quit
sleep 2.5
echo "after:  $(frames)"
echo "found:  $found"
check "the two windows that were never touched are exactly where they were found" test "$(real_frame_of "$W1") | $(real_frame_of "$W2")" = "${found% | *}"
size_of() { real_frame_of "$1" | awk '{ print int($3), int($4) }'; }
check "the one that was docked has its own size back" test "$(size_of "$W3")" = "$(echo "${found##* | }" | awk '{ print int($3), int($4) }')"
arbor_stop 70-after-quit
