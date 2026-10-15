#!/bin/bash
# The real-window suite: every shipped feature exercised on real windows the way a person would, with real
# drags, clicks, shortcuts and menus, and checked against what the window server says happened.
#
#   make suite [SECTIONS="30 60-tiles"]                      on this Mac, keeping the evidence
#   scripts/mac-shell/suite.sh [section…]                    on this Mac; sections by number or name
#   scripts/mac-shell/run.sh --macs 2 scripts/mac-shell/suite.sh      on two of GitHub's Macs, side by side, from anywhere: eight minutes
#                                                            each. All of it takes sixteen, which is more than one run is given
#   scripts/mac-shell/rehearse.sh                            on Linux, against stand-ins: proves the scripts, not Arbor
#
# Builds, then runs scripts/mac-shell/suite/[0-9]*.sh in order, each as a process of its own with a time limit, so that
# one section's failure, crash or hang costs the others nothing. A section is an ordinary Mac shell script (lib.sh)
# and also runs alone: scripts/mac-shell/run.sh scripts/mac-shell/suite/30-seams.sh.
#
# What the claims and checks print is the evidence `make parity` counts: it lands in mac-shell/evidence/<section>.txt. With
# ARBOR_KEEP_EVIDENCE=1 (`make suite` sets it) it is copied to collab/evidence/suite-<section>-latest.txt, by run.sh where the run was
# started, here on this Mac, where what was proved is also listed in collab/parity.json (scripts/mac-shell/suite-parity.py). Commit both.
# "The real-window suite" in docs/TESTING.md says how to add a feature's claims.
#
# On a person's Mac it is one supervised run with one curtain (the header of lib.sh says what that means): it moves the
# pointer and presses keys, uses only its own test windows, changes no setting, and ⌃C stops it. Claims that need more
# than that (arbor:// links, Login Items, the bare Desktop, ⌘Tab) run only on GitHub's Macs.
#
# Exit code: 0 every check passed or failed as it is `known` to, 1 another failed or a section did not finish, 2 nothing
# could be built, 75 somebody took the curtain down, 77 this Mac is not free, 124 or 130 cut off or stopped.
# Environment: ARBOR_SECTION_LIMIT  seconds a section may take (default 150)
# GitHub's Macs keep lib.sh's limit, which fits their job's.
{ [ "${GITHUB_ACTIONS:-}" = true ] && [ "$(id -un)" = runner ]; } || ARBOR_TIME_LIMIT=${ARBOR_TIME_LIMIT:-1800}
source "$(dirname "$0")/lib.sh"
section_limit=${ARBOR_SECTION_LIMIT:-150}

sections=""
if [ $# -eq 0 ]; then
  sections=$(ls scripts/mac-shell/suite/[0-9]*.sh)
else
  for wanted in "$@"; do
    found=$(ls scripts/mac-shell/suite/"$(basename "$wanted" .sh)"*.sh 2>/dev/null)
    [ -n "$found" ] || die "suite.sh: no section $wanted in scripts/mac-shell/suite/"
    sections="$sections $found"
  done
fi

# Given to several Macs at once (run.sh --macs 2), each takes every second section: "2/2" is the second Mac of two.
share=${MAC_SHELL_SHARE:-1/1}
if [ "${share#*/}" -gt 1 ] 2>/dev/null; then
  mine="" place=0
  for section in $sections; do
    [ $((place % ${share#*/} + 1)) -ne "${share%/*}" ] || mine="$mine $section"
    place=$((place + 1))
  done
  echo "Mac ${share%/*} of ${share#*/}:$(for section in $mine; do printf ' %s' "$(basename "$section" .sh)"; done)"
  sections=$mine
fi

# Here, so that the sections find it done, and so that the curtain is this script's and hangs until the last of them has ended.
arbor_build
# For every Mac that has a share of the sections, whichever they are.
screen_edges_dock || echo "macOS tiles at the screen's edges on this Mac, so Arbor stands aside there: the claims about docking at an edge skip themselves"
# What a Mac has shown once can be replayed on Linux for ever (docs/TRACES.md).
export ARBOR_RECORD=1

began_all=$SECONDS
report=""
passed=0
failed=0
known=0
unfinished=0
for section in $sections; do
  name=$(basename "$section" .sh)
  echo
  echo "=== $name"
  began=$SECONDS
  on_record=$(wc -l < "$ARBOR_LEDGER/pids" | tr -d ' ')
  limit "$section_limit" "$BASH" "$section" 2>&1
  code=$?
  # Somebody took the curtain down, or stopped the section: they want their Mac back, not the next section.
  case "$code" in
    75 | 129 | 130 | 143) exit "$code" ;;
  esac
  if [ -n "${ARBOR_CURTAIN_PID:-}" ] && ! kill -0 "$ARBOR_CURTAIN_PID" 2>/dev/null; then
    echo "the curtain was taken down: somebody wants their Mac back. Ending the suite"
    exit 75
  fi
  on_throwaway_mac && arbor_in_the_way | sed 's/^/left in the way: /'
  evidence="$ARBOR_OUT/evidence/$name.txt"
  section_passed=$(grep -c '^  ✔' "$evidence" 2>/dev/null)
  section_failed=$(grep -c '^  ✘' "$evidence" 2>/dev/null)
  steps=$(grep -c '^▸ ' "$evidence" 2>/dev/null)
  section_known=$(grep -c '^  ✘.*(known: ' "$evidence" 2>/dev/null)
  passed=$((passed + ${section_passed:-0}))
  failed=$((failed + ${section_failed:-0}))
  known=$((known + ${section_known:-0}))
  note=""
  case "$code" in
    0 | 1) ;;
    77) note="  SKIPPED" ;;
    124) note="  CUT OFF after ${section_limit}s"; unfinished=$((unfinished + 1)) ;;
    *) note="  DID NOT FINISH (exit code $code)"; unfinished=$((unfinished + 1)) ;;
  esac
  if [ "$code" -ge 2 ]; then
    # What a section that was cut off left behind would be in the next one's way: the processes it put on record, and no others.
    arbor_release_keys
    "$ARBOR_POINTER" calm
    # Without a process to name, kill_started would stop all that are on record, this script's curtain among them.
    left=$(tail -n "+$((on_record + 1))" "$ARBOR_LEDGER/pids" | cut -d ' ' -f 1)
    # shellcheck disable=SC2086
    [ -z "$left" ] || kill_started $left
  fi
  report="$report$(printf '%-18s %3d claims %4d passed %3d failed %4d s%s' \
    "$name" "${steps:-0}" "${section_passed:-0}" "${section_failed:-0}" "$((SECONDS - began))" "$note")
"
done

echo
echo "=== the suite"
printf '%s' "$report"
grep -h '^  ✘' "$ARBOR_OUT"/evidence/*.txt 2>/dev/null | sed 's/^  /failed: /'
echo "suite: $passed passed, $failed failed ($known of them known), $unfinished section(s) unfinished, in $((SECONDS - began_all)) s"

# A rehearsal proves nothing about real windows, so it leaves no evidence. GitHub's Macs are thrown away: run.sh keeps theirs.
if [ -z "${ARBOR_REHEARSAL:-}" ] && ! on_throwaway_mac; then
  if [ "${ARBOR_KEEP_EVIDENCE:-}" = 1 ]; then
    for section in $sections; do
      name=$(basename "$section" .sh)
      # A section that never got to a claim says nothing new.
      if grep -q '^▸ ' "$ARBOR_OUT/evidence/$name.txt" 2>/dev/null; then
        # What is kept gets committed. The run's own files are gone over only when it ends.
        arbor_discreet < "$ARBOR_OUT/evidence/$name.txt" > "collab/evidence/suite-$name-latest.txt"
      fi
    done
    echo "evidence: collab/evidence/suite-*-latest.txt"
    python3 scripts/mac-shell/suite-parity.py | tail -n 25
    echo "commit collab/evidence and collab/parity.json, with docs/FEATURES.md after \`make parity\`"
  else
    echo "evidence: mac-shell/evidence/ (ARBOR_KEEP_EVIDENCE=1, or \`make suite\`, copies it to collab/evidence and lists it in collab/parity.json)"
  fi
fi

[ "$failed" -eq "$known" ] && [ "$unfinished" -eq 0 ]
