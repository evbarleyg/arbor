#!/bin/bash
# "Never log window titles" (CLAUDE.md), nor the names people give to spaces, nor what they type into Go to…: people paste
# arbor.log into bug reports. This gives windows, spaces and searches words that occur nowhere else, runs them through every
# command that takes text, with debug logging on, also where commands are refused (a held view, a pause, nonsense), and
# looks for those words in the log. Part of `make check`. **A new command that takes text gets a line here.**
#
# Not secrets, and allowed in the log: bundle ids and app names (`exclude`, `summon`), the name of a trace, settings.
set -uo pipefail
cd "$(dirname "$0")/.."
sim=.build/debug/arbor-sim
[ -x "$sim" ] || { echo "privacy smoke test: $sim is not built"; exit 1; }
home=$(mktemp -d) || exit 1
trap 'rm -rf "$home"' EXIT

# Commands that fail are part of it, so the simulator's exit code says nothing.
ARBOR_HOME=$home ARBOR_DEBUG=1 "$sim" quiet \
  "open Safari" "open Mail" "open Notes" \
  "title 101 TITLEWORD one" "title 102 TITLEWORD two" "title 103 TITLEWORD three" \
  "dock 101 left" "dock 102 right" "zoom 101" "name NAMEWORD" "show-all" "go NAMEWORD" "go NAMEWORDx" "spaces" \
  "find TITLEWORD" "find TITLEWORD two" "find QUERYWORD" "reveal 103" \
  "rule add com.example.safari float title TITLEWORD" "rules" "rule change 1 com.example.safari ignore title TITLEWORD" \
  "rule remove 1" "layout --titles" "layout Safari:TITLEWORD | Mail" "layout \"Safari\" \"TITLEWORD one\" | Mail" \
  "bind ctrl+opt+j go NAMEWORD" "bind ctrl+opt+k find TITLEWORD" "bindings" "key ctrl+opt+j" "key ctrl+opt+k" \
  "hold" "go NAMEWORD" "find TITLEWORD" "name NAMEWORD2" "unname NAMEWORD" "key ctrl+opt+j" "release" \
  "pause" "go NAMEWORD" "find TITLEWORD" "name NAMEWORD3" "resume" \
  "unbind ctrl+opt+j" "unbind ctrl+opt+k" "unname NAMEWORD" "unname NAMEWORDy" \
  "title 101 TITLEWORD four" "minimize 101" "restore 101" "close 101" "close 102" \
  "state" "ascii" "menu" "doctor" "status" \
  "nonsense TITLEWORD" "dock TITLEWORD left" "zoom TITLEWORD" "name" "find" > "$home/out.txt" 2>&1

[ -s "$home/arbor.log" ] || { echo "privacy smoke test FAILED: nothing was logged, so nothing was tried"; exit 1; }
grep -q "DEBUG" "$home/arbor.log" || { echo "privacy smoke test FAILED: no debug lines, so half of it was not tried"; exit 1; }
# The words did reach Arbor: replies may say them.
grep -q "NAMEWORD" "$home/out.txt" || { echo "privacy smoke test FAILED: the names never arrived"; exit 1; }
if grep -n -e TITLEWORD -e NAMEWORD -e QUERYWORD "$home/arbor.log"; then
  echo "privacy smoke test FAILED: the lines above are in arbor.log"
  exit 1
fi
echo "privacy smoke test passed"
