#!/bin/bash
# Why do Arbor's eight calls take 94 ms where macOS answers the same eight in 15 to 30? Without motion, eight windows that Arbor arranges
# arrive in seven pieces of a film; asked by scripts/mac-shell/breath.swift in the same order of calls, they arrive in two to five.
# Asking side by side does not help what shows, and neither does it matter whether anybody listens to the windows meanwhile (both
# measured). So what is left to gain is Arbor's own share of the time between the first call and the last.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-arrange.sh
#
# The question only a Mac can answer: where is Arbor's main thread between the first `setFrame` of an `arrange` and the last?
# Eight test windows, two to a process, four processes; Arbor without motion, as the second build ships. Six times `arrange` and
# `float-all` while `sample` watches and a trace records when each call ended. Then Arbor is paused and the bare tool takes the same
# windows from a pile to a grid and back six times: like with like, on one Mac, minutes apart. Then Arbor once more.
# Safe on a person's Mac: its own test windows and an Arbor limited to them; no setting is changed. Three minutes after the build.
source "$(dirname "$0")/lib.sh"

step "the Mac"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m), $(sysctl -n hw.ncpu) cores"
arbor_build
BREATH="$ARBOR_ROOT/.build/mac-shell/breath"
if [ -z "${ARBOR_BUILT:-}" ]; then
  mkdir -p "$ARBOR_ROOT/.build/mac-shell"
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/breath.swift" -o "$BREATH" > "$ARBOR_OUT/build-breath.log" 2>&1 \
    || { cat "$ARBOR_OUT/build-breath.log"; die "scripts/mac-shell/breath.swift did not compile"; }
fi

step "three processes of two windows, and Arbor's own two"
scratch_dir arrange ARRANGE_DIR
PIDS=""
for index in 1 2 3; do
  mkfifo "$ARRANGE_DIR/stdin$index"
  "$ARBOR_BIN/ArborTestWindows" --count 2 < "$ARRANGE_DIR/stdin$index" > "$ARRANGE_DIR/hello$index" 2>> "$ARBOR_OUT/test-windows.log" \
    3>&- 4>&- 5>&- &
  started $!
  # The process lives until its stdin closes, so this shell holds the other end (descriptors 3 to 5).
  eval "exec $((index + 2))> \"$ARRANGE_DIR/stdin$index\""
  tries=0
  until [ -s "$ARRANGE_DIR/hello$index" ] || [ "$tries" -ge 100 ]; do
    sleep 0.1
    tries=$((tries + 1))
  done
  pid=$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["pid"])' "$(head -n 1 "$ARRANGE_DIR/hello$index")" 2> /dev/null) \
    || die "ArborTestWindows $index did not report its windows"
  PIDS="$PIDS $pid"
done
arbor_settings '{"animationDuration": 0, "focusRing": false}'
# shellcheck disable=SC2086
ARBOR_EXTRA_PIDS=$(echo $PIDS | tr ' ' ',') arbor_start 2
PIDS="$PIDS $ARBOR_WINDOWS_PID"
echo "processes:$PIDS"
sleep 2

# acts <name>: six times arrange and float-all, sampled and traced.
acts() {
  local tries=0 n
  step "Arbor arranges and lets go, six times: $1"
  ctl trace on "arrange-$1"
  if command -v sample > /dev/null 2>&1; then
    sample "$ARBOR_PID" 16 1 -mayDie -file "$ARBOR_OUT/sample-$1.txt" > "$ARBOR_OUT/sample-$1.says" 2>&1 &
    started $!
    until grep -q "^Sampling process" "$ARBOR_OUT/sample-$1.says" || [ "$tries" -ge 60 ]; do
      sleep 0.25
      tries=$((tries + 1))
    done
  fi
  for n in 1 2 3 4 5 6; do
    "$ARBOR_BIN/arborctl" arrange > /dev/null 2>&1
    sleep 1
    "$ARBOR_BIN/arborctl" float-all > /dev/null 2>&1
    sleep 1
  done
  ctl trace off
  tries=0
  while [ ! -s "$ARBOR_OUT/sample-$1.txt" ] && [ "$tries" -lt 60 ] && command -v sample > /dev/null 2>&1; do
    sleep 0.5
    tries=$((tries + 1))
  done
  "$ARBOR_BIN/arborctl" stats > "$ARBOR_OUT/stats-$1.txt" 2>&1
}

acts first
step "the bare tool, with Arbor paused"
ctl pause
if [ -n "${ARBOR_BUILT:-}" ]; then
  echo "a rehearsal has no Accessibility to ask"
else
  # As it was measured before; then left alone for two seconds between the acts, as Arbor's acts are; then with Arbor's question to the app.
  # shellcheck disable=SC2086
  BREATH_EACH=1 limit 60 "$BREATH" one-by-one 6 $PIDS
  # shellcheck disable=SC2086
  BREATH_EACH=1 BREATH_REST=2 limit 60 "$BREATH" one-by-one 6 $PIDS
  # shellcheck disable=SC2086
  BREATH_EACH=1 BREATH_REST=2 BREATH_GUARD=1 limit 60 "$BREATH" one-by-one 6 $PIDS
  # shellcheck disable=SC2086
  BREATH_REST=2 BREATH_GUARD=1 limit 60 "$BREATH" side-by-side 6 $PIDS
fi
ctl resume
sleep 2
acts again

mkdir -p "$ARBOR_OUT/traces"
cp "$ARBOR_HOME"/traces/*.jsonl "$ARBOR_OUT/traces/" 2> /dev/null
arbor_log
arbor_stop
for index in 1 2 3; do eval "exec $((index + 2))>&-"; done
exit 0
