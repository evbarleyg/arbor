#!/bin/bash
# All frames of one act in one breath: what does macOS allow? Without motion, eight windows that Arbor arranges arrive one by one, in
# seven pieces of a film at sixty frames a second. A trace of that act: each `setFrame` that RESIZES a window takes 4 to 27 ms (one
# that only moves it: 0.9 ms), and each is waited for before the next is sent. That time is the app's own, laying out its content.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-breath.sh
#
# The question only a Mac can answer: if the apps are asked side by side, do their windows arrive together? And which way of asking
# does it: a thread to an app, or calls that are sent and not waited for? Arbor does not run: scripts/mac-shell/breath.swift asks
# Accessibility itself, in Arbor's order (size, position, size, the frame read back), and watches the window server meanwhile.
#
# Eight test windows, two to a process, four processes. Each way takes them six times from a pile to a grid or back. The ways take
# turns, and the first comes once more at the end: a hosted Mac drifts within minutes.
# Safe on a person's Mac: it starts its own test windows and moves no others; no setting is changed. Two minutes after the build.
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

step "four processes of two windows"
scratch_dir breath BREATH_DIR
PIDS=""
for index in 1 2 3 4; do
  mkfifo "$BREATH_DIR/stdin$index"
  "$ARBOR_BIN/ArborTestWindows" --count 2 < "$BREATH_DIR/stdin$index" > "$BREATH_DIR/hello$index" 2>> "$ARBOR_OUT/test-windows.log" \
    3>&- 4>&- 5>&- 6>&- &
  started $!
  # The process lives until its stdin closes, so this shell holds the other end (descriptors 3 to 6).
  eval "exec $((index + 2))> \"$BREATH_DIR/stdin$index\""
  tries=0
  until [ -s "$BREATH_DIR/hello$index" ] || [ "$tries" -ge 100 ]; do
    sleep 0.1
    tries=$((tries + 1))
  done
  pid=$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["pid"])' "$(head -n 1 "$BREATH_DIR/hello$index")" 2> /dev/null) \
    || die "ArborTestWindows $index did not report its windows"
  PIDS="$PIDS $pid"
done
echo "processes:$PIDS"
sleep 1

if [ -n "${ARBOR_BUILT:-}" ]; then
  echo "a rehearsal has no Accessibility to ask: the tool is type-checked, not run"
else
  # The first run's answer: side by side halves the wait and hardly changes what shows. But Arbor's own eight calls take 94 ms where
  # these take 15 to 34. What Arbor has and this had not: it listens to the windows it moves.
  for turn in 1 2 3; do
    for pair in one-by-one:nobody one-by-one:main one-by-one:thread side-by-side:main side-by-side:thread; do
      step "${pair%%:*}, ${pair##*:} listening, turn $turn"
      # shellcheck disable=SC2086
      BREATH_OBSERVED=${pair##*:} limit 60 "$BREATH" "${pair%%:*}" 6 $PIDS
      sleep 1
    done
  done
fi

for index in 1 2 3 4; do eval "exec $((index + 2))>&-"; done
exit 0
