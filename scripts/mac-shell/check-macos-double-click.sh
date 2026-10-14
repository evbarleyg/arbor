#!/bin/bash
# What macOS makes of a double-click on a docked window's title bar stays (backlog K193):
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-macos-double-click.sh
#
# macOS has an action of its own for that double-click (System Settings → Desktop & Dock → "Double-click a window's title
# bar to": Fill, Zoom, Minimize, Do Nothing). Arbor used to pull a docked window back into its slot a quarter of a
# second after macOS had zoomed it: two moves, and a fight. Now it stands aside.
#
# One session for each setting of macOS's, beginning with the one it comes with, on test windows and with real
# double-clicks: the window goes where macOS sends it, by one road, and stays; nobody else moves; Arbor sets no frame
# (its own trace says so); macOS's second double-click brings it back to its slot; and after a third, one command of
# Arbor's does, in one move. Then the same with two of macOS's own apps.
#
# The question only a Mac can answer: does the Accessibility layer's monitor hear the second press, with its count, before the
# app reports the new frame? The traces come back in traces/: what macOS reports round a title bar's double-click.
#
# On a person's Mac only the first session runs, with the setting as that person has it. The others change a setting of the system's
# and open apps, so they run on GitHub's throwaway Macs alone.
source "$(dirname "$0")/lib-double-click.sh"

# heard <n> <window>: Arbor's log has that many double-clicks that reached the window's app
heard() { [ "$(grep -c "a double-click reached w$2\$" "$ARBOR_HOME/arbor.log")" -eq "$1" ]; }

# there_and_back <name> <window> <neighbour>: both docked, everything in view.
there_and_back() {
  local name=$1 window=$2 neighbour=$3 slot beside zoomed
  slot=$(real_frame_of "$window")
  beside=$(real_frame_of "$neighbour")
  # Worked out before the trace starts, so that it holds what happened and not the script's questions.
  local bar
  bar=$(titlebar_of "$window")

  step "$name: double-click the docked window's title bar"
  trace_on "double-click-$name" "a double-click on a docked window's title bar; macOS's own action: $name"
  # shellcheck disable=SC2086
  frames_during "$window" "$ARBOR_OUT/frames-$name-1.txt" must dblclick $bar
  trace_off "double-click-$name"
  zoomed=$(real_frame_of "$window")
  shot "$name-1-after-the-double-click"
  check "Arbor heard that the double-click reached the app" heard 1 "$window"
  check "the window is docked as before" is docked "$window"
  # What macOS is set to do says what must be seen: a window that only seems to have stayed may have been there and back.
  case "$(defaults read -g AppleActionOnDoubleClick 2>/dev/null)" in
    Minimize) check "macOS minimized it" eventually is minimized "$window" ;;
    None) check "macOS did nothing with it" stayed "$ARBOR_OUT/frames-$name-1.txt" ;;
    *) check "macOS gave it another frame" differs "$zoomed" "$slot" ;;
  esac
  if is minimized "$window"; then
    echo "like any window that is minimized: its neighbours share its room, as they always have"
    # Descriptor 9 is the test windows' stdin.
    echo "restore $window" >&9
    check "back from the Dock it is in its slot" eventually real_frame_is "$window" "$slot"
    return
  fi
  check "Arbor set no frame at all" arbor_moved_nothing
  check "the neighbour did not move" real_frame_is "$neighbour" "$beside"
  if stayed "$ARBOR_OUT/frames-$name-1.txt"; then
    check "the window is in its slot" real_frame_is "$window" "$slot"
    return
  fi
  check "the window went one way, and did not turn round" one_road "$ARBOR_OUT/frames-$name-1.txt"
  sleep 2
  check "nor two seconds later: it is where macOS put it" real_frame_is "$window" "$zoomed"
  check "and Arbor says that it lets it be" is letBe "$window"
  summary

  step "$name: double-click it again"
  # The title bar is where the window really is.
  read -r zx zy zw _ <<< "$zoomed"
  trace_on "double-click-$name-again" "a second double-click on its title bar"
  # Whole points: on a Retina display the window server deals in halves.
  frames_during "$window" "$ARBOR_OUT/frames-$name-2.txt" must dblclick "$((${zx%.*} + ${zw%.*} / 2))" "$((${zy%.*} + 12))"
  trace_off "double-click-$name-again"
  check "macOS returns it to its slot" eventually real_frame_is "$window" "$slot"
  check "by one road" one_road "$ARBOR_OUT/frames-$name-2.txt"
  check "and Arbor set no frame" arbor_moved_nothing
  check "from where Arbor keeps it like any docked window" eventually grep -q "w$window is back in its slot" "$ARBOR_HOME/arbor.log"
  check "and says so" not is letBe "$window"
  shot "$name-2-back"

  step "$name: once more, and this time Arbor takes it back"
  # shellcheck disable=SC2086
  must dblclick $bar
  sleep 2
  echo "the window is at $(real_frame_of "$window")"
  trace_on "double-click-$name-show-all" "show-all takes the zoomed window back"
  frames_during "$window" "$ARBOR_OUT/frames-$name-3.txt" ctl show-all
  trace_off "double-click-$name-show-all"
  check "showing everything puts it into its slot" eventually real_frame_is "$window" "$slot"
  check "by one road" one_road "$ARBOR_OUT/frames-$name-3.txt"
  check "the neighbour did not move" real_frame_is "$neighbour" "$beside"
  echo "Arbor set the window's frame $(moves_of "$window") time(s)"
  shot "$name-3-taken-back"
}

arbor_build

actions="as-it-is"
on_throwaway_mac && actions="default Fill Maximize Minimize None"
for action in $actions; do
  step "session: macOS's own action is $action"
  title_bar_action "$action"
  arbor_settings '{}'
  arbor_start 3
  ctl dock "$W1" left
  ctl dock "$W2" right
  sleep 0.7
  summary
  there_and_back "$action" "$W1" "$W2"
  grep -i "double-click" "$ARBOR_HOME/arbor.log" | tail -n 8 | cut -c 1-200 | sed 's/^/    /'
  arbor_stop
done
on_throwaway_mac || echo "a person's Mac: leaving out macOS's other settings and the real apps, which run only on GitHub's Macs"
on_throwaway_mac || exit 0
title_bar_action default

for app in TextEdit Terminal; do
  step "session: $app, docked beside a test window"
  open -a "$app" 2>/dev/null || { echo "$app: cannot open"; continue; }
  sleep 4
  pid=$(pgrep -x "$app" | head -n 1)
  if [ -z "$pid" ]; then echo "$app is not running"; continue; fi
  arbor_settings '{}'
  ARBOR_EXTRA_PIDS=$pid
  arbor_start 1
  A=$(state | python3 -c '
import json, sys
print(next((w["id"] for w in json.load(sys.stdin)["windows"] if w["managed"] and w["pid"] == int(sys.argv[1])), ""))' "$pid")
  if [ -n "$A" ]; then
    ctl dock "$A" left
    ctl dock "$W1" right
    sleep 1
    summary
    there_and_back "$app" "$A" "$W1"
  else
    echo "$app has no window that Arbor arranges"
  fi
  arbor_stop
  ARBOR_EXTRA_PIDS=""
  pkill -x "$app"
done
exit 0
