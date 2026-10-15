# The journey of probe-went-and-came-back.sh and of its control, second playing: a display goes and comes back, with four windows that live on it and two
# that lie across its edge. Read in by those two, which say whether Arbor runs (JOURNEY_ARBOR=yes|no) and differ in nothing else but the places. Do not run it.
# And by probe-the-top-corners.sh, which plays one part of it alone. JOURNEY_PARTS names the parts to play: S F M L D H P1 if nothing is said, which is
# what the two play. T (without Arbor) is played only where it is named, after P1. A part that is not named is left out without a word but for the line
# `parts: …`; the build, the Mac, `stays`, the windows, `arbor`, `quit`, `end` and the clean-up are always played, s0 to s2 and z1 for any of S F M L D H, s2c for S and
# F; STRADDLES and CARRIED are opened for all but T. D asks what it asks only straight after a return: name it with L. T alone (probe-the-top-corners.sh) has
# no `stays` and opens LIVES, TEXT and JAVA only.
#
# Nothing here is a verdict. The script ends itself (`die`, exit code 2) only where going on would measure nothing: a tool that did not compile, a display
# that did not come, no sampler, fewer than two windows, no window on A, with Arbor no trace at the start. What else goes wrong is said (`!!!`, `SKIPPED:`) and
# the journey goes on. It checks at the end that every window is within reach. Everything else is written down for a program to read.
#
# WHO IS WHO
#   LIVES       Notes                      wholly on display A from s2 on, put through Accessibility
#   TEXT        TextEdit, a document       the same. Moved by the pointer at m3, minimized at h1
#   JAVA        jconsole, a Java app       the same. The one window that is not Apple's and not AppKit's (Chrome and Firefox did not open on a hosted Mac)
#   PICTURE     Preview, a picture         the same. Its app is hidden at h1. (Console, should Preview open no window)
#   STRADDLES   Terminal                   across the edge between the main display and A, most of it on A, put through Accessibility
#   CARRIED     TextEdit, a second document   across the same edge, most of it on the MAIN display, carried there by the real pointer and dropped (s2c). Neither a
#                                          clamp wholly onto A nor one wholly onto the main display gives the x it is dropped at, nor STRADDLES' x
#   DESK        Script Editor, a script    wholly on the main display throughout: a bystander, and what Arbor docks and frames at d1 and P1c. (Or Activity Monitor)
#   stays       a virtual display, 1280×720, serial 9, left of the main one, from before anything is measured until the end: on a hosted Mac the
#               FIRST virtual display may also change the main display's size, and that change is to be over and done with
#   A           1920×1080, serial 1, right of the main one
#   B           1280×800, serial 2: ANOTHER display, not another mode. In A's place (s6), left of `stays` (f1), under the main one (f3), at the right (P1)
#   below       1920×1080, serial 3, under the main display and 160 points wider on either side, so that it lies under both bottom corners (P1 alone)
# macOS knows a display by vendor, product and serial number (vdisplay.m), so A is the same display every time it comes, and B never is A.
# An app that opens no window is left out with a `!!!`, and the journey goes on with the rest.
#
# THE PLACES DIFFER between the two scripts, by 40 points to the right and 30 down in the control, on A and on the main display alike: whichever plays second,
# a window found at the other script's place has inherited it.
#
# THE STEPS. Each: a mark in the samples and in the trace, the act, four seconds of rest (JOURNEY_REST), then the lines below.
#   stays  the display that stays is plugged in         open-<NAME>  the windows are opened; every other app with a window is hidden
#   arbor  Arbor is started (the control: `pgrep -x Arbor` finds none)
#  S, the first playing's steps with more windows
#   s0   every window is put wholly on the main display      s1   plug A
#   s2   LIVES, TEXT, JAVA and PICTURE are put wholly on A, STRADDLES across the edge, through Accessibility
#   s2c  CARRIED is carried across the edge by its title bar with the real pointer and dropped; tried twice
#   s3   unplug A      s4  plug A      s5  unplug A      s6  plug B in A's place      s7  unplug B      s8  plug A, after another display has been and gone
#  F, a change elsewhere while A is there and two windows hang over the main display's right edge: does either move?
#   f1   plug B left of `stays`      f2  unplug B      f3  plug B under the main display      f4  unplug B
#  M, moved while the display is away
#   m1   unplug A      m2  LIVES is moved on the main display through Accessibility      m3  TEXT is moved there by the pointer; tried twice
#   m4   plug A: do the two stay or go? JAVA and PICTURE, which nobody touched, are the comparison      m5  all are put as at s2 again
#  L, a longer absence
#   l1   unplug A, and thirty seconds of rest (JOURNEY_LONG)      l2  plug A
#  D, with Arbor alone: straight after that return, a move of the view on the MAIN display
#   d1   DESK is docked at the left of the main display and framed (`dock`, `zoom`): `parked` says of every window whether Arbor took it out of view
#   d2   `show-all`, and DESK floats again
#  H, hidden and minimized
#   h0   all are put as at s2 again      h1  PICTURE's app is hidden and TEXT is minimized, both on A
#   h2   unplug A: where do Accessibility and the window server have the two?
#   h3   the app is unhidden, the window restored: `whole` says whether each lies wholly on one display      h4  plug A
#  z1    unplug A
#  P1, with Arbor alone: see part_P1
#  T, without Arbor and only where JOURNEY_PARTS names it: the top corners. t0 to t9: see part_T
#   quit   Arbor quits (the control: nothing happens)               end    the display that stays is unplugged
# A display that does not come where it belongs is moved there at once (`vdisplay move`), and the line `> plug` says which of the two it was.
#
# THE OUTPUT, for a program. After every step:
#   displays <step> id <id> serial <n> frame <x> <y> <w> <h> <main|-> ; id …        every display, by `vdisplay list`, whose lines follow as they are
#   at <step> <NAME> <window id> ax <x y w h> server <x y w h>      Accessibility's frame (apptool describe), the window server's (pointer frame); `- - - -`: no answer
#   share <step> <NAME> <window id> shown <0…1> lies <0…1> on <display> flags <…>     shown: how much of it is on one display, 0 if the window server does not
#                                show it (pointer visible); lies: the same by its frame alone, shown or not, and which display that is; flags: apptool's (minimized…)
#   arbor <step> | …             with Arbor: its own account (lib.sh's `summary`): the displays with their visible frames, each window with the frame
#                                Arbor last saw, THE DISPLAY WHOSE WORKSPACE HOLDS IT, floating, docked, parked, minimized, hidden
#   log <step> …                 with Arbor, after a change of displays: what its log says of it ("disconnected; remembering N", "reconnected; N … returned", "displays changed")
#   books <step> <plug|unplug> A lie <n> (<ids>) filed <n> (<ids>) log <N> went <n> (<ids>)      with Arbor, three numbers that should be one: how many windows lie
#                                mostly on A by the window server, how many Arbor's account has under A, and the N of its log. At an unplug the first two are from just
#                                before it, at a plug from after it; `went`: what the account had under A just before A last went
#   clock: <step> done <n>s …    seconds since the script began
# Besides: `put <step> <NAME> <id> asked <x y w h> took <x y w h>`; `carry <step> <NAME> <id> try <n> …` and `carried … dropped at <x y w h>`; `> plug`, `> unplug`;
#   `window <NAME> …` once; `parts: …` once; `whole`, `parked`, `corner`, `visible` where the steps above name them;
#   `SKIPPED: <what>` for a step the clock left no time for (none begins after JOURNEY_BUDGET seconds, 900) and for what hangs on something that failed;
#   `!!! …` for what spoils the comparison (a display is not where it was, a window is missing or not where it was put, Arbor has ended, an Arbor runs in the
#   control) and for four findings: Arbor's log counts fewer windows than its account had under A; its account has fewer under A than lie on it; a window that
#   lay on A was parked at d1; no top corner in P1.
#
# WHAT COMES BACK in mac-shell/ (the last lines of the output list it):
#   samples.log         the window server's list sixty times a second (sampler.swift), from before `stays` until after `end`, with lib-day.sh's marks:
#                       `M begin <n> <name>`, `M text <n> …`, `M end <n> …`, `M label <id> <NAME>`. A change of displays is called `display-<step>-…`
#   macos-reports.log   what Accessibility reported of the apps' windows, to the millisecond (apptool watch), with the steps as `SCRIPT ==` lines
#   traces/*.jsonl      with Arbor: went-and-came-back-S, -F, -M, -L, -D, -H, -P1, one for each part, every step as a remark (docs/TRACES.md)
#   arbor-<script>.log  with Arbor: its log at debug level.
# A reader of the `Y` lines has to keep every display, by its id: `stays` is one of them.
case "${JOURNEY_ARBOR:-}" in
  yes | no) ;;
  *)
    echo "probe-went-and-came-back-journey.sh is read in by probe-went-and-came-back.sh and by its control, which say whether Arbor runs" >&2
    exit 64 ;;
esac
JOURNEY_BUDGET=${JOURNEY_BUDGET:-900}
JOURNEY_REST=${JOURNEY_REST:-4}
JOURNEY_LONG=${JOURNEY_LONG:-30}
# Which parts are played, whatever the order they are named in: always in the order S F M L D H P1 T.
JOURNEY_PARTS=${JOURNEY_PARTS:-S F M L D H P1}
for part in $JOURNEY_PARTS; do
  case "$part" in
    S | F | M | L | D | H | P1 | T) ;;
    *) echo "JOURNEY_PARTS: no part is called $part (S F M L D H P1 T)" >&2; exit 64 ;;
  esac
done
# Under the 1,200 s of scripts/ci-mac-shell.sh, so that a journey that hangs is ended by lib.sh's supervisor, which cleans up and lets the logs come back.
ARBOR_TIME_LIMIT=${ARBOR_TIME_LIMIT:-1020}
source "$(dirname "${BASH_SOURCE[0]}")/lib-day.sh"
needs_throwaway_mac "plug virtual displays in and out, switch the display's size, change the setting Reduce Motion, hide apps, drag windows, and open and quit six apps"
# lib-day.sh writes it for the journeys of the gate (docs/VIABLE.md), and this is none.
rm -f "$ARBOR_OUT/run.json"

# The windows that opened, by name. W_<NAME> is a window's id, P_<NAME> its process.
CAST=""
W_LIVES="" W_TEXT="" W_JAVA="" W_PICTURE="" W_STRADDLES="" W_CARRIED="" W_DESK=""
P_LIVES="" P_TEXT="" P_JAVA="" P_PICTURE="" P_STRADDLES="" P_CARRIED="" P_DESK=""
# Those that are meant to lie wholly on A, and those of them that were seen to when they were last put there.
FOR_A="LIVES TEXT JAVA PICTURE"
ON_A=""
# The displays that are plugged in, by name, in the order they came; how many the Mac has of its own; the main one as `id x y w h` once `stays` is there.
PLUGGED=""
BUILT_IN=1
MAIN=""
# A's identifier, which is Arbor's name for it and stays the same from plug to plug; the windows Arbor's account had under A when it last went, and those
# of which most lay on A then, by the window server. NOT_ARBORS: the windows Arbor does not arrange, which are in none of its accounts.
UUID_A=""
FILED_UNDER_A=""
LAY_ON_A=""
NOT_ARBORS=""
HIDDEN=""
MOTION_WAS=""

with_arbor() { [ "$JOURNEY_ARBOR" = yes ]; }
in_cast() { case " $CAST " in *" $1 "*) return 0 ;; esac; return 1; }
plays() { case " $JOURNEY_PARTS " in *" $1 "*) return 0 ;; esac; return 1; }
# The parts that begin with A plugged in and the windows on it: s0, s1 and s2 are played for them. Those and P1 have the two windows that lie across the edge.
begins_on_A() { plays S || plays F || plays M || plays L || plays D || plays H; }
# T alone has no display that stays, and three windows.
only_T() { [ "$JOURNEY_PARTS" = T ]; }
if with_arbor; then OX=0 OY=0; else OX=40 OY=30; fi

# MARK: The clock, and words

in_time() {
  [ "$SECONDS" -lt "$JOURNEY_BUDGET" ] && return 0
  echo "SKIPPED: $* (${SECONDS}s have gone, the budget is ${JOURNEY_BUDGET}s)"
  return 1
}
clock() { echo "clock: $* ${SECONDS}s after the script began, at $(date -u +%H:%M:%SZ)"; }
loud() { echo "!!! $*"; }
# no_arbor <step>: says whether an Arbor runs, loudly if one does
no_arbor() {
  local found
  found=$(pgrep -x Arbor | tr '\n' ' ')
  if [ -z "$found" ]; then
    echo "no Arbor runs at $1: \`pgrep -x Arbor\` finds no process"
  else
    loud "$1: AN ARBOR RUNS (\`pgrep -x Arbor\`: $found)"
  fi
}

# within <seconds> <command…>: tries it until it holds. Prints what the last try printed if it never did.
within() {
  local until=$((SECONDS + $1)) output
  shift
  while :; do
    if output=$("$@" 2>&1); then return 0; fi
    if [ "$SECONDS" -ge "$until" ]; then
      printf '%s\n' "$output"
      return 1
    fi
    sleep 0.2
  done
}

# record <name>: a new trace; fails unless Arbor then says that it is recording. arbor_start_apps does not look at ARBOR_RECORD, which is arbor_start's: the
# trace is asked for by name, as lib-day.sh asks for its own.
record() {
  if [ "${ARBOR_RECORD:-}" != 1 ]; then
    echo "trace: none, because ARBOR_RECORD is not 1"
    return 1
  fi
  arborctl trace off > /dev/null 2>&1
  echo "trace: $(arborctl trace on "$1" 2>&1 | sed "s|$ARBOR_HOME/||")"
  arborctl trace status 2>/dev/null | grep -q "^recording "
}

# part <letter> "<title>": a heading, and with Arbor a trace of its own: a trace ends by itself after ten minutes, and a part is what is read together.
part() {
  step "$1. $2"
  arbor_answers || return 0
  record "went-and-came-back-$1" || loud "part $1: NO TRACE is being recorded ($(arborctl trace status 2>&1 | head -n 1))"
}

# A journey without samples is a run for nothing, and a mark written to a sampler that has gone would end the script with SIGPIPE.
sampler_lives() { [ -n "$DAY_SAMPLER_PID" ] && kill -0 "$DAY_SAMPLER_PID" 2>/dev/null; }

# begin_step <kind> <name> "<what happens>": lib-day.sh's `act`, which writes the marks.
begin_step() {
  sampler_lives || die "the sampler has ended ($(tail -n 1 "$ARBOR_OUT/sampler.log" 2>/dev/null)): nothing would be seen from here on"
  act "$@"
}

# The rest after the act (REST_NOW: another length, for this once), and the step's end in the samples. judge=no: jolts.py, should anybody ask it, has no rule for this.
rested() {
  sleep "${REST_NOW:-$JOURNEY_REST}"
  sampler_lives && note "end $DAY_STEP act=$DAY_KIND judge=no"
}

# Where the pointer waits while nothing is carried: the same point of the main display in both scripts. It presses nothing.
rest_pointer() { move 800 600; }

# MARK: Displays. lib.sh's display_add knows one; here up to four are plugged in at a time, as in check-F58.sh, part 5b.

# display_facts <name>: width height serial side
display_facts() {
  case "$1" in
    stays) echo "1280 720 9 left" ;;
    A) echo "1920 1080 1 right" ;;
    B) echo "1280 800 2 right" ;;
    below) echo "1920 1080 3 under-and-wider" ;;
  esac
}

# x y w h, as `pointer displays` has it.
frame_of_display() { pointer displays | awk -v id="$1" '$1 == id { print $2, $3, $4, $5 }'; }

await_count() {
  # shellcheck disable=SC2086
  set -- $PLUGGED
  arbor_await_displays "$((BUILT_IN + $#))" || loud "macOS lists $ARBOR_DISPLAY_COUNT displays five seconds later, not $((BUILT_IN + $#))"
}

# plug <name> [side]: right, left, under (flush with the main display's left edge), under-and-wider (centred under it), left-of-stays, left-and-lower (500 points
# down), right-and-higher (700 points up), above (flush with the left edge)
plug() {
  local name=$1 width="" height="" serial="" side="" file pid hello="" tries=0 id x y main at
  read -r width height serial side <<< "$(display_facts "$name")"
  [ -n "$side" ] || die "plug: no display is called $name"
  side=${2:-$side}
  case " $PLUGGED " in *" $name "*) die "plug: display $name is plugged in already" ;; esac
  file="$APPS_TEMP/display-$name"
  : > "$file"
  # Straight from this shell, never from within $( ) or ( ): vdisplay unplugs its display when its parent has gone.
  "$ARBOR_VDISPLAY" add "$width" "$height" "Arbor Test Display $name" --serial "$serial" \
    > "$file" 2>> "$ARBOR_OUT/vdisplay.log" 3>&- 5<&- 6>&- 8>&- 9>&- &
  pid=$!
  started "$pid"
  while [ -z "$hello" ] && [ "$tries" -lt 80 ] && kill -0 "$pid" 2>/dev/null; do
    sleep 0.1
    hello=$(head -n 1 "$file")
    tries=$((tries + 1))
  done
  if [ -z "$hello" ]; then
    kill_started "$pid"
    die "plug: display $name did not come ($(tail -n 1 "$ARBOR_OUT/vdisplay.log"))"
  fi
  id=${hello%% *}
  [ "$name" != A ] || UUID_A=${hello##* }
  PLUGGED="$PLUGGED $name"
  await_count
  # The main display's origin is 0 0: that is what makes it the main one.
  main=$("$ARBOR_VDISPLAY" list | awk '$8 == "main" { print $5, $6 }')
  case "$side" in
    right) x=${main% *} y=0 ;;
    left) x=-$width y=0 ;;
    left-of-stays) x=$((-1280 - width)) y=0 ;;
    under) x=0 y=${main#* } ;;
    under-and-wider) x=$(((${main% *} - width) / 2)) y=${main#* } ;;
    left-and-lower) x=-$width y=500 ;;
    right-and-higher) x=${main% *} y=-700 ;;
    above) x=0 y=-$height ;;
    *) die "plug: no side is called $side" ;;
  esac
  eval "DISPLAY_PID_$name=\$pid DISPLAY_ID_$name=\$id DISPLAY_AT_$name=\"\$x \$y \$width \$height\""
  at=$("$ARBOR_VDISPLAY" list | awk -v id="$id" '$1 == id { print $3, $4 }')
  if [ "$at" = "$x $y" ]; then
    echo "> plug $name: display $id, serial $serial, $width x $height: it came at $at, where it belongs, and is not moved"
  else
    echo "> plug $name: display $id, serial $serial, $width x $height: it came at $at and is moved to $x $y: now at $("$ARBOR_VDISPLAY" move "$id" "$x" "$y" 2>&1)"
  fi
}

unplug() {
  local name=$1 pid each kept=""
  eval "pid=\${DISPLAY_PID_$name:-}"
  [ -n "$pid" ] || return 0
  echo "> unplug $name"
  kill -TERM "$pid" 2>/dev/null
  ended "$pid" 50 || kill_started "$pid"
  eval "DISPLAY_PID_$name= DISPLAY_ID_$name= DISPLAY_AT_$name="
  for each in $PLUGGED; do [ "$each" = "$name" ] || kept="$kept $each"; done
  PLUGGED=$kept
  await_count
}

# MARK: What is written down after every step

# lies "<x y w h>" "<what vdisplay list printed>": <0…1> <display>: how much of the rectangle lies on the display that has most of it, and which that is
lies() {
  local each id names=""
  for each in $PLUGGED; do
    eval "id=\$DISPLAY_ID_$each"
    names="$names $id=$each"
  done
  echo "$2" | awk -v frame="$1" -v names="$names" '
    BEGIN {
      split(frame, f, " ")
      count = split(names, pair, " ")
      for (i = 1; i <= count; i++) { split(pair[i], part, "="); name[part[1]] = part[2] }
      best = 0
      where = "none"
    }
    {
      across = (f[1] + f[3] < $3 + $5 ? f[1] + f[3] : $3 + $5) - (f[1] > $3 ? f[1] : $3)
      down = (f[2] + f[4] < $4 + $6 ? f[2] + f[4] : $4 + $6) - (f[2] > $4 ? f[2] : $4)
      if (across > 0 && down > 0 && f[3] * f[4] > 0 && across * down / (f[3] * f[4]) > best) {
        best = across * down / (f[3] * f[4])
        where = ($8 == "main" ? "main" : (($1 in name) ? name[$1] : $1))
      }
    }
    END { printf "%.2f %s\n", best, where }'
}

tell() {
  local step=$1 list main name id at want said ax server
  list=$("$ARBOR_VDISPLAY" list)
  echo "displays $step $(echo "$list" | awk '{ printf "%sid %s serial %s frame %s %s %s %s %s", (NR > 1 ? " ; " : ""), $1, $11, $3, $4, $5, $6, $8 }')"
  echo "$list" | sed 's/^/  vdisplay list: /'
  main=$(echo "$list" | awk '$8 == "main" { print $1, $3, $4, $5, $6 }')
  if [ -n "$MAIN" ] && [ "$main" != "$MAIN" ]; then
    loud "$step: THE MAIN DISPLAY IS NOT WHAT IT WAS: it was $MAIN (id x y w h) and is ${main:-not listed}"
  fi
  for name in $PLUGGED; do
    eval "id=\$DISPLAY_ID_$name want=\$DISPLAY_AT_$name"
    at=$(echo "$list" | awk -v id="$id" '$1 == id { print $3, $4, $5, $6 }')
    [ "$at" = "$want" ] || loud "$step: display $name ($id) belongs at $want and is at ${at:-no place: it is not listed}"
  done
  for name in $CAST; do
    eval "id=\$W_$name"
    said=$(apptool describe "$id" 2>/dev/null)
    ax=$(echo "$said" | awk 'NF >= 7 { print $4, $5, $6, $7 }')
    server=$(real_frame_of "$id" 2>/dev/null)
    echo "at $step $name $id ax ${ax:-- - - -} server ${server:-- - - -}"
    echo "share $step $name $id shown $("$ARBOR_POINTER" visible "$id" 2>/dev/null || echo -) lies $(lies "$server" "$list" | sed 's/ / on /') flags $(echo "$said" | awk '{ print ($8 == "" ? "?" : $8) }')"
  done
  if arbor_answers; then
    summary 2>&1 | sed "s/^/arbor $step | /"
  elif with_arbor && [ -n "$ARBOR_PID" ]; then
    loud "$step: ARBOR'S PROCESS HAS ENDED, and nobody asked it to: from here on this is macOS alone"
  fi
  clock "$step done"
}

# filed_under <display's identifier>: the windows Arbor's own account has in that display's workspace
filed_under() {
  arborctl state 2>/dev/null | python3 -c '
import json, sys
try:
    windows = json.load(sys.stdin)["state"]["windows"]
except (ValueError, KeyError):
    sys.exit(0)
print(" ".join(str(window["id"]) for window in windows if window.get("display") == sys.argv[1]))' "$1"
}

# lying_on_A: the windows Arbor arranges of which most lies on A, by the window server
lying_on_A() {
  local list name id found=""
  list=$("$ARBOR_VDISPLAY" list)
  for name in $CAST; do
    case " $NOT_ARBORS " in *" $name "*) continue ;; esac
    eval "id=\$W_$name"
    case "$(lies "$(real_frame_of "$id" 2>/dev/null)" "$list")" in *" A") found="$found $id" ;; esac
  done
  echo "${found# }"
}
how_many() { echo $#; }

# books <step> <plug|unplug> <display> <lines arbor.log had before>: what Arbor's log says of the change. For A, three numbers that should be one: how many windows
# lay on it, how many Arbor's account had under it, how many its log speaks of. At an unplug the first two are from just before; at a plug `went` has those, and
# `lie` and `filed` are from now.
books() {
  local step=$1 what=$2 which=$3 said number lie filed
  said=$(arbor_log_since "$4" | cut -c 26- | grep -E "disconnected; remembering|reconnected; |displays changed|already has an arrangement")
  echo "${said:-nothing about the displays}" | sed "s/^/log $step /"
  [ "$which" = A ] || return 0
  number=$(echo "$said" | grep -F "display $UUID_A " | sed -n -E 's/.*(remembering|reconnected;) ([0-9]+) window.*/\2/p' | tail -n 1)
  # No line at all is what Arbor writes when the workspace that goes holds no window.
  number=${number:-0}
  if [ "$what" = unplug ]; then lie=$LAY_ON_A filed=$FILED_UNDER_A; else lie=$(lying_on_A) filed=$(filed_under "$UUID_A"); fi
  # shellcheck disable=SC2086
  echo "books $step $what A lie $(how_many $lie) (${lie:-none}) filed $(how_many $filed) (${filed:-none}) log $number went $(how_many $FILED_UNDER_A) (${FILED_UNDER_A:-none})"
  # shellcheck disable=SC2086
  [ "$number" -ge "$(how_many $FILED_UNDER_A)" ] \
    || loud "$step: Arbor's log counts $number window(s) at this $what of A, and its own account had $(how_many $FILED_UNDER_A) under A before A went: $FILED_UNDER_A"
  # shellcheck disable=SC2086
  [ "$(how_many $filed)" -ge "$(how_many $lie)" ] \
    || loud "$step: Arbor's account has $(how_many $filed) window(s) under A (${filed:-none}), and $(how_many $lie) lie on it (${lie:-none})"
}

# change <step> plug|unplug <display> [side]: if the clock allows. change_now: whatever the clock says, for what has to be undone.
change_now() {
  local lines=""
  if arbor_answers; then
    lines=$(arbor_log_lines)
    if [ "$2 $3" = "unplug A" ]; then FILED_UNDER_A=$(filed_under "$UUID_A") LAY_ON_A=$(lying_on_A); fi
  fi
  begin_step display-change "display-$1-$2-$3" "$1: display $3: $2${4:+, $4}"
  "$2" "$3" ${4:+"$4"}
  rested
  tell "$1"
  [ -z "$lines" ] || books "$1" "$2" "$3" "$lines"
}
change() {
  in_time "$1 ($2 $3)" || return 0
  # What was left out before this leaves nothing to unplug, and nothing is plugged in twice.
  case "$2 $PLUGGED " in
    "plug "*" $3 "*) echo "SKIPPED: $1 ($2 $3): it is plugged in"; return 0 ;;
    "plug "*) ;;
    "unplug "*" $3 "*) ;;
    *) echo "SKIPPED: $1 ($2 $3): it is not plugged in"; return 0 ;;
  esac
  change_now "$@"
}
A_is_there() { [ -n "${DISPLAY_ID_A:-}" ]; }
# with_A <part>: whether there is time for the part, and A to play it with
with_A() {
  in_time "$1, all of it" || return 1
  A_is_there && return 0
  echo "SKIPPED: $1, all of it: A is not plugged in"
  return 1
}

# MARK: Putting a window somewhere, through Accessibility and by hand

# wholly_on "<a display's x y w h>" "<a window's x y w h>"
wholly_on() { inside "$2" "$1"; }
# across <x> "<a window's x y w h>": part of it lies left of that line and part of it right
across() {
  local x="" w=""
  read -r x _ w _ <<< "$2"
  [ -n "$w" ] || return 1
  x=${x%.*} w=${w%.*}
  [ "$x" -lt "$1" ] && [ $((x + w)) -gt "$1" ]
}
# near <x> <y> "<a window's x y w h>": its corner is within 40 points of there. A dragged window trails a posted pointer.
near() {
  local x="" y=""
  read -r x y _ <<< "$3"
  [ -n "$y" ] || return 1
  about "${x%.*}" "$1" 40 > /dev/null && about "${y%.*}" "$2" 40 > /dev/null
}

# put <step> <NAME> <x> <y> <w> <h> <test…>: asks through Accessibility (apptool set-frame: size, position, size, as Arbor sets a frame), then asks the window server
# until `<test…> "<its frame>"` holds. `-` for w and h: the size it has. Asked a second time after two seconds; after six it says so, loudly, and fails.
put() {
  local step=$1 name=$2 x=$3 y=$4 w=$5 h=$6 id began=$SECONDS again=""
  shift 6
  eval "id=\$W_$name"
  if [ "$w" = - ]; then read -r _ _ w h <<< "$(real_of "$id")"; fi
  echo "put $step $name $id asked $x $y $w $h took $(apptool set-frame "$id" "$x" "$y" "$w" "$h" 2>&1)"
  until "$@" "$(real_frame_of "$id" 2>/dev/null)"; do
    if [ -z "$again" ] && [ $((SECONDS - began)) -ge 2 ]; then
      again=yes
      echo "put $step $name $id asked $x $y $w $h took $(apptool set-frame "$id" "$x" "$y" "$w" "$h" 2>&1) (asked again: the window server had it at $(real_frame_of "$id" 2>&1))"
    elif [ $((SECONDS - began)) -ge 6 ]; then
      loud "$step: $name (window $id) was asked twice to go to $x $y $w $h and is at $(real_frame_of "$id" 2>&1) six seconds later, which is not where it should lie ($*)"
      return 1
    fi
    sleep 0.1
  done
}

# carry <step> <NAME> <x> <y> <test…>: the real pointer takes the window by a free point of its title bar, carries it until its corner should be at x y, and lets go
# (lib-day.sh's drag_window, which lets go at once of a press that did not take hold). Its app is clicked forward first: a press on a window of an app that is
# not in front is passed on late. Then the window server is asked whether `<test…> "<its frame>"` holds. Tried twice.
carry() {
  local step=$1 name=$2 x=$3 y=$4 id try gx gy role cx cy
  shift 4
  eval "id=\$W_$name"
  for try in 1 2; do
    app_focus "$id" > /dev/null 2>&1 || echo "carry $step $name $id try $try: the click on its title bar did not bring its app forward"
    gx="" gy="" role="" cx="" cy=""
    read -r gx gy role <<< "$(apptool grab "$id" 2>/dev/null)"
    read -r cx cy _ <<< "$(real_of "$id")"
    if [ -z "$gy" ] || [ -z "$cy" ]; then
      echo "carry $step $name $id try $try: no free point of its title bar shows"
      continue
    fi
    gx=${gx%.*} gy=${gy%.*}
    echo "carry $step $name $id try $try: from $cx $cy, taken at $gx $gy ($role), to $x $y"
    # Whatever drag_window says: it goes by one look at the window server's list, which lags, and may take a press that did take hold for one that did not.
    drag_window "$id" "$((gx + x - cx))" "$((gy + y - cy))" --hold 0.4
    sleep 0.6
    if "$@" "$(real_frame_of "$id" 2>/dev/null)"; then
      echo "carried $step $name $id dropped at $(real_frame_of "$id")"
      rest_pointer
      return 0
    fi
    echo "carry $step $name $id try $try: it lies at $(real_frame_of "$id" 2>&1), which is not where it should ($*)"
  done
  rest_pointer
  return 1
}

# place <home|A> <NAME>: x y w h from the display's corner, before the script's own 40 and 30 points. `-`: the size it has (Terminal rounds sizes to its cells).
place() {
  case "$1 $2" in
    "home LIVES") echo "300 105 1000 660" ;;
    "home TEXT") echo "60 60 640 420" ;;
    "home JAVA") echo "700 90 800 560" ;;
    "home PICTURE") echo "120 340 720 420" ;;
    "home STRADDLES") echo "500 330 - -" ;;
    "home CARRIED") echo "860 250 - -" ;;
    "home DESK") echo "230 250 620 460" ;;
    "A LIVES") echo "450 190 1000 660" ;;
    "A TEXT") echo "90 70 640 420" ;;
    "A JAVA") echo "1040 90 800 560" ;;
    "A PICTURE") echo "150 600 720 420" ;;
    "A STRADDLES") echo "-150 300 - -" ;;
  esac
}

# put_home <step>: every window wholly on the main display. What fails has been said loudly.
put_home() {
  local step=$1 main name x y w h
  in_time "$step (every window is put on the main display)" || return 1
  main=$(frame_of_display "${MAIN%% *}")
  begin_step instrument "put-$step-home" "$step: every window is put wholly on the main display, through Accessibility"
  for name in $CAST; do
    read -r x y w h <<< "$(place home "$name")"
    put "$step" "$name" "$((x + OX))" "$((y + OY))" "$w" "$h" wholly_on "$main"
  done
  rested
  tell "$step"
}

# put_on_A <step>: FOR_A wholly on A, STRADDLES across the edge. ON_A: those that then lie wholly on A.
put_on_A() {
  local step=$1 name x y w h ax="" ay="" aw="" ah=""
  A_is_there || { echo "SKIPPED: $step (the windows are put on A): A is not plugged in"; return 1; }
  in_time "$step (the windows are put on A)" || return 1
  begin_step instrument "put-$step-on-A" "$step: $FOR_A are put wholly on A$(in_cast STRADDLES && echo " and STRADDLES across the edge between the main display and A"), through Accessibility"
  read -r ax ay aw ah <<< "$(frame_of_display "$DISPLAY_ID_A")"
  [ -n "$ah" ] || die "$step: \`pointer displays\` does not list display A ($DISPLAY_ID_A)"
  ON_A=""
  for name in $FOR_A; do
    in_cast "$name" || continue
    read -r x y w h <<< "$(place A "$name")"
    if put "$step" "$name" "$((ax + x + OX))" "$((ay + y + OY))" "$w" "$h" wholly_on "$ax $ay $aw $ah"; then ON_A="$ON_A $name"; fi
  done
  if in_cast STRADDLES; then
    read -r x y w h <<< "$(place A STRADDLES)"
    put "$step" STRADDLES "$((ax + x + OX))" "$((ay + y + OY))" "$w" "$h" across "$ax"
  fi
  rested
  tell "$step"
  # shellcheck disable=SC2086
  set -- $ON_A
  echo "on A after $step: $# window(s):$ON_A"
  if [ $# -eq 0 ] && [ "$step" = s2 ]; then die "$step: no window lies on A: there is nothing to go and come back"; fi
  [ $# -ge 3 ] || loud "$step: FEWER THAN THREE WINDOWS LIE WHOLLY ON A ($#): if one of them speaks early, little is left for Arbor to remember"
}

# MARK: However it ends, the Mac is as it was found

journey_leave() {
  local each
  arbor_stop
  for each in $PLUGGED; do unplug "$each"; done
  if sampler_lives; then
    sampler_stop
  elif [ -n "$DAY_SAMPLER_PID" ]; then
    exec 6>&- 5<&-
    DAY_SAMPLER_PID=""
    [ -z "$DAY_WITNESS_PID" ] || kill_started "$DAY_WITNESS_PID"
    DAY_WITNESS_PID=""
  fi
  watch_stop
  # Started by this script itself and not through `open`, so lib-apps.sh does not know it.
  [ -z "$P_JAVA" ] || kill_started "$P_JAVA"
  P_JAVA=""
  for each in $HIDDEN; do apptool unhide "$each" > /dev/null 2>&1; done
  HIDDEN=""
  [ "$MOTION_WAS" != true ] || macos_reduce_motion on
  MOTION_WAS=""
}

# In place of lib-day.sh's last words, which would have jolts.py judge the samples. Then lib-apps.sh's clean-up, which quits the apps and takes the exit code from here.
journey_last_words() {
  local code=$?
  trap '' TERM INT
  journey_leave
  return "$code"
}
trap 'journey_last_words; apps_exit' EXIT

# MARK: The build

step "the build"
if with_arbor; then
  day_build
else
  # No Arbor is built, so none can be started by a slip. day_build_tools leaves out the one tool that is not Swift.
  day_build_tools
  arbor_is_current "$ARBOR_ROOT/scripts/mac-shell/vdisplay.m" "$ARBOR_VDISPLAY" \
    || clang -fobjc-arc -O1 -framework Foundation -framework ApplicationServices -framework CoreGraphics -framework ColorSync \
      "$ARBOR_ROOT/scripts/mac-shell/vdisplay.m" -o "$ARBOR_VDISPLAY" > "$ARBOR_OUT/build-vdisplay.log" 2>&1 \
    || cat "$ARBOR_OUT/build-vdisplay.log"
fi
[ -x "$ARBOR_VDISPLAY" ] || die "scripts/mac-shell/vdisplay.m did not compile: no virtual display, no journey"
clock "built"

# MARK: The Mac

step "the Mac"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m), commit $(git rev-parse --short HEAD)"
echo "this is $ARBOR_NAME: $(if with_arbor; then echo "WITH ARBOR"; else echo "THE CONTROL, without Arbor"; fi); playing ${MAC_SHELL_PART:-1} of ${MAC_SHELL_PARTS:-1} on this dispatch"
echo "its places are $OX points to the right and $OY down of the table's"
echo "parts: $JOURNEY_PARTS"
# The size the first playing had. A hosted Mac's own 1024×768 is smaller than the windows need.
display_mode 1600x900 1680x1050 1920x1080
macos_tiling
# A hosted Mac comes with Reduce Motion on, a person's does not. Arbor reads it when it starts. Put back at the end.
MOTION_WAS=$("$ARBOR_POINTER" reduce-motion 2>/dev/null)
macos_reduce_motion off
arbor_count_displays
BUILT_IN=$ARBOR_DISPLAY_COUNT
[ "$BUILT_IN" -eq 1 ] || loud "this Mac has $BUILT_IN displays before any is plugged in"
tell before

sampler_start
sleep 1

if only_T; then
  step "no display stays: a display comes and goes once, before the main display's frame is read"
  change_now t0a plug B
  change_now t0b unplug B
else
  step "the display that stays"
  change_now stays plug stays
fi
MAIN=$("$ARBOR_VDISPLAY" list | awk '$8 == "main" { print $1, $3, $4, $5, $6 }')
[ -n "$MAIN" ] || die "vdisplay list names no main display"
echo "the main display from here on (id x y w h): $MAIN"

# MARK: The windows

# opens <NAME> <bundle id> [file]: lib-day.sh's `meet`. An app that opens no standard window is quit again, and the journey goes on without it.
opens() {
  local name=$1 pid
  shift
  begin_step open-close "open-$name" "opens $1"
  if APP_WAIT=25 APP_OPEN_LIMIT=90 meet "$name" "$@"; then
    eval "pid=\$P_$name"
    app_dismiss "$pid" || echo "a sheet or a dialog stayed in the way of $name"
    CAST="$CAST $name"
  else
    loud "$name: $1 opened no standard window: the journey goes on without it"
    eval "pid=\$P_$name"
    app_quit "$pid"
    eval "W_$name= P_$name="
  fi
  REST_NOW=2 rested
}

step "the windows"
apps_scratch
opens LIVES com.apple.Notes
opens TEXT com.apple.TextEdit "$APPS_SCRATCH/oak.txt"
begin_step open-close open-JAVA "starts jconsole, a Java app"
if java=$("${JOURNEY_JAVA_HOME:-/usr/libexec/java_home}" 2>/dev/null) && [ -x "$java/bin/jconsole" ]; then
  "$java/bin/jconsole" > /dev/null 2>&1 3>&- 5<&- 6>&- 8>&- 9>&- &
  P_JAVA=$!
  started "$P_JAVA"
  # T alone is to be short: there it has eight seconds to open its window.
  W_JAVA=$(apptool wait-window "$P_JAVA" "$(if only_T; then echo 8; else echo 25; fi)" | awk '$3 == "AXStandardWindow" { print $1; exit }')
fi
if [ -n "$W_JAVA" ]; then
  label "$W_JAVA" JAVA
  CAST="$CAST JAVA"
else
  loud "JAVA: no jconsole, or it opened no standard window: every window of this journey is Apple's"
  [ -z "$P_JAVA" ] || kill_started "$P_JAVA"
  P_JAVA=""
fi
REST_NOW=2 rested
if ! only_T; then
  opens PICTURE com.apple.Preview "$APPS_SCRATCH/leaf.png"
  in_cast PICTURE || opens PICTURE com.apple.Console
fi
if begins_on_A || plays P1; then
  opens STRADDLES com.apple.Terminal
  begin_step open-close open-CARRIED "opens a second document in TextEdit"
  if in_cast TEXT && app_open com.apple.TextEdit "$APPS_SCRATCH/elm.txt" > /dev/null && app_await_window "$P_TEXT" "$W_TEXT" 10; then
    W_CARRIED=$NEW_WINDOW P_CARRIED=$P_TEXT
    label "$W_CARRIED" CARRIED
    CAST="$CAST CARRIED"
  else
    loud "CARRIED: TextEdit opened no second window: no window is carried by the pointer"
  fi
  REST_NOW=2 rested
fi
if ! only_T; then
  opens DESK com.apple.ScriptEditor2 "$APPS_SCRATCH/hello.applescript"
  in_cast DESK || opens DESK com.apple.ActivityMonitor
fi

# An app may have swapped the window it opened with for another meanwhile.
kept=""
for name in $CAST; do
  eval "pid=\$P_$name window=\$W_$name"
  listed=$(app_windows "$pid")
  case " $listed " in
    *" $window "*) kept="$kept $name"; continue ;;
  esac
  fresh=""
  for id in $listed; do
    case " $W_TEXT $W_CARRIED " in *" $id "*) ;; *) fresh=$id; break ;; esac
  done
  if [ -n "$fresh" ]; then
    eval "W_$name=\$fresh"
    label "$fresh" "$name"
    kept="$kept $name"
  else
    loud "$name has no standard window any more: the journey goes on without it"
  fi
done
CAST=$kept
pids=""
for name in $CAST; do
  eval "pid=\$P_$name window=\$W_$name"
  echo "window $name $window pid $pid: $(apptool describe "$window" 2>&1)"
  case " $pids " in *" $pid "*) ;; *) pids="$pids $pid" ;; esac
done
# shellcheck disable=SC2086
set -- $CAST
[ $# -ge 2 ] || die "fewer than two windows opened: no journey to speak of"
# shellcheck disable=SC2086
watch_start macos-reports.log $pids

# Whatever else has an ordinary window on the screen is hidden, if it is an app that can be; unhidden at the end.
for pid in $(pointer windows --on-screen | awk '$3 == 0 { print $2 }' | sort -u); do
  case " $pids " in *" $pid "*) continue ;; esac
  app=$(apptool apps | awk -v pid="$pid" '$1 == pid && $2 == "regular" { print $4 }')
  if [ -n "$app" ] && apptool hide "$pid"; then
    HIDDEN="$HIDDEN $pid"
    echo "hidden: $app (process $pid)"
  fi
done
sleep 1
echo "on the screen now, from the front (id pid level x y w h on owner):"
pointer windows --on-screen | head -n 40

# MARK: Arbor, or none

# As a person runs it: every regular app's windows, its shortcuts, its event taps, its menu bar item, the settings it ships with. All but the
# welcome window (ARBOR_NO_PROMPT=1 is arbor_start_apps' own), which would lie over the windows until a pointer closed it.
start_arbor() {
  arbor_start_apps all ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0 || return 1
  note "arbor $ARBOR_PID"
}

step "Arbor"
if with_arbor; then
  [ ! -e "$ARBOR_HOME/settings.json" ] || die "there is a settings.json in Arbor's home: these would not be the settings it ships with"
  begin_step quit-and-start arbor "arbor: Arbor is started"
  start_arbor || die "Arbor did not start"
  floating=0
  for name in $CAST; do
    eval "window=\$W_$name"
    if why=$(within 8 is floating "$window"); then
      floating=$((floating + 1))
    else
      NOT_ARBORS="$NOT_ARBORS $name"
      loud "$name (window $window) does not float eight seconds after Arbor started: $why. It stays in the journey: macOS moves it all the same"
    fi
  done
  [ "$floating" -ge 2 ] || die "fewer than two windows float: Arbor has nothing to remember or to fetch"
  why=$(count docked 0) || die "something is docked, and nothing should be: $why"
  if arborctl status | grep -q "^paused"; then die "Arbor is paused: $(arborctl status | head -n 1)"; fi
  echo "$floating windows float, nothing is docked, Arbor is not paused, and its home holds no settings.json"
  # A trace begins when things are at rest (docs/TRACES.md): what a start has still scheduled would not be in its header.
  sleep 2
else
  begin_step quit-and-start arbor "arbor: no Arbor is started: this is the control"
  found=$(pgrep -x Arbor | tr '\n' ' ')
  [ -z "$found" ] || die "this is the control, and an Arbor is running (\`pgrep -x Arbor\`: $found)"
  echo "no Arbor runs: \`pgrep -x Arbor\` finds no process; none is built or started by this script, and the question is asked again after the last step"
fi
rest_pointer
rested
tell arbor

# MARK: S. The first playing's steps, with more windows

if begins_on_A; then
  step "S. the display goes and comes back"
  if with_arbor; then
    record went-and-came-back-S || die "no trace is being recorded: what Arbor asks of the windows, which is the question, would not come back"
  fi
  put_home s0
  change s1 plug A
  put_on_A s2
fi
if ! plays S && ! plays F; then
  :
elif ! in_cast CARRIED; then
  echo "SKIPPED: s2c (a window is carried across the edge by the pointer): there is no such window"
elif ! A_is_there; then
  echo "SKIPPED: s2c (a window is carried across the edge by the pointer): A is not plugged in"
elif in_time "s2c (a window is carried across the edge by the pointer)"; then
  begin_step drag carry-s2c-across "s2c: CARRIED is taken by its title bar with the real pointer, carried until some 200 points of it hang over the main display's right edge, and dropped"
  read -r edge _ <<< "$DISPLAY_AT_A"
  read -r _ _ cw _ <<< "$(real_of "$W_CARRIED")"
  if carry s2c CARRIED "$((edge - cw + 200 + OX))" "$((420 + OY))" across "$edge"; then
    if arbor_answers && ! is floating "$W_CARRIED" > /dev/null 2>&1; then loud "s2c: CARRIED does not float any more: the drop docked it"; fi
  else
    echo "SKIPPED: what is asked of a window that a hand dropped across the edge: CARRIED was not carried there and lies at $(real_frame_of "$W_CARRIED" 2>&1)"
  fi
  rested
  tell s2c
fi
if plays S; then
  change s3 unplug A
  change s4 plug A
  change s5 unplug A
  change s6 plug B
  change s7 unplug B
  change s8 plug A
fi

# MARK: F. A change elsewhere, while A is there and windows hang over the main display's right edge

if plays F && with_A F; then
  part F "a change of displays elsewhere, while A is there"
  change f1 plug B left-of-stays
  change f2 unplug B
  change f3 plug B under
  change f4 unplug B
fi

# MARK: M. Moved on the main display while A is away

if plays M && with_A M; then
  part M "windows of A's are moved on the main display while A is away"
  change m1 unplug A
  if in_cast LIVES && in_time "m2 (LIVES is moved through Accessibility)"; then
    begin_step instrument put-m2-moved "m2: LIVES is moved on the main display, through Accessibility, at the size it has"
    put m2 LIVES "$((140 + OX))" "$((150 + OY))" - - near "$((140 + OX))" "$((150 + OY))" \
      || echo "SKIPPED: what m4 is asked about a window moved through Accessibility: LIVES was not moved"
    rested
    tell m2
  fi
  if in_cast TEXT && in_time "m3 (TEXT is moved by the pointer)"; then
    begin_step drag carry-m3-moved "m3: TEXT is taken by its title bar with the real pointer, carried elsewhere on the main display, and dropped"
    carry m3 TEXT "$((820 + OX))" "$((380 + OY))" near "$((820 + OX))" "$((380 + OY))" \
      || echo "SKIPPED: what m4 is asked about a window moved by hand: TEXT was not carried and lies at $(real_frame_of "$W_TEXT" 2>&1)"
    rested
    tell m3
  fi
  change m4 plug A
  put_on_A m5
fi

# MARK: L. A longer absence

if plays L && with_A L; then
  part L "a longer absence"
  REST_NOW=$JOURNEY_LONG change l1 unplug A
  change l2 plug A
fi

# MARK: D, with Arbor alone. After a return, the view moves on the MAIN display: is a window that lies on A taken out of view?

# Straight after l2, with nothing in between: Arbor's account is to be as the return left it, and putting the windows anywhere first might set it right.

# parked_now <step> <which lay where before: "NAME=display …">: of every window whether Arbor's account has it out of view, and where the window server has it
parked_ids() {
  arborctl state 2>/dev/null | python3 -c '
import json, sys
try:
    print(" ".join(str(window["id"]) for window in json.load(sys.stdin)["state"]["windows"] if window.get("parked")))
except (ValueError, KeyError):
    pass'
}
parked_now() {
  local step=$1 before=" $2 " name id ids
  ids=" $(parked_ids) "
  for name in $CAST; do
    eval "id=\$W_$name"
    case "$ids" in
      *" $id "*)
        echo "parked $step $name $id yes server $(real_frame_of "$id" 2>&1)"
        case "$before" in *" $name=A "*) loud "$step: $name lay on A and Arbor took it out of view when the view moved on the main display" ;; esac ;;
      *) echo "parked $step $name $id no server $(real_frame_of "$id" 2>&1)" ;;
    esac
  done
}
# dock_and_frame <step>: DESK at the left of the main display, framed
dock_and_frame() {
  ctl dock "$W_DESK" left
  within 5 is docked "$W_DESK" > /dev/null || loud "$1: DESK is not docked"
  ctl zoom "$W_DESK"
}
if ! with_arbor || ! plays D; then
  :
elif ! arbor_answers || ! in_cast DESK || ! A_is_there; then
  echo "SKIPPED: D, all of it: it takes Arbor, DESK and A"
elif in_time "D, all of it"; then
  part D "after a return, DESK is docked and framed on the main display"
  list=$("$ARBOR_VDISPLAY" list)
  before=""
  for name in $CAST; do
    eval "window=\$W_$name"
    before="$before $name=$(lies "$(real_frame_of "$window" 2>/dev/null)" "$list" | cut -d ' ' -f 2)"
  done
  echo "before d1 each window lies mostly on:$before"
  begin_step view dock-d1-and-frame "d1: DESK is docked at the left of the main display and framed"
  dock_and_frame d1
  rested
  tell d1
  parked_now d1 "$before"
  begin_step view show-d2-all "d2: everything is shown again, and DESK floats again"
  ctl show-all
  ctl float "$W_DESK"
  rested
  tell d2
fi

# MARK: H. Hidden and minimized

# whole <step> <NAME>: is all of it on one display, and shown?
whole() {
  local id shown
  eval "id=\$W_$2"
  shown=$("$ARBOR_POINTER" visible "$id" 2>/dev/null)
  echo "whole $1 $2 $id $([ "$shown" = 1.00 ] && echo yes || echo no) shown ${shown:--} server $(real_frame_of "$id" 2>&1)"
}
# hide_and_minimize <step> "<what the step says>", unhide_and_restore <step> "<…>": each a step of its own. AWAY: they are, until they are shown again.
AWAY=""
hide_and_minimize() {
  begin_step macos-own "hide-$1" "$2"
  AWAY=yes
  if in_cast PICTURE; then apptool hide "$P_PICTURE" || loud "$1: PICTURE's app was not hidden"; else echo "SKIPPED: the hidden window: there is no PICTURE"; fi
  if in_cast TEXT; then apptool minimize "$W_TEXT" || loud "$1: TEXT was not minimized"; else echo "SKIPPED: the minimized window: there is no TEXT"; fi
  rested
  tell "$1"
}
unhide_and_restore() {
  local name
  begin_step macos-own "unhide-$1" "$2"
  if in_cast PICTURE; then apptool unhide "$P_PICTURE" || loud "$1: PICTURE's app was not unhidden"; fi
  if in_cast TEXT; then apptool unminimize "$W_TEXT" || loud "$1: TEXT was not restored"; fi
  AWAY=""
  rested
  tell "$1"
  for name in PICTURE TEXT; do
    if in_cast "$name"; then whole "$1" "$name"; fi
  done
}
if plays H && with_A H; then
  part H "a hidden app's window and a minimized window, both on A"
  put_on_A h0
  hide_and_minimize h1 "h1: PICTURE's app is hidden and TEXT is minimized, both on A"
  change h2 unplug A
  unhide_and_restore h3 "h3: PICTURE's app is unhidden and TEXT is restored, while A is away"
  change h4 plug A
fi

if begins_on_A; then
  step "A goes for the last time"
  change z1 unplug A
fi

# MARK: P1, with Arbor alone: windows that are out of view, with a display under both bottom corners of the main one

# Where does a floating window rest that Arbor has taken out of view, when a display lies under the corners it would be kept in? And how often is it sent there again
# when the displays change? The second is for the trace to say: count the setFrame calls to each window after each `displaysChanged`.
#   P1a  plug `below`               P1b  every window home on the main display
#   P1c  DESK is docked at the left and framed, so that the others, which float, go out of view. `parked` says which, `corner` in which corner of the main
#        display each rests, `visible` what Arbor takes for the main display's visible frame
#   P1d  plug B at the right    P1e  unplug B    P1f  plug B    P1g  unplug B    P1h  unplug `below`: five more reports of the displays, `corner` after each
# corners <step>: top|middle|bottom - left|right|under|within, by the window server's frame against the main display's
corners() {
  local step=$1 name id x y w h mx my mw mh level side low=""
  read -r _ mx my mw mh <<< "$MAIN"
  for name in $CAST; do
    eval "id=\$W_$name"
    is parked "$id" > /dev/null 2>&1 || continue
    x="" y="" w="" h=""
    read -r x y w h <<< "$(real_of "$id")"
    [ -n "$h" ] || continue
    if [ "$y" -le $((my + 60)) ]; then level=top; elif [ "$y" -ge $((my + mh - 130)) ]; then level=bottom; else level=middle; fi
    if [ "$x" -ge $((mx + mw - 3)) ]; then side=right; elif [ $((x + w)) -le $((mx + 3)) ]; then side=left; elif [ "$level" = bottom ]; then side=under; else side=within; fi
    echo "corner $step $name $id $level-$side server $x $y $w $h"
    [ "$level" = top ] || low="$low $name"
  done
  # Without a display below, the bottom corners are where nothing shows.
  case " $PLUGGED " in
    *" below "*) [ -z "$low" ] || loud "$step: NO TOP CORNER, with a display under both bottom corners, for:$low" ;;
  esac
}
part_P1() {
  local each
  in_time "P1, all of it" || return 0
  if ! arbor_answers || ! in_cast DESK; then
    echo "SKIPPED: P1, all of it: it takes Arbor and DESK"
    return 0
  fi
  part P1 "out of view, with a display under both bottom corners of the main one"
  change P1a plug below
  put_home P1b || return 0
  begin_step view dock-P1c-and-frame "P1c: DESK is docked at the left and framed: the others, which float, go out of view"
  dock_and_frame P1c
  rested
  tell P1c
  parked_now P1c ""
  corners P1c
  echo "visible P1c main $(screen_of 1 2>&1)"
  if [ "$(arbor_ask count parked 0 > /dev/null 2>&1 && echo none)" = none ]; then
    echo "SKIPPED: P1d to P1g: no window went out of view"
  else
    for each in "P1d plug" "P1e unplug" "P1f plug" "P1g unplug"; do
      # shellcheck disable=SC2086
      change $each B
      in_time "the corners after ${each% *}" && corners "${each% *}"
    done
  fi
  change P1h unplug below
  in_time "the corners after P1h" && corners P1h
}
if with_arbor && plays P1; then part_P1; fi

# MARK: T, without Arbor: the top corners

# Asked through Accessibility for a place under the menu bar AT A TOP CORNER of the main display, where does a window end? On record so far are eight calls, all in the
# middle of a display (x 170 or 220; asked for y 0 and y -50; the window went to the visible top, 31, and kept its x and its size), and none at a corner.
# TEXT at 640×420, LIVES at 1000×660 if they take those sizes, JAVA at the size it has. In each arrangement each window is asked four times with `apptool set-frame` (size, position, size, as Arbor sets a
# frame), each time from 300 200 on the main display, where it is put and seen to lie first:
#   a  the top RIGHT corner: x = the main display's right edge less 1, y = its top      b  the same x, y 50 points above the top
#   c  the top LEFT corner: x = its left edge less the window's width plus 1, y = its top      d  the same x, y 50 points above the top
# And in t1 and t2 two places at the bottom, for the table to be laid beside another probe's:
#   e  the bottom RIGHT corner: x = the right edge less 1, y = the bottom less 1      f  x = the right edge of the VISIBLE frame less 1, the same y; left out where that is e
# A second later: `top <arrangement> <NAME> <id> asked <x y w h> | accessibility <x y w h> | server <x y w h> | shown <0.00…1.00> on <display>`: how much of it is on one display
# (pointer visible), and the display most of its frame lies on. Before it `answer …`, what set-frame read back at once.
# Each ask is a step in the samples, top-<arrangement>-<NAME>-<a…f>. `dock: …`, once: where the Dock is, and what is taken off each side of the main display.
# Played in this order, so that what the clock cuts is what matters least:
#   t2  `below`, 1920×1080, centred under the main display       t3  a left neighbour that begins lower: B at -1280, 500
#   t5  a display above: B at 0, -800                            t4  the left neighbour of t3, and A at the right
#   t1  the main display alone                                   t6  a right neighbour that begins higher: A at the main display's width, -700
# Of the first window, TEXT, a picture is taken at each resting place with lib.sh's `shot`, which takes every display, one file each: top-<arrangement>-<a…f>.png is
# the main display, -d2.png and -d3.png the others, to be told apart by their sizes (1280 wide: B; 1600, made smaller from 1920: A or `below`).
# `stays` lies at the left and would change the question. Played alone, this part never plugs it in: B is plugged in and out once instead (t0a, t0b), so that whatever the
# first virtual display does to the main display's size is over before its frame is read. Played after other parts, `stays` is unplugged for the part (t0) and
# plugged in again after it (t9).
# `visible <arrangement> <display> <x y w h>`: each display between its menu bar and the Dock, as the sampler last wrote it down (its V and Y lines: NSScreen's visibleFrame).
# A display that macOS does not have where it was asked for is a `!!!`, and the arrangement is SKIPPED.
T_NAMES=""

visible_frames() {
  local name id
  echo "visible $1 main $(awk '$2 == "V" { seen = $3 " " $4 " " $5 " " $6 } END { print (seen == "" ? "not known" : seen) }' "$DAY_SAMPLES")"
  for name in $PLUGGED; do
    eval "id=\$DISPLAY_ID_$name"
    echo "visible $1 $name $(awk -v id="$id" '$2 == "Y" && $3 == id && NF >= 11 { seen = $8 " " $9 " " $10 " " $11 } END { print (seen == "" ? "not known" : seen) }' "$DAY_SAMPLES")"
  done
}

# in_place <arrangement> <display>: whether macOS has it where `plug` asked for it. `tell` has said so loudly if not.
in_place() {
  local id want
  eval "id=\${DISPLAY_ID_$2:-} want=\${DISPLAY_AT_$2:-}"
  if [ -n "$id" ] && [ "$("$ARBOR_VDISPLAY" list | awk -v id="$id" '$1 == id { print $3, $4, $5, $6 }')" = "$want" ]; then return 0; fi
  echo "SKIPPED: $1: display $2 is not where the arrangement wants it"
  return 1
}

# top_corners <arrangement>: the four asks of each window
top_corners() {
  local t=$1 list mx="" my="" mw="" mh="" vx="" vw="" name id hx=300 hy=200 w h letters="a b c d" letter x y said server
  in_time "$t (the asks)" || return 0
  list=$("$ARBOR_VDISPLAY" list)
  read -r mx my mw mh <<< "$(echo "$list" | awk '$8 == "main" { print $3, $4, $5, $6 }')"
  [ -n "$mh" ] || { echo "SKIPPED: $t: vdisplay list names no main display"; return 0; }
  visible_frames "$t"
  case "$t" in t1 | t2) letters="a b c d e f" ;; esac
  read -r vx _ vw _ <<< "$(awk '$2 == "V" { seen = $3 " " $4 " " $5 " " $6 } END { print seen }' "$DAY_SAMPLES")"
  for name in $T_NAMES; do
    in_time "$t $name" || return 0
    eval "id=\$W_$name"
    for letter in $letters; do
      if [ "$letter" = f ] && [ -z "$vw" ]; then
        echo "SKIPPED: top $t $name f: the main display's visible frame is not known"
        continue
      elif [ "$letter" = f ] && [ $((vx + vw)) -eq $((mx + mw)) ]; then
        echo "SKIPPED: top $t $name f: the same place as e: nothing is taken off the main display's right"
        continue
      fi
      put "$t" "$name" "$hx" "$hy" - - near "$hx" "$hy" || { echo "SKIPPED: top $t $name $letter: it is not at $hx $hy, where every ask begins"; continue; }
      sleep 0.3
      w="" h=""
      read -r _ _ w h <<< "$(real_of "$id")"
      [ -n "$h" ] || { echo "SKIPPED: top $t $name $letter: the window server does not say how large it is"; continue; }
      case "$letter" in
        a) x=$((mx + mw - 1)) y=$my ;;
        b) x=$((mx + mw - 1)) y=$((my - 50)) ;;
        c) x=$((mx - w + 1)) y=$my ;;
        d) x=$((mx - w + 1)) y=$((my - 50)) ;;
        e) x=$((mx + mw - 1)) y=$((my + mh - 1)) ;;
        f) x=$((vx + vw - 1)) y=$((my + mh - 1)) ;;
      esac
      begin_step instrument "top-$t-$name-$letter" "$t: $name is asked through Accessibility for $x $y, at the size it has"
      echo "answer $t $name $id asked $x $y $w $h took $(apptool set-frame "$id" "$x" "$y" "$w" "$h" 2>&1)"
      REST_NOW=1 rested
      said=$(apptool describe "$id" 2>/dev/null | awk 'NF >= 7 { print $4, $5, $6, $7 }')
      server=$(real_frame_of "$id" 2>/dev/null)
      echo "top $t $name $id asked $x $y $w $h | accessibility ${said:-- - - -} | server ${server:-- - - -} | shown $("$ARBOR_POINTER" visible "$id" 2>/dev/null || echo -) on $(lies "$server" "$list" | cut -d ' ' -f 2)"
      # It has rested a second already.
      if [ "$name" = "${T_NAMES%% *}" ]; then ARBOR_SETTLE=0 shot "top-$t-$letter"; fi
    done
    put "$t" "$name" "$hx" "$hy" - - near "$hx" "$hy"
  done
  clock "$t asked"
}

part_T() {
  local name again=""
  in_time "T, all of it" || return 0
  step "T. the top corners"
  no_arbor T
  for name in TEXT LIVES JAVA; do
    if in_cast "$name"; then T_NAMES="${T_NAMES:+$T_NAMES }$name"; fi
  done
  # Wider than 501 points, both: in t3 and t4 the top left place then lies nearer to the left neighbour, 500 points below it, than to the main display, a window's width
  # less 1 away. Only so do "the nearest display stops it" and "the display that has most of it stops it" give two answers. JAVA keeps the size it has.
  if in_cast TEXT; then put T TEXT 300 200 640 420 near 300 200; fi
  if in_cast LIVES; then put T LIVES 300 200 1000 660 near 300 200; fi
  case " $PLUGGED " in
    *" stays "*)
      change_now t0 unplug stays
      again=yes
      MAIN=$("$ARBOR_VDISPLAY" list | awk '$8 == "main" { print $1, $3, $4, $5, $6 }')
      echo "the main display while \`stays\` is away (id x y w h): $MAIN" ;;
  esac
  echo "dock: orientation $(defaults read com.apple.dock orientation 2>/dev/null || echo "not set, which is the bottom"), autohide $(defaults read com.apple.dock autohide 2>/dev/null || echo "not set, which is off");" \
    "the main display ${MAIN#* }, visible $(awk '$2 == "V" { seen = $3 " " $4 " " $5 " " $6 } END { print (seen == "" ? "not known" : seen) }' "$DAY_SAMPLES")"
  change t2 plug below under-and-wider
  if in_place t2 below; then top_corners t2; fi
  change t2z unplug below
  change t3 plug B left-and-lower
  if in_place t3 B; then top_corners t3; fi
  change t3z unplug B
  change t5 plug B above
  if in_place t5 B; then top_corners t5; fi
  change t5z unplug B
  change t4b plug B left-and-lower
  change t4 plug A right
  if in_place t4 B && in_place t4 A; then top_corners t4; fi
  change t4y unplug A
  change t4z unplug B
  top_corners t1
  change t6 plug A right-and-higher
  if in_place t6 A; then top_corners t6; fi
  change t6z unplug A
  if [ -n "$again" ]; then
    # Whatever the clock says: the end expects it.
    for name in $PLUGGED; do change_now "t9-$name" unplug "$name"; done
    change_now t9 plug stays
    MAIN=$("$ARBOR_VDISPLAY" list | awk '$8 == "main" { print $1, $3, $4, $5, $6 }')
  fi
}
if ! plays T; then
  :
elif with_arbor; then
  echo "SKIPPED: T, all of it: it is asked of macOS alone, and this script runs Arbor"
else
  part_T
fi

# MARK: The end

step "the end"
# Only a part that was cut short has left them so.
[ -z "$AWAY" ] || unhide_and_restore end-shown "end-shown: PICTURE's app is unhidden and TEXT is restored"
if with_arbor; then
  begin_step quit-and-start quit "quit: Arbor quits"
  # Quitting ends the trace. arbor_stop brings the log and the traces to mac-shell/.
  arbor_stop
  step "after Arbor"
else
  begin_step quit-and-start quit "quit: nothing happens: the control has no Arbor to quit"
fi
rested
tell quit
# Only what was cut short has left anything but `stays`.
for name in $PLUGGED; do [ "$name" = stays ] || change_now "end-$name" unplug "$name"; done
MAIN=""
case " $PLUGGED " in
  *" stays "*) change_now end unplug stays ;;
  *) tell end ;;
esac
found=$(pgrep -x Arbor | tr '\n' ' ')
if [ -z "$found" ]; then
  echo "no Arbor runs now: \`pgrep -x Arbor\` finds no process"
else
  loud "AN ARBOR RUNS after the last step (\`pgrep -x Arbor\`: $found)"
fi

# A tenth: a window that hangs over an edge is not lost. What this is after is one that nobody could get hold of: left in Arbor's corner, hidden, in the Dock,
# or beyond every display.
within_reach() {
  local share
  share=$(arbor_share_in_view "$1") || return 1
  echo "$share % of it lie on a display: $(real_frame_of "$1")"
  [ "$share" -ge 10 ]
}
for name in $CAST; do
  eval "window=\$W_$name"
  echo "reach $name $window $(within_reach "$window" 2>&1)"
  check "$name is within reach at the end: a tenth of it or more lies on a display" within_reach "$window"
done

journey_leave
step "what came back"
echo "mac-shell/samples.log: $(lines_of "$ARBOR_OUT/samples.log") lines, $(grep -c " M begin " "$ARBOR_OUT/samples.log" 2>/dev/null) steps"
echo "  the sampler's own account: $(tail -n 1 "$ARBOR_OUT/samples.log" 2>/dev/null | cut -d ' ' -f 2-)"
echo "mac-shell/macos-reports.log: $(lines_of "$ARBOR_OUT/macos-reports.log") lines"
if with_arbor; then
  for file in "$ARBOR_OUT"/traces/*.jsonl; do
    [ -f "$file" ] || { loud "NO TRACE CAME BACK"; continue; }
    echo "mac-shell/traces/$(basename "$file"): $(lines_of "$file") lines, $(grep -c "displaysChanged" "$file") with displaysChanged in them"
  done
  echo "mac-shell/$(arbor_log_name arbor): $(lines_of "$ARBOR_OUT/$(arbor_log_name arbor)") lines"
fi
clock "all done"
