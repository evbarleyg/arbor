#!/bin/bash
# Does macOS itself bring windows back when a display returns? A probe of macOS alone: Arbor does not run (collab/QUESTIONS.md, Q29, 4).
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-display-returns.sh
#
# Arbor fetches floating windows back to a display that returns. If macOS does so by itself, that is a second mover for nothing. So: four stock apps' windows on a second display; the display goes, and macOS
# moves them over; nothing is touched; the display comes back. Where is each window after 1, 3 and 10 s: to the point where it was, roughly, or not at all? Once more with one window
# moved by hand meanwhile.
#
# WHAT KIND OF DISPLAY: a virtual one (vdisplay.m, a private API), with the same vendor, product and serial number each time, so that macOS can take it for the same display. No cable, no lid, no sleep. On
# GitHub's Macs the first virtual display also changes the size of the main one, so every round is played twice: with that display alone, and with another virtual display that stays throughout, beside
# which the one that goes and comes may leave the main display alone. What the displays were at each moment is printed. A real display may behave otherwise, and nothing here can tell.
source "$(dirname "$0")/lib-apps.sh"
needs_throwaway_mac "plug virtual displays in and out, at which macOS rearranges every window"

GOES_PID=""
GOES_ID=""
WINDOWS=""
at_exit 'kill_started $GOES_PID'
displays() { pointer displays | awk '{ print "    display " $1 ": " $2, $3, $4, $5 }'; }
# comes <how many displays there are then>
comes() {
  local hello="" tries=0
  : > "$ARBOR_OUT/goes.txt"
  "$ARBOR_VDISPLAY" add 1280 800 "Arbor Test Display That Goes" --serial 7 > "$ARBOR_OUT/goes.txt" 2>> "$ARBOR_OUT/vdisplay.log" 9>&- 8>&- 3>&- &
  GOES_PID=$!
  started "$GOES_PID"
  while [ -z "$hello" ] && [ "$tries" -lt 80 ]; do
    sleep 0.1
    hello=$(head -n 1 "$ARBOR_OUT/goes.txt")
    tries=$((tries + 1))
  done
  [ -n "$hello" ] || die "no virtual display ($(tail -n 1 "$ARBOR_OUT/vdisplay.log"))"
  GOES_ID=${hello%% *}
  arbor_await_displays "$1" || echo "NOTE: macOS lists $ARBOR_DISPLAY_COUNT displays, not $1"
}
goes() {
  kill -TERM "$GOES_PID" 2>/dev/null
  ended "$GOES_PID" || echo "NOTE: the display's process did not end"
  GOES_PID=""
  arbor_await_displays "$1" || echo "NOTE: macOS lists $ARBOR_DISPLAY_COUNT displays, not $1"
}
# look <file>: where the window server has each window.
look() {
  local id
  for id in $WINDOWS; do echo "$id $(real_frame_of "$id")"; done > "$ARBOR_OUT/$1.txt"
}
# round <name> <displays without the one that goes> [touch]
round() {
  local name=$1 others=$2 touch=${3:-} id index=0 gx gy gw gh px py first
  step "$name: the display comes, and four windows are put on it"
  comes $((others + 1))
  sleep 3
  displays
  read -r gx gy gw gh <<< "$(pointer displays | awk -v id="$GOES_ID" '$1 == id { print $2, $3, $4, $5 }')"
  [ -n "${gh:-}" ] || die "the display that came is not listed"
  for id in $WINDOWS; do
    apptool set-frame "$id" $((gx + 60 + index * 150)) $((gy + 70 + index * 60)) 620 420 > /dev/null
    index=$((index + 1))
  done
  sleep 2
  look "$name-0-on-it"

  step "$name: it goes"
  goes "$others"
  sleep 3
  displays
  look "$name-1-gone"
  if [ -n "$touch" ]; then
    first=${WINDOWS%% *}
    read -r px py _ <<< "$(apptool grab "$first")"
    echo "one window is moved by hand meanwhile, 140 points right and 90 down"
    drag "$px" "$py" $((px + 140)) $((py + 90))
    sleep 1
    look "$name-1b-moved-by-hand"
  fi

  step "$name: it comes back, and nothing is touched"
  comes $((others + 1))
  sleep 1
  look "$name-2-back-1s"
  sleep 2
  look "$name-3-back-3s"
  sleep 7
  look "$name-4-back-10s"
  displays
  shot "$name-back"
  python3 - "$ARBOR_OUT" "$name" "$touch" <<'PY'
import os, sys
folder, name, touch = sys.argv[1:4]
def read(stage):
    path = os.path.join(folder, f"{name}-{stage}.txt")
    rows = {}
    for line in open(path):
        words = line.split()
        rows[words[0]] = [round(float(word)) for word in words[1:5]] if len(words) >= 5 else None
    return rows
stages = ["0-on-it", "1-gone"] + (["1b-moved-by-hand"] if touch else []) + ["2-back-1s", "3-back-3s", "4-back-10s"]
seen = {stage: read(stage) for stage in stages}
print(f"  {'window':8}" + "".join(f"{stage:>22}" for stage in stages) + "   verdict at 10 s")
for index, window in enumerate(seen["0-on-it"]):
    was, now, gone = seen["0-on-it"][window], seen["4-back-10s"][window], seen["1-gone"][window]
    if not was or not now:
        verdict = "cannot tell: no frame"
    elif was == now:
        verdict = "to the point, size and all"
    elif was[:2] == now[:2]:
        verdict = "to the point, another size"
    elif abs(was[0] - now[0]) <= 40 and abs(was[1] - now[1]) <= 40:
        verdict = "roughly (within 40 points)"
    elif now == (seen.get("1b-moved-by-hand") or seen["1-gone"])[window]:
        verdict = "NOT AT ALL: where it lay while the display was gone"
    else:
        verdict = "somewhere else"
    hand = " (the one moved by hand)" if touch and index == 0 else ""
    print(f"  {window:8}" + "".join(f"{' '.join(map(str, seen[stage][window] or ['?'])):>22}" for stage in stages) + f"   {verdict}{hand}")
PY
  step "$name: tidied up"
  goes "$others"
  sleep 2
}

apps_build
apps_scratch
step "four stock apps, no Arbor"
for app in "com.apple.TextEdit $APPS_SCRATCH/oak.txt" "com.apple.Safari $APPS_SCRATCH/page.html" "com.apple.Preview $APPS_SCRATCH/leaf.png" "com.apple.finder $APPS_SCRATCH/grove"; do
  # shellcheck disable=SC2086
  if app_open $app; then
    WINDOWS="$WINDOWS $APP_WINDOW"
    echo "  window $APP_WINDOW is ${app%% *}'s"
  else
    echo "NOTE: ${app%% *} gave no window"
  fi
done
WINDOWS=${WINDOWS# }
[ -n "$WINDOWS" ] || die "no app gave a window"
displays

round alone 1
round alone-and-a-hand 1 touch

step "another virtual display, which stays"
if display_add 1280 720 right; then
  displays
  round beside-one-that-stays 2
  round beside-one-that-stays-and-a-hand 2 touch
  display_remove
fi
