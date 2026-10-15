#!/bin/bash
# What does it save to ask the apps of a layout side by side? On the model of a Mac the wait is the slowest app's instead of the sum
# (scripts/mac-on-linux/tests/Together.swift), and by the recordings of whole days the sum is three times the slowest: 185 against
# 62 ms as a rule. But apps that lay their content out at the same time share the cores and the window server, which no model knows.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-together.sh
#
# The question only a Mac can answer: seven stock apps, a window each, arranged and let go six times: how long until the last window has
# answered, with `ARBOR_ONE_BY_ONE=1` (the control: Arbor as it was) and without?
# The two take turns, three sessions each: a hosted Mac drifts within minutes. first-dock.py reads each session's log and trace into a
# table, a row to an act: compare "at rest" and the time under "moves". The first `arrange` of a session is a case of its own: the
# windows have to be smaller than they were ever seen, so each is asked one at a time whether it can be (Controller+AskFirst.swift).
# What is put back (`float-all`) is not foretold, so there the two should not differ: the measure of the Mac's own drift.
# What comes back: the tables in output.txt, together-<session>.log, traces/<session>.jsonl (no titles: docs/TRACES.md).
# For GitHub's Macs (lib-apps.sh opens real apps). Six minutes after the build.
source "$(dirname "$0")/lib-apps.sh"

READER="$ARBOR_ROOT/scripts/mac-shell/first-dock.py"
TRACES="$ARBOR_OUT/traces"
mkdir -p "$TRACES"

apps_watchdog 1050
step "the Mac"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m), $(sysctl -n hw.ncpu) cores"
apps_build
display_mode 1920x1080 1680x1050 1600x900
apps_scratch

step "seven apps, a window each"
PIDS=""
open_one() {
  if app_open "$@"; then
    app_dismiss "$APP_PID"
    PIDS="$PIDS $APP_PID"
    echo "$1: pid $APP_PID, windows $APP_WINDOWS"
  else
    echo "$1 did not open a window: left out"
  fi
}
open_one com.apple.finder "$APPS_SCRATCH/grove"
open_one com.apple.Safari "$APPS_SCRATCH/page.html"
open_one com.apple.TextEdit "$APPS_SCRATCH/oak.txt"
open_one com.apple.Terminal
open_one com.apple.Notes
open_one com.apple.iCal
open_one com.apple.Preview "$APPS_SCRATCH/leaf.png"
echo "processes:$PIDS"
sleep 2

# session <name> [NAME=value]: Arbor over the seven; six times arrange and float-all, recorded and read.
session() {
  local name=$1 log
  shift
  step "$name"
  # Every session: a session that ends takes its home folder along, settings included.
  arbor_settings '{"animationDuration": 0, "focusRing": false}'
  # shellcheck disable=SC2086
  arbor_start_apps $PIDS "$@" || die "Arbor did not start"
  sleep 2
  ctl trace on "$name"
  for _ in 1 2 3 4 5 6; do
    ctl arrange
    sleep 1.5
    ctl float-all
    sleep 1.5
  done
  ctl trace off
  cp "$ARBOR_HOME"/traces/*-"$name".jsonl "$TRACES/$name.jsonl" || die "no recording of $name"
  log="$ARBOR_OUT/together-$name.log"
  cp "$ARBOR_HOME/arbor.log" "$log"
  echo
  python3 "$READER" table "$log" "$TRACES/$name.jsonl" || die "the recording of $name cannot be read"
  arbor_stop
  sleep 2
}

for turn in 1 2 3; do
  session "one-by-one-$turn" ARBOR_ONE_BY_ONE=1
  session "side-by-side-$turn"
done
exit 0
