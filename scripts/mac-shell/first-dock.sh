#!/bin/bash
# The first dock after a start is as quick as the next. Real apps, Arbor's shipped settings, the debug build and the release build.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/first-dock.sh          on one of GitHub's Macs, from anywhere: about a quarter of an hour
#
# On a hosted Mac the first dock of a day, with nine apps' windows on screen, came to rest 3.1 s after the key: for 1.9 s of them nothing
# moved at all, and Arbor's log had nothing to say about them but "stage up" at their end. The second dock waited 5 ms at the same place.
# A first run of this script found what it was: "the stage kept the windows waiting 4807 ms: its panel 14, 8 costumes 4729, the desktop 3, going
# up 61". macOS draws an app's icon at a size the first time anybody asks, and keeps it: the same eight took 27 ms a minute later, in another
# run of Arbor. So the cost is the Mac's, once, and a hosted Mac is always one that has not paid it: ITS FIRST SESSION IS THE ONE THAT COUNTS.
#
# The questions only a Mac can answer:
#   1. On a Mac that has drawn none of the icons: does the stage keep the first dock waiting? (It takes what covers are there and never waits
#      for one: UI/Wardrobe.swift.) How long do the covers take on their own thread, and does Arbor answer meanwhile?
#   2. What does getting ready ahead of time (Controller+Rehearsal.swift) save beyond that? ARBOR_NO_REHEARSAL=1 is the control: its first motion
#      makes its panel while the windows wait, and its cards are plain.
#   3. How much of every number is the debug build's? The same in the release build.
#
# Four sessions of Arbor over the same open apps, each a start, a rest, three docks, a frame and Show Everything, with a trace recorded: debug,
# debug without the rehearsal, then the release build with and without. first-dock.py reads each session's log and trace into a table.
#
# What comes back: the tables in output.txt, arbor-<n>.log, traces/<session>.jsonl (no titles: docs/TRACES.md).
#
# Only on GitHub's Macs: it opens real apps, lets Arbor arrange every window there is, and switches Reduce Motion and the display's size.
source "$(dirname "${BASH_SOURCE[0]}")/lib-apps.sh"
needs_throwaway_mac "open nine real apps, let Arbor arrange every window on the Mac, and switch Reduce Motion and the display's size"

READER="$ARBOR_ROOT/scripts/mac-shell/first-dock.py"
TRACES="$ARBOR_OUT/traces"
mkdir -p "$TRACES"
CAST=""

# meet <bundle id> [file…]: opens it; its first standard window joins the cast.
meet() {
  if APP_WAIT=25 app_open "$@" && [ -n "$APP_WINDOW" ]; then
    app_dismiss "$APP_PID" || echo "a sheet or dialog stayed in the way"
    CAST="$CAST $APP_WINDOW"
  else
    echo "$1 opened no standard window: on without it"
  fi
}

now() { perl -MTime::HiRes=time -e 'printf "%d", time * 1000'; }

# session <name> <folder of the build> [NAME=value…]
session() {
  local name=$1 bin=$2 log asked
  shift 2
  step "session $name"
  ARBOR_BIN=$bin
  arbor_start_apps all "$@" || die "Arbor did not start"
  # While things are got ready: whatever keeps the main thread keeps this answer.
  for _ in 1 2 3 4 5 6; do
    asked=$(now)
    "$ARBOR_BIN/arborctl" status > /dev/null 2>&1
    echo "  status answered in $(($(now) - asked)) ms"
    sleep 0.3
  done
  # A person who starts Arbor does not dock in the same second.
  sleep 4
  echo "  processor time since the start (minutes:seconds): $(ps -o time= -p "$ARBOR_PID" | tr -d ' ')"
  ctl trace on "$name"
  # shellcheck disable=SC2086
  set -- $CAST
  ctl dock "$1" left
  sleep 2
  ctl dock "$2" right
  sleep 2
  ctl dock "$3" right
  sleep 2
  ctl zoom "$1"
  sleep 2
  ctl show-all
  sleep 2
  ctl trace off
  cp "$ARBOR_HOME"/traces/*-"$name".jsonl "$TRACES/$name.jsonl"
  log="$ARBOR_OUT/first-dock-$name.log"
  cp "$ARBOR_HOME/arbor.log" "$log"
  echo
  python3 "$READER" table "$log" "$TRACES/$name.jsonl"
  echo
  echo "got ready ahead of time:"
  python3 "$READER" ready "$log"
  grep -E "the stage kept the windows waiting" "$log" | cut -c 1-200 | head -n 3
  FIRST_WAIT=$(python3 "$READER" wait "$log" 1)
  arbor_stop
  sleep 2
}

apps_watchdog 1050
step "the Mac"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m), $(sysctl -n hw.ncpu) cores"
apps_build
DEBUG=$ARBOR_BIN
display_mode 1600x900 1440x900 1680x1050 1920x1080
# GitHub's Macs come with Reduce Motion on. A person's Mac does not, and with it on there is no stage.
macos_reduce_motion off
apps_scratch

step "the apps are open already"
meet com.apple.finder "$APPS_SCRATCH/grove"
meet com.apple.Safari "$APPS_SCRATCH/page.html"
meet com.apple.TextEdit "$APPS_SCRATCH/oak.txt"
meet com.apple.Terminal
meet com.apple.Notes
meet com.apple.iCal
meet com.apple.systempreferences
meet com.apple.Preview "$APPS_SCRATCH/leaf.png"
meet com.apple.mail
sleep 3
echo "the cast:$CAST"
# shellcheck disable=SC2086
set -- $CAST
[ $# -ge 5 ] || die "only $# apps opened a window: nothing to measure"

# The Mac has drawn no icon yet.
session debug "$DEBUG"
check "debug, on a Mac that has drawn none of the icons: the stage keeps the first dock waiting under 100 ms" test "${FIRST_WAIT:-9999}" -lt 100
# Of the first motion alone: the later ones have theirs in any case.
first_motion() { grep -m 1 "the stage kept the windows waiting" "$1"; }
check "and every card has its colour and icon" eval 'first_motion "$ARBOR_OUT/first-dock-debug.log" | grep -q "(0 not ready)"'
session debug-unrehearsed "$DEBUG" ARBOR_NO_REHEARSAL=1
check "with nothing got ready it waits for no icon either (${FIRST_WAIT:-?} ms)" test "${FIRST_WAIT:-9999}" -lt 200

# Only now, with the debug build's numbers safe: the script has twenty minutes in all. (153 s, the first time it was timed.)
# Only what is started here, and in a folder of its own: the debug build stays what the next script of a list finds.
step "the release build"
began=$SECONDS
if bounded 420 swift build -c release --product Arbor > "$ARBOR_OUT/build-release.log" 2>&1 \
  && bounded 120 swift build -c release --product arborctl >> "$ARBOR_OUT/build-release.log" 2>&1; then
  echo "built in $((SECONDS - began))s"
  session release "$ARBOR_ROOT/.build/release"
  check "release: the stage keeps the first dock waiting under 100 ms" test "${FIRST_WAIT:-9999}" -lt 100
  session release-unrehearsed "$ARBOR_ROOT/.build/release" ARBOR_NO_REHEARSAL=1
else
  tail -n 20 "$ARBOR_OUT/build-release.log"
  echo "no release build after $((SECONDS - began))s: the debug build's numbers are all there is"
fi
ARBOR_BIN=$DEBUG
