#!/bin/bash
# Does the Mac's input survive when Arbor loses the Accessibility permission with its event taps installed?
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-permission-loss.sh      (about three minutes)
#
# macOS holds every event a tap has asked for until the tap's owner answers, and has been reported to stop all input when that owner
# loses the permission. check-F63.sh and input-taps.sh take the permission from everything, their own tools included, so neither can
# press anything afterwards. Here Arbor is a bundle under an identifier of its own, opened by Launch Services, so that it
# answers for its own permission: that one entry is given and taken, and this script's tools keep theirs.
#
# Each round: the entry is written, Arbor is opened and has its taps; asker.swift posts a click, a key and a notch of the wheel every
# 50 ms, each with a number, for twelve seconds; four seconds in, the permission goes; a listener at the far end of the taps writes down
# what arrived and when. Three rounds with `tccutil reset Accessibility <identifier>`, two with the entry deleted and tccd restarted, which a running
# process feels only a quarter of a minute later: meanwhile Arbor keeps its taps and is told yes. Those rounds' streams last until then. And two with
# the notification com.apple.accessibility.api posted after that, which is probably what the switch in System Settings comes to.
# What is asked: every event arrives; none is more than 10 ms late once the taps are gone; and THE NUMBER: the longest hole.
#
# The controls: the same deed and the same stream with nobody running, and with an Arbor that has no taps (ARBOR_NO_HOTKEYS=1).
#
# A round in which nothing could be posted, nothing arrived before the loss, Arbor had no taps or did not lose them proves nothing: it
# says INVALID and fails. arrivals-<n>.txt and stream-<n>.txt are the raw lists.
#
# What it does not try: a pinch (nothing public posts one), and a scroll with ⌃⌥ down, which is the only time the scroll tap is switched
# on. The clicks go through the tap on mouse-downs, which is always on. Arbor runs with ARBOR_NO_PROMPT=1: no window of its own, and no
# question of macOS's, comes between the clicks and the test window.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "write to the permission database with sudo, restart tccd and reset a bundle's Accessibility permission"

BUNDLE_ID=com.evbarleyg.arbor.probe-permission-loss
TCC="/Library/Application Support/com.apple.TCC/TCC.db"
ASKER="$ARBOR_ROOT/.build/mac-shell/asker"
WITNESS="$ARBOR_ROOT/.build/mac-shell/witness"

tcc() { sudo sqlite3 "$TCC" "$1"; }
status_starts() { case "$("$ARBOR_BIN/arborctl" status 2>&1)" in "$1"*) return 0 ;; *) return 1 ;; esac; }
arbor_taps() { "$WITNESS" taps | grep "pid=$ARBOR_PID "; }
has_taps() { [ "$(arbor_taps | wc -l)" -ge 3 ]; }
no_taps() { [ "$(arbor_taps | wc -l)" -eq 0 ]; }
gone() { ! kill -0 "$1" 2>/dev/null; }
invalid() { echo "INVALID: $1"; check "round $round is valid: $1" false; }

arbor_build
for tool in asker witness; do
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/$tool.swift" -o "$ARBOR_ROOT/.build/mac-shell/$tool" \
    > "$ARBOR_OUT/build-$tool.log" 2>&1 || { cat "$ARBOR_OUT/build-$tool.log"; die "scripts/mac-shell/$tool.swift did not compile"; }
done
tcc "SELECT count(*) FROM access;" > /dev/null 2>&1 || die "the permission database cannot be read here"
echo "the tools' own permission: $(pointer ax-access)"
[ "$(pointer ax-access)" = true ] || die "INVALID: this script's own tools have no Accessibility permission, so nothing can be posted"

step "the bundle"
# The test windows come with a session; its Arbor, a child of this shell that shares the shell's permission, makes way for the bundle.
arbor_start 2
"$ARBOR_BIN/arborctl" quit > /dev/null
ended "$ARBOR_PID" || die "the session's own Arbor did not quit"
ARBOR_PID=""
# Not in the session's folder: tccutil finds a bundle by its identifier in Launch Services' list, and of one under /tmp it says "No such bundle identifier",
# as the user and as root, registered or not.
app="$HOME/Applications/ArborProbePermissionLoss.app"
at_exit 'rm -rf "${app:?}"'
rm -rf "${app:?}"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$ARBOR_BIN/Arbor" "$app/Contents/MacOS/Arbor"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" -c "Delete :CFBundleURLTypes" "$app/Contents/Info.plist" \
  || die "could not edit Info.plist"
codesign --force --sign - --identifier "$BUNDLE_ID" "$app" || die "codesign failed"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app" || echo "lsregister could not register the bundle"
codesign --display --requirements - "$app" 2>/dev/null | sed -n 's/^\(# \)\{0,1\}designated => //p' | tee "$ARBOR_SESSION_DIR/requirement.txt"
csreq -r "$ARBOR_SESSION_DIR/requirement.txt" -b "$ARBOR_SESSION_DIR/requirement.bin" || die "csreq could not read the bundle's requirement"
REQUIREMENT="X'$(xxd -p "$ARBOR_SESSION_DIR/requirement.bin" | tr -d '\n')'"
at_exit "tcc \"DELETE FROM access WHERE client = '$BUNDLE_ID';\""
rows() { tcc "SELECT client, auth_value FROM access WHERE service = 'kTCCServiceAccessibility' AND client = '$BUNDLE_ID';"; }

# What the switch in System Settings records. A new process asks the daemon, which answers from memory, so it is restarted.
grant() {
  tcc "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, indirect_object_identifier, flags, last_modified) VALUES ('kTCCServiceAccessibility', '$BUNDLE_ID', 0, 2, 3, 1, $REQUIREMENT, 'UNUSED', 0, strftime('%s', 'now'));" \
    || die "INVALID: the grant could not be written"
  sudo killall -9 tccd 2>/dev/null
  sleep 1
}
launch() {
  limit 20 open -n "$app" --env ARBOR_HOME="$ARBOR_HOME" --env ARBOR_SOCKET="$ARBOR_SOCKET" --env ARBOR_DEBUG=1 \
    --env ARBOR_ONLY_PIDS="$ARBOR_WINDOWS_PID" --env ARBOR_NO_WATCHDOG=1 --env ARBOR_NO_PICTURES=1 --env ARBOR_NO_PROMPT=1 \
    --env ARBOR_NO_STATUS_ITEM=1 --env ARBOR_NO_HOTKEYS="$1"
  sleep 2
  ARBOR_PID=$(pgrep -f "$app/Contents/MacOS/Arbor" | head -n 1)
  [ -n "$ARBOR_PID" ] || die "INVALID: the bundle did not start"
  started "$ARBOR_PID"
}
leave() {
  [ -n "$ARBOR_PID" ] || return 0
  "$ARBOR_BIN/arborctl" quit > /dev/null 2>&1
  eventually gone "$ARBOR_PID" || kill_started "$ARBOR_PID"
  ARBOR_PID=""
}

by_tccutil() { tccutil reset Accessibility "$BUNDLE_ID" || sudo tccutil reset Accessibility "$BUNDLE_ID"; }
by_the_row() {
  tcc "DELETE FROM access WHERE service = 'kTCCServiceAccessibility' AND client = '$BUNDLE_ID';"
  sudo killall -9 tccd 2>/dev/null
  echo "the entry deleted, tccd restarted"
}

# Probably what the switch in System Settings comes to: a process that is running goes by what it was told last until this notification is posted
# (probe-permission-grant.sh).
by_the_row_announced() {
  by_the_row
  "$ASKER" announce
}

# one_round <number> <how the permission goes> [arbor|arbor-without-taps|nobody]: the last two are the controls. If input stands still without
# Arbor's taps as well, it is not the taps' doing.
one_round() {
  local how=$2 who=${3:-arbor} x y w h log_mark taken back length=12 between
  round=$1
  # By that road the loss came 14 s after the deed: the stream has to last until then.
  [ "$how" = by_the_row ] && length=34
  between="from the loss until the taps were gone"
  [ "$how" = by_the_row ] && between="FROM THE ROW'S DELETION UNTIL ARBOR NOTICED"
  step "round $round: $how, with $who"
  grant
  if [ "$who" != nobody ]; then
    launch "$([ "$who" = arbor ] && echo 0 || echo 1)"
    if ! eventually status_starts running; then
      "$ARBOR_BIN/arborctl" status
      invalid "Arbor has the permission at launch"
      leave
      return
    fi
    echo "Arbor pid $ARBOR_PID, entry: $(rows)"
    if [ "$who" = arbor ]; then
      eventually has_taps || { invalid "Arbor has its event taps"; leave; return; }
      arbor_taps
    else
      no_taps || { invalid "this Arbor has no event taps"; leave; return; }
    fi
  fi
  # The second window is in front. By the window server, which is there whoever runs.
  read -r x y w h <<< "$(real_frame_of "$W2")"
  x=$((${x%.*} + ${w%.*} / 2)) y=$((${y%.*} + ${h%.*} / 2))
  log_mark=$(wc -l < "$ARBOR_HOME/arbor.log")

  "$ASKER" arrivals "$((length + 5))" > "$ARBOR_OUT/arrivals-$round.txt" 2>&1 &
  started $!
  eventually grep -q arrivals-ready "$ARBOR_OUT/arrivals-$round.txt" || { invalid "the listener at the end of the taps started"; leave; return; }
  "$ASKER" stream "$length" 50 "$x" "$y" > "$ARBOR_OUT/stream-$round.txt" 2>&1 &
  stream=$!
  started "$stream"
  sleep 4
  taken=$("$ASKER" now)
  "$how"
  back=$("$ASKER" now)
  echo "the permission was taken between $taken and $back"
  ended "$stream" "$((length * 10 + 30))" || invalid "the stream came to its end"
  sleep 1
  cat "$ARBOR_OUT/stream-$round.txt"
  tail -n "+$((log_mark + 1))" "$ARBOR_HOME/arbor.log" | grep -E "ermission|event tap|stopped|ERROR" | cut -c 12-220 | tail -n 8
  echo "the tools' own permission afterwards: $(pointer ax-access)"
  removed=""
  if [ "$who" != nobody ]; then
    check "round $round: Arbor has no event tap left" eventually no_taps
    "$ARBOR_BIN/arborctl" status | head -n 1 | cut -c 1-100
    # Whichever noticed first: the taps' own check, or the controller.
    removed=$(tail -n "+$((log_mark + 1))" "$ARBOR_HOME/arbor.log" | grep -m 1 -E "permission is gone|permission was taken away" | cut -c 12-23)
    [ -n "$removed" ] || invalid "Arbor's log says when it noticed"
  fi

  python3 - "$ARBOR_OUT/arrivals-$round.txt" "$ARBOR_OUT/stream-$round.txt" "$taken" "${removed:-$back}" "$between" > "$ARBOR_SESSION_DIR/verdict" <<'PYTHON'
import re, sys

def seconds(text):
    hours, minutes, rest = text.split(":")
    return int(hours) * 3600 + int(minutes) * 60 + float(rest)

arrivals, stream, taken, removed, between = sys.argv[1:6]
taken, removed = seconds(taken), seconds(removed)
posted = re.search(r"stream ends: (\d+) events posted", open(stream).read())
posted = int(posted.group(1)) if posted else 0
found = []
for line in open(arrivals):
    match = re.match(r"(\S+) (\S+) n=(\d+) late_us=(-?\d+)", line)
    if match:
        found.append((seconds(match.group(1)), match.group(2), int(match.group(3)), int(match.group(4))))
numbers = {entry[2] for entry in found}
missing = [number for number in range(1, posted + 1) if number not in numbers]
kinds = ["down", "up", "key-down", "key-up", "wheel"]
print(f"posted {posted}, arrived {len(numbers)}, missing {len(missing)}" + (f": {missing[:20]}" if missing else ""))
print("arrived by kind: " + ", ".join(f"{kind} {sum(1 for entry in found if entry[1] == kind)}" for kind in kinds))
spans = [("before the loss", float("-inf"), taken), (between, taken, removed), ("after the taps were gone", removed, float("inf"))]
worst = {}
for name, start, end in spans:
    part = [entry for entry in found if start <= entry[0] < end]
    holes = [(later[0] - earlier[0], earlier[0]) for earlier, later in zip(found, found[1:]) if start <= earlier[0] < end]
    hole = max(holes) if holes else (0, 0)
    late = max((entry[3] for entry in part), default=0)
    over = sum(1 for entry in part if entry[3] > 10000)
    worst[name] = (len(part), hole[0], late, over)
    # Every event has its number, so what was posted from the first of a stretch up to the first of the next is known: what is lost at a seam counts for the stretch it ends.
    later = [entry[2] for entry in found if entry[0] >= end]
    due = (min(later) if later else posted + 1) - min(entry[2] for entry in part) if part else 0
    print(f"{name}: {len(part)} arrived of {due} posted, longest hole {hole[0] * 1000:.0f} ms, worst lateness {late / 1000:.1f} ms, more than 10 ms late: {over}")
def stamp(time):
    return f"{int(time // 3600):02d}:{int(time % 3600 // 60):02d}:{time % 60:06.3f}"
for earlier, later in zip(found, found[1:]):
    if later[0] - earlier[0] > 0.15 or later[2] - earlier[2] > 1:
        print(f"  a hole of {(later[0] - earlier[0]) * 1000:.0f} ms from {stamp(earlier[0])} (n={earlier[2]}) to {stamp(later[0])} (n={later[2]}): {later[2] - earlier[2] - 1} events lost in it")
print(f"the taps were gone {(removed - taken) * 1000:.0f} ms after the permission began to go")
holes = [(later[0] - earlier[0], earlier[0]) for earlier, later in zip(found, found[1:])]
print(f"THE LONGEST HOLE: {max(holes)[0] * 1000:.0f} ms" if holes else "THE LONGEST HOLE: nothing arrived")
print("facts", posted, len(missing), worst["before the loss"][0], worst["after the taps were gone"][0], worst["after the taps were gone"][3],
      round(max(holes)[0] * 1000) if holes else 999999, round(worst["before the loss"][2] / 1000), round(worst["after the taps were gone"][2] / 1000),
      round(worst["before the loss"][1] * 1000), round(worst[between][1] * 1000), round(worst["after the taps were gone"][1] * 1000))
PYTHON
  grep -v "^facts " "$ARBOR_SESSION_DIR/verdict"
  read -r _ posted missing before after late hole late_before late_after hole_before hole_during hole_after <<< "$(grep "^facts " "$ARBOR_SESSION_DIR/verdict")"
  [ "${posted:-0}" -ge 500 ] || invalid "the stream posted its events (${posted:-0})"
  [ "${before:-0}" -ge 100 ] || invalid "events arrived before the loss (${before:-0})"
  [ "${after:-0}" -ge 100 ] || invalid "events arrived after the taps were gone (${after:-0})"
  # The rule: three absolutes, and the comparison on the same Mac. A hosted Mac is never quite still: with nothing taken from anybody events have been 85 ms late there.
  check "round $round: NOTHING LOST: every event that was posted arrived (${missing:-?} did not)" test "${missing:-1}" -eq 0
  check "round $round: the hole while the permission went (${hole_during:-?} ms) is no longer than a second" test "${hole_during:-9999}" -le 1000
  check "round $round: no later after the taps were gone (${late_after:-?} ms) than this Mac was before the loss (${late_before:-?} ms), or 10 ms" \
    test "${late_after:-9999}" -le "$((${late_before:-0} > 10 ? ${late_before:-0} : 10))"
  check "round $round: no longer a hole after the taps were gone (${hole_after:-?} ms) than before the loss (${hole_before:-?} ms), or 150 ms" \
    test "${hole_after:-9999}" -le "$((${hole_before:-0} > 150 ? ${hole_before:-0} : 150))"
  # The bars as they first stood, beside it.
  check "round $round: (the first bar) none more than 10 ms late once the taps were gone" test "${late:-1}" -eq 0
  check "round $round: (the first bar) input never stood still for a quarter of a second (${hole:-?} ms)" test "${hole:-999999}" -lt 250
  shot "round-$round-afterwards"
  leave
}

one_round 1 by_the_row
one_round 2 by_the_row nobody
one_round 3 by_the_row arbor-without-taps
one_round 4 by_the_row
one_round 5 by_the_row_announced
one_round 6 by_the_row_announced nobody
one_round 7 by_the_row_announced
one_round 8 by_tccutil
one_round 9 by_tccutil
one_round 10 by_tccutil
one_round 11 by_the_row
one_round 12 by_the_row nobody

step "the end"
arbor_log
arbor_close_windows
