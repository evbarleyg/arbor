#!/bin/bash
# A command given before Arbor has heard that the displays changed, on real macOS: the second display is virtual.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-a-key-in-the-wait.sh
#
# Arbor hears of a change of displays only once it has settled, a second and a half after macOS's last notice. Until then whatever
# moves a window or a view is refused and nothing is done (Controller+Displays.swift, `refusalWhileTheDisplaysChange`). Linux proves what
# the controller does. What only a Mac can tell: whether macOS's own list is new early enough for the refusal to bite as soon as the
# display is gone, for how long it lasts, whether anything moves meanwhile, and whether the same command is carried out a moment later.
#
# Every change is recorded as a trace of its own, which comes back in traces/.
#
# On GitHub's Macs plugging the display in also switches the main one from 1024×768 to 1920×1080, and unplugging switches it
# back, so every plug is a change of resolution too.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "plug a virtual display in and out, at which macOS moves every window"

WIDTH=1280
HEIGHT=800
LINE=6   # the window level of the line that says what happened

arbor_build
macos_tiling off

TRACES="$ARBOR_OUT/traces"
mkdir -p "$TRACES"

arranges() { [ "$(arbor_ask displays)" = "$1" ]; }
docked_on() { is docked "$2" && is "display$1" "$2"; }
size_of() { real_frame_of "$1" | awk '{ print $3, $4 }'; }
not() { ! "$@"; }
arbor_log_says_refused_since() { arbor_log_since "$1" | grep -F "the displays are still changing" > /dev/null; }
refused() { case "$1" in *"the displays are still changing"*) return 0 ;; *) return 1 ;; esac; }

# The display goes and the command is given as soon as macOS's own list is shorter: no waiting, no question to Arbor in between. Then
# again every quarter of a second until it is no longer refused.
# unplugged_and_at_once <trace> <command…>
unplugged_and_at_once() {
  local name=$1 id answer tries=0
  shift
  "$ARBOR_BIN/arborctl" trace on "$name" > /dev/null
  display_remove
  answer=$("$ARBOR_BIN/arborctl" "$@" 2>&1)
  echo "> $* at once: $answer"
  check "$name: at once it is refused" refused "$answer"
  for id in $ARBOR_WINDOW_IDS; do
    check "$name: refused, and window $id is on the screen that is left" is on_screen "$id"
  done
  shot "$name-refused"
  while refused "$answer" && [ "$tries" -lt 20 ]; do
    sleep 0.25
    tries=$((tries + 1))
    answer=$("$ARBOR_BIN/arborctl" "$@" 2>&1)
  done
  echo "> $* after $tries more tries, a quarter of a second apart: $answer"
  check "$name: within three and a half seconds it is refused no longer" test "$tries" -le 14
  sleep 3
  "$ARBOR_BIN/arborctl" trace off > /dev/null
  cp "$ARBOR_HOME"/traces/*-"$name".jsonl "$TRACES/$name.jsonl" || echo "no trace $name"
  check "$name: Arbor arranges one display" arranges 1
  for id in $ARBOR_WINDOW_IDS; do
    check "$name: in the end window $id is on the screen that is left" is on_screen "$id"
  done
  summary
}

plug_in() {
  display_add $WIDTH $HEIGHT right
  check "Arbor arranges two displays" eventually arranges 2
}

step "two displays: two windows docked and one floating on the second, one docked on the main one"
arbor_start 5 ARBOR_NO_HOTKEYS=0
plug_in
for id in "$W3" "$W4" "$W5"; do
  ctl move-to-display 2 "$id"
  check "window $id went across" eventually is display2 "$id"
done
own1=$(size_of "$W1")
ctl dock "$W5" left
ctl dock "$W4" right
ctl dock "$W1" left
check "window $W5 is docked on the second display" docked_on 2 "$W5"
check "window $W4 is docked on the second display" docked_on 2 "$W4"
sleep 2
summary
shot arranged

step "the display goes, and Float All is asked for at once"
unplugged_and_at_once float-all-in-the-wait float-all
check "window $W1 has its own size" test "$(size_of "$W1")" = "$own1"

step "it comes back: what slept with it wakes"
plug_in
sleep 3
summary
shot back
check "window $W5 is docked on the second display again" eventually docked_on 2 "$W5"

step "one window fills the second display; the display goes, and Show Everything is asked for at once"
ctl zoom "$W5"
sleep 2
summary
unplugged_and_at_once show-all-in-the-wait show-all

step "it comes back; the display goes, and ⌃⌥Space is pressed at once, by a real key: the line is where it can be read"
plug_in
sleep 3
summary
"$ARBOR_BIN/arborctl" trace on key-in-the-wait > /dev/null
display_remove
key ctrl+opt+space
check "the key is refused" eventually logged "show-all failed: the displays are still changing"
check "the line is on screen" has_overlay $LINE
line=$(overlay_frame $LINE)
left=$("$ARBOR_POINTER" displays | awk 'NR == 1 { print $2, $3, $4, $5 }')
echo "the line is at $line; the display that is left is at $left"
check "the line is on the display that is left" inside "$line" "$left"
shot key-refused
sleep 4
check "the line has gone" not has_overlay $LINE
mark=$(arbor_log_lines)
key ctrl+opt+space
sleep 1
check "pressed again, it is refused no longer" not arbor_log_says_refused_since "$mark"
"$ARBOR_BIN/arborctl" trace off > /dev/null
cp "$ARBOR_HOME"/traces/*-key-in-the-wait.jsonl "$TRACES/key-in-the-wait.jsonl" || echo "no trace key-in-the-wait"
summary

step "a window goes to the Dock, which changes its size for it; a key half a second later is carried out"
mark=$(arbor_log_lines)
tw minimize "$W2"
sleep 0.5
key ctrl+opt+space
sleep 1
check "the key after the window went to the Dock is not refused" not arbor_log_says_refused_since "$mark"
tw restore "$W2"
sleep 1
summary

step "what Arbor's log says of the displays"
grep -i "display" "$ARBOR_HOME/arbor.log" | cut -c 26- | uniq -c | tail -n 30
arbor_stop after-quit
