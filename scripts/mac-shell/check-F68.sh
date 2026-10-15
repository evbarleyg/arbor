#!/bin/bash
# F68 on real windows: Arbor knows how small apps go (docs/features/F68-how-small-apps-go.md).
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-F68.sh          on one of GitHub's Macs, from anywhere: about ten minutes
#   scripts/mac-shell/rehearse.sh scripts/mac-shell/check-F68.sh     on Linux: all but the real apps
#
# What is kept of an app is foresight, and no plan stands on it unasked: a window whose slot is just what is foreseen is asked for 40
# points less, where it stands. The stand-ins answer such a question at once and to the point. What only a Mac can settle:
#   1. Does a real window that is asked for less than it goes stay as it is, at once, in one answer? How long does the answer take?
#   2. Does the second day go without a window out of its way, where the first does not?
#   3. Where what is kept is too high, or too low: do things end as on the day it was right, and is it put right in the file?
#   4. The same with real apps, whose smallest sizes nobody chose: Notes and Terminal.
#
# Two test apps, each with a bundle id of its own and one window. One goes no narrower than 400 points, which is more than its share beside the
# other and the Desktop, so that room has to be made for it. Five days over one home: nothing known; what the first day left; the same made too
# high by hand, and the day after that; and too low. Each day begins with that window 800 points wide, docks it left and the other right, with a trace recorded, floats
# both, and quits. Reduce Motion is on, so that there is no stage and every move shows.
#
# What comes back: the roads in output.txt (every frame asked for and taken, command by command), traces/<day>.jsonl (no titles).
#
# Only on one of GitHub's Macs: it switches Reduce Motion, and opens Notes and Terminal and lets Arbor arrange them.
source "$(dirname "${BASH_SOURCE[0]}")/lib-apps.sh"
needs_throwaway_mac "switch Reduce Motion, and open Notes and Terminal and let Arbor arrange them"

READER="$ARBOR_ROOT/scripts/mac-shell/check-F68.py"
TRACES="$ARBOR_OUT/traces"
mkdir -p "$TRACES"
STATE="$ARBOR_HOME/state.json"
reader() { python3 "$READER" "$@"; }
kept() { reader kept "$STATE" "$1"; }
width_of() { real_frame_of "$1" | awk '{ printf "%d", $3 }'; }

# play <day> <left> <right>: with Arbor running. Leaves where both ended in ENDED.
play() {
  ctl trace on "$1"
  ctl dock "$2" left
  sleep 2
  ctl dock "$3" right
  sleep 2
  ctl trace off
  cp "$ARBOR_HOME"/traces/*-"$1".jsonl "$TRACES/$1.jsonl"
  ENDED="$(real_frame_of "$2") | $(real_frame_of "$3")"
  echo "ended: $ENDED"
  summary
  ctl float-all
  sleep 2
}

arbor_build
# GitHub's Macs come with it on; a rehearsal and whoever has switched it off do not.
macos_reduce_motion on
ARBOR_TEST_WINDOWS_ARGS="--min-size 1:400x300"
ARBOR_SECOND_APP=1
# Wider than anything that is kept of it: a window that is smaller already is not held to what is kept, and is asked nothing.
morning() {
  echo "move $W1 100 120 800 420" >&9
  sleep 1
}

step "the first day: nothing is known"
arbor_start 1
check "nothing is kept yet" test "$(kept "$ARBOR_TEST_BUNDLE")" = nothing
morning
play first "$W1" "$V1"
reader roads "$TRACES/first.jsonl" || echo "(strangers: this is what the store is for)"
check "the one that goes no narrower than 400 has that" test "$(echo "$ENDED" | awk '{ printf "%d", $3 }')" = 400
arbor_quit
check "and that is kept for its app" test "$(kept "$ARBOR_TEST_BUNDLE" | cut -d x -f 1)" = 400

step "the second day: what is kept is right"
arbor_relaunch
morning
play right "$W1" "$V1"
RIGHT=$ENDED
check "nobody goes out of its way" reader roads "$TRACES/right.jsonl"
check "it is asked once for 40 points less, where it stands, for no more than it has" reader question "$TRACES/right.jsonl" "$W1" w 360
check "and stays as it is" test "$(reader question "$TRACES/right.jsonl" "$W1" w 360 | grep -c "took [0-9.,-]* 400×")" = 1
arbor_quit
check "what is kept is as it was" test "$(kept "$ARBOR_TEST_BUNDLE" | cut -d x -f 1)" = 400

step "the third day: what is kept is too high"
reader keep "$STATE" "$ARBOR_TEST_BUNDLE" 460
arbor_relaunch
morning
play high "$W1" "$V1"
reader roads "$TRACES/high.jsonl" || echo "(the price of a store that is wrong: the window that gives way, once)"
check "it is asked for 40 points less than is kept, where it stands" reader question "$TRACES/high.jsonl" "$W1" w 420
check "things end as on the day it was right" test "$ENDED" = "$RIGHT"
arbor_quit
check "and what is kept has been put right" test "$(kept "$ARBOR_TEST_BUNDLE" | cut -d x -f 1)" = 400

step "the day after: what was too high costs nobody anything any more"
arbor_relaunch
morning
play after-high "$W1" "$V1"
check "nobody goes out of its way" reader roads "$TRACES/after-high.jsonl"
check "things end as on the day it was right" test "$ENDED" = "$RIGHT"
arbor_quit

step "the fifth day: what is kept is too low"
reader keep "$STATE" "$ARBOR_TEST_BUNDLE" 350
arbor_relaunch
morning
play low "$W1" "$V1"
reader roads "$TRACES/low.jsonl" || echo "(what not knowing costs)"
check "things end as on the day it was right" test "$ENDED" = "$RIGHT"
arbor_quit
check "and what is kept has been put right" test "$(kept "$ARBOR_TEST_BUNDLE" | cut -d x -f 1)" = 400
arbor_stop

if [ -n "${ARBOR_REHEARSAL:-}" ]; then
  echo "a rehearsal has no real apps"
  exit 0
fi

step "real apps: Notes and Terminal, two days"
apps_watchdog 420
apps_build
app_open com.apple.Notes
NOTES=$APP_WINDOW NOTES_PID=$APP_PID
[ -n "$NOTES" ] && { app_dismiss "$NOTES_PID" || echo "a sheet or dialog stayed in the way"; }
app_open com.apple.Terminal
TERMINAL=$APP_WINDOW TERMINAL_PID=$APP_PID
if [ -z "$NOTES" ] || [ -z "$TERMINAL" ]; then
  echo "Notes or Terminal opened no standard window: nothing to see"
  exit 0
fi
rm -f "$STATE"
arbor_start_apps "$NOTES_PID" "$TERMINAL_PID" || die "Arbor did not start"
play apps-first "$NOTES" "$TERMINAL"
reader roads "$TRACES/apps-first.jsonl" || echo "(strangers)"
FOUND=$(echo "$ENDED" | awk '{ printf "%d", $3 }')
arbor_stop
echo "kept of Notes: $(kept com.apple.Notes); it ended $FOUND wide"
if [ "$(kept com.apple.Notes)" = nothing ]; then
  echo "Notes refused nothing on this display: nothing was learned, and there is no second day to see"
  exit 0
fi
arbor_start_apps "$NOTES_PID" "$TERMINAL_PID" || die "Arbor did not start"
play apps-right "$NOTES" "$TERMINAL"
check "real apps, the second day: nobody goes out of its way" reader roads "$TRACES/apps-right.jsonl"
check "Notes is asked once for 40 points less, where it stands" reader question "$TRACES/apps-right.jsonl" "$NOTES" w $((FOUND - 40))
check "and ends as wide as the day before" test "$(echo "$ENDED" | awk '{ printf "%d", $3 }')" = "$FOUND"
arbor_stop
