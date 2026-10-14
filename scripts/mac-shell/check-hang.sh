#!/bin/bash
# An app that hangs, on real windows: does Arbor go on answering, does Quit end, does every window come back? Four sessions
# with two apps of test windows, one of which stops answering for 20 s: while the view moves, during a Quit, during a pause
# and during a start. Then two in which it is only slow, and takes 0.7 s over every move. Run it with
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-hang.sh        (or, on a Mac, bash scripts/mac-shell/check-hang.sh)
#
# What only a Mac can answer: how long a call to an app that does not answer really holds Arbor up, and whether a move that was
# sent to such an app is carried out when it wakes. It prints the seconds until every answer, beside what the same commands take
# while every app is awake, so that two runs on two commits can be laid side by side. Each session records a trace (mac-shell/traces).
# Safe on a person's Mac: it touches only its own test windows and changes no setting; no pointer, no keys. About five minutes.
source "$(dirname "$0")/lib.sh"

HANG=20
TRACES="$ARBOR_OUT/traces"
mkdir -p "$TRACES"

# Everything stays a real window on a small display, so a move of the view has five windows to move.
small_slots='{"minimumUsableWidth": 60, "minimumUsableHeight": 40, "gap": 6}'

# awkward_start: the app that will hang, with windows X1 and X2, afresh for each session. This shell holds its stdin
# (descriptor 8), and it exits when that closes.
AWKWARD_JOB=""
at_exit '[ -z "$AWKWARD_JOB" ] || kill_started $AWKWARD_JOB'
awkward_start() {
  local hello="" tries=0
  mkfifo "$ARBOR_SESSION_DIR/awkward-stdin"
  "${ARBOR_TEST_WINDOWS_2:-$ARBOR_BIN/ArborTestWindows}" --count 2 "$@" < "$ARBOR_SESSION_DIR/awkward-stdin" \
    > "$ARBOR_SESSION_DIR/awkward-hello" 2>> "$ARBOR_OUT/test-windows.log" &
  AWKWARD_JOB=$!
  started "$AWKWARD_JOB"
  exec 8> "$ARBOR_SESSION_DIR/awkward-stdin"
  while [ -z "$hello" ] && [ "$tries" -lt 100 ]; do
    sleep 0.1
    hello=$(head -n 1 "$ARBOR_SESSION_DIR/awkward-hello" 2>/dev/null)
    tries=$((tries + 1))
  done
  AWKWARD_PID=$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["pid"])' "$hello") || die "no second app: $hello"
  read -r X1 X2 <<< "$(python3 -c 'import json, sys; print(*json.loads(sys.argv[1])["windows"])' "$hello")"
  echo "the app that will hang: pid $AWKWARD_PID, windows $X1 $X2"
  # Where they are when Arbor first sees them.
  tell_awkward move "$X1" 120 120 420 300
  tell_awkward move "$X2" 200 180 420 300
  sleep 0.5
}

awkward_stop() {
  exec 8>&-
  ended "$AWKWARD_JOB" 30 || kill_started "$AWKWARD_JOB"
  AWKWARD_JOB=""
}

# tell_awkward <command…>: one line on its stdin (ArborTestWindows/Commands.swift). An app that has gone is not written to:
# SIGPIPE would take this script with it.
tell_awkward() {
  if ! kill -0 "$AWKWARD_JOB" 2>/dev/null; then
    echo "the second app has gone; it was not told: $*"
    return 1
  fi
  echo "> the second app: $*"
  echo "$*" >&8
}

# hang: it stops answering now. HUNG_AT is when.
hang() {
  tell_awkward hang "$HANG"
  sleep 0.5
  HUNG_AT=$(arbor_now)
}

# It is awake again, with a second or two to spare. One sleep: in a rehearsal only a sleep of a second or more moves the clock.
await_the_end_of_the_hang() {
  local left
  left=$(echo "$HANG + 2 - ($(arbor_now) - $HUNG_AT)" | bc | cut -d . -f 1)
  case "$left" in "" | -*) left=0 ;; esac
  sleep "$left"
  echo "the second app is awake again"
}

# timed <command…>: an arborctl command. Prints the seconds until its answer; TOOK has them.
timed() {
  local began
  began=$(arbor_now)
  "$ARBOR_BIN/arborctl" "$@" > /dev/null 2>&1
  TOOK=$(echo "$(arbor_now) - $began" | bc)
  echo "> $*: answered after $TOOK s"
}

at_most() { [ "$(echo "$1 <= $2" | bc)" = 1 ]; }
out_of_view() { ! is on_screen "$1"; }

# session <name>: Arbor on both apps' windows, recording.
session() {
  arbor_settings "$small_slots"
  ARBOR_EXTRA_PIDS=$AWKWARD_PID
  arbor_start 3
  ARBOR_EXTRA_PIDS=""
  SESSION_HOME=$ARBOR_HOME
  "$ARBOR_BIN/arborctl" trace on "$1" > /dev/null
}

# quit: asks Arbor to quit and says how long that took. The windows stay for what is to be seen of them afterwards.
quit() {
  local began
  began=$(arbor_now)
  "$ARBOR_BIN/arborctl" quit > /dev/null 2>&1
  check "Arbor is gone within 5 s of Quit" arbor_await_exit "$ARBOR_PID" 50
  echo "Quit took $(echo "$(arbor_now) - $began" | bc) s"
}

# The end of a session: both apps' windows close, and the traces come back without the date in their names.
session_ends() {
  local file base
  arbor_stop
  awkward_stop
  for file in "$SESSION_HOME"/traces/*.jsonl; do
    [ -f "$file" ] || continue
    base=${file##*/}
    cp "$file" "$TRACES/${base:18}"
  done
}

step "the Mac"
echo "macOS $(sw_vers -productVersion) on $(uname -m), $(sysctl -n hw.ncpu) cores; commit $(git -C "$ARBOR_ROOT" rev-parse --short HEAD)"
arbor_build

step "1. the view moves while an app hangs"
awkward_start
session hang-view
check "Arbor arranges the second app's windows too" eventually is managed "$X1"
ctl arrange
sleep 1
AWAKE=0
for command in "zoom $W1" back "zoom $W2" back; do
  # shellcheck disable=SC2086
  timed $command
  at_most "$TOOK" "$AWAKE" || AWAKE=$TOOK
  sleep 0.5
done
echo "with every app awake the slowest answer came after $AWAKE s"
hang
FIRST=""
LATER=0
for command in "zoom $W1" back "zoom $W2" back "zoom $W1" back; do
  # shellcheck disable=SC2086
  timed $command
  if [ -z "$FIRST" ]; then FIRST=$TOOK; else at_most "$TOOK" "$LATER" || LATER=$TOOK; fi
  sleep 0.5
done
echo "while the app hung: the first answer came after $FIRST s, the slowest of the later ones after $LATER s"
check "the first command is held up by 0.6 s at most" at_most "$FIRST" "$(echo "$AWAKE + 0.6" | bc)"
check "the later ones by a tenth at most" at_most "$LATER" "$(echo "$AWAKE + 0.1" | bc)"
for id in "$W1" "$W2" "$W3"; do
  check "window $id of the other app is in its slot meanwhile" eventually is in_slot "$id"
done
await_the_end_of_the_hang
for id in "$X1" "$X2"; do
  check "window $id follows into its slot once its app is awake" eventually is in_slot "$id"
done
summary
"$ARBOR_BIN/arborctl" stats > "$ARBOR_OUT/stats-hang-view.txt" 2>&1
quit
for id in "$X1" "$X2"; do
  check "window $id is on screen after quitting" eventually is on_screen "$id"
done
session_ends

step "2. Quit while an app hangs whose windows are out of view"
awkward_start
session hang-quit
check "Arbor arranges the second app's windows too" eventually is managed "$X1"
ctl arrange
sleep 1
ctl zoom "$W1"
sleep 1
check "the second app's windows are out of view" out_of_view "$X1"
hang
quit
for id in "$W1" "$W2" "$W3"; do
  check "window $id of the other app is on screen at once" is on_screen "$id"
done
echo "what the log says of the end:"
grep -iE "stopped|does not answer|could not|left word" "$SESSION_HOME/arbor.log" | tail -n 6
await_the_end_of_the_hang
for id in "$X1" "$X2"; do
  check "window $id comes back on screen once its app is awake, though Arbor is gone" eventually is on_screen "$id"
done
echo "the window server has them at: $(real_frame_of "$X1") and $(real_frame_of "$X2")"
# Seen, not inferred from a sleep: an app obeys its stdin only when its main thread runs again.
tell_awkward move "$X1" 120 120 420 300
check "the app is awake by then: told to, it moves window $X1 into view itself" eventually is on_screen "$X1"
session_ends

step "3. a pause while an app hangs whose windows are out of view"
awkward_start
session hang-pause
check "Arbor arranges the second app's windows too" eventually is managed "$X1"
ctl arrange
sleep 1
ctl zoom "$W1"
sleep 1
check "the second app's windows are out of view" out_of_view "$X1"
hang
timed pause
check "the pause is answered within 5 s" at_most "$TOOK" 5
for id in "$W1" "$W2" "$W3"; do
  check "window $id of the other app is on screen at once" is on_screen "$id"
done
await_the_end_of_the_hang
# During a pause Arbor tries again after 1, 2, 4, 8, 16 s and so on: after a hang of 20 s the next try is 31 s into the pause.
waited=0
until { is on_screen "$X1" && is on_screen "$X2"; } || [ "$waited" -ge 20 ]; do
  sleep 1
  waited=$((waited + 1))
done
echo "waited $waited s for them after the app woke"
for id in "$X1" "$X2"; do
  check "window $id comes back on screen once its app is awake: a pause promises every window in view" is on_screen "$id"
done
ctl resume
sleep 1
session_ends

step "4. Arbor starts while an app hangs"
awkward_start
hang
began=$(arbor_now)
session hang-start
STARTED=$(echo "$(arbor_now) - $began" | bc)
echo "Arbor had the other app's three windows $STARTED s after it was started"
check "that took 5 s at most" at_most "$STARTED" 5
timed status
check "and it answers at once" at_most "$TOOK" "$(echo "$AWAKE + 0.1" | bc)"
await_the_end_of_the_hang
for id in "$X1" "$X2"; do
  check "window $id is known to Arbor once its app is awake" eventually is managed "$id"
  check "and has not moved: nobody docked it" arbor_close "$(real_frame_of "$id")" "$([ "$id" = "$X1" ] && echo 120 120 420 300 || echo 200 180 420 300)"
done
summary
session_ends

# where_everything_is: each window's state and frame, the second app's first, without the numbers that differ from session to session.
where_everything_is() {
  local id
  for id in "$X1" "$X2" "$W1" "$W2" "$W3"; do
    if is tile "$id" > /dev/null 2>&1; then echo tile; else frame_of "$id"; fi
  done | tr '\n' ';'
}

# arranged <name> [slow]: five windows are arranged, of which the second app's first refuses to be narrower than 500 points, which no slot
# is. WHERE says how it ended.
arranged() {
  awkward_start --min-size 1:500x300
  session "$1"
  check "Arbor arranges the second app's windows too" eventually is managed "$X1"
  # Slow over each move, as an app is that lays its content out anew. (One that is busy in bursts does not make Arbor's moves late: a hosted
  # Mac showed that Arbor's main thread waits on a read to it, returns the moment it attends, and the moves that follow are all served then.)
  if [ "${2:-}" = slow ]; then
    tell_awkward sluggish 700
    sleep 1
  fi
  timed arrange
  sleep 12
  WHERE=$(where_everything_is)
  summary
}

step "5. what an arrangement comes to while every app is awake"
arranged awake-arrange
AWAKE_WHERE=$WHERE
session_ends

step "6. the same while the second app takes 0.7 s over every move, longer than Arbor waits"
arranged slow-arrange slow
check "arrange is held up by 0.6 s at most" at_most "$TOOK" "$(echo "$AWAKE + 0.6" | bc)"
echo "awake: $AWAKE_WHERE"
echo "slow:  $WHERE"
# Not to the point the same: awake, the refusal is learnt within `arrange`, which shares the width out afresh; slow, at a later layout.
for id in "$X1" "$X2" "$W1" "$W2" "$W3"; do
  check "window $id is in its slot: what the slow app made of the size was learnt late, and room was made" is in_slot "$id"
done
echo "what the log says of apps that went late:"
grep -c "took longer than" "$SESSION_HOME/arbor.log"
grep "took longer than" "$SESSION_HOME/arbor.log" | tail -n 3
# The fake Mac's Arbor is the controller on stand-ins: the line comes from the layer below.
[ -n "${ARBOR_REHEARSAL:-}" ] || check "the overrun is in the log, by bundle id" grep -q "took longer than" "$SESSION_HOME/arbor.log"
"$ARBOR_BIN/arborctl" stats > "$ARBOR_OUT/stats-slow-arrange.txt" 2>&1
tell_awkward sluggish 0
sleep 1
session_ends
