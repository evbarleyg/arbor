#!/bin/bash
# F54, arrangements as a line of text, on real windows and through the real arborctl and a real shell:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-F54.sh
#
# 1. On test windows, safe on anybody's Mac: a line with every sign in it crosses the shell, arborctl and the socket
#    unharmed; the windows go where it says; `layout` prints a line that puts them back; an error points at its column;
#    parts of titles stay out of the log.
# 2. Only on a throwaway Mac, because Arbor then arranges every window there is: `layout --open` really opens apps
#    (TextEdit, which may or may not make a window when opened in the background, and Terminal, which does), they do not
#    take the keyboard, and their windows take their places. What is not known is recorded rather than judged.
source "$(dirname "$0")/lib.sh"

printed() { "$ARBOR_BIN/arborctl" layout "$@"; }
prints() { [ "$(printed --ids)" = "$1" ]; }
left_of() { [ "$(frame_of "$1" | awk '{ print int($1 + $3) }')" -le "$(frame_of "$2" | awk '{ print int($1) }')" ]; }
above() { [ "$(frame_of "$1" | awk '{ print int($2 + $4) }')" -le "$(frame_of "$2" | awk '{ print int($2) }')" ]; }
# safe anywhere: called in part 2 only, which runs on a throwaway Mac
front() { lsappinfo info -only name "$(lsappinfo front)" 2>/dev/null | tr -d '\n'; }
docked_count() { printed --ids | tr -c '0-9' '\n' | grep -c '^[0-9][0-9][0-9]*$'; }

arbor_build

step "a line of text, by window number"
arbor_start 4
ctl layout "$W2:2 | Desktop | ($W3 / $W1)"
check "2 is left of 3" eventually left_of "$W2" "$W3"
check "3 is above 1" eventually above "$W3" "$W1"
check "every docked window is in its slot" eventually is in_slot "$W2"
check "4 was not mentioned and floats" is floating "$W4"
check "it prints what was typed" prints "$W2:2 | Desktop | ($W3 / $W1)"
shot 01-layout

step "the line that is printed puts things back"
saved=$(printed --ids)
ctl float-all
ctl layout "$saved"
check "the same arrangement again" prints "$saved"
check "and the windows are there" eventually is in_slot "$W1"

step "by app name: the most recent window, the rest as tabs"
app=$(state | python3 -c 'import json, sys; print(json.load(sys.stdin)["windows"][0]["app"])')
echo "the test windows' app is called: $app"
ctl layout "'$app' | '$app'*"
printed
printed --titles
check "all four are docked" test "$(docked_count)" = 4
shot 02-tabs

step "errors come back whole"
ctl layout "$W1 | $W2 / $W3"
check "and the command fails" test "$("$ARBOR_BIN/arborctl" layout "$W1 | $W2 / $W3" > /dev/null 2>&1; echo $?)" = 1

step "parts of titles stay out of the log"
ctl layout "'$app'~Zebra | $W2"
check "the command is logged" grep -q "layout .*~…" "$ARBOR_HOME/arbor.log"
check "without the title" test "$(grep -c Zebra "$ARBOR_HOME/arbor.log")" = 0
arbor_stop 03-quit

on_throwaway_mac || { echo; echo "part 2 skipped: it lets Arbor arrange every window and opens apps, and this Mac is somebody's"; exit 0; }
# The fake Mac has test windows only: no TextEdit or Terminal to open, and none of AXWindowSystem+Launch.swift, whose log is read below.
[ -z "${ARBOR_REHEARSAL:-}" ] || { echo; echo "part 2 skipped: a rehearsal has no apps to open, so only a real Mac can judge --open"; exit 0; }

step "layout --open, with Arbor arranging everything"
on_throwaway_mac && { pkill -x TextEdit; pkill -x Terminal; }
sleep 1
# safe anywhere: on a person's Mac the script has ended above; arranging every window is what part 2 is about
env ARBOR_NO_PROMPT=1 ARBOR_DEBUG=1 ARBOR_NO_HOTKEYS=1 ARBOR_NO_STATUS_ITEM=1 ARBOR_NO_WATCHDOG=1 "$ARBOR_BIN/Arbor" > "$ARBOR_OUT/arbor-stderr-open.log" 2>&1 &
ARBOR_PID=$!
started "$ARBOR_PID"
running() { "$ARBOR_BIN/arborctl" status | grep -q "^running"; }
check "Arbor runs" eventually running
before=$(front)
echo "in front before: $before"
ctl layout --open "TextEdit | Desktop | Terminal"
for second in 1 2 3 4 5 6 7 8 9 10; do
  sleep 1
  echo "after ${second}s: $(printed)   in front: $(front)"
done
check "Terminal's window took its place" sh -c "'$ARBOR_BIN/arborctl' layout | grep -q Terminal"
# Not a check: TextEdit opened in the background may show an Open panel, or nothing.
printed | grep -q TextEdit && echo "TextEdit's window took its place too" || echo "TextEdit made no standard window within 10 s"
check "the app in front is the one that was" test "$(front)" = "$before"
summary
shot 04-opened
grep -i "open\|took its place" "$ARBOR_HOME/arbor.log" | tail -n 10

step "an app that does not exist"
ctl layout --open "Terminal | NoSuchAppAtAll"
sleep 2
check "the log says that macOS found none" grep -q "found no app called NoSuchAppAtAll" "$ARBOR_HOME/arbor.log"
arbor_stop 05-quit
on_throwaway_mac && { pkill -x TextEdit; pkill -x Terminal; }
