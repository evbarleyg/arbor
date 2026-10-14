# What the scripts about double-clicks share: check-macos-double-click.sh (what macOS makes of one stays) and check-F14.sh (the ones
# Arbor takes). Source it instead of lib.sh (it sources that first); do not run it.
#
#   frames_during <window> <file> <command…>   run the command; the file gets every distinct frame the window server reports for the
#                                     window from just before it until two to three seconds later
#   one_road <file>                 the window never turned round: it was moved once, however many stages an animation shows
#   stayed <file>                   it never moved at all
#   never_outside <file> x y w h    no frame in the file reaches outside the rectangle
#   real_frame_is <window> "<x y w h>" | same a b | differs a b | not <command…>
#   must <press…>                   a press whose check is that nothing happens: a ✘ if the nets of a person's Mac declined it
#   camera_on <window>|desktop|root
#   trace_on <name> "<remark>" | trace_off <name>     a trace (docs/TRACES.md) round what follows; it comes back as
#                                     mac-shell/traces/<name>.jsonl, and TRACE is that file, or empty where none can be recorded
#   arbor_moved_nothing | moves_of <window>           by that trace: Arbor set no frame | how often it set that window's
#   layouts                         how often Arbor has laid a display out so far. One more than the step asked for is a window put back
#   title_bar_action Fill|Maximize|Minimize|None|default|as-it-is    macOS's own answer to a title bar's double-click, before a session
#   witness_start | witness_stop    witness.swift at the far end of the taps: WITNESS_PID is empty where it cannot listen
#   mark <text…>                    everything the witness prints from here on belongs to what follows
#   reached <pattern> <count>       how many of the events since the mark got as far as the apps
#   late <down|up> [pattern]        how late they got there, in µs: "<events> <median> <second largest>"
#   arbor_taps | tap_is <mask> <true|false> | no_taps | no_double_click_tap
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TRACES="$ARBOR_OUT/traces"
mkdir -p "$TRACES"
TRACE=""

frames_during() {
  local id=$1 file=$2 watcher
  shift 2
  (
    end=$((SECONDS + 3))
    last=""
    while [ "$SECONDS" -lt "$end" ]; do
      now=$("$ARBOR_POINTER" frame "$id")
      if [ "$now" != "$last" ]; then echo "$now"; last=$now; fi
    done
  ) > "$file" 7>&- 8>&- 9>&- &
  watcher=$!
  started "$watcher"
  sleep 0.1
  "$@"
  ended "$watcher" 80 || kill_started "$watcher"
  echo "frames of $id meanwhile:"
  sed 's/^/    /' "$file"
}

# On its way from the first frame to the last, each of x, y, width and height went one way only.
one_road() {
  awk '
    NR == 1 { for (i = 1; i <= 4; i++) { first[i] = $i; before[i] = $i } next }
    { for (i = 1; i <= 4; i++) { step[NR, i] = $i - before[i]; before[i] = $i } rows = NR }
    END {
      for (i = 1; i <= 4; i++) {
        whole = before[i] - first[i]
        for (row = 2; row <= rows; row++) if (step[row, i] * whole < 0 || (whole == 0 && step[row, i] != 0)) bad = 1
      }
      exit bad
    }' "$1"
}
stayed() { [ "$(wc -l < "$1" | tr -d ' ')" -eq 1 ]; }
# macOS's zoom and fill go to the edges of the visible frame, past the gap that Arbor always leaves.
never_outside() {
  awk -v x="$2" -v y="$3" -v w="$4" -v h="$5" \
    '$1 < x || $2 < y || $1 + $3 > x + w || $2 + $4 > y + h { bad = 1 } END { exit bad }' "$1"
}
# Asked afresh every time `eventually` tries it.
real_frame_is() { [ "$(real_frame_of "$1")" = "$2" ]; }
same() { [ "$1" = "$2" ]; }
differs() { [ "$1" != "$2" ]; }
not() { ! "$@"; }
must() { "$@" || check "the press was let through: $*" false; }

camera_on() {
  state | python3 -c '
import json, sys
display = json.load(sys.stdin)["displays"][0]
tree, camera, want = display["tree"], display["camera"], sys.argv[1]
if want in ("root", "desktop"):
    sys.exit(0 if camera == tree[want] else 1)
windows = tree["nodes"][str(camera)]["kind"].get("stack", {}).get("windows", [])
sys.exit(0 if int(want) in windows else 1)
' "$1"
}

trace_on() {
  ctl trace on "$1"
  "$ARBOR_BIN/arborctl" trace note "$2" > /dev/null
}
trace_off() {
  local file
  ctl trace off
  TRACE=""
  for file in "$ARBOR_HOME"/traces/*-"$1".jsonl; do
    [ -f "$file" ] || continue
    TRACE="$TRACES/$1.jsonl"
    cp "$file" "$TRACE"
  done
}
# The rehearsal on Linux records no traces: what they alone can say is left out there.
arbor_moved_nothing() { [ -z "$TRACE" ] || ! grep -q -E '"call":"(setFrame|moveTogether)"' "$TRACE"; }
moves_of() { [ -z "$TRACE" ] && echo "?" || grep -c -E "\"call\":\"setFrame\".*\"id\":$1[,}]" "$TRACE"; }

layouts() { "$ARBOR_BIN/arborctl" stats | awk '/lay out a display/ { print $5 }'; }

# Before a session, because an app may read it when it starts.
title_bar_action() {
  if [ "$1" != as-it-is ] && arbor_may "change the setting \"double-click a window's title bar to\""; then
    if [ "$1" = default ]; then defaults delete -g AppleActionOnDoubleClick 2>/dev/null; else defaults write -g AppleActionOnDoubleClick -string "$1"; fi
  fi
  echo "AppleActionOnDoubleClick: $(defaults read -g AppleActionOnDoubleClick 2>/dev/null || echo "not set")"
}

# MARK: The witness

WITNESS="$ARBOR_ROOT/.build/mac-shell/witness"
SEEN="$ARBOR_OUT/witness.txt"
WITNESS_PID=""

# It only listens. Without it (no permission, say, or in a rehearsal) the checks that need it are left out.
witness_start() {
  : > "$SEEN"
  if arbor_is_current "$ARBOR_ROOT/scripts/mac-shell/witness.swift" "$WITNESS" \
    || swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/witness.swift" -o "$WITNESS" > "$ARBOR_OUT/build-witness.log" 2>&1; then
    # It ends by itself, whatever becomes of this script.
    "$WITNESS" watch "${1:-580}" >> "$SEEN" 2>&1 7>&- 8>&- 9>&- &
    WITNESS_PID=$!
    started "$WITNESS_PID"
    at_exit '[ -n "$WITNESS_PID" ] && kill_started "$WITNESS_PID"'
    eventually grep -q witness-ready "$SEEN" || witness_stop
  fi
  [ -n "$WITNESS_PID" ] || echo "no witness: $(head -n 3 "$ARBOR_OUT/build-witness.log" "$SEEN" 2>/dev/null | tr '\n' ' ')"
}
witness_stop() {
  [ -n "$WITNESS_PID" ] && kill_started "$WITNESS_PID"
  WITNESS_PID=""
}
mark() { sleep 0.4; echo "## $*" >> "$SEEN"; }
since_the_mark() {
  sleep 0.4
  awk '/^## / { text = ""; next } { text = text $0 "\n" } END { printf "%s", text }' "$SEEN"
}
reached() { [ "$(since_the_mark | grep -c -- "$1")" -eq "$2" ]; }
late() {
  since_the_mark | grep "^$1 " | grep -- "${2:-.}" | sed 's/.*delay_us=\([0-9-]*\).*/\1/' | sort -n \
    | awk '{ v[NR] = $1 } END { if (NR) print NR, v[int((NR + 1) / 2)], v[NR > 1 ? NR - 1 : 1]; else print 0, 0, 0 }'
}
arbor_taps() { "$WITNESS" taps | grep "pid=$ARBOR_PID "; }
# 0x2 is mouse-downs, 0x46 the rest of a click whose mouse-down Arbor hid.
tap_is() { arbor_taps | grep -q "mask=$1 enabled=$2"; }
no_taps() { [ "$(arbor_taps | wc -l)" -eq 0 ]; }
no_double_click_tap() { ! arbor_taps | grep -q "mask=0x46 "; }
