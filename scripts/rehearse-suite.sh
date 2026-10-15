#!/bin/bash
# The real-window suite, rehearsed against the fake Mac wherever that can say something about the change: a step of `make check`, so of
# `make gate`, and CI's "linux / rehearsal".
#
#   scripts/rehearse-suite.sh            decides, says why, and rehearses or does not
#   scripts/rehearse-suite.sh --always   rehearses whatever has changed
#   scripts/rehearse-suite.sh --decide   reads the paths that changed, one to a line, and only says what it would do: exit code 0 to rehearse, 3 not to
#
# Why. The suite (scripts/mac-shell/suite.sh) is some 2,400 checks on real windows, and it runs when somebody takes two Macs for it. In between the
# product moves on: in one night twelve of its claims went out of date and nobody saw it, because nothing played them. A rehearsal plays all
# of them against the REAL controller on the stand-ins (scripts/mac-shell/rehearse.sh says what stands in for what), on every core, in five minutes on four.
# A ✘ here is a claim that the change has made untrue, or a fault the change has brought: either way it is the change's to settle, in the same pull request.
# Reword a claim and its evidence no longer counts: scripts/mac-shell/suite-parity.py says what that takes off the scoreboard.
#
# Where it can say nothing it says so and takes a second: a change to pages, scenarios, tests, tools, or to the macOS-only code, none of which a
# rehearsal runs. What has changed is what the branch and the working tree add to the trunk; in a pull request's run at GitHub, what the
# merge adds to its base. Where that cannot be told, and wherever work is integrated (a push, a merge train, the nightly run), it rehearses.
#
# Environment:
#   PART, PARTS           "1" of "2": this machine's share of the sections, as CI's two divide them
#   ARBOR_REHEARSAL_AS, ARBOR_REHEARSAL_DISPLAY, ARBOR_REHEARSAL_BASH    as for rehearse.sh: a person's Mac, another display, macOS's own bash
#   ARBOR_TRACE=1         record traces all the same, as a run on a Mac does
#   ARBOR_NO_REHEARSAL=1  not this time: for a second gate after a mend of a line, by whoever has seen the suite rehearsed on the change already. It says so in
#                         capitals in its one line, which is the row's line in `make gate`. At GitHub nobody hears it
#
# Prints every ✘ under its section and claim, and a last line with the sum. All of it: .build/rehearsal-<n>/log.txt.
# Exit code 0: nothing to say, or every check held (or is known to fail). 1: a ✘. 2: the fake Mac does not build.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

# matters <path>: a rehearsal runs it, reads it or is built from it.
matters() {
  case "$1" in
    # Package.swift leaves these out off macOS, and the fake Mac plays them by hand.
    Sources/ArborKit/AX/* | Sources/ArborKit/UI/* | Sources/ArborKit/Input/* | Sources/ArborKit/App/*) return 1 ;;
    Sources/Arbor/* | Sources/arborctl/* | Sources/arbor-e2e/* | Sources/ArborTestWindows/*) return 1 ;;
    Package.swift | Sources/*) return 0 ;;
    scripts/rehearse-suite.sh | scripts/mac-shell/rehearse.sh | scripts/mac-shell/rehearse/*) return 0 ;;
    scripts/mac-shell/suite.sh | scripts/mac-shell/suite/* | scripts/mac-shell/lib.sh | scripts/mac-shell/state.py) return 0 ;;
  esac
  return 1
}

# decide: reads paths, prints the sentence. 0: rehearse.
decide() {
  local path first="" count=0 all=0
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    all=$((all + 1))
    matters "$path" || continue
    count=$((count + 1))
    [ -n "$first" ] || first=$path
  done
  if [ "$count" -eq 0 ]; then
    echo "the suite is not rehearsed: of what has changed ($all files) a rehearsal runs, reads and compiles nothing"
    return 3
  fi
  echo "the suite is rehearsed: $first$([ "$count" -eq 1 ] || echo " and $((count - 1)) more") can make a claim untrue"
}

# changed: the paths, or exit code 1 where nobody can tell.
changed() {
  local base trunk
  # In a run at GitHub, which names the event it is for.
  if [ -n "${GITHUB_EVENT_NAME:-}" ]; then
    # What is checked out is the merge of the pull request into its base, so two dots: what the merge adds to the base as it is now.
    [ -n "${GITHUB_BASE_REF:-}" ] || return 1
    git fetch --quiet --depth=1 origin "$GITHUB_BASE_REF" 2> /dev/null || return 1
    git diff --name-only FETCH_HEAD HEAD
    return
  fi
  for trunk in origin/swarm/trunk origin/main; do
    base=$(git merge-base "$trunk" HEAD 2> /dev/null) || continue
    git diff --name-only "$base" || return 1
    git ls-files --others --exclude-standard
    return
  done
  return 1
}

case "${1:-}" in
  "" | --always) ;;
  --decide) decide; exit ;;
  *) sed -n '2,8p' "$0"; exit 64 ;;
esac

if [ "$(uname -s)" != Linux ]; then
  echo "the suite is not rehearsed: a rehearsal is for Linux. On a Mac the suite itself runs: make suite"
  exit 0
fi
# A run at GitHub names the event it is for, and is what others go by.
if [ -n "${ARBOR_NO_REHEARSAL:-}" ] && [ -z "${GITHUB_EVENT_NAME:-}" ]; then
  echo "THE SUITE IS NOT REHEARSED, BY ARBOR_NO_REHEARSAL: this says nothing about the real-window suite's claims"
  exit 0
fi
# Before anything is built.
if [ "${1:-}" = --always ]; then
  echo "the suite is rehearsed: asked for"
elif paths=$(changed); then
  decide <<< "$paths" || exit 0
else
  echo "the suite is rehearsed: here work is integrated, or nobody can tell what has changed"
fi

began=$SECONDS
jobs=$(nproc 2> /dev/null || echo 1)
rm -rf .build/rehearsal-[0-9]*
# A run on a Mac records itself, for what a Mac has shown once should never need a Mac again. What the fake Mac shows is to be had again for nothing, and
# recording it takes half as long again (464 s against 302, on four cores).
export ARBOR_TRACE=${ARBOR_TRACE:-0}
MAC_SHELL_SHARE="${PART:-1}/${PARTS:-1}" scripts/mac-shell/rehearse.sh --jobs "$jobs" > .build/rehearse-suite.log 2>&1
code=$?
if [ "$code" -eq 2 ] || ! ls .build/rehearsal-[0-9]*/log.txt > /dev/null 2>&1; then
  tail -n 40 .build/rehearse-suite.log
  echo "the suite could not be rehearsed (exit code $code)"
  exit 2
fi

# Every ✘ under its section and its claim; what is known to fail says so itself.
cat .build/rehearsal-[0-9]*/log.txt | awk '
  /^=== / { section = $2 }
  /^▸ / { claim = $0 }
  /^  ✘ / {
    if (section != said_section) { print ""; print section; said_section = section }
    if (claim != said_claim) { print claim; said_claim = claim }
    print
  }'
sum=$(cat .build/rehearsal-[0-9]*/log.txt | awk '
  /^suite: / { passed += $2; failed += $4; gsub(/[^0-9]/, "", $6); known += $6; for (i = 1; i <= NF; i++) if ($i ~ /^section/) unfinished += $(i - 1) }
  END { printf "%d held, %d failed (%d of them known), %d sections unfinished", passed, failed, known, unfinished }')
echo
echo "the suite, rehearsed on $jobs fake Macs${PARTS:+ (part $PART of $PARTS)}: $sum, in $((SECONDS - began)) s"
[ "$code" -eq 0 ] || exit 1
