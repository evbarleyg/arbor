#!/bin/bash
# What wakes the Accessibility flag in a process that is already running?
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-permission-grant.sh      (about five minutes)
#
# Launched without the permission, Arbor asks AXIsProcessTrusted() once a second and promises to notice by itself. check-F63.sh writes the
# grant into the permission database and restarts tccd, and on a hosted Mac Arbor went on waiting for two and a half minutes, while
# the next process to be started had the permission at once. Is that Arbor, or the way a script grants?
#
# asker.swift, in a bundle under an identifier of its own and opened by Launch Services, so that it answers for its own permission, writes down
# twice a second what it is told: the flag, whether it can make an active tap, whether it can make one that only listens. Round it the
# entry is written, tccd is restarted, and the distributed notification com.apple.accessibility.api is posted, seven seconds apart and in two
# orders, so that each is seen alone. Then the same for a process that HAS the permission and loses it: the entry set to "denied", as the
# switch records it; `tccutil reset`; the entry deleted. Last, Arbor itself, as a bundle, through the first of these.
#
# It measures; its few checks are about whether the measurement is worth anything. ask-<round>.txt are the raw lists.
# What it cannot do is press the switch in System Settings, which is the road a person takes.
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/lib-gestures.sh"
needs_throwaway_mac "write to the permission database with sudo, restart tccd and reset two bundles' Accessibility permission"

ASKER_ID=com.evbarleyg.arbor.probe-asker
ARBOR_ID=com.evbarleyg.arbor.probe-permission-grant
TCC="/Library/Application Support/com.apple.TCC/TCC.db"
ASKER="$ARBOR_ROOT/.build/mac-shell/asker"

tcc() { sudo sqlite3 "$TCC" "$1"; }
gone() { ! kill -0 "$1" 2>/dev/null; }

arbor_build
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/asker.swift" -o "$ASKER" > "$ARBOR_OUT/build-asker.log" 2>&1 \
  || { cat "$ARBOR_OUT/build-asker.log"; die "scripts/mac-shell/asker.swift did not compile"; }
tcc "SELECT count(*) FROM access;" > /dev/null 2>&1 || die "the permission database cannot be read here"
tcc ".schema access" | head -n 30 > "$ARBOR_OUT/schema.txt"

# requirement_of <bundle>: its designated requirement as the database keeps it.
requirement_of() {
  codesign --display --requirements - "$1" 2>/dev/null | sed -n 's/^\(# \)\{0,1\}designated => //p' > "$ARBOR_SESSION_DIR/requirement.txt"
  csreq -r "$ARBOR_SESSION_DIR/requirement.txt" -b "$ARBOR_SESSION_DIR/requirement.bin" || die "csreq could not read the requirement of $1"
  echo "X'$(xxd -p "$ARBOR_SESSION_DIR/requirement.bin" | tr -d '\n')'"
}

step "the asker's bundle"
asker_app="$ARBOR_SESSION_DIR/ArborAsker.app"
mkdir -p "$asker_app/Contents/MacOS"
cp "$ASKER" "$asker_app/Contents/MacOS/asker"
cat > "$asker_app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$ASKER_ID</string>
  <key>CFBundleExecutable</key><string>asker</string>
  <key>CFBundleName</key><string>ArborAsker</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - --identifier "$ASKER_ID" "$asker_app" || die "codesign failed"
# tccutil finds a bundle by its identifier in Launch Services' list, which is kept for each user: as root it knows nothing of a bundle this user opened.
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$LSREGISTER" -f "$asker_app" || echo "lsregister could not register the asker"
sudo "$LSREGISTER" -f "$asker_app" || echo "lsregister could not register the asker for root"
ASKER_REQUIREMENT=$(requirement_of "$asker_app")
at_exit "tcc \"DELETE FROM access WHERE client IN ('$ASKER_ID', '$ARBOR_ID');\""

# Whose entry the ways below are about.
CLIENT=$ASKER_ID
REQUIREMENT=$ASKER_REQUIREMENT
written() {
  tcc "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, indirect_object_identifier, flags, last_modified) VALUES ('kTCCServiceAccessibility', '$CLIENT', 0, 2, 3, 1, $REQUIREMENT, 'UNUSED', 0, strftime('%s', 'now'));" \
    || die "the grant could not be written"
}
denied() { tcc "UPDATE access SET auth_value = 0 WHERE service = 'kTCCServiceAccessibility' AND client = '$CLIENT';"; }
deleted() { tcc "DELETE FROM access WHERE service = 'kTCCServiceAccessibility' AND client = '$CLIENT';"; }
tccd_restarted() { sudo killall -9 tccd 2>/dev/null; }
announced() { "$ASKER" announce > /dev/null; }
reset_by_tccutil() { tccutil reset Accessibility "$CLIENT" || sudo tccutil reset Accessibility "$CLIENT"; }

# changes <file>: the first line, and every line at which an answer differs from the line before.
changes() { awk '{ answer = $3 " " $4 " " $5 } answer != last { print "    " $1, answer } { last = answer }' "$1"; }

# a_round <name> <with|without> <way>…: a new asker, with or without the permission, then each way, seven seconds apart.
a_round() {
  local name=$1 start=$2 way pid list="$ARBOR_OUT/ask-$1.txt"
  shift 2
  step "$name: a process started $start the permission; then: $*"
  deleted
  [ "$start" = with ] && written
  tccd_restarted
  sleep 1
  : > "$list"
  limit 20 open -n "$asker_app" --args ask "$(($# * 7 + 6))" "$list"
  sleep 3
  pid=$(pgrep -f "$asker_app/Contents/MacOS/asker" | head -n 1)
  [ -n "$pid" ] && started "$pid"
  check "$name: the asker runs and writes" test -s "$list"
  check "$name: it began $start the permission" grep -q "flag=$([ "$start" = with ] && echo yes || echo no) " "$list"
  for way in "$@"; do
    echo "  $("$ASKER" now) $way"
    "$way"
    sleep 7
  done
  [ -z "$pid" ] || eventually gone "$pid" || kill_started "$pid"
  echo "  what it was told, whenever that changed:"
  changes "$list"
  echo "  the last: $(tail -n 1 "$list" | cut -d' ' -f 3-)"
  # The control: what a process that has never asked is told now.
  : > "$list.new"
  limit 20 open -n "$asker_app" --args ask 1 "$list.new"
  sleep 3
  echo "  a new process now: $(head -n 1 "$list.new" | cut -d' ' -f 3-)"
}

"$ASKER" hear 400 > "$ARBOR_OUT/heard.txt" 2>&1 &
started $!

a_round grant-1 without written tccd_restarted announced
a_round grant-2 without written announced tccd_restarted
a_round loss-1 with denied tccd_restarted announced
a_round loss-2 with reset_by_tccutil announced
a_round loss-3 with deleted announced tccd_restarted

step "who announced anything (com.apple.accessibility.api, as this script's own listener heard it)"
cat "$ARBOR_OUT/heard.txt"

step "Arbor itself, as a bundle, launched without the permission; then: written, tccd restarted, announced"
# This is about the taps, so it asks for them, whatever Arbor ships with. The file stays in the session's home, which every Arbor of this run is given.
arbor_settings "{$ARBOR_GESTURES_ON}"
arbor_start 2
"$ARBOR_BIN/arborctl" quit > /dev/null
ended "$ARBOR_PID" || die "the session's own Arbor did not quit"
ARBOR_PID=""
app="$ARBOR_SESSION_DIR/Arbor.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$ARBOR_BIN/Arbor" "$app/Contents/MacOS/Arbor"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $ARBOR_ID" -c "Delete :CFBundleURLTypes" "$app/Contents/Info.plist" \
  || die "could not edit Info.plist"
codesign --force --sign - --identifier "$ARBOR_ID" "$app" || die "codesign failed"
CLIENT=$ARBOR_ID
REQUIREMENT=$(requirement_of "$app")
deleted
tccd_restarted
sleep 1
limit 20 open -n "$app" --env ARBOR_HOME="$ARBOR_HOME" --env ARBOR_SOCKET="$ARBOR_SOCKET" --env ARBOR_DEBUG=1 \
  --env ARBOR_ONLY_PIDS="$ARBOR_WINDOWS_PID" --env ARBOR_NO_WATCHDOG=1 --env ARBOR_NO_PICTURES=1
sleep 3
ARBOR_PID=$(pgrep -f "$app/Contents/MacOS/Arbor" | head -n 1)
[ -n "$ARBOR_PID" ] || die "the bundle did not start"
started "$ARBOR_PID"
says() { "$ARBOR_BIN/arborctl" status 2>&1 | head -n 1 | cut -c 1-60; }
echo "  $("$ASKER" now) launched: $(says)"
check "Arbor waits for the permission" test "$(says | cut -c 1-7)" = waiting
shot arbor-1-waiting
woke=""
for way in written tccd_restarted announced; do
  echo "  $("$ASKER" now) $way"
  "$way"
  for _ in 1 2 3 4 5 6 7; do
    sleep 1
    case "$(says)" in running*) [ -n "$woke" ] || { woke=$way; echo "  $("$ASKER" now) Arbor is running, after: $way"; } ;; esac
  done
  echo "  $("$ASKER" now) seven seconds later: $(says)"
done
shot arbor-2-afterwards
echo "WHAT WOKE ARBOR: ${woke:-nothing}"
check "Arbor notices by itself, by one of the three" test -n "$woke"
cut -c 12-200 "$ARBOR_HOME/arbor.log" | grep -v DEBUG | tail -n 12
"$ARBOR_BIN/arborctl" quit > /dev/null 2>&1
eventually gone "$ARBOR_PID" || kill_started "$ARBOR_PID"
ARBOR_PID=""
arbor_log
arbor_close_windows
