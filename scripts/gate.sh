#!/bin/bash
# Everything a change must pass on Linux before it is pushed, each thing once and on every core: `make gate`.
#
#   scripts/gate.sh             lint, build, the tests, whatever else `make check` runs (smoke, privacy, scenarios, the tools' self-tests …),
#                               the type-check of the macOS-only code, parity (which rewrites docs/FEATURES.md, as `make parity` does)
#   scripts/gate.sh --check     parity fails if docs/FEATURES.md is out of date instead of rewriting it, as CI does
#
# It proves what `make check scenarios parity typecheck-mac lint` proves. That runs the tests twice (`make parity` once more),
# each time on one core of four, because nearly every test is bound to the main actor, and the scenarios twice. Here the tests run
# once, a process to a file, as many at a time as there are cores (scripts/fast-tests.py), parity reads what they left, and what
# does not need one another's results runs side by side. On four cores, with the build up to date: four minutes instead of thirteen.
# What else `make check` runs it reads from the Makefile, so a step added there is a step here, with nobody's help.
#
# Every step runs, whatever became of the others, unless the build failed: one round tells all there is to tell. A line for each, with its
# seconds; of a step that failed, the end of its output. All output: .build/gate/<step>.log. Exit code 1 if any step failed.
# On Linux only: on a Mac `make check` sees the real thing.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
logs=.build/gate

# step <name> <command…>: runs it, keeps its output, says how it went. Leaves <name>.failed behind when it failed.
step() {
  local name=$1 start=$SECONDS
  shift
  if "$@" > "$logs/$name.log" 2>&1; then
    printf '  ✔ %-18s %4d s   %s\n' "$name" $((SECONDS - start)) "$(grep -v -e '^[[:space:]]*$' -e '^make\[' "$logs/$name.log" | tail -1 | cut -c 1-120)"
  else
    local code=$?
    : > "$logs/$name.failed"
    printf '  ✘ %-18s %4d s   exit code %d; the end of %s:\n' "$name" $((SECONDS - start)) "$code" "$logs/$name.log"
    tail -25 "$logs/$name.log" | sed 's/^/      /'
  fi
}

# All in a function, which bash reads to its end before it runs any of it. A script is otherwise read as it goes, and a rebase in
# the minutes this takes would put other lines under its feet.
gate() {
  [ "$(uname -s)" = Linux ] || { echo "gate.sh is for Linux (scripts/fast-tests.py knows only its test runners); on a Mac: make check scenarios parity"; exit 2; }
  parity=()
  case "${1:-}" in
    "") ;;
    --check) parity=(--check) ;;
    *) sed -n '2,7p' "$0"; exit 64 ;;
  esac

  rm -rf "$logs"
  mkdir -p "$logs"
  began=$SECONDS
  # What runs in the background does not hear Ctrl-C by itself, and would go on compiling, and rewrite docs/FEATURES.md, after this has gone.
  trap 'trap - TERM; echo "the gate was interrupted"; kill 0' INT TERM

  step lint make lint
  step build swift build --build-tests
  if [ -e "$logs/build.failed" ]; then
    grep -E 'error:' "$logs/build.log" | sort -u | head -20 | sed 's/^/      /'
    echo "the gate is shut: it does not build ($((SECONDS - began)) s)"
    exit 1
  fi

  # By themselves: some of them hold Arbor to a budget of milliseconds, and the smoke runs give a process fractions of a second to answer.
  step tests ./scripts/fast-tests.py run --no-build --log "$logs/test-output.log"

  # The rest of `make check`: what it depends on besides lint, build and test, then the lines of its recipe, one after another as there.
  # But the tools' self-test, which takes two minutes and mostly waits for processes it started: that goes beside the compiler, below.
  local rule needed line name beside=""
  rule=$(sed -n '/^check:/,/^$/p' Makefile)
  for needed in $(sed -n '1s/^check://p' <<<"$rule"); do
    case "$needed" in lint | build | test) ;; *) step "$needed" make "$needed" ;; esac
  done
  while IFS= read -r line; do
    name=$(grep -oE 'scripts/[A-Za-z0-9._/-]+' <<<"$line" | head -1)
    name=$(basename "${name:-${line%% *}}")
    name=${name%.*}
    case "$line" in
      # Only make knows what its variables stand for.
      *'$'*) step "$name" sh -c 'echo "gate.sh cannot run this line of make check by itself, for the \$ in it: $1"; exit 2' sh "$line" ;;
      *scripts/test-tooling.py) beside=$line ;;
      *) step "$name" bash -c "$line" ;;
    esac
  done < <(sed -n 's/^\t@\{0,1\}//p' <<<"$rule")
  [ -n "$rule" ] || step check sh -c 'echo "the Makefile has no rule for check"; exit 2'

  # Side by side: the compiler, on every core it can get, and what mostly waits.
  step typecheck-mac make typecheck-mac &
  [ -z "$beside" ] || step test-tooling bash -c "$beside" &
  if [ -e "$logs/tests.failed" ]; then
    echo "  – parity                    not asked: it goes by the tests, which failed"
  else
    step parity python3 scripts/parity.py --test-log "$logs/test-output.log" ${parity[@]+"${parity[@]}"} &
  fi
  wait

  failed=$(cd "$logs" && ls ./*.failed 2>/dev/null | sed 's#^\./##; s#\.failed$##' | tr '\n' ' ')
  if [ -n "$failed" ]; then
    echo "the gate is shut: ${failed% } ($((SECONDS - began)) s)"
    exit 1
  fi
  echo "the gate is open ($((SECONDS - began)) s)"
}

gate "$@"
