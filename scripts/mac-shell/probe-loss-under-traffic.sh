#!/bin/bash
# Arbor loses the Accessibility permission while EVERY one of its event taps is switched on and has traffic. Does input survive?
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-loss-under-traffic.sh      (about four minutes)
#
# probe-permission-loss.sh puts clicks through the tap on mouse-downs, which is always on. The others are on only at times:
#   round a  the scroll tap, while ⌃⌥ is down. A notch of the wheel and the key F19 every 50 ms; ⌃⌥ go down a second before the loss. Until the
#            taps go Arbor swallows the notches, by design; from then on every one must arrive. THE NUMBER: from the loss to the first
#            notch that arrives. ⌃⌥ come up at the end, and a key must then arrive without modifiers.
#   round b  the gesture tap. A whole small pinch without ⌥ over a test window every 50 ms: it is the app's, so all of it must arrive, throughout.
#   round c  the tap on drags and mouse-ups, in the middle of a ⌃⌥-drag: the button down, the band showing. Afterwards the button's release arrives
#            somewhere, nothing of Arbor's is left on the screen, and the next plain click, drag and key arrive whole.
# Each round by the roads of `take`, twice (README-permission-probes.md says how to read it). As in the other probe Arbor is a bundle under an identifier of its own, opened by Launch Services; only its
# entry is taken, and this script's tools keep theirs. The settings are as they ship.
#
# The bars: no hole longer than a second between the loss and the taps' going, none over 150 ms (three beats of the stream) after it, nothing more than
# 10 ms late after it, nothing lost after it, nothing stuck. A round that could not post, saw nothing arrive before the loss, or did not have
# the tap in question switched on at the loss proves nothing: it says INVALID and fails. arrivals-<round>.txt and stream-<round>.txt are the raw lists.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "write to the permission database with sudo, restart tccd and reset a bundle's Accessibility permission"

BUNDLE_ID=com.evbarleyg.arbor.probe-loss-under-traffic
TCC="/Library/Application Support/com.apple.TCC/TCC.db"
ASKER="$ARBOR_ROOT/.build/mac-shell/asker"
WITNESS="$ARBOR_ROOT/.build/mac-shell/witness"

tcc() { sudo sqlite3 "$TCC" "$1"; }
status_starts() { case "$("$ARBOR_BIN/arborctl" status 2>&1)" in "$1"*) return 0 ;; *) return 1 ;; esac; }
arbor_taps() { "$WITNESS" taps | grep "pid=$ARBOR_PID "; }
# tap_is <mask> <true|false>: 0x2 is mouse-downs, 0x44 drags and mouse-ups, 0x400000 scrolls, 0x20000000 gestures.
tap_is() { arbor_taps | grep -q "mask=$1 enabled=$2"; }
has_taps() { [ "$(arbor_taps | wc -l)" -eq 4 ]; }
no_taps() { [ "$(arbor_taps | wc -l)" -eq 0 ]; }
nothing_of_arbors() { [ -z "$(overlays | awk '$8 == "on"')" ]; }
gone() { ! kill -0 "$1" 2>/dev/null; }
invalid() { echo "INVALID: $1"; check "round $round is valid: $1" false; }

arbor_build
for tool in asker witness; do
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/$tool.swift" -o "$ARBOR_ROOT/.build/mac-shell/$tool" \
    > "$ARBOR_OUT/build-$tool.log" 2>&1 || { cat "$ARBOR_OUT/build-$tool.log"; die "scripts/mac-shell/$tool.swift did not compile"; }
done
tcc "SELECT count(*) FROM access;" > /dev/null 2>&1 || die "the permission database cannot be read here"
[ "$(pointer ax-access)" = true ] || die "INVALID: this script's own tools have no Accessibility permission, so nothing can be posted"

step "the bundle"
# The test windows come with a session; its Arbor, a child of this shell that shares the shell's permission, makes way for the bundle.
arbor_start 2
"$ARBOR_BIN/arborctl" quit > /dev/null
ended "$ARBOR_PID" || die "the session's own Arbor did not quit"
ARBOR_PID=""
# Not in the session's folder: tccutil finds a bundle by its identifier in Launch Services' list, and of one under /tmp it says "No such bundle identifier",
# as the user and as root, registered or not.
app="$HOME/Applications/ArborProbeLossUnderTraffic.app"
at_exit 'rm -rf "${app:?}"'
rm -rf "${app:?}"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$ARBOR_BIN/Arbor" "$app/Contents/MacOS/Arbor"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" -c "Delete :CFBundleURLTypes" "$app/Contents/Info.plist" \
  || die "could not edit Info.plist"
codesign --force --sign - --identifier "$BUNDLE_ID" "$app" || die "codesign failed"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app" || echo "lsregister could not register the bundle"
codesign --display --requirements - "$app" 2>/dev/null | sed -n 's/^\(# \)\{0,1\}designated => //p' > "$ARBOR_SESSION_DIR/requirement.txt"
csreq -r "$ARBOR_SESSION_DIR/requirement.txt" -b "$ARBOR_SESSION_DIR/requirement.bin" || die "csreq could not read the bundle's requirement"
REQUIREMENT="X'$(xxd -p "$ARBOR_SESSION_DIR/requirement.bin" | tr -d '\n')'"
at_exit "tcc \"DELETE FROM access WHERE client = '$BUNDLE_ID';\""

# judge.py <arrivals> <stream> <taken> <removed> <kinds that must arrive throughout> [<kind that is swallowed while ⌃⌥ is down and the taps are in>]
cat > "$ARBOR_SESSION_DIR/judge.py" <<'PYTHON'
import os, re, sys

def seconds(text):
    hours, minutes, rest = text.split(":")
    return int(hours) * 3600 + int(minutes) * 60 + float(rest)

arrivals, stream, taken, removed, always = sys.argv[1:6]
swallowed = sys.argv[6] if len(sys.argv) > 6 else ""
taken, removed, always = seconds(taken), seconds(removed), always.split(",")
text = open(stream).read()
posted = re.search(r"stream ends: (\d+) events posted", text)
posted = int(posted.group(1)) if posted else 0
found = []
for line in open(arrivals):
    match = re.match(r"(\S+) (\S+) n=(\d+) late_us=(-?\d+) mods=(\S+)", line)
    if match:
        found.append((seconds(match.group(1)), match.group(2), int(match.group(3)), int(match.group(4)), match.group(5)))
print(f"posted {posted}, arrived {len(found)}: " + ", ".join(f"{kind} {sum(1 for e in found if e[1] == kind)}" for kind in sorted({e[1] for e in found})))
print(f"the taps were gone {(removed - taken) * 1000:.0f} ms after the permission began to go")

steady = [e for e in found if e[1] in always]
between = os.environ.get("BETWEEN", "from the loss until the taps were gone")
stretches = [("before the loss", float("-inf"), taken), (between, taken, removed), ("after the taps were gone", removed, float("inf"))]
facts = {}
for name, start, end in stretches:
    part = [e for e in steady if start <= e[0] < end]
    holes = [later[0] - earlier[0] for earlier, later in zip(steady, steady[1:]) if start <= earlier[0] < end]
    hole, late = max(holes, default=0), max((e[3] for e in part), default=0)
    facts[name] = (len(part), round(hole * 1000), sum(1 for e in part if e[3] > 10000), round(late / 1000))
    print(f"{'+'.join(always)} {name}: {len(part)} arrived, LONGEST HOLE {hole * 1000:.0f} ms, worst lateness {late / 1000:.1f} ms, more than 10 ms late: {facts[name][2]}")

# The comparison, as the rule reads it: at the median, by kind of event.
def median(values):
    values = sorted(values)
    return values[len(values) // 2] / 1000 if values else 0
worse, told = 0, []
for kind in always:
    first, then = (median([e[3] for e in found if e[1] == kind and start <= e[0] < end]) for _, start, end in (stretches[0], stretches[2]))
    told.append(f"{kind} {first:.2f} / {then:.2f}")
    worse = max(worse, then - first)
print("median lateness in ms, before the loss / after the taps were gone: " + ", ".join(told))
# A beat posts three events in a fixed order, so which numbers are of the kinds that must always arrive is read off those that did.
places = {e[2] % 3 for e in steady}
gone = [number for number in range(1, posted + 1) if number % 3 in places and number not in {e[2] for e in found}]
print(f"{'+'.join(always)}: LOST {len(gone)} of {sum(1 for number in range(1, posted + 1) if number % 3 in places)} posted" + (f", n={gone[0]} to {gone[-1]}" if gone else ""))
def stamp(time):
    return f"{int(time // 3600):02d}:{int(time % 3600 // 60):02d}:{time % 60:06.3f}"
for earlier, later in zip(steady, steady[1:]):
    if later[0] - earlier[0] > 0.15:
        print(f"  a hole of {(later[0] - earlier[0]) * 1000:.0f} ms from {stamp(earlier[0])} (n={earlier[2]}) to {stamp(later[0])} (n={later[2]})")
# Every event has a number, and a beat posts its kinds in a fixed order, so which numbers are of which kind is read off what arrived.
numbers = {e[2] for e in found}
lost_after, first_after, met = 0, -1, 0
if swallowed:
    down = re.search(r"(\S+) ctrl\+opt down after n=(\d+)", text)
    up = re.search(r"(\S+) ctrl\+opt up after n=(\d+)", text)
    if down and up:
        held_from, held_to = int(down.group(2)), int(up.group(2))
        theirs = [e for e in found if e[1] == swallowed]
        plain_before = sum(1 for e in theirs if e[2] <= held_from)
        met = sum(1 for e in theirs if held_from < e[2] and e[0] < taken)
        later = [e for e in theirs if e[0] >= taken]
        print(f"{swallowed}: {plain_before} arrived before ⌃⌥ went down ({down.group(1)}); {met} arrived with ⌃⌥ down and the permission there (0 = Arbor swallowed them all)")
        if later:
            first_after = round((later[0][0] - taken) * 1000)
            stride = 3  # key-down, key-up, wheel
            expected = list(range(later[0][2], posted + 1, stride))
            lost_after = sum(1 for number in expected if number not in numbers)
            holes = [b[0] - a[0] for a, b in zip(later, later[1:])]
            print(f"{swallowed}: THE FIRST TO ARRIVE AFTER THE LOSS came {first_after} ms after it (n={later[0][2]}, mods={later[0][4]}); "
                  f"of the {len(expected)} from there on {lost_after} were lost; longest hole among them {max(holes, default=0) * 1000:.0f} ms")
        last = [e for e in found if e[2] > held_to and e[1] == "key-down"]
        print(f"key-downs after ⌃⌥ came up ({up.group(1)}): {len(last)}, their modifiers: {sorted({e[4] for e in last})}")
        facts["clean"] = int(bool(last) and all(e[4] == "none" for e in last))
        facts["plain"] = plain_before
else:
    lost_after = sum(1 for number in range(1, posted + 1) if number not in numbers)
    print(f"lost altogether: {lost_after}")
print("facts", posted, facts["before the loss"][0], facts["after the taps were gone"][0], facts[between][1],
      facts["after the taps were gone"][1], facts["after the taps were gone"][2], lost_after, first_after, met, facts.get("clean", -1), facts.get("plain", -1),
      facts["before the loss"][1], facts["before the loss"][3], facts["after the taps were gone"][3], len(gone), round(worse))
PYTHON

grant() {
  tcc "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, indirect_object_identifier, flags, last_modified) VALUES ('kTCCServiceAccessibility', '$BUNDLE_ID', 0, 2, 3, 1, $REQUIREMENT, 'UNUSED', 0, strftime('%s', 'now'));" \
    || die "INVALID: the grant could not be written"
  sudo killall -9 tccd 2>/dev/null
  # Not one second: whoever posts events has been blocked for two seconds four and a half seconds after such a kill. That must be over before the stream begins.
  sleep 6
}
leave() {
  "$ARBOR_POINTER" calm
  "$ARBOR_BIN/arborctl" quit > /dev/null 2>&1
  eventually gone "$ARBOR_PID" || kill_started "$ARBOR_PID"
  ARBOR_PID=""
}
# Granted, opened, running, with its four taps; [1 | Desktop | 2]; the settings and the taps for the record; the listener listening. 1 if not.
begin() {
  round=$1
  step "round $round, by the road \"$ROAD\": $2"
  grant
  limit 20 open -n "$app" --env ARBOR_HOME="$ARBOR_HOME" --env ARBOR_SOCKET="$ARBOR_SOCKET" --env ARBOR_DEBUG=1 \
    --env ARBOR_ONLY_PIDS="$ARBOR_WINDOWS_PID" --env ARBOR_NO_WATCHDOG=1 --env ARBOR_NO_PICTURES=1 --env ARBOR_NO_PROMPT=1 \
    --env ARBOR_NO_STATUS_ITEM=1
  sleep 2
  ARBOR_PID=$(pgrep -f "$app/Contents/MacOS/Arbor" | head -n 1)
  [ -n "$ARBOR_PID" ] || die "INVALID: the bundle did not start"
  started "$ARBOR_PID"
  eventually status_starts running || { "$ARBOR_BIN/arborctl" status; invalid "Arbor has the permission at launch"; leave; return 1; }
  eventually has_taps || { arbor_taps; invalid "Arbor has its four event taps"; leave; return 1; }
  for name in gesturesEnabled scrollZoom frameRectangleModifier frameRectangleOnDesktop guardDesktopClicks continuousZoom; do
    printf '%s ' "$("$ARBOR_BIN/arborctl" get "$name" 2>&1 | head -n 1)"
  done
  echo
  arbor_taps
  "$ARBOR_BIN/arborctl" dock "$W1" left > /dev/null
  "$ARBOR_BIN/arborctl" dock "$W2" right > /dev/null
  sleep 0.5
  read -r X Y <<< "$(center_of "$W2")"
  move "$X" "$Y"
  LOG_MARK=$(wc -l < "$ARBOR_HOME/arbor.log")
  # Appending, as `mark` does: two writers of whom only one appends write over each other.
  : > "$ARBOR_OUT/arrivals-$round.txt"
  "$ASKER" arrivals "${3:-$(($(length) + 5))}" >> "$ARBOR_OUT/arrivals-$round.txt" 2>&1 &
  started $!
  eventually grep -q arrivals-ready "$ARBOR_OUT/arrivals-$round.txt" || { invalid "the listener at the end of the taps started"; leave; return 1; }
}
# The road the permission goes by. tccutil: `tccutil reset Accessibility <identifier>`, felt at once. word: the entry deleted and the notification
# com.apple.accessibility.api posted, at which running processes ask again (probe-permission-grant.sh). row: the entry deleted and tccd killed, nothing said, which a
# running process feels 4 to 16 s later or not within half a minute: until then Arbor keeps its taps and is told yes. announced: the same, and the notification.
# Killing tccd is no person's deed, and blocks whoever posts events for seconds, with nobody else running: a hole in which no number is missing.
ROAD=tccutil
take() {
  TAKEN=$("$ASKER" now)
  case "$ROAD" in
    tccutil) tccutil reset Accessibility "$BUNDLE_ID" || sudo tccutil reset Accessibility "$BUNDLE_ID" ;;
    word)
      tcc "DELETE FROM access WHERE service = 'kTCCServiceAccessibility' AND client = '$BUNDLE_ID';"
      "$ASKER" announce ;;
    row | announced)
      tcc "DELETE FROM access WHERE service = 'kTCCServiceAccessibility' AND client = '$BUNDLE_ID';"
      sudo killall -9 tccd 2>/dev/null
      [ "$ROAD" = row ] || "$ASKER" announce ;;
  esac
  echo "the permission was taken by the road \"$ROAD\" between $TAKEN and $("$ASKER" now)"
}
# How long a stream lasts, and what the stretch between the deed and the taps' going is called.
length() { [ "$ROAD" = row ] && echo 34 || echo 12; }
between() { [ "$ROAD" = row ] && echo "FROM THE ROW'S DELETION UNTIL ARBOR NOTICED" || echo "from the loss until the taps were gone"; }
# What Arbor's log says of it, and when the taps went.
afterwards() {
  tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | grep -E "ermission|event tap|stopped|ERROR" | grep -v "DEBUG said" | cut -c 12-220 | tail -n 8
  # Not before the deed: an Arbor that takes its taps out when macOS is slow to answer (a doubt) writes the same line.
  # From the line of whoever takes the taps out; the controller's, which after the cure comes up to 3 s later or never, only where there is no other.
  REMOVED=$(tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | awk -v taken="$TAKEN" 'substr($0, 12, 12) >= taken && /permission is gone/ { print substr($0, 12, 12); exit }')
  if [ -z "$REMOVED" ]; then
    REMOVED=$(tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | awk -v taken="$TAKEN" 'substr($0, 12, 12) >= taken && /permission was taken away/ { print substr($0, 12, 12); exit }')
    [ -z "$REMOVED" ] || echo "(\"noticed\" is the controller's line: there is no line about the taps' going)"
  fi
  echo "false alarms (\"permission is back after N ms (macOS has not said in time …\"): $(tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | grep -c "permission is back after .*macOS has not said")"
  echo "slow answers (\"macOS took N ms to say …\"), N: $(tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | sed -n 's/.*macOS took \([0-9.]*\) ms to say.*/\1/p' | tr '\n' ' ')"
  echo "doubts (\"macOS has not said …\"): $(tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | grep -c "macOS has not said"); \"permission is back\": $(tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | grep -c "permission is back"); of them before the deed: $(tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | awk -v taken="$TAKEN" 'substr($0, 12, 12) < taken && /macOS has not said/' | wc -l | tr -d ' ')"
  [ -n "$REMOVED" ] || { echo "FINDING: Arbor has not noticed by now. Its taps: $(arbor_taps | wc -l | tr -d ' '). Everything after the deed counts as \"after\" below."; REMOVED=$TAKEN; }
  echo "lines about a tap that macOS switched off: $(tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | grep -c -E "event tap was off|switched (it|them) back on|too slow|of user input|switched the .* event tap off")"
  [ "$REMOVED" = "$TAKEN" ] || check "round $round: Arbor has no event tap left" eventually no_taps
  "$ARBOR_BIN/arborctl" status | head -n 1 | cut -c 1-120
  echo "the tools' own permission afterwards: $(pointer ax-access)"
}
# bars: what both streams are held to, from the line of facts.
bars() {
  grep -v "^facts " "$ARBOR_SESSION_DIR/verdict"
  read -r _ posted before after hole_during hole_after late_after lost first met clean plain hole_before worst_before worst_after gone median_worse \
    <<< "$(grep "^facts " "$ARBOR_SESSION_DIR/verdict")"
  [ "${posted:-0}" -ge 400 ] || invalid "the stream posted its events (${posted:-0})"
  [ "${before:-0}" -ge 80 ] || invalid "events arrived before the loss (${before:-0})"
  [ "${after:-0}" -ge 80 ] || invalid "events arrived after the taps were gone (${after:-0})"
  check "round $round: NOTHING LOST of what must always arrive (${gone:-?} were)" test "${gone:-1}" -eq 0
  check "round $round: no hole longer than a second while Arbor let go of its taps (${hole_during:-?} ms)" test "${hole_during:-9999}" -le 1000
  check "round $round: no hole after that (${hole_after:-?} ms; a beat is 50)" test "${hole_after:-9999}" -le 150
  check "round $round: nothing more than 10 ms late after that" test "${late_after:-1}" -eq 0
  check "round $round: nothing lost after that" test "${lost:-1}" -eq 0
  # A hosted Mac is never quite still: with nothing taken from anybody, events have been 85 ms late and 200 ms apart there. So, beside the bars:
  check "round $round: AT THE MEDIAN, by kind of event, no more than 10 ms later after that than before the loss (${median_worse:-?} ms at most)" test "${median_worse:-99}" -le 10
  check "round $round: (at the worst) no later after that (${worst_after:-?} ms) than this Mac was before the loss (${worst_before:-?} ms), or 10 ms" \
    test "${worst_after:-9999}" -le "$((${worst_before:-0} > 10 ? ${worst_before:-0} : 10))"
  check "round $round: no longer a hole after that (${hole_after:-?} ms) than before the loss (${hole_before:-?} ms), or 150 ms" \
    test "${hole_after:-9999}" -le "$((${hole_before:-0} > 150 ? ${hole_before:-0} : 150))"
}

round_a() {
  begin "$1" "the scroll tap: ⌃⌥ down from a second before the loss, a notch and a key every 50 ms" || return
  "$ASKER" stream "$(length)" 50 "$X" "$Y" --kinds key,wheel --ctrl-opt 3 "$(($(length) - 2))" > "$ARBOR_OUT/stream-$round.txt" 2>&1 &
  stream=$!
  started "$stream"
  sleep 3.6
  arbor_taps | grep "mask=0x400000"
  tap_is 0x400000 true || invalid "the scroll tap is switched on at the loss"
  take
  ended "$stream" "$(($(length) * 10 + 30))" || invalid "the stream came to its end"
  sleep 1
  cat "$ARBOR_OUT/stream-$round.txt"
  afterwards
  BETWEEN=$(between) python3 "$ARBOR_SESSION_DIR/judge.py" "$ARBOR_OUT/arrivals-$round.txt" "$ARBOR_OUT/stream-$round.txt" "$TAKEN" "$REMOVED" key-down,key-up wheel \
    > "$ARBOR_SESSION_DIR/verdict"
  bars
  [ "${plain:-0}" -ge 30 ] || invalid "plain notches arrived before ⌃⌥ went down (${plain:-0})"
  [ "${met:-1}" -eq 0 ] || invalid "Arbor swallowed the notches while it had the permission, so the tap had traffic (${met:-?} got through)"
  check "round $round: notches arrive again after the loss (the first after ${first:-?} ms)" test "${first:--1}" -ge 0
  [ "$ROAD" = row ] || check "round $round: and within the second" test "${first:-9999}" -ge 0 -a "${first:-9999}" -le 1000
  check "round $round: no modifier is stuck: keys after ⌃⌥ came up carry none" test "${clean:-0}" -eq 1
  check "round $round: nothing of Arbor's is left on the screen" eventually nothing_of_arbors
  shot "round-$round-afterwards"
  leave
}

round_b() {
  begin "$1" "the gesture tap: a small pinch without ⌥ over a test window every 50 ms" || return
  tap_is 0x20000000 true || invalid "the gesture tap is switched on"
  "$ASKER" stream "$(length)" 50 "$X" "$Y" --kinds pinch > "$ARBOR_OUT/stream-$round.txt" 2>&1 &
  stream=$!
  started "$stream"
  sleep 4
  tap_is 0x20000000 true || invalid "the gesture tap is switched on at the loss"
  take
  ended "$stream" "$(($(length) * 10 + 30))" || invalid "the stream came to its end"
  sleep 1
  cat "$ARBOR_OUT/stream-$round.txt"
  echo "pinches Arbor's tap saw begin: $(tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | grep -c "pinch began")"
  [ "$(tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | grep -c "pinch began")" -ge 20 ] || invalid "the gesture tap had traffic before the loss"
  afterwards
  BETWEEN=$(between) python3 "$ARBOR_SESSION_DIR/judge.py" "$ARBOR_OUT/arrivals-$round.txt" "$ARBOR_OUT/stream-$round.txt" "$TAKEN" "$REMOVED" gesture > "$ARBOR_SESSION_DIR/verdict"
  bars
  check "round $round: nothing of Arbor's is left on the screen" eventually nothing_of_arbors
  leave
}

count_since() { awk -v mark="## $1" '$0 == mark { on = 1; next } /^## / { on = 0 } on' "$ARBOR_OUT/arrivals-$round.txt" | grep -c -- "$2"; }
mark() { sleep 0.3; echo "## $1" >> "$ARBOR_OUT/arrivals-$round.txt"; }
round_c() {
  local x y w h
  begin "$1" "the drag tap: the loss in the middle of a ⌃⌥-drag, the button down and the band showing" 75 || return
  read -r x y w h <<< "$(frame_of "$W2")"
  mark "a plain click before"
  click "$X" "$Y"
  mark "the drag"
  [ "$(count_since "a plain click before" " down ")" -eq 1 ] || invalid "a plain click arrived before the loss"
  drag "$((x + 30))" "$((y + 60))" "$((x + w - 30))" "$((y + h - 40))" --mods ctrl+opt --no-release
  has_overlay 3 || invalid "the band shows at the loss"
  tap_is 0x44 true || invalid "the tap on drags and mouse-ups is switched on at the loss"
  arbor_taps
  [ "$(count_since "the drag" -E " (down|dragged|up) ")" -eq 0 ] || invalid "Arbor kept the ⌃⌥-drag from the apps while it had the permission"
  shot "round-$round-1-band"
  take
  sleep 2
  [ "$ROAD" != row ] || { for _ in 1 2 3 4 5 6 7 8 9 10; do no_taps && break; sleep 3; done; }
  afterwards
  shot "round-$round-2-after-the-loss"
  check "round $round: no band or panel of Arbor's is left on the screen, the button still down" eventually nothing_of_arbors
  mark "the release"
  release --mods ctrl+opt
  mark "a plain click afterwards"
  check "round $round: the button's release arrived" test "$(count_since "the release" " up ")" -eq 1
  click "$X" "$Y"
  mark "a plain drag afterwards"
  check "round $round: the next plain click arrives whole: one down" test "$(count_since "a plain click afterwards" " down .*mods=none")" -eq 1
  check "round $round: and one up" test "$(count_since "a plain click afterwards" " up .*mods=none")" -eq 1
  drag "$X" "$Y" "$((X + 40))" "$((Y + 40))" --steps 10
  mark "a plain key afterwards"
  check "round $round: the next plain drag arrives whole: one down" test "$(count_since "a plain drag afterwards" " down ")" -eq 1
  check "round $round: ten moves or more" test "$(count_since "a plain drag afterwards" " dragged ")" -ge 10
  check "round $round: one up" test "$(count_since "a plain drag afterwards" " up ")" -eq 1
  key f6
  mark "the end"
  check "round $round: no modifier is stuck: a key arrives without any" test "$(count_since "a plain key afterwards" "key-down .*mods=none")" -eq 1
  echo "worst lateness after the loss: $(awk '/^## the release/ { on = 1 } on' "$ARBOR_OUT/arrivals-$round.txt" | sed -n 's/.*late_us=\([0-9-]*\).*/\1/p' | sort -n | tail -n 1) µs"
  echo "the button, by the window server: $(pointer where)"
  shot "round-$round-3-afterwards"
  leave
}

# ROADS="tccutil word row announced" is all of them. Twice the two that kill no daemon, unless told otherwise.
turn=0
for ROAD in ${ROADS:-tccutil word tccutil word}; do
  turn=$((turn + 1))
  round_a "a-$ROAD-$turn"
  round_b "b-$ROAD-$turn"
  round_c "c-$ROAD-$turn"
done

step "the end"
arbor_log
arbor_close_windows
