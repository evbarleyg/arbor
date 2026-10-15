#!/bin/bash
# Leaving an app Arbor pauses for (`pauseForApps`), with real apps: the window that is switched to has the keyboard and is in view.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-resume.sh
#
# What only a Mac can say. The pause ends at macOS's word that another app has become active, and a resume ends by asking who has the
# keyboard and bringing that window into view. macOS names the app in front on another channel, up to 50 ms later
# (`AppThatCameForward`). Asked in between, it names the app that was left: Arbor showed that one's window, and the window that was
# switched to stayed out of view with the keyboard in it. So, in each round:
#   - is the window that was switched to in view, and does it stay?
#   - was the window that was left ever taken for the one with the keyboard? Arbor's log says who was.
# Several rounds, because what goes wrong here goes wrong by milliseconds; the end says how often macOS was behind.
#
# Needs apps with bundle ids, which test windows have not: Calculator is the app Arbor pauses for, TextEdit the one that is
# switched to, with a throwaway document. No trace: a pause ends one, and none can be started during a pause (docs/TRACES.md).
source "$(dirname "$0")/lib-apps.sh"
needs_throwaway_mac "open Calculator and TextEdit and bring them forward in turn"

ROUNDS=6

apps_build
apps_scratch
apps_watchdog 420

step "Calculator, TextEdit and a test window"
app_open com.apple.calculator || die "no Calculator"
GAME_PID=$APP_PID GAME=$APP_WINDOW
app_open com.apple.TextEdit "$APPS_SCRATCH/oak.txt" || die "no TextEdit"
EDIT_PID=$APP_PID EDIT=$APP_WINDOW
companions_start 1
arbor_start_apps "$GAME_PID" "$EDIT_PID" "$COMPANIONS_PID" || die "Arbor did not start"
echo "Calculator: pid $GAME_PID, window $GAME; TextEdit: pid $EDIT_PID, window $EDIT"
# Apps have just joined the Dock, which changes the visible frame for a second or so.
sleep 3
ctl dock "$C1" left
ctl dock "$EDIT" right
ctl set pauseForApps add com.apple.calculator
brief

says() { "$ARBOR_BIN/arborctl" status | grep -q "$1"; }
# What Arbor has logged since line $1, without the date.
logged_since() { tail -n "+$(($1 + 1))" "$ARBOR_HOME/arbor.log" | cut -c 26-; }
took_for_the_one_with_the_keyboard() { logged_since "$1" | grep -q "w$2 has the keyboard"; }

round=1
while [ "$round" -le "$ROUNDS" ]; do
  step "out of the app Arbor pauses for, to a window the view does not show ($round of $ROUNDS)"
  ctl show-all > /dev/null
  ctl zoom "$C1" > /dev/null
  check "TextEdit's window is out of view" eventually is parked "$EDIT"
  echo "> open -b com.apple.calculator"
  open -b com.apple.calculator
  check "Arbor pauses" eventually says "paused"
  sleep 1
  mark=$(wc -l < "$ARBOR_HOME/arbor.log")
  echo "> open -b com.apple.TextEdit"
  open -b com.apple.TextEdit
  check "Arbor runs again" eventually says "running"
  check "TextEdit's window has the keyboard" eventually is focused "$EDIT"
  check "and is in view" eventually is on_screen "$EDIT" || brief
  # Long enough for every look Arbor takes at a focus report (a second).
  sleep 1.5
  check "and stays there" is on_screen "$EDIT"
  check "Calculator's window was never taken for the one with the keyboard" not took_for_the_one_with_the_keyboard "$mark" "$GAME"
  logged_since "$mark" | grep -E "resumed|keyboard|focus is on|forward|active|showing|framed" | tail -n 12
  round=$((round + 1))
done

echo
echo "macOS was behind with the app in front $(grep -c "still names another app" "$ARBOR_HOME/arbor.log") time(s) in this session"

arbor_stop
companions_stop
app_quit "$EDIT_PID"
app_quit "$GAME_PID"
