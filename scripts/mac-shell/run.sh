#!/bin/bash
# Runs a script from this repository on a real Mac and brings back what it produced. Or several scripts.
#
#   scripts/mac-shell/run.sh [--macs N] [--on macos-15] [--bare] [--release] [--priority N] [--no-preflight "<why>"] <script>… [ref]
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-demo.sh
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-F10.sh scripts/mac-shell/shots-F12.sh scripts/mac-shell/shots-F43.sh
#
# NOTHING STARTS THAT LINUX CAN ALREADY REFUTE. The commit must have been through scripts/mac-shell/preflight.sh: lint, build, the type-check of the
# macOS-only code and the headless tests (none of it needed while the code is the trunk's), and a rehearsal of each script against the fake Mac.
# Where there is a `swift`, run.sh runs it itself. Where there is none it says what to run where there is one, and exits with 96.
#   --no-preflight "<why>"   start it all the same, and say why: the reason is printed, and stands in the run's title for everybody to read.
# It applies to the branch that is checked out: of another ref run.sh cannot know more than GitHub does.
#
# SEVERAL SCRIPTS IN ONE RUN share one Mac, one checkout and one build, and wait for a Mac once: GitHub lends the repository five at a
# time (`make mac-queue`), so three scripts in one run are back sooner than three runs, and leave four Macs to the others. They
# run one after the other, each gets its turn whatever became of the one before, and what each said and left comes back in a folder of
# its own: .mac-shell/<first script>-<run id>/1-<script>/, 2-<script>/, …, with a line for each in summary.txt. At most four to a Mac
# (each may take twenty minutes); more are shared out among as many Macs as that takes.
#   --macs N    share the scripts out among N Macs, which work side by side: for scripts that take long. What the second Mac brings
#               back is in …/mac-2/. ONE script and --macs N: every Mac runs it, and finds in $MAC_SHELL_SHARE which part is
#               its own, "2/3" on the second of three; only for a script that looks there (compat.sh does).
#   --on KIND   another of GitHub's Macs than macos-26: macos-15, macos-14 or macos-15-intel. They come out of the same five.
#   --bare      no toolchain and no build: half a minute saved for a script that only asks the Mac something.
#   --release   the scripts drive the release build, the program people get (ARBOR_CONFIGURATION=release says the same): for whatever is measured,
#               how busy, how long, how smooth. It is built before the first script and kept for the next run, apart from the debug builds.
#   --priority N   GitHub hands its Macs out in no particular order, so the order is kept here, before the run is started: waiting
#               here costs nobody anything. 1 waits for nobody's ordinary run: a fault on real windows, a merge train. 2 waits while three or
#               more jobs are waiting for a Mac. 3 (the default) waits while any is: pictures, features, whatever can wait.
#               And whatever the priority, it waits while two jobs for <ref> (3: one) are running or waiting already, the run it replaces aside,
#               and WHILE A TRAIN'S OWN macOS JOB IS WAITING FOR A MAC (CI for train/…, swarm/trunk or main): everybody's landing waits for that one.
#
# Starts the "Mac shell" workflow (.github/workflows/mac-shell.yml) for <ref> (a branch; default: the
# current one, which must be pushed: the Mac runs what GitHub has), waits for it, fetches the branch
# the workflow pushed its output to into .mac-shell/<script>-<run id>/ in this worktree, deletes that branch,
# and prints the folder, the exit code and the end of the output. Exits with the script's exit code (of several: the first that is
# not 0), or with 95 (the rules changed while it held back: read them and start it again), 96 (not through the pre-flight), 97 (could not start),
# 98 (it has waited long enough: THE RUN IS NOT CANCELLED, it goes on without this waiter, and how to watch, fetch and cancel it is printed) or
# 99 (the run produced no output).
# With ARBOR_KEEP_EVIDENCE=1 the evidence of the real-window suite's sections (scripts/mac-shell/suite/) is copied to
# collab/evidence/suite-<section>-latest.txt, where `make parity` reads it; commit it when it should count.
#
# Needs only git and `gh api` (REST), so it works where logs and artifacts cannot be downloaded. GitHub allows an account 5,000 REST calls an
# hour, for everything everybody does under it, and a dozen copies of this script asking every ten seconds have used them up and
# stopped all work for half an hour. So whatever Git can answer is asked of Git, which does not count: what GitHub has at <ref>, and whether
# the run has ended, which is when its output branch appears. A run costs about ten calls, however long it waits.
# See "Seeing the real app from anywhere" in docs/TESTING.md.
#
# The output branch is mac-shell-out/<tag>, and the tag names the ref and the script, not the run: some
# environments may push but not delete branches, and there each run replaces the last one's output
# instead of adding a branch. Starting the same scripts for the same ref again cancels the run that is still under way.
#
# Environment: MAC_SHELL_TIMEOUT  seconds to wait for the run (default 2700), and as many again once it has its Mac. It is this script's patience and nothing
#                                 else: a run is never cancelled for it. One that waits keeps its place in GitHub's line, one that is half done its minutes.
#              MAC_SHELL_ASK      seconds until GitHub is first asked whether the run has ended without output (default 180); twice as long each time after
#              MAC_SHELL_LOOK     seconds a look at the queue may take before it is left behind (default 60)
#              ARBOR_MAC_RULES    files, with colons between them, in which whoever coordinates writes what holds for everybody. A run that has held back and
#                                 finds one of them changed does not start: it prints what is new and ends with 95. What was true when it began to wait may not be any more.
#              MAC_SHELL_TAIL     lines of output.txt to print (default 40)
#              MAC_SHELL_POLL     seconds between two looks at the queue while it holds back (default 120, and up to a quarter more)
#              ARBOR_MAC_QUEUE_CACHE   a file in which several checkouts share one look at the queue (scripts/mac-queue.py)
#              ARBOR_MAC_PRIORITY as --priority
#              MAC_SHELL_TAG      another tag (letters, digits, . _ -; at most 40)
#              MAC_SHELL_WORKFLOW_REF   the branch whose mac-shell.yml runs (default: swarm/trunk if there is one, else main).
#                                 One for everybody, whatever <ref> is: a run can read only the caches of the branch its workflow is
#                                 from, so this is what lets it start with the toolchain, and the build, of somebody else's run.
#                                 Name your own branch after changing the workflow or .github/actions.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 97

usage="usage: scripts/mac-shell/run.sh [--macs N] [--on macos-15] [--bare] [--release] [--priority N] [--no-preflight \"<why>\"] <script>… [ref]"
macs="" ref="" kind=macos-26 bare=false priority=${ARBOR_MAC_PRIORITY:-3} unchecked="" configuration=${ARBOR_CONFIGURATION:-debug}
scripts=()
while [ $# -gt 0 ]; do
  case "$1" in
    --macs) macs=${2:?$usage}; shift ;;
    --on) kind=${2:?$usage}; shift ;;
    --release) configuration=release ;;
    --bare) bare=true ;;
    --priority) priority=${2:?$usage}; shift ;;
    --no-preflight) unchecked=${2:?$usage}; shift ;;
    -*) echo "$usage" >&2; exit 97 ;;
    *.sh) scripts+=("${1#./}") ;;
    # The one word that is no script, and only in the last place: a script's name with a slip in it must not pass for a branch.
    *) [ $# -eq 1 ] || { echo "run.sh: '$1' is neither a script (*.sh) nor, in the last place, a ref" >&2; exit 97; }; ref=$1 ;;
  esac
  shift
done
[ ${#scripts[@]} -gt 0 ] || { echo "$usage" >&2; exit 97; }
case "$macs" in *[!0-9]* | 0) echo "run.sh: --macs takes a number, 1 or more" >&2; exit 97 ;; esac
case "$priority" in 1 | 2 | 3) ;; *) echo "run.sh: --priority takes 1, 2 or 3" >&2; exit 97 ;; esac
case "$configuration" in debug | release) ;; *) echo "run.sh: ARBOR_CONFIGURATION is debug or release, not '$configuration'" >&2; exit 97 ;; esac
[ "$configuration" = debug ] || [ "$bare" = false ] || { echo "run.sh: --bare builds nothing, so there is no release build to drive" >&2; exit 97; }
ref=${ref:-$(git rev-parse --abbrev-ref HEAD)}
[ "$ref" != HEAD ] || { echo "run.sh: no branch is checked out; name one: run.sh <script> <ref>" >&2; exit 97; }
limit=${MAC_SHELL_TIMEOUT:-2700}
script=${scripts[0]}

# Who runs what: one line for each Mac.
PER_MAC=4
if [ ${#scripts[@]} -eq 1 ]; then
  macs=${macs:-1}
  shares=$(for ((mac = 0; mac < macs; mac++)); do echo "$script"; done)
else
  macs=${macs:-$(((${#scripts[@]} + PER_MAC - 1) / PER_MAC))}
  [ "$macs" -le ${#scripts[@]} ] || macs=${#scripts[@]}
  [ $(((${#scripts[@]} + macs - 1) / macs)) -le $PER_MAC ] \
    || { echo "run.sh: ${#scripts[@]} scripts are more than $PER_MAC each for $macs Macs" >&2; exit 97; }
  # Dealt out like cards, so that neighbours in the list, which tend to be alike, do not all land on one Mac.
  shares=$(for ((mac = 0; mac < macs; mac++)); do
    for ((index = mac; index < ${#scripts[@]}; index += macs)); do printf '%s ' "${scripts[index]}"; done; echo
  done | sed 's/ $//')
fi

repo=$(git remote get-url origin | sed -E 's#^(https://[^/]*/|git@[^:]*:|ssh://[^/]*/)##; s#\.git$##; s#/$##')
api() { gh api "$@"; }
fail() { echo "run.sh: $1" >&2; exit "${2:-97}"; }

# What runs is what GitHub has at <ref>, so catch a forgotten push before a Mac is started.
remote=$(git ls-remote origin "refs/heads/$ref" 2>/dev/null | cut -f 1)
[ -n "$remote" ] || fail "GitHub has no branch '$ref' in $repo; push it first"
git cat-file -e "$remote^{commit}" 2>/dev/null || git fetch --quiet --no-tags origin "refs/heads/$ref" 2>/dev/null \
  || fail "cannot fetch '$ref' from $repo"
for each in "${scripts[@]}"; do
  case "$each" in *[!A-Za-z0-9._/-]*) fail "'$each': a script's path may hold letters, digits, dots, dashes, underscores and slashes" ;; esac
  git cat-file -e "$remote:$each" 2>/dev/null || fail "GitHub has no file '$each' at $ref (${remote:0:7}); commit and push it first"
done
# The workflow is one branch's for everybody, but lib.sh is <ref>'s own. One from before the switch takes no notice of it: the workflow would build release, and the
# script then build and drive debug, without a word: a number measured on the wrong program.
if [ "$configuration" != debug ] && git cat-file -e "$remote:scripts/mac-shell/lib.sh" 2>/dev/null \
  && ! git show "$remote:scripts/mac-shell/lib.sh" | grep -q 'swift build -c "\$ARBOR_CONFIGURATION"'; then
  fail "$ref's scripts/mac-shell/lib.sh is older than the switch for the $configuration build, and would drive debug whatever is asked: bring the branch up to date first"
fi
if [ "$ref" = "$(git rev-parse --abbrev-ref HEAD)" ]; then
  [ "$remote" = "$(git rev-parse HEAD)" ] || fail "$ref is at ${remote:0:7} on GitHub but $(git rev-parse --short HEAD) here; push first"
  [ -z "$(git status --porcelain -- scripts Sources Package.swift)" ] \
    || echo "run.sh: note: uncommitted changes under scripts/ or Sources/ will not be part of this run" >&2
fi

home=${MAC_SHELL_WORKFLOW_REF:-}
for candidate in swarm/trunk main; do
  [ -z "$home" ] || break
  git fetch --quiet --no-tags origin "+refs/heads/$candidate:refs/remotes/origin/$candidate" 2>/dev/null || continue
  ! git cat-file -e "origin/$candidate:.github/actions/mac-setup/action.yml" 2>/dev/null || home=$candidate
done
# Neither has the shared set-up yet: as it was before there was one.
home=${home:-$ref}
if [ "$home" != "$ref" ] && ! git diff --quiet "origin/$home" HEAD -- .github/workflows/mac-shell.yml .github/actions 'scripts/ci-*' 2>/dev/null; then
  echo "run.sh: note: the workflow and its set-up are $home's, not this branch's, which differ (MAC_SHELL_WORKFLOW_REF=$ref runs these)" >&2
fi

slug() { printf '%s' "$1" | tr -c 'A-Za-z0-9_-' '-' | cut -c "1-$2"; }
name=$(slug "$(basename "$script" .sh)" 16)
[ ${#scripts[@]} -eq 1 ] || name=$(slug "$name" 13)-x${#scripts[@]}
[ "$kind" = macos-26 ] || name=$(slug "$name" 9)-${kind#macos-}
# A tag of its own: the same script on the other build is another question, and must not cancel this one.
[ "$configuration" = debug ] || name=$(slug "$name" 12)-rel
tag=${MAC_SHELL_TAG:-$(slug "$ref" 21).$name}

# What Linux can say, it says first.
if [ -n "$unchecked" ]; then
  echo "without the pre-flight: $unchecked"
elif [ "$ref" = "$(git rev-parse --abbrev-ref HEAD)" ] && [ "$(uname -s)" = Linux ]; then
  if ! scripts/mac-shell/preflight.sh --check "${scripts[@]}" > /dev/null; then
    if command -v swift > /dev/null 2>&1; then
      scripts/mac-shell/preflight.sh "${scripts[@]}" || fail "the pre-flight failed: no Mac for what Linux can already refute (--no-preflight \"<why>\" if it must be)" 96
    else
      scripts/mac-shell/preflight.sh --check "${scripts[@]}" >&2
      echo "run.sh: there is no swift here. Where there is one, in this folder:  scripts/mac-shell/preflight.sh ${scripts[*]}" >&2
      fail "not started (--no-preflight \"<why>\" if it must be)" 96
    fi
  fi
fi

# Its turn. Only the answer "yes" lets it go. If the queue cannot be read, GitHub is most likely refusing calls because the hour's are used up, and
# if that meant "go", everybody who was holding back would start at once, at the worst moment. Priority 1 alone is not held up by what cannot be
# found out, and does not pay for finding out: it reads what somebody else saw of late, and goes if there is nothing to read.
start=$(date +%s)
told="" together="" yielded=0
# What the rules said when the waiting began.
rules=$(mktemp -d) || fail "no room for a temporary folder"
trap 'rm -rf "$rules"' EXIT
number=0
while IFS= read -r -d : file; do
  number=$((number + 1))
  [ -z "$file" ] || cp "$file" "$rules/$number" 2>/dev/null || : > "$rules/$number"
done <<< "${ARBOR_MAC_RULES:-}:"
# changed_rules: prints what has been added to them since, if anything has.
changed_rules() {
  local number=0 file
  while IFS= read -r -d : file; do
    number=$((number + 1))
    [ -n "$file" ] && ! cmp -s "$file" "$rules/$number" || continue
    echo "--- new in $(basename "$file"):"
    diff "$rules/$number" "$file" 2>/dev/null | sed -n 's/^> //p' | tail -n 20 | cut -c 1-400
  done <<< "${ARBOR_MAC_RULES:-}:"
}
# look <seconds> <command…>: what it says goes to $why, how it ends is how this ends; 124 if it has not ended by then. Not `$(…)`, and nobody waits for it: the
# look reads a file that several machines share, and a read that falls on the moment somebody else rewrites it has been seen to hang for good, in a state in
# which no signal reaches it. Whoever waited for that, or held the other end of its pipe, hung with it, silently, with no limit anywhere around. It is left behind.
look() {
  local patience=$(($1 * 10)) answer="$rules/look.$RANDOM"
  shift
  ( "$@" > "$answer.said" 2>/dev/null; echo $? > "$answer.ended" ) > /dev/null 2>&1 &
  while [ ! -s "$answer.ended" ] && [ "$patience" -gt 0 ]; do
    sleep 0.1
    patience=$((patience - 1))
  done
  [ -s "$answer.ended" ] || { why=""; return 124; }
  why=$(cat "$answer.said")
  return "$(cat "$answer.ended")"
}
while :; do
  # While work goes to main, its checks come first (hold.txt, docs/PUBLIC.md). Only the answer "held" holds: where nobody can tell, the queue decides.
  # Priority 1 does not ask that; the queue it does ask, for a train that is waiting for a Mac or on its way to one.
  held=""
  if [ "$priority" != 1 ]; then
    why=$(python3 scripts/public-check.py --rules 2>/dev/null | sed -n '1s/^[^A-Za-z]*//p'; exit "${PIPESTATUS[0]}")
    [ $? -ne 1 ] || held=yes together=yes
  fi
  if [ -z "$held" ]; then
    # shellcheck disable=SC2046
    look "${MAC_SHELL_LOOK:-60}" python3 scripts/mac-queue.py --repo "$repo" --turn "$priority" --for "$ref" --tag "$tag" $([ "$priority" != 1 ] || echo --known)
    case $? in
      0)
        # When what held everybody back is over, all who waited would let go in the same minute, in the order their timers fire, and take the Macs from
        # under whatever is more urgent and about to be started. So priority 1 goes at once, 2 a look later, 3 two looks later, and each asks again then.
        if [ -n "$together" ] && [ "$yielded" -lt $((priority - 1)) ]; then
          yielded=$((yielded + 1))
          why="what held everybody back is over: priority 1 goes first, this has priority $priority"
        else
          break
        fi ;;
      4) ;;
      5) together=yes yielded=0 ;;
      *) [ "$priority" != 1 ] || break
        why="the queue for the Macs cannot be read (are GitHub's calls for this hour used up? gh api rate_limit says, and costs none)" ;;
    esac
  fi
  [ $(($(date +%s) - start)) -le "$limit" ] || fail "not started after ${limit}s: $why" 98
  [ "$why" = "$told" ] || echo "holding back: $why"
  told=$why
  # Seldom, and not all copies at the same moment: every look costs calls.
  sleep "$((${MAC_SHELL_POLL:-120} + RANDOM % (${MAC_SHELL_POLL:-120} / 4 + 1)))"
done
# Whoever has waited acts on what was true when the waiting began. If the rules have been written to since, that is for a reader to weigh, not for a timer.
if [ -n "$told" ]; then
  new=$(changed_rules)
  if [ -n "$new" ]; then
    echo "$new"
    fail "not started: the rules have changed while this run held back. Read what is new, then start it again" 95
  fi
fi

# What the output branches hold now, which may be an earlier run's: a change is the sign that a Mac has finished.
outputs() { git ls-remote origin "refs/heads/mac-shell-out/$tag" "refs/heads/mac-shell-out/$tag.*" 2>/dev/null | sort; }
before=$(outputs)

# The dispatch call does not say which run it started: it is the one newer than the newest so far
# whose title carries the tag.
runs="repos/$repo/actions/workflows/mac-shell.yml/runs?event=workflow_dispatch&per_page=30"
newest=$(api "$runs" --jq '.workflow_runs[0].id // 0') || fail "cannot list the workflow's runs"
# Said only where it is asked for: GitHub refuses a start with an input the workflow does not know, and $home's may be an older one.
other=()
[ "$configuration" = debug ] || other=(-f "inputs[configuration]=$configuration")
api -X POST "repos/$repo/actions/workflows/mac-shell.yml/dispatches" \
  -f ref="$home" -f "inputs[ref]=$ref" -f "inputs[script]=${scripts[*]}" -f "inputs[tag]=$tag" ${other[@]+"${other[@]}"} \
  -f "inputs[runner]=$kind" -F "inputs[bare]=$bare" -f "inputs[unchecked]=$(printf '%s' "$unchecked" | tr -c 'A-Za-z0-9 .,:_/-' ' ' | cut -c 1-80)" \
  -f "inputs[macs]=$([ "$macs" -eq 1 ] || echo "$shares" | sed 's/.*/"&"/' | paste -sd, - | sed 's/.*/[&]/')" >/dev/null \
  || fail "could not start the workflow of $home for $ref"
echo "started ${scripts[*]} at $ref (${remote:0:7}), tag $tag$([ "$macs" -eq 1 ] || echo ", on $macs Macs")$([ "$configuration" = debug ] || echo ", the $configuration build")"
# For whoever shares a look at the queue: there is one more waiting now. Costs no call.
look 20 python3 scripts/mac-queue.py --repo "$repo" --started "$macs" --for "$ref"

start=$(date +%s)
run=""
while [ -z "$run" ]; do
  [ $(($(date +%s) - start)) -gt 180 ] && fail "the run did not appear within 3 minutes" 98
  sleep 6
  run=$(api "$runs" --jq ".workflow_runs[] | select(.id > $newest and (.display_title | endswith(\"[$tag]\"))) | .id" \
    2>/dev/null | tail -n 1)
done
echo "run $run: https://github.com/$repo/actions/runs/$run"

# Every Mac pushes its output as its last deed, so Git tells when they have finished. GitHub itself is asked only now and then, for the run
# that ends without any output: cancelled while it waited, or stopped before its first step. The longer the wait the more rarely, after 3, 6, 12, 24 and
# then every 30 minutes: every three minutes is twenty calls an hour for each run that waits, to hear twenty times that nothing has happened.
#
# The time limit is this script's patience. It used to cancel the run, counted from the start: GitHub has handed out no Mac for twenty minutes on end, and
# then a run lost its place in the line, or the minutes its Mac had already spent, to its own waiter.
let_go() {
  local some=$tag
  [ "$macs" -eq 1 ] || some="$tag.1 (to .$macs)"
  cat >&2 <<END
run.sh: still $1 after ${limit}s. NOT CANCELLED: the run keeps its place and goes on without this waiter.
  has it ended?       git ls-remote origin 'refs/heads/mac-shell-out/$tag*'      (a branch for each Mac, as its last deed)
  what it brought:    git fetch origin mac-shell-out/$some && git archive FETCH_HEAD | tar -x -C <a folder>
  cancel it by hand:  gh api -X POST repos/$repo/actions/runs/$run/cancel
END
  exit 98
}
status="" asked=$(date +%s) every=${MAC_SHELL_ASK:-180} dispatched=$start begun=""
# From the moment it is known to have its Mac the time counts anew, once.
has_begun() { [ -n "$begun" ] || [ "$status" != in_progress ] || { begun=yes start=$(date +%s); }; }
while [ "$status" != completed ]; do
  if [ $(($(date +%s) - start)) -gt "$limit" ]; then
    [ -z "$begun" ] || let_go "under way"
    status=$(api "repos/$repo/actions/runs/$run" --jq .status 2>/dev/null)
    has_begun
    [ "$status" != completed ] || break
    [ -n "$begun" ] || let_go "waiting for a Mac"
    continue
  fi
  sleep "${MAC_SHELL_STEP:-15}"
  if [ "$(comm -13 <(echo "$before") <(outputs) | grep -c .)" -ge "$macs" ]; then
    # The job has a few steps left after the push.
    sleep 10
    break
  fi
  if [ $(($(date +%s) - asked)) -ge "$every" ]; then
    asked=$(date +%s)
    every=$((every * 2 < 1800 ? every * 2 : 1800))
    status=$(api "repos/$repo/actions/runs/$run" --jq .status 2>/dev/null)
    has_begun
  fi
done
conclusion=$(api "repos/$repo/actions/runs/$run" --jq '.conclusion // .status' 2>/dev/null)
echo "finished after $(($(date +%s) - dispatched))s: ${conclusion:-GitHub does not say how}"

annotations() {
  for job in $(api "repos/$repo/actions/runs/$run/jobs" --jq '.jobs[].id'); do
    api "repos/$repo/check-runs/$job/annotations?per_page=50" \
      --jq '.[] | "[\(.annotation_level)] \(.title // "")\n\(.message)"' | cut -c 1-400
  done
}

# bring_back <tag> <folder>: what one Mac pushed. The branch may hold an earlier run's output; the commit message says whose it is.
bring_back() {
  local branch="mac-shell-out/$1"
  git fetch --quiet --no-tags origin "+refs/heads/$branch:refs/mac-shell/$1" 2>/dev/null
  case "$(git log -1 --format=%s "refs/mac-shell/$1" 2>/dev/null)" in
    *"(run $run)") ;;
    *) git update-ref -d "refs/mac-shell/$1" 2>/dev/null; return 1 ;;
  esac
  mkdir -p "$2"
  git archive "refs/mac-shell/$1" | tar -x -C "$2"
  git update-ref -d "refs/mac-shell/$1"
  api -X DELETE "repos/$repo/git/refs/heads/$branch" >/dev/null 2>&1 \
    || echo "(this environment may not delete branches: $branch stays until the next run replaces it)"
}

directory=".mac-shell/$name-$run"
code="" missing=0
for ((mac = 1; mac <= macs; mac++)); do
  if [ "$macs" -eq 1 ]; then from=$tag into=$directory; else from=$tag.$mac into=$directory/mac-$mac; fi
  if ! bring_back "$from" "$into"; then
    missing=$((missing + 1))
    continue
  fi
  its=$(cat "$into/exit-code.txt" 2>/dev/null)
  [ "$macs" -eq 1 ] || echo "Mac $mac: exit code ${its:-unknown (cut off)}: $(echo "$shares" | sed -n "${mac}p")"
  case "$code" in "" | 0) code=$its ;; esac
  [ -n "$its" ] || missing=$((missing + 1))
done
if [ ! -d "$directory" ]; then
  echo "the run pushed no output; its annotations:"
  annotations
  exit 99
fi

# A section that never got to a claim says nothing new, so it does not replace what is there.
copied=""
if [ "${ARBOR_KEEP_EVIDENCE:-}" = 1 ]; then
  # One Mac's output lies in the folder itself, that of several in mac-1/, mac-2/…
  for evidence in "$directory"/evidence/*.txt "$directory"/mac-*/evidence/*.txt; do
    section=$(basename "$evidence" .txt)
    if [ -f "$evidence" ] && [ -f "scripts/mac-shell/suite/$section.sh" ] && grep -q '^▸ ' "$evidence"; then
      cp "$evidence" "collab/evidence/suite-$section-latest.txt" && copied="$copied $section"
    fi
  done
fi

echo
if [ ${#scripts[@]} -eq 1 ] && [ "$macs" -eq 1 ]; then
  echo "--- end of $directory/output.txt"
  tail -n "${MAC_SHELL_TAIL:-40}" "$directory/output.txt" 2>/dev/null
  echo "---"
else
  cat "$directory"/summary.txt "$directory"/mac-*/summary.txt 2>/dev/null
fi
echo "output: $PWD/$directory"
ls "$directory" | sed 's/^/  /'
[ -z "$copied" ] || echo "evidence copied to collab/evidence/suite-*-latest.txt:$copied (next: scripts/mac-shell/suite-parity.py)"
if [ "$missing" -gt 0 ] || [ -z "$code" ]; then
  echo "exit code: unknown (cut off, or a Mac brought nothing back: $conclusion)"
  exit 99
fi
echo "exit code: $code"
exit "$code"
