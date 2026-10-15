#!/bin/bash
# A probe, not a check (board 1.96): an app is ended without a word of its own. Is Arbor told, and how long does the dead window keep its slot?
#
#   scripts/mac-shell/run.sh --no-preflight "a real app is killed, which the fake Mac does not play" scripts/mac-shell/probe-an-app-that-is-ended.sh
#
# Seen on a Mac, by the way, in check-macos-double-click.sh: the second test app was ended (its pipe closed, SIGTERM three seconds later) and
# Arbor was never told. No window was reported gone, its log said nothing for ten seconds, it kept the dead window's slot into a pause, where
# its request to that window came back empty, and the resume counted one window fewer. Arbor hears of an app's end from macOS's
# "did terminate" notice alone (AXWindowSystem). Was that the test app, which the harness starts in its own way, or does a real app that crashes
# or is force-quit leave a ghost's slot too?
#
# So: TextEdit, opened as a person opens it, with a window docked beside a test window. Ended three ways: as a crash ends it (SIGKILL), as
# Force Quit and a log-out's impatience end it (SIGTERM), and in good order (it is asked to quit), which is the control. For each: how long
# until Arbor no longer knows the window, up to twenty seconds; whether the neighbour takes the room; and from Arbor's own trace, what it was told.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "open TextEdit and kill it"

# still_known <window>: whether Arbor still lists it.
still_known() { is known "$1" > /dev/null 2>&1; }

brought_to_an_end() {
  local how=$1 pid window began waited=gave-up beside
  step "TextEdit, ended by $how"
  open -a TextEdit 2> /dev/null || { echo "TextEdit: cannot open"; return 0; }
  sleep 4
  pid=$(pgrep -x TextEdit | head -n 1)
  if [ -z "$pid" ]; then echo "TextEdit is not running"; return 0; fi
  arbor_settings '{}'
  ARBOR_EXTRA_PIDS=$pid
  arbor_start 1
  window=$(state | python3 -c '
import json, sys
print(next((w["id"] for w in json.load(sys.stdin)["windows"] if w["managed"] and w["pid"] == int(sys.argv[1])), ""))' "$pid")
  if [ -z "$window" ]; then
    echo "TextEdit has no window that Arbor arranges"
  else
    ctl dock "$window" left
    ctl dock "$W1" right
    sleep 1.5
    summary
    beside=$(real_frame_of "$W1")
    ctl trace on "an-app-ended-$how"
    "$ARBOR_BIN/arborctl" trace note "ended by $how, window $window" > /dev/null
    began=$(python3 -c 'import time; print(time.time())')
    case "$how" in
      kill) kill -KILL "$pid" ;;
      term) kill -TERM "$pid" ;;
      quit) osascript -e 'tell application "TextEdit" to quit' > /dev/null 2>&1 ;;
    esac
    for _ in $(seq 1 100); do
      if ! still_known "$window"; then
        waited=$(python3 -c 'import sys, time; print(round(time.time() - float(sys.argv[1]), 1))' "$began")
        break
      fi
      sleep 0.2
    done
    echo "  $how: the process is $(kill -0 "$pid" 2> /dev/null && echo still there || echo gone); Arbor forgot the window after: $waited s"
    echo "  $how: the neighbour was at $beside and is at $(real_frame_of "$W1")"
    summary
    # What a request to a window that is no more comes to, if Arbor still believes in it.
    ctl show-all > /dev/null
    sleep 1
    echo "  $how: after Show Everything Arbor $(still_known "$window" && echo still knows it || echo does not know it)"
    ctl trace off
    shot "ended-by-$how"
    forget_window "$window"
  fi
  arbor_stop
  ARBOR_EXTRA_PIDS=""
  pkill -x TextEdit
  sleep 1
}

for how in kill term quit; do brought_to_an_end "$how"; done

step "what Arbor was told"
python3 - "$ARBOR_OUT"/traces/*an-app-ended-*.jsonl << 'PYTHON'
import json, sys

# After the remark: everything but the script's own questions and Arbor's look at the permission.
for path in sys.argv[1:]:
    print(path.rsplit("/", 1)[-1])
    after = None
    for line in open(path, errors="replace"):
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if isinstance(entry.get("note"), str) and entry["note"].startswith("ended by"):
            after = entry.get("t", 0)
            continue
        if after is None:
            continue
        text = json.dumps(entry, ensure_ascii=False)
        if entry.get("command") == "state" or entry.get("done") == "state" or "ccessibility" in text:
            continue
        if entry.get("call") == "focusedWindow" and entry.get("result") is None and entry.get("t", 0) - after > 1:
            continue
        print(f'  +{entry.get("t", 0) - after:6.2f}  {text[:170]}')
PYTHON
exit 0
