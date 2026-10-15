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
# Arbor's does, in one move. Then as a person met it: four windows, `arrange`, the double-click, and what comes next (other
# windows are switched to, one opens, ⌃⌥0 and back). Then the first round with two of macOS's own apps.
#
# The question only a Mac can answer: does the Accessibility layer's monitor hear the second press, with its count, before the
# app reports the new frame? The traces come back in traces/: what macOS reports round a title bar's double-click.
#
# On a person's Mac only the first session of each kind runs, with the setting as that person has it. The others change a setting of the system's
# and open apps, so they run on GitHub's throwaway Macs alone.
source "$(dirname "$0")/lib.sh"

TRACES="$ARBOR_OUT/traces"
mkdir -p "$TRACES"

# frames_during <window id> <file> <command…>: runs the command and writes every distinct frame the window server
# reports for the window from just before it until two to three seconds later.
frames_during() {
  local id=$1 file=$2 watcher
  shift 2
  (
    end=$((SECONDS + 3))
    last=""
    while [ "$SECONDS" -lt "$end" ]; do
      now=$("$ARBOR_POINTER" frame "$id")
      if [ "$now" != "$last" ]; then echo "$now"; last=$now; fi
    done
  ) > "$file" 7>&- 8>&- 9>&- &
  watcher=$!
  started "$watcher"
  sleep 0.1
  "$@"
  ended "$watcher" 80 || kill_started "$watcher"
  echo "frames of $id meanwhile:"
  sed 's/^/    /' "$file"
}

# one_road <file>: the window never turned round. On its way from the first frame to the last, each of x, y, width and height
# went one way only, so it was moved once, however many stages macOS's animation shows.
one_road() {
  awk '
    NR == 1 { for (i = 1; i <= 4; i++) { first[i] = $i; before[i] = $i } next }
    { for (i = 1; i <= 4; i++) { step[NR, i] = $i - before[i]; before[i] = $i } rows = NR }
    END {
      for (i = 1; i <= 4; i++) {
        whole = before[i] - first[i]
        for (row = 2; row <= rows; row++) if (step[row, i] * whole < 0 || (whole == 0 && step[row, i] != 0)) bad = 1
      }
      exit bad
    }' "$1"
}
stayed() { [ "$(wc -l < "$1" | tr -d ' ')" -eq 1 ]; }
real_frame_is() { [ "$(real_frame_of "$1")" = "$2" ]; }
differs() { [ "$1" != "$2" ]; }
not() { ! "$@"; }
# must <press…>: on somebody's Mac the nets may decline a press, and then nothing happens either.
must() { "$@" || check "the press was let through: $*" false; }

trace_on() {
  ctl trace on "$1"
  "$ARBOR_BIN/arborctl" trace note "$2" > /dev/null
}
# trace_off <name>: ends the trace and brings it back without the date in its name. Sets TRACE.
trace_off() {
  local file
  ctl trace off
  TRACE=""
  for file in "$ARBOR_HOME"/traces/*-"$1".jsonl; do
    [ -f "$file" ] || continue
    TRACE="$TRACES/$1.jsonl"
    cp "$file" "$TRACE"
  done
}
# heard <n> <window>: Arbor's log has that many double-clicks that reached the window's app
heard() { [ "$(grep -c "a double-click reached w$2\$" "$ARBOR_HOME/arbor.log")" -eq "$1" ]; }
# The rehearsal on Linux records no traces: what they alone can say is left out there.
arbor_moved_nothing() { [ -z "$TRACE" ] || ! grep -q -E '"call":"(setFrame|moveTogether)"' "$TRACE"; }
moves_of() { [ -z "$TRACE" ] && echo "?" || grep -c -E "\"call\":\"setFrame\".*\"id\":$1[,}]" "$TRACE"; }

# title_bar_action <Fill|Maximize|Minimize|None|default>: before a session, because an app may read it when it starts.
title_bar_action() {
  if [ "$1" != as-it-is ] && arbor_may "change the setting \"double-click a window's title bar to\""; then
    if [ "$1" = default ]; then defaults delete -g AppleActionOnDoubleClick 2>/dev/null; else defaults write -g AppleActionOnDoubleClick -string "$1"; fi
  fi
  echo "AppleActionOnDoubleClick: $(defaults read -g AppleActionOnDoubleClick 2>/dev/null || echo "not set")"
}

# Seen on macOS 26: set to fill, a second double-click leaves the window filled. Not set, and set to zoom, it returns it.
fill_is_set() { [ "$(defaults read -g AppleActionOnDoubleClick 2>/dev/null)" = Fill ]; }

# at_its_slot <window>: by its corner and its width. Not by its height: how a slot's height is met on a Mac is another script's question.
at_its_slot() {
  local sx sy sw fx fy fw
  read -r sx sy sw _ <<< "$(arbor_ask slot "$1")"
  read -r fx fy fw _ <<< "$(real_frame_of "$1")"
  [ -n "$sw" ] && [ -n "$fw" ] && arbor_close "${sx} ${sy} ${sw} 0" "${fx} ${fy} ${fw} 0" \
    || { echo "it is at $fx $fy, $fw wide; its slot at $sx $sy, $sw wide"; return 1; }
}

# there_and_back <name> <window> <neighbour>: both docked, everything in view.
there_and_back() {
  local name=$1 window=$2 neighbour=$3 slot beside zoomed stood=no
  # Where it stands, which is where macOS will return it to. An app that rounds its size stands a few points out of its slot.
  slot=$(real_frame_of "$window")
  is in_slot "$window" > /dev/null 2>&1 && stood=yes
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
  check "and Arbor set no frame" arbor_moved_nothing
  if fill_is_set; then
    check "set to fill, macOS leaves it filled" stayed "$ARBOR_OUT/frames-$name-2.txt"
    check "and Arbor goes on letting it be" is letBe "$window"
  else
    check "macOS returns it to where it stood" eventually real_frame_is "$window" "$slot"
    check "by one road" one_road "$ARBOR_OUT/frames-$name-2.txt"
    if [ "$stood" = yes ]; then
      check "from where Arbor keeps it like any docked window" eventually grep -q "w$window is back in its slot" "$ARBOR_HOME/arbor.log"
      check "and says so" not is letBe "$window"
    else
      echo "it did not stand in its slot before the zoom ($slot; its slot: $(arbor_ask slot "$window")): whether that counts as home is not asked here"
    fi
  fi
  shot "$name-2-back"

  step "$name: once more, and this time Arbor takes it back"
  # shellcheck disable=SC2086
  must dblclick $bar
  sleep 2
  echo "the window is at $(real_frame_of "$window")"
  trace_on "double-click-$name-show-all" "show-all takes the zoomed window back"
  frames_during "$window" "$ARBOR_OUT/frames-$name-3.txt" ctl show-all
  trace_off "double-click-$name-show-all"
  check "showing everything puts it at its slot" eventually at_its_slot "$window"
  check "and Arbor lets it be no longer" not is letBe "$window"
  check "by one road" one_road "$ARBOR_OUT/frames-$name-3.txt"
  check "the neighbour did not move" real_frame_is "$neighbour" "$beside"
  echo "Arbor set the window's frame $(moves_of "$window") time(s)"
  shot "$name-3-taken-back"
}

# as_a_person_met_it <name>: four windows, `arrange`, macOS's own double-click on a title bar (collab/IDEAS.md, I19: it "works for a
# moment, then Arbor puts it back where the arrangement had it"), and then what a day brings next.
as_a_person_met_it() {
  local name=$1 slot zoomed bar beside new zx zy zw
  ctl arrange
  sleep 1
  summary
  slot=$(real_frame_of "$W1")
  beside="$(real_frame_of "$W2") $(real_frame_of "$W3") $(real_frame_of "$W4")"
  bar=$(titlebar_of "$W1")
  the_others_stayed() { [ "$(real_frame_of "$W2") $(real_frame_of "$W3") $(real_frame_of "$W4")" = "$beside" ]; }

  step "$name, arranged: double-click a title bar"
  trace_on "arranged-$name" "four windows, arrange, a double-click on a title bar; macOS's own action: $name"
  # shellcheck disable=SC2086
  frames_during "$W1" "$ARBOR_OUT/frames-$name-arranged-1.txt" must dblclick $bar
  zoomed=$(real_frame_of "$W1")
  shot "$name-arranged-1-after-the-double-click"
  check "macOS gave it another frame" differs "$zoomed" "$slot"
  check "it went one way, and did not turn round" one_road "$ARBOR_OUT/frames-$name-arranged-1.txt"
  sleep 5
  trace_off "arranged-$name"
  check "five seconds later it is where macOS put it" real_frame_is "$W1" "$zoomed"
  check "Arbor set no frame at all" arbor_moved_nothing
  check "the other three did not move" the_others_stayed
  check "it is docked as before" is docked "$W1"
  check "and \`arborctl state\` says that it is let be" is letBe "$W1"

  step "$name, arranged: switch to the others, and back"
  ctl focus "$W3"
  sleep 1
  check "the window switched to has the keyboard" eventually is focused "$W3"
  shot "$name-arranged-switched-to-another"
  tw front "$W4"
  sleep 1
  ctl focus "$W1"
  sleep 1
  check "it is where macOS put it" real_frame_is "$W1" "$zoomed"
  check "the other three did not move" the_others_stayed

  step "$name, arranged: a window opens"
  open_window new 300 300 500 300
  sleep 1.5
  check "it is where macOS put it" real_frame_is "$W1" "$zoomed"
  check "the other three did not move" the_others_stayed

  step "$name, arranged: everything (the key is ⌃⌥0), and back"
  frames_during "$W1" "$ARBOR_OUT/frames-$name-arranged-2.txt" ctl home
  check "a command of the person's puts it into its slot" eventually real_frame_is "$W1" "$slot"
  check "by one road" one_road "$ARBOR_OUT/frames-$name-arranged-2.txt"
  ctl back
  sleep 1
  check "the way back is a view, not a size: it stays there" real_frame_is "$W1" "$slot"
  check "the other three did not move" the_others_stayed

  step "$name, arranged: there again, and macOS's second double-click"
  # shellcheck disable=SC2086
  must dblclick $bar
  sleep 2
  read -r zx zy zw _ <<< "$(real_frame_of "$W1")"
  frames_during "$W1" "$ARBOR_OUT/frames-$name-arranged-3.txt" must dblclick "$((${zx%.*} + ${zw%.*} / 2))" "$((${zy%.*} + 12))"
  if fill_is_set; then
    check "set to fill, macOS leaves it filled" stayed "$ARBOR_OUT/frames-$name-arranged-3.txt"
    ctl show-all
    check "and a key puts it back" eventually real_frame_is "$W1" "$slot"
  else
    check "macOS returns it to where it stood" eventually real_frame_is "$W1" "$slot"
    check "by one road" one_road "$ARBOR_OUT/frames-$name-arranged-3.txt"
  fi
  shot "$name-arranged-2-back"
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
actions="as-it-is"
on_throwaway_mac && actions="default Fill Maximize"
for action in $actions; do
  step "session: four windows arranged; macOS's own action is $action"
  title_bar_action "$action"
  arbor_settings '{}'
  arbor_start 4
  as_a_person_met_it "$action"
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
