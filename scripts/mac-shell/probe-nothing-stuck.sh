#!/bin/bash
# When Arbor loses the Accessibility permission with its taps in, macOS drops every event until the taps are gone. What is left stuck?
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-nothing-stuck.sh      (about nine minutes; README-permission-probes.md says how to read it)
#
# probe-permission-loss.sh posts each down with its up in the same beat, so both are lost or neither. Here the button, the key F19 and ⇧ are each down for 400 ms and
# up for 400 ms, a third of that apart (asker.swift, `pairs`), so that the withdrawal falls between a down and its up in most rounds. The moment of the deed moves through
# the cycle from round to round.
#
# Who is asked: the listener at the far end of the taps (what got through); an app of the script's own under the pointer (`asker window`: what IT was given, and
# whether a key repeats); and, every 20 ms, the window server's own idea of what is down (CGEventSource's button, key and flags state) and AppKit's.
# For each round: which events were lost; every down that arrived whose up did not (THE QUESTION), and for how long the window server then held it to be down;
# every up that arrived without its down; what is held down a second after the stream has let go of everything; whether the next plain click arrives whole.
#
# By tccutil's road, which is felt at once and kills no daemon. The controls: nobody running; a bare tapper, which never lets go of its tap (the floor).
# What a hosted Mac cannot say: whether real keys and buttons are dropped as posted ones are, and whether a real key whose up is lost goes on repeating
# (the keyboard's repeat is made below where events are posted).
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "write to the permission database with sudo, restart tccd and reset a bundle's Accessibility permission"

ARBOR_ID=com.evbarleyg.arbor.probe-nothing-stuck
TAPPER_ID=com.evbarleyg.arbor.probe-stuck-tapper
TCC="/Library/Application Support/com.apple.TCC/TCC.db"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
ASKER="$ARBOR_ROOT/.build/mac-shell/asker"
WITNESS="$ARBOR_ROOT/.build/mac-shell/witness"

tcc() { sudo sqlite3 "$TCC" "$1"; }
status_starts() { case "$("$ARBOR_BIN/arborctl" status 2>&1)" in "$1"*) return 0 ;; *) return 1 ;; esac; }
taps_of() { "$WITNESS" taps | grep -c "pid=$1 " || true; }
gone() { ! kill -0 "$1" 2>/dev/null; }
invalid() { echo "INVALID: $1"; check "round $round is valid: $1" false; }

arbor_build
for tool in asker witness; do
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/$tool.swift" -o "$ARBOR_ROOT/.build/mac-shell/$tool" \
    > "$ARBOR_OUT/build-$tool.log" 2>&1 || { cat "$ARBOR_OUT/build-$tool.log"; die "scripts/mac-shell/$tool.swift did not compile"; }
done
tcc "SELECT count(*) FROM access;" > /dev/null 2>&1 || die "the permission database cannot be read here"
[ "$(pointer ax-access)" = true ] || die "INVALID: this script's own tools have no Accessibility permission, so nothing can be posted"

# requirement_of <bundle>: its designated requirement as the database keeps it.
requirement_of() {
  codesign --display --requirements - "$1" 2>/dev/null | sed -n 's/^\(# \)\{0,1\}designated => //p' > "$ARBOR_SESSION_DIR/requirement.txt"
  csreq -r "$ARBOR_SESSION_DIR/requirement.txt" -b "$ARBOR_SESSION_DIR/requirement.bin" || die "csreq could not read the requirement of $1"
  echo "X'$(xxd -p "$ARBOR_SESSION_DIR/requirement.bin" | tr -d '\n')'"
}

step "the bundles"
# The test windows come with a session; its Arbor, a child of this shell that shares the shell's permission, makes way for the bundle.
arbor_start 1
"$ARBOR_BIN/arborctl" quit > /dev/null
ended "$ARBOR_PID" || die "the session's own Arbor did not quit"
ARBOR_PID=""
# Not under /tmp: tccutil would not find them.
app="$HOME/Applications/ArborProbeNothingStuck.app"
tapper="$HOME/Applications/ArborProbeStuckTapper.app"
at_exit 'rm -rf "${app:?}" "${tapper:?}"'
rm -rf "${app:?}" "${tapper:?}"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$tapper/Contents/MacOS"
cp "$ARBOR_BIN/Arbor" "$app/Contents/MacOS/Arbor"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $ARBOR_ID" -c "Delete :CFBundleURLTypes" "$app/Contents/Info.plist" || die "could not edit Info.plist"
cp "$ASKER" "$tapper/Contents/MacOS/asker"
cat > "$tapper/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$TAPPER_ID</string>
  <key>CFBundleExecutable</key><string>asker</string>
  <key>CFBundleName</key><string>ArborProbeStuckTapper</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - --identifier "$ARBOR_ID" "$app" || die "codesign failed"
codesign --force --sign - --identifier "$TAPPER_ID" "$tapper" || die "codesign failed"
"$LSREGISTER" -f "$app" "$tapper" || echo "lsregister could not register the bundles"
ARBOR_REQUIREMENT=$(requirement_of "$app")
TAPPER_REQUIREMENT=$(requirement_of "$tapper")
at_exit "tcc \"DELETE FROM access WHERE client IN ('$ARBOR_ID', '$TAPPER_ID');\""

cat > "$ARBOR_SESSION_DIR/stuck.py" <<'PYTHON'
import re, sys

def seconds(text):
    hours, minutes, rest = text.split(":")
    return int(hours) * 3600 + int(minutes) * 60 + float(rest)

stream, arrivals, window, taken, noticed = sys.argv[1:6]
taken = seconds(taken)
posted = {}  # number -> (time, what)
for line in open(stream):
    match = re.match(r"(\S+) posted n=(\d+) (\S+)", line)
    if match:
        posted[int(match.group(2))] = (seconds(match.group(1)), match.group(3))
arrived = {int(match.group(2)): seconds(match.group(1)) for match in (re.match(r"(\S+) \S+ n=(\d+) ", line) for line in open(arrivals)) if match}
saw = {int(match.group(2)): seconds(match.group(1)) for match in (re.match(r"(\S+) saw \S+ n=(\d+) ", line) for line in open(window)) if match}
repeats = sum(1 for line in open(window) if "repeat=true" in line)
held = [(seconds(match.group(1)), dict(pair.split("=") for pair in match.group(2).split())) for match in (re.match(r"(\S+) held (.*)", line) for line in open(window)) if match]
lost = sorted(number for number in posted if number not in arrived)
print(f"posted {len(posted)}, arrived at the end of the taps {len(arrived)}, given to the app {len(saw)}, lost {len(lost)}"
      + (": " + ", ".join(f"n={number} {posted[number][1]}" for number in lost) if lost else ""))
if lost:
    first, last = posted[lost[0]][0], posted[lost[-1]][0]
    print(f"the first that was lost was posted {(first - taken) * 1000:.0f} ms after the deed began, the last {(last - taken) * 1000:.0f} ms after it"
          + (f"; Arbor noticed {(seconds(noticed) - taken) * 1000:.0f} ms after it" if noticed != "-" else ""))
# A down is followed by its up three numbers later.
state_of = {"down": "button", "key-down": "f19", "shift-down": "shift-key"}
orphans, widows = [], []
for number, (time, what) in sorted(posted.items()):
    if what in state_of and number + 3 in posted:
        if number in arrived and number + 3 not in arrived:
            orphans.append(number)
            name = state_of[what]
            later = [moment for moment, state in held if moment > time and state.get(name) == "up"]
            print(f"  A DOWN WHOSE UP WAS LOST: n={number} {what} at {(time - taken) * 1000:+.0f} ms; the window server held {name} to be down for "
                  + (f"{(later[0] - time) * 1000:.0f} ms (400 is right)" if later else "EVER: it never came up again"))
        if number not in arrived and number + 3 in arrived:
            widows.append(number + 3)
            print(f"  an up without its down: n={number + 3} {posted[number + 3][1]}")
last = held[-1][1] if held else {}
stuck = sorted(name for name, value in last.items() if value in ("down", "on"))
print("held down at the end: " + (", ".join(stuck) if stuck else "nothing") + f"; key repeats the app was given: {repeats}")
print("facts", len(posted), len(lost), len(orphans), len(widows), len(stuck), sum(1 for number in arrived if posted.get(number, (taken,))[0] < taken), repeats)
PYTHON

# The app under the pointer: in the lower right, clear of the test window.
WX=600 WY=380 WW=320 WH=220
PX=$((WX + WW / 2)) PY=$((WY + WH / 2))

# one_round <number> <arbor|nobody|bare-tapper>
one_round() {
  local who=$2 id requirement pid="" mark taken noticed=- stream tenths
  round=$1
  step "round $round: with $who"
  id=$ARBOR_ID requirement=$ARBOR_REQUIREMENT
  [ "$who" = bare-tapper ] && id=$TAPPER_ID requirement=$TAPPER_REQUIREMENT
  tcc "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, indirect_object_identifier, flags, last_modified) VALUES ('kTCCServiceAccessibility', '$id', 0, 2, 3, 1, $requirement, 'UNUSED', 0, strftime('%s', 'now'));" \
    || die "INVALID: the grant could not be written"
  sudo killall -9 tccd 2>/dev/null
  sleep 6 # whoever posts events has been blocked for seconds after such a kill: that must be over before the stream begins
  case "$who" in
    arbor)
      limit 20 open -n "$app" --env ARBOR_HOME="$ARBOR_HOME" --env ARBOR_SOCKET="$ARBOR_SOCKET" --env ARBOR_DEBUG=1 --env ARBOR_ONLY_PIDS="$ARBOR_WINDOWS_PID" \
        --env ARBOR_NO_WATCHDOG=1 --env ARBOR_NO_PICTURES=1 --env ARBOR_NO_PROMPT=1 --env ARBOR_NO_STATUS_ITEM=1
      sleep 2
      ARBOR_PID=$(pgrep -f "$app/Contents/MacOS/Arbor" | head -n 1)
      [ -n "$ARBOR_PID" ] || die "INVALID: the bundle did not start"
      started "$ARBOR_PID"
      pid=$ARBOR_PID
      eventually status_starts running || { invalid "Arbor has the permission at launch"; kill_started "$ARBOR_PID"; ARBOR_PID=""; return; } ;;
    bare-tapper)
      : > "$ARBOR_OUT/tapper-$round.txt"
      limit 20 open -n "$tapper" --args tap 22 "$ARBOR_OUT/tapper-$round.txt"
      eventually grep -q tap-ready "$ARBOR_OUT/tapper-$round.txt" || { invalid "the bare tapper has its tap"; return; }
      pid=$(sed -n 's/.*tap-ready pid=//p' "$ARBOR_OUT/tapper-$round.txt")
      started "$pid" ;;
  esac
  [ -z "$pid" ] || echo "$who is pid $pid with $(taps_of "$pid") taps"
  mark=$(wc -l < "$ARBOR_HOME/arbor.log")

  : > "$ARBOR_OUT/window-$round.txt"
  "$ASKER" window 17 "$ARBOR_OUT/window-$round.txt" $WX $WY $WW $WH > /dev/null 2>&1 &
  started $!
  eventually grep -q window-ready "$ARBOR_OUT/window-$round.txt" || { invalid "the app under the pointer opened its window"; return; }
  : > "$ARBOR_OUT/arrivals-$round.txt"
  "$ASKER" arrivals 15 >> "$ARBOR_OUT/arrivals-$round.txt" 2>&1 &
  started $!
  eventually grep -q arrivals-ready "$ARBOR_OUT/arrivals-$round.txt" || { invalid "the listener at the end of the taps started"; return; }
  pointer move "$PX" "$PY"
  "$ASKER" pairs 8 "$PX" "$PY" > "$ARBOR_OUT/stream-$round.txt" 2>&1 &
  stream=$!
  started "$stream"
  # Through the cycle of 800 ms in steps of 70 ms, from round to round.
  tenths=$((round * 7 % 80))
  sleep "2.$(printf '%02d' "$tenths")"
  taken=$("$ASKER" now)
  tccutil reset Accessibility "$id"
  ended "$stream" 120 || invalid "the stream came to its end"
  sleep 1
  echo "## afterwards" >> "$ARBOR_OUT/arrivals-$round.txt"
  pointer click "$PX" "$PY"
  sleep 0.5
  if [ "$who" = arbor ]; then
    # Not before the deed: an Arbor that takes its taps out when macOS is slow to answer (a doubt) writes the same line.
    noticed=$(tail -n "+$((mark + 1))" "$ARBOR_HOME/arbor.log" \
      | awk -v taken="$taken" 'substr($0, 12, 12) >= taken && /permission is gone|permission was taken away/ { print substr($0, 12, 12); exit }')
    tail -n "+$((mark + 1))" "$ARBOR_HOME/arbor.log" | grep -E "permission is gone|permission was taken away|permission is back|macOS was asked" | cut -c 12-170 | head -n 5
    echo "doubts (\"macOS has not said for …\"): $(tail -n "+$((mark + 1))" "$ARBOR_HOME/arbor.log" | grep -c "macOS has not said for")"
    [ -n "$noticed" ] || { echo "FINDING: Arbor has not noticed by the end of the stream; its taps: $(taps_of "$pid")"; noticed=-; }
  fi
  [ "$who" != bare-tapper ] || grep -E "switched-off|question|the end" "$ARBOR_OUT/tapper-$round.txt"
  python3 "$ARBOR_SESSION_DIR/stuck.py" "$ARBOR_OUT/stream-$round.txt" "$ARBOR_OUT/arrivals-$round.txt" "$ARBOR_OUT/window-$round.txt" "$taken" "$noticed" \
    > "$ARBOR_SESSION_DIR/verdict"
  grep -v "^facts " "$ARBOR_SESSION_DIR/verdict"
  read -r _ posted lost orphans widows stuck before repeats <<< "$(grep "^facts " "$ARBOR_SESSION_DIR/verdict")"
  echo "the button a second after the stream, by the window server: $(pointer where)"
  echo "the next plain click, at the end of the taps: $(awk '/^## afterwards/ { on = 1; next } on' "$ARBOR_OUT/arrivals-$round.txt" | grep -c -E " (down|up) other") of 2"
  [ "${posted:-0}" -ge 50 ] || invalid "the stream posted its events (${posted:-0})"
  [ "${before:-0}" -ge 10 ] || invalid "events arrived before the deed (${before:-0})"
  check "round $round: NO UP WAS LOST WHOSE DOWN ARRIVED (${orphans:-?} were)" test "${orphans:-1}" -eq 0
  check "round $round: nothing is held down at the end" test "${stuck:-1}" -eq 0
  check "round $round: the next plain click arrives whole" \
    test "$(awk '/^## afterwards/ { on = 1; next } on' "$ARBOR_OUT/arrivals-$round.txt" | grep -c -E " (down|up) other")" -eq 2
  echo "$round $who lost=${lost:-?} downs-without-up=${orphans:-?} ups-without-down=${widows:-?} held-at-the-end=${stuck:-?} repeats=${repeats:-?}" >> "$ARBOR_OUT/table.txt"
  if [ "$who" = arbor ]; then
    "$ARBOR_BIN/arborctl" quit > /dev/null 2>&1
    eventually gone "$ARBOR_PID" || kill_started "$ARBOR_PID"
    ARBOR_PID=""
  fi
  [ "$who" != bare-tapper ] || kill_started "$pid"
}

: > "$ARBOR_OUT/table.txt"
number=0
for who in ${ROUNDS:-nobody bare-tapper arbor arbor arbor arbor arbor arbor bare-tapper arbor arbor arbor arbor arbor arbor nobody}; do
  number=$((number + 1))
  one_round "$number" "$who"
done

step "side by side"
cat "$ARBOR_OUT/table.txt"
arbor_log
arbor_close_windows
