# Steps that are watched: lib-apps.sh's real apps, with every frame of every window written down while the script plays.
# Source it instead of lib-apps.sh (it sources that first); do not run it. day.sh is the long example.
#
#   #!/bin/bash
#   source "$(dirname "$0")/lib-day.sh"
#   day_build;  apps_scratch;  sampler_start
#   chapter "Morning"
#   act open-close open-textedit "opens TextEdit";    meet textedit com.apple.TextEdit "$APPS_SCRATCH/oak.txt";  acted judge=no
#   act quit-and-start launch "starts Arbor";         day_launch;                      acted
#   act switch click-textedit "clicks its title bar"; click_window "$W_textedit";      acted front="$W_textedit"
#   act dock-key dock-left "presses ⌃⌥⌘←";            key ctrl+opt+cmd+left;           acted moves=docked front="$W_textedit"
#   day_report
#
# A check asks where a window is once things have settled. A person also sees how it got there. So sampler.swift asks the
# window server for every window's frame sixty times a second, a step is ONE thing a person does, and `acted` says what
# that may do: which windows it may move, which one ends in front. jolts.py reads the samples afterwards and says for each step
# which windows moved, how many times, by which road, and which rule of the product's that broke (its header lists them).
#
#   day_build                       apps_build, and compile sampler.swift
#   day_build_tools                 only the tools (pointer, apptool, sampler, witness), for a script in which Arbor does not run
#   sampler_start | sampler_stop    write mac-shell/samples.log from now on | stop. With it goes the witness (witness.swift log): mac-shell/witness.log, how late
#                                     every press, release and key reached the far end of the event taps (`input-held`)
#   note <text…>                    a mark in the samples (jolts.py's header lists the marks it reads)
#   quiet [ms] [limit ms]           wait until no window has moved, come, gone or changed its place in the pile for that long
#                                     (1000, at most 8000). Sets QUIET to `quiet:<waited ms>` or `restless:<waited ms>`
#   chapter "<title>"               a heading in the output and in the report. While Arbor runs each chapter is a trace of its own
#                                     (docs/TRACES.md): mac-shell/traces/<date>-day-<n>.jsonl, with every step as a remark in it, so that
#                                     what macOS reported and the apps answered on the Mac can be replayed anywhere
#   label <window> <name>           what the report calls the window. Never its title
#   meet <name> <bundle id> [file…] app_open, and label what opened: sets P_<name>, W_<name> (its first standard window). Fails
#                                     when no standard window came
#   act <kind> <slug> "<what the person does>"        a step begins. The kinds are docs/VIABLE.md's: switch open-close dock-key drag
#                                     drag-where-macos-tiles view resize macos-own way-out quit-and-start display-change tile-click idle
#   want "<what should hold>" <command…>              inside a step: a finding of the script's own when it does not
#   must <command…>                 inside a step: what the person does. When it cannot be done (no free point of a title bar, no icon in the
#                                     Dock) the step is a finding of the script's own and is not judged: an act that was not performed passes nothing
#   acted [key=value…]              waits for quiet, compares Arbor's belief with the screen (audit), takes the picture
#                                     mac-shell/<nnn>-<slug>.jpg and ends the step. The keys are jolts.py's, and besides ids
#                                     `moves=` takes `docked`: whatever is docked before or after the step. `tiles=ok`, with everything=1 after Show
#                                     Everything: a tile may stand in for a window (jolts.py's tiles= and keyboard=). `audit=no` leaves the comparison out, for a step
#                                     in which macOS holds the windows where Arbor cannot know them to be. What the comparison
#                                     found after the step before as well is not said again
#   day_scratch                     apps_scratch, and the same documents under names with a canary word in them ($DAY_DOCUMENTS/$APPS_CANARY-oak.txt, -elm.txt,
#                                     -grove/, -page.html, -leaf.png): a document's name is its window's title, and day_report looks for the word in all
#                                     that the run brings back but the pictures (`told`)
#   idle <seconds>                  inside a step: nothing is done for that long. Meanwhile Arbor may use 1 % of a core and write 20 lines a minute (`busy`)
#   day_launch [NAME=value…]        Arbor as a person runs it: every regular app, shortcuts and menu bar item on. The same
#                                     $ARBOR_HOME every time, so that a second launch finds what the first one saved
#   day_gone                        after a step that quit Arbor: waits for it to end, forgets its process, and looks for what it left: a process, a
#                                     panel (`left-behind`)
#   docked_ids | floating_ids       the ids Arbor has docked | floating, separated by commas
#   arbor_window                    the id of Arbor's own standard window, if one is open: its welcome
#   click_window <window>           a real click on a free point of its title bar (fails when it is covered)
#   drag_window <window> x y [options]                a real drag by such a point
#   dock_click <bundle id>          a real click on the app's icon in the Dock
#   cmd_tab [n]                     ⌘ down, ⇥ n times (1), ⌘ up
#   window_menu <window>            real clicks: the Window menu of the app in front, then the window's line in it
#   arbor_menu <key…>               open Arbor's menu with a real click and choose with these keys, e.g. `arbor_menu up return`
#   main_window_of <pid>            the window of that app that has, or would have, the keyboard
#   bare_spot                       x y: a point of the wallpaper that no window covers (fails when there is none)
#   day_manifest <key> <json value> what mac-shell/run.json says about the run besides what every run says (docs/VIABLE.md, "Which runs count")
#   day_report                      stop the sampler, write mac-shell/day-report.md, print the findings, keep the pictures and
#                                     write the stories (mac-shell/<nnn>-<slug>.story.log) of the steps with a finding
source "$(dirname "${BASH_SOURCE[0]}")/lib-apps.sh"

DAY_SAMPLER="$ARBOR_ROOT/.build/mac-shell/sampler"
DAY_JOLTS="$ARBOR_ROOT/scripts/mac-shell/jolts.py"
DAY_SAMPLES="$ARBOR_OUT/samples.log"
DAY_SAMPLER_PID=""
DAY_WITNESS="$ARBOR_ROOT/.build/mac-shell/witness"
DAY_WITNESS_PID=""
DAY_STEP=0
DAY_TRACES=0
DAY_QUESTIONS=0
DAY_UNDONE=""
DAY_DOCUMENTS=""
# No word of any language, so that nothing else can bring it in.
APPS_CANARY=quokkadoo
DAY_SLUG=""
DAY_KIND=""
DAY_DOCKED_BEFORE=""
DAY_OFFENCES=""
# Arbor's own acts since it started.
DAY_SINCE_START=0
DAY_MANIFEST=""
DAY_AUDIT_BEFORE=""
DAY_FACE="ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0 ARBOR_NO_PROMPT=0"
QUIET=""

day_build() {
  local compiler second
  mkdir -p "$(dirname "$DAY_SAMPLER")"
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/sampler.swift" -o "$DAY_SAMPLER" \
    > "$ARBOR_OUT/build-sampler.log" 2>&1 &
  compiler=$!
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/witness.swift" -o "$DAY_WITNESS" \
    > "$ARBOR_OUT/build-witness.log" 2>&1 &
  second=$!
  apps_build
  if ! wait "$compiler"; then
    grep -A 6 "error:" "$ARBOR_OUT/build-sampler.log" | head -n 80
    die "scripts/mac-shell/sampler.swift did not compile"
  fi
  if ! wait "$second"; then
    grep -A 6 "error:" "$ARBOR_OUT/build-witness.log" | head -n 80
    die "scripts/mac-shell/witness.swift did not compile"
  fi
}

day_build_tools() {
  local started=$SECONDS tool jobs=""
  mkdir -p "$(dirname "$DAY_SAMPLER")"
  for tool in pointer apptool sampler witness; do
    swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/$tool.swift" -o "$ARBOR_ROOT/.build/mac-shell/$tool" \
      > "$ARBOR_OUT/build-$tool.log" 2>&1 &
    jobs="$jobs $tool:$!"
  done
  for tool in $jobs; do
    if ! wait "${tool#*:}"; then
      grep -A 6 "error:" "$ARBOR_OUT/build-${tool%:*}.log" | head -n 80
      die "scripts/mac-shell/${tool%:*}.swift did not compile"
    fi
  done
  ARBOR_DISPLAY_COUNT=$("$ARBOR_POINTER" displays | wc -l | tr -d ' ')
  echo "built the tools in $((SECONDS - started))s"
  arbor_make_room || exit 77
}

# MARK: The sampler

# Descriptors 5 and 6 are the script's ends of the two fifos. Opened in the order the sampler opens its ends in.
sampler_start() {
  local tiers=""
  [ -z "$DAY_SAMPLER_PID" ] || return 0
  if command -v taskpolicy > /dev/null; then tiers="taskpolicy -l 0 -t 0"; fi
  mkfifo "$APPS_TEMP/sampler-in" "$APPS_TEMP/sampler-out" || die "sampler_start: no fifos in $APPS_TEMP"
  # What the runner's agent starts counts as work in the background, whose timers macOS runs together with others': two samples in seven came 40 to
  # 70 ms late. taskpolicy asks for the tightest tiers, then becomes the sampler.
  # shellcheck disable=SC2086
  $tiers "$DAY_SAMPLER" "$DAY_SAMPLES" "$APPS_TEMP/sampler-in" "$APPS_TEMP/sampler-out" --hz "${DAY_HZ:-60}" \
    2>> "$ARBOR_OUT/sampler.log" 8>&- 9>&- &
  DAY_SAMPLER_PID=$!
  started "$DAY_SAMPLER_PID"
  exec 6> "$APPS_TEMP/sampler-in" 5< "$APPS_TEMP/sampler-out"
  "$DAY_WITNESS" log "$ARBOR_OUT/witness.log" 2>> "$ARBOR_OUT/sampler.log" 5<&- 6>&- 8>&- 9>&- &
  DAY_WITNESS_PID=$!
  started "$DAY_WITNESS_PID"
  echo "the sampler writes mac-shell/samples.log (pid $DAY_SAMPLER_PID), the witness mac-shell/witness.log (pid $DAY_WITNESS_PID)"
}

sampler_stop() {
  [ -n "$DAY_SAMPLER_PID" ] || return 0
  echo stop >&6
  exec 6>&- 5<&-
  apps_end "$DAY_SAMPLER_PID"
  DAY_SAMPLER_PID=""
  kill_started "$DAY_WITNESS_PID"
  DAY_WITNESS_PID=""
}

note() { [ -n "$DAY_SAMPLER_PID" ] && echo "mark $*" >&6; }

quiet() {
  local answer waited word
  QUIET=""
  [ -n "$DAY_SAMPLER_PID" ] || { sleep 1; return 0; }
  DAY_QUESTIONS=$((DAY_QUESTIONS + 1))
  echo "quiet ${1:-1000} ${2:-8000} q$DAY_QUESTIONS" >&6
  # Longer than the sampler takes at the most; it may have died. An answer to an earlier question, which came too late for it, is passed over.
  while read -r -t $(((${2:-8000} + 4000) / 1000)) answer waited word <&5; do
    [ "$word" = "q$DAY_QUESTIONS" ] || continue
    QUIET="$answer:$waited"
    [ "$answer" = quiet ]
    return
  done
  QUIET="restless:0"
  return 1
}

# MARK: Documents whose names must not be told

day_scratch() {
  apps_scratch
  DAY_DOCUMENTS="$APPS_SCRATCH/told"
  mkdir -p "$DAY_DOCUMENTS"
  cp "$APPS_SCRATCH/oak.txt" "$DAY_DOCUMENTS/$APPS_CANARY-oak.txt"
  cp "$APPS_SCRATCH/elm.txt" "$DAY_DOCUMENTS/$APPS_CANARY-elm.txt"
  cp "$APPS_SCRATCH/leaf.png" "$DAY_DOCUMENTS/$APPS_CANARY-leaf.png"
  cp -R "$APPS_SCRATCH/grove" "${DAY_DOCUMENTS:?}/$APPS_CANARY-grove"
  sed "s|<title>|<title>$APPS_CANARY |" "$APPS_SCRATCH/page.html" > "$DAY_DOCUMENTS/$APPS_CANARY-page.html"
}

# MARK: Steps

chapter() {
  step "$*"
  note "chapter $*"
  day_trace
}

# A new trace, from a moment when things are at rest. A trace ends by itself after ten minutes, and when Arbor pauses or quits.
day_trace() {
  arbor_answers || return 0
  "$ARBOR_BIN/arborctl" trace off > /dev/null 2>&1
  DAY_TRACES=$((DAY_TRACES + 1))
  "$ARBOR_BIN/arborctl" trace on "day-$DAY_TRACES" | sed "s|$ARBOR_HOME/||"
}

label() {
  note "label $1 $2"
  echo "  w$1 is $2"
}

meet() {
  local name=$1 index=1 id code
  shift
  app_open "$@"
  code=$?
  eval "P_$name=\$APP_PID W_$name=\$APP_WINDOW"
  for id in $APP_WINDOWS; do
    if [ "$index" -eq 1 ]; then label "$id" "$name"; else label "$id" "$name-$index"; fi
    index=$((index + 1))
  done
  [ "$code" -eq 0 ] && [ -n "$APP_WINDOW" ]
}

arbor_answers() { [ -n "$ARBOR_PID" ] && kill -0 "$ARBOR_PID" 2>/dev/null; }

# One question to Arbor for all three: sets DAY_DOCKED, DAY_FLOATING and DAY_TILES (<window>@x:y:w:h,…), to nothing while Arbor does not run.
day_ids() {
  DAY_DOCKED="" DAY_FLOATING="" DAY_TILES=""
  arbor_answers || return 0
  read -r DAY_DOCKED DAY_FLOATING DAY_TILES <<< "$("$ARBOR_BIN/arborctl" state 2>/dev/null | python3 -c '
import json, sys
try:
    state = json.load(sys.stdin)["state"]
    windows = [window for window in state["windows"] if window["managed"]]
except (ValueError, KeyError):
    sys.exit(0)
for docked in (True, False):
    print(",".join(str(window["id"]) for window in windows if window["docked"] == docked) or "-", end=" ")
print(",".join("%d@%s" % (window, ":".join(str(round(number)) for pair in tile["frame"] for number in pair))
               for display in state["displays"] for tile in display["tiles"] for window in tile["windows"]) or "-")')"
  DAY_DOCKED=${DAY_DOCKED#-} DAY_FLOATING=${DAY_FLOATING#-} DAY_TILES=${DAY_TILES#-}
}
docked_ids() { day_ids; echo "$DAY_DOCKED"; }
floating_ids() { day_ids; echo "$DAY_FLOATING"; }
arbor_window() { arbor_answers && app_windows "$ARBOR_PID" | cut -d ' ' -f 1; }

act() {
  DAY_STEP=$((DAY_STEP + 1))
  DAY_KIND=$1
  shift
  DAY_SLUG=$1
  DAY_UNDONE=""
  day_ids
  DAY_DOCKED_BEFORE=$DAY_DOCKED
  echo
  echo "-- $DAY_STEP $1: $2"
  mark "== $DAY_STEP $1"
  if arbor_answers; then "$ARBOR_BIN/arborctl" trace note "step $DAY_STEP $1" > /dev/null 2>&1; fi
  note "begin $DAY_STEP $1"
  note "text $DAY_STEP $2"
}

want() {
  check "$@" || note "finding $DAY_STEP - FAIL not so: $1"
}

# ps gives the time a process has had of the processors as [[dd-]hh:]mm:ss.cc.
day_cpu_seconds() {
  ps -o cputime= -p "$1" 2>/dev/null | awk '{ parts = split($1, unit, ":"); seconds = 0; for (i = 1; i <= parts; i++) seconds = seconds * 60 + unit[i]; printf "%.2f", seconds }'
}

idle() {
  local seconds=$1 cpu lines share written
  arbor_answers || { sleep "$seconds"; return 0; }
  cpu=$(day_cpu_seconds "$ARBOR_PID")
  lines=$(lines_of "$ARBOR_HOME/arbor.log")
  sleep "$seconds"
  share=$(echo "$(day_cpu_seconds "$ARBOR_PID") $cpu $seconds" | awk '{ printf "%.1f", ($1 - $2) * 100 / $3 }')
  written=$(( ($(lines_of "$ARBOR_HOME/arbor.log") - lines) * 60 / seconds ))
  echo "  with nothing to do Arbor used $share % of a core and wrote $written lines a minute"
  if [ "$(echo "$share" | awk '{ print ($1 > 1) }')" = 1 ]; then note "finding $DAY_STEP -:busy FAIL with nothing to do Arbor used $share % of a core"; fi
  if [ "$written" -gt 20 ]; then note "finding $DAY_STEP -:busy FAIL with nothing to do Arbor wrote $written lines of log a minute"; fi
}

must() {
  "$@" && return 0
  DAY_UNDONE="$DAY_UNDONE $1"
  return 1
}

acted() {
  local word wants="" findings line code audit=yes
  [ -z "${DAY_NO_AUDIT:-}" ] || audit=""
  quiet || echo "  ~ windows were still moving after ${QUIET#*:} ms"
  day_ids
  if [ -n "$DAY_UNDONE" ]; then
    echo "  ✘ the act was not performed:$DAY_UNDONE"
    note "finding $DAY_STEP - FAIL the act was not performed:$DAY_UNDONE could not be done"
    wants=" judge=no"
  fi
  for word in "$@"; do
    case "$word" in
      moves=docked | moves=docked,*) word="moves=$DAY_DOCKED_BEFORE,$DAY_DOCKED,${word#moves=docked}" ;;
      audit=no) audit=""; continue ;;
      tiles=ok) word="tiles=$DAY_TILES keyboard=$(apptool focused 2>/dev/null | cut -d ' ' -f 1)" ;;
      offence=*) DAY_OFFENCES="$DAY_OFFENCES ${word#offence=}:$DAY_SLUG" ;;
      # Nothing would be checked, and it would look like a pass.
      front= | comes= | drags=) note "finding $DAY_STEP - FAIL the script could not tell which window ${word%=} is about"; continue ;;
    esac
    wants="$wants $word"
  done
  if arbor_answers && [ -z "$audit" ]; then
    wants="$wants floating=$DAY_FLOATING docked=$DAY_DOCKED"
  elif arbor_answers; then
    findings=$(audit)
    code=$?
    if [ "$code" -eq 2 ]; then
      # Wrong, or only slow? Apps animate, and Arbor puts things back a moment later.
      sleep 1.5
      line=$(audit)
      [ $? -eq 2 ] || { note "finding $DAY_STEP - ODD took more than a second longer to agree with the screen: $(echo "$findings" | grep -m 1 FAIL | cut -c 6-)"; findings=$line; }
    fi
    while IFS= read -r line; do
      case $'\n'"$DAY_AUDIT_BEFORE"$'\n' in *$'\n'"$line"$'\n'*) continue ;; esac
      # A floating window's frame is its person's, so it may lie over docked ones.
      case "$line" in "ODD floating "*" overlap by "*) continue ;; esac
      case "$line" in
        FAIL*) echo "  ✘ ${line#FAIL }"; note "finding $DAY_STEP - FAIL ${line#FAIL }" ;;
        ODD*) echo "  ~ ${line#ODD }"; note "finding $DAY_STEP - ODD ${line#ODD }" ;;
      esac
    done <<< "$findings"
    DAY_AUDIT_BEFORE=$findings
    wants="$wants floating=$DAY_FLOATING docked=$DAY_DOCKED"
  elif [ -n "$ARBOR_PID" ]; then
    echo "  ✘ ARBOR DIED"
    note "finding $DAY_STEP -:crash FAIL Arbor's process ended, and nobody asked it to"
    tail -n 20 "$ARBOR_OUT/$(arbor_log_name arbor-stderr)" 2>/dev/null
    ARBOR_PID=""
  fi
  case "$DAY_KIND" in
    dock-key | view | resize | way-out | drag | tile-click)
      DAY_SINCE_START=$((DAY_SINCE_START + 1))
      [ "$DAY_SINCE_START" -ne 1 ] || wants="$wants first=1" ;;
  esac
  note "end $DAY_STEP act=$DAY_KIND settled=$QUIET$wants"
  echo "  ($QUIET ms)$wants"
  snap_now "$(printf '%03d-%s' "$DAY_STEP" "$DAY_SLUG")" > /dev/null
}

# MARK: Arbor, as a person runs it

day_launch() {
  # shellcheck disable=SC2086
  arbor_start_apps all $DAY_FACE "$@" || return 1
  note "arbor $ARBOR_PID"
  DAY_SINCE_START=0
  day_trace
}

day_gone() {
  local pid=$ARBOR_PID left
  [ -n "$pid" ] || return 0
  ended "$pid" 50 || return 1
  ARBOR_PID=""
  left=$(ps -A -o pid=,comm= | grep -F "$ARBOR_BIN/Arbor" | awk '{ printf "%s ", $1 }')
  [ -z "$left" ] || note "finding $DAY_STEP -:left-behind FAIL after Quit a process of Arbor's is still there: $left"
  left=$(pointer windows --pid "$pid" | wc -l | tr -d ' ')
  [ "$left" -eq 0 ] || note "finding $DAY_STEP -:left-behind FAIL after Quit $left windows of Arbor's are still there"
}

# MARK: What a person does

click_window() {
  local x y role
  read -r x y role <<< "$(apptool grab "$1" 2>/dev/null)"
  [ -n "${x:-}" ] || { echo "no free point of w$1's title bar shows"; return 1; }
  click "$x" "$y"
  # Off the title bar again: a pointer resting near the green button opens its menu, which swallows the next key.
  move "$x" "$((y + 120))"
}

# Not every point that looks free moves the window: a toolbar has controls Accessibility does not call controls. So the button stays down until the window is
# seen to have followed; a press that did not take hold of it is let go, and the drag was not performed.
drag_window() {
  local window=$1 to_x=$2 to_y=$3 x y role before hold=0.2 keep="" options=""
  shift 3
  while [ $# -gt 0 ]; do
    case "$1" in
      --hold) hold=$2; shift ;;
      --no-release) keep=yes ;;
      *) options="$options $1" ;;
    esac
    shift
  done
  read -r x y role <<< "$(apptool grab "$window" 2>/dev/null)"
  [ -n "${x:-}" ] || { echo "no free point of w$window's title bar shows"; return 1; }
  mark "drag w$window from $x,$y to $to_x,$to_y"
  before=$(real_frame_of "$window")
  # shellcheck disable=SC2086
  drag "$x" "$y" "$to_x" "$to_y" --no-release $options
  if [ "$(real_frame_of "$window")" = "$before" ]; then
    release
    echo "the press at $x,$y ($role) did not take hold of w$window"
    return 1
  fi
  [ -n "$keep" ] && return 0
  sleep "$hold"
  release
}

dock_click() {
  local x y
  read -r x y <<< "$(apptool dock "$1" 2>/dev/null)"
  [ -n "${x:-}" ] || { echo "the Dock shows no icon of $1"; return 1; }
  click "$x" "$y"
  # Away from the Dock, whose labels and magnification follow the pointer.
  move "$x" "$((y - 200))"
}

cmd_tab() {
  local times=${1:-1}
  key cmd+tab --down
  while [ "$times" -gt 1 ]; do
    sleep 0.15
    key cmd+tab --held
    times=$((times - 1))
  done
  sleep 0.15
  key cmd+tab --up
}

window_menu() {
  local pid x y
  pid=$(apptool front | cut -d ' ' -f 1)
  read -r x y <<< "$(apptool menu "$pid" Window 2>/dev/null)"
  [ -n "${x:-}" ] || { echo "the app in front has no Window menu"; return 1; }
  click "$x" "$y"
  sleep 0.5
  x=""
  read -r x y <<< "$(apptool menu-window "$1" 2>/dev/null)"
  if [ -z "${x:-}" ]; then
    echo "the Window menu has no line for w$1"
    key escape
    return 1
  fi
  click "$x" "$y"
}

arbor_menu_is_open() { has_overlay 101; }

arbor_menu() {
  local chord
  # shellcheck disable=SC2046
  rightclick $(status_item) || return 1
  eventually arbor_menu_is_open || { echo "Arbor's menu did not open"; return 1; }
  for chord in "$@"; do
    sleep 0.15
    key "$chord"
  done
}

# An app whose keyboard is with a sheet or a dialog names no window: then the first standard one it lists, which is the frontmost.
main_window_of() {
  local id
  id=$(apptool focused "$1" 2>/dev/null | cut -d ' ' -f 1)
  [ -n "$id" ] || id=$(app_windows "$1" | cut -d ' ' -f 1)
  echo "$id"
}

# From the middle outwards would find the gaps last; a person who misses a window clicks beside it, so any bare point will do.
bare_spot() {
  local x y w h px py
  read -r x y w h <<< "$(pointer displays | awk 'NR == 1 { print $2, $3 + 40, $4, $5 - 140 }')"
  py=$((y + 20))
  while [ "$py" -lt $((y + h)) ]; do
    px=$((x + 20))
    while [ "$px" -lt $((x + w - 20)) ]; do
      if ! apptool top-at "$px" "$py" > /dev/null 2>&1; then
        echo "$px $py"
        return 0
      fi
      px=$((px + 60))
    done
    py=$((py + 60))
  done
  return 1
}

# MARK: The report

day_manifest() { DAY_MANIFEST="$DAY_MANIFEST$1=$2"$'\n'; }

day_write_manifest() {
  day_manifest reduce_motion "$("$ARBOR_POINTER" reduce-motion)"
  DAY_MANIFEST=$DAY_MANIFEST DAY_OFFENCES=$DAY_OFFENCES python3 - "$ARBOR_OUT/run.json" "$(git -C "$ARBOR_ROOT" rev-parse HEAD)" "$(basename "$ARBOR_SCRIPT")" \
    "$(sw_vers -productVersion) ($(sw_vers -buildVersion))" "$SECONDS" << 'PYTHON'
import json, os, sys
path, commit, script, macos, seconds = sys.argv[1:]
run = {"gate": 1, "commit": commit, "run": os.environ.get("GITHUB_RUN_ID", ""), "attempt": int(os.environ.get("GITHUB_RUN_ATTEMPT", "1")),
       "script": script, "settings": "shipped", "build": "debug", "macos": macos, "seconds": int(seconds)}
for line in os.environ["DAY_MANIFEST"].splitlines():
    key, _, value = line.partition("=")
    run[key] = json.loads(value)
# An act's id is its slug and which act of that slug it is in its run (viable.py).
offences = []
for word in os.environ["DAY_OFFENCES"].split():
    detector, _, slug = word.partition(":")
    offences.append({"detector": detector, "id": f"{slug}#1"})
if offences:
    run["offences"] = offences
with open(path, "w", encoding="utf-8") as handle:
    json.dump(run, handle, indent=1)
    handle.write("\n")
PYTHON
}

day_report() {
  local number name code logs told
  watch_stop
  if arbor_answers; then "$ARBOR_BIN/arborctl" trace off > /dev/null 2>&1; fi
  # One home for the whole day, so one log, whatever the number of the session.
  if [ -f "$ARBOR_HOME/arbor.log" ]; then cp "$ARBOR_HOME/arbor.log" "$ARBOR_OUT/arbor.log"; fi
  if [ -d "$ARBOR_HOME/traces" ]; then cp -R "$ARBOR_HOME/traces" "$ARBOR_OUT/traces"; fi
  # While the sampler still takes marks: what only shows once everything has been gathered counts for the last step.
  if on_throwaway_mac && cp "$HOME"/Library/Logs/DiagnosticReports/Arbor*.ips "$ARBOR_OUT/" 2>/dev/null; then
    note "finding $DAY_STEP -:crash FAIL macOS wrote a crash report of Arbor's"
  fi
  # -I: not the pictures, which show the titles as the screen did.
  told=$(grep -rIl "$APPS_CANARY" "$ARBOR_OUT" 2>/dev/null | sed "s|$ARBOR_OUT/||" | tr '\n' ' ')
  [ -z "$told" ] || note "finding $DAY_STEP -:told FAIL a window's title is in what the run brings back: $told"
  sampler_stop
  logs=$(ls "$ARBOR_OUT/arbor.log" "$ARBOR_OUT/day-macos.log" 2>/dev/null | tr '\n' ' ')
  python3 "$DAY_JOLTS" report "$DAY_SAMPLES" --json "$ARBOR_OUT/day-findings.json" > "$ARBOR_OUT/day-report.md"
  code=$?
  # Only the samples know whether Arbor's stage was ever up.
  day_manifest stage_seen "$(python3 -c 'import json, sys; print(json.dumps(json.load(open(sys.argv[1]))["stage_seen"]))' "$ARBOR_OUT/day-findings.json" 2>/dev/null || echo null)"
  day_write_manifest
  step "the report (all of it: mac-shell/day-report.md)"
  sed -n '1,/^## Every step/p' "$ARBOR_OUT/day-report.md" | sed '$d'
  if [ -n "${DAY_SABOTAGE:-}" ]; then
    # Findings are what this run is after. What counts is whether they are the right ones.
    step "the sabotage"
    python3 "$DAY_JOLTS" sabotage "$DAY_SAMPLES" | tee "$ARBOR_OUT/sabotage.md"
    code=${PIPESTATUS[0]}
  fi
  # shellcheck disable=SC2086
  python3 "$DAY_JOLTS" stories "$DAY_SAMPLES" "$ARBOR_OUT" $logs > "$APPS_TEMP/failing"
  for name in "$ARBOR_OUT"/[0-9][0-9][0-9]-*.jpg; do
    [ -f "$name" ] || continue
    number=$(basename "$name" | cut -c 1-3 | sed 's/^0*//')
    if [ -z "${DAY_KEEP_PICTURES:-}" ] && ! grep -qx "$number" "$APPS_TEMP/failing"; then
      rm -f "$name" # never empty: the loop's own, and the line above found it to be a file
    fi
  done
  [ "$code" -eq 0 ] || ARBOR_FAILED=$((ARBOR_FAILED + 1))
  return "$code"
}

# A day that was cut short (the time limit, a step that ended the script) still tells what it saw. Then lib-apps.sh's clean-up, which
# takes the exit code from here.
day_last_words() {
  local code=$?
  trap '' TERM INT
  [ -n "$DAY_SAMPLER_PID" ] && day_report
  return "$code"
}
trap 'day_last_words; apps_exit' EXIT
