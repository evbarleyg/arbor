#!/bin/bash
# Arbor starts, and macOS says late who has the keyboard (collab/BOARD.md, 1.29's rest). With real windows, a real key and a launcher that goes away:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-late-report.sh
#
# A docked window has the keyboard and is a tile when everything shows. Named in time it is let be where it stands. Named late (whatever started
# Arbor is still in front and gives the keyboard back a moment later) it has gone to the corner by then: within the start's first second, with no click and
# no modifier key since, it is put back at the frame the start found, in one request, and let be. Nobody else moves, and the view stays on everything.
#
# Five starts with the keyboard in that window. Then five with an app in front that Arbor does not look at (keys.swift, clicked before the start) and
# that ends as soon as Arbor's log says "started": macOS then gives the keyboard back to the app from before, and nobody has touched anything.
#
# It also WRITES DOWN what nobody had measured: how long after "started" Arbor hears who has the keyboard. Those lines begin with "late:".
#
# Arbor is started as the other scripts start it, not through Launch Services: a bundle opened that way has no Accessibility permission on these Macs.
#
# Only on GitHub's Macs: it types plain letters, which land in whatever has the keyboard if Arbor has a fault here.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "type plain letters, which land in whichever app has the keyboard"

ARBOR_TEST_WINDOWS_ARGS="--regular"
KEYS="$ARBOR_ROOT/.build/mac-shell/keys"
KEYS_APP="$ARBOR_ROOT/.build/mac-shell/ArborKeys.app"
KEYS_ID=dev.arbor.test.keys
KEYS_LOG="$ARBOR_OUT/keys.log"
KEYS_PID=""

witness_in_front() { [ "$("$KEYS" frontmost)" = "$KEYS_ID" ]; }
keys_ready() { grep -q "ready pid=$KEYS_PID " "$KEYS_LOG" 2>/dev/null; }
witness_window() { "$ARBOR_POINTER" windows --pid "$KEYS_PID" | awk '$3 == 0 && $8 == "on" { print $1, int($4), int($5), int($6), int($7); exit }'; }
starts() { grep -c "INFO  started:" "$ARBOR_HOME/arbor.log" 2>/dev/null; }
# What the log holds since the last start.
since_the_start() { awk '/INFO  started:/ { kept = "" } { kept = kept $0 "\n" } END { printf "%s", kept }' "$ARBOR_HOME/arbor.log"; }
said() { since_the_start | grep -c "$1"; }
said_once() { [ "$(said "$1")" = 1 ]; }
never_said() { [ "$(said "$1")" = 0 ]; }

# types <id> "<when>": a plain x gets to that window.
types() {
  local before
  before=$(events_of "$1" key)
  key x
  check "$2: an x reaches it" eventually received "$1" key -gt "$before"
}

# ends_the_launcher <starts so far>: as soon as the log has one more.
ends_the_launcher() {
  local tries=0
  while [ "$(starts)" -le "$1" ] && [ "$tries" -lt 1000 ]; do
    sleep 0.02
    tries=$((tries + 1))
  done
  kill -TERM "$KEYS_PID" 2>/dev/null
}

# round <number> <in-time|late>
round() {
  local found so_far launcher
  arbor_quit
  sleep 1
  click_window "$W1"
  types "$W1" "before the start"
  found=$(real_frame_of "$W1")
  if [ "$2" = late ]; then
    rm -f "$KEYS_LOG"
    "$KEYS_APP/Contents/MacOS/keys" app "$KEYS_LOG" 740 540 260 160 9>&- &
    KEYS_PID=$!
    started "$KEYS_PID"
    eventually keys_ready || die "the key-logging app did not start"
    read -r launcher _ <<< "$(witness_window)"
    [ -n "${launcher:-}" ] || die "the key-logging app shows no window"
    click_window "$launcher"
    check "the launcher is in front" eventually witness_in_front
    sleep 1.5  # so that the click is older than anything the start may take for a switch
  fi
  so_far=$(starts)
  if [ "$2" = late ]; then ends_the_launcher "$so_far" 3>&- 7>&- 8>&- 9>&- & fi
  arbor_relaunch
  sleep 2.5
  echo "late: round $1 ($2): the log since the start, about the keyboard and window $W1:"
  since_the_start | grep -E "started:|focus is on|has the keyboard|let be|back from|w$W1 " | head -n 30 | sed 's/^/late:   /'
  # shellcheck disable=SC2086
  check "it is where the start found it" eventually frame_is "$W1" $found
  check "it is in view" in_view "$W1"
  check "it is still a tile" tile_is "$W1" window
  check "the view is on everything" camera_on root
  check "its neighbour is in its place" in_slot "$W2"
  check "the test windows' app is in front" eventually front_is "$ARBOR_WINDOWS_PID"
  types "$W1" "after the start"
  if [ "$2" = late ]; then
    check "the report came late, and it was put back once" said_once "which macOS says only now"
  else
    check "it was named in time" never_said "which macOS says only now"
  fi
  shot "round-$1-$2"
}

arbor_build
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/keys.swift" -o "$KEYS" > "$ARBOR_OUT/build-keys.log" 2>&1 || {
  cat "$ARBOR_OUT/build-keys.log"
  die "scripts/mac-shell/keys.swift did not compile"
}
rm -rf "$KEYS_APP"
mkdir -p "$KEYS_APP/Contents/MacOS"
cp "$KEYS" "$KEYS_APP/Contents/MacOS/keys"
cat > "$KEYS_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$KEYS_ID</string>
  <key>CFBundleExecutable</key><string>keys</string>
  <key>CFBundleName</key><string>ArborKeys</string>
  <key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
at_exit 'kill_started $KEYS_PID; rm -rf "$KEYS_APP"'

step "[1 | Desktop | 2], window 1 squeezed until it is a tile, and no room is made for it"
arbor_settings '{"makeRoom": false}'
arbor_start 2
ctl dock "$W1" left
ctl dock "$W2" right
sleep 3  # a regular app joining the Dock resizes it, and with it every slot
ctl resize "$W1" right -250
sleep 1
check "window 1 is a tile" eventually tile_is "$W1" window
summary
shot 0-the-tile

for number in 1 2 3 4 5; do
  claim "a start with the keyboard in the window that would be a tile lets it be ($number of 5)"
  round "$number" in-time
done
for number in 6 7 8 9 10; do
  claim "a launcher gives the keyboard back just after the start: the window is put back and let be ($((number - 5)) of 5)"
  round "$number" late
done
arbor_stop quit
