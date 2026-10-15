#!/bin/bash
# Does a real window whose PLACE ALONE is set through Accessibility, once for every frame of the display, glide as macOS's own tiling does? A probe: no Arbor moves anything, and
# nothing of Arbor's changes by what it finds until somebody decides.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-place.sh          on one of GitHub's Macs, from anywhere: four minutes
#   scripts/mac-shell/judge-place.py .mac-shell/probe-place-<run id>   anywhere with numpy and Pillow, afterwards: the verdict
#   scripts/mac-shell/standstill.py table .mac-shell/probe-place-<run id>     for how long the display stood still, film by film
#   scripts/polish/judge.py sheet .mac-shell/probe-place-<run id>/films/swap-1 swap.png --from 100 --to 700     the frames, to look at
#
# A move that changes a window's size takes two askings, and the display shows the state between them: that road is closed. A move that keeps the size takes one. The camera's own moves are
# such (a window comes into view or leaves it), and so is a swap of two equal tiles. glide.swift asks; its header says how it is paced (never by a timer) and that it goes by the clock.
# HOW SMOOTH IT IS IS JUDGED FROM WHAT THE DISPLAY SHOWED: the polish judge's camera films two test windows, each another app's and one flat colour, on a black desk, one act a film. Each way is played
# five times, since which states fall on a frame of the display is chance. THE ROADS: across (620 points); a swap of two tiles, both gliding at once; out of view, to where Arbor parks a
# window, and back into view. THE CONTROLS: the camera's own square, right and wrong, before anything else; the place set once, there and back, before each road, so that no glide
# pays for a first time; and THE BAR, macOS's own Window > Move & Resize > Left and Right on the same window, which from one half to the other is a move of the place alone.
# BLIND: first, with no camera running, five glides with each pacer: they choose the pacer for the roads, the display link unless spinning on the clock kept its time more often. Then across, five glides
# filmed and five with no camera, in turns, so that the tool's own log of its ticks says whether the camera disturbs the pacing. What the display showed of a blind glide nobody saw; but pulse.swift lies
# beside all of them, filmed or not: another process that is told the display's own beat, and writes down where that faltered. Its strip, whose squares never stop, also makes every frame of a film differ from
# the one before, so that a film tells a window that waited while the display went on from a display that stood still.
# The test windows are opened once and never hidden, closed or ordered out: on GitHub's Macs a window that is shown again after a while away holds the whole display for about a second. The camera that
# showed its square is stopped before the acts, and the one that films them shows nothing.
# THE DAY'S NINE REAL APPS are no flat rectangles, and are not filmed: of them only what the tool's own clock can say, what an asking costs, whether it is back within the frame, where the window ends.
# No size is asked of them, so none can be refused. Last, two of them change places at once.
# WHAT LINUX PROVES (rehearse.sh): that this script gets to its end, that glide.swift (all but its lines of Accessibility and the display link) paces, counts and writes as its header says, and that the
# judge reads it. Nothing about any app or any display: the stand-in camera takes no pictures.
# What comes back: glide.log (every tick, every asking), glides.txt (what the tool said of each act), films/, pulse.log, cpu.log, said-on-the-mac.txt (the judge on the logs alone: a hosted Mac has no numpy).
#
# Only on GitHub's Macs: it films the whole display, opens real apps and moves their windows, and switches Reduce Motion, Reduce Transparency and the wallpaper.
# What answers the question comes first; what a cut costs is, from the end: the pair of apps, the apps, the other pacer's films.
ARBOR_TIME_LIMIT=240
source "$(dirname "$0")/lib-film.sh"
needs_throwaway_mac "film the whole display, open nine real apps and move their windows, and switch Reduce Motion, Reduce Transparency and the wallpaper"

GLIDE="$ARBOR_ROOT/.build/mac-shell/glide"
LOG="$ARBOR_OUT/glide.log"
# What the runner's agent starts counts as work in the background, which is woken late.
TIERS=""
if command -v taskpolicy > /dev/null; then TIERS="taskpolicy -l 0 -t 0"; fi

compile() { swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/$1.swift" -o "$ARBOR_ROOT/.build/mac-shell/$1" > "$ARBOR_OUT/build-$1.log" 2>&1; }

# Whether that many seconds are left.
left() { [ $((ARBOR_TIME_LIMIT - SECONDS)) -gt "$1" ]; }

# play <act> <glide's arguments…>: one act, and a rest.
play() {
  local said
  # shellcheck disable=SC2086
  said=$($TIERS "$GLIDE" "$LOG" "$@" 2>&1 4>&- 9>&-) || echo "  ✘ glide $1 ended with exit code $?"
  echo "$said" | tee -a "$ARBOR_OUT/glides.txt"
  sleep 0.2
}

# filmed <act> "<what happens>" <glide's arguments…>: the act is a film of its own, under its own name.
filmed() {
  local act=$1
  scene "$act" camera "$2" || return 1
  shift 2
  play "$act" "$@"
  scene_end 0.3
}

# seat <n> x y w h: the nth test window's own app puts it there. The one time a size is set.
seat() {
  local window
  eval "window=\$W$1"
  tell "$1" "move $window $2 $3 $4 $5"
  # A rehearsal keeps test windows in one world (arbor-fakemac) and what glide.swift can move there in another: files, as rehearse/real-apps says.
  [ -z "${ARBOR_REHEARSAL:-}" ] || { mkdir -p "$ARBOR_REHEARSAL_DIR/apps" && echo "600000$1 dev.arbor.cast.$1 $2 $3 $4 $5 1" > "$ARBOR_REHEARSAL_DIR/apps/$window"; }
}

# Where Accessibility last had that window: x,y
where() { awk -v window="$1" '$2 == "read" && $4 == window { place = $6 "," $7 } END { print place }' "$LOG"; }

# to_and_fro play|filmed <group> <pace> <window> <there> <back>: five glides, there, back, there, back, there.
to_and_fro() {
  local how=$1 group=$2 pace=$3 window=$4 there=$5 back=$6 n place
  for n in 1 2 3 4 5; do
    place=$there
    [ $((n % 2)) -eq 1 ] || place=$back
    if [ "$how" = filmed ]; then
      filmed "$group-$n" "the window glides across, paced by $pace" --pace "$pace" "$window:$place"
    else
      play "$group-$n" --pace "$pace" "$window:$place"
    fi
  done
}

# As in check-standstill.sh: the strip lies between the menu bar and the windows.
PULSE_PID=""
pulse_start() {
  [ -z "${ARBOR_REHEARSAL:-}" ] || { echo "> the strip (not rehearsed)"; return 0; }
  [ -x "$ARBOR_ROOT/.build/mac-shell/pulse" ] || return 0
  # shellcheck disable=SC2086
  $TIERS "$ARBOR_ROOT/.build/mac-shell/pulse" "$ARBOR_OUT/pulse.log" 440 31 < /dev/null >> "$ARBOR_OUT/pulse-stderr.log" 2>&1 3>&- 4>&- 7>&- 8>&- 9>&- &
  PULSE_PID=$!
  started "$PULSE_PID"
  sleep 1
}

pulse_stop() {
  [ -z "$PULSE_PID" ] || kill_started "$PULSE_PID"
  PULSE_PID=""
}

# An app's first standard window, now: an app may swap the window it opened with for another, as Mail does.
window_of() { "$FILM_APPTOOL" windows "$1" | awk '$3 == "AXStandardWindow" { print $1; exit }'; }

# How many of a blind group's glides kept their time, by the tool's own word.
kept() { grep -c "^glide $1-[0-9]*: .*: paced$" "$ARBOR_OUT/glides.txt"; }

# ps gives the time a process has had of the processors as [[dd-]hh:]mm:ss.cc.
cpu() {
  local who pid
  for who in "app:$3" "server:$SERVER"; do
    pid=${who#*:}
    [ -z "$pid" ] || echo "$1 $2 ${who%:*} $(ps -o cputime= -p "$pid" 2>/dev/null | awk '{ parts = split($1, unit, ":"); for (i = 1; i <= parts; i++) seconds = seconds * 60 + unit[i]; printf "%.2f", seconds }')"
  done >> "$ARBOR_OUT/cpu.log"
}

step "the Mac"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m), $(sysctl -n hw.ncpu) cores"
mkdir -p "$(dirname "$GLIDE")"
compile glide &
tool=$!
# In a rehearsal film_build compiles nothing, and the stand-in for the compiler leaves the stand-in for the one tool and knows nothing of the other.
if [ -n "${ARBOR_REHEARSAL:-}" ]; then compile apptool; else compile pulse; fi &
other=$!
film_build
wait "$other" || echo "scripts/mac-shell/pulse.swift did not compile: on without the strip"
wait "$tool" || { grep -A 6 "error:" "$ARBOR_OUT/build-glide.log" | head -n 60; die "scripts/mac-shell/glide.swift did not compile"; }
cast_build
read -r _ _ _ WIDE HIGH _ <<< "$(pointer displays | head -n 1)"
echo "the display: $WIDE x $HIGH, after $SECONDS s"
# As a Mac comes. GitHub's come with both on, and macOS's own tiling glides only with Reduce Motion off.
macos_reduce_motion off
glass on
wallpaper "#000000"
SERVER=$(pgrep -x WindowServer | head -n 1)
# Two tiles side by side with Arbor's gaps, well above the Dock; and a window narrow enough to go 620 points across the smallest display.
TOP=43 NEAR=12 FAR=632 NARROW=380
TILE=$(((WIDE - 36) / 2)) TALL=$((HIGH - 168))
RIGHT=$((TILE + 24))

step "1. the camera's own square, right and wrong, on a bare desk: whether camera and ruler may be believed"
# Without a camera nothing is filmed and there is no verdict; what the pacers and the apps are worth is told all the same.
camera_start || echo "NO CAMERA"
for kind in good linear slow twice hop flash; do metronome "$kind"; done
scene ground bare "the bare desk"
scene_end 0.3
camera_stop

step "2. two test windows, each another app's. Arbor starts them and quits: it moves nothing"
ARBOR_TEST_WINDOWS_ARGS="--regular"
# The fake Mac has no menus of macOS's to fill.
[ -n "${ARBOR_REHEARSAL:-}" ] || ARBOR_TEST_WINDOWS_ARGS="--regular --window-menu"
cast_start 2
ctl quit
arbor_ended
check "Arbor has quit before anything is played" test -z "$ARBOR_PID"
seat 2 "$NEAR" $((TOP + TALL - 90)) 200 90
seat 1 "$NEAR" "$TOP" "$NARROW" $((TALL - 110))
pulse_start
echo "after $SECONDS s"

step "3. blind: no camera. The place set once, there and back; then five glides with each pacer"
play blind-control-1 --duration 0 "$W1:$FAR,$TOP"
play blind-control-2 --duration 0 "$W1:$NEAR,$TOP"
to_and_fro play blind-link link "$W1" "$FAR,$TOP" "$NEAR,$TOP"
play blind-control-3 --duration 0 "$W1:$NEAR,$TOP"
to_and_fro play blind-spin spin "$W1" "$FAR,$TOP" "$NEAR,$TOP"
play blind-control-4 --duration 0 "$W1:$NEAR,$TOP"
PACE=link OTHER=spin
if [ "$(kept blind-spin)" -gt "$(kept blind-link)" ]; then PACE=spin OTHER=link; fi
echo "kept their time: $(kept blind-link) of 5 by the display link, $(kept blind-spin) of 5 spinning: the roads are played by $PACE. After $SECONDS s"

step "4. across: five glides filmed and five with no camera, in turns"
camera_start || camera_start || echo "the camera did not come back"
filmed control-across-1 "the place is set once" --duration 0 "$W1:$FAR,$TOP"
filmed control-across-2 "and set back" --duration 0 "$W1:$NEAR,$TOP"
place=$FAR
for turn in filmed:1 unfilmed:1 unfilmed:2 filmed:2 filmed:3 unfilmed:3 unfilmed:4 filmed:4 filmed:5 unfilmed:5; do
  if [ "${turn%:*}" = filmed ]; then
    camera_start || camera_start || echo "the camera did not come back"
    filmed "across-$PACE-${turn#*:}" "the window glides across, paced by $PACE" --pace "$PACE" "$W1:$place,$TOP"
  else
    camera_stop
    sleep 0.3
    play "unfilmed-$PACE-${turn#*:}" --pace "$PACE" "$W1:$place,$TOP"
  fi
  if [ "$place" = "$FAR" ]; then place=$NEAR; else place=$FAR; fi
done
camera_start || camera_start || echo "the camera did not come back"
echo "after $SECONDS s"

step "5. a swap of two equal tiles, both gliding at once"
seat 1 "$NEAR" "$TOP" "$TILE" "$TALL"
seat 2 "$RIGHT" "$TOP" "$TILE" "$TALL"
sleep 1
filmed control-swap-1 "both places are set once" --duration 0 "$W1:$RIGHT,$TOP" "$W2:$NEAR,$TOP"
filmed control-swap-2 "and set back" --duration 0 "$W1:$NEAR,$TOP" "$W2:$RIGHT,$TOP"
for n in 1 2 3 4 5; do
  if [ $((n % 2)) -eq 1 ]; then
    filmed "swap-$n" "the two tiles change places" --pace "$PACE" "$W1:$RIGHT,$TOP" "$W2:$NEAR,$TOP"
  else
    filmed "swap-$n" "the two tiles change places" --pace "$PACE" "$W1:$NEAR,$TOP" "$W2:$RIGHT,$TOP"
  fi
done
echo "after $SECONDS s"

step "6. out of view and into it: to where Arbor parks a window (Controller+Layout.swift: a point of it stays on the display, in the bottom right corner)"
# The second tile goes first, off film, and stays there. What macOS makes of the place asked for is in the log: it lets no title bar go under the Dock.
play park-2 --duration 0 "$W2:$((WIDE - 1)),$((HIGH - 1))"
play home-1 --duration 0 "$W1:$NEAR,$TOP"
filmed control-view-1 "the tile is sent out of view at once" --duration 0 "$W1:$((WIDE - 1)),$((HIGH - 1))"
PARKED=$(where "$W1")
echo "asked for $((WIDE - 1)),$((HIGH - 1)), the window stands at $PARKED: that is the road's end, which macOS does not refuse"
filmed control-view-2 "and fetched back at once" --duration 0 "$W1:$NEAR,$TOP"
for n in 1 2 3 4 5; do
  filmed "out-$n" "the tile glides out of view" --pace "$PACE" "$W1:$PARKED"
  filmed "in-$n" "the tile glides into view" --pace "$PACE" "$W1:$NEAR,$TOP"
done
echo "after $SECONDS s"

step "7. the bar: macOS's own tiling of the same window, from one half of the display to the other"
# shellcheck disable=SC2046
click $(titlebar_of "$W1")
sleep 0.6
# Into the left half first, off film: that changes its size.
play tile --menu "Window/Move & Resize/Left" "$W1"
for n in 1 2 3 4 5; do
  filmed "bar-$n" "macOS moves the tile to the other half" --menu "Window/Move & Resize/$([ $((n % 2)) -eq 1 ] && echo Right || echo Left)" "$W1"
done
echo "after $SECONDS s"

step "8. across once more, by the other pacer"
if left 85; then
  seat 1 "$NEAR" "$TOP" "$NARROW" $((TALL - 110))
  sleep 1
  to_and_fro filmed "across-$OTHER" "$OTHER" "$W1" "$FAR,$TOP" "$NEAR,$TOP"
else
  echo "NOT PLAYED: no time left"
fi
camera_stop
pulse_stop
play park-1 --duration 0 "$W1:$((WIDE - 1)),$((HIGH - 1))"
echo "after $SECONDS s"

step "9. the day's nine apps, by the tool's own clock: no camera, no size asked for"
scratch_dir place PAPERS
echo "An oak." > "$PAPERS/oak.txt"
echo "<!doctype html><title>page</title><p>A page.</p>" > "$PAPERS/page.html"
[ -z "$FILM_CAST" ] || cp "$FILM_CAST/Oak.png" "$PAPERS/leaf.png"
# Those first that took longest over an asking when sizes were asked for too: what a cut costs comes last.
CAST="mail=com.apple.mail= finder=com.apple.finder=$PAPERS calendar=com.apple.iCal= safari=com.apple.Safari=$PAPERS/page.html notes=com.apple.Notes= preview=com.apple.Preview=$PAPERS/leaf.png
  textedit=com.apple.TextEdit=$PAPERS/oak.txt terminal=com.apple.Terminal= settings=com.apple.systempreferences="
# All at once, and all are waited for: nothing is measured while an app draws for the first time.
for one in $CAST; do
  bundle=${one#*=} paper=${one##*=}
  limit 20 open -g -b "${bundle%%=*}" ${paper:+"$paper"} || echo "${one%%=*} did not open"
done
OPEN=""
for one in $CAST; do
  name=${one%%=*} bundle=${one#*=}
  film_await 100 "$FILM_APPTOOL" pid "${bundle%%=*}" > /dev/null || { echo "$name: NOT PLAYED: it did not start"; continue; }
  pid=$("$FILM_APPTOOL" pid "${bundle%%=*}")
  started "$pid" > /dev/null
  "$FILM_APPTOOL" wait-window "$pid" 10 > /dev/null || { echo "$name: NOT PLAYED: no window"; continue; }
  OPEN="$OPEN $name=$pid"
done
sleep 2
echo "open:$OPEN, after $SECONDS s"
for one in $OPEN; do
  name=${one%%=*} pid=${one#*=}
  left 12 || { echo "$name: NOT PLAYED: no time left"; continue; }
  window=$(window_of "$pid")
  [ -n "$window" ] || { echo "$name: NOT PLAYED: no window"; continue; }
  echo "$name is pid $pid, w$window"
  # In front, so that it is drawn.
  "$FILM_APPTOOL" activate "$pid"
  "$FILM_APPTOOL" raise "$window"
  play "app-$name-there" --duration 0 "$window:640,60"
  play "app-$name-back" --duration 0 "$window:20,60"
  cpu "app-$name" before "$pid"
  to_and_fro play "app-$name" "$PACE" "$window" 640,60 20,60
  cpu "app-$name" after "$pid"
  # Out of the next one's way, where Arbor would put it.
  play "app-$name-parked" --duration 0 "$window:$((WIDE - 1)),$((HIGH - 1))"
done
# Two of them at once, each asked from a thread of its own: does the one hold up the other?
# shellcheck disable=SC2086
set -- $OPEN
if [ $# -ge 2 ] && left 10; then
  one=$(window_of "${1#*=}") two=$(window_of "${2#*=}")
  echo "the pair is ${1%%=*}, w$one, and ${2%%=*}, w$two"
  play app-pair-home --duration 0 "$one:20,60" "$two:640,60"
  for n in 1 2 3 4 5; do
    if [ $((n % 2)) -eq 1 ]; then play "app-pair-$n" --pace "$PACE" "$one:640,60" "$two:20,60"; else play "app-pair-$n" --pace "$PACE" "$one:20,60" "$two:640,60"; fi
  done
fi
echo "after $SECONDS s"

cast_stop

step "the judge, on the logs alone"
python3 "$ARBOR_ROOT/scripts/mac-shell/judge-place.py" "$ARBOR_OUT" | tee "$ARBOR_OUT/said-on-the-mac.txt"
check "the judge could read what the run leaves" grep -q "^verdict: " "$ARBOR_OUT/said-on-the-mac.txt"
echo "after $SECONDS s"
