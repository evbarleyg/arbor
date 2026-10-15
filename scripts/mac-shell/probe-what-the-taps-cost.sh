#!/bin/bash
# What do Arbor's event taps cost every click, key and scroll of the Mac, and what is only the Mac's own unrest?
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-what-the-taps-cost.sh      (about five minutes)
#
# On a hosted Mac, with Arbor's four taps in and nothing else going on, 85 of 550 posted events reached the far end of the taps more than 10 ms late.
# Is that the Mac, Arbor, or Arbor's taps? The same stream (asker.swift: a click, the key F19 and a notch of the wheel every 50 ms, each numbered), the same listener,
# the same Mac, the same test windows, in turns: no Arbor at all; Arbor without taps and shortcuts (ARBOR_NO_HOTKEYS=1), which still has its mouse monitor and
# its observers; Arbor with its four taps. Three turns of each, and in each turn ten seconds of clicks into a window's content and ten of presses on its
# title bar, where Arbor also looks at the window server's list (`AXWindowSystem.makePress`), which is no tap's doing.
#
# ON A RELEASE BUILD, which is what people run, if one compiles within nine minutes; else on the debug build every Mac shell script uses. THE BUILD line says which.
#
# For each turn and each kind of event: how many arrived of how many, the median, the 99th percentile and the worst of the lateness, how many were more than 10 ms
# late, the longest hole. Then all turns of a kind together, and THE TAPS' OWN SHARE: with taps against without. It measures; its checks are only about
# whether the measurement is worth anything.
#
# It clicks and types for four minutes: hosted Macs only.
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/lib-gestures.sh"
needs_throwaway_mac "click, type and scroll twenty times a second for four minutes"

ASKER="$ARBOR_ROOT/.build/mac-shell/asker"
WITNESS="$ARBOR_ROOT/.build/mac-shell/witness"
gone() { ! kill -0 "$1" 2>/dev/null; }
running() { "$ARBOR_BIN/arborctl" status 2>/dev/null | grep -q "^running"; }
taps_of_arbor() {
  [ -n "$ARBOR_PID" ] || { echo 0; return; }
  "$WITNESS" taps | grep -c "pid=$ARBOR_PID " || true
}

arbor_build
for tool in asker witness; do
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/$tool.swift" -o "$ARBOR_ROOT/.build/mac-shell/$tool" \
    > "$ARBOR_OUT/build-$tool.log" 2>&1 || { cat "$ARBOR_OUT/build-$tool.log"; die "scripts/mac-shell/$tool.swift did not compile"; }
done

cat > "$ARBOR_SESSION_DIR/figures.py" <<'PYTHON'
import re, sys

def seconds(text):
    hours, minutes, rest = text.split(":")
    return int(hours) * 3600 + int(minutes) * 60 + float(rest)

def read(path):
    """What arrived while this list's own stream ran: a listener that outlives it overhears the next one's beginning."""
    text = open(path.replace("arrivals-", "stream-")).read()
    begins, ends = (seconds(re.search(r"(\S+) stream " + word, text).group(1)) for word in ("begins", "ends"))
    found = []
    for line in open(path):
        match = re.match(r"(\S+) (\S+) n=(\d+) late_us=(-?\d+)", line)
        if match and begins - 0.05 <= seconds(match.group(1)) <= ends + 0.4:
            found.append((seconds(match.group(1)), match.group(2), int(match.group(3)), int(match.group(4))))
    return found

def figures(lists):
    """One line for each kind of event over these lists; holes are looked for within a list, never from one to the next."""
    lines = []
    for kind in ["down", "up", "key-down", "key-up", "wheel", "all"]:
        late, hole = [], 0
        for found in lists:
            part = [entry for entry in found if kind in (entry[1], "all")]
            late += [entry[3] for entry in part]
            hole = max([hole] + [later[0] - earlier[0] for earlier, later in zip(part, part[1:])])
        late.sort()
        if late:
            lines.append(f"    {kind:9} {len(late):5} arrived  median {late[len(late) // 2] / 1000:6.2f} ms  99th {late[min(len(late) - 1, int(len(late) * 0.99))] / 1000:6.2f} ms  "
                         f"worst {late[-1] / 1000:6.2f} ms  over 10 ms: {sum(1 for value in late if value > 10000):3}  longest hole {hole * 1000:4.0f} ms")
    return lines

print("\n".join(figures([read(path) for path in sys.argv[1:]])))
PYTHON

step "the build"
ARBOR_UNDER_TEST="$ARBOR_BIN/Arbor"
BUILD="DEBUG (swift build, not optimised)"
if limit 540 swift build -c release --product Arbor > "$ARBOR_OUT/build-release.log" 2>&1 && [ -x "$ARBOR_ROOT/.build/release/Arbor" ]; then
  ARBOR_UNDER_TEST="$ARBOR_ROOT/.build/release/Arbor"
  BUILD="RELEASE (swift build -c release)"
else
  tail -n 5 "$ARBOR_OUT/build-release.log"
fi
echo "THE BUILD: $BUILD, after $SECONDS s"

# The test windows stay for the whole run; only Arbor comes and goes. Nothing is docked, so that they stay where they are whoever runs. The second is in front.
# A press that missed would land on the wallpaper, at which macOS sweeps every window aside.
macos_click_wallpaper off
# This is about the taps, so it asks for them, whatever Arbor ships with. The file stays in the session's home, which every Arbor of this run is given.
arbor_settings "{$ARBOR_GESTURES_ON}"
arbor_start 2 ARBOR_NO_HOTKEYS=0
# where <content|title-bar>: x y, by the window server, which is there in every turn.
where() {
  local x y w h
  read -r x y w h <<< "$(real_frame_of "$W2")"
  x=${x%.*} y=${y%.*} w=${w%.*} h=${h%.*}
  if [ "$1" = content ]; then echo "$((x + w / 2)) $((y + h / 2))"; else echo "$((x + w / 2)) $((y + 12))"; fi
}
echo "clicks into the content at $(where content), presses on the title bar at $(where title-bar)"
sysctl -n hw.ncpu hw.memsize | tr '\n' ' '; echo "(cores, bytes of memory)"

without_arbor() {
  [ -n "$ARBOR_PID" ] || return 0
  "$ARBOR_BIN/arborctl" quit > /dev/null 2>&1
  ended "$ARBOR_PID" || kill_started "$ARBOR_PID"
  ARBOR_PID=""
  sleep 1
}
# with_arbor <ARBOR_NO_HOTKEYS' value>: as arbor_start starts it, on the windows that are there, without the debug log, as people run it.
with_arbor() {
  without_arbor
  env ARBOR_ONLY_PIDS="$ARBOR_WINDOWS_PID" ARBOR_NO_PROMPT=1 ARBOR_DEBUG=0 ARBOR_NO_STATUS_ITEM=1 ARBOR_NO_WATCHDOG=1 ARBOR_NO_HOTKEYS="$1" \
    "$ARBOR_UNDER_TEST" >> "$ARBOR_OUT/arbor-stderr-turns.log" 2>&1 7>&- 8>&- 9>&- &
  ARBOR_PID=$!
  started "$ARBOR_PID"
  eventually running || die "Arbor did not start again"
  sleep 1
}

# measure <kind of turn> <number> <content|title-bar>
measure() {
  local list="$ARBOR_OUT/arrivals-$1-$2-$3.txt" stream posted x y
  read -r x y <<< "$(where "$3")"
  "$ASKER" arrivals 11.5 > "$list" 2>&1 &
  started $!
  eventually grep -q arrivals-ready "$list" || die "the listener at the end of the taps did not start"
  "$ASKER" stream 10 50 "$x" "$y" > "$ARBOR_OUT/stream-$1-$2-$3.txt" 2>&1 &
  stream=$!
  started "$stream"
  ended "$stream" 140 || die "the stream did not come to its end"
  sleep 1.5 # until the listener has ended
  posted=$(sed -n 's/.*stream ends: \([0-9]*\) events posted/\1/p' "$ARBOR_OUT/stream-$1-$2-$3.txt")
  echo "  $1, turn $2, $3 ($x $y): posted ${posted:-0}, Arbor's taps: $(taps_of_arbor)"
  python3 "$ARBOR_SESSION_DIR/figures.py" "$list"
  check "$1, turn $2, $3: the stream posted its events and every one arrived" \
    test "${posted:-0}" -ge 500 -a "$(sed -n 's/.* n=\([0-9]*\) .*/\1/p' "$list" | sort -u | wc -l)" -eq "${posted:-0}"
}

for turn in 1 2 3; do
  step "turn $turn ($BUILD)"
  without_arbor
  measure no-arbor "$turn" content
  measure no-arbor "$turn" title-bar
  with_arbor 1
  check "turn $turn: this Arbor has no taps" test "$(taps_of_arbor)" -eq 0
  measure arbor-without-taps "$turn" content
  measure arbor-without-taps "$turn" title-bar
  with_arbor 0
  check "turn $turn: Arbor has its four taps" test "$(taps_of_arbor)" -eq 4
  measure arbor-with-taps "$turn" content
  measure arbor-with-taps "$turn" title-bar
done

step "all turns together ($BUILD)"
for where in content title-bar; do
  for kind in no-arbor arbor-without-taps arbor-with-taps; do
    echo "  $kind, $where, three turns:"
    python3 "$ARBOR_SESSION_DIR/figures.py" "$ARBOR_OUT"/arrivals-"$kind"-*-"$where".txt
  done
done
echo "THE TAPS' OWN SHARE is the difference between the last two of each three; what Arbor costs otherwise (its mouse monitor, its observers), between the first two."
arbor_stop after-quit
