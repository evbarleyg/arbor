#!/bin/bash
# A key that Arbor claims never reaches the app in front, unless the person said so (collab/IDEAS.md, I16; F63). With real keys and a witness:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-claimed-keys.sh
#
# On a tester's Mac ⌃⌥A, then Arbor's `arrange`, ran the ⌃⌥A of the app in front, twice, and that destroyed something there. Nobody knows what state
# Arbor was in, and nobody asks. So this goes through EVERY state in which Arbor's process is alive and its item is in the menu bar, and asks
# the one question in each: with an app in front that writes down every key it is given (keys.swift), does the key get to it?
#
# Its first run, as a probe of the Arbor of 2026-10-15 (macOS 26.6.2), found three states in which it did and nobody had said so: 1, 1c and 1d below. In none
# of them had Arbor registered a hot key. It also found that macOS never refuses a registration (3, 4): see collab/reality.json.
#
# THE QUESTIONS ONLY A MAC CAN ANSWER
#   1. Waiting for the Accessibility permission (a first launch; a new build whose signature the old grant does not fit), and after the permission was
#      taken away: is Arbor's item in the menu bar, is the key taken all the same, and does the line on screen say why?
#   2. With no event tap at all (`pointerGestures` false, as shipped): is any default shortcut taken only by a tap? Every default is pressed.
#   3. Another program holds the same chord: does RegisterEventHotKey refuse? Who hears the press: the first, the last, both, the app in front?
#   4. The hot key is Arbor's, and the app hears of the key by a road of its own: a menu item, a hot key of its own, a global monitor, a tap.
#   5. A pause, a held view, an app on `passThroughApps`, `hotkeysEnabled` false, secure input.
#   6. While the hot keys are being registered anew: how long are there none, and does a press get through?
#
# The key is ⌃⌥Z, which Arbor binds in every map. Every round has its control, and ends in one line that begins with RESULT: the state, what `status` says, whether the item shows, who got the key.
#
# Arbor runs from an app bundle started through Launch Services, so that it answers for its own permission: the entry in the privacy
# database is the bundle's, and the tools that press the keys keep theirs. (check-F63.sh switches the permission off for everybody, and can
# press nothing meanwhile.)
#
# Only on GitHub's Macs: it writes to the privacy database and types into whatever has the keyboard.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "write to the privacy database, and press keys that land in whichever app has the keyboard"

KEYS="$ARBOR_ROOT/.build/mac-shell/keys"
ANNOUNCE="$ARBOR_ROOT/.build/mac-shell/announce-accessibility"
KEYS_APP="$ARBOR_ROOT/.build/mac-shell/ArborKeys.app"
KEYS_ID=dev.arbor.test.keys
KEYS_LOG="$ARBOR_OUT/keys.log"
KEYS_PID=""
CLAIM_PID=""
# Low on the left: the welcome window comes up in the middle of the display.
KEYS_FRAME="20 520 260 160"
KEYS_X=150
KEYS_Y=620
ARBOR_ID=com.evbarleyg.arbor
TCC="/Library/Application Support/com.apple.TCC/TCC.db"
# The key where a US keyboard has A: what the witness's other roads and `keys claim` are made for, so rounds 3 and 4 bind it first.
A=0
# And Z: `undo`, a key of Arbor's in every map.
Z=6

tcc() { sudo sqlite3 "$TCC" "$1"; }
front_is() { [ "$("$KEYS" frontmost)" = "$1" ]; }
count() { grep -c "$1" "$2" 2>/dev/null || true; }
# given <down|up> <key code>: how often the app itself was given that. The other roads write "road …" after the time, and are counted apart.
given() { count "^[0-9:.]* $1 code=$2 " "$KEYS_LOG"; }
status_line() { "$ARBOR_BIN/arborctl" status 2>&1 | head -n 1 | cut -c 1-70; }
status_starts() { case "$(status_line)" in "$1"*) return 0 ;; *) return 1 ;; esac; }
holder() { cat "$ARBOR_HOME/arbor.lock" 2>/dev/null; }
answers() { "$ARBOR_BIN/arborctl" status > /dev/null 2>&1; }
patiently() { eventually "$@" || eventually "$@" || eventually "$@" || eventually "$@"; }
item_shows() { [ -n "$ARBOR_PID" ] && "$ARBOR_POINTER" status-item "$ARBOR_PID" --frame > /dev/null 2>&1; }

# The switch in System Settings does three things, and so does this, in that order: it writes the entry, the daemon (which answers from memory) learns of
# it, and the change is announced, which is how a running process hears of it.
told() {
  sudo killall -9 tccd 2>/dev/null
  sleep 2
  "$ANNOUNCE"
}
# grant [hex of a code requirement]: the bundle's own entry, made from one that is there, so that it has whatever columns this macOS has.
grant() {
  local requirement=NULL
  [ -n "${1:-}" ] && requirement="X'$1'"
  tcc "DELETE FROM access WHERE service = 'kTCCServiceAccessibility' AND client = '$ARBOR_ID';
    CREATE TEMP TABLE one AS SELECT * FROM access WHERE service = 'kTCCServiceAccessibility' AND auth_value = 2 LIMIT 1;
    UPDATE one SET client = '$ARBOR_ID', client_type = 0, csreq = $requirement;
    INSERT INTO access SELECT * FROM one;"
  told
  echo "$(arbor_now) the bundle has an entry that allows${1:+, for one signature only}"
}
withdraw() {
  tcc "UPDATE access SET auth_value = 0 WHERE service = 'kTCCServiceAccessibility' AND client = '$ARBOR_ID';"
  told
  echo "$(arbor_now) the bundle's entry says no"
}
forget() {
  tcc "DELETE FROM access WHERE service = 'kTCCServiceAccessibility' AND client = '$ARBOR_ID';"
  told
}

# witness [roads]: the app that writes down its keys, afresh.
witness() {
  [ -n "$KEYS_PID" ] && { kill_started "$KEYS_PID"; KEYS_PID=""; }
  rm -f "$KEYS_LOG"
  # shellcheck disable=SC2086
  KEYS_ROADS="${1:-}" "$KEYS_APP/Contents/MacOS/keys" app "$KEYS_LOG" $KEYS_FRAME &
  KEYS_PID=$!
  started "$KEYS_PID"
  keys_ready() { grep -q "ready pid=$KEYS_PID " "$KEYS_LOG" 2>/dev/null; }
  eventually keys_ready || die "the key-logging app did not start"
  grep "road " "$KEYS_LOG" | sed 's/^/  /'
}

# launch [NAME=value…]: the bundle, the way Finder starts it. It may arrange the witness's window and no other.
launch() {
  local word arguments=()
  set -- "ARBOR_HOME=$ARBOR_HOME" "ARBOR_SOCKET=$ARBOR_SOCKET" ARBOR_NO_WATCHDOG=1 ARBOR_DEBUG=1 "ARBOR_ONLY_PIDS=$KEYS_PID" "$@"
  for word in "$@"; do arguments+=(--env "$word"); done
  if [ -n "${ARBOR_REHEARSAL:-}" ]; then
    # The fake Mac has no Launch Services, and no privacy database either: this rehearses the script's own lines and no more.
    env "$@" "$ARBOR_APP/Contents/MacOS/Arbor" > /dev/null 2>&1 &
    echo $! > "$ARBOR_HOME/arbor.lock"
  else
    open -n "${arguments[@]}" "$ARBOR_APP"
  fi
  patiently answers || die "Arbor did not answer on its socket"
  ARBOR_PID=$(holder)
  started "$ARBOR_PID"
  echo "Arbor pid $ARBOR_PID: $(status_line)"
}
leave() {
  [ -n "$ARBOR_PID" ] || return 0
  "$ARBOR_BIN/arborctl" quit > /dev/null 2>&1
  arbor_await_exit "$ARBOR_PID" 50 || kill -KILL "$ARBOR_PID" 2>/dev/null
  ARBOR_PID=""
}

# The witness has the keyboard. A click that falls while Arbor is still moving its window (a pause, a resume) lands on the wallpaper, and the key would then
# go to the Finder and prove nothing (2026-10-15). So: as often as it takes, and a round in which it never comes forward says so.
come_forward() {
  local tries=0
  until front_is "$KEYS_ID"; do
    tries=$((tries + 1))
    [ "$tries" -gt 5 ] && { echo "  (THE WITNESS IS NOT IN FRONT: $("$KEYS" frontmost): this round proves nothing)"; return 1; }
    kill -USR1 "$KEYS_PID" 2>/dev/null
    sleep 0.5
    click "$KEYS_X" "$KEYS_Y"
    sleep 0.5
  done
}

RESULTS="$ARBOR_OUT/results.txt"
: > "$RESULTS"
# press "<state>" [chord] [key code]: the witness in front, the chord pressed once. One line of the table, and REACHED is set to how many
# key-downs the app was given.
REACHED=0
ACTED=0
press() {
  local state=$1 chord=${2:-ctrl+opt+z} code=${3:-$Z} downs ups lines acted roads claimed line
  come_forward
  downs=$(given down "$code")
  ups=$(given up "$code")
  roads=$(count "road .*\(down\|pressed\|ran\)" "$KEYS_LOG")
  claimed=$(count " pressed" "$ARBOR_OUT/claim.log")
  lines=$(arbor_log_lines)
  key "$chord"
  sleep 0.8
  REACHED=$(($(given down "$code") - downs))
  ups=$(($(given up "$code") - ups))
  roads=$(($(count "road .*\(down\|pressed\|ran\)" "$KEYS_LOG") - roads))
  claimed=$(($(count " pressed" "$ARBOR_OUT/claim.log") - claimed))
  acted=$(arbor_log_since "$lines" | grep -c "shortcut\|show-all\|undo\|said on")
  ACTED=$acted
  line="RESULT | $state | status: $([ -n "$ARBOR_PID" ] && status_line || echo "no Arbor") | item in the menu bar: $(item_shows && echo yes || echo no)"
  line="$line | the app got: $REACHED down, $ups up | by other roads: $roads | another claimant: $claimed | lines in Arbor's log: $acted"
  echo "$line" | tee -a "$RESULTS"
}
reached() { [ "$REACHED" -gt 0 ]; }
taken() { [ "$REACHED" -eq 0 ]; }
# Arbor's log has grown by the command, or by what it said about it.
answered() { [ "$ACTED" -gt 0 ]; }
# The last line Arbor put on screen, as its log has it.
said() { grep "said on " "$ARBOR_HOME/arbor.log" | tail -n 1 | grep -qF "$1"; }
NEEDS="Arbor needs the Accessibility permission · Check Setup… in its menu"

arbor_build
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/keys.swift" -o "$KEYS" > "$ARBOR_OUT/build-keys.log" 2>&1 || {
  cat "$ARBOR_OUT/build-keys.log"
  die "scripts/mac-shell/keys.swift did not compile"
}
swiftc -O -swift-version 5 - -o "$ANNOUNCE" > "$ARBOR_OUT/build-announce.log" 2>&1 <<'SWIFT' || die "the three lines that announce a change did not compile"
import Foundation
DistributedNotificationCenter.default().postNotificationName(
  Notification.Name("com.apple.accessibility.api"), object: nil, userInfo: nil, deliverImmediately: true)
SWIFT
tcc "SELECT count(*) FROM access;" > /dev/null 2>&1 || die "the privacy database cannot be read here"
sw_vers -productVersion

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
at_exit 'leave; kill_started $KEYS_PID $CLAIM_PID; forget > /dev/null 2>&1; rm -rf "$KEYS_APP"'

step "0. the control: no Arbor at all"
witness
press "no Arbor"
check "with nobody to take it, the key reaches the app: the witness works" reached

step "1. waiting for the permission: a first launch"
forget
launch ARBOR_NO_PROMPT=0
check "Arbor waits for the permission" patiently status_starts "waiting for Accessibility permission"
sleep 1
shot 10-waiting
check "its item is in the menu bar" item_shows
keys_first() {
  awk '/registered [0-9]+ shortcuts/ && !keys { keys = NR } /the menu bar item is up/ && !item { item = NR } END { exit !(keys && item && keys < item) }' \
    "$ARBOR_HOME/arbor.log"
}
check "the keys were registered before the item was made" keys_first
press "waiting for the permission (first launch)"
check "the key is taken all the same" taken
check "and the line says why" said "$NEEDS"
shot 10-waiting-the-line
"$ARBOR_BIN/arborctl" bindings 2>&1 | tail -n 1
"$ARBOR_BIN/arborctl" doctor 2>&1 | grep -i "shortcut\|permission\|accessib" | head -n 6
open_menu && sleep 0.6 && shot 11-waiting-its-menu
key escape
press "waiting for the permission, a second time"
check "a second time too" taken

step "1b. the permission arrives: the control for 1"
grant
check "Arbor starts by itself" patiently status_starts "running"
grep "registered [0-9]* shortcuts" "$ARBOR_HOME/arbor.log" | tail -n 1
press "running, permission granted while it waited"
check "the key is Arbor's" taken
check "and Arbor answers it" answered
shot 12-running

step "2. with no event tap, as shipped: every default shortcut in turn"
echo "event taps: $("$KEYS" taps "$ARBOR_PID")"
"$ARBOR_BIN/arborctl" get pointerGestures 2>&1 | head -n 1
leaked=""
while read -r chord command; do
  case "$command" in
    # Its window takes the keyboard and has no key that closes it.
    settings-window | "") continue ;;
  esac
  before=$(count "^[0-9:.]* down code=.* mods=.*ctrl" "$KEYS_LOG")
  come_forward > /dev/null
  key "$chord"
  sleep 0.35
  after=$(count "^[0-9:.]* down code=.* mods=.*ctrl" "$KEYS_LOG")
  [ "$after" = "$before" ] || leaked="$leaked $chord($command)"
  case "$command" in
    # A panel that has the keyboard now, or lies over who has it.
    ask-name | find | minimap | show-shortcuts) key escape; sleep 0.3 ;;
    toggle-pause) "$ARBOR_BIN/arborctl" resume > /dev/null 2>&1 ;;
  esac
  pressed=$((${pressed:-0} + 1))
done << LIST
$("$ARBOR_BIN/arborctl" bindings 2>/dev/null | sed -n 's/^\([a-z0-9+]*[^ ]*\) .*→ \(.*\)$/\1 \2/p')
LIST
echo "RESULT | all defaults, no tap | pressed: ${pressed:-0} | reached the app:${leaked:- none}" | tee -a "$RESULTS"
check "none of them reaches the app" test -z "$leaked"
"$ARBOR_BIN/arborctl" float-all > /dev/null 2>&1
"$ARBOR_BIN/arborctl" show-all > /dev/null 2>&1

step "2b. the key held down: its repeats and its release"
come_forward
before=$(count "code=$Z " "$KEYS_LOG")
key ctrl+opt+z --down
key ctrl+opt+z --repeat 12
key ctrl+opt+z --up
sleep 0.5
echo "RESULT | held with 12 repeats | the app got: $(($(count "code=$Z " "$KEYS_LOG") - before)) events" | tee -a "$RESULTS"
check "neither a repeat nor the release reaches the app" test "$(count "code=$Z " "$KEYS_LOG")" = "$before"

step "5. what the person said themselves, and what changes nothing"
come_forward
key ctrl+opt+escape
check "a pause says whose the keys are now" eventually said "Arbor is paused: its keys are the apps’ again"
shot 50-paused
press "paused"
check "in a pause the key is the app's: the person said so" reached
"$ARBOR_BIN/arborctl" bindings 2>&1 | tail -n 1
ctl resume
press "resumed: the control"
check "the key is Arbor's again" taken
ctl hold
press "the view is held"
check "a held view keeps the key" taken
ctl release
ctl hold still
press "holding still"
check "holding still keeps the key" taken
ctl release
ctl pass-through "$KEYS_ID" on
press "the app is on passThroughApps"
check "in an app on the list the key is the app's: the person said so" reached
ctl pass-through "$KEYS_ID" off
ctl set hotkeysEnabled false
press "hotkeysEnabled false"
check "with shortcuts off the key is the app's: the person said so" reached
ctl set hotkeysEnabled true
press "all of it undone: the control"
check "the key is Arbor's again" taken

step "6. while the hot keys are registered anew"
# Another binding each time, so that every change registers all of them again.
( for n in $(seq 1 40); do
    "$ARBOR_BIN/arborctl" bind ctrl+opt+shift+cmd+f$((n % 2 + 13)) show-all > /dev/null 2>&1
    "$ARBOR_BIN/arborctl" unbind ctrl+opt+shift+cmd+f$((n % 2 + 13)) > /dev/null 2>&1
  done ) &
storm=$!
come_forward
before=$(count "down code=$Z " "$KEYS_LOG")
registrations=$(grep -c "registered [0-9]* shortcuts" "$ARBOR_HOME/arbor.log")
for _ in $(seq 1 60); do "$ARBOR_POINTER" key ctrl+opt+z; done
kill "$storm" 2>/dev/null
sleep 0.5
registrations=$(($(grep -c "registered [0-9]* shortcuts" "$ARBOR_HOME/arbor.log") - registrations))
echo "RESULT | 60 presses during $registrations registrations | the app got: $(($(count "down code=$Z " "$KEYS_LOG") - before))" | tee -a "$RESULTS"
# No check: all the hot keys are let go of and taken again for a millisecond or two at each registration, and whether a press falls in is luck.
grep "registered [0-9]* shortcuts" "$ARBOR_HOME/arbor.log" | sed 's/.*registered/registered/' | sort | uniq -c | sort -rn | head -n 5

step "4. the key is Arbor's, and the app has roads of its own"
# The witness's roads are made for ⌃⌥A.
ctl bind ctrl+opt+a show-all
leave
witness menu,monitor,tap
launch ARBOR_NO_PROMPT=1
patiently status_starts "running" > /dev/null
press "running; the app has a menu item, a global monitor and a listening tap" ctrl+opt+a "$A"
grep "road " "$KEYS_LOG" | sed 's/^/  /'
leave
press "no Arbor; the same app: the control" ctrl+opt+a "$A"
grep "road " "$KEYS_LOG" | tail -n 4 | sed 's/^/  /'
witness hotkey
launch ARBOR_NO_PROMPT=1
patiently status_starts "running" > /dev/null
grep "already in use\|registered [0-9]* shortcuts" "$ARBOR_HOME/arbor.log" | tail -n 2
press "running; the app in front registered ⌃⌥A itself BEFORE Arbor did" ctrl+opt+a "$A"
grep "road " "$KEYS_LOG" | sed 's/^/  /'
witness hotkey
press "running; the app in front registered ⌃⌥A itself AFTER Arbor did" ctrl+opt+a "$A"
grep "road " "$KEYS_LOG" | sed 's/^/  /'
witness secure
press "running; secure input is on" ctrl+opt+a "$A"
witness

step "3. another program holds the same chord"
for how in "" exclusive; do
  "$KEYS" claim "$ARBOR_OUT/claim.log" 60 $how &
  CLAIM_PID=$!
  started "$CLAIM_PID"
  sleep 1
  cat "$ARBOR_OUT/claim.log"
  press "another program claimed ⌃⌥A AFTER Arbor ${how:-(plain)}" ctrl+opt+a "$A"
  leave
  launch ARBOR_NO_PROMPT=1
  patiently status_starts "running" > /dev/null
  grep "already in use\|registered [0-9]* shortcuts" "$ARBOR_HOME/arbor.log" | tail -n 2
  "$ARBOR_BIN/arborctl" doctor 2>&1 | grep -i "shortcut" | head -n 4
  press "another program claimed ⌃⌥A BEFORE Arbor ${how:-(plain)}" ctrl+opt+a "$A"
  kill_started "$CLAIM_PID"
  CLAIM_PID=""
  rm -f "$ARBOR_OUT/claim.log"
  press "that program has gone: the control" ctrl+opt+a "$A"
done

step "1c. the permission is taken away while Arbor runs"
withdraw
check "Arbor notices" patiently status_starts "Arbor's Accessibility permission was taken away"
sleep 1
shot 13-taken-away
check "its item is in the menu bar" item_shows
press "the permission was taken away"
check "the key is taken all the same" taken
check "and the line says why" said "$NEEDS"
"$ARBOR_BIN/arborctl" bindings 2>&1 | tail -n 1
grant
check "Arbor starts again" patiently status_starts "running"
press "the permission is back: the control"
check "the key is Arbor's again" taken
check "and Arbor answers it" answered
leave

step "1d. a new build over an old grant: the switch in System Settings stays on"
requirement=$(codesign -d -r- "$ARBOR_APP" 2>&1 | sed -n 's/^.*designated => //p')
echo "this build's requirement begins: $(echo "$requirement" | cut -c 1-24)"
echo "$requirement" | csreq -r- -b "$ARBOR_OUT/requirement.bin" || die "csreq could not read the requirement"
grant "$(xxd -p "$ARBOR_OUT/requirement.bin" | tr -d '\n')"
rm -f "$ARBOR_OUT/requirement.bin"
launch ARBOR_NO_PROMPT=1
check "the build the grant was made for runs: the control" patiently status_starts "running"
press "the build the grant was made for"
check "its key is its own" taken
leave
/usr/libexec/PlistBuddy -c "Add :ArborProbe string another-build" "$ARBOR_APP/Contents/Info.plist"
arbor_sign Arbor
launch ARBOR_NO_PROMPT=0
sleep 3
echo "the entry still says: $(tcc "SELECT auth_value FROM access WHERE service = 'kTCCServiceAccessibility' AND client = '$ARBOR_ID';") (2 is allowed)"
shot 14-another-build
check "the new build waits for a permission it seems to have" status_starts "waiting for Accessibility permission"
check "its item is in the menu bar" item_shows
press "another ad-hoc build, the old grant still switched on"
check "the key is taken all the same" taken
check "and the line says why" said "$NEEDS"
leave

step "the table"
cat "$RESULTS"
arbor_log
