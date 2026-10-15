#!/bin/bash
# Can a script take the road a person takes: the switch in System Settings → Privacy & Security → Accessibility, clicked with the pointer?
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-the-switch.sh      (about three minutes; LOOK AT THE PICTURES)
#
# Every other road by which the permission probes take the permission away is a script's: tccutil, a row deleted, a daemon killed, a notification posted
# (README-permission-probes.md). This one opens the pane, finds the row of a bundle of Arbor's own identity by what Accessibility says of the window, and clicks its
# switch. macOS may ask for a password or Touch ID, which a hosted Mac cannot give: then it says so, with a picture, and that is the answer.
# If the switch can be clicked, it is clicked off and on again: what the row, Arbor's status, its taps and its log say two and eight seconds later, and whether
# System Settings posts com.apple.accessibility.api, which everybody says and nobody here has seen. The loss probes can then have it for a road.
#
# An experiment, not a check: it prints what it finds at each step and goes on as far as it gets.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "write to the permission database with sudo, open System Settings and click a switch in Privacy & Security"

BUNDLE_ID=com.evbarleyg.arbor.probe-the-switch
NAME=ArborProbeTheSwitch
TCC="/Library/Application Support/com.apple.TCC/TCC.db"
ASKER="$ARBOR_ROOT/.build/mac-shell/asker"
WITNESS="$ARBOR_ROOT/.build/mac-shell/witness"
AXFIND="$ARBOR_ROOT/.build/mac-shell/axfind"

tcc() { sudo sqlite3 "$TCC" "$1"; }
row() { tcc "SELECT client, auth_value, auth_reason FROM access WHERE service = 'kTCCServiceAccessibility' AND client = '$BUNDLE_ID';"; }
status_starts() { case "$("$ARBOR_BIN/arborctl" status 2>&1)" in "$1"*) return 0 ;; *) return 1 ;; esac; }
arbor_taps() { "$WITNESS" taps | grep -c "pid=$ARBOR_PID " || true; }
gone() { ! kill -0 "$1" 2>/dev/null; }
settings_pid() { pgrep -x "System Settings" | head -n 1; }
ax() { "$AXFIND" "$(settings_pid)" "$@"; }
# What the window says, as VoiceOver would read it.
tree() { ax tree > "$ARBOR_OUT/$1.txt" 2>&1; echo "tree: mac-shell/$1.txt, $(wc -l < "$ARBOR_OUT/$1.txt" | tr -d ' ') elements"; }

arbor_build
for tool in asker witness axfind; do
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/$tool.swift" -o "$ARBOR_ROOT/.build/mac-shell/$tool" \
    > "$ARBOR_OUT/build-$tool.log" 2>&1 || { cat "$ARBOR_OUT/build-$tool.log"; die "scripts/mac-shell/$tool.swift did not compile"; }
done
tcc "SELECT count(*) FROM access;" > /dev/null 2>&1 || die "the permission database cannot be read here"

step "the bundle, granted and running"
arbor_start 2
"$ARBOR_BIN/arborctl" quit > /dev/null
ended "$ARBOR_PID" || die "the session's own Arbor did not quit"
ARBOR_PID=""
app="$HOME/Applications/$NAME.app"
at_exit 'rm -rf "${app:?}"'
rm -rf "${app:?}"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$ARBOR_BIN/Arbor" "$app/Contents/MacOS/Arbor"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" -c "Set :CFBundleName $NAME" -c "Delete :CFBundleURLTypes" "$app/Contents/Info.plist" \
  || die "could not edit Info.plist"
codesign --force --sign - --identifier "$BUNDLE_ID" "$app" || die "codesign failed"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app" || echo "lsregister could not register the bundle"
codesign --display --requirements - "$app" 2>/dev/null | sed -n 's/^\(# \)\{0,1\}designated => //p' > "$ARBOR_SESSION_DIR/requirement.txt"
csreq -r "$ARBOR_SESSION_DIR/requirement.txt" -b "$ARBOR_SESSION_DIR/requirement.bin" || die "csreq could not read the bundle's requirement"
at_exit "tcc \"DELETE FROM access WHERE client = '$BUNDLE_ID';\"; killall 'System Settings' 2>/dev/null"
tcc "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, indirect_object_identifier, flags, last_modified) VALUES ('kTCCServiceAccessibility', '$BUNDLE_ID', 0, 2, 3, 1, X'$(xxd -p "$ARBOR_SESSION_DIR/requirement.bin" | tr -d '\n')', 'UNUSED', 0, strftime('%s', 'now'));" \
  || die "the grant could not be written"
sudo killall -9 tccd 2>/dev/null
sleep 6
limit 20 open -n "$app" --env ARBOR_HOME="$ARBOR_HOME" --env ARBOR_SOCKET="$ARBOR_SOCKET" --env ARBOR_DEBUG=1 \
  --env ARBOR_ONLY_PIDS="$ARBOR_WINDOWS_PID" --env ARBOR_NO_WATCHDOG=1 --env ARBOR_NO_PICTURES=1 --env ARBOR_NO_PROMPT=1 --env ARBOR_NO_STATUS_ITEM=1
sleep 2
ARBOR_PID=$(pgrep -f "$app/Contents/MacOS/Arbor" | head -n 1)
[ -n "$ARBOR_PID" ] || die "the bundle did not start"
started "$ARBOR_PID"
eventually status_starts running || die "Arbor has no permission at launch: $("$ARBOR_BIN/arborctl" status | head -n 1)"
echo "Arbor pid $ARBOR_PID, taps $(arbor_taps), row: $(row)"
"$ASKER" hear 170 > "$ARBOR_OUT/heard.txt" 2>&1 &
started $!

step "the pane"
limit 20 open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
sleep 8
shot 01-the-pane
[ -n "$(settings_pid)" ] || die "System Settings did not open"
tree 01-the-pane
grep -n -i "$NAME\|AXSwitch\|AXCheckBox\|AXToggle" "$ARBOR_OUT/01-the-pane.txt" | cut -c 1-200 | head -n 30

# The row's switch: the first switch or checkbox on the line of the bundle's name, or after it in the tree.
find_switch() {
  python3 - "$ARBOR_OUT/$1.txt" "$NAME" <<'PYTHON'
import re, sys
lines = open(sys.argv[1], errors="replace").read().splitlines()
named = [index for index, line in enumerate(lines) if sys.argv[2] in line]
for index in named:
    for line in lines[index:index + 8]:
        if re.search(r"AXSwitch|AXCheckBox|AXToggle", line):
            numbers = re.findall(r"-?\d+(?:\.\d+)?", line)[-4:]
            x, y, w, h = (float(number) for number in numbers)
            print(int(x + w / 2), int(y + h / 2), "|", line.strip()[:160])
            sys.exit(0)
sys.exit(1)
PYTHON
}
place=$(find_switch 01-the-pane) || { echo "ANSWER: the pane opened, but no switch could be found beside \"$NAME\" in what Accessibility says of the window. See the picture and the tree."; exit 1; }
echo "the switch: $place"
read -r sx sy _ <<< "$place"

# flip <name of the pictures>: one click on the switch, and what everybody says afterwards.
flip() {
  local mark taken
  mark=$(wc -l < "$ARBOR_HOME/arbor.log")
  echo "before: row $(row), Arbor: $("$ARBOR_BIN/arborctl" status | head -n 1 | cut -c 1-60), taps $(arbor_taps)"
  taken=$("$ASKER" now)
  pointer click "$sx" "$sy"
  echo "clicked the switch at $sx $sy at $taken"
  sleep 2
  shot "$1-two-seconds-after-the-click"
  tree "$1-after-the-click"
  echo "windows of macOS's own that came up (a sheet, a dialog):"
  pointer windows --on-screen | awk '$3 >= 0 && $3 < 1000' | grep -v -E "ArborTestWindows|Arbor$|Dock$|Window Server$|Control Center$|Finder$" | head -n 8
  sleep 6
  echo "eight seconds after: row $(row), Arbor: $("$ARBOR_BIN/arborctl" status | head -n 1 | cut -c 1-60), taps $(arbor_taps)"
  tail -n "+$((mark + 1))" "$ARBOR_HOME/arbor.log" | grep -E "ermission|event tap|stopped|started|ERROR" | grep -v "DEBUG said" | cut -c 12-200 | head -n 8
  shot "$1-eight-seconds-after"
}

step "the switch, off"
before=$(row)
flip 02-off
if [ "$(row)" = "$before" ]; then
  echo "ANSWER: the click changed nothing in the database. If a sheet asks for a password or Touch ID, the pictures 02-off-… show it: then a script cannot take this road on a hosted Mac."
  grep -i -E "password|touch id|authenticat|unlock" "$ARBOR_OUT/02-off-after-the-click.txt" | cut -c 1-200 | head -n 8
  cat "$ARBOR_OUT/heard.txt"
  exit 1
fi
echo "ANSWER: the switch CAN be clicked by a script on a hosted Mac: the row went from ($before) to ($(row))."

step "the switch, on again"
flip 03-on

step "who announced anything (com.apple.accessibility.api)"
cat "$ARBOR_OUT/heard.txt"

"$ARBOR_BIN/arborctl" quit > /dev/null 2>&1
eventually gone "$ARBOR_PID" || kill_started "$ARBOR_PID"
ARBOR_PID=""
arbor_log
arbor_close_windows
