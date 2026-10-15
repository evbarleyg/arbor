#!/bin/bash
# What wakes Arbor when nothing happens. In thirteen idle half-minutes on hosted Macs Arbor used 1.2 to 1.6 % of a core in the
# seven during which its welcome window was open, and 0.1 to 0.3 % in the six during which it was not. The window reads the facts
# about the Mac afresh once a second (`ArborApp.systemFacts`). Wording the window again takes a quarter of a millisecond (timed
# on Linux), so the rest goes to macOS.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-idle.sh
#
# A first run taught that the first thing asked about a running app, be it only its process number, is a round trip to Launch
# Services, and that it had no "before" to compare with: like with like, or nothing is learnt. The second, with 32 apps running:
# as it is 0.10, 0.10, 0.30 and 0.17 % of a core; with nothing kept 0.43 and 0.67 %, the main thread seen with the running apps
# for 184 ms of fifteen seconds. The input sources: 1 ms. What is left of the second is the question about Screen Recording.
# The question only a Mac can answer: is Arbor at rest with the window open, how far from where it was, and what is left?
#
# Three rounds on one Mac, minutes apart, each a fresh home folder, four test windows that nobody touches, and Arbor with its
# shortcuts, its menu bar item and its welcome window, as a first launch has them: as it is; with `KeptFact` made to forget at
# once, which is the code as it was (only on a throwaway Mac: it changes a source file, builds again and puts the file back); as
# it is, once more. In each: a rest, two half-minutes in which the processor time Arbor has had is read before and after, then
# `sample` for fifteen seconds. Kept: mac-shell/sample-<round>.txt (call stacks, no window's title) and Arbor's log.
# On a person's Mac: the first round only, with its own test windows and an Arbor limited to them; no setting is changed.
# About seven minutes after the build.
source "$(dirname "$0")/lib.sh"

# ps gives the time a process has had of the processors as [[dd-]hh:]mm:ss.cc.
cpu_seconds() {
  ps -o cputime= -p "$1" 2> /dev/null | awk '{ parts = split($1, unit, ":"); seconds = 0; for (i = 1; i <= parts; i++) seconds = seconds * 60 + unit[i]; printf "%.2f", seconds }'
}

half_minute() {
  local before after
  before=$(cpu_seconds "$ARBOR_PID")
  sleep 30
  after=$(cpu_seconds "$ARBOR_PID")
  echo "$after $before" | awk -v round="$1" '{ printf "%s: with nothing to do Arbor used %.2f %% of a core (%.2f s in 30 s)\n", round, ($1 - $2) * 100 / 30, $1 - $2 }'
}

# round <name>
round() {
  local tries=0
  step "round: $1"
  # arbor_stop leaves a new home folder behind, which has welcomed nobody.
  arbor_start 4 ARBOR_NO_PROMPT=0 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
  sleep 6
  echo "Arbor's own windows (id pid layer x y w h on owner):"
  pointer windows | awk -v pid="$ARBOR_PID" '$2 == pid' | head -n 12
  half_minute "$1"
  half_minute "$1"
  if command -v sample > /dev/null 2>&1; then
    sample "$ARBOR_PID" 15 1 -mayDie -file "$ARBOR_OUT/sample-$1.txt" > "$ARBOR_OUT/sample-$1.says" 2>&1 &
    started $!
    while [ ! -s "$ARBOR_OUT/sample-$1.txt" ] && [ "$tries" -lt 120 ]; do
      sleep 0.5
      tries=$((tries + 1))
    done
    echo "milliseconds of fifteen seconds in which the main thread was seen in:"
    grep -E "OnboardingSession.refresh|ArborApp.systemFacts|MacFacts.competingApps.getter|MacFacts.readInputSources|MacFacts.switches|TCCAccessPreflight|AXIsProcessTrusted " \
      "$ARBOR_OUT/sample-$1.txt" | sed -E 's/^[ +!:|]+//; s/  \(in [A-Za-z]+\).*\]//' | cut -c 1-120 | head -n 14
  else
    echo "no sample here: times only"
  fi
  arbor_log
  arbor_stop
}

step "the Mac"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m), $(sysctl -n hw.ncpu) cores"
# Two numbers, no names.
on_throwaway_mac && echo "processes: $(ps -A -o pid= | wc -l | tr -d ' '); of them apps that Launch Services knows: $(lsappinfo list 2> /dev/null | grep -c 'ASN:')"
arbor_build

round as-it-is

if on_throwaway_mac; then
  kept="$ARBOR_ROOT/Sources/ArborCore/SystemFacts.swift"
  scratch_dir probe PROBE_KEEPS
  cp "$kept" "$PROBE_KEEPS/SystemFacts.swift"
  # However this ends, the file is as it was.
  at_exit "cp '$PROBE_KEEPS/SystemFacts.swift' '$kept'"
  grep -v "if let kept, kept.key == key { return kept.value }" "$PROBE_KEEPS/SystemFacts.swift" > "$kept"
  step "built again with nothing kept"
  cmp -s "$kept" "$PROBE_KEEPS/SystemFacts.swift" && echo "the line was not found: this round will say nothing"
  [ -n "${ARBOR_BUILT:-}" ] || (cd "$ARBOR_ROOT" && swift build > "$ARBOR_OUT/build-as-it-was.log" 2>&1) || tail -n 20 "$ARBOR_OUT/build-as-it-was.log"
  round as-it-was
  cp "$PROBE_KEEPS/SystemFacts.swift" "$kept"
  step "built again as it is"
  [ -n "${ARBOR_BUILT:-}" ] || (cd "$ARBOR_ROOT" && swift build > "$ARBOR_OUT/build-as-it-is.log" 2>&1) || tail -n 20 "$ARBOR_OUT/build-as-it-is.log"
  round as-it-is-again
fi
exit 0
