#!/bin/bash
# Runs a script from this repository on a real Mac and brings back what it produced.
#
#   scripts/mac-shell/run.sh <script> [ref]
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-demo.sh
#
# Starts the "Mac shell" workflow (.github/workflows/mac-shell.yml) on <ref> (a branch; default: the
# current one, which must be pushed: the Mac runs what GitHub has), waits for it, fetches the branch
# the workflow pushed its output to into .mac-shell/<script>-<run id>/ in this worktree, deletes that branch,
# and prints the folder, the exit code and the end of the output. Exits with the script's exit code, or with
# 97 (could not start), 98 (timed out) or 99 (the run produced no output).
#
# Needs only git and `gh api` (REST), so it works where logs and artifacts cannot be downloaded.
# See "Seeing the real app from anywhere" in docs/TESTING.md.
#
# The output branch is mac-shell-out/<tag>, and the tag names the ref and the script, not the run: some
# environments may push but not delete branches, and there each run replaces the last one's output
# instead of adding a branch. So do not start the same script on the same ref twice at once.
#
# Environment: MAC_SHELL_TIMEOUT  seconds to wait for the run (default 2700)
#              MAC_SHELL_TAIL     lines of output.txt to print (default 40)
#              MAC_SHELL_TAG      another tag (letters, digits, . _ -; at most 40)
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 97

script=${1:?usage: scripts/mac-shell/run.sh <script> [ref]}
ref=${2:-$(git rev-parse --abbrev-ref HEAD)}
[ "$ref" != HEAD ] || { echo "run.sh: no branch is checked out; name one: run.sh <script> <ref>" >&2; exit 97; }
limit=${MAC_SHELL_TIMEOUT:-2700}
script=${script#./}

repo=$(git remote get-url origin | sed -E 's#^(https://[^/]*/|git@[^:]*:|ssh://[^/]*/)##; s#\.git$##; s#/$##')
api() { gh api "$@"; }
fail() { echo "run.sh: $1" >&2; exit "${2:-97}"; }

# What runs is what GitHub has at <ref>, so catch a forgotten push before a Mac is started.
remote=$(api "repos/$repo/commits/$ref" --jq .sha 2>/dev/null) || fail "GitHub has no ref '$ref' in $repo; push it first"
api "repos/$repo/contents/$script?ref=$remote" --jq .path >/dev/null 2>&1 \
  || fail "GitHub has no file '$script' at $ref (${remote:0:7}); commit and push it first"
if [ "$ref" = "$(git rev-parse --abbrev-ref HEAD)" ]; then
  [ "$remote" = "$(git rev-parse HEAD)" ] || fail "$ref is at ${remote:0:7} on GitHub but $(git rev-parse --short HEAD) here; push first"
  [ -z "$(git status --porcelain -- scripts Sources Package.swift)" ] \
    || echo "run.sh: note: uncommitted changes under scripts/ or Sources/ will not be part of this run" >&2
fi

slug() { printf '%s' "$1" | tr -c 'A-Za-z0-9_-' '-' | cut -c "1-$2"; }
name=$(slug "$(basename "$script" .sh)" 16)
tag=${MAC_SHELL_TAG:-$(slug "$ref" 23).$name}

# The dispatch call does not say which run it started: it is the one newer than the newest so far
# whose title carries the tag.
runs="repos/$repo/actions/workflows/mac-shell.yml/runs?event=workflow_dispatch&per_page=30"
newest=$(api "$runs" --jq '.workflow_runs[0].id // 0') || fail "cannot list the workflow's runs"
api -X POST "repos/$repo/actions/workflows/mac-shell.yml/dispatches" \
  -f ref="$ref" -f "inputs[script]=$script" -f "inputs[tag]=$tag" >/dev/null || fail "could not start the workflow on $ref"
echo "started $script at $ref (${remote:0:7}), tag $tag"

start=$(date +%s)
run=""
while [ -z "$run" ]; do
  [ $(($(date +%s) - start)) -gt 180 ] && fail "the run did not appear within 3 minutes" 98
  sleep 4
  run=$(api "$runs" --jq ".workflow_runs[] | select(.id > $newest and (.display_title | endswith(\"[$tag]\"))) | .id" \
    2>/dev/null | tail -n 1)
done
echo "run $run: https://github.com/$repo/actions/runs/$run"

status=""
while [ "$status" != completed ]; do
  if [ $(($(date +%s) - start)) -gt "$limit" ]; then
    api -X POST "repos/$repo/actions/runs/$run/cancel" >/dev/null 2>&1
    fail "still $status after ${limit}s; cancelled the run" 98
  fi
  sleep 10
  status=$(api "repos/$repo/actions/runs/$run" --jq .status 2>/dev/null)
done
conclusion=$(api "repos/$repo/actions/runs/$run" --jq .conclusion)
echo "finished after $(($(date +%s) - start))s: $conclusion"

annotations() {
  for job in $(api "repos/$repo/actions/runs/$run/jobs" --jq '.jobs[].id'); do
    api "repos/$repo/check-runs/$job/annotations?per_page=50" \
      --jq '.[] | "[\(.annotation_level)] \(.title // "")\n\(.message)"' | cut -c 1-400
  done
}

# The branch may hold an earlier run's output; the commit message says whose it is.
branch="mac-shell-out/$tag"
git fetch --quiet --no-tags origin "+refs/heads/$branch:refs/mac-shell/$tag" 2>/dev/null
case "$(git log -1 --format=%s "refs/mac-shell/$tag" 2>/dev/null)" in
  *"(run $run)") ;;
  *)
    git update-ref -d "refs/mac-shell/$tag" 2>/dev/null
    echo "the run pushed no output; its annotations:"
    annotations
    exit 99 ;;
esac
directory=".mac-shell/$name-$run"
mkdir -p "$directory"
git archive "refs/mac-shell/$tag" | tar -x -C "$directory"
git update-ref -d "refs/mac-shell/$tag"
api -X DELETE "repos/$repo/git/refs/heads/$branch" >/dev/null 2>&1 \
  || echo "(this environment may not delete branches: $branch stays until the next run replaces it)"

code=$(cat "$directory/exit-code.txt" 2>/dev/null)
echo
echo "--- end of $directory/output.txt"
tail -n "${MAC_SHELL_TAIL:-40}" "$directory/output.txt" 2>/dev/null
echo "---"
echo "output: $PWD/$directory"
ls "$directory" | sed 's/^/  /'
if [ -z "$code" ]; then
  echo "exit code: unknown (the script was cut off: $conclusion)"
  exit 99
fi
echo "exit code: $code"
exit "$code"
