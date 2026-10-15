#!/bin/bash
# What Arbor costs on real windows: how long commands take and where the time goes, with idle apps, a busy app and an
# app that hangs; then memory after a few hundred commands, and wakeups while idle. Run it with
#
#   scripts/mac-shell/run.sh scripts/mac-shell/perf.sh        (or, on a Mac, bash scripts/mac-shell/perf.sh)
#
# Every time comes from Arbor's own `stats` command (commands, layouts, and Accessibility calls by kind, by app and by
# thread). The tables are printed and kept as mac-shell/stats-*.txt.
# Safe on a person's Mac: it starts its own test windows and an Arbor limited to them, changes no setting, and only
# reads with footprint, heap, leaks and top (the first three only where developer mode is on: elsewhere macOS asks for a
# password in a dialog). It drags one gap with the real pointer. About five minutes.
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/lib-gestures.sh"

PERF_PIDS=""
PERF_LAST_PID=""
PERF_COUNT=0

quiet() { "$ARBOR_BIN/arborctl" "$@" > /dev/null 2>&1; }

# perf_start <processes> <windows each> [arguments for the last process…]
# Like lib.sh's arbor_start, with several processes of test windows: W1… are numbered process by process. The
# shell holds each one's stdin open (descriptors 3 to 8); they exit when it closes.
perf_start() {
  local processes=$1 each=$2 index=1 number=0 descriptor hello tries id pid extra
  shift 2
  PERF_PIDS=""
  ARBOR_WINDOW_IDS=""
  PERF_COUNT=$processes
  ARBOR_SESSION=$((ARBOR_SESSION + 1))
  while [ "$index" -le "$processes" ]; do
    descriptor=$((index + 2))
    extra=""
    [ "$index" -eq "$processes" ] && extra="$*"
    mkfifo "$ARBOR_SESSION_DIR/stdin$index"
    # shellcheck disable=SC2086
    "$ARBOR_BIN/ArborTestWindows" --count "$each" $extra \
      < "$ARBOR_SESSION_DIR/stdin$index" > "$ARBOR_SESSION_DIR/hello$index" 2>> "$ARBOR_OUT/test-windows.log" \
      3>&- 4>&- 5>&- 6>&- 7>&- 8>&- &
    started $!
    eval "exec $descriptor> \"$ARBOR_SESSION_DIR/stdin$index\""
    hello=""
    tries=0
    while [ -z "$hello" ] && [ "$tries" -lt 100 ]; do
      sleep 0.1
      hello=$(head -n 1 "$ARBOR_SESSION_DIR/hello$index" 2>/dev/null)
      tries=$((tries + 1))
    done
    pid=$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["pid"])' "$hello" 2>/dev/null) \
      || die "ArborTestWindows $index did not report its windows (got: $hello)"
    PERF_PIDS="$PERF_PIDS${PERF_PIDS:+,}$pid"
    PERF_LAST_PID=$pid
    for id in $(python3 -c 'import json, sys; print(*json.loads(sys.argv[1])["windows"])' "$hello"); do
      number=$((number + 1))
      eval "W$number=$id"
      ARBOR_WINDOW_IDS="$ARBOR_WINDOW_IDS $id"
      # Twelve windows of one process open in a row that runs off a small screen, and that is where a quit puts them back.
      echo "move $id $((40 + number % 6 * 40)) $((60 + number % 6 * 30)) 480 352" >&"$descriptor"
    done
    # Before Arbor looks: a window that moves later has been moved by somebody.
    tries=0
    until [ "$(real_frame_of "$id" | cut -d ' ' -f 1)" = "$((40 + number % 6 * 40))" ] || [ "$tries" -ge 50 ]; do
      sleep 0.1
      tries=$((tries + 1))
    done
    index=$((index + 1))
  done

  # No debug log: it is not what people run.
  env ARBOR_ONLY_PIDS="$PERF_PIDS" ARBOR_NO_PROMPT=1 ARBOR_NO_HOTKEYS="${PERF_NO_HOTKEYS:-1}" ARBOR_NO_STATUS_ITEM=1 ARBOR_NO_WATCHDOG=1 \
    "$ARBOR_BIN/Arbor" > "$ARBOR_OUT/$(arbor_log_name arbor-stderr)" 2>&1 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- &
  ARBOR_PID=$!
  started "$ARBOR_PID"
  tries=0
  until "$ARBOR_BIN/arborctl" state 2>/dev/null | python3 "$ARBOR_STATE_PY" ready "$number" 2>/dev/null; do
    [ "$tries" -ge 100 ] && die "Arbor did not start managing the $number test windows"
    sleep 0.2
    tries=$((tries + 1))
  done
  echo "session $ARBOR_SESSION: Arbor pid $ARBOR_PID, $processes process(es) $PERF_PIDS, windows$ARBOR_WINDOW_IDS"
}

perf_stop() {
  local index=1
  arbor_stop
  while [ "$index" -le "$PERF_COUNT" ]; do
    eval "exec $((index + 2))>&-"
    index=$((index + 1))
  done
  PERF_COUNT=0
  sleep 0.5
}

# table <file name> <title>: prints the statistics gathered since the last reset, and keeps them.
table() {
  echo
  echo "-- $2"
  "$ARBOR_BIN/arborctl" stats | tee "$ARBOR_OUT/stats-$1.txt"
}

# camera <times>: frame one window of twelve and go back, which moves every window each time.
camera() {
  local turn=0
  quiet stats reset
  while [ "$turn" -lt "$1" ]; do
    quiet zoom "$W1"
    quiet back
    turn=$((turn + 1))
  done
}

# Everything stays a real window on the runner's small screen, so a camera move has twelve windows to move.
small_slots='{"minimumUsableWidth": 60, "minimumUsableHeight": 40, "gap": 6}'

step "the Mac"
echo "macOS $(sw_vers -productVersion) on $(uname -m), $(sysctl -n hw.ncpu) cores"
arbor_build

step "twelve windows of one app"
arbor_settings "$small_slots"
perf_start 1 12
quiet arrange
camera 10
table "1x12-camera" "one app: 10 x (zoom, back)"
quiet stats reset
turn=0
while [ "$turn" -lt 10 ]; do
  quiet resize "$W1" right 8
  quiet resize "$W1" right -8
  turn=$((turn + 1))
done
table "1x12-seam" "one app: 20 x resize by 8 points, as a seam drag does"
quiet stats reset
turn=0
while [ "$turn" -lt 10 ]; do
  quiet show-all
  turn=$((turn + 1))
done
table "1x12-nothing" "one app: 10 x show-all when everything shows already"

step "panels that were put away and handed out again still work"
# Seam handles are thin. The focus ring, which is there all the time, is as large as its window.
on_screen_overlays() { overlays | awk '$8 == "on" && ($6 <= 24 || $7 <= 24)' | wc -l | tr -d ' '; }
before=$(on_screen_overlays)
quiet zoom "$W1"
sleep 0.3
check "no handle is on screen while one window is framed" test "$(on_screen_overlays)" = 0
quiet back
sleep 0.3
echo "handles on screen: $before before, $(on_screen_overlays) after zoom and back"
check "all the handles are back" test "$(on_screen_overlays)" = "$before"
read -r _ _ width_before _ <<< "$(frame_of "$W1")"
read -r seam_x seam_y <<< "$(seam_right_of "$W1")"
drag "$seam_x" "$seam_y" "$((seam_x + 40))" "$seam_y"
sleep 0.5
read -r _ _ width_after _ <<< "$(frame_of "$W1")"
echo "the first window was $width_before wide and is $width_after wide after dragging the gap on its right by 40"
check "a handle that was handed out again takes a drag" test "$width_after" -ge "$((width_before + 30))"
perf_stop

step "twelve windows of four apps"
arbor_settings "$small_slots"
perf_start 4 3
quiet arrange
camera 10
table "4x3-camera" "four apps: 10 x (zoom, back)"
perf_stop

# tell_last <command…>: one line on the stdin of the last process of test windows (ArborTestWindows/Commands.swift).
# Writing to a pipe nobody reads any more would end this shell.
tell_last() {
  kill -0 "$PERF_LAST_PID" 2>/dev/null || return 1
  eval "echo \"\$*\" >&$((PERF_COUNT + 2))"
}

all_in_view() {
  local id
  for id in $ARBOR_WINDOW_IDS; do
    is on_screen "$id" || return 1
  done
}

for attention in 30 2; do
  step "twelve windows of four apps, one of them busy 300 ms at a time with $attention ms of attention between"
  arbor_settings "$small_slots"
  perf_start 4 3
  quiet arrange
  tell_last busy 300 "$attention"
  sleep 2
  camera 3
  busy_ended=$(arbor_now)
  until all_in_view || [ "$(echo "$(arbor_now) - $busy_ended > 20" | bc)" = 1 ]; do sleep 0.1; done
  echo "every window was in view $(echo "$(arbor_now) - $busy_ended" | bc) s after the last command"
  table "busy-$attention-camera" "one app busy (attention $attention ms): 3 x (zoom, back)"
  # The window that grows belongs to the busy app: its lane is still at work when the focus is asked for.
  quiet zoom "$W12"
  check "the keyboard follows into the busy app's window" eventually is focused "$W12"
  quiet back
  tell_last busy 0
  for id in $ARBOR_WINDOW_IDS; do
    check "window $id ended up in view (busy app)" eventually is on_screen "$id"
  done
  perf_stop
done

step "twelve windows of four apps, one of them hangs for 20 s"
arbor_settings "$small_slots"
perf_start 4 3
quiet arrange
sleep 1
quiet stats reset
tell_last hang 20
sleep 0.5
hang_started=$(arbor_now)
for command in "zoom $W1" back "zoom $W1" back; do
  started=$(arbor_now)
  # shellcheck disable=SC2086
  quiet $command
  echo "$command: the reply took $(echo "$(arbor_now) - $started" | bc) s"
done
table "hang-camera" "one app hung: zoom, back, zoom, back"
# When the app is back, 20 s after it was told to hang, its windows follow.
until all_in_view || [ "$(echo "$(arbor_now) - $hang_started > 45" | bc)" = 1 ]; do sleep 0.1; done
echo "every window was in view $(echo "$(arbor_now) - $hang_started" | bc) s after the hang began"
for id in $ARBOR_WINDOW_IDS; do
  check "window $id ended up in view (after the hang)" eventually is on_screen "$id"
done
summary
perf_stop

# soak: 400 commands with tiles and seams coming and going. (A rehearsal replays its whole history at every command:
# PERF_SOAK_TURNS=2 scripts/mac-shell/rehearse.sh scripts/mac-shell/perf.sh)
soak() {
  local turn=0
  while [ "$turn" -lt "${PERF_SOAK_TURNS:-50}" ]; do
    quiet zoom "$W1"
    quiet back
    quiet zoom "$W5"
    quiet show-all
    quiet float "$W2"
    quiet dock "$W2" left
    quiet resize "$W3" right 10
    quiet desktop
    turn=$((turn + 1))
  done
  quiet show-all
}

# limited <seconds> <command…>: a tool that asks for permission in a dialog must not hold the script up.
limited() { limit "$@"; }
# Nor put the dialog on somebody's screen: without developer mode macOS asks for a password before one process may read another.
may_inspect() { on_throwaway_mac || DevToolsSecurity -status 2>&1 | grep -q "enabled"; }

memory() {
  may_inspect || { echo "$1: skipped: developer mode is off, so macOS would ask somebody for a password"; return 0; }
  echo "$1: $(limited 30 footprint "$ARBOR_PID" 2>&1 | grep -E "phys_footprint:" | tr -s ' ')"
  limited 60 heap "$ARBOR_PID" 2>/dev/null | grep -E " (TilePanel|SeamPanel|OverlayPanel|AXObserver|__NSCFTimer) " | awk '{ printf "  %s %s", $1, $4 } END { print "" }'
}

# idle <title>: what happens while nothing happens. In delta mode each sample counts what happened since the one before;
# the first is since launch and is left out.
idle() {
  sleep 3
  quiet stats reset
  echo "$1: idle wakeups and context switches in each of two spans of 10 s"
  top -l 3 -s 10 -c d -pid "$ARBOR_PID" -stats pid,command,cpu,idlew,csw,threads,power 2>&1 | grep -E "^PID|^ *$ARBOR_PID" | sed -n '1p;4p;6p'
  "$ARBOR_BIN/arborctl" stats | tail -n +2
}

step "memory: three times 400 commands"
perf_start 4 3
quiet arrange
sleep 1
memory "at the start"
quiet stats reset
soak
table soak "400 commands"
memory "after 400 commands"
soak
memory "after 800 commands"
soak
memory "after 1200 commands"
may_inspect && limited 120 leaks "$ARBOR_PID" > "$ARBOR_OUT/leaks.txt" 2>&1
grep -E "leaks for" "$ARBOR_OUT/leaks.txt" 2>/dev/null
# Whose they are: the first line of each leak's description, counted.
grep -E "ROOT (LEAK|CYCLE)" "$ARBOR_OUT/leaks.txt" 2>/dev/null | grep -v "^ \{9,\}" | sed -E 's/0x[0-9a-f]+//g; s/^ *[0-9]+ \([^)]*\) //' | sort | uniq -c | sort -rn | head -n 10

step "energy"
idle "without shortcuts and event taps"
perf_stop
PERF_NO_HOTKEYS=0
arbor_settings "{$ARBOR_GESTURES_ON}"
perf_start 4 3
quiet arrange
idle "with shortcuts and event taps (and their permission check once a second)"
perf_stop
