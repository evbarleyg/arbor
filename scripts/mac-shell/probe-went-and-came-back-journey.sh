# The journey of probe-went-and-came-back.sh and of its control: a display goes and comes back, with one window that lives on it and one that
# lies across its edge. Read in by those two, which say whether Arbor runs (JOURNEY_ARBOR=yes|no) and differ in nothing else. Do not run it.
#
# Nothing here is a verdict. The script ends itself (`die`, exit code 2) where going on would measure nothing: a tool that did not compile, a
# display that did not come, a window that does not lie where it was put, with Arbor a window that does not float or no trace. And it checks at
# the end that both windows are within reach. Everything else is written down for a program to read.
#
# WHO IS WHO
#   LIVES       Notes' window (TextEdit's, should Notes open none; the output says which): wholly on display A from s2 on
#   STRADDLES   Terminal's window: across the edge between the main display and A from s2 on, 150 points of it on the main one
#   stays       a virtual display, 1280×720, serial 9, left of the main one, from before anything is measured until the end: on a hosted Mac the
#               FIRST virtual display also changes the main display's size, and that change is to be over and done with
#   A           1920×1080, serial 1, right of the main one          B    1280×800, serial 2, in the same place: ANOTHER display, not another mode
#   below       1280×720, serial 3, under the main one (P1 alone)
# macOS knows a display by vendor, product and serial number (vdisplay.m), so A is the same display every time it comes, and B never is A.
#
# THE STEPS. Each: a mark in the samples and in the trace, the act, four seconds of rest (JOURNEY_REST), then the lines below.
#   stays  the display that stays is plugged in                     open-…  the two apps are opened, every other app with a window is hidden
#   arbor  Arbor is started (the control: `pgrep -x Arbor` finds none)
#   s0     both windows are put wholly on the main display, at the same two places in both scripts: apps remember frames from the script before
#   s1     plug A                s2   LIVES is put on A, 450 points in and 190 down, 1000×660; STRADDLES across the edge
#   s3     unplug A              s4   plug A              s5   unplug A
#   s6     plug B                s7   unplug B
#   s8     plug A: the telling one. Under macOS alone Notes once went to the place it had had on the display in that size, not to where it was last
#   s9     unplug A              s10  plug A              s11  unplug A
#   P1a…   with Arbor alone, and only if the clock allows: see part_P1
#   quit   Arbor quits (the control: nothing happens)               end    the display that stays is unplugged
# A window is put with `apptool set-frame` (Accessibility: size, position, size, as Arbor sets a frame), never carried by the pointer, and the
# window server is asked until it lies there by the frames `pointer displays` gives.
# A display that does not come where it belongs is moved there at once (`vdisplay move`), and the line `> plug` says which of the two it was: a
# display macOS has met in this login session comes where it was, one it has not met comes where macOS likes. So the second script to
# play on a Mac may be spared moves at `stays`, s1 and s6 that the first one made.
#
# THE OUTPUT, for a program. After every step:
#   displays <step> id <id> serial <n> frame <x> <y> <w> <h> <main|-> ; id …        every display, by `vdisplay list`, whose lines follow as they are
#   at <step> <LIVES|STRADDLES> <window id> ax <x y w h> server <x y w h>            Accessibility's frame (apptool describe), the window server's
#                                                                                   (pointer frame); `- - - -` where there was no answer
#   arbor <step> | …             with Arbor: its own account (lib.sh's `summary`): the displays with their visible frames, each window with the frame
#                                Arbor last saw, the display whose workspace holds it, floating, docked, parked
#   clock: <step> done <n>s …    seconds since the script began
# Besides: `put <step> <name> <id> asked <x y w h> took <x y w h>` for every frame asked for; `> plug`, `> unplug`; `window <name> …` once;
#   `SKIPPED: <step>` for a step the clock left no time for (no step begins after JOURNEY_BUDGET seconds, 900);
#   `!!! …` for what would spoil the comparison: the main display or a virtual one is not where it was, Arbor has ended, an Arbor runs in the control.
#
# WHAT COMES BACK in mac-shell/ (the last lines of the output list it):
#   samples.log         the window server's list sixty times a second (sampler.swift), from before `stays` until after `end`, with lib-day.sh's marks:
#                       `M begin <n> <name>`, `M text <n> …`, `M end <n> …`, `M label <id> LIVES`. A change of displays is called `display-<step>-…`
#   macos-reports.log   what Accessibility reported of the two apps' windows, to the millisecond (apptool watch), with the steps as `SCRIPT ==` lines
#   traces/*.jsonl      with Arbor: went-and-came-back (arbor to s11) and went-and-came-back-P1, every step as a remark (docs/TRACES.md)
#   arbor-<script>.log  with Arbor: its log at debug level
# A reader that keeps ONE second display from the `Y` lines takes `stays` for it until A first goes: it has to keep them all, by their ids.
case "${JOURNEY_ARBOR:-}" in
  yes | no) ;;
  *)
    echo "probe-went-and-came-back-journey.sh is read in by probe-went-and-came-back.sh and by its control, which say whether Arbor runs" >&2
    exit 64 ;;
esac
JOURNEY_BUDGET=${JOURNEY_BUDGET:-900}
JOURNEY_REST=${JOURNEY_REST:-4}
# Under the 1,200 s of scripts/ci-mac-shell.sh, so that a journey that hangs is ended by lib.sh's supervisor, which cleans up and lets the logs come back.
ARBOR_TIME_LIMIT=${ARBOR_TIME_LIMIT:-1020}
source "$(dirname "${BASH_SOURCE[0]}")/lib-day.sh"
needs_throwaway_mac "plug virtual displays in and out, switch the display's size, change the setting Reduce Motion, hide apps, and open and quit Notes and Terminal"
# lib-day.sh writes it for the journeys of the gate (docs/VIABLE.md), and this is none.
rm -f "$ARBOR_OUT/run.json"

W_LIVES="" W_STRADDLES="" P_LIVES="" P_STRADDLES=""
LIVES_APP=""
# The displays that are plugged in, by name, in the order they came; how many the Mac has of its own; the main one as `id x y w h` once `stays` is there.
PLUGGED=""
BUILT_IN=1
MAIN=""
HIDDEN=""
MOTION_WAS=""

with_arbor() { [ "$JOURNEY_ARBOR" = yes ]; }

# MARK: The clock, and words

in_time() {
  [ "$SECONDS" -lt "$JOURNEY_BUDGET" ] && return 0
  echo "SKIPPED: $* (${SECONDS}s have gone, the budget is ${JOURNEY_BUDGET}s)"
  return 1
}
clock() { echo "clock: $* ${SECONDS}s after the script began, at $(date -u +%H:%M:%SZ)"; }
loud() { echo "!!! $*"; }

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
  echo "trace: $(arborctl trace status 2>&1 | sed "s|$ARBOR_HOME/||")"
  arborctl trace status 2>/dev/null | grep -q "^recording "
}

# A journey without samples is a run for nothing, and a mark written to a sampler that has gone would end the script with SIGPIPE.
sampler_lives() { [ -n "$DAY_SAMPLER_PID" ] && kill -0 "$DAY_SAMPLER_PID" 2>/dev/null; }

# begin_step <kind> <name> "<what happens>": lib-day.sh's `act`, which writes the marks.
begin_step() {
  sampler_lives || die "the sampler has ended ($(tail -n 1 "$ARBOR_OUT/sampler.log" 2>/dev/null)): nothing would be seen from here on"
  act "$@"
}

# The rest after the act, and the step's end in the samples. judge=no: jolts.py, should anybody ask it, has no rule for this.
rested() {
  sleep "$JOURNEY_REST"
  sampler_lives && note "end $DAY_STEP act=$DAY_KIND judge=no"
}

# MARK: Displays. lib.sh's display_add knows one; here up to three are plugged in at a time, as in check-F58.sh, part 5b.

# display_facts <name>: width height serial side
display_facts() {
  case "$1" in
    stays) echo "1280 720 9 left" ;;
    A) echo "1920 1080 1 right" ;;
    B) echo "1280 800 2 right" ;;
    below) echo "1280 720 3 below" ;;
  esac
}

# x y w h, as `pointer displays` has it.
frame_of_display() { pointer displays | awk -v id="$1" '$1 == id { print $2, $3, $4, $5 }'; }

await_count() {
  # shellcheck disable=SC2086
  set -- $PLUGGED
  arbor_await_displays "$((BUILT_IN + $#))" || loud "macOS lists $ARBOR_DISPLAY_COUNT displays five seconds later, not $((BUILT_IN + $#))"
}

plug() {
  local name=$1 width="" height="" serial="" side="" file pid hello="" tries=0 id x y main at
  read -r width height serial side <<< "$(display_facts "$name")"
  [ -n "$side" ] || die "plug: no display is called $name"
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
  PLUGGED="$PLUGGED $name"
  await_count
  # The main display's origin is 0 0: that is what makes it the main one.
  main=$("$ARBOR_VDISPLAY" list | awk '$8 == "main" { print $5, $6 }')
  case "$side" in
    right) x=${main% *} y=0 ;;
    left) x=-$width y=0 ;;
    below) x=0 y=${main#* } ;;
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

tell() {
  local step=$1 list main name id at want ax server
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
  for name in LIVES STRADDLES; do
    eval "id=\$W_$name"
    [ -n "$id" ] || continue
    ax=$(apptool describe "$id" 2>/dev/null | awk '{ print $4, $5, $6, $7 }')
    server=$(real_frame_of "$id" 2>/dev/null)
    echo "at $step $name $id ax ${ax:-- - - -} server ${server:-- - - -}"
  done
  if arbor_answers; then
    summary 2>&1 | sed "s/^/arbor $step | /"
  elif with_arbor && [ -n "$ARBOR_PID" ]; then
    loud "$step: ARBOR'S PROCESS HAS ENDED, and nobody asked it to: from here on this is macOS alone"
  fi
  clock "$step done"
}

# change <step> plug|unplug <display>: if the clock allows. change_now: whatever the clock says, for what has to be undone.
change_now() {
  begin_step display-change "display-$1-$2-$3" "$1: display $3: $2"
  "$2" "$3"
  rested
  tell "$1"
}
change() {
  in_time "$1 ($2 $3)" || return 0
  # What the clock left out before this leaves nothing to unplug, and nothing is plugged in twice.
  case "$2 $PLUGGED " in
    "plug "*" $3 "*) echo "SKIPPED: $1 ($2 $3): it is plugged in"; return 0 ;;
    "plug "*) ;;
    "unplug "*" $3 "*) ;;
    *) echo "SKIPPED: $1 ($2 $3): it is not plugged in"; return 0 ;;
  esac
  change_now "$@"
}

# MARK: Putting a window somewhere

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

# put <step> <name> <x> <y> <w> <h> <test…>: asks through Accessibility, then asks the window server until `<test…> "<its frame>"` holds. Asked a second
# time after two seconds. After six the journey is over (an earlier one was lost because a window never got across), or, with PUT_FAILS=return, the part.
PUT_FAILS=die
put() {
  local step=$1 name=$2 x=$3 y=$4 w=$5 h=$6 id began=$SECONDS again=""
  shift 6
  eval "id=\$W_$name"
  echo "put $step $name $id asked $x $y $w $h took $(apptool set-frame "$id" "$x" "$y" "$w" "$h" 2>&1)"
  until "$@" "$(real_frame_of "$id" 2>/dev/null)"; do
    if [ -z "$again" ] && [ $((SECONDS - began)) -ge 2 ]; then
      again=yes
      echo "put $step $name $id asked $x $y $w $h took $(apptool set-frame "$id" "$x" "$y" "$w" "$h" 2>&1) (asked again: the window server had it at $(real_frame_of "$id" 2>&1))"
    elif [ $((SECONDS - began)) -ge 6 ]; then
      tell "$step-failed"
      again="$step: $name (window $id) was asked twice to go to $x $y $w $h and is at $(real_frame_of "$id" 2>&1) six seconds later, which is not where it should lie ($*)"
      [ "$PUT_FAILS" = return ] || die "$again"
      loud "$again"
      return 1
    fi
    sleep 0.1
  done
}

# Both wholly on the main display, at places that are the same in both scripts. STRADDLES keeps the size it has: Terminal rounds sizes to its cells.
put_home() {
  local step=$1 main w="" h=""
  main=$(frame_of_display "${MAIN%% *}")
  begin_step instrument "put-$step-home" "$step: both windows are put wholly on the main display, through Accessibility"
  put "$step" LIVES 300 105 1000 660 wholly_on "$main" || return 1
  read -r _ _ w h <<< "$(real_of "$W_STRADDLES")"
  put "$step" STRADDLES 500 330 "$w" "$h" wholly_on "$main" || return 1
  rested
  tell "$step"
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
# The size the earlier journeys had (the first on offer; a hosted Mac has no 1440×900): its own 1024×768 is smaller than LIVES needs.
display_mode 1440x900 1600x900 1680x1050 1920x1080
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

step "the display that stays"
change_now stays plug stays
MAIN=$("$ARBOR_VDISPLAY" list | awk '$8 == "main" { print $1, $3, $4, $5, $6 }')
[ -n "$MAIN" ] || die "vdisplay list names no main display"
echo "the main display from here on (id x y w h): $MAIN"

# MARK: The two windows

step "the two windows"
begin_step open-close open-LIVES "opens Notes"
LIVES_APP=com.apple.Notes
if ! APP_WAIT=25 APP_OPEN_LIMIT=90 meet LIVES "$LIVES_APP"; then
  echo "Notes opened no standard window: TextEdit stands in for it"
  app_quit "$P_LIVES"
  apps_scratch
  LIVES_APP=com.apple.TextEdit
  APP_WAIT=25 APP_OPEN_LIMIT=90 meet LIVES "$LIVES_APP" "$APPS_SCRATCH/oak.txt" || die "neither Notes nor TextEdit opened a standard window"
fi
app_dismiss "$P_LIVES" || echo "a sheet or a dialog stayed in the way of LIVES"
rested
begin_step open-close open-STRADDLES "opens Terminal"
APP_WAIT=25 APP_OPEN_LIMIT=90 meet STRADDLES com.apple.Terminal || die "Terminal opened no standard window"
app_dismiss "$P_STRADDLES" || echo "a sheet or a dialog stayed in the way of STRADDLES"
rested
# An app may have swapped the window it opened with for another meanwhile.
for name in LIVES STRADDLES; do
  eval "pid=\$P_$name window=\$W_$name"
  listed=$(app_windows "$pid")
  case " $listed " in
    *" $window "*) ;;
    *)
      [ -n "$listed" ] || die "$name has no standard window any more"
      eval "W_$name=\${listed%% *}"
      eval "label \"\$W_$name\" $name" ;;
  esac
done
echo "window LIVES $W_LIVES pid $P_LIVES app $LIVES_APP: $(apptool describe "$W_LIVES" 2>&1)"
echo "window STRADDLES $W_STRADDLES pid $P_STRADDLES app com.apple.Terminal: $(apptool describe "$W_STRADDLES" 2>&1)"
watch_start macos-reports.log "$P_LIVES" "$P_STRADDLES"

# Whatever else has an ordinary window on the screen is hidden, if it is an app that can be; unhidden at the end.
for pid in $(pointer windows --on-screen | awk -v a="$P_LIVES" -v b="$P_STRADDLES" '$3 == 0 && $2 != a && $2 != b { print $2 }' | sort -u); do
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

step "Arbor"
if with_arbor; then
  [ ! -e "$ARBOR_HOME/settings.json" ] || die "there is a settings.json in Arbor's home: these would not be the settings it ships with"
  begin_step quit-and-start arbor "arbor: Arbor is started"
  # As a person runs it: every regular app's windows, its shortcuts, its event taps, its menu bar item, the settings it ships with. All but the
  # welcome window (ARBOR_NO_PROMPT=1 is arbor_start_apps' own), which would lie over the two windows until a pointer closed it.
  arbor_start_apps all ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0 || die "Arbor did not start"
  note "arbor $ARBOR_PID"
  for name in LIVES STRADDLES; do
    eval "window=\$W_$name"
    why=$(within 10 is floating "$window") || die "$name (window $window) does not float ten seconds after Arbor started: $why"
  done
  why=$(count docked 0) || die "something is docked, and nothing should be: $why"
  if arborctl status | grep -q "^paused"; then die "Arbor is paused: $(arborctl status | head -n 1)"; fi
  echo "both windows float, nothing is docked, Arbor is not paused, and its home holds no settings.json"
  # A trace begins when things are at rest (docs/TRACES.md): what a start has still scheduled would not be in its header.
  sleep 2
  record went-and-came-back || die "no trace is being recorded: what Arbor asks of the windows, which is the question, would not come back"
else
  begin_step quit-and-start arbor "arbor: no Arbor is started: this is the control"
  found=$(pgrep -x Arbor | tr '\n' ' ')
  [ -z "$found" ] || die "this is the control, and an Arbor is running (\`pgrep -x Arbor\`: $found)"
  echo "no Arbor runs: \`pgrep -x Arbor\` finds no process; none is built or started by this script, and the question is asked again after the last step"
fi
rested
tell arbor

# MARK: The journey

step "the journey"
put_home s0
change s1 plug A
if [ -z "${DISPLAY_ID_A:-}" ]; then
  echo "SKIPPED: s2 (the windows are put): A is not plugged in"
elif in_time "s2 (the windows are put)"; then
  begin_step instrument put-s2-on-A "s2: LIVES is put wholly on A and STRADDLES across the edge between the main display and A, through Accessibility"
  read -r ax ay aw ah <<< "$(frame_of_display "$DISPLAY_ID_A")"
  [ -n "${ah:-}" ] || die "s2: \`pointer displays\` does not list display A ($DISPLAY_ID_A)"
  put s2 LIVES "$((ax + 450))" "$((ay + 190))" 1000 660 wholly_on "$ax $ay $aw $ah"
  read -r _ _ sw sh <<< "$(real_of "$W_STRADDLES")"
  put s2 STRADDLES "$((ax - 150))" 300 "$sw" "$sh" across "$ax"
  rested
  tell s2
fi
change s3 unplug A
change s4 plug A
change s5 unplug A
change s6 plug B
change s7 unplug B
change s8 plug A
change s9 unplug A
change s10 plug A
change s11 unplug A

# MARK: P1, with Arbor alone: a window that is out of view, with a display below the main one

# Where does a floating window rest that Arbor has taken out of view, when there is a display under the corner it is kept in? And how often is it sent
# there again when the displays change? The second is for the trace to say: count the setFrame calls to LIVES after each `displaysChanged`.
#   P1a  plug `below`               P1b  both windows home on the main display
#   P1c  STRADDLES is docked at the left and framed (`dock`, `zoom`), so that LIVES, which floats, goes out of view. `parked` and `visible` say where to
#   P1d  plug B    P1e  unplug B    P1f  plug B    P1g  unplug B    P1h  unplug `below`: five more reports of the displays
part_P1() {
  local why
  in_time "P1, all of it" || return 0
  arbor_answers || { echo "SKIPPED: P1, all of it: Arbor does not run"; return 0; }
  step "P1. out of view, with a display below the main one"
  record went-and-came-back-P1 || { echo "SKIPPED: P1, all of it: it is the trace that counts the calls, and none is being recorded"; return 0; }
  change P1a plug below
  in_time "P1b to P1h" || return 0
  # The journey proper is over and written down: what fails from here on costs this part alone.
  PUT_FAILS=return
  if ! put_home P1b; then
    echo "SKIPPED: P1c to P1g: the windows are not where the part begins"
    change P1h unplug below
    return 0
  fi
  begin_step view P1c-dock-and-frame "P1c: STRADDLES is docked at the left and framed: LIVES, which floats, goes out of view"
  ctl dock "$W_STRADDLES" left
  within 5 is docked "$W_STRADDLES" > /dev/null || loud "P1c: STRADDLES is not docked"
  ctl zoom "$W_STRADDLES"
  if why=$(within 5 is parked "$W_LIVES"); then
    rested
    tell P1c
    echo "parked P1c LIVES $W_LIVES server $(real_frame_of "$W_LIVES" 2>&1)"
    echo "visible P1c main $(screen_of 1 2>&1)"
    change P1d plug B
    change P1e unplug B
    change P1f plug B
    change P1g unplug B
  else
    rested
    tell P1c
    echo "SKIPPED: P1d to P1g: LIVES did not go out of view: $why"
  fi
  change P1h unplug below
}
if with_arbor; then part_P1; fi

# MARK: The end

step "the end"
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
# Only what the clock cut short has left anything but `stays`.
for name in $PLUGGED; do [ "$name" = stays ] || change_now "end-$name" unplug "$name"; done
MAIN=""
change_now end unplug stays
found=$(pgrep -x Arbor | tr '\n' ' ')
if [ -z "$found" ]; then
  echo "no Arbor runs now: \`pgrep -x Arbor\` finds no process"
else
  loud "AN ARBOR RUNS after the last step (\`pgrep -x Arbor\`: $found)"
fi

# A tenth: macOS alone has been seen to leave a window hanging five sixths over the edge of the only display.
# What this is after is a window that nobody could get hold of: left in Arbor's corner, or beyond every display.
within_reach() {
  local share
  share=$(arbor_share_in_view "$1") || return 1
  echo "$share % of it lie on a display: $(real_frame_of "$1")"
  [ "$share" -ge 10 ]
}
for name in LIVES STRADDLES; do
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
