#!/bin/bash
# Who holds the display? Part 4: would a person meet it? Real apps in place of the test windows (part 1 has the story).
#
# THE QUESTION ONLY A MAC CAN ANSWER: does the display stand still when the windows that come back are TextEdit's, Safari's, Terminal's and Notes', with
# Arbor, and with a plain tool in Arbor's place.
ARBOR_TIME_LIMIT=1000
source "$(dirname "$0")/lib-apps.sh"
source "$(dirname "$0")/lib-standstill.sh"

# The fake Mac has no real apps, and lib-apps.sh's tools are compiled against AppKit.
[ -z "${ARBOR_REHEARSAL:-}" ] || { echo "real apps cannot be rehearsed"; exit 64; }
apps_build
still_build
still_begin
apps_scratch
pulse_start

PIDS=""
IDS=""
COUNT=0
# The first four that have a window to show for themselves.
for app in com.apple.TextEdit:"$APPS_SCRATCH/oak.txt" com.apple.Safari:"$APPS_SCRATCH/page.html" com.apple.Terminal: com.apple.Notes: \
  com.apple.Preview:"$APPS_SCRATCH/leaf.png"; do
  [ "$COUNT" -lt 4 ] || break
  # shellcheck disable=SC2086
  if app_open "${app%%:*}" ${app#*:} && [ -n "$APP_WINDOW" ]; then
    app_dismiss "$APP_PID"
    PIDS="$PIDS $APP_PID"
    IDS="$IDS $APP_WINDOW"
    COUNT=$((COUNT + 1))
  fi
done
echo "the apps:$PIDS; their windows:$IDS"
# shellcheck disable=SC2086
set -- $IDS
[ $# -ge 3 ] || die "fewer than three real apps have a window"
W1=$1 W2=$2 W3=$3 W4=${4:-}
# For the mover and for what is counted.
# shellcheck disable=SC2086
ARBOR_EXTRA_PIDS=$(echo $PIDS | tr ' ' ',')

# shellcheck disable=SC2086
arbor_start_apps $PIDS $STILL_FACE
sleep 2
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W1" bottom
[ -z "$W4" ] || ctl dock "$W4" beside "$W2" bottom
sleep 2
app_focus "$W2"
brief
shot apps-arranged

step "1. real apps, with Arbor"
away_and_back apps 4

step "2. one framed and everything again, which was never seen to stand still"
i=1
while [ "$i" -le 2 ]; do
  filmed "apps-frame-$i-away" "presses ⌃⌥↩ on a docked window" key ctrl+opt+return
  filmed "apps-frame-$i-back" "presses ⌃⌥Space" key ctrl+opt+space
  i=$((i + 1))
done

BACK=""
AWAY=""
read -r dx dy dw dh <<< "$(display_frame_of 1)"
for id in $IDS; do
  read -r x y _ _ <<< "$(real_of "$id")"
  BACK="$BACK move:$id:${x:-12}:${y:-43}"
  AWAY="$AWAY move:$id:$((dx + dw - 1)):$((dy + dh - 1))"
done

step "3. who waits for whom"
key ctrl+opt+d
sleep 3
watched watched-spindump-apps-back key ctrl+opt+[

step "4. THE CONTROL: the same windows, no Arbor"
# Killed, not asked to quit: a quit gives every window its earlier size back, and the control wants them as they are.
arbor_kill
sleep 1
i=1
while [ "$i" -le 3 ]; do
  # shellcheck disable=SC2086
  filmed "apps-control-$i-away" "a tool sends the windows to the corner" mover wait:700 go $AWAY
  # shellcheck disable=SC2086
  filmed "apps-control-$i-back" "a tool brings them back" mover wait:700 go $BACK
  i=$((i + 1))
done
i=1
while [ "$i" -le 3 ]; do
  # shellcheck disable=SC2086
  filmed "apps-cover-$i-away" "a tool sends the windows to the corner, under a cover" mover wait:700 go cover:0.46 $AWAY
  # shellcheck disable=SC2086
  filmed "apps-cover-$i-back" "a tool brings them back, under a cover" mover wait:700 go cover:0.46 $BACK
  i=$((i + 1))
done

for pid in $PIDS; do app_quit "$pid"; done
still_end
system_log_of_the_worst 4
