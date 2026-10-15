#!/bin/bash
# Can the window itself be seen moving? A probe: Arbor does not run, and nothing of Arbor's is changed by what it finds until somebody decides.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-glide.sh          on one of GitHub's Macs, from anywhere: six minutes
#
# Arbor's motion shows cards on a stage while the real windows are moved once, underneath. A picture of the window in the card's place needs Screen Recording,
# which Arbor never asks for. What is left is to move THE REAL WINDOW IN STEPS through Accessibility, which Arbor has anyway (glide.swift).
# THE QUESTIONS ONLY A MAC CAN ANSWER: how long does each of the day's nine apps take to answer a call that moves its window? Of 8 and of 12 places asked for in
# 0.2 s, how many does the window server ever show, and how long does the window stand still between two? Does the app lay its content out again on the way? Does it end
# where it was asked to? How far apart are 2 and 4 windows that move together, and what does a thread for each app gain? What does it cost the processor? Each
# with a CONTROL: the same move in one call, as Arbor moves windows with its motion off. And beside it, for the other road: how long do pictures of 1, 4 and 8 windows take?
# WHAT LINUX PROVES (rehearse.sh): that this script gets to its end, that glide.swift (all but its forty lines of Accessibility) paces, counts and writes as its header
# says, and that the judge reads it. Nothing about any app: rehearse/real-apps makes them up.
# WHAT IS JUDGED AFTERWARDS, by judge-glide.py, whose header has the limits (`judge-glide.py <folder>`, on any machine, with other limits if wanted): glide.log (every call),
# samples.log (what the window server showed, 120 times a second), cpu.log, pictures.txt. verdict.txt is what it said on the Mac. If two apps of nine stutter, this road is closed.
# To look at: film-glide-<n>.png and film-control-<n>.png, four windows on their way, about 70 ms apart; <nnn>-open-<app>.jpg, what each app put up.
#
# Only on GitHub's Macs: it opens real apps, moves and resizes their windows, quits them, and switches Reduce Motion and the display's size.
# The apps alone come first: what is cut off is the sets, the films and the pictures, and what is there can still be judged.
ARBOR_TIME_LIMIT=450
# Twice the display's rate: a place that was there for a whole frame cannot fall between two samples.
DAY_HZ=120
# Two samples' time. What the sampler did not see is held against no app.
DAY_LATE=17
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
needs_throwaway_mac "open nine real apps, move and resize their windows, quit them, and switch Reduce Motion and the display's size"

TOOLS="$ARBOR_ROOT/.build/mac-shell"
LOG="$ARBOR_OUT/glide.log"
ACT=0
PLAYERS=""
# As the sampler is started (lib-day.sh): what the runner's agent starts counts as work in the background, whose timers come late.
TIERS=""
if command -v taskpolicy > /dev/null; then TIERS="taskpolicy -l 0 -t 0"; fi

compile() { swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/$1.swift" -o "$TOOLS/$1" > "$ARBOR_OUT/build-$1.log" 2>&1; }

# The processor time of the apps that move and of the window server, to a hundredth of a second: what `ps` has.
cpu() {
  local name
  for name in $PLAYERS; do echo "$1 $2 $name $(day_cpu_seconds "$(pid_of "$name")")"; done >> "$ARBOR_OUT/cpu.log"
  [ -z "$SERVER" ] || echo "$1 $2 server $(day_cpu_seconds "$SERVER")" >> "$ARBOR_OUT/cpu.log"
}

# play <who> <steps> <order> <window>:<x>,<y>[,<w>,<h>]…: one act, called <who>.<n>. One step is the control.
# FILM=<name>: pictures are taken meanwhile.
play() {
  local who=$1 steps=$2 order=$3 duration=0.2 glide
  shift 3
  [ "$steps" -gt 1 ] || duration=0
  ACT=$((ACT + 1))
  cpu "$who.$ACT" before
  note "glide $who.$ACT"
  # shellcheck disable=SC2086
  $TIERS "$TOOLS/glide" "$LOG" "$who.$ACT" --steps "$steps" --duration "$duration" --order "$order" "$@" 5<&- 6>&- &
  glide=$!
  [ -z "${FILM:-}" ] || film "$FILM" 6
  wait "$glide" || echo "  ✘ glide $who.$ACT ended with exit code $?"
  quiet 300 2000 || echo "  ~ windows were still moving after ${QUIET#*:} ms"
  cpu "$who.$ACT" after
}

# In front, so that it is drawn, and where its road begins.
place() {
  apptool activate "$(pid_of "$1")"
  apptool raise "$(window_of "$1")"
  apptool set-frame "$(window_of "$1")" "$2" "$3" "$4" "$5" > /dev/null
}

# alone <app>: 500 points there and back; the control, 8 steps and 12; then all of it with a change of size.
alone() {
  local window steps
  window=$(window_of "$1")
  step "$1 alone (w$window)"
  PLAYERS=$1
  place "$1" 60 80 700 500
  quiet 300 2000
  for steps in 1 8 12; do
    play "$1" "$steps" by-window "$window:540,220"
    play "$1" "$steps" by-window "$window:60,80"
  done
  for steps in 1 8 12; do
    play "$1" "$steps" by-window "$window:540,220,620,440"
    play "$1" "$steps" by-window "$window:60,80,700,500"
  done
}

# roads <app…>: puts the windows in a cascade and sets THERE and BACK, the two ends of their roads.
roads() {
  local name index=0
  PLAYERS="$*" THERE="" BACK=""
  for name in "$@"; do
    place "$name" $((40 + index * 50)) $((60 + index * 40)) 560 400
    BACK="$BACK $(window_of "$name"):$((40 + index * 50)),$((60 + index * 40))"
    THERE="$THERE $(window_of "$name"):$((520 + index * 50)),$((200 + index * 40))"
    index=$((index + 1))
  done
  quiet 300 2000
}

# together <who> <app…>: windows of different apps at once, in both orders.
together() {
  local who=$1 steps
  shift
  step "$who: $*"
  roads "$@"
  # shellcheck disable=SC2086
  for steps in 1 8 12; do
    play "$who" "$steps" by-window $THERE
    play "$who" "$steps" by-window $BACK
    play "$who" "$steps" threads $THERE
    play "$who" "$steps" threads $BACK
  done
}

step "the Mac"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m), $(sysctl -n hw.ncpu) cores"
mkdir -p "$TOOLS"
compile glide &
first=$!
compile picture-time &
second=$!
day_build_tools
wait "$first" || { grep -A 6 "error:" "$ARBOR_OUT/build-glide.log" | head -n 60; die "scripts/mac-shell/glide.swift did not compile"; }
wait "$second" || { grep -A 6 "error:" "$ARBOR_OUT/build-picture-time.log" | head -n 60; echo "picture-time.swift did not compile: on without it"; }
display_mode 1440x900 1600x900 1680x1050 1920x1080
# As the day is played: GitHub's Macs come with Reduce Motion on, a person's Mac does not.
macos_reduce_motion off
SERVER=$(pgrep -x WindowServer | head -n 1)
day_scratch
sampler_start

chapter "The apps are open already"
for name in $(members_of stock); do walk_open "$name"; done
sleep 3
# An app may have swapped the window it opened with for another meanwhile, as Mail does (lib-walk.sh).
for name in $WALK_CAST; do
  listed=$(app_windows "$(pid_of "$name")")
  case " $listed " in
    *" $(window_of "$name") "*) ;;
    *) [ -z "$listed" ] || { eval "W_$name=\${listed%% *}"; label "$(window_of "$name")" "$name"; } ;;
  esac
done
echo "the cast:$WALK_CAST"
for name in $WALK_CAST; do echo "  $name is $(bundle_of "$name"), pid $(pid_of "$name"), w$(window_of "$name")"; done
# shellcheck disable=SC2086
set -- $WALK_CAST
check "all nine apps opened a window" test $# -eq 9
[ $# -ge 4 ] || die "only $# apps opened a window: nothing to measure"

for name in $WALK_CAST; do alone "$name"; done
together two "$1" "$2"
together four "$1" "$2" "$3" "$4"
# The other end of the cast, if it is another four.
[ $# -lt 8 ] || together four-more "${@:$#-3}"

step "two films: four windows in twelve steps, and the control"
roads "$1" "$2" "$3" "$4"
# shellcheck disable=SC2086
FILM=film-glide play film 12 by-window $THERE
# shellcheck disable=SC2086
FILM=film-control play film 1 by-window $BACK

step "how long pictures take"
if [ -x "$TOOLS/picture-time" ]; then
  # shellcheck disable=SC2046
  limit 90 "$TOOLS/picture-time" $(for name in $WALK_CAST; do window_of "$name"; done) | tee "$ARBOR_OUT/pictures.txt"
fi

sampler_stop
step "the judge"
python3 "$ARBOR_ROOT/scripts/mac-shell/judge-glide.py" "$ARBOR_OUT" | tee "$ARBOR_OUT/verdict.txt"
check "the judge could read what the run leaves" grep -q "^verdict: " "$ARBOR_OUT/verdict.txt"
