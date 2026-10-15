# For the probes into a display that stands still in mid-motion (probe-standstill-*.sh): lib-film.sh's films, with something on the display that
# never stops moving, a control that needs no Arbor, and what macOS itself can say about the moment. Source it; do not run it.
#
#   still_build                     film_build, cast_build, and compile pulse.swift and mover.swift
#   still_begin | still_end         the Mac as a person has it (no Reduce Motion, no Reduce Transparency), camera, sampler | and all of it stopped, the table printed
#   pulse_start | pulse_stop        the strip whose squares cross once a second (pulse.swift): with it, a wait between two frames is a display that stood still
#   filmed <name> "<what is done>" <command…>   one film of one thing: the command is the thing. What the processes burnt meanwhile is noted; the pictures of a
#                                   film in which the display never stood still for 150 ms are thrown away, its log is kept
#   mover <step…>                   mover.swift on the cast's windows
#   away_and_back <name> [n]        n times (3): ⌃⌥D, a film; ⌃⌥[, a film: <name>-<i>-away, <name>-<i>-back
#   watched <name> <command…>       `filmed`, with spindump (or, with STILL_WATCH=sample, `sample` of the window server, Arbor and the cast), the system's log at debug level and macOS's own pictures beside it. Not for measuring: for seeing who waits for whom
#   system_log_of_the_worst [n]     what the system's log holds about the n (6) longest standstills of the run
source "$(dirname "${BASH_SOURCE[0]}")/lib-film.sh"
needs_throwaway_mac "film the whole display, change Reduce Motion and Reduce Transparency, and sample every process as root"

STILL_PULSE="$ARBOR_ROOT/.build/mac-shell/pulse"
STILL_MOVER="$ARBOR_ROOT/.build/mac-shell/mover"
STILL_PY="$ARBOR_ROOT/scripts/mac-shell/standstill.py"
STILL_PULSE_PID=""
# Shortcuts and the menu bar item on, as a person has them.
STILL_FACE="ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0"
# How long a film goes on after the thing was done. With the strip up every frame is kept, and the camera has room for six seconds of those.
STILL_REST=1.6

still_build() {
  local tool
  film_build
  cast_build
  [ -z "${ARBOR_REHEARSAL:-}" ] || return 0
  for tool in pulse mover; do
    if ! swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/$tool.swift" -o "$ARBOR_ROOT/.build/mac-shell/$tool" > "$ARBOR_OUT/build-$tool.log" 2>&1; then
      grep -A 6 "error:" "$ARBOR_OUT/build-$tool.log" | head -n 60
      die "scripts/mac-shell/$tool.swift did not compile"
    fi
  done
}

still_begin() {
  step "the Mac"
  sw_vers 2>/dev/null
  echo "processors: $(sysctl -n hw.ncpu 2>/dev/null), memory: $(($(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1048576)) MB"
  system_profiler SPDisplaysDataType 2>/dev/null | grep -E "Chipset|Type|Vendor|Metal|Resolution|VRAM" | sed 's/^ */  /'
  pointer displays
  macos_reduce_motion off
  glass on
  macos_tiling
  camera_start || die "no camera"
  sampler_start
  ARBOR_TEST_WINDOWS_ARGS="--regular"
}

still_end() {
  pulse_stop
  sampler_stop
  camera_stop
  step "for how long the display stood still"
  python3 "$STILL_PY" table "$ARBOR_OUT"
}

pulse_start() {
  local tiers=""
  [ -z "${ARBOR_REHEARSAL:-}" ] || { echo "> pulse_start (not rehearsed)"; return 0; }
  [ -z "$STILL_PULSE_PID" ] || return 0
  if command -v taskpolicy > /dev/null; then tiers="taskpolicy -l 0 -t 0"; fi
  # Between the menu bar and the windows, in the middle, where the Desktop's part of the arrangement is.
  # shellcheck disable=SC2086
  $tiers "$STILL_PULSE" "$ARBOR_OUT/pulse.log" 440 31 < /dev/null >> "$ARBOR_OUT/pulse-stderr.log" 2>&1 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&- &
  STILL_PULSE_PID=$!
  started "$STILL_PULSE_PID"
  sleep 1
  echo "the pulse beats (pid $STILL_PULSE_PID)"
}

pulse_stop() {
  [ -n "$STILL_PULSE_PID" ] || return 0
  kill_started "$STILL_PULSE_PID"
  STILL_PULSE_PID=""
}

# The processes whose work is counted: the window server, Arbor, the cast.
still_pids() {
  local server
  server=$(ps -axo pid=,comm= | awk '$2 ~ /\/WindowServer$/ { print $1; exit }')
  echo "$server ${ARBOR_PID:-} ${ARBOR_WINDOWS_PID:-} ${ARBOR_EXTRA_PIDS:-}" | tr ',' ' ' | xargs | tr ' ' ','
}

still_cpu() {
  [ -z "${ARBOR_REHEARSAL:-}" ] || return 0
  ps -o comm=,cputime= -p "$(still_pids)" 2>/dev/null | awk '{ n = split($1, path, "/"); print "cpu", path[n], $2 }' | while read -r line; do note "$line"; done
}

filmed() {
  local name=$1 text=$2 longest
  shift 2
  scene "$name" camera "$text" || return 1
  still_cpu
  "$@"
  sleep "$STILL_REST"
  still_cpu
  scene_end 0
  [ -z "${ARBOR_REHEARSAL:-}" ] || return 0
  longest=$(python3 "$STILL_PY" longest "$ARBOR_OUT/films/$name")
  echo "the display stood still for $longest ms at most"
  if [ "${longest:-0}" -lt 150 ] && [ -z "${STILL_KEEP:-}" ]; then
    find "$ARBOR_OUT/films/$name" -name '*.png' -delete
  fi
}

mover() {
  [ -z "${ARBOR_REHEARSAL:-}" ] || { echo "> mover $* (not rehearsed)"; return 0; }
  echo "> mover $*"
  "$STILL_MOVER" "$ARBOR_OUT/mover.log" "${ARBOR_WINDOWS_PID:-0}${ARBOR_EXTRA_PIDS:+,$ARBOR_EXTRA_PIDS}" "$@" 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&-
}

away_and_back() {
  local name=$1 times=${2:-3} i=1
  while [ "$i" -le "$times" ]; do
    filmed "$name-$i-away" "presses ⌃⌥D" key ctrl+opt+d
    filmed "$name-$i-back" "presses ⌃⌥[" key ctrl+opt+[
    i=$((i + 1))
  done
}

# Who waits for whom. Both tools take a moment to begin, so the thing is done a second and a half after they were started.
watched() {
  local name=$1 stream="" keep=${STILL_KEEP:-} tries=0 pid server
  shift
  if [ -z "${ARBOR_REHEARSAL:-}" ]; then
    log stream --level debug --style compact \
      --predicate 'process == "WindowServer" OR process == "Arbor" OR process == "Oak" OR process == "Elm" OR process == "Ash" OR process == "Fir" OR process == "Dock" OR process == "mover" OR process == "runningboardd" OR process == "TextEdit" OR process == "Safari" OR process == "Terminal" OR process == "Notes" OR process == "Preview"' \
      > "$ARBOR_OUT/log-$name.txt" 2>&1 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&- &
    stream=$!
    started "$stream"
    if [ "${STILL_WATCH:-spindump}" = sample ]; then
      server=$(ps -axo pid=,comm= | awk '$2 ~ /\/WindowServer$/ { print $1; exit }')
      sudo sample "$server" 5 2 -file "$ARBOR_OUT/sample-$name-WindowServer.txt" > /dev/null 2>&1 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&- &
      for pid in $(echo "${ARBOR_PID:-} ${ARBOR_WINDOWS_PID:-} ${ARBOR_EXTRA_PIDS:-}" | tr ',' ' '); do
        sample "$pid" 5 2 -mayDie -file "$ARBOR_OUT/sample-$name-$pid.txt" > /dev/null 2>&1 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&- &
      done
    else
      sudo spindump -notarget 5 10 -timeline -o "$ARBOR_OUT/spindump-$name.txt" > "$ARBOR_OUT/spindump-$name.log" 2>&1 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&- &
    fi
    sleep 1.5
  fi
  STILL_KEEP=yes
  filmed "$name" "the same, watched" "$@"
  STILL_KEEP=$keep
  [ -n "$stream" ] || return 0
  # They go on for a good while after the sampling: they look up the names. (Root's processes: `kill -0` says nothing about them.)
  while ps -axo comm= | grep -q -E '/(spindump|sample)$' && [ "$tries" -lt 120 ]; do
    sleep 1
    tries=$((tries + 1))
  done
  echo "watched: the samplers were done after $tries s"
  kill_started "$stream"
  sudo chmod a+r "$ARBOR_OUT"/spindump-* "$ARBOR_OUT"/sample-* 2>/dev/null
  still_thin "$ARBOR_OUT/spindump-$name.txt"
  tail -n 3 "$ARBOR_OUT/spindump-$name.log" 2>/dev/null
  echo "watched: $(wc -l < "$ARBOR_OUT/log-$name.txt" | tr -d ' ') lines of the system's log"
}

# Of a spindump of everything, the head and the processes that have a part in this.
still_thin() {
  [ -f "$1" ] || return 0
  python3 - "$1" << 'PYTHON'
import re, sys
path = sys.argv[1]
with open(path, encoding="utf-8", errors="replace") as file:
    text = file.read()
parts = re.split(r"(?m)^(?=Process:\s)", text)
wanted = re.compile(r"Process:\s+(WindowServer|Arbor|Oak|Elm|Ash|Fir|Dock|mover|pulse|camera|sampler|ArborTestWindows|TextEdit|Safari|Terminal|Notes)\b")
kept = [parts[0]] + [part for part in parts[1:] if wanted.match(part)]
with open(path, "w", encoding="utf-8") as file:
    file.write("".join(kept)[:6_000_000])
PYTHON
}

system_log_of_the_worst() {
  local from to name
  [ -z "${ARBOR_REHEARSAL:-}" ] || return 0
  python3 "$STILL_PY" worst "$ARBOR_OUT" "${1:-6}" | while read -r from to name; do
    limit 60 log show --start "$(date -r "$from" '+%Y-%m-%d %H:%M:%S')" --end "$(date -r "$to" '+%Y-%m-%d %H:%M:%S')" --info --debug --style compact \
      2>&1 | head -n 6000 > "$ARBOR_OUT/system-log-$name.txt"
    echo "system-log-$name.txt: $(wc -l < "$ARBOR_OUT/system-log-$name.txt" | tr -d ' ') lines"
  done
}

# The arrangement of the films in which the standstill was found: two columns of two with the Desktop between them.
still_arrange() {
  ctl float-all
  sleep 1
  ctl dock "$W4" left
  ctl dock "$W3" right
  ctl dock "$W2" beside "$W4" bottom
  ctl dock "$W1" beside "$W3" bottom
  sleep 1.5
}

# A real click on its title bar, so that it has the keyboard.
still_press() {
  # shellcheck disable=SC2046
  click $(titlebar_of "$1")
  sleep 0.6
}
