#!/bin/bash
# Can the window itself be seen moving, as macOS's own tiling moves it? A probe: Arbor does not run, and nothing of Arbor's changes by what it finds until somebody decides.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-glide.sh          on one of GitHub's Macs, from anywhere: six minutes
#
# Arbor's motion shows cards on a stage while the real windows are moved once, underneath. A picture of the window in the card's place needs Screen Recording, which Arbor
# never asks for. macOS's own tiling moves the real window: it glides and grows for 0.3 s, a new frame with every frame of the display, four edges in step. What is left to Arbor
# is to SET THE REAL WINDOW'S FRAME ONCE FOR EVERY FRAME OF THE DISPLAY through Accessibility, which it has anyway: two askings each time, place and size (glide.swift).
# THE QUESTIONS ONLY A MAC CAN ANSWER, of each of the day's nine apps alone: of 18 frames asked for in 0.3 s, how many does the window server ever show, and how long does the window
# stand still between two? Which order of the two askings keeps the edges in step, and what shows between them? What does it cost the processor? Where does it end? Each beside a
# CONTROL (the frame set once, as Arbor does with its motion off, in either order) and beside THE BAR (macOS's own Window > Move & Resize > Left on the same window). Then two
# windows: one glides, the other is set once. And for the other road: how long do pictures of 1, 4 and 8 windows take?
# WHAT LINUX PROVES (rehearse.sh): that this script gets to its end, that glide.swift (all but its lines of Accessibility) paces, orders, counts and writes as its header says, and that
# the judge reads it. Nothing about any app: rehearse/real-apps makes them up.
# WHAT IS JUDGED AFTERWARDS, by judge-glide.py, whose header has the limits (`judge-glide.py <folder>`, on any machine, with other limits if wanted): glide.log (every asking),
# samples.log (what the window server showed, 120 times a second), cpu.log, pictures.txt. verdict.txt is what it said on the Mac. If two apps of nine stutter, this road is closed.
# To look at: film-glide-<n>.png, a pair on its way, about 70 ms apart; <nnn>-open-<app>.jpg, what each app put up.
#
# Only on GitHub's Macs: it opens real apps, moves and resizes their windows, quits them, and switches Reduce Motion and the display's size.
# The apps alone come first: what is cut off is the pairs, the film and the pictures, and what is there can still be judged.
ARBOR_TIME_LIMIT=480
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

# play <who> <steps> <order> <window>:<x>,<y>,<w>,<h>…: one act, called <who>.<n>. One step is the control; 12 are made in 0.2 s, 18 in 0.3 s.
# play <who> bar <window>: macOS's own tiling. FILM=<name>: pictures are taken meanwhile.
play() {
  local who=$1 steps=$2 glide
  shift 2
  case "$steps" in
    bar) set -- --menu "Window/Move & Resize/Left" "$@" ;;
    1) set -- --steps 1 --duration 0 --order "$@" ;;
    *) set -- --steps "$steps" --duration "$(echo "$steps" | awk '{ printf "%.3f", $1 / 60 }')" --order "$@" ;;
  esac
  ACT=$((ACT + 1))
  cpu "$who.$ACT" before
  note "glide $who.$ACT"
  # shellcheck disable=SC2086
  $TIERS "$TOOLS/glide" "$LOG" "$who.$ACT" "$@" 5<&- 6>&- &
  glide=$!
  # Of the first act alone.
  [ -z "${FILM:-}" ] || { film "$FILM" 6; FILM=""; }
  wait "$glide" || echo "  ✘ glide $who.$ACT ended with exit code $?"
  quiet 300 2000 || echo "  ~ windows were still moving after ${QUIET#*:} ms"
  cpu "$who.$ACT" after
}

# In front, so that it is drawn, and where its road begins.
place() {
  apptool activate "$(pid_of "$1")"
  apptool raise "$(window_of "$1")"
  # shellcheck disable=SC2086
  apptool set-frame "$(window_of "$1")" ${2//,/ } > /dev/null
}

# Two roads. On the first every edge moves, the near ones the way the window grows: by glide.swift's rule no order can put an edge off its road there. On the second the left
# edge moves alone and the others are to stand still, which two askings cannot promise: there the orders differ.
SMALL=60,80,560,400   LARGE=420,160,800,560
RIGHT=640,80,560,400  WIDE=240,80,960,400

# road <app> <frame> <frame> <order…>: there and back, 18 steps in each of these orders, then the control in either.
road() {
  local app=$1 here=$2 there=$3 window order
  window=$(window_of "$1")
  shift 3
  for order in "$@"; do
    play "$app" 18 "$order" "$window:$there"
    play "$app" 18 "$order" "$window:$here"
  done
  set -- "$app" "$here" "$there"
  for order in place-first size-first; do
    play "$1" 1 "$order" "$window:$3"
    play "$1" 1 "$order" "$window:$2"
  done
}

alone() {
  step "$1 alone (w$(window_of "$1"))"
  PLAYERS=$1
  place "$1" "$SMALL"
  quiet 300 2000
  road "$1" "$SMALL" "$LARGE" by-edges
  # From the one road to the other: the place alone, 580 points.
  play "$1" 12 by-edges "$(window_of "$1"):$RIGHT"
  road "$1" "$RIGHT" "$WIDE" by-edges place-first size-first
  # Last: what macOS has tiled it may treat as its own.
  play "$1" bar "$(window_of "$1")"
}

# pair <who> <app> <app>: the first glides, the second is set once as the glide begins. There and back.
pair() {
  step "$1: $2 glides, $3 jumps"
  PLAYERS="$2 $3"
  place "$3" 700,420,520,300
  place "$2" "$SMALL"
  quiet 300 2000
  play "$1" 18 by-edges "$(window_of "$2"):$LARGE" "$(window_of "$3"):100,500,620,340"
  play "$1" 18 by-edges "$(window_of "$2"):$SMALL" "$(window_of "$3"):700,420,520,300"
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

# What the window server's share has to be read against: it also answers the sampler, 120 times a second.
if [ -n "$SERVER" ]; then
  rested=$(day_cpu_seconds "$SERVER")
  sleep 3
  echo "with nothing moving the window server uses $(echo "$(day_cpu_seconds "$SERVER") $rested" | awk '{ printf "%.0f", ($1 - $2) * 100 / 3 }') % of a core"
fi

for name in $WALK_CAST; do alone "$name"; done
pair pair1 "$1" "$2"
pair pair2 "$3" "$4"
[ $# -lt 8 ] || { pair pair3 "$5" "$6"; pair pair4 "$7" "$8"; }
FILM=film-glide pair film "$1" "$2"

step "how long pictures take"
if [ -x "$TOOLS/picture-time" ]; then
  # shellcheck disable=SC2046
  limit 90 "$TOOLS/picture-time" $(for name in $WALK_CAST; do window_of "$name"; done) | tee "$ARBOR_OUT/pictures.txt"
fi

sampler_stop
step "the judge"
python3 "$ARBOR_ROOT/scripts/mac-shell/judge-glide.py" "$ARBOR_OUT" | tee "$ARBOR_OUT/verdict.txt"
check "the judge could read what the run leaves" grep -q "^verdict: " "$ARBOR_OUT/verdict.txt"
