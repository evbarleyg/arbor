#!/bin/bash
# What wakes Arbor when nothing happens. In thirteen idle half-minutes on hosted Macs Arbor used 1.2 to 1.6 % of a core in the
# seven during which its welcome window was open, and 0.1 to 0.3 % in the six during which it was not. The window reads the facts
# about the Mac afresh once a second (`ArborApp.systemFacts`).
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-idle.sh
#
# The question only a Mac can answer: which of those facts takes the time (the running apps, the input sources, another
# process's defaults, the two permissions, wording the window again), so that the cure goes where the cost is.
#
# Two runs of Arbor on one home folder, each with four test windows that nobody touches. The first opens the welcome window, as a
# first launch does; the second, having welcomed, does not: the control. In each: a rest, half a minute in which the processor
# time Arbor has had is read before and after, then `sample` for fifteen seconds. Kept: mac-shell/sample-<n>.txt (call stacks,
# no window's title) and Arbor's log.
# Safe on a person's Mac: its own test windows, an Arbor limited to them with its own home folder, no setting changed.
# About two minutes after the build.
source "$(dirname "$0")/lib.sh"

# ps gives the time a process has had of the processors as [[dd-]hh:]mm:ss.cc.
cpu_seconds() {
  ps -o cputime= -p "$1" 2> /dev/null | awk '{ parts = split($1, unit, ":"); seconds = 0; for (i = 1; i <= parts; i++) seconds = seconds * 60 + unit[i]; printf "%.2f", seconds }'
}

step "the Mac"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m), $(sysctl -n hw.ncpu) cores"
echo "processes: $(ps -A -o pid= | wc -l | tr -d ' ')"
arbor_build

for run in 1 2; do
  step "run $run of Arbor"
  arbor_start 4 ARBOR_NO_PROMPT=0
  sleep 6
  echo "Arbor's own windows (id pid layer x y w h on owner):"
  pointer windows | awk -v pid="$ARBOR_PID" '$2 == pid' | head -n 12
  before=$(cpu_seconds "$ARBOR_PID")
  sleep 30
  after=$(cpu_seconds "$ARBOR_PID")
  echo "$after $before" | awk '{ printf "with nothing to do Arbor used %.2f %% of a core (%.2f s in 30 s)\n", ($1 - $2) * 100 / 30, $1 - $2 }'
  if command -v sample > /dev/null 2>&1; then
    sample "$ARBOR_PID" 15 1 -mayDie -file "$ARBOR_OUT/sample-$run.txt" > "$ARBOR_OUT/sample-$run.says" 2>&1 &
    started $!
    tries=0
    while [ ! -s "$ARBOR_OUT/sample-$run.txt" ] && [ "$tries" -lt 120 ]; do
      sleep 0.5
      tries=$((tries + 1))
    done
  else
    echo "no sample here: times only"
  fi
  arbor_log
  arbor_stop
done

step "what the samples saw of the welcome window's second"
grep -c "" "$ARBOR_OUT"/sample-*.txt 2> /dev/null
grep -h -E "OnboardingSession.refresh|systemFacts|MacFacts|onboardingModel|OnboardingWindow.render" "$ARBOR_OUT"/sample-1.txt 2> /dev/null | cut -c 1-220 | head -n 30
exit 0
