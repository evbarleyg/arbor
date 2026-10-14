#!/bin/bash
# What Linux can say about a Mac shell run before it takes a Mac. run.sh starts nothing that has not been through this.
#
#   scripts/mac-shell/preflight.sh <script>…           where Swift is (on Linux): check what has not been checked yet
#   scripts/mac-shell/preflight.sh --check <script>…   anywhere, needs only Git: has it all been checked? Prints what has not; exit code 1 then
#
# GitHub lends the repository five Macs at a time, and a run that ends in a compiler's error, a typo in the script or a wait for
# something that never comes has held one for minutes to say what Linux says for nothing. So, for the commit that is checked out:
#
#   the code      `make lint`, `swift build`, `make typecheck-mac` (the macOS-only code against stand-ins: no compile error reaches a Mac)
#                 and `swift test`. Not needed, and not run, while Package.swift, Sources, Tests, the stand-ins and the helper tools are what the
#                 trunk has: that has been through CI.
#   each script   `bash -n`; and if it is built on lib.sh, a rehearsal against the fake Mac (rehearse.sh), which must get to the script's
#                 end: exit code 0, or 1 for a check that came out ✘, which may be the very thing the Mac is asked about. On the way nothing
#                 may have been said that is a slip whatever the machine: a command bash does not know, a variable nobody set, a command
#                 Arbor does not know (lib.sh goes on after a step that fails, so the exit code alone does not tell). A script that needs something
#                 the fake Mac lacks (64) or declines there (77) cannot be rehearsed to its end: that is said, and lets it pass.
#                 Not needed while the script and lib*.sh are what the trunk has: this is about what is new. (Not every script there can be
#                 rehearsed to its end. One that cannot, and has changed, is what run.sh's --no-preflight "<why>" is for.)
#
# What has passed is noted in .mac-shell/preflight/ (which Git ignores) under Git's hash of what was checked, not under a commit: nothing is
# checked twice, a change to one script rehearses that script and no more, and the note made in a container is found by run.sh outside
# it. Uncommitted changes to anything that counts make --check fail: the Mac runs what was committed, and the note is about what lies here.
#
# Exit code 0: all of it has passed. 1: something has not. 2: it cannot be checked here (no Swift; a Mac).
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 2

only_check=""
if [ "${1:-}" = --check ]; then only_check=yes; shift; fi
[ $# -gt 0 ] || { echo "usage: scripts/mac-shell/preflight.sh [--check] <script>…" >&2; exit 64; }
notes=.mac-shell/preflight
# Without Git every hash below would be that of nothing, and all alike.
git rev-parse --quiet --verify HEAD > /dev/null 2>&1 \
  || { echo "preflight: Git does not work in $PWD (a worktree whose repository is not in this container?)"; exit 2; }
TRUNK=${ARBOR_TRUNK:-origin/swarm/trunk}

CODE="Package.swift Sources Tests scripts/typecheck-mac"
short() { git hash-object --stdin | cut -c 1-20; }
# code_of <commit>: names everything the compilers and the tests read.
code_of() {
  # shellcheck disable=SC2086
  { for path in $CODE; do git rev-parse "$1:$path"; done; git ls-tree -r "$1" -- scripts/mac-shell | grep -E '\.(swift|m)$'; } 2>/dev/null | short
}
# script_of <path>: names the script, everything in its folder it may lean on, and the controller it is rehearsed against.
script_of() { { echo "$1"; git rev-parse HEAD:scripts/mac-shell HEAD:Sources HEAD:Package.swift; git rev-parse "HEAD:$1"; } 2>/dev/null | short; }

# leans_on <commit> <path>: the script and the library under it.
leans_on() { { git rev-parse "$1:$2"; git ls-tree "$1" scripts/mac-shell/ | grep -E 'lib[^/]*\.sh|state\.py'; } 2>/dev/null | short; }

# shellcheck disable=SC2086
dirty=$(git status --porcelain -- $CODE scripts/mac-shell "$@" | head -n 5)
if [ -n "$dirty" ]; then
  echo "preflight: not committed, so not what the Mac would run:"
  echo "$dirty"
  exit 1
fi

code=$(code_of HEAD)
owed=()
# No trunk to compare with: then the code is owed.
git rev-parse --quiet --verify "$TRUNK" > /dev/null 2>&1 || TRUNK=""
if { [ -z "$TRUNK" ] || [ "$code" != "$(code_of "$TRUNK")" ]; } && [ ! -f "$notes/code-$code" ]; then owed+=(code); fi
for script in "$@"; do
  [ -f "$script" ] || { echo "preflight: no file $script"; exit 1; }
  if [ -n "$TRUNK" ] && git cat-file -e "$TRUNK:$script" 2>/dev/null && [ "$(leans_on HEAD "$script")" = "$(leans_on "$TRUNK" "$script")" ]; then continue; fi
  [ -f "$notes/script-$(script_of "$script")" ] || owed+=("$script")
done
[ ${#owed[@]} -gt 0 ] || exit 0

if [ -n "$only_check" ]; then
  echo "preflight: not yet through the pre-flight at $(git rev-parse --short HEAD): ${owed[*]}"
  exit 1
fi
if [ "$(uname -s)" != Linux ]; then echo "preflight: for Linux: the stand-ins and the fake Mac are for machines without AppKit"; exit 2; fi
command -v swift > /dev/null 2>&1 || { echo "preflight: there is no swift here; run this where there is (a container with this folder in it will do)"; exit 2; }
mkdir -p "$notes"

# step <what it is called> <command…>: quiet when it passes, its last lines when it does not.
step() {
  local name=$1 began=$SECONDS log
  shift
  log=$(mktemp) || exit 2
  if "$@" > "$log" 2>&1; then
    echo "✔ $name ($((SECONDS - began)) s)"
    rm -f "$log"
    return 0
  fi
  echo "✘ $name ($((SECONDS - began)) s). The end of what it said:"
  grep -E "error:|✘" "$log" | sort -u | head -n 20
  tail -n 15 "$log"
  rm -f "$log"
  return 1
}

failed=0
for what in "${owed[@]}"; do
  if [ "$what" = code ]; then
    if step "lint" make lint && step "swift build" swift build && step "the macOS-only code type-checks" make typecheck-mac \
      && step "the headless tests" swift test; then
      : > "$notes/code-$code"
    else
      failed=1
    fi
    continue
  fi
  step "$what: bash -n" bash -n "$what" || { failed=1; continue; }
  if grep -qE '^[[:space:]]*(source|\.)[[:space:]].*lib(-[a-zA-Z0-9]+)?\.sh' "$what"; then
    began=$SECONDS
    log=$(mktemp) || exit 2
    scripts/mac-shell/rehearse.sh "$what" > "$log" 2>&1
    answer=$?
    # Of the script's own making, wherever it runs.
    slips=$(grep -nE ': command not found$|: unbound variable$|: syntax error|^unknown command `|: bad substitution$|: ambiguous redirect$' "$log" | head -n 10)
    [ -z "$slips" ] || answer=slips
    case "$answer" in
      slips)
        echo "✘ $what: in the rehearsal it said what no Mac would take better:"
        echo "$slips" | sed "s|$PWD/||g; s/^/    /"
        rm -f "$log"
        failed=1
        continue ;;
      0 | 1) echo "✔ $what: rehearsed to its end, exit code $answer ($((SECONDS - began)) s)" ;;
      64 | 77)
        echo "– $what: cannot be rehearsed to its end (exit code $answer): $(grep -vE '^[[:space:]]*$' "$log" | tail -n 1 | cut -c 1-160)" ;;
      *)
        echo "✘ $what: the rehearsal ended with exit code $answer. The end of what it said:"
        tail -n 25 "$log"
        rm -f "$log"
        failed=1
        continue ;;
    esac
    rm -f "$log"
  fi
  : > "$notes/script-$(script_of "$what")"
done
exit "$failed"
