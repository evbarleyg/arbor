# Real apps for Mac shell scripts: lib.sh's sessions, with other people's windows in place of test windows.
# Source it instead of lib.sh (it sources that first); do not run it.
#
#   #!/bin/bash
#   source "$(dirname "$0")/lib-apps.sh"
#   apps_build
#   apps_scratch                                   # throwaway documents in $APPS_SCRATCH
#   app_open com.apple.TextEdit "$APPS_SCRATCH/oak.txt"
#   arbor_start_apps "$APP_PID"
#   ctl dock "$APP_WINDOW" left;  snap docked
#   audit "$APP_PID"                               # does the screen agree with what Arbor believes?
#   arbor_stop
#   app_quit "$APP_PID"
#
# compat.sh is the long example. Real apps resist: they have minimum and fixed sizes, round sizes to character
# cells, put toolbars where the title bar was, open sheets on first launch and reopen windows by themselves. So
# nothing here assumes that a step worked, every wait ends, and whatever ends the script, the apps it
# opened are quit.
#
# On your own Mac a script built on this runs only with ARBOR_APPS_HERE=1, which is yours to set and nobody else's. It opens real
# apps and moves your pointer. It opens only its own throwaway documents, quits only apps it started itself, and Arbor stays
# limited to the processes you name. But an app that was not running is still yours: launched, it may bring back the windows
# and unsaved documents of last time, which Arbor then arranges and app_quit answers with "Don't Save"; and the throwaway
# documents end up among its recent items and in its history. Whatever changes a setting of the
# system's or touches everything on the Mac (`arbor_start_apps all`, `display_mode`) happens only on one of GitHub's
# Macs (lib.sh's on_throwaway_mac), and so do pictures, which show the whole screen (or with ARBOR_SHOTS=1).
#
#   apps_build                      arbor_build, and compile apptool.swift (the view through Accessibility)
#   apps_scratch                    make $APPS_SCRATCH: oak.txt elm.txt grove/ copse/ page.html page2.html leaf.png bark.png
#                                     hello.applescript
#   apps_picture <path> <w> <h>     a PNG with a soft gradient
#   apptool <command…>              see apptool.swift: windows, grab, button, limits, tree, press, watch, …
#   bounded <seconds> <program…>    run a program (not a function), killed after that long
#   app_open <bundle id|name> [file…]   open it in the background and wait for a standard window. Sets APP_PID,
#                                     APP_WINDOWS (its standard windows, front first) and APP_WINDOW (the first)
#   app_running <bundle id|name>    whether it runs already: then it is somebody's, and not for a script to quit
#   app_windows <pid>               the ids of its standard windows
#   app_await_window <pid> "<known ids>" [seconds]    wait for a standard window that is not among them: NEW_WINDOW
#   app_dismiss <pid>               press the way out of first-run sheets and dialogs, if there are any
#   app_focus <window>              a real click on its title bar; fails unless its app is then in front
#   app_quit <pid>                  ask an app this script started to quit, answer "don't save", and after six seconds insist
#   companions_start [count]        well-behaved neighbours: test windows C1…, as a regular app (pid COMPANIONS_PID)
#   arbor_start_apps all|<pid…> [NAME=value…]         Arbor limited to those processes, or (throwaway Macs) as a person runs it
#   apps_watchdog <seconds>         end the script after that long, whatever it is stuck on
#   display_mode <w>x<h>…           switch the display to the first of these sizes it offers (throwaway Macs)
#   snap <name>                     like shot, as a JPEG a quarter of the size: mac-shell/<name>.jpg
#   audit [pid…]                    compare Arbor's state with the window server: FAIL, ODD and NOTE lines (compat.py)
#   brief                           the state in a few lines, without titles
#   gone <window> | in_view <window>                  Arbor no longer lists it | it has a slot in view and is not parked
#   slot_of <window> | real_of <window>               x y w h: where the layout puts it | where the window server has it
#   has_slot <window> "<x y w h>"   whether that is its slot now: `eventually has_slot $W "$before"`
#   not <command…>                  the opposite: `eventually not is minimized $W`
#   watch_start <file> [pid…] | watch_stop            write every Accessibility and workspace notification to mac-shell/<file>
#   mark <text…>                    a line of the script's own in that file
#
# A matrix of app × step (compat.sh):
#   begin <step>                    start a step for $APP; then any of
#   run <arborctl command…>           a command that should be accepted, timed
#   want "<what should hold>" <command…>              ✘ for the step when it does not
#   odd "<what was odd>"              "odd" for the step
#   finish [no-audit]               let things settle, audit, take the picture, write the cell; a step that is not ✔
#                                     prints what Arbor logged and macOS reported meanwhile
#   skip <step> "<why>"             the step does not apply
#   matrix                          print the matrix so far

# A drill through the apps takes longer than lib.sh gives a script on a person's Mac, and may not take longer than the workflow's
# twenty minutes give it on GitHub's; apps_watchdog is these scripts' own limit.
ARBOR_TIME_LIMIT=${ARBOR_TIME_LIMIT:-1100}
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
[ "${ARBOR_APPS_HERE:-}" = 1 ] || needs_throwaway_mac "open real apps, which bring back somebody's windows and unsaved documents, and quit them without saving"

ARBOR_APPTOOL="$ARBOR_ROOT/.build/mac-shell/apptool"
ARBOR_COMPAT_PY="$ARBOR_ROOT/scripts/mac-shell/compat.py"
APPS_PIDS=""
APPS_SCRATCH=""
scratch_dir apps APPS_TEMP
COMPANIONS_PID=""
WATCH_PID=""
WATCH_FILE=""
WATCHDOG_PID=""
APP=""
APP_PID=""
APP_WINDOW=""
APP_WINDOWS=""
NEW_WINDOW=""
CELLS="$ARBOR_OUT/cells.tsv"
STEP=""
STEP_INDEX=0
STEP_FAILS=""
STEP_ODDS=""
STEP_LOG_MARK=0
STEP_WATCH_MARK=0
AUDIT_PIDS=""
ARBOR_DEAD=""

apptool() { "$ARBOR_APPTOOL" "$@"; }

# macOS has no timeout(1).
bounded() { arbor_within "$@"; }

apps_build() {
  local compiler
  mkdir -p "$(dirname "$ARBOR_APPTOOL")"
  swiftc -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/apptool.swift" -o "$ARBOR_APPTOOL" \
    > "$ARBOR_OUT/build-apptool.log" 2>&1 &
  compiler=$!
  arbor_build
  if ! wait "$compiler"; then
    grep -A 6 "error:" "$ARBOR_OUT/build-apptool.log" | head -n 80
    die "scripts/mac-shell/apptool.swift did not compile"
  fi
}

# MARK: Throwaway content

apps_scratch() {
  local name
  [ -n "$APPS_SCRATCH" ] && return 0
  APPS_SCRATCH="$APPS_TEMP/scratch"
  mkdir -p "$APPS_SCRATCH/grove" "$APPS_SCRATCH/copse"
  for name in oak elm; do
    printf 'A throwaway document for the compatibility lab: %s.\n' "$name" > "$APPS_SCRATCH/$name.txt"
  done
  for name in ash beech cedar; do
    echo "$name" > "$APPS_SCRATCH/grove/$name.txt"
    echo "$name" > "$APPS_SCRATCH/copse/$name.txt"
  done
  for name in page page2; do
    printf '<!doctype html><meta charset="utf-8"><title>%s</title><body style="font: 20px system-ui; margin: 3em">%s</body>\n' \
      "$name" "A local page for the compatibility lab: $name." > "$APPS_SCRATCH/$name.html"
  done
  echo 'display dialog "hello"' > "$APPS_SCRATCH/hello.applescript"
  apps_picture "$APPS_SCRATCH/leaf.png" 480 320
  apps_picture "$APPS_SCRATCH/bark.png" 400 400
}

# apps_picture <path> <width> <height>: a PNG with a soft gradient, made from nothing
apps_picture() {
  python3 - "$@" << 'PYTHON'
import struct, sys, zlib
path, width, height = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
rows = bytearray()
for y in range(height):
    rows.append(0)
    for x in range(width):
        t = (x / width + y / height) / 2
        rows += bytes((int(38 + 40 * t), int(70 + 60 * (1 - t)), int(92 + 70 * t)))
def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
with open(path, "wb") as out:
    out.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
              + chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b""))
PYTHON
}

# MARK: Apps

apps_remember() {
  case " $APPS_PIDS " in *" $1 "*) ;; *) APPS_PIDS="$APPS_PIDS $1" ;; esac
}

apps_forget() {
  local pid kept=""
  for pid in $APPS_PIDS; do [ "$pid" = "$1" ] || kept="$kept $pid"; done
  APPS_PIDS=$kept
}

app_windows() { apptool windows "$1" 2>/dev/null | awk '$3 == "AXStandardWindow" { printf "%s ", $1 }'; }

app_running() { apptool pid "$1" > /dev/null 2>&1; }

app_open() {
  local app=$1 how=-a tries=0 lines code ours=yes said
  shift
  if app_running "$app"; then
    ours=""
    # On a person's Mac an app that runs already is theirs, with their windows, unless this script started it.
    if ! on_throwaway_mac; then
      case " $APPS_PIDS " in
        *" $(apptool pid "$app" 2>/dev/null) "*) ;;
        *) echo "$app is running already, with somebody's windows"; return 1 ;;
      esac
    fi
  fi
  case "$app" in *.*.*) how=-b ;; esac
  APP_PID=""
  APP_WINDOW=""
  APP_WINDOWS=""
  # A document's name is its window's title. A script that looks for titles in what a run brings back (lib-day.sh) must not put them there itself.
  said="$*"
  echo "> open -g $how $app ${said//${APPS_CANARY:-$'\001'}/…}"
  # -g: in the background, as the test windows open, so that what comes to the front is the script's doing.
  # safe anywhere: on a person's Mac only an app that was not running or that this script started gets here
  # APP_OPEN_LIMIT: a large app that has never run on a Mac is looked over by macOS first, and `open` waits for that.
  bounded "${APP_OPEN_LIMIT:-20}" open -g "$how" "$app" "$@" || { echo "open failed"; return 1; }
  until APP_PID=$(apptool pid "$app" 2>/dev/null); do
    [ "$tries" -ge 100 ] && { echo "$app did not start within 10 s"; return 1; }
    sleep 0.1
    tries=$((tries + 1))
  done
  # Opened again, an app this script started is still this script's.
  case " $APPS_PIDS " in *" $APP_PID "*) ours=yes ;; esac
  if [ -n "$ours" ] || on_throwaway_mac; then apps_remember "$APP_PID"; fi
  lines=$(apptool wait-window "$APP_PID" "${APP_WAIT:-15}")
  code=$?
  echo "pid $APP_PID lists (id role subrole x y w h flags):"
  echo "$lines" | sed 's/^/  /'
  APP_WINDOWS=$(echo "$lines" | awk '$3 == "AXStandardWindow" { printf "%s ", $1 }')
  APP_WINDOW=${APP_WINDOWS%% *}
  return "$code"
}

app_await_window() {
  local pid=$1 known=" $2 " tenths=$((${3:-8} * 10)) tries=0 id
  NEW_WINDOW=""
  while [ "$tries" -lt "$tenths" ]; do
    for id in $(app_windows "$pid"); do
      case "$known" in
        *" $id "*) ;;
        *) NEW_WINDOW=$id; return 0 ;;
      esac
    done
    sleep 0.1
    tries=$((tries + 1))
  done
  return 1
}

# Only when something is in the way: these words also stand on buttons of ordinary windows.
app_dismiss() {
  local pid=$1 round=0
  while [ "$round" -lt 3 ]; do
    apptool windows "$pid" 2>/dev/null | grep -Eq "sheets=|AXDialog|AXSystemDialog" || return 0
    [ "$round" -eq 0 ] && { echo "something is in the way:"; apptool tree "$pid" 5 | grep -E "AXWindow|AXSheet|AXButton" | head -n 30; }
    apptool press "$pid" "Continue" "Not Now" "Skip" "Get Started" "Later" "Don’t Allow" "Cancel" "OK" "Close" || return 1
    sleep 0.8
    round=$((round + 1))
  done
}

app_focus() {
  local x y role pid
  read -r x y role <<< "$(apptool grab "$1" 2>/dev/null)"
  if [ -z "${x:-}" ]; then
    # Covered, or all controls: what the Dock or ⌘Tab would do.
    apptool raise "$1"
    read -r x y role <<< "$(apptool grab "$1" 2>/dev/null)"
    [ -n "${x:-}" ] || return 1
  fi
  click "$x" "$y"
  # Off the title bar again: a pointer resting near the green button opens its menu, which swallows the next key.
  move "$x" "$((y + 120))"
  sleep 0.3
  pid=$(pointer windows | awk -v id="$1" '$1 == id { print $2 }')
  [ "$(apptool front | cut -d ' ' -f 1)" = "$pid" ]
}

app_quit() {
  local pid=$1
  [ -n "$pid" ] || return 0
  case " $APPS_PIDS " in
    *" $pid "*) ;;
    *) echo "pid $pid was running before this script: left alone"; return 0 ;;
  esac
  if kill -0 "$pid" 2>/dev/null; then
    apptool quit "$pid" > /dev/null 2>&1
    if ! arbor_await_exit "$pid" 30; then
      apptool press "$pid" "Delete" "Don’t Save" "Terminate" "Close" "Quit" "Discard Changes"
      if ! arbor_await_exit "$pid" 30; then
        echo "pid $pid would not quit; killing it"
        kill -KILL "$pid" 2>/dev/null
        arbor_await_exit "$pid" 20
      fi
    fi
  fi
  apps_forget "$pid"
}

# Sees a helper of the script's own out: three seconds to go by itself, then no choice. Only then `wait`, which would
# otherwise wait for as long as the helper lives.
apps_end() {
  arbor_await_exit "$1" 30 || kill -TERM "$1" 2>/dev/null
  arbor_await_exit "$1" 20 || kill -KILL "$1" 2>/dev/null
  arbor_await_exit "$1" 20 && wait "$1" 2>/dev/null
}

# MARK: Neighbours

# Test windows do what they are told, so what goes wrong in a layout they share with a real app is the app's doing
# (or Arbor's). As a regular app, because that is what Arbor arranges when it is not limited to a list of processes.
companions_start() {
  local count=${1:-2} hello="" tries=0 index=0 id
  [ -z "$COMPANIONS_PID" ] || return 0
  mkfifo "$APPS_TEMP/companions"
  "$ARBOR_BIN/ArborTestWindows" --count "$count" --regular \
    < "$APPS_TEMP/companions" > "$APPS_TEMP/hello" 2>> "$ARBOR_OUT/test-windows.log" &
  COMPANIONS_PID=$!
  started "$COMPANIONS_PID"
  exec 8> "$APPS_TEMP/companions"
  while [ -z "$hello" ] && [ "$tries" -lt 100 ]; do
    sleep 0.1
    hello=$(head -n 1 "$APPS_TEMP/hello" 2>/dev/null)
    tries=$((tries + 1))
  done
  for id in $(python3 -c 'import json, sys; print(*json.loads(sys.argv[1])["windows"])' "$hello"); do
    index=$((index + 1))
    eval "C$index=$id"
  done
  [ "$index" -eq "$count" ] || die "ArborTestWindows did not report its windows (got: $hello)"
  echo "companions: pid $COMPANIONS_PID, $count windows"
}

companions_stop() {
  [ -n "$COMPANIONS_PID" ] || return 0
  exec 8>&-
  apps_end "$COMPANIONS_PID"
  COMPANIONS_PID=""
  rm -f "$APPS_TEMP/companions" "$APPS_TEMP/hello"
}

# MARK: Sessions

arbor_start_apps() {
  local only="" extra="" argument limit deadline
  for argument in "$@"; do
    case "$argument" in
      all) only=all ;;
      [A-Za-z_]*=*) extra="$extra $argument" ;;
      *[!0-9]* | "") die "arbor_start_apps: expected all, a process id or NAME=value, got '$argument'" ;;
      *) [ "$only" = all ] || only="$only,$argument" ;;
    esac
  done
  [ -n "$only" ] || die "arbor_start_apps: name the processes, or all"
  [ -z "$ARBOR_PID" ] || die "arbor_start_apps: a session is running; call arbor_stop first"
  [ -x "$ARBOR_BIN/Arbor" ] && [ -x "$ARBOR_APPTOOL" ] || die "arbor_start_apps: call apps_build first"
  arbor_mac_is_free || exit 77
  : > "$ARBOR_LEDGER/input"
  if [ "$only" = all ]; then
    on_throwaway_mac || [ -n "${ARBOR_APPS_ALL:-}" ] \
      || die "arbor_start_apps all would arrange every window on this Mac; set ARBOR_APPS_ALL=1 if you mean it"
    limit="ARBOR_LIMIT=none"
  else
    limit="ARBOR_ONLY_PIDS=${only#,}"
  fi
  ARBOR_SESSION=$((ARBOR_SESSION + 1))
  # No watchdog: a script that kills Arbor starts the next one itself.
  # shellcheck disable=SC2086
  # safe anywhere: $limit is ARBOR_ONLY_PIDS=<the processes named>, or, asked for by name just above, no limit
  env "$limit" ARBOR_NO_PROMPT=1 ARBOR_DEBUG=1 ARBOR_NO_HOTKEYS=1 ARBOR_NO_STATUS_ITEM=1 ARBOR_NO_WATCHDOG=1 $extra \
    "$ARBOR_BIN/Arbor" > "$ARBOR_OUT/$(arbor_log_name arbor-stderr)" 2>&1 5<&- 6>&- 8>&- 9>&- &
  ARBOR_PID=$!
  started "$ARBOR_PID"
  deadline=$((SECONDS + 20))
  while [ "$SECONDS" -lt "$deadline" ]; do
    "$ARBOR_BIN/arborctl" state 2>/dev/null | python3 "$ARBOR_STATE_PY" ready 0 2>/dev/null
    case $? in
      0)
        echo "session $ARBOR_SESSION: Arbor pid $ARBOR_PID, $limit: $("$ARBOR_BIN/arborctl" status)"
        arbor_trace_next "session $ARBOR_SESSION begins"
        return 0 ;;
      3) die "Arbor has no Accessibility permission here, so it cannot move windows" ;;
    esac
    kill -0 "$ARBOR_PID" 2>/dev/null || break
    sleep 0.2
  done
  echo "Arbor did not get going; its last status: $("$ARBOR_BIN/arborctl" status 2>&1)"
  tail -n 30 "$ARBOR_HOME/arbor.log" "$ARBOR_OUT/$(arbor_log_name arbor-stderr)" 2>/dev/null
  return 1
}

# The runners' display starts at 1024×768, smaller than any Mac's; real apps' minimum sizes leave no room on it.
display_mode() {
  local size
  arbor_may "switch the display to another size" || return 0
  for size in "$@"; do
    if apptool set-mode "${size%x*}" "${size#*x}" 2>/dev/null; then
      sleep 2
      echo "display: $(pointer displays)"
      return 0
    fi
  done
  echo "display: none of $* is on offer; still $(pointer displays)"
  return 1
}

# Ends the script after so many seconds, whatever it is stuck on.
apps_watchdog() {
  local script=$$
  ( sleep "$1"; echo "::error title=mac-shell::still running after $1 s: stopped"; kill -TERM "$script" ) 8>&- 9>&- &
  WATCHDOG_PID=$!
}

# Whatever ends the script: the watcher, the apps and the neighbours go, then lib.sh's own clean-up.
apps_exit() {
  local code=$? pid
  trap - EXIT
  # Nothing may cut the clean-up short: in bash 3.2 a `wait` here runs the trap of the signal that ended the script again.
  trap '' TERM INT
  [ -n "$WATCHDOG_PID" ] && kill -TERM "$WATCHDOG_PID" 2>/dev/null
  watch_stop
  arbor_stop
  for pid in $APPS_PIDS; do app_quit "$pid"; done
  companions_stop
  scratch_remove "$APPS_TEMP"
  (exit "$code")
  arbor_exit
}
trap apps_exit EXIT

# MARK: Looking

# JPEG: a drill takes hundreds of pictures, and they travel through Git.
snap() {
  sleep "${ARBOR_SETTLE:-0.7}"
  snap_now "$1"
}

snap_now() {
  local path="$ARBOR_OUT/$1.jpg" width
  arbor_may_shoot "$1" > /dev/null || return 0
  if ! screencapture -x -C -t jpg "$path" 2>> "$ARBOR_OUT/screencapture.log" || [ ! -s "$path" ]; then
    echo "snap $1: screencapture failed ($(tail -n 1 "$ARBOR_OUT/screencapture.log"))"
    return 1
  fi
  width=$(sips -g pixelWidth "$path" 2>/dev/null | awk '/pixelWidth/ { print $2 }')
  [ "${width:-0}" -gt 1440 ] && sips --resampleWidth 1440 "$path" > /dev/null 2>&1
  echo "snap: mac-shell/$1.jpg"
}

audit() {
  pointer windows > "$APPS_TEMP/server.txt"
  # shellcheck disable=SC2086
  "$ARBOR_BIN/arborctl" state 2>/dev/null | python3 "$ARBOR_COMPAT_PY" audit "$APPS_TEMP/server.txt" "$@"
}

brief() { "$ARBOR_BIN/arborctl" state | python3 "$ARBOR_COMPAT_PY" brief; }

not() { ! "$@"; }
gone() { ! arbor_ask frame "$1" > /dev/null 2>&1; }
in_view() { arbor_ask slot "$1" > /dev/null 2>&1 && ! is parked "$1"; }
slot_of() { arbor_ask slot "$1"; }
has_slot() { [ "$(arbor_ask slot "$1" 2>/dev/null)" = "$2" ]; }
# real_frame_of in whole points, for shell arithmetic: on a Retina screen the window server deals in halves.
real_of() { real_frame_of "$1" | awk '{ for (i = 1; i <= NF; i++) printf "%d ", $i + 0.5 }'; }

# MARK: What macOS reports

# Stamped like arbor.log, so that the two files sort into one story.
stamp() {
  perl -MTime::HiRes=time -MPOSIX=strftime \
    -e '$t = time; printf "%s.%03dZ", strftime("%Y-%m-%dT%H:%M:%S", gmtime($t)), ($t - int($t)) * 1000'
}

watch_start() {
  watch_stop
  WATCH_FILE="$ARBOR_OUT/$1"
  shift
  "$ARBOR_APPTOOL" watch "$@" >> "$WATCH_FILE" 2>&1 5<&- 6>&- 8>&- 9>&- &
  WATCH_PID=$!
}

watch_stop() {
  [ -n "$WATCH_PID" ] || return 0
  kill -TERM "$WATCH_PID" 2>/dev/null
  apps_end "$WATCH_PID"
  WATCH_PID=""
}

mark() { [ -n "$WATCH_FILE" ] && echo "$(stamp) SCRIPT $*" >> "$WATCH_FILE"; }

lines_of() { if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi; }

# What Arbor logged and macOS reported since the step began, in order of time, without the date.
step_story() {
  {
    [ -f "$ARBOR_HOME/arbor.log" ] && tail -n "+$((STEP_LOG_MARK + 1))" "$ARBOR_HOME/arbor.log"
    [ -n "$WATCH_FILE" ] && [ -f "$WATCH_FILE" ] && tail -n "+$((STEP_WATCH_MARK + 1))" "$WATCH_FILE"
  } | sort -s -k 1,1 | cut -c 12- | head -n "${1:-45}" | sed 's/^/    /'
}

# MARK: The matrix

begin() {
  STEP=$1
  STEP_INDEX=$((STEP_INDEX + 1))
  STEP_FAILS=""
  STEP_ODDS=""
  STEP_LOG_MARK=$(lines_of "$ARBOR_HOME/arbor.log")
  STEP_WATCH_MARK=$(lines_of "$WATCH_FILE")
  step "$APP: $STEP"
  mark "== $APP: $STEP"
}

# Once Arbor has died nothing more can hold, and waiting three seconds for each thing would take minutes.
want() {
  if [ -n "$ARBOR_DEAD" ]; then
    check "$1" false
  else
    check "$@"
  fi || STEP_FAILS="$STEP_FAILS; not so: $1"
}

odd() {
  echo "  ~ $*"
  STEP_ODDS="$STEP_ODDS; $*"
}

run() {
  local code elapsed
  echo "> $*"
  mark "> $*"
  if [ -n "$ARBOR_DEAD" ]; then
    STEP_FAILS="$STEP_FAILS; Arbor is gone: $*"
    return 1
  fi
  ARBOR_TIMING="$APPS_TEMP/timing" perl -MTime::HiRes=time -e \
    '$t = time; $c = system(@ARGV) >> 8; open(F, ">", $ENV{ARBOR_TIMING}); printf F "%d", (time - $t) * 1000; exit $c' \
    "$ARBOR_BIN/arborctl" "$@"
  code=$?
  elapsed=$(cat "$APPS_TEMP/timing" 2>/dev/null || echo 0)
  [ "$code" -eq 0 ] || STEP_FAILS="$STEP_FAILS; Arbor refused: $*"
  [ "$elapsed" -le 400 ] || odd "$1 took $elapsed ms"
  return "$code"
}

cell() {
  printf '%s\t%s\t%s\t%s\t%s\n' "$APP" "$1" "$2" "$3" "$4" >> "$CELLS"
}

finish() {
  local findings="" line verdict=ok picture note code
  picture=$(printf '%s-%02d-%s' "$APP" "$STEP_INDEX" "$STEP")
  sleep "${ARBOR_SETTLE:-0.7}"
  if [ "${1:-}" != no-audit ]; then
    # shellcheck disable=SC2086
    findings=$(audit $AUDIT_PIDS)
    code=$?
    if [ "$code" -eq 2 ]; then
      # Wrong, or only slow? Apps animate, and Arbor puts things back a quarter of a second later.
      sleep 1.5
      # shellcheck disable=SC2086
      line=$(audit $AUDIT_PIDS)
      if [ $? -ne 2 ]; then
        odd "took more than a second to settle: $(echo "$findings" | grep -m 1 FAIL | cut -c 6-)"
        findings=$line
      fi
    fi
    while IFS= read -r line; do
      case "$line" in
        FAIL*) echo "  ✘ ${line#FAIL }"; STEP_FAILS="$STEP_FAILS; ${line#FAIL }" ;;
        ODD*) odd "${line#ODD }" ;;
        NOTE*) echo "  · ${line#NOTE }" ;;
      esac
    done <<< "$findings"
  fi
  snap_now "$picture"
  if [ -n "$ARBOR_PID" ] && [ -z "$ARBOR_DEAD" ] && [ "$STEP" != quit-arbor ] && ! kill -0 "$ARBOR_PID" 2>/dev/null; then
    ARBOR_DEAD=yes
    STEP_FAILS="$STEP_FAILS; ARBOR DIED"
    tail -n 20 "$ARBOR_OUT/$(arbor_log_name arbor-stderr)" 2>/dev/null
  fi
  [ -n "$STEP_ODDS" ] && verdict=odd
  [ -n "$STEP_FAILS" ] && verdict=fail
  note="${STEP_FAILS#; }"
  [ -n "$STEP_FAILS" ] && [ -n "$STEP_ODDS" ] && note="$note; "
  note="$note${STEP_ODDS#; }"
  cell "$STEP" "$verdict" "$picture.jpg" "$note"
  if [ "$verdict" != ok ]; then
    [ -n "$ARBOR_PID" ] && brief | sed 's/^/    /'
    step_story
  fi
  STEP=""
}

skip() {
  echo
  echo "== $APP: $1: skipped, $2"
  cell "$1" na "" "$2"
}

matrix() { python3 "$ARBOR_COMPAT_PY" matrix "$CELLS"; }
