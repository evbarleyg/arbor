#!/bin/bash
# `arborctl watch` on a real Mac (docs/features/F24-events.md): what Linux cannot show.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/watch.sh
#
#   1. The real app on real windows: events for commands, for real clicks and for switching between two
#      apps; titles only on request; `quitting` and exit code 0 on quit; exit code 3 after kill -9.
#   2. Darwin's sockets: the real arborctl against arbor-sim --serve (scripts/watch-smoke.sh), and the socket tests.
#
# The end-to-end runner's three steps on `watch` are `make e2e`'s: it starts an Arbor with its watchdog and takes no signal, so one
# that this script's time limit ended would leave an Arbor behind.
#
# The event streams come back as mac-shell/watch-*.jsonl.
# A build, a build of the tests and the tests do not fit into the usual quarter of an hour.
ARBOR_TIME_LIMIT=1500
source "$(dirname "$0")/lib.sh"
arbor_build

heard() { grep -q -- "$2" "$ARBOR_OUT/$1.jsonl"; }
never_heard() { ! heard "$@"; }
# The windows of the focus events in a stream from line $2 on, as one line of ids.
focus_sequence() {
  tail -n "+$2" "$ARBOR_OUT/$1.jsonl" | python3 -c '
import json, sys
events = [json.loads(line) for line in sys.stdin]
print(*[event.get("window", "none") for event in events if event["event"] == "focus"])'
}
lines_of() { wc -l < "$ARBOR_OUT/$1.jsonl" | tr -d " "; }
# `check` silences what it runs; descriptor 3 still reaches the output.
exec 3>&1
same() { [ "$1" = "$2" ] || { echo "    got '$1', expected '$2'" >&3; return 1; }; }
# Sets $code to the exit code of a background process, which gets five seconds to end.
exit_code_of() {
  if arbor_await_exit "$1" 50; then
    wait "$1"
    code=$?
  else
    kill -9 "$1"
    code="none: it was still running"
  fi
}

step "two apps' windows, and two watchers"
# It lives until its stdin closes. `sleep` holds the other end, so that no process started later inherits it
# (the first run of this script hung for that reason); the script ends it with `kill`.
mkfifo "$ARBOR_SESSION_DIR/stdin2"
sleep 600 > "$ARBOR_SESSION_DIR/stdin2" &
holder=$!
# On record, so that however the script ends no test window stays on the screen for `sleep`'s ten minutes.
started "$holder"
"$ARBOR_BIN/ArborTestWindows" --count 1 < "$ARBOR_SESSION_DIR/stdin2" > "$ARBOR_SESSION_DIR/hello2" &
other=$!
started "$other"
eventually test -s "$ARBOR_SESSION_DIR/hello2" || die "the second ArborTestWindows did not report its window"
X1=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["windows"][0])' "$ARBOR_SESSION_DIR/hello2")
ARBOR_EXTRA_PIDS=$other arbor_start 2
check "Arbor arranges the other app's window too" eventually is managed "$X1"

"$ARBOR_BIN/arborctl" watch > "$ARBOR_OUT/watch-all.jsonl" 2> "$ARBOR_OUT/watch-all.err" &
all=$!
started "$all"
"$ARBOR_BIN/arborctl" watch focus --titles > "$ARBOR_OUT/watch-focus.jsonl" 2> "$ARBOR_OUT/watch-focus.err" &
focus=$!
started "$focus"
check "hello arrives at once" eventually heard watch-all '^{"event":"hello","protocol":1,"snapshot":{"accessibility":true,'
check "hello lists the windows" heard watch-all "\"docked\":false,\"state\":\"in-view\",\"window\":$X1}"

step "commands"
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$X1" beside "$W2" bottom
check "docking is reported" eventually heard watch-all "\"change\":\"docked\",.*\"window\":$X1}"
check "and the layout, with three windows in view" eventually heard watch-all '^{"event":"layout",.*"dockedCount":3,"floatingCount":0,'
ctl zoom "$W1"
check "framing a window is reported" eventually heard watch-all "\"kind\":\"window\",.*\"outOfView\":2,\"windows\":\\[$W1\\]}"
check "and the others as out of view" eventually heard watch-all "\"change\":\"state\",.*\"state\":\"out-of-view\",\"window\":$X1}"
ctl save-view 3
check "a saved view shows its number" eventually heard watch-all "\"kind\":\"window\",.*\"savedView\":3,\"windows\":\\[$W1\\]}"
ctl show-all
check "and Show Everything" eventually heard watch-all "\"canGoBack\":true,.*\"kind\":\"everything\",.*\"windows\":\\[$W1,$W2,$X1\\]}"
before=$(lines_of watch-all)
ctl relayout
ctl show-all
sleep 0.5
check "commands that change nothing send nothing" same "$(lines_of watch-all)" "$before"
summary

step "real clicks, within one app and between two"
# shellcheck disable=SC2046
click $(center_of "$X1")
sleep 0.6
start=$(($(lines_of watch-focus) + 1))
# shellcheck disable=SC2046
for window in "$W1" "$W2" "$W1" "$X1" "$W1" "$X1" "$W2"; do
  click $(center_of "$window")
  sleep 0.6
done
echo "focus events: $(focus_sequence watch-focus "$start")"
check "every click on another window is reported, once" \
  same "$(focus_sequence watch-focus "$start")" "$W1 $W2 $W1 $X1 $W1 $X1 $W2"
check "titles reach the watcher that asked for them" heard watch-focus '"title":"Arbor Test 1"'
check "and nobody else" never_heard watch-all 'Arbor Test'
check "nor the log" test -z "$(grep 'Arbor Test' "$ARBOR_HOME/arbor.log")"

step "a window closes"
kill_started "$holder" "$other"
check "its closing is reported, with its app" eventually heard watch-all "\"change\":\"closed\",.*\"window\":$X1}"

step "a pause"
ctl pause
check "paused is reported" eventually heard watch-all '^{"event":"paused"}'
check "and the watchers stay" kill -0 "$all" "$focus"
ctl resume
check "resumed is reported, and the state after it" eventually heard watch-all '^{"event":"resumed"}'
check "with the arrangement as it was" eventually heard watch-all "\"kind\":\"everything\",.*\"windows\":\\[$W1,$W2\\]}"
check "and the windows as adopted, not opened" eventually heard watch-all "\"change\":\"adopted\",.*\"window\":$W1}"

step "quitting"
check "both are still watching" kill -0 "$all" "$focus"
arbor_stop
exit_code_of "$all"
check "watch exits with 0" same "$code" 0
check "after quitting" same "$(tail -n 1 "$ARBOR_OUT/watch-all.jsonl")" '{"event":"quitting"}'
exit_code_of "$focus"
check "so does the filtered one" same "$code" 0
check "after quitting, which no filter holds back" same "$(tail -n 1 "$ARBOR_OUT/watch-focus.jsonl")" '{"event":"quitting"}'
check "neither complained" test ! -s "$ARBOR_OUT/watch-all.err" -a ! -s "$ARBOR_OUT/watch-focus.err"
echo "--- watch-all.jsonl, without hello"
tail -n +2 "$ARBOR_OUT/watch-all.jsonl" | cut -c 1-220

step "Arbor is killed"
arbor_start 2
"$ARBOR_BIN/arborctl" watch view > "$ARBOR_OUT/watch-killed.jsonl" 2> "$ARBOR_OUT/watch-killed.err" &
killed=$!
started "$killed"
check "hello" eventually heard watch-killed '^{"event":"hello"'
kill -9 "$ARBOR_PID"
exit_code_of "$killed"
check "watch exits with 3" same "$code" 3
check "and says why" grep -q "went away" "$ARBOR_OUT/watch-killed.err"
limit 10 "$ARBOR_BIN/arborctl" watch > /dev/null 2>&1
check "and with 2 while Arbor is not running" same $? 2
arbor_stop

step "Darwin's sockets: the real arborctl against the simulator"
./scripts/watch-smoke.sh
check "scripts/watch-smoke.sh passes" same $? 0

step "the socket, feed and event tests"
swift test --filter 'ControlServerTests|ArborctlWatchTests|EventFeedTests|LineBufferTests|OutboundQueueTests|WatchLineTests|ArborEvent|WatchCommandTests' \
  > "$ARBOR_OUT/test.log" 2>&1
check "swift test passes" same $? 0
grep -E "error:|✘|Test run with" "$ARBOR_OUT/test.log" | head -n 40
