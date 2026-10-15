#!/bin/bash
# All frames of one act in one breath, on film. scripts/mac-shell/probe-breath.sh asked the window server, which said that windows
# asked side by side arrive hardly closer together than windows asked one by one. But it is busy at that very moment, and what a
# person sees is the display. So the same acts are filmed, sixty frames a second, and scripts/polish/judge.py counts the pieces.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/films-breath.sh         then: python3 scripts/polish/judge.py acts .mac-shell/films-breath-<run>
#
# The question only a Mac can answer: in how many frames of the display do eight windows of four apps arrive, from a pile in a grid and
# back, when they are asked one by one as Arbor asks today, side by side, without waiting, and with two calls a window for three?
# Arbor is started, because the cast comes with it, and paused at once: it watches nothing and moves nothing.
# For GitHub's Macs only (lib-film.sh films the whole display). About five minutes after the build.
source "$(dirname "$0")/lib-film.sh"

step "the Mac"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m), $(sysctl -n hw.ncpu) cores"
film_build
BREATH="$ARBOR_ROOT/.build/mac-shell/breath"
if [ -z "${ARBOR_REHEARSAL:-}" ]; then
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/breath.swift" -o "$BREATH" > "$ARBOR_OUT/build-breath.log" 2>&1 \
    || { cat "$ARBOR_OUT/build-breath.log"; die "scripts/mac-shell/breath.swift did not compile"; }
fi
macos_reduce_motion off
cast_build
display_size 1920 1080
camera_start || die "no camera"
cast_start 8
ctl pause
PIDS="$(echo "${ARBOR_EXTRA_PIDS:-}" | tr ',' ' ') $ARBOR_WINDOWS_PID"
echo "the cast's processes: $PIDS"

# act <way> <grid|pile> <n>
act() {
  scene "$1-to-the-$2-$3" instant "eight windows are sent to the $2, $1" || return 1
  if [ -n "${ARBOR_REHEARSAL:-}" ]; then
    echo "a rehearsal has no Accessibility to ask"
  else
    # shellcheck disable=SC2086
    limit 30 "$BREATH" "$1" "$2" $PIDS
  fi
  scene_end 1
}

# shellcheck disable=SC2086
[ -n "${ARBOR_REHEARSAL:-}" ] || limit 30 "$BREATH" one-by-one pile $PIDS > /dev/null
sleep 1
for n in 1 2 3; do
  for way in one-by-one side-by-side no-wait one-by-one-in-two side-by-side-in-two; do
    act "$way" grid "$n"
    act "$way" pile "$n"
  done
done

cast_stop
camera_stop
exit 0
