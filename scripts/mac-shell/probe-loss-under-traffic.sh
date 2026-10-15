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
# Each round twice. As in the other probe Arbor is a bundle under an identifier of its own, opened by Launch Services; only its entry is taken
# (`tccutil reset Accessibility <identifier>`), and this script's tools keep theirs. The settings are as they ship.
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
app="$ARBOR_SESSION_DIR/Arbor.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$ARBOR_BIN/Arbor" "$app/Contents/MacOS/Arbor"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" -c "Delete :CFBundleURLTypes" "$app/Contents/Info.plist" \
  || die "could not edit Info.plist"
codesign --force --sign - --identifier "$BUNDLE_ID" "$app" || die "codesign failed"
codesign --display --requirements - "$app" 2>/dev/null | sed -n 's/^\(# \)\{0,1\}designated => //p' > "$ARBOR_SESSION_DIR/requirement.txt"
csreq -r "$ARBOR_SESSION_DIR/requirement.txt" -b "$ARBOR_SESSION_DIR/requirement.bin" || die "csreq could not read the bundle's requirement"
REQUIREMENT="X'$(xxd -p "$ARBOR_SESSION_DIR/requirement.bin" | tr -d '\n')'"
at_exit "tcc \"DELETE FROM access WHERE client = '$BUNDLE_ID';\""

# judge.py <arrivals> <stream> <taken> <removed> <kinds that must arrive throughout> [<kind that is swallowed while ⌃⌥ is down and the taps are in>]
cat > "$ARBOR_SESSION_DIR/judge.py" <<'PYTHON'
import re, sys

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
stretches = [("before the loss", float("-inf"), taken), ("from the loss until the taps were gone", taken, removed), ("after the taps were gone", removed, float("inf"))]
facts = {}
for name, start, end in stretches:
    part = [e for e in steady if start <= e[0] < end]
    holes = [later[0] - earlier[0] for earlier, later in zip(steady, steady[1:]) if start <= earlier[0] < end]
    hole, late = max(holes, default=0), max((e[3] for e in part), default=0)
    facts[name] = (len(part), round(hole * 1000), sum(1 for e in part if e[3] > 10000))
    print(f"{'+'.join(always)} {name}: {len(part)} arrived, LONGEST HOLE {hole * 1000:.0f} ms, worst lateness {late / 1000:.1f} ms, more than 10 ms late: {facts[name][2]}")

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
print("facts", posted, facts["before the loss"][0], facts["after the taps were gone"][0], facts["from the loss until the taps were gone"][1],
      facts["after the taps were gone"][1], facts["after the taps were gone"][2], lost_after, first_after, met, facts.get("clean", -1), facts.get("plain", -1))
PYTHON

grant() {
  tcc "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, indirect_object_identifier, flags, last_modified) VALUES ('kTCCServiceAccessibility', '$BUNDLE_ID', 0, 2, 3, 1, $REQUIREMENT, 'UNUSED', 0, strftime('%s', 'now'));" \
    || die "INVALID: the grant could not be written"
  sudo killall -9 tccd 2>/dev/null
  sleep 1
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
  step "round $round: $2"
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
  "$ASKER" arrivals "${3:-17}" > "$ARBOR_OUT/arrivals-$round.txt" 2>&1 &
  started $!
  eventually grep -q arrivals-ready "$ARBOR_OUT/arrivals-$round.txt" || { invalid "the listener at the end of the taps started"; leave; return 1; }
}
take() {
  TAKEN=$("$ASKER" now)
  sudo tccutil reset Accessibility "$BUNDLE_ID"
  echo "the permission was taken between $TAKEN and $("$ASKER" now)"
}
# What Arbor's log says of it, and when the taps went.
afterwards() {
  tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | grep -E "ermission|event tap|stopped|ERROR" | cut -c 12-220 | tail -n 8
  check "round $round: Arbor has no event tap left" eventually no_taps
  REMOVED=$(tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | grep -m 1 "permission is gone" | cut -c 12-23)
  [ -n "$REMOVED" ] || { invalid "Arbor's log says when the taps went"; REMOVED=$TAKEN; }
  "$ARBOR_BIN/arborctl" status | head -n 1 | cut -c 1-120
  echo "the tools' own permission afterwards: $(pointer ax-access)"
}
# bars: what both streams are held to, from the line of facts.
bars() {
  grep -v "^facts " "$ARBOR_SESSION_DIR/verdict"
  read -r _ posted before after hole_during hole_after late_after lost first met clean plain <<< "$(grep "^facts " "$ARBOR_SESSION_DIR/verdict")"
  [ "${posted:-0}" -ge 400 ] || invalid "the stream posted its events (${posted:-0})"
  [ "${before:-0}" -ge 80 ] || invalid "events arrived before the loss (${before:-0})"
  [ "${after:-0}" -ge 80 ] || invalid "events arrived after the taps were gone (${after:-0})"
  check "round $round: no hole longer than a second while Arbor let go of its taps (${hole_during:-?} ms)" test "${hole_during:-9999}" -le 1000
  check "round $round: no hole after that (${hole_after:-?} ms; a beat is 50)" test "${hole_after:-9999}" -le 150
  check "round $round: nothing more than 10 ms late after that" test "${late_after:-1}" -eq 0
  check "round $round: nothing lost after that" test "${lost:-1}" -eq 0
}

round_a() {
  begin "$1" "the scroll tap: ⌃⌥ down from a second before the loss, a notch and a key every 50 ms" || return
  "$ASKER" stream 12 50 "$X" "$Y" --kinds key,wheel --ctrl-opt 3 10 > "$ARBOR_OUT/stream-$round.txt" 2>&1 &
  stream=$!
  started "$stream"
  sleep 3.6
  arbor_taps | grep "mask=0x400000"
  tap_is 0x400000 true || invalid "the scroll tap is switched on at the loss"
  take
  ended "$stream" 150 || invalid "the stream came to its end"
  sleep 1
  cat "$ARBOR_OUT/stream-$round.txt"
  afterwards
  python3 "$ARBOR_SESSION_DIR/judge.py" "$ARBOR_OUT/arrivals-$round.txt" "$ARBOR_OUT/stream-$round.txt" "$TAKEN" "$REMOVED" key-down,key-up wheel \
    > "$ARBOR_SESSION_DIR/verdict"
  bars
  [ "${plain:-0}" -ge 30 ] || invalid "plain notches arrived before ⌃⌥ went down (${plain:-0})"
  [ "${met:-1}" -eq 0 ] || invalid "Arbor swallowed the notches while it had the permission, so the tap had traffic (${met:-?} got through)"
  check "round $round: notches arrive again after the loss (the first after ${first:-?} ms)" test "${first:--1}" -ge 0
  check "round $round: and within the second" test "${first:-9999}" -ge 0 -a "${first:-9999}" -le 1000
  check "round $round: no modifier is stuck: keys after ⌃⌥ came up carry none" test "${clean:-0}" -eq 1
  check "round $round: nothing of Arbor's is left on the screen" eventually nothing_of_arbors
  shot "round-$round-afterwards"
  leave
}

round_b() {
  begin "$1" "the gesture tap: a small pinch without ⌥ over a test window every 50 ms" || return
  tap_is 0x20000000 true || invalid "the gesture tap is switched on"
  "$ASKER" stream 12 50 "$X" "$Y" --kinds pinch > "$ARBOR_OUT/stream-$round.txt" 2>&1 &
  stream=$!
  started "$stream"
  sleep 4
  tap_is 0x20000000 true || invalid "the gesture tap is switched on at the loss"
  take
  ended "$stream" 150 || invalid "the stream came to its end"
  sleep 1
  cat "$ARBOR_OUT/stream-$round.txt"
  echo "pinches Arbor's tap saw begin: $(tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | grep -c "pinch began")"
  [ "$(tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | grep -c "pinch began")" -ge 20 ] || invalid "the gesture tap had traffic before the loss"
  afterwards
  python3 "$ARBOR_SESSION_DIR/judge.py" "$ARBOR_OUT/arrivals-$round.txt" "$ARBOR_OUT/stream-$round.txt" "$TAKEN" "$REMOVED" gesture > "$ARBOR_SESSION_DIR/verdict"
  bars
  check "round $round: nothing of Arbor's is left on the screen" eventually nothing_of_arbors
  leave
}

count_since() { awk -v mark="## $1" '$0 == mark { on = 1; next } /^## / { on = 0 } on' "$ARBOR_OUT/arrivals-$round.txt" | grep -c -- "$2"; }
mark() { sleep 0.3; echo "## $1" >> "$ARBOR_OUT/arrivals-$round.txt"; }
round_c() {
  local x y w h
  begin "$1" "the drag tap: the loss in the middle of a ⌃⌥-drag, the button down and the band showing" 40 || return
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

round_a a1
round_b b1
round_c c1
round_a a2
round_b b2
round_c c2

step "the end"
arbor_log
arbor_close_windows
