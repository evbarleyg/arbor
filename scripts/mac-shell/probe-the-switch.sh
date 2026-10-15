#!/bin/bash
# Can a script take the road a person takes: the switch in System Settings → Privacy & Security → Accessibility, clicked with the pointer? And in which order do things then go?
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-the-switch.sh      (about four minutes; LOOK AT THE PICTURES)
#
# Every other road by which the permission probes take the permission away is a script's: tccutil, a row deleted, a daemon killed, a notification posted
# (README-permission-probes.md). By tccutil the right to tap goes first and input is dropped until the taps are out; with the row deleted and the word said, the flag goes first and
# nothing is dropped. Which of the two a person meets, only the switch can say.
#
# This opens the pane, finds a bundle's row by what Accessibility says of the window, and clicks its switch, once. Meanwhile: a listener for com.apple.accessibility.api
# (the word); the bundle's own answers (the flag and four more questions, every 10 ms, for the bare tapper; arbor.log for Arbor); and a stream of the key F19 every 20 ms with a
# listener at the far end of the taps (the first dropped event). Keys and no clicks: a click elsewhere would bring another window in front of the pane.
# First the bare tapper, which never lets go of its tap: ONE click gives the order. It is killed eight seconds later, which gives the Mac back. Then Arbor: what a person would meet.
#
# macOS may ask for a password or Touch ID, which a hosted Mac cannot give. Then this says so, with a picture, and stops: it does not try to get round it.
# An experiment: it prints what it finds at each step and goes on as far as it gets.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "write to the permission database with sudo, open System Settings and click switches in Privacy & Security"

ARBOR_ID=com.evbarleyg.arbor.probe-the-switch
ARBOR_NAME=ArborProbeTheSwitch
TAPPER_ID=com.evbarleyg.arbor.probe-switch-tapper
TAPPER_NAME=ArborProbeSwitchTapper
TCC="/Library/Application Support/com.apple.TCC/TCC.db"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
ASKER="$ARBOR_ROOT/.build/mac-shell/asker"
WITNESS="$ARBOR_ROOT/.build/mac-shell/witness"
AXFIND="$ARBOR_ROOT/.build/mac-shell/axfind"

tcc() { sudo sqlite3 "$TCC" "$1"; }
row_of() { tcc "SELECT client, auth_value, auth_reason FROM access WHERE service = 'kTCCServiceAccessibility' AND client = '$1';"; }
status_starts() { case "$("$ARBOR_BIN/arborctl" status 2>&1)" in "$1"*) return 0 ;; *) return 1 ;; esac; }
taps_of() { "$WITNESS" taps | grep -c "pid=$1 " || true; }
gone() { ! kill -0 "$1" 2>/dev/null; }
settings_pid() { pgrep -x "System Settings" | head -n 1; }
# What the window says, as VoiceOver would read it.
tree() { "$AXFIND" "$(settings_pid)" tree > "$ARBOR_OUT/$1.txt" 2>&1; echo "tree: mac-shell/$1.txt, $(wc -l < "$ARBOR_OUT/$1.txt" | tr -d ' ') elements"; }
requirement_of() {
  codesign --display --requirements - "$1" 2>/dev/null | sed -n 's/^\(# \)\{0,1\}designated => //p' > "$ARBOR_SESSION_DIR/requirement.txt"
  csreq -r "$ARBOR_SESSION_DIR/requirement.txt" -b "$ARBOR_SESSION_DIR/requirement.bin" || die "csreq could not read the requirement of $1"
  echo "X'$(xxd -p "$ARBOR_SESSION_DIR/requirement.bin" | tr -d '\n')'"
}
grant() {
  tcc "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, indirect_object_identifier, flags, last_modified) VALUES ('kTCCServiceAccessibility', '$1', 0, 2, 3, 1, $2, 'UNUSED', 0, strftime('%s', 'now'));" \
    || die "the grant could not be written"
}

arbor_build
for tool in asker witness axfind; do
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/$tool.swift" -o "$ARBOR_ROOT/.build/mac-shell/$tool" \
    > "$ARBOR_OUT/build-$tool.log" 2>&1 || { cat "$ARBOR_OUT/build-$tool.log"; die "scripts/mac-shell/$tool.swift did not compile"; }
done
tcc "SELECT count(*) FROM access;" > /dev/null 2>&1 || die "the permission database cannot be read here"

step "the two bundles, granted"
arbor_start 1
"$ARBOR_BIN/arborctl" quit > /dev/null
ended "$ARBOR_PID" || die "the session's own Arbor did not quit"
ARBOR_PID=""
app="$HOME/Applications/$ARBOR_NAME.app"
tapper="$HOME/Applications/$TAPPER_NAME.app"
at_exit 'rm -rf "${app:?}" "${tapper:?}"'
rm -rf "${app:?}" "${tapper:?}"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$tapper/Contents/MacOS"
cp "$ARBOR_BIN/Arbor" "$app/Contents/MacOS/Arbor"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $ARBOR_ID" -c "Set :CFBundleName $ARBOR_NAME" -c "Delete :CFBundleURLTypes" "$app/Contents/Info.plist" \
  || die "could not edit Info.plist"
cp "$ASKER" "$tapper/Contents/MacOS/asker"
cat > "$tapper/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$TAPPER_ID</string>
  <key>CFBundleExecutable</key><string>asker</string>
  <key>CFBundleName</key><string>$TAPPER_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - --identifier "$ARBOR_ID" "$app" || die "codesign failed"
codesign --force --sign - --identifier "$TAPPER_ID" "$tapper" || die "codesign failed"
"$LSREGISTER" -f "$app" "$tapper" || echo "lsregister could not register the bundles"
at_exit "tcc \"DELETE FROM access WHERE client IN ('$ARBOR_ID', '$TAPPER_ID');\"; killall 'System Settings' 2>/dev/null"
grant "$ARBOR_ID" "$(requirement_of "$app")"
grant "$TAPPER_ID" "$(requirement_of "$tapper")"
sudo killall -9 tccd 2>/dev/null
sleep 6
"$ASKER" hear 200 > "$ARBOR_OUT/heard.txt" 2>&1 &
started $!

step "the pane"
limit 20 open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
sleep 8
shot 01-the-pane
[ -n "$(settings_pid)" ] || die "System Settings did not open"
tree 01-the-pane
grep -n -E "ArborProbe|AXSwitch|AXCheckBox|AXToggle" "$ARBOR_OUT/01-the-pane.txt" | cut -c 1-200 | head -n 30

# switch_of <tree> <name>: x y of the first switch or checkbox on the line of the bundle's name, or just after it in the tree.
switch_of() {
  python3 - "$ARBOR_OUT/$1.txt" "$2" <<'PYTHON'
import re, sys
lines = open(sys.argv[1], errors="replace").read().splitlines()
for index in (index for index, line in enumerate(lines) if sys.argv[2] in line):
    for line in lines[index:index + 8]:
        if re.search(r"AXSwitch|AXCheckBox|AXToggle", line):
            x, y, w, h = (float(number) for number in re.findall(r"-?\d+(?:\.\d+)?", line)[-4:])
            print(int(x + w / 2), int(y + h / 2))
            sys.exit(0)
sys.exit(1)
PYTHON
}

# Windows on the screen that belong to neither the run nor the furniture: a sheet of macOS's own is another process's window.
strangers() {
  pointer windows --on-screen | awk '$3 >= 0 && $3 < 2000' \
    | grep -v -E " (ArborTestWindows|Arbor|asker|Dock|Finder|Window Server|Control Center|Spotlight|Notification Center|Wallpaper|System Settings)$"
}
# asks_for_a_password <tree>: whether what came up wants a password or Touch ID, in the pane itself or in a window of macOS's agents.
asks_for_a_password() {
  grep -q -i -E "password|touch id|AXSecureTextField" "$ARBOR_OUT/$1.txt" || strangers | grep -q -i -E "SecurityAgent|coreauth|LocalAuthentication|authorizationhost"
}

# order <name> <time of the click> <the bundle's own file, or - >: the word, the questions, the first dropped event, each in ms from the click.
order() {
  python3 - "$ARBOR_OUT/stream-$1.txt" "$ARBOR_OUT/arrivals-$1.txt" "$ARBOR_OUT/heard.txt" "$2" "$3" "$ARBOR_HOME/arbor.log" <<'PYTHON'
import re, sys

def seconds(text):
    hours, minutes, rest = text.split(":")
    return int(hours) * 3600 + int(minutes) * 60 + float(rest)

stream, arrivals, heard, clicked, own, log = sys.argv[1:7]
clicked = seconds(clicked)
text = open(stream).read()
begins = seconds(re.search(r"(\S+) stream begins", text).group(1))
ends = re.search(r"(\S+) stream ends: (\d+)", text)
posted = int(ends.group(2)) if ends else 0
found = [(seconds(m.group(1)), int(m.group(2))) for m in (re.match(r"(\S+) \S+ n=(\d+) ", line) for line in open(arrivals)) if m]
numbers = {number for _, number in found}
missing = [number for number in range(1, posted + 1) if number not in numbers]
events = []
for line in open(heard):
    match = re.match(r"(\S+) heard (\S+)", line)
    if match and seconds(match.group(1)) >= clicked - 0.2:
        events.append((seconds(match.group(1)), "THE WORD: " + match.group(2) + " was posted"))
if own != "-":
    for line in open(own):
        match = re.match(r"(\S+) (question .*|switched-off .*)", line)
        if match and seconds(match.group(1)) >= clicked - 0.2:
            events.append((seconds(match.group(1)), match.group(2)))
else:
    for line in open(log):
        match = re.match(r"\S{11}(\S{12})Z \S+ +(.*(?:ermission is gone|ermission was taken away|stopped;|ermission is back|ermission granted|started:).*)", line)
        if match and seconds(match.group(1)) >= clicked - 0.2:
            events.append((seconds(match.group(1)), "arbor.log: " + match.group(2)[:120]))
if missing:
    events.append((begins + (missing[0] - 1) // 2 * 0.02, f"THE FIRST DROPPED EVENT was due (n={missing[0]})"))
    later = [time for time, number in found if number > missing[-1]]
    events.append((later[0], f"the first event to arrive again (after {len(missing)} lost)") if later else (seconds(ends.group(1)), f"the stream ends; nothing has arrived again ({len(missing)} lost)"))
print(f"posted {posted}, arrived {len(numbers)}, lost {len(missing)}")
for time, what in sorted(events):
    print(f"  {(time - clicked) * 1000:+7.0f} ms  {what}")
if not events:
    print("  nothing happened: no word, no change of answer, nothing dropped")
PYTHON
}

# flip <name> <bundle id> <name in the list> <pid> <the bundle's own file or ->: the stream, one click on the switch two seconds in, pictures. 1 if the row did not change.
flip() {
  local name=$1 id=$2 listed=$3 pid=$4 own=$5 place sx sy before clicked stream
  tree "$name-before"
  place=$(switch_of "$name-before" "$listed") || { echo "ANSWER: no switch could be found beside \"$listed\" in what Accessibility says of the window. See the picture and the tree."; return 1; }
  read -r sx sy <<< "$place"
  before=$(row_of "$id")
  echo "the switch of $listed is at $sx $sy; row ($before); taps of pid $pid: $(taps_of "$pid")"
  : > "$ARBOR_OUT/arrivals-$name.txt"
  "$ASKER" arrivals 13 >> "$ARBOR_OUT/arrivals-$name.txt" 2>&1 &
  started $!
  eventually grep -q arrivals-ready "$ARBOR_OUT/arrivals-$name.txt" || die "the listener at the end of the taps did not start"
  "$ASKER" stream 10 20 "$sx" "$sy" --kinds key > "$ARBOR_OUT/stream-$name.txt" 2>&1 &
  stream=$!
  started "$stream"
  sleep 2
  clicked=$("$ASKER" now)
  pointer click "$sx" "$sy"
  echo "clicked at $clicked"
  sleep 1.5
  shot "$name-after-the-click"
  echo "windows that are neither the run's nor the furniture's (id pid level x y w h on owner):"
  strangers
  # Before anything else that needs input: a tapper that never lets go has the Mac's input by now, if the switch worked.
  sleep 5
  echo "6.5 s after the click: row ($(row_of "$id")); taps of pid $pid: $(taps_of "$pid")"
  [ "$own" = - ] || kill_started "$pid"
  ended "$stream" 80 || echo "the stream did not come to its end"
  sleep 0.5
  tree "$name-after"
  if [ "$(row_of "$id")" = "$before" ]; then
    if asks_for_a_password "$name-after"; then
      echo "ANSWER: macOS ASKS FOR A PASSWORD OR TOUCH ID before it lets the switch be moved (picture $name-after-the-click.png). A script cannot take this road on a hosted Mac, and this one does not try to get round it."
      grep -i -E "password|touch id|AXSecureTextField" "$ARBOR_OUT/$name-after.txt" | cut -c 1-180 | head -n 6
    else
      echo "ANSWER: the click changed nothing in the database, and nothing on the screen asks for a password. See the picture $name-after-the-click.png and the tree."
    fi
    return 1
  fi
  echo "ANSWER: THE SWITCH CAN BE CLICKED by a script on a hosted Mac: the row went from ($before) to ($(row_of "$id"))."
  echo "THE ORDER, in ms from the click:"
  order "$name" "$clicked" "$own"
}

step "the bare tapper's switch, off: one click gives the order"
: > "$ARBOR_OUT/tapper.txt"
limit 20 open -n -g "$tapper" --args tap 40 "$ARBOR_OUT/tapper.txt"
eventually grep -q tap-ready "$ARBOR_OUT/tapper.txt" || die "the bare tapper has no tap: $(cat "$ARBOR_OUT/tapper.txt")"
TAPPER_PID=$(sed -n 's/.*tap-ready pid=//p' "$ARBOR_OUT/tapper.txt")
started "$TAPPER_PID"
at_exit "kill -9 $TAPPER_PID 2>/dev/null"
flip 02-tapper "$TAPPER_ID" "$TAPPER_NAME" "$TAPPER_PID" "$ARBOR_OUT/tapper.txt" || { cat "$ARBOR_OUT/heard.txt"; exit 1; }

step "Arbor's switch, off: what a person would meet"
limit 20 open -n -g "$app" --env ARBOR_HOME="$ARBOR_HOME" --env ARBOR_SOCKET="$ARBOR_SOCKET" --env ARBOR_DEBUG=1 \
  --env ARBOR_ONLY_PIDS="$ARBOR_WINDOWS_PID" --env ARBOR_NO_WATCHDOG=1 --env ARBOR_NO_PICTURES=1 --env ARBOR_NO_PROMPT=1 --env ARBOR_NO_STATUS_ITEM=1
sleep 2
ARBOR_PID=$(pgrep -f "$app/Contents/MacOS/Arbor" | head -n 1)
[ -n "$ARBOR_PID" ] || die "the bundle did not start"
started "$ARBOR_PID"
eventually status_starts running || die "Arbor has no permission at launch: $("$ARBOR_BIN/arborctl" status | head -n 1)"
flip 03-arbor-off "$ARBOR_ID" "$ARBOR_NAME" "$ARBOR_PID" -
"$ARBOR_BIN/arborctl" status | head -n 1 | cut -c 1-120

step "Arbor's switch, on again: does it notice by itself?"
mark=$(wc -l < "$ARBOR_HOME/arbor.log")
flip 04-arbor-on "$ARBOR_ID" "$ARBOR_NAME" "$ARBOR_PID" -
"$ARBOR_BIN/arborctl" status | head -n 1 | cut -c 1-120
tail -n "+$((mark + 1))" "$ARBOR_HOME/arbor.log" | grep -E "ermission|started|event tap" | grep -v "DEBUG said" | cut -c 12-170 | head -n 8

step "who announced anything (com.apple.accessibility.api)"
cat "$ARBOR_OUT/heard.txt"

"$ARBOR_BIN/arborctl" quit > /dev/null 2>&1
eventually gone "$ARBOR_PID" || kill_started "$ARBOR_PID"
ARBOR_PID=""
arbor_log
arbor_close_windows
