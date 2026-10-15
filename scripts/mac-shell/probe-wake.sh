#!/bin/bash
# After a real sleep and a real wake, are Arbor's keys still Arbor's? A probe, alone on its Mac (collab/BOARD.md, 0.1; IDEAS I16).
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-wake.sh
#
# "It was let go of meanwhile (a pause, an app with shortcuts off, secure input, a wake)" is one of the guesses for a key of Arbor's that reached the app in front. probe-whose-key.sh tried all but
# the wake: it put the display to sleep, not the Mac. This puts the Mac to sleep, with a wake asked for forty seconds on.
#
# NEVER TOGETHER WITH ANOTHER SCRIPT: a hosted Mac that is put to sleep may not come back, and takes the run's output with it. So there is nothing here but the question: the keys
# before, the sleep, the keys after. Whether the Mac slept at all is asked of macOS and printed: a Mac that refused proves nothing.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "put the Mac to sleep"
source "$(dirname "$0")/lib-ears.sh"

KEYS="ctrl+opt+a ctrl+opt+left ctrl+opt+right ctrl+opt+return ctrl+opt+space ctrl+opt+[ ctrl+opt+z ctrl+opt+f ctrl+opt+g"
echo "$KEYS" | tr ' ' '\n' > "$CHORDS"
ears_open
slept() { echo "macOS's own record: last sleep $(sysctl -n kern.sleeptime), last wake $(sysctl -n kern.waketime)"; }

step "0  no Arbor: the control"
# shellcheck disable=SC2086
press_all control $KEYS

step "1  Arbor running, before the sleep"
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
ctl arrange
what_arbor_says
# shellcheck disable=SC2086
press_all before-the-sleep $KEYS

step "2  the sleep"
slept
pmset -g | grep -E " sleep |hibernatemode|standby|SleepDisabled" | sed 's/^/  /'
pmset -g assertions | grep -E "PreventUserIdleSystemSleep|PreventSystemSleep" | head -n 4 | sed 's/^/  /'
before=$(date +%s)
sudo pmset relative wake 40 || echo "NOTE: no wake could be asked for"
echo "$(wall) going to sleep"
sudo pmset sleepnow
sleep 20
echo "$(wall) this line is written after the sleep, or during a sleep that never came; $(($(date +%s) - before)) s by the clock"
caffeinate -u -t 2
sleep 3
slept
pmset -g log | grep -E " (Sleep|Wake|DarkWake) +	" | tail -n 6 | cut -c 1-160 | sed 's/^/  /'

step "3  after it"
what_arbor_says
grep -iE "wake|woke|sleep" "$ARBOR_HOME/arbor.log" | tail -n 8 | cut -c 12- | sed 's/^/  log | /'
# shellcheck disable=SC2086
press_all after-the-wake $KEYS
shot 01-after-the-wake
arbor_stop 02-quit
