#!/bin/bash
# The key that fills the screen, on the day's apps, never docked (collab/QUESTIONS.md, Q29; board 0.16). For each of TextEdit, Safari,
# Terminal and System Settings: its frame before, filled and after, as the window server has them, and every other window's.
# What only real apps can tell: whether each takes the view's frame in one go, what a terminal's whole lines and an app that will
# not grow make of it, whether their late reports end the fill, and whether each gets exactly its own frame back.
# And how each got there, which a look at a window at rest does not tell: the frames Arbor asked it to take, counted in Arbor's own trace.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-fill.sh scripts/mac-shell/check-fill-apps.sh
source "$(dirname "$0")/lib-apps.sh"

is_at() { arbor_close "$(real_frame_of "$1")" "$2"; }
# others_are_still <id>: every window but that one is where it was before Arbor touched anything
others_are_still() {
  local index=0 code=0
  while [ "$index" -lt "${#WINDOWS[@]}" ]; do
    if [ "${WINDOWS[$index]}" != "$1" ] && ! is_at "${WINDOWS[$index]}" "${BEFORE[$index]}"; then
      echo "${NAMES[$index]} was at ${BEFORE[$index]} and is at $(real_frame_of "${WINDOWS[$index]}")"
      code=1
    fi
    index=$((index + 1))
  done
  return $code
}

# calls_of <id> <command>: "2 calls in 73 ms: …": what Arbor asked of that window since the command last came (calls.py)
calls_of() {
  arbor_trace_note "at rest"
  python3 "$ARBOR_ROOT/scripts/mac-shell/calls.py" "$ARBOR_HOME/traces" "$1" "$2"
}
in_one_call() { [ "${1%% *}" = 1 ] || { echo "$1"; return 1; }; }

apps_build
apps_scratch
apps_watchdog 500
NAMES=()
WINDOWS=()
PIDS=()
meet() {
  local name=$1
  shift
  if app_open "$@"; then
    app_dismiss "$APP_PID"
    NAMES+=("$name")
    WINDOWS+=("$APP_WINDOW")
    PIDS+=("$APP_PID")
  else
    echo "$name did not open: left out"
  fi
}
meet TextEdit com.apple.TextEdit "$APPS_SCRATCH/oak.txt"
meet Safari com.apple.Safari "$APPS_SCRATCH/page.html"
# On a hosted Mac's small display Safari opens as large as the display. Arbor leaves such a window as it is ("fills the screen already"),
# and it covers the others, which a click then cannot reach: both seen on the first run. So it is made smaller, before Arbor starts.
[ "${NAMES[${#NAMES[@]}-1]}" != Safari ] || apptool set-frame "$APP_WINDOW" 120 70 760 520 > /dev/null
meet Terminal com.apple.Terminal
APP_WAIT=25 meet Settings com.apple.systempreferences
[ "${#WINDOWS[@]}" -ge 2 ] || die "fewer than two apps opened"

arbor_start_apps "${PIDS[@]}" ARBOR_NO_HOTKEYS=0
sleep 1
BEFORE=()
for window in "${WINDOWS[@]}"; do BEFORE+=("$(real_frame_of "$window")"); done
snap 00-as-found

FIRST=()
index=0
while [ "$index" -lt "${#WINDOWS[@]}" ]; do
  name=${NAMES[$index]} window=${WINDOWS[$index]} own=${BEFORE[$index]}
  claim "$name, never docked: the key fills the screen with it, keeps it there, and gives its frame back"
  # What the Dock or ⌘Tab would do: the Accessibility raise alone does not lift a window over another app's.
  apptool activate "${PIDS[$index]}"
  sleep 0.5
  check "a real click gives it the keyboard" app_focus "$window"
  check "the real key runs the command" pressed ctrl+opt+return zoom
  sleep 1
  filled=$(real_frame_of "$window")
  echo "FRAMES $name before: $own filled: $filled"
  FIRST+=("$(calls_of "$window" zoom)")
  echo "CALLS $name to fill the view, the first time: ${FIRST[$index]}"
  check "Arbor knows that it fills" is filled "$window"
  check "it still floats" is floating "$window"
  if [ "$name" = Settings ]; then
    echo "NOTE $name is expected not to grow as far as the view: $(fills "$window" 2>&1 || true)"
  elif [ "$name" = Terminal ]; then
    echo "NOTE $name holds whole lines: $(fills "$window" 2>&1 || true)"
  else
    check "it fills the view" fills "$window"
    check "and went there in one call" in_one_call "${FIRST[$index]}"
  fi
  check "nothing else has moved" others_are_still "$window"
  snap "$((index + 1))1-$name-filled"
  sleep 3
  check "three seconds on it is where the fill left it" is_at "$window" "$filled"
  check "and Arbor still knows that it fills" is filled "$window"
  check "the real key runs the command" pressed ctrl+opt+return zoom
  check "it is exactly where and as large as it was" eventually is_at "$window" "$own"
  echo "FRAMES $name after: $(real_frame_of "$window")"
  back=$(calls_of "$window" zoom)
  echo "CALLS $name back: $back"
  check "and went there in one call" in_one_call "$back"
  check "Arbor knows that it no longer fills" not is filled "$window"
  check "nothing else has moved" others_are_still "$window"
  index=$((index + 1))
done
snap 50-all-back

claim "the first time, too, a window that does not take the view's size goes to its place in one call"
known "board 1.120: how large a window goes is learned by offering it the whole view in the view's corner; after the cut"
index=0
while [ "$index" -lt "${#WINDOWS[@]}" ]; do
  case ${NAMES[$index]} in
    Settings | Terminal) check "${NAMES[$index]}" in_one_call "${FIRST[$index]}" ;;
  esac
  index=$((index + 1))
done

claim "filled at Quit, each has its own frame back"
for window in "${WINDOWS[@]}"; do ctl zoom "$window"; done
sleep 1
index=0
while [ "$index" -lt "${#WINDOWS[@]}" ]; do
  name=${NAMES[$index]} window=${WINDOWS[$index]}
  echo "FRAMES $name filled by name: $(real_frame_of "$window")"
  again=$(calls_of "$window" "zoom $window")
  echo "CALLS $name to fill the view, the second time: $again"
  # What is known of a window by now is used: no way round by the corner. A terminal is talked down to whole lines where it lies.
  if [ "$name" = Terminal ]; then
    echo "NOTE $name holds whole lines"
  else
    check "$name went there in one call" in_one_call "$again"
  fi
  index=$((index + 1))
done
snap 60-all-filled
arbor_stop
others_are_still 0 && echo "every window is where it was found"
check "every window is where it was found" others_are_still 0
snap 61-after-quit
