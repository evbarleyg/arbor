#!/bin/bash
# Starts a run of the newcomer's eval on one of GitHub's Macs, and says what to tell the newcomer.
#
#   scripts/newcomer/start.sh <run> arbor <commit or branch> [unmarked]  with Arbor to install, built from there, marked as a browser marks a download: what a stranger
#                                                                        gets. unmarked: spared macOS's Gatekeeper, which the score then says
#   scripts/newcomer/start.sh <run> macos                                the same tasks with what macOS itself offers
#
# <run> is a name of your choosing, 1 to 20 letters, digits and dashes. Git alone, no call to GitHub's API: the commit that is checked out
# here, under a subject that says what is asked for, is pushed to newcomer-start/<run>, which starts the workflow "Newcomer" as that commit has it. So the
# rig that runs is the one in this checkout, landed or not; uncommitted changes are not part of it.
# It then waits for the first picture, ten minutes or so with Arbor to build, and prints the newcomer's words of use.
# One run at a time: a second one waits for the first to end. Afterwards: scripts/newcomer/fetch.sh <run>, then score.py.
set -euo pipefail
cd "$(dirname "$0")/../.."
usage="usage: scripts/newcomer/start.sh <run> arbor <commit or branch> [unmarked] | <run> macos"
run=${1:?$usage} arm=${2:?$usage}
[[ "$run" =~ ^[A-Za-z0-9-]{1,20}$ ]] || { echo "start.sh: a run's name is 1 to 20 letters, digits and dashes" >&2; exit 64; }
case "$arm" in
  arbor)
    build=${3:?$usage}
    # What GitHub can check out: a commit it has, by its full name, or a branch.
    if full=$(git rev-parse --verify --quiet "$build^{commit}") && [ -z "$(git ls-remote origin "refs/heads/$build")" ]; then build=$full; fi
    asked="arm=arbor build=$build mark=$([ "${4:-}" = unmarked ] && echo no || echo yes)" ;;
  macos) asked="arm=macos" ;;
  *) echo "$usage" >&2; exit 64 ;;
esac
[ -z "$(git status --porcelain -- scripts .github)" ] || echo "start.sh: note: uncommitted changes under scripts/ or .github/ are not part of this run" >&2
screen="refs/heads/mac-shell-out/newcomer.$run.screen"
[ -z "$(git ls-remote origin "$screen" "refs/heads/newcomer-start/$run")" ] || { echo "start.sh: there is, or was today, a run called $run: take another name" >&2; exit 65; }

commit=$(TZ=UTC git commit-tree "HEAD^{tree}" -p HEAD -m "newcomer: $asked")
git push --quiet origin "$commit:refs/heads/newcomer-start/$run"
echo "started $run ($asked) with the rig at $(git rev-parse --short HEAD)"
began=$SECONDS
until [ -n "$(git ls-remote origin "$screen")" ]; do
  [ $((SECONDS - began)) -lt "${NEWCOMER_START_LIMIT:-2400}" ] || { echo "start.sh: no first picture after $((SECONDS - began)) s: is it waiting for a Mac, or for another run to end?" >&2; exit 98; }
  sleep 15
done
url=$(git remote get-url origin)
cat << WORDS
the Mac is up after $((SECONDS - began)) s. It waits for somebody to say ready only as long as leaves every task its time: about ten minutes with Arbor, forty without. For the newcomer, who gets this and nothing else:

    git clone --depth 1 --single-branch --branch mac-shell-out/newcomer.$run.screen $url mac
    cd mac && cat HOWTO.md

WORDS
