#!/bin/bash
# Where the time goes in the first motion of a run. On a hosted Mac the first dock of a day took over two seconds from the
# key to the first move, every later one a quarter of a second; Arbor's log says nothing in between but "stage up" at the end.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-first-motion.sh
#
# The question only a Mac can answer: of all that the first motion does for the first time (the stage's panel and layers, the
# apps' icons and colours, the picture of the desktop, the first commit to the window server), what takes the two seconds, and
# is it paid once per run of Arbor or once per login?
#
# Two runs of Arbor, one after the other, each with four test windows. In each: a rest after the launch, then `sample` watches
# Arbor's threads while two windows are docked, one after the other, and each command is timed. Kept: mac-shell/sample-<n>.txt
# (call stacks, no window's title), Arbor's log and `stats`.
# Safe on a person's Mac: its own test windows, an Arbor limited to them, no setting changed. About a minute after the build.
source "$(dirname "$0")/lib.sh"

now() { python3 -c 'import time; print(int(time.time() * 1000))'; }

# timed <words of a command>: runs it and says how long the answer took.
timed() {
  local began ended
  began=$(now)
  "$ARBOR_BIN/arborctl" "$@" > /dev/null 2>&1
  ended=$(now)
  echo "  $((ended - began)) ms: $*"
}

step "the Mac"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m), $(sysctl -n hw.ncpu) cores"
arbor_build
timed status

for run in 1 2; do
  step "run $run of Arbor"
  arbor_start 4
  # Past the housekeeping that follows a launch: the wallpaper's file is read 0.6 s after the first layout.
  sleep 4
  if command -v sample > /dev/null 2>&1; then
    sample "$ARBOR_PID" 6 1 -mayDie -file "$ARBOR_OUT/sample-$run.txt" > /dev/null 2>&1 &
    started $!
    # It takes a moment to attach.
    sleep 1.5
  else
    echo "no sample here: times only"
  fi
  timed status
  timed dock "$W1" left
  sleep 1
  timed dock "$W2" right
  sleep 1
  timed zoom "$W1"
  sleep 1
  timed show-all
  tries=0
  while [ ! -s "$ARBOR_OUT/sample-$run.txt" ] && [ "$tries" -lt 40 ] && command -v sample > /dev/null 2>&1; do
    sleep 0.5
    tries=$((tries + 1))
  done
  "$ARBOR_BIN/arborctl" stats > "$ARBOR_OUT/stats-$run.txt" 2>&1
  grep -E "stage|started" "$ARBOR_HOME/arbor.log" | tail -n 12
  arbor_log
  arbor_stop
done

step "the main thread while the first window was docked, run 1 (the heaviest branches)"
[ -s "$ARBOR_OUT/sample-1.txt" ] && sed -n '/^Call graph:/,/^Total number in stack/p' "$ARBOR_OUT/sample-1.txt" | head -n 150 | cut -c 1-200
exit 0
