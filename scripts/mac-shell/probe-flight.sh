#!/bin/bash
# What can be known of a window that is on its way to the Dock, and which call fetches it back?
#
#   scripts/mac-shell/run.sh --no-preflight "a probe of macOS itself: no Arbor runs" scripts/mac-shell/probe-flight.sh
#
# Seen on a hosted Mac: the view is held, the window that is shown is minimized, and it comes straight back out of the Dock. In the trace its app named its next
# window half a second before it said "miniaturized", with a request of Arbor's for the keyboard in between. Was that macOS's way, or Arbor's doing? What this found
# is in collab/evidence/the-flight-to-the-dock.txt and collab/reality.json: Arbor's doing. The next window is named when the flight is over, and the raise fetches.
# Nothing here is a check and no Arbor runs: the output is the point (flight.txt). It answers, for test windows and for TextEdit, for ⌘M, the
# yellow button and Accessibility's AXMinimized, with Reduce Motion on and off:
#   1. When does the app name its next window, and when does it say "miniaturized"?                       (modes poll and sparse, lines "app")
#   2. What does the window server say of the window meanwhile?                                           (lines "server")
#   3. What does a read of AXMinimized answer during the flight, and how long does the answer take?        (modes poll and read)
#   4. Which of AXMain and AXRaise fetches the window back?                                                (modes main, raise, both)
#      And what do they do to a window that is at rest in the Dock?                                        (modes rest-main, rest-raise)
#   5. Does "read AXMinimized first, and leave a minimized window alone" keep it in the Dock?              (modes guarded, late)
source "$(dirname "$0")/lib-apps.sh"
needs_throwaway_mac "open TextEdit, minimize windows and switch Reduce Motion"

apps_build
FLIGHT="$ARBOR_ROOT/.build/mac-shell/flight"
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/flight.swift" -o "$FLIGHT" > "$ARBOR_OUT/build-flight.log" 2>&1 || {
  cat "$ARBOR_OUT/build-flight.log"
  die "scripts/mac-shell/flight.swift did not compile"
}
NOTES="$ARBOR_OUT/flight.txt"
say() { echo "$*" | tee -a "$NOTES"; }

# round <name> <pid> <window> <way> <mode>
round() {
  local name=$1 pid=$2 window=$3 way=$4 mode=$5 point watcher
  say ""
  say "--- $name, $way, $mode"
  app_focus "$window" > /dev/null 2>&1 || say "  (the window could not be given the keyboard by a click)"
  sleep 0.4
  point=$(apptool button "$window" minimize 2> /dev/null)
  # The pointer is there before the watch begins, so that only the press falls into it.
  # shellcheck disable=SC2086
  [ "$way" = button ] && [ -n "$point" ] && move $point > /dev/null
  "$FLIGHT" "$pid" "$window" 2.6 "$mode" >> "$NOTES" 2>&1 &
  watcher=$!
  started "$watcher"
  sleep 0.5
  case "$way" in
    key) key cmd+m > /dev/null ;;
    # shellcheck disable=SC2086
    button) click $point > /dev/null ;;
    ax) apptool minimize "$window" > /dev/null ;;
  esac
  ended "$watcher" 60
  say "  afterwards: $(apptool describe "$window" 2> /dev/null | cut -d ' ' -f 1,4-)"
  apptool unminimize "$window" > /dev/null 2>&1
  sleep 1.3
}

all_rounds() {
  local name=$1 pid=$2 window=$3 way mode
  for mode in poll sparse read both guarded late main raise rest-main rest-raise; do round "$name" "$pid" "$window" key "$mode"; done
  for way in button ax; do
    for mode in poll both guarded; do round "$name" "$pid" "$window" "$way" "$mode"; done
  done
}

say "# probe-flight.sh $(date -u +%Y-%m-%dT%H:%MZ) on macOS $(sw_vers -productVersion), commit $(git rev-parse --short HEAD)"
apps_watchdog 1000
apps_scratch
companions_start 3
app_open com.apple.TextEdit "$APPS_SCRATCH/oak.txt" "$APPS_SCRATCH/elm.txt" || say "TextEdit did not open"
TEXT_PID=$APP_PID
TEXT_WINDOW=$APP_WINDOW
app_dismiss "$TEXT_PID"

for motion in on off; do
  step "Reduce Motion $motion"
  say ""
  say "=== $(macos_reduce_motion "$motion" | tail -n 1)"
  sleep 1
  all_rounds "test windows" "$COMPANIONS_PID" "$C1"
  [ -n "$TEXT_WINDOW" ] && all_rounds TextEdit "$TEXT_PID" "$TEXT_WINDOW"
done
macos_reduce_motion on > /dev/null

app_quit "$TEXT_PID"
companions_stop
echo "read mac-shell/flight.txt"
