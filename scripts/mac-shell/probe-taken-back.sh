#!/bin/bash
# A request for the keyboard that is taken back at once: does it come true all the same?
#
#   scripts/mac-shell/run.sh --no-preflight "a probe of macOS itself: no Arbor runs" scripts/mac-shell/probe-taken-back.sh
#
# ⌃⌥→ and ⌃⌥← in one roll of the fingers, between two framed neighbours of different apps: by reading, the view goes to B, back to A, and a third time to B when B's
# late activation lands, because the second request, for a window of the app that is still in front, activates nobody and so recalls nothing. Nobody has seen
# it. Nothing here is a check and no Arbor runs: the output is the point (taken-back.txt). A is a test window, B a window of TextEdit; then the other way round.
#   1. How long does an activation take, and in which order do the reports come?                                            (mode there)
#   2. Taken back at once, or 20, 60 or 150 ms later, as Arbor's layer does it: who has the keyboard in the end? What is reported? (modes back…)
#   3. Does activating the app that is still in front recall the first activation?                                          (modes recall…)
source "$(dirname "$0")/lib-apps.sh"
needs_throwaway_mac "open TextEdit and move the keyboard between apps"

apps_build
TAKEBACK="$ARBOR_ROOT/.build/mac-shell/takeback"
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/takeback.swift" -o "$TAKEBACK" > "$ARBOR_OUT/build-takeback.log" 2>&1 || {
  cat "$ARBOR_OUT/build-takeback.log"
  die "scripts/mac-shell/takeback.swift did not compile"
}
NOTES="$ARBOR_OUT/taken-back.txt"
say() { echo "$*" | tee -a "$NOTES"; }

# round <what A is> <pid A> <window A> <pid B> <window B> <mode>
round() {
  say ""
  say "--- A is $1, $6"
  app_focus "$3" > /dev/null 2>&1 || say "  (A could not be given the keyboard by a click)"
  sleep 0.6
  bounded 10 "$TAKEBACK" "$2" "$3" "$4" "$5" "$6" >> "$NOTES" 2>&1
  sleep 0.4
}

say "# probe-taken-back.sh $(date -u +%H:%MZ) on macOS $(sw_vers -productVersion), commit $(git rev-parse --short HEAD)"
apps_watchdog 600
apps_scratch
companions_start 2
app_open com.apple.TextEdit "$APPS_SCRATCH/oak.txt" || die "TextEdit did not open"
TEXT_PID=$APP_PID
TEXT_WINDOW=$APP_WINDOW
app_dismiss "$TEXT_PID"
# Side by side, so that a click reaches either.
apptool set-frame "$C1" 40 80 440 400 > /dev/null
apptool set-frame "$C2" 40 500 440 200 > /dev/null
apptool set-frame "$TEXT_WINDOW" 520 80 460 500 > /dev/null

for turn in 1 2 3; do
  step "turn $turn"
  for mode in there back back-20 back-60 back-150 recall recall-20 recall-60; do
    round "a test window" "$COMPANIONS_PID" "$C1" "$TEXT_PID" "$TEXT_WINDOW" "$mode"
    round "TextEdit's" "$TEXT_PID" "$TEXT_WINDOW" "$COMPANIONS_PID" "$C1" "$mode"
  done
done

# One more question about the flight to the Dock (probe-flight.sh), which costs ten seconds here: does the call that minimizes a window, and the one that brings it back,
# return at once or when the flight is over? Arbor makes both on its main thread.
step "the calls that minimize and restore"
FLIGHT="$ARBOR_ROOT/.build/mac-shell/flight"
if swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/flight.swift" -o "$FLIGHT" > "$ARBOR_OUT/build-flight.log" 2>&1; then
  for turn in 1 2; do
    say ""
    say "--- a test window, the tool minimizes and restores it itself"
    app_focus "$C1" > /dev/null 2>&1
    bounded 10 "$FLIGHT" "$COMPANIONS_PID" "$C1" 3.6 self 2>&1 | grep -v " server " >> "$NOTES"
    say ""
    say "--- TextEdit's window, the same"
    app_focus "$TEXT_WINDOW" > /dev/null 2>&1
    bounded 10 "$FLIGHT" "$TEXT_PID" "$TEXT_WINDOW" 3.6 self 2>&1 | grep -v " server " >> "$NOTES"
  done
else
  cat "$ARBOR_OUT/build-flight.log"
fi

app_quit "$TEXT_PID"
companions_stop
echo "read mac-shell/taken-back.txt"
