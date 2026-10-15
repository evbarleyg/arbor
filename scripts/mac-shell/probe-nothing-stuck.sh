#!/bin/bash
# When Arbor loses the Accessibility permission with its taps in, macOS drops every event until the taps are gone. What is left stuck?
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-nothing-stuck.sh      (about eleven minutes; README-permission-probes.md says how to read it)
#
# What is known (README-permission-probes.md): after the right to tap is withdrawn events go on arriving until one comes that a switched-on tap has asked for, which for Arbor at rest is a press of
# the button; from that press on everything is dropped until the taps are out. So the button's own down is the first thing lost, and what can stick is whatever is DOWN AT THAT PRESS: a key, a modifier.
#
# The stream (asker.swift, `pairs`): the key F19, ⇧ and the button, each down for 400 ms of a cycle of 800; the key and ⇧ go down before the button and come up after it has gone down. At the deed the
# stream is told to wind up: one more press of the button, and its cycle to the end. Then one thing at a time, to see WHAT PUTS RIGHT what is stuck: three seconds of silence, a move of the pointer, a notch of the wheel, one press and
# release of the button, of the key, of ⇧, a second apart. The moment of the deed moves through the cycle from round to round.
#
# Who is asked: the listener at the far end of the taps (what got through); an app of the script's own under the pointer (`asker window`: what IT was given, whether a key repeats, whether it is given drags,
# where its window is: the button is pressed on its title bar); and, every 20 ms, the window server's own idea of what is down (CGEventSource's button, key and flags state) and AppKit's.
# THE MARK: NOTHING STAYS STUCK: after the hole the next press and release arrive whole, and the window server's and the app's idea of what is down is right again after that one act, for the button, a key
# and a modifier; no drag goes on with nobody holding; no key repeats. THE TABLE, per kind: what was believed after a lost up, for how long, and what put it right.
#
# By tccutil's road, which is felt at once and kills no daemon. The controls: nobody running; a bare tapper, which never lets go of its tap.
# What a hosted Mac cannot say: whether real keys and buttons are dropped as posted ones are, and whether a real key whose up is lost goes on repeating
# (the keyboard's repeat is made below where events are posted).
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/lib-gestures.sh"
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
# This is about the taps, so it asks for them, whatever Arbor ships with. The file stays in the session's home, which every Arbor of this run is given.
arbor_settings "{$ARBOR_GESTURES_ON}"
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

stream, arrivals, window, taken, noticed, label = sys.argv[1:7]
taken = seconds(taken)
posted = {}  # number -> (time, what)
for line in open(stream):
    match = re.match(r"(\S+) posted n=(\d+) (\S+)", line)
    if match:
        posted[int(match.group(2))] = (seconds(match.group(1)), match.group(3))
over = re.search(r"(\S+) the cycles are over", open(stream).read())
over = seconds(over.group(1)) if over else float("inf")
arrived = {int(match.group(2)): seconds(match.group(1)) for match in (re.match(r"(\S+) \S+ n=(\d+) ", line) for line in open(arrivals)) if match}
saw = {int(match.group(2)): seconds(match.group(1)) for match in (re.match(r"(\S+) saw \S+ n=(\d+) ", line) for line in open(window)) if match}
held = [(seconds(match.group(1)), dict(pair.split("=") for pair in match.group(2).split())) for match in (re.match(r"(\S+) held (.*)", line) for line in open(window)) if match]
lost = sorted(number for number in posted if number not in arrived)
print(f"posted {len(posted)}, arrived at the end of the taps {len(arrived)}, given to the app {len(saw)}, lost {len(lost)}"
      + (": " + ", ".join(f"n={number} {posted[number][1]}" for number in lost[:14]) + (" …" if len(lost) > 14 else "") if lost else ""))
if lost:
    print(f"the first that was lost was posted {(posted[lost[0]][0] - taken) * 1000:+.0f} ms from the beginning of the deed, the last {(posted[lost[-1]][0] - taken) * 1000:+.0f} ms"
          + (f"; Arbor's taps were out at {(seconds(noticed) - taken) * 1000:+.0f} ms" if noticed != "-" else ""))

def cleared(name, since):
    """When the window server or AppKit next held it to be up."""
    return next((moment for moment, state in held if moment > since and state.get(name) in ("up", "off")), None)

def cause(moment, kind):
    """What arrived in the 70 ms before: that is what put it right."""
    near = [(time, number) for number, time in arrived.items() if moment - 0.07 <= time <= moment + 0.005]
    if not near:
        return "nothing: it came right by itself"
    what = posted[max(near)[1]][1]
    return f"{what}, " + ("of the same kind" if what in kinds[kind][:2] else "another kind of event")

def lasted(moment, since):
    return "to the end of the record" if moment is None else f"{(moment - since) * 1000:.0f} ms"

kinds = {"button": ("down", "up", ["button", "appkit-button"]), "key": ("key-down", "key-up", ["f19"]), "modifier": ("shift-down", "shift-up", ["shift-key", "shift-flag", "appkit-shift"])}
rows, orphans, widows, slow = [], 0, 0, 0
for kind, (down, up, names) in kinds.items():
    numbers = sorted(number for number, (_, what) in posted.items() if what in (down, up))
    for first, second in zip(numbers, numbers[1:]):
        if posted[first][1] != down or posted[second][1] != up:
            continue
        if first in arrived and second not in arrived:
            orphans += 1
            since = posted[second][0]
            print(f"  A LOST UP WHOSE DOWN ARRIVED: the {kind}, n={first} and n={second}, which was posted {(since - taken) * 1000:+.0f} ms from the deed")
            for name in names:
                moment = cleared(name, since)
                print(f"    {name} was held to be down for {lasted(moment, since)} after that" + (f"; put right by: {cause(moment, kind)}" if moment else ""))
                rows.append(f"{label} {kind} {name} {lasted(moment, since).replace(' ', '-')} | {cause(moment, kind) if moment else 'NOTHING'}")
                # The one act: the first press and release of that kind after the silence.
                act = [number for number in numbers if posted[number][0] > over and posted[number][1] == up and number in arrived]
                if moment is None or (act and moment > arrived[act[0]] + 0.1):
                    slow += 1
            later = [time for number, time in saw.items() if posted[number][1] == up and time > since]
            print(f"    the app was given the down and no up; the next up of that kind it was given came {lasted(later[0] if later else None, since)} after")
        if first not in arrived and second in arrived:
            widows += 1
            print(f"  an up without its down: the {kind}, n={second}")
text = open(window).read()
repeats = len(re.findall(r"repeat=true", text))
drags = sum(1 for match in re.finditer(r"(\S+) saw dragged", text) if seconds(match.group(1)) > over)
places = [state.get("window") for moment, state in held if moment > over]
moved = len(set(places)) > 1
last = held[-1][1] if held else {}
stuck = sorted(name for name, value in last.items() if value in ("down", "on"))
print("held down at the end: " + (", ".join(stuck) if stuck else "nothing") + f"; key-downs with the repeat flag the app was given: {repeats}; drags it was given after the cycles, with nobody holding: {drags}; "
      + ("ITS WINDOW MOVED after the cycles: " + " ".join(dict.fromkeys(places)) if moved else "its window stayed where it was"))
final = sorted(number for number, (time, _) in posted.items() if time > over)
print(f"after the silence: {sum(1 for number in final if number in arrived)} of {len(final)} arrived (a move, a notch, three presses and releases)")
for row in rows:
    print("row " + row)
print("facts", len(posted), len(lost), orphans, widows, len(stuck), sum(1 for number in arrived if posted.get(number, (taken,))[0] < taken), repeats, drags, int(moved), slow,
      sum(1 for number in final if number not in arrived))
PYTHON

# The app under the pointer: in the lower right, clear of the test window.
WX=600 WY=380 WW=320 WH=220
# On its title bar: were the button held to be down with nobody holding, the window would follow the pointer.
PX=$((WX + WW / 2)) PY=$((WY + 14))

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
      limit 20 open -n "$tapper" --args tap 30 "$ARBOR_OUT/tapper-$round.txt"
      eventually grep -q tap-ready "$ARBOR_OUT/tapper-$round.txt" || { invalid "the bare tapper has its tap"; return; }
      pid=$(sed -n 's/.*tap-ready pid=\([0-9]*\).*/\1/p' "$ARBOR_OUT/tapper-$round.txt")
      started "$pid" ;;
  esac
  [ -z "$pid" ] || echo "$who is pid $pid with $(taps_of "$pid") taps"
  mark=$(wc -l < "$ARBOR_HOME/arbor.log")

  : > "$ARBOR_OUT/window-$round.txt"
  "$ASKER" window 24 "$ARBOR_OUT/window-$round.txt" $WX $WY $WW $WH > /dev/null 2>&1 &
  started $!
  eventually grep -q window-ready "$ARBOR_OUT/window-$round.txt" || { invalid "the app under the pointer opened its window"; return; }
  : > "$ARBOR_OUT/arrivals-$round.txt"
  "$ASKER" arrivals 22 >> "$ARBOR_OUT/arrivals-$round.txt" 2>&1 &
  started $!
  eventually grep -q arrivals-ready "$ARBOR_OUT/arrivals-$round.txt" || { invalid "the listener at the end of the taps started"; return; }
  pointer move "$PX" "$PY"
  "$ASKER" pairs 6 "$PX" "$PY" > "$ARBOR_OUT/stream-$round.txt" 2>&1 &
  stream=$!
  started "$stream"
  # Through the cycle of 800 ms in steps of 70 ms, from round to round.
  tenths=$((round * 7 % 80))
  sleep "2.$(printf '%02d' "$tenths")"
  kill -USR1 "$stream"
  taken=$("$ASKER" now)
  tccutil reset Accessibility "$id"
  ended "$stream" 200 || invalid "the stream came to its end"
  sleep 0.5
  if [ "$who" = arbor ]; then
    # Not before the deed: an Arbor that takes its taps out when macOS is slow to answer (a doubt) writes the same line.
    noticed=$(tail -n "+$((mark + 1))" "$ARBOR_HOME/arbor.log" | awk -v taken="$taken" 'substr($0, 12, 12) >= taken && /permission is gone/ { print substr($0, 12, 12); exit }')
    [ -n "$noticed" ] \
      || noticed=$(tail -n "+$((mark + 1))" "$ARBOR_HOME/arbor.log" | awk -v taken="$taken" 'substr($0, 12, 12) >= taken && /permission was taken away/ { print substr($0, 12, 12); exit }')
    tail -n "+$((mark + 1))" "$ARBOR_HOME/arbor.log" | grep -E "permission is gone|permission was taken away|permission is back|macOS was asked" | cut -c 12-170 | head -n 5
    echo "doubts (\"macOS has not said …\"): $(tail -n "+$((mark + 1))" "$ARBOR_HOME/arbor.log" | grep -c "macOS has not said")"
    [ -n "$noticed" ] || { echo "FINDING: Arbor has not noticed by the end of the stream; its taps: $(taps_of "$pid")"; noticed=-; }
  fi
  [ "$who" != bare-tapper ] || grep -E "switched-off|question|the end" "$ARBOR_OUT/tapper-$round.txt"
  python3 "$ARBOR_SESSION_DIR/stuck.py" "$ARBOR_OUT/stream-$round.txt" "$ARBOR_OUT/arrivals-$round.txt" "$ARBOR_OUT/window-$round.txt" "$taken" "$noticed" "$round-$who" \
    > "$ARBOR_SESSION_DIR/verdict"
  grep -v -E "^(facts|row) " "$ARBOR_SESSION_DIR/verdict"
  grep "^row " "$ARBOR_SESSION_DIR/verdict" | cut -c 5- >> "$ARBOR_OUT/rows.txt"
  read -r _ posted lost orphans widows stuck before repeats drags moved slow unheard <<< "$(grep "^facts " "$ARBOR_SESSION_DIR/verdict")"
  echo "the button a second after the stream, by the window server: $(pointer where)"
  [ "${posted:-0}" -ge 25 ] || invalid "the stream posted its events (${posted:-0})"
  [ "${before:-0}" -ge 8 ] || invalid "events arrived before the deed (${before:-0})"
  check "round $round: NOTHING STAYS STUCK: whatever was held after a lost up is right again after one press and release of its kind at the latest (${slow:-?} were not)" test "${slow:-1}" -eq 0
  check "round $round: nothing is held down at the end" test "${stuck:-1}" -eq 0
  check "round $round: after the hole the move, the notch and the three presses and releases all arrive (${unheard:-?} did not)" test "${unheard:-1}" -eq 0
  check "round $round: no key repeats" test "${repeats:-1}" -eq 0
  check "round $round: no drag goes on with nobody holding" test "${drags:-1}" -eq 0 -a "${moved:-1}" -eq 0
  echo "$round $who lost=${lost:-?} lost-ups-whose-down-arrived=${orphans:-?} ups-without-down=${widows:-?} not-right-after-one-act=${slow:-?} held-at-the-end=${stuck:-?} repeats=${repeats:-?} drags=${drags:-?} window-moved=${moved:-?}" >> "$ARBOR_OUT/table.txt"
  if [ "$who" = arbor ]; then
    "$ARBOR_BIN/arborctl" quit > /dev/null 2>&1
    eventually gone "$ARBOR_PID" || kill_started "$ARBOR_PID"
    ARBOR_PID=""
  fi
  [ "$who" != bare-tapper ] || kill_started "$pid"
}

: > "$ARBOR_OUT/table.txt"
: > "$ARBOR_OUT/rows.txt"
number=0
for who in ${ROUNDS:-nobody bare-tapper arbor arbor arbor arbor arbor arbor bare-tapper arbor arbor arbor arbor arbor arbor nobody}; do
  number=$((number + 1))
  one_round "$number" "$who"
done

step "side by side"
cat "$ARBOR_OUT/table.txt"
echo
echo "THE TABLE: round and variant, kind, who believed it, for how long after the lost up | what put it right"
cat "$ARBOR_OUT/rows.txt"
arbor_log
arbor_close_windows
