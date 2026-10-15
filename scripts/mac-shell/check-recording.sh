#!/bin/bash
# Whether a run on a hosted Mac records itself, and brings back what tells what happened (docs/TRACES.md, "Every run on a hosted Mac is recorded").
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-recording.sh
#
# What only a Mac can say:
#   - that the real app writes the traces lib.sh asks for, one from every step, and that they replay;
#   - that a real trace holds what the app hears of macOS by itself: an app coming forward, a press that an event tap saw;
#   - that a word to the recorder leaves a real peek, with a real key held, alone, and that no trace begins in the middle of a real drag;
#   - what a word to the recorder costs, which every step and every check of every script now pays;
#   - that a check that fails leaves a real picture behind.
#
# On a person's Mac nothing is recorded and no picture of the whole screen is taken, so there is nothing to check: it declines.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "record which apps are open and take pictures of the whole screen"

SIM="$ARBOR_ROOT/.build/debug/arbor-sim"
not() { ! "$@"; }
recorder_says() { "$ARBOR_BIN/arborctl" trace status | grep -q "$1"; }
holds() { grep -l "$1" "$ARBOR_OUT"/traces/check-recording-*.jsonl > /dev/null 2>&1; }

arbor_build

step "a second app, to switch to"
mkfifo "$ARBOR_SESSION_DIR/stdin2"
"${ARBOR_TEST_WINDOWS_2:-$ARBOR_BIN/ArborTestWindows}" --count 1 --regular < "$ARBOR_SESSION_DIR/stdin2" > "$ARBOR_SESSION_DIR/hello2" 2>> "$ARBOR_OUT/test-windows.log" &
SECOND=$!
started "$SECOND"
at_exit "kill_started $SECOND"
exec 8> "$ARBOR_SESSION_DIR/stdin2"
hello2="" tries=0
while [ -z "$hello2" ] && [ "$tries" -lt 100 ]; do
  sleep 0.1
  hello2=$(head -n 1 "$ARBOR_SESSION_DIR/hello2" 2>/dev/null)
  tries=$((tries + 1))
done
P2=$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["pid"])' "$hello2") || die "no second process: $hello2"
X1=$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["windows"][0])' "$hello2")
ARBOR_EXTRA_PIDS=$P2
ARBOR_TEST_WINDOWS_ARGS="--regular"
# With shortcuts and event taps, which are what sees a press and a key.
arbor_start 3 ARBOR_NO_HOTKEYS=0
check "recording began with the session" recorder_says "^recording .*check-recording-1-01"
sleep 3

step "a dock, a click, a drag"
check "the step began the next trace" recorder_says "^recording .*check-recording-1-02"
# [W1 | Desktop with W3 | (W2 / X1)]: no window covers another, so a press lands where it is meant to.
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$X1" beside "$W2" bottom
# shellcheck disable=SC2046
click $(center_of "$W2")
check "the window that was clicked has the keyboard" eventually is focused "$W2"
# shellcheck disable=SC2046
drag $(titlebar_of "$W3") 512 500
sleep 1

step "the other app comes forward, and the first again"
# shellcheck disable=SC2046
click $(center_of "$X1")
check "the other app's window has the keyboard" eventually is focused "$X1"
# shellcheck disable=SC2046
click $(center_of "$W1")
check "the first app's window has it again" eventually is focused "$W1"
sleep 1

step "no trace begins in the middle of a drag"
before=$("$ARBOR_BIN/arborctl" trace status | sed 's/: .*//')
# shellcheck disable=SC2046
drag $(titlebar_of "$W3") 512 300 --no-release
step "with the window in the hand"
check "the trace that was running goes on" test "$("$ARBOR_BIN/arborctl" trace status | sed 's/: .*//')" = "$before"
release
sleep 1

step "a word to the recorder leaves a peek alone"
ctl zoom "$W1"
# shellcheck disable=SC2046
click $(center_of "$W1")
key ctrl+opt+space --down
sleep 1
peeking() { grep -c "peek: held" "$ARBOR_HOME/arbor.log"; }
ended() { grep -c "peek: the key came up\|peek: interrupted\|peek: ended" "$ARBOR_HOME/arbor.log"; }
held=$(peeking) over=$(ended)
check "the key is held and Arbor peeks" test "$held" -gt 0
check "a remark is taken" "$ARBOR_BIN/arborctl" trace note "in the middle of a peek"
check "and the peek goes on" test "$(ended)" = "$over"
key ctrl+opt+space --up
sleep 1
ctl show-all

step "what a word to the recorder costs"
began=$(arbor_now)
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do arbor_trace_note "a remark"; done
echo "a remark: $(echo "($(arbor_now) - $began) * 50" | bc) ms"
began=$(arbor_now)
for _ in 1 2 3 4 5 6 7 8 9 10; do arbor_trace_next "the next trace"; done
echo "the next trace: $(echo "($(arbor_now) - $began) * 100" | bc) ms"

step "a check that fails leaves the moment behind"
# In a shell of its own, so that it does not count against this script.
moment=fail-$ARBOR_NAME-$((ARBOR_FAILED + 1))
(check "this one fails on purpose" false) | sed 's/✘/(✘)/'
check "the picture is there" test -s "$ARBOR_OUT/$moment.png"

arbor_stop

step "what came back"
ls -l "$ARBOR_OUT/traces" | awk 'NR > 1 { print "  " $5, $NF }'
check "a trace for every step of the session" test "$(ls "$ARBOR_OUT"/traces/check-recording-1-*.jsonl | wc -l | tr -d ' ')" -ge 8
check "Arbor's log is there, at debug level" grep -q " DEBUG " "$ARBOR_OUT/arbor-$ARBOR_NAME.log"
check "a trace holds an app coming forward" holds '"event":"applicationActivated"'
check "a trace holds a press" holds '"event":"pointerPressed"'
check "a trace holds the key that was held" holds '"event":"shortcut"'
check "headings are remarks" holds '"note":"the other app comes forward, and the first again"'
check "so are checks" holds '"note":"✔ the other app'
check "the last one ends with the quit" grep -q '"command":"quit"' "$(ls "$ARBOR_OUT"/traces/check-recording-1-*.jsonl | tail -n 1)"
# In a home of its own: arbor-sim keeps a log as Arbor does.
scratch_dir replays
problems=0
for trace in "$ARBOR_OUT"/traces/check-recording-1-*.jsonl; do
  if ! said=$(ARBOR_HOME="$SCRATCH_DIR" "$SIM" replay "$trace" 2>&1); then
    problems=$((problems + 1))
    echo "  $(basename "$trace"): $(echo "$said" | tail -n 4 | tr '\n' ' ')"
  fi
done
check "every one of them replays without a problem" test "$problems" -eq 0
check "the log that came back is still the session's own" grep -q "trace check-recording-1-01: recording to" "$ARBOR_OUT/arbor-$ARBOR_NAME.log"
check "no title is in any of them" python3 "$ARBOR_ROOT/scripts/trace-check.py" "$ARBOR_OUT"/traces/check-recording-1-*.jsonl
