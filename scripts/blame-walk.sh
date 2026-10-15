#!/bin/bash
# Whose fault is a walk that broke a rule: this change's, or the trunk's?
#
#   scripts/blame-walk.sh script.txt [base]        or the script on standard input
#
# A random walk that goes red in a change may have nothing to do with it: the change sent the seed another way, and
# the new road leads past a fault that was there before. So before anybody is blamed, the shrunk script that the failure printed is
# replayed twice: on this tree and on `base` (by default where this branch left origin/swarm/trunk). The base is checked out and built
# in .build/blame/<commit>, once for each commit, which takes some minutes the first time.
#
# Exit 0: the base breaks the same rule, so it is the trunk's: list it or tell the chaos lab, and go on. 1: only this tree breaks it.
# 2: this tree does not break anything either, or something could not be built.
set -euo pipefail
cd "$(dirname "$0")/.."

script=$(mktemp)
trap 'rm -f "$script"' EXIT
# As a failure prints it: indented.
sed -e 's/^[[:space:]]*//' -e '/^$/d' "${1:--}" > "$script"
base=$(git rev-parse --verify --quiet "${2:-$(git merge-base HEAD origin/swarm/trunk)}^{commit}") || { echo "blame-walk: no such commit"; exit 2; }

rules() { "$1" replay --quiet --go-on < "$script" | sed -n 's/^  \[\([A-Za-z-]*\)\].*/\1/p' | sort -u; }

swift build --product arbor-sim 2>&1 | grep -E "error:|Compiling|Build complete" | tail -1
here=$(rules .build/debug/arbor-sim)
if [ -z "$here" ]; then
  echo "blame-walk: this tree breaks no rule in that script"
  exit 2
fi

tree=.build/blame/$base
if [ ! -d "$tree" ]; then
  mkdir -p .build/blame
  git worktree add --detach --quiet "$tree" "$base"
fi
(cd "$tree" && swift build --product arbor-sim 2>&1 | grep -E "error:|Build complete" | tail -1)
[ -x "$tree/.build/debug/arbor-sim" ] || { echo "blame-walk: the base did not build"; exit 2; }
there=$(rules "$tree/.build/debug/arbor-sim")

echo "this tree breaks:        $(echo $here)"
echo "the base ${base:0:8} breaks: $(echo ${there:-nothing})"
only=$(comm -23 <(echo "$here") <(echo "$there"))
if [ -z "$only" ]; then
  echo "blame-walk: THE TRUNK'S. The base breaks all of it too; this change only led the walk there."
  exit 0
fi
echo "blame-walk: ONLY WITH THIS CHANGE: $(echo $only). (A rule that this change adds cannot break on the base: then look at the frames, with replay --frames.)"
exit 1
