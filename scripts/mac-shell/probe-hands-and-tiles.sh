#!/bin/bash
# What macOS itself does with a window that a hand lets go of low, in the menu bar, at an edge, in a corner or with ⌥ down, and with one
# that is asked to go above the menu bar. Nothing here is a check: the output is the point.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-hands-and-tiles-1.sh      groups A and E
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-hands-and-tiles-2.sh      group D
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-hands-and-tiles-3.sh      groups E4, B and C
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-hands-and-tiles.sh        all of them, A E E4 D B C, as far as the clock lets it come
#
# Arbor is paused throughout: the question is macOS's. macOS's tiling is as the Mac comes, which is on.
#
#   A  a hand lets go low: where the window rests, and whether it follows the pointer below the limit while the button is down
#   E  the ⌥ key: down before the press, pressed in the middle of the drag, let go before the button, at the left edge and in the menu
#      bar, with a window of a fixed size.  E4: with other modifiers beside it
#   D  tiles nobody measured: the four quarters, a window taller than its tile, the whole screen from the left, windows that cannot take
#      the tile's size at the right edge, a window wider than the half
#   B  out of the menu bar again: is the window glued until the pointer is back at its old offset, or does it follow at once
#   C  asked to go above the menu bar: through Accessibility, by its own app, and a new window that opens there
#
# What comes back, besides this output:
#   ax-events.txt   what Accessibility reported about the test windows (axwatch.swift: seconds since it began, `[button down]`, `mouse up`),
#                   with a line `--- <trial> <seconds since 1970>` before each trial and `--- put` before a window is put back
#   samples.log     the window server's list and the pointer sixty times a second (sampler.swift), with `M <trial>` before each trial
#
# Every trial prints, each on a line of its own:
#   == <trial>
#   before: x y w h             the window server's frame
#   drag: x1 y1 x2 y2 options   the very words the pointer tool got
#   macOS shows: id level x y w h; …    every window of WindowManager's on the screen with the button still down. In brackets after
#                               `shows`: an earlier moment of the same trial
#   pointer: x y down|up
#   held: x y w h               just before the button comes up
#   let go: x y w h             0.1 s after
#   rest: x y w h               2 s after
# In A's names the number is how far above the visible frame's bottom the window's top is let go: -15 is 15 points below it, behind the Dock.
# B prints `step: pointer x y down window x y w h` after every five points down (drag_on: one movement, then a point aside and back).
# C has no hand: `ask: x y w h`, through Accessibility `answer: x y w h` (what it says at once), then `let go:` and `rest:` as above.
# `off the tile: x y w h window <id>`, before a trial: the frame after a hand has dragged that window off the tile an earlier trial left it on,
# before its app gives it the trial's frame to the point.
# `clock:` ends each group. `SKIPPED` names a trial the clock left no time for (PROBE_BUDGET, seconds since the script began).
# `NOT MEASURED` names what a missing tool took away.
PROBE_GROUPS=${PROBE_GROUPS:-A E E4 D B C}
PROBE_BUDGET=${PROBE_BUDGET:-335}
# What Arbor's own Accessibility layer is told meanwhile comes back as a trace (docs/TRACES.md). Recording moves nothing.
ARBOR_RECORD=${ARBOR_RECORD:-1}
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "drag windows into the menu bar, behind the Dock, to every edge and into every corner, and hold modifiers down meanwhile"
type drag_on > /dev/null 2>&1 || die "this checkout's pointer tool cannot carry on with the button down (drag_on): B, E2 and E3 need a trunk that has it"

# MARK: The tools

TOOLS="$ARBOR_ROOT/.build/mac-shell"
EVENTS="$ARBOR_OUT/ax-events.txt"
COMPILING=""
WATCHER=""
SAMPLER_PID=""
mkdir -p "$TOOLS"

# compile <name> <source> [option of swiftc]: beside Arbor's own build, unless an earlier script on this Mac has done it
compile() {
  arbor_is_current "$2" "$TOOLS/$1" && return 0
  rm -f "$TOOLS/$1"
  # shellcheck disable=SC2086
  swiftc ${3:-} -swift-version 5 "$2" -o "$TOOLS/$1" > "$ARBOR_OUT/build-$1.log" 2>&1 &
  COMPILING="$COMPILING $1:$!"
}
has() { [ -z "${ARBOR_REHEARSAL:-}" ] && [ -x "$TOOLS/$1" ]; }

if [ -n "${ARBOR_REHEARSAL:-}" ]; then
  echo "REHEARSAL: no swiftc here, so axwatch, the sampler and apptool are not built and not run:"
  echo "REHEARSAL: no ax-events.txt but its headings, no samples.log, no ask of C's through Accessibility is made"
else
  compile axwatch "$ARBOR_ROOT/scripts/mac-shell/axwatch.swift" -O
  compile sampler "$ARBOR_ROOT/scripts/mac-shell/sampler.swift" -O
  case " $PROBE_GROUPS " in *" C "*) compile apptool "$ARBOR_ROOT/scripts/mac-shell/apptool.swift" ;; esac
fi
arbor_build
for job in $COMPILING; do
  wait "${job#*:}" && continue
  echo "NOT MEASURED: ${job%:*} did not compile:"
  grep -A 6 "error:" "$ARBOR_OUT/build-${job%:*}.log" | head -n 30
done
echo "clock: built after ${SECONDS}s"

step "the Mac"
echo "macOS $(sw_vers -productVersion)"
macos_tiling
macos_click_wallpaper
echo "displays:"; pointer displays
# ⌃ pressed twice starts Dictation, which asks first, in an alert in front of everything. E4 presses it six times.
case " $PROBE_GROUPS " in *" E4 "*) macos_dictation_shortcut off ;; esac

ARBOR_TEST_WINDOWS_ARGS="--max-size 1:300x240 --min-size 2:700x500"
arbor_start 3
ctl pause
# open_at <variable> <x y w h> [fixed]: the test windows' `open x y w h [fixed]`, which the fake ones do not take
open_at() {
  if [ -z "${ARBOR_REHEARSAL:-}" ]; then open_window "$@"; return; fi
  echo "REHEARSAL: open $2 $3 $4 $5 ${6:-} is asked for in other words, and \`fixed\` is a least and a greatest size"
  # shellcheck disable=SC2046
  open_window "$1" "size=$4x$(($5 - 28))" "at=$2,$3" $([ -z "${6:-}" ] || echo "min=$4x$5 max=$4x$5")
}
open_at F 300 200 300 240 fixed
MAXED=$W1 MINED=$W2 PLAIN=$W3 FIXED=$F

whole() { local word out=""; for word in "$@"; do out="$out ${word%.*}"; done; echo "${out# }"; }
# shellcheck disable=SC2046
read -r vx vy vw vh <<< "$(whole $(arbor_ask screen))"
# shellcheck disable=SC2046
read -r dx dy dw dh <<< "$(whole $(display_frame_of 1))"
bottom=$((vy + vh)) middle=$((vy + vh / 2)) centre=$((dx + dw / 2)) last_x=$((dx + dw - 1)) last_y=$((dy + dh - 1))
echo "visible: $vx $vy $vw $vh"
echo "display: $dx $dy $dw $dh"
echo "windows: plain $PLAIN ($(real_frame_of "$PLAIN")), fixed $FIXED ($(real_frame_of "$FIXED")), max-size $MAXED ($(real_frame_of "$MAXED")), min-size $MINED ($(real_frame_of "$MINED"))"
echo "on the screen, front to back (id pid level x y w h on owner):"
pointer windows --on-screen

# size_of <window>: w h, whole numbers
size_of() {
  local x y w h
  read -r x y w h <<< "$(real_frame_of "$1")"
  echo "${w%.*} ${h%.*}"
}
PLAIN_SIZE=$(size_of "$PLAIN") FIXED_SIZE=$(size_of "$FIXED") MAXED_SIZE=$(size_of "$MAXED") MINED_SIZE=$(size_of "$MINED")
# in_the_middle <w h>: x y w h, with its middle on the display's and its top 100 points under the menu bar
in_the_middle() { echo "$((centre - $1 / 2)) $((vy + 100)) $1 $2"; }

echo "# $ARBOR_NAME, groups $PROBE_GROUPS, on macOS $(sw_vers -productVersion), commit $(git rev-parse --short HEAD)" >> "$EVENTS"
if has axwatch; then
  echo "# axwatch begins at $(arbor_now) seconds since 1970; its own seconds count from there" >> "$EVENTS"
  "$TOOLS/axwatch" "$ARBOR_WINDOWS_PID" >> "$EVENTS" 2>&1 7>&- 8>&- 9>&- &
  WATCHER=$!
  started "$WATCHER"
  at_exit 'kill_started $WATCHER'
fi
if has sampler; then
  mkfifo "$ARBOR_SESSION_DIR/sampler-in" "$ARBOR_SESSION_DIR/sampler-out"
  "$TOOLS/sampler" "$ARBOR_OUT/samples.log" "$ARBOR_SESSION_DIR/sampler-in" "$ARBOR_SESSION_DIR/sampler-out" --hz 60 \
    2>> "$ARBOR_OUT/sampler-stderr.log" 7>&- 8>&- 9>&- &
  SAMPLER_PID=$!
  started "$SAMPLER_PID"
  exec 6> "$ARBOR_SESSION_DIR/sampler-in" 5< "$ARBOR_SESSION_DIR/sampler-out"
fi
sleep 1

# MARK: A trial

START=""   # x y w h: where the window lies before the trial
HOLD=0.3   # seconds between the end of the movement and the lists
MODS=""    # the modifiers that go down before the press and up after the release
PACE=""    # options of drag: how fast the hand is. Nothing: 0.6 s in 30 steps

in_time() {
  [ "$SECONDS" -lt "$PROBE_BUDGET" ] && return 0
  echo "SKIPPED: $1 (${SECONDS}s have gone, the budget is ${PROBE_BUDGET}s)"
  return 1
}
note() {
  echo "--- $* $(arbor_now)" >> "$EVENTS"
  # Writing to a pipe nobody reads would end this script.
  if [ -n "$SAMPLER_PID" ] && kill -0 "$SAMPLER_PID" 2>/dev/null; then echo "mark $*" >&6; fi
}
heading() { step "$1"; note "$1"; }
clock() { echo; echo "clock: group $1 done ${SECONDS}s after the script began, at $(date -u +%H:%M:%SZ)"; }

# The middle of what shows of the title bar.
grab_of() {
  local x y w h left right
  read -r x y w h <<< "$(real_frame_of "$1")"
  x=${x%.*} y=${y%.*} w=${w%.*}
  left=$x right=$((x + w))
  [ "$left" -lt "$dx" ] && left=$dx
  [ "$right" -gt $((dx + dw)) ] && right=$((dx + dw))
  echo "$(((left + right) / 2)) $((y + 12))"
}

# put <window> <x y w h>: a window of another size lies on a tile, or came off one. A hand takes it off, so that macOS forgets the tile and gives
# the size back; what that size is gets printed, because it creeps. Then its own app gives it the frame to the point.
put() {
  local id=$1
  shift
  note put
  tw front "$id" > /dev/null
  if [ "$(size_of "$id")" != "$3 $4" ]; then
    # shellcheck disable=SC2046
    drag $(grab_of "$id") "$centre" $((vy + 112)) --duration 0.25 --steps 12 --hold 0 > /dev/null
    sleep 0.3
    echo "off the tile: $(real_frame_of "$id") window $id"
  fi
  tw move "$id" "$@" > /dev/null
  sleep 0.3
}

# showing [moment]: who is on the screen besides the furniture and the test windows. Arbor should never be.
showing() {
  local list rest
  list=$(pointer windows | awk '$8 == "on"')
  echo "macOS shows${1:+ [$1]}: $(echo "$list" | awk '$9 == "WindowManager" { printf "%s %s %s %s %s %s; ", $1, $3, $4, $5, $6, $7 }')"
  rest=$(echo "$list" | awk -v arbor="$ARBOR_PID" '$2 == arbor { printf "%s %s %s %s %s %s; ", $1, $3, $4, $5, $6, $7 }')
  [ -z "$rest" ] || echo "ARBOR SHOWS${1:+ [$1]}: $rest"
  # Of the test windows' app only what is no ordinary window: a menu that ⌃ and a press opened, say.
  rest=$(echo "$list" | awk -v arbor="$ARBOR_PID" '$2 != arbor && !($9 == "ArborTestWindows" && $3 == 0)' \
    | grep -v -E " (WindowManager|Dock|Finder|Window Server|Control Cent(er|re)|Spotlight|Notification Cent(er|re)|Wallpaper|SystemUIServer|loginwindow)$" \
    | awk '{ printf "%s %s %s %s %s %s %s; ", $1, $3, $4, $5, $6, $7, $9 }')
  [ -z "$rest" ] || echo "also on the screen${1:+ [$1]}: $rest"
}
in_hand() {
  showing
  echo "pointer: $(pointer where)"
  echo "held: $(real_frame_of "$1")"
}
let_go() {
  sleep 0.1
  echo "let go: $(real_frame_of "$1")"
  sleep 1.9
  echo "rest: $(real_frame_of "$1")"
}

# begin <name> <window> <x> <y> [options of drag]: from START by the title bar until the pointer is at x y (`same`: straight up or down),
# and the button stays down
begin() {
  local name=$1 id=$2 x=$3 y=$4 gx gy words
  shift 4
  # shellcheck disable=SC2086
  put "$id" $START
  heading "$name"
  echo "before: $(real_frame_of "$id")"
  read -r gx gy <<< "$(grab_of "$id")"
  [ "$x" = same ] && x=$gx
  words="$gx $gy $x $y --hold $HOLD --no-release${PACE:+ $PACE}${MODS:+ --mods $MODS}${*:+ $*}"
  echo "drag: $words"
  # shellcheck disable=SC2086
  drag $words
}

# trial <name> <window> <x> <y> [options of drag]
trial() {
  in_time "$1" || return 0
  begin "$@"
  in_hand "$2"
  # shellcheck disable=SC2086
  release ${MODS:+--mods $MODS}
  let_go "$2"
}

# nudge <x> <y> [options]: a point aside and back with the button down, as no hand can help doing. It is what drag_on ends with.
nudge() { drag_on "$@" --steps 1 --duration 0 --hold 0; }

# MARK: A. A hand lets go low

# low <name> <window> <how far above the visible frame's bottom the window's top is let go>
low() { trial "$1" "$2" same $((bottom - $3 + 12)); }

group_A() {
  local above round
  HOLD=0.3 MODS="" PACE=""
  # shellcheck disable=SC2086
  START=$(in_the_middle $PLAIN_SIZE)
  for above in 60 40 33 32 31 29 28 27 20 10 0 -15; do low "A.plain.top-at-bottom-minus.$above.1" "$PLAIN" "$above"; done
  trial "A.plain.pointer-in-the-last-row.1" "$PLAIN" same "$last_y"
  # shellcheck disable=SC2086
  START=$(in_the_middle $FIXED_SIZE)
  for above in 31 29 -15; do low "A.fixed.top-at-bottom-minus.$above.1" "$FIXED" "$above"; done
  # shellcheck disable=SC2086
  START=$(in_the_middle $PLAIN_SIZE)
  round=2
  for above in 31 29 32 28 33 27; do low "A.plain.top-at-bottom-minus.$above.$round" "$PLAIN" "$above"; done
}

# MARK: E. The ⌥ key

# ⌥ goes down in the middle of the drag.
late_option() {
  local name=$1 id=$2 x=$3 y=$4
  in_time "$name" || return 0
  MODS="" HOLD=0.3
  begin "$name" "$id" "$x" "$y"
  showing "no key yet"
  key opt --down
  sleep 1
  showing "⌥ down, the pointer still"
  nudge "$x" "$y" --mods opt
  sleep 0.6
  in_hand "$id"
  release --mods opt
  let_go "$id"
  # The release has let go of it; this takes it off the record of keys that are down.
  key opt --up
}

# ⌥ comes up before the button does.
early_option() {
  local name=$1 id=$2 x=$3 y=$4
  in_time "$name" || return 0
  MODS=opt HOLD=1
  begin "$name" "$id" "$x" "$y"
  MODS=""
  showing "⌥ down"
  key opt --up
  sleep 0.6
  showing "⌥ up, the pointer still"
  nudge "$x" "$y"
  sleep 0.4
  in_hand "$id"
  release
  let_go "$id"
}

group_E() {
  local x
  PACE="--duration 0.4 --steps 20"
  # shellcheck disable=SC2086
  START=$(in_the_middle $PLAIN_SIZE)
  for x in 200 700; do MODS=opt HOLD=1 trial "E1.option-before-the-press.$x" "$PLAIN" "$x" "$middle"; done
  for x in 200 700; do late_option "E2.option-in-the-middle.$x" "$PLAIN" "$x" "$middle"; done
  for x in 200 700; do early_option "E3.option-up-before-the-button.$x" "$PLAIN" "$x" "$middle"; done
  HOLD=1
  MODS=opt trial "E6.option.left-edge" "$PLAIN" "$dx" "$middle"
  MODS=opt trial "E6.option.menu-bar" "$PLAIN" "$centre" "$dy"
  # shellcheck disable=SC2086
  START=$(in_the_middle $FIXED_SIZE)
  for x in 200 700; do MODS=opt trial "E5.option.fixed.$x" "$FIXED" "$x" "$middle"; done
  MODS=""
}

group_E4() {
  local x chord
  HOLD=1 PACE="--duration 0.4 --steps 20"
  # shellcheck disable=SC2086
  START=$(in_the_middle $PLAIN_SIZE)
  for chord in opt+shift opt+cmd ctrl+opt ctrl+opt+cmd ctrl+opt+shift; do
    for x in 200 700; do MODS=$chord trial "E4.$chord.$x" "$PLAIN" "$x" "$middle"; done
  done
  MODS=""
}

# MARK: D. Tiles never measured

group_D() {
  local corner x y above lower
  MODS="" HOLD=1.2 PACE="--duration 0.4 --steps 20"
  above="$((vx + 60)) $((vy + 30)) $PLAIN_SIZE"
  lower="$((centre - 240)) $((middle + 40)) $PLAIN_SIZE"
  for corner in top-left top-right bottom-left bottom-right; do
    case $corner in top-*) y=$dy ;; *) y=$last_y ;; esac
    case $corner in *-left) x=$dx ;; *) x=$last_x ;; esac
    START=$above trial "D1.quarter.$corner.from-left-and-above" "$PLAIN" "$x" "$y"
    START=$lower trial "D1.quarter.$corner.from-lower" "$PLAIN" "$x" "$y"
  done
  START="$((centre - 240)) $((vy + 5)) 480 660"
  trial "D2.tall-660.quarter.top-left" "$PLAIN" "$dx" "$dy"
  trial "D2.tall-660.quarter.bottom-right" "$PLAIN" "$last_x" "$last_y"
  trial "D2.tall-660.half.left" "$PLAIN" "$dx" "$middle"
  START="$((centre - 240)) $vy 480 $((vh + 46))"
  trial "D2.taller-than-the-visible-frame.half.left" "$PLAIN" "$dx" "$middle"
  START="$((dx - 100)) $((vy + 60)) $PLAIN_SIZE"
  trial "D3.whole-screen.from-over-the-left-edge" "$PLAIN" same "$dy"
  # shellcheck disable=SC2086
  START=$(in_the_middle $FIXED_SIZE)
  trial "D4.fixed.right-edge" "$FIXED" "$last_x" "$middle"
  # shellcheck disable=SC2086
  START=$(in_the_middle $MAXED_SIZE)
  trial "D4.max-size.right-edge" "$MAXED" "$last_x" "$middle"
  START="$((dx + 100)) $((vy + 60)) $MINED_SIZE"
  trial "D4.min-size.right-edge" "$MINED" "$last_x" "$middle"
  START="$((dx + dw - 710)) $((vy + 100)) 700 348"
  trial "D5.wider-than-the-half.from-the-right.right-half" "$PLAIN" "$last_x" "$middle"
  trial "D5.wider-than-the-half.from-the-right.left-half" "$PLAIN" "$dx" "$middle"
}

# MARK: B. Out of the menu bar again

group_B() {
  local y gx wait
  MODS="" PACE=""
  # shellcheck disable=SC2086
  START=$(in_the_middle $PLAIN_SIZE)
  # Once at once, once after macOS has had the time to offer the whole screen.
  for wait in 0.3 1.5; do
    in_time "B.up-to-5.down-in-steps.after-$wait" || continue
    HOLD=$wait
    begin "B.up-to-5.down-in-steps.after-$wait" "$PLAIN" same $((dy + 5))
    in_hand "$PLAIN"
    read -r gx y <<< "$(pointer where)"
    gx=${gx%.*}
    y=$((dy + 10))
    while [ "$y" -le $((dy + 120)) ]; do
      drag_on "$gx" "$y" --steps 1 --duration 0 --hold 0
      echo "step: pointer $(pointer where) window $(real_frame_of "$PLAIN")"
      y=$((y + 5))
    done
    in_hand "$PLAIN"
    release
    let_go "$PLAIN"
  done
}

# MARK: C. Asked to go above

# asked <name> <who asks> <y>
asked() {
  local name=$1 who=$2 y=$3 x w h
  in_time "$name" || return 0
  # shellcheck disable=SC2086
  put "$PLAIN" $START
  heading "$name"
  echo "before: $(real_frame_of "$PLAIN")"
  read -r x _ w h <<< "$START"
  echo "ask: $x $y $w $h"
  case $who in
    accessibility)
      if has apptool; then echo "answer: $("$TOOLS/apptool" set-frame "$PLAIN" "$x" "$y" "$w" "$h" 2>&1)"
      else echo "NOT MEASURED: no apptool, nothing was asked"; fi ;;
    app) tw move "$PLAIN" "$x" "$y" "$w" "$h" ;;
  esac
  let_go "$PLAIN"
}

group_C() {
  local y new
  # shellcheck disable=SC2086
  START=$(in_the_middle $PLAIN_SIZE)
  for y in $((vy - 1)) $((vy - 20)) "$dy" $((dy - 50)); do asked "C1.accessibility-asks.y.$y" accessibility "$y"; done
  for y in $((vy - 1)) $((vy - 20)) "$dy" $((dy - 50)); do asked "C2.its-app-asks.y.$y" app "$y"; done
  for y in "$dy" $((dy + 20)) $((dy - 20)); do
    in_time "C3.a-new-window.y.$y" || continue
    heading "C3.a-new-window.y.$y"
    echo "ask: 340 $y 300 240"
    open_at new 340 "$y" 300 240 || continue
    let_go "$new"
    tw close "$new" > /dev/null
    forget_window "$new"
  done
}

# MARK: The run

for group in $PROBE_GROUPS; do
  "group_$group"
  clock "$group"
done

# Where Arbor's quitting finds them in view, each at its own size.
MODS=""
# shellcheck disable=SC2086
put "$PLAIN" $(in_the_middle $PLAIN_SIZE)
# shellcheck disable=SC2086
put "$FIXED" $((vx + 20)) $((vy + 20)) $FIXED_SIZE
# shellcheck disable=SC2086
put "$MAXED" $((vx + 40)) $((vy + 300)) $MAXED_SIZE
# shellcheck disable=SC2086
put "$MINED" $((vx + 300)) $((vy + 60)) $MINED_SIZE
if [ -n "$SAMPLER_PID" ] && kill -0 "$SAMPLER_PID" 2>/dev/null; then
  echo stop >&6
  exec 6>&- 5<&-
  ended "$SAMPLER_PID" 30 || kill_started "$SAMPLER_PID"
fi
[ -z "$WATCHER" ] || kill_started "$WATCHER"
echo "ax-events.txt: $(grep -c "" "$EVENTS") lines; samples.log: $(grep -c "" "$ARBOR_OUT/samples.log" 2>/dev/null || true) lines"
ctl resume
arbor_stop
echo "clock: all done ${SECONDS}s after the script began"
