#!/bin/bash
# The display never stands still while Arbor moves the view (rule 3: no jolts).
#
#   scripts/mac-shell/rehearse.sh scripts/mac-shell/check-standstill.sh      on Linux, first, for nothing
#   scripts/mac-shell/run.sh scripts/mac-shell/check-standstill.sh           eight minutes on a hosted Mac
#   scripts/mac-shell/standstill.py table .mac-shell/check-standstill-<run id>
#
# WHAT ONLY A MAC CAN ANSWER: whether the display went on showing new pictures while the view moved. Every check of frames passes on a display that showed one
# picture for a second in the middle of an act: the windows are where they belong before and after. So a strip whose squares never stop (pulse.swift)
# lies on top of everything, framewatch.swift writes down when the display showed a new picture, and standstill.py finds the longest wait.
# No picture is taken or kept. Beside them, witnesses that film nothing: the display's own beat as another process is told it (pulse.swift's display link), for
# how long a key is held that the tool lets go of at once, and sampler.swift, to which a window server that answers nobody is a sample that came late.
#
# WHAT WAS FOUND, and is macOS's own doing (collab/reality.json, `a-panel-shown-again-costs-a-hosted-mac-a-second`): the first time in a process's life that a panel which
# draws itself is shown again after seconds out of view, a hosted Mac's display stands still for most of a second (0.43 to 1.45), at times with the keys and the window list. For
# Arbor that is the first way back to a view with a tile in it, once after every start, with motion and without, filmed or not. A plain tool gets the same.
#   1. THE CONTROL, told and not checked: no Arbor. A plain tool, a fresh process each time, shows a panel as Arbor shows a tile, puts it away and shows it again: after
#      0.3, 1, 2 and 3.4 s; drawing less; and handing over a finished bitmap in place of drawing
#   2. Arbor from fresh starts, without motion and with: every way back but the first is CHECKED at 0.3 s: what stands still then is Arbor's to answer for. The first is
#      measured and printed like the others, with the plain tool's beside it; marked over 1.5 s, and checked at 2.5 s
#   3. the same with nobody filming: told
ARBOR_TIME_LIMIT=900
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "watch the whole display for changes, and change the Accessibility setting Reduce Motion"

STILL_PULSE="$ARBOR_ROOT/.build/mac-shell/pulse"
STILL_WATCH="$ARBOR_ROOT/.build/mac-shell/framewatch"
STILL_MOVER="$ARBOR_ROOT/.build/mac-shell/mover"
STILL_SAMPLER="$ARBOR_ROOT/.build/mac-shell/sampler"
STILL_SAMPLER_PID=""
STILL_PY="$ARBOR_ROOT/scripts/mac-shell/standstill.py"
STILL_PULSE_PID=""
STILL_WATCH_PID=""
# A person sees a hitch of a tenth of a second, and a hosted Mac has hiccups of 0.13 s with nothing being done. What was found is 0.43 s and more.
STILL_LIMIT=300
# The first way back after a start is macOS's own (see above), and is measured and printed all the same: a fault that is passed over is not a fault that is cured.
# It was 1.45 s at the most. A limit that stands a frame or two from what the Mac has done by itself goes red one day with nothing of Arbor's changed, and a red that
# means nothing teaches people to walk past reds. So: over 1.5 s it is printed with a mark, and over 2.5 s something has been added to it.
STILL_FIRST=2500
STILL_FIRST_MARK=1500

still_build() {
  local tool
  arbor_build
  [ -z "${ARBOR_REHEARSAL:-}" ] || return 0
  for tool in pulse framewatch mover sampler; do
    arbor_is_current "$ARBOR_ROOT/scripts/mac-shell/$tool.swift" "$ARBOR_ROOT/.build/mac-shell/$tool" && continue
    if ! swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/$tool.swift" -o "$ARBOR_ROOT/.build/mac-shell/$tool" > "$ARBOR_OUT/build-$tool.log" 2>&1; then
      grep -A 6 "error:" "$ARBOR_OUT/build-$tool.log" | head -n 60
      die "scripts/mac-shell/$tool.swift did not compile"
    fi
  done
}

# still_watch stream|blind: starts the watcher that way, in place of the one that runs. Descriptor 4 is the script's end of its stdin.
STILL_WATCHES=0
still_watch() {
  local tries=0 log
  [ -z "${ARBOR_REHEARSAL:-}" ] || { echo "> the watcher: $1 (not rehearsed)"; return 0; }
  [ "$1" = "${STILL_MODE:-}" ] && return 0
  if [ -n "$STILL_WATCH_PID" ]; then
    echo stop >&4
    exec 4>&-
    ended "$STILL_WATCH_PID" 30 || kill_started "$STILL_WATCH_PID"
  fi
  STILL_MODE=$1
  STILL_WATCHES=$((STILL_WATCHES + 1))
  log="$ARBOR_OUT/framewatch-$STILL_WATCHES.log"
  rm -f "$STILL_TEMP/commands"
  mkfifo "$STILL_TEMP/commands" || die "no fifo in $STILL_TEMP"
  # shellcheck disable=SC2046
  "$STILL_WATCH" $([ "$1" = blind ] && echo --blind) "$ARBOR_OUT/frames.log" < "$STILL_TEMP/commands" > "$log" 2>&1 3>&- 5>&- 6>&- 7>&- 8>&- 9>&- &
  STILL_WATCH_PID=$!
  started "$STILL_WATCH_PID"
  exec 4> "$STILL_TEMP/commands"
  until grep -q -E "^framewatch-(ready|failed)" "$log" || [ "$tries" -ge 150 ]; do
    sleep 0.1
    tries=$((tries + 1))
  done
  grep -q "^framewatch-ready" "$log" || { cat "$log"; die "nobody watches the display"; }
  sleep 1
}

pulse_start() {
  local tiers=""
  [ -z "${ARBOR_REHEARSAL:-}" ] && [ -z "$STILL_PULSE_PID" ] || return 0
  if command -v taskpolicy > /dev/null; then tiers="taskpolicy -l 0 -t 0"; fi
  # Between the menu bar and the windows.
  # shellcheck disable=SC2086
  $tiers "$STILL_PULSE" "$ARBOR_OUT/pulse.log" 440 31 < /dev/null >> "$ARBOR_OUT/pulse-stderr.log" 2>&1 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&- &
  STILL_PULSE_PID=$!
  started "$STILL_PULSE_PID"
  sleep 1
}

pulse_stop() {
  [ -n "$STILL_PULSE_PID" ] || return 0
  kill_started "$STILL_PULSE_PID"
  STILL_PULSE_PID=""
}

still_start() {
  local tiers=""
  [ -z "${ARBOR_REHEARSAL:-}" ] || { echo "> the strip, the watcher and the sampler (not rehearsed)"; return 0; }
  scratch_dir still STILL_TEMP
  still_watch stream
  pulse_start
  # What the runner's agent starts counts as work in the background, and its timers come late.
  if command -v taskpolicy > /dev/null; then tiers="taskpolicy -l 0 -t 0"; fi
  # Descriptors 5 and 6 are the script's ends of the sampler's fifos; both ways, so that opening them does not wait for a sampler that ended at once.
  mkfifo "$STILL_TEMP/in" "$STILL_TEMP/out" || die "no fifos in $STILL_TEMP"
  # shellcheck disable=SC2086
  $tiers "$STILL_SAMPLER" "$ARBOR_OUT/samples.log" "$STILL_TEMP/in" "$STILL_TEMP/out" --hz 60 2>> "$ARBOR_OUT/sampler.log" 3>&- 4>&- 7>&- 8>&- 9>&- &
  STILL_SAMPLER_PID=$!
  started "$STILL_SAMPLER_PID"
  exec 6<> "$STILL_TEMP/in" 5<> "$STILL_TEMP/out"
  sleep 1
}

still_stop() {
  [ -n "$STILL_WATCH_PID" ] || return 0
  pulse_stop
  kill -0 "$STILL_SAMPLER_PID" 2>/dev/null && echo stop >&6
  exec 6>&- 5<&-
  ended "$STILL_SAMPLER_PID" 30 || kill_started "$STILL_SAMPLER_PID"
  echo stop >&4
  exec 4>&-
  ended "$STILL_WATCH_PID" 30 || kill_started "$STILL_WATCH_PID"
  STILL_WATCH_PID=""
  step "for how long the display stood still"
  python3 "$STILL_PY" table "$ARBOR_OUT"
  step "every wait of over 300 ms between two frames, whatever was going on"
  python3 "$STILL_PY" waits "$ARBOR_OUT" 300
  step "when the window server kept the sampler waiting for over 300 ms"
  awk '$2 == "L" && $3 > 300 { print $1, $3 " ms" }' "$ARBOR_OUT/samples.log"
  step "the system's log, on one clock: who set up drawing through the GPU, Arbor's own lines, and what the window server says of its own threads"
  limit 120 log show --last 20m --info --debug --style compact --predicate \
    '(sender == "QuartzCore" AND eventMessage CONTAINS "Precompiled pipelines") OR (subsystem == "dev.arbor" AND (eventMessage CONTAINS "back" OR eventMessage CONTAINS "starting" OR eventMessage CONTAINS "drawing ready")) OR (process == "WindowServer" AND eventMessage CONTAINS "delayed by")' \
    2>&1 | grep -E "Arbor|mover|WindowServer" | cut -c 1-150
}

# A watcher that dies between the look and the line must not take the script with it.
trap '' PIPE
still_mark() { [ -n "$STILL_WATCH_PID" ] && echo "mark $*" >&4; }

# first_way_out <group>: the check of a first way out, with the plain tool's own beside it: whoever reads a red sees at once whether the Mac was slow for everybody
first_way_out() {
  check "the first way out, which costs what macOS makes it cost, took no more than that" calm "$1" "$STILL_FIRST"
  [ -z "${ARBOR_REHEARSAL:-}" ] || return 0
  echo "    the first way out: $(python3 "$STILL_PY" each "$ARBOR_OUT" "$1") ms; the plain tool's, with no Arbor, in this run: $(python3 "$STILL_PY" each "$ARBOR_OUT" control-away-3400) ms"
  python3 "$STILL_PY" calm "$ARBOR_OUT" "$1" "$STILL_FIRST_MARK" > /dev/null || echo "    (!) OVER $STILL_FIRST_MARK ms: longer than it was ever seen to take"
}

# watched <scene> <command…>: the display at rest for a good second, the thing, and two seconds more
watched() {
  local name=$1
  shift
  still_mark "scene $name"
  sleep 1.3
  still_mark action
  "$@"
  sleep 2
}

# calm <group> [ms]: in none of its scenes did the display stand still for that long (STILL_LIMIT)
calm() {
  [ -z "${ARBOR_REHEARSAL:-}" ] || { echo "(not rehearsed)"; return 0; }
  # Read while the watcher goes on writing: it is all there up to the last mark, once the watcher has had a moment to write that.
  sleep 0.3
  python3 "$STILL_PY" calm "$ARBOR_OUT" "$1" "${2:-$STILL_LIMIT}"
}

mover() {
  [ -z "${ARBOR_REHEARSAL:-}" ] || { echo "> mover $* (not rehearsed)"; return 0; }
  echo "> mover $*"
  "$STILL_MOVER" "$ARBOR_OUT/mover.log" "${ARBOR_WINDOWS_PID:-0}" "$@" 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&-
}

still_build
macos_reduce_motion off
still_start

# Two windows side by side and a third that cannot be as narrow as its slot: a tile.
tile_session() {
  ARBOR_TEST_WINDOWS_ARGS="--regular --min-size 3:700x500"
  # Written down before the start: no second of it is spent with another setting.
  arbor_settings "{\"animationDuration\": $MOTION}"
  still_mark "start of Arbor"
  arbor_start 3 "$@"
  sleep 2
  ctl dock "$W1" left
  ctl dock "$W2" right
  sleep 1.5
  ctl dock "$W3" right
  sleep 2
  check "the third window is a tile" is tile "$W3"
}

step "0. nothing is done"
watched rest-1 sleep 0.3
still_mark scene
check "the strip is seen to move, and the display does not stand still by itself" calm rest

step "1. THE CONTROL: no Arbor. A plain tool, a fresh process each time, shows a panel of its own as Arbor shows a tile, puts it away and shows it again"
T=771:43:241:653
# again <name> <ms out of view> [look:…]
again() {
  local name=$1 away=$2
  shift 2
  watched "$name" mover "$@" "tile:$T:0.2" wait:1500 leave:0.2 "wait:$away" go show:0.2
}
for i in 1 2; do
  again "control-away-300-$i" 300
  again "control-away-1000-$i" 1000
  again "control-away-2000-$i" 2000
  again "control-away-3400-$i" 3400
  again "control-bitmap-3400-$i" 3400 look:bitmap
  again "control-plain-3400-$i" 3400 look:plain
done
again control-bitmap-3400-3 3400 look:bitmap
still_mark scene

# trial <name> stream|blind: a fresh start; into the window that is a tile and back out by the key, three times. The first way back has a name of its own.
trial() {
  local name=$1 i
  still_watch "$2"
  tile_session ARBOR_NO_HOTKEYS=0
  watched "$name-first-away" ctl zoom "$W3"
  watched "$name-first-back" key ctrl+opt+[
  for i in 1 2; do
    watched "$name-away-$i" ctl zoom "$W3"
    watched "$name-back-$i" key ctrl+opt+[
  done
  still_mark scene
}

MOTION=0
for session in a b; do
  claim "into a window that is a tile and back out, after the first time, without motion: the display never stands still ($session)"
  trial "tile-$session" stream
  check "on the way in" calm "tile-$session-away"
  check "on the way out" calm "tile-$session-back"
  first_way_out "tile-$session-first-back"
  arbor_stop
done

MOTION=0.46
claim "into a window that is a tile and back out, after the first time, with motion: the display never stands still"
trial tile-motion stream
check "on the way in" calm tile-motion-away
check "on the way out" calm tile-motion-back
first_way_out tile-motion-first-back
arbor_stop

MOTION=0
step "3. with nobody filming"
trial tile-unfilmed blind
arbor_stop
still_watch stream

still_stop
