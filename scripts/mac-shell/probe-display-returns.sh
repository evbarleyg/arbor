#!/bin/bash
# Where does macOS NOT bring a window back when a display returns? A probe of macOS alone: Arbor does not run (collab/QUESTIONS.md, Q29, 4).
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-display-returns.sh
#
# Arbor fetches floating windows back to a display that returns. That macOS does so by itself is known (docs/REALITY.md, macos-puts-windows-back-on-a-display-that-returns: three test windows, back at their
# old frames 0.15 to 0.2 s after a virtual display with the same identifier returned). If it always does, Arbor's fetching is a second mover for nothing; one case in which macOS leaves a window behind keeps it.
# So this looks for such a case: four stock apps' windows rather than test windows; one window dragged by hand while the display is gone; a display that returns with ANOTHER serial number, which is what
# macOS knows it by; one that is put at the other side of the main display as soon as it is back. Where is each window 1, 3 and 10 s after the return: to the point where it was, roughly, or not at all?
#
# WHAT KIND OF DISPLAY: a virtual one (vdisplay.m, a private API). No cable, no lid, no sleep. On GitHub's Macs the first virtual display also changes the size of the main one, so the first two rounds are played
# twice: with that display alone, and with another virtual display that stays throughout, beside which the one that goes and comes may leave the main display alone. What the displays were at each
# moment is printed. A real display may behave otherwise, and nothing here can tell.
source "$(dirname "$0")/lib-apps.sh"
needs_throwaway_mac "plug virtual displays in and out, at which macOS rearranges every window"

GOES_PID=""
GOES_ID=""
WINDOWS=""
at_exit 'kill_started $GOES_PID'
displays() { pointer displays | awk '{ print "    display " $1 ": " $2, $3, $4, $5 }'; }
# comes <how many displays there are then> [serial number]
comes() {
  local hello="" tries=0 serial=${2:-7}
  : > "$ARBOR_OUT/goes.txt"
  "$ARBOR_VDISPLAY" add 1280 800 "Arbor Test Display That Goes" --serial "$serial" > "$ARBOR_OUT/goes.txt" 2>> "$ARBOR_OUT/vdisplay.log" 9>&- 8>&- 3>&- &
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
# where_it_is <file>: the frame of the display that goes and comes, so that a window's place can also be told from that display's corner.
where_it_is() { pointer displays | awk -v id="$GOES_ID" '$1 == id { print $2, $3, $4, $5 }' > "$ARBOR_OUT/$1.txt"; }
# round <name> <displays without the one that goes> [touch|-] [the serial number it returns with] [other-side]
round() {
  local name=$1 others=$2 touch=${3:-} back=${4:-7} side=${5:-} id index=0 gx gy gw gh px py first mw
  [ "$touch" = - ] && touch=""
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
  where_it_is "$name-display-before"

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

  step "$name: it comes back, and no window is touched"
  comes $((others + 1)) "$back"
  if [ -n "$side" ]; then
    # Left of the main display, where it had been right of it or wherever macOS had put it.
    "$ARBOR_VDISPLAY" move "$GOES_ID" -1280 0 | sed 's/^/  moved to the other side: /'
  fi
  sleep 1
  look "$name-2-back-1s"
  sleep 2
  look "$name-3-back-3s"
  sleep 7
  look "$name-4-back-10s"
  where_it_is "$name-display-after"
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
def corner(which):
    words = open(os.path.join(folder, f"{name}-display-{which}.txt")).read().split()
    return [int(float(word)) for word in words[:2]] if len(words) >= 2 else None
before, after = corner("before"), corner("after")
print(f"  the display's corner: {before} before, {after} after")
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
    elif before and after and before != after and [was[0] - before[0], was[1] - before[1]] == [now[0] - after[0], now[1] - after[1]]:
        verdict = "to the point, counted from the display's corner, which moved"
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
round another-serial-number 1 - 8
round at-the-other-side 1 - 7 other-side

step "another virtual display, which stays"
if display_add 1280 720 right; then
  displays
  round beside-one-that-stays 2
  round beside-one-that-stays-and-a-hand 2 touch
  display_remove
fi
