#!/bin/bash
# A probe, not a check: what macOS's own ways of moving a window look like from outside, and what Arbor does about them today.
#
#   scripts/mac-shell/run.sh --no-preflight "real apps and the sampler, which the fake Mac has not" scripts/mac-shell/probe-macos-own-moves.sh
#
# A double-click on a title bar is one way of asking macOS for another frame, and Arbor stands aside for it. There are more: ⌥-click on the
# green button; Window ▸ Zoom, Fill, Move & Resize; and the keys macOS has for its own tiling (fn ⌃ F, C, R and the arrows). On a
# docked window Arbor still undoes them all. The ruling (board 0.24): a docked window whose frame changes, Arbor having asked nothing,
# within a second of a click or a modifier key, is taken for its person's asking macOS. Whether a second is the right length only a
# Mac can say. So for each act, on a test window and on two of macOS's own apps, played with the real pointer and real keys:
#
#   how long after the release of the button, or the key, does the first new frame show; how long until the last; how many steps.
#
# Twice: with Arbor paused, which is macOS by itself; and with Arbor running and the window docked, which is today's Arbor (a trace of each
# session comes back in traces/). sampler.swift asks the window server sixty times a second and also writes down the button and the
# keys; the table at the end is read from its log, mac-shell/samples.log.
#
# It changes no setting. It opens TextEdit and Terminal and tiles windows all over the screen, so it runs on GitHub's throwaway Macs alone.
source "$(dirname "$0")/lib-day.sh"
needs_throwaway_mac "open TextEdit and Terminal, ask System Events where their menus are, and tile windows all over the screen"

# place_of <process> <what, in System Events' words>: the middle of it, in whole points. Only looks.
place_of() {
  arbor_within 10 osascript -e "tell application \"System Events\" to tell process \"$1\" to get {position, size} of $2" 2> /dev/null \
    | awk -F', *' 'NF == 4 { printf "%d %d\n", $1 + $3 / 2, $2 + $4 / 2 }'
}

# menu_pick <process> <item> [<item of its submenu>]: in the Window menu, with the real pointer, as a hand does it.
menu_pick() {
  local process=$1 item=$2 sub=${3:-} bar="menu bar item \"Window\" of menu bar 1" at
  at=$(place_of "$process" "$bar")
  [ -n "$at" ] || { echo "$process has no Window menu"; return 1; }
  # shellcheck disable=SC2086
  click $at
  sleep 0.5
  at=$(place_of "$process" "menu item \"$item\" of menu 1 of $bar")
  if [ -z "$at" ]; then
    echo "its Window menu has no \"$item\""
    key escape
    return 1
  fi
  if [ -z "$sub" ]; then
    # shellcheck disable=SC2086
    click $at
    return
  fi
  # shellcheck disable=SC2086
  move $at
  sleep 0.7
  at=$(place_of "$process" "menu item \"$sub\" of menu 1 of menu item \"$item\" of menu 1 of $bar")
  if [ -z "$at" ]; then
    echo "\"$item\" has no \"$sub\""
    key escape
    key escape
    return 1
  fi
  # shellcheck disable=SC2086
  click $at
}

# opt_green <window>
opt_green() {
  local at
  at=$("$ARBOR_POINTER" button "$1" zoom 2> /dev/null) || { echo "it has no green button"; return 1; }
  # shellcheck disable=SC2086
  click $at --mods opt
}

# says <window>: what Arbor takes it for
says() {
  local word
  for word in docked floating letBe parked; do
    if is "$word" "$1" > /dev/null 2>&1; then printf '%s ' "$word"; fi
  done
}

# one <subject> <round> <slug> <window> <command…>: a mark, the act, and quiet. The mark comes first and the act's own clicks after it, so
# that the reader finds the last release or key before the first new frame.
one() {
  local subject=$1 round=$2 slug=$3 window=$4 before after
  shift 4
  before=$(real_frame_of "$window")
  note "probe $subject $round $slug $window"
  if ! "$@"; then
    note "probe-void $subject $round $slug $window"
    echo "  $slug: could not be played"
    return 0
  fi
  quiet 1200 6000
  # What comes now, the way home for one, is no part of the act.
  note "probe-end"
  after=$(real_frame_of "$window")
  echo "  $slug: $before -> $after ($QUIET)$([ "$round" = running ] && echo "; Arbor says: $(says "$window")")"
}

# every_act <subject> <round> <window> <process>
every_act() {
  local subject=$1 round=$2 window=$3 process=$4 chord
  # Home between two acts: with Arbor running, into its slot; paused, wherever macOS's own way back leads.
  home() { if [ "$round" = running ]; then ctl show-all > /dev/null; sleep 1.5; fi; }
  # In front, and the click that brought it there long past.
  click_window "$window"
  sleep 2.5
  one "$subject" "$round" opt-green "$window" opt_green "$window"
  home
  one "$subject" "$round" opt-green-again "$window" opt_green "$window"
  home
  one "$subject" "$round" menu-zoom "$window" menu_pick "$process" Zoom
  home
  one "$subject" "$round" menu-fill "$window" menu_pick "$process" Fill
  home
  one "$subject" "$round" menu-left "$window" menu_pick "$process" "Move & Resize" Left
  home
  one "$subject" "$round" menu-return "$window" menu_pick "$process" "Move & Resize" "Return to Previous Size"
  home
  for chord in left right up down f c r; do
    sleep 1.5
    one "$subject" "$round" "key-$chord" "$window" key "fn+ctrl+$chord"
    home
  done
}

# session <subject> <window> <neighbour> <process>: Arbor runs, both are floating.
session() {
  local subject=$1 window=$2 neighbour=$3 process=$4
  step "$subject: Arbor paused: macOS by itself"
  ctl pause
  sleep 1
  every_act "$subject" paused "$window" "$process"
  shot "$subject-paused-at-the-end"
  ctl resume
  sleep 1.5

  step "$subject: docked, Arbor running: what it does today"
  ctl dock "$window" left
  ctl dock "$neighbour" right
  sleep 1.5
  summary
  ctl trace on "macos-own-moves-$subject"
  every_act "$subject" running "$window" "$process"
  ctl trace off
  shot "$subject-running-at-the-end"
  summary
}

day_build
sampler_start
echo "macOS $(sw_vers -productVersion); tiling by keys: $(defaults read com.apple.WindowManager 2> /dev/null | grep -c -i tiling) settings written"

step "session: a test window"
arbor_settings '{}'
ARBOR_TEST_WINDOWS_ARGS="--regular"
arbor_start 2
session test "$W1" "$W2" ArborTestWindows
arbor_stop
ARBOR_TEST_WINDOWS_ARGS=""

for app in TextEdit Terminal; do
  step "session: $app"
  open -a "$app" 2> /dev/null || { echo "$app: cannot open"; continue; }
  sleep 4
  pid=$(pgrep -x "$app" | head -n 1)
  if [ -z "$pid" ]; then echo "$app is not running"; continue; fi
  arbor_settings '{}'
  ARBOR_EXTRA_PIDS=$pid
  arbor_start 1
  A=$(state | python3 -c '
import json, sys
print(next((w["id"] for w in json.load(sys.stdin)["windows"] if w["managed"] and w["pid"] == int(sys.argv[1])), ""))' "$pid")
  if [ -n "$A" ]; then session "$app" "$A" "$W1" "$app"; else echo "$app has no window that Arbor arranges"; fi
  arbor_stop
  ARBOR_EXTRA_PIDS=""
  on_throwaway_mac && pkill -x "$app"
done
sampler_stop

step "the table"
python3 - "$DAY_SAMPLES" << 'PYTHON'
import sys

# For each mark: the last release of the button, or key, before the window's first new frame; then how long to the first frame, to the
# last, and how many frames. With Arbor running the road is printed too: what macOS did, and what came after.
acts, current = [], None
for line in open(sys.argv[1], errors="replace"):
    parts = line.split()
    if len(parts) < 2:
        continue
    time, kind = int(parts[0]), parts[1]
    if kind == "M" and len(parts) >= 7 and parts[2] == "probe":
        current = {"name": parts[3:6], "window": parts[6], "marked": time, "inputs": [], "frames": [], "void": False}
        acts.append(current)
    elif kind == "M" and len(parts) >= 3 and parts[2] == "probe-void" and current:
        current["void"] = True
        current = None
    elif kind == "M" and len(parts) >= 3 and parts[2] == "probe-end":
        current = None
    elif current and kind == "B" and parts[2] == "up":
        current["inputs"].append(time)
    elif current and kind == "K":
        current["inputs"].append(time)
    elif current and kind == "W" and parts[2] == current["window"]:
        current["frames"].append((time, " ".join(parts[5:9])))

print(f'{"subject":10} {"round":8} {"act":16} {"first ms":>9} {"last ms":>8} {"steps":>6}   road')
worst = 0
for act in acts:
    subject, state, slug = act["name"]
    if act["void"]:
        print(f"{subject:10} {state:8} {slug:16} {'not played':>9}")
        continue
    if not act["frames"]:
        print(f"{subject:10} {state:8} {slug:16} {'-':>9} {'-':>8} {0:>6}   no new frame")
        continue
    first = act["frames"][0][0]
    before = [t for t in act["inputs"] if t <= first]
    asked = before[-1] if before else act["marked"]
    last = act["frames"][-1][0]
    if state == "paused":
        worst = max(worst, first - asked)
    road = [frame for _, frame in act["frames"]]
    shown = road if len(road) <= 4 else road[:2] + ["…"] + road[-2:]
    print(f"{subject:10} {state:8} {slug:16} {first - asked:>9} {last - asked:>8} {len(road):>6}   {' | '.join(shown)}{'' if before else '   (no input seen: counted from the mark)'}")
print(f"\nthe slowest first frame with Arbor paused: {worst} ms after the release or the key")
PYTHON
exit 0
