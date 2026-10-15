#!/bin/bash
# F58 (hold the view) on a real Mac: docs/features/F58-hold-the-view.md.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-F58.sh
#
# Two kinds of question. What does somebody watching a shared screen, or choosing a window to share, see of windows
# that are out of view? (Parts 1 and 2 measure; most of it is not a check.) And does a held view stay put when real
# apps come forward, real keys are pressed and real windows are dragged, minimized and restored? (Parts 3 to 5.)
#
# Two processes with test windows, both ordinary apps that ⌘Tab can reach: W1 W2 W3 and X1 X2.
#
# On somebody's own Mac it touches only its test windows, the pointer and the keyboard focus. There the harness leaves out
# the grey wallpaper, the virtual display and every picture of the whole screen (ARBOR_SHOTS=1 takes those), and with the
# pictures the measuring in parts 1 and 2; everything that is a check still runs. Quit your own Arbor first: both would take ⌃⌥.
ARBOR_SHORTCUTS=all  # it presses keys of the whole map, of which nine ship
source "$(dirname "$0")/lib.sh"

arbor_build
for tool in axtool share-probe; do
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/$tool.swift" -o "$ARBOR_ROOT/.build/mac-shell/$tool" \
    > "$ARBOR_OUT/build-$tool.log" 2>&1 || { cat "$ARBOR_OUT/build-$tool.log"; die "scripts/mac-shell/$tool.swift did not compile"; }
done
ax() {
  echo "> axtool $*"
  "$ARBOR_ROOT/.build/mac-shell/axtool" "$@"
}
probe() {
  echo "> share-probe $*"
  # It waits for ScreenCaptureKit for ten seconds at most itself; this is for whatever else could keep it.
  limit 20 "$ARBOR_ROOT/.build/mac-shell/share-probe" "$@"
}
not() { ! "$@"; }
LOG_MARK=0
log_since() {
  tail -n "+$((LOG_MARK + 1))" "$ARBOR_HOME/arbor.log" | cut -c 26- | grep -E "${2:-.}" | tail -n "${1:-25}"
  LOG_MARK=$(wc -l < "$ARBOR_HOME/arbor.log")
}
# The first line of the summary: the display, its view and whether Back has somewhere to go.
# Where the view is, without what macOS leaves of the display: four windows minimized into the Dock made it five points lower at the first run on a Mac, and
# two checks took that for a view that had moved.
view() { summary | head -n 1 | sed 's/, visible [^,]*//'; }
view_is() { [ "$(view)" = "$1" ]; }
status_says() { "$ARBOR_BIN/arborctl" status | grep -q "$1"; }
# Away from the edges, and in the same place in every picture that is compared with another.
rest_pointer() { move 500 420; }
# edges <picture> <reference> <top> <bottom> <lines>: nothing where the pictures were not taken. Rows and columns are
# the picture's pixels, which are points only on a display of scale 1, like the runner's.
edges() {
  if [ -s "$ARBOR_OUT/$1.png" ] && [ -s "$ARBOR_OUT/$2.png" ]; then
    probe edges "$ARBOR_OUT/$1.png" "$ARBOR_OUT/$2.png" 60 "$3" "$4" | tail -n "$5"
  else
    echo "  not measured: no pictures"
  fi
}
# as_seen <id>: what the window server says of a window
as_seen() {
  echo "  window $1: window server $(real_frame_of "$1"), share on a display $(pointer visible "$1"), $(pointer windows | awk -v id="$1" '$1 == id { print "on-screen list: " $8 }')"
}

# look_on <name> <seconds>: from now on, in the background, a picture of the main display about twice a second and, as fast as the tool answers, how much of each window
# that is out of view lies on a display. looked_on waits for both and says what they saw; WATCHED is the most of a window that lay on a display.
# In the background, because display_add is seconds at work. At the first run on a Mac the script slept while the displays changed, and only the trace told
# that macOS had put all four in plain view for almost two seconds. The share is the window server's frame against the displays: whether something covered it, the pictures tell.
look_on() {
  local until=$((SECONDS + $2)) began
  LOOK=$1
  began=$(arbor_now)
  (
    while [ "$SECONDS" -lt "$until" ]; do
      line=""
      for id in "$W2" "$W3" "$X1" "$X2"; do line="$line $id:$("$ARBOR_POINTER" visible "$id" 2>/dev/null)"; done
      echo "$(echo "$(arbor_now) - $began" | bc) s$line"
    done > "$ARBOR_OUT/$LOOK-shares.txt"
  ) 9>&- 8>&- &
  LOOK_SHARES_PID=$!
  (
    round=1
    while [ "$SECONDS" -lt "$until" ]; do
      shot "$LOOK-$round"
      round=$((round + 1))
      sleep 0.3
    done > "$ARBOR_OUT/$LOOK-shots.txt" 2>&1
  ) 9>&- 8>&- &
  LOOK_SHOTS_PID=$!
}
looked_on() {
  local looks unanswered first last
  check "$LOOK: both lookers came to an end" ended "$LOOK_SHARES_PID" 200
  ended "$LOOK_SHOTS_PID" 200 || kill "$LOOK_SHOTS_PID" 2>/dev/null
  read -r looks unanswered WATCHED first last <<< "$(awk '
    { shown = 0
      for (i = 3; i <= NF; i++) {
        split($i, part, ":")
        if (part[2] !~ /^[0-9.]+$/) { unanswered++; continue }
        if (part[2] + 0 > most) most = part[2] + 0
        if (part[2] + 0 > 0.02) shown = 1
      }
      if (shown) { if (first == "") first = $1; last = $1 }
    }
    END { print NR + 0, unanswered + 0, most + 0, (first == "" ? "-" : first), (last == "" ? "-" : last) }' "$ARBOR_OUT/$LOOK-shares.txt")"
  echo "$LOOK: $looks looks, $(grep -c "^shot:" "$ARBOR_OUT/$LOOK-shots.txt") pictures; the most of a window on a display: $WATCHED; from $first s to $last s"
  awk '{ for (i = 3; i <= NF; i++) { split($i, part, ":"); if (part[2] + 0 > 0.02) { print "  " $0; next } } }' "$ARBOR_OUT/$LOOK-shares.txt" | sed -n '1,3p;$p'
  check "$LOOK: there were looks, and each got an answer" test "$looks" -ge 5 -a "$unanswered" -eq 0
}
hardly() { [ "$(echo "$1" | awk '{ print ($1 <= 0.02) ? "yes" : "no" }')" = yes ]; }

# Mid grey shows both what is darker than the wallpaper (shadows) and what is lighter (title bars).
wallpaper '#808080'
sleep 1

step "1. where macOS lets a window be put, and what shows there (no Arbor)"
mkfifo "$ARBOR_SESSION_DIR/stdin0"
"$ARBOR_BIN/ArborTestWindows" --count 1 < "$ARBOR_SESSION_DIR/stdin0" > "$ARBOR_SESSION_DIR/hello0" 2>> "$ARBOR_OUT/test-windows.log" &
started "$!"
exec 7> "$ARBOR_SESSION_DIR/stdin0"
sleep 2
P0=$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["pid"])' "$(head -n 1 "$ARBOR_SESSION_DIR/hello0")") || die "no test window"
Y1=$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["windows"][0])' "$(head -n 1 "$ARBOR_SESSION_DIR/hello0")")
pointer displays
# The main display's size in points, and the test window's.
read -r _ _ _ DW DH _ <<< "$(pointer displays | head -n 1)"
read -r _ _ YW _ <<< "$(real_frame_of "$Y1")"
echo "display $DW x $DH, window $YW wide"
rest_pointer
probe place "$P0" "$Y1" 200 200
shot spot-reference
# try_spot <name> <x> <y>
try_spot() {
  echo "-- $1"
  probe place "$P0" "$Y1" "$2" "$3"
  sleep 0.3
  as_seen "$Y1"
  shot "spot-$1"
  edges "spot-$1" spot-reference 0 100000 8
  probe place "$P0" "$Y1" 200 200
  sleep 0.2
  echo "  and back: $(real_frame_of "$Y1")"
}
try_spot "today-1-point-right" "$((DW - 1))" "$((DH - 1))"
try_spot "0-points-right" "$DW" "$((DH - 1))"
try_spot "40-beyond-right" "$((DW + 40))" "$((DH - 1))"
try_spot "far-beyond" "$((DW * 3))" "$((DH * 3))"
try_spot "today-1-point-left" "$((1 - YW))" "$((DH - 1))"
try_spot "0-points-left" "$((0 - YW))" "$((DH - 1))"
try_spot "below-the-bottom" 200 "$((DH - 1))"
exec 7>&-
sleep 1

step "a second process with two windows"
mkfifo "$ARBOR_SESSION_DIR/stdin2"
"$ARBOR_BIN/ArborTestWindows" --count 2 --regular < "$ARBOR_SESSION_DIR/stdin2" > "$ARBOR_SESSION_DIR/hello2" 2>> "$ARBOR_OUT/test-windows.log" &
SECOND=$!
started "$SECOND"
# However the script ends, and whatever has become of its standard input by then.
at_exit "kill_started $SECOND"
exec 8> "$ARBOR_SESSION_DIR/stdin2"
sleep 2
hello2=$(head -n 1 "$ARBOR_SESSION_DIR/hello2")
P2=$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["pid"])' "$hello2") || die "no second process: $hello2"
read -r X1 X2 <<< "$(python3 -c 'import json, sys; print(*json.loads(sys.argv[1])["windows"])' "$hello2")"
echo "second process $P2 with windows $X1 $X2"
# arbor_start limits Arbor to the process it launches, and to these.
ARBOR_EXTRA_PIDS=$P2
ARBOR_TEST_WINDOWS_ARGS="--regular"
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
P1=$ARBOR_WINDOWS_PID
check "Arbor manages the second process's windows too" eventually is managed "$X1"
# Two apps have just joined the Dock, which changes the visible frame for a second or so.
sleep 3

ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W2" bottom
ctl dock "$X1" beside "$W1" bottom
# shellcheck disable=SC2046
click $(titlebar_of "$W1")
check "the click gave W1 the keyboard" eventually is focused "$W1"
ctl zoom "$W1"
for id in "$W2" "$W3" "$X1" "$X2"; do check "window $id is out of view" eventually is parked "$id"; done
summary

step "2. what a share of the whole screen shows of four windows that are out of view"
ctl hold
check "the view is held" sh -c "'$ARBOR_BIN/arborctl' status | grep -q 'the view is held'"
HELD=$(view)
rest_pointer
shot share-four-out-of-view
for id in "$W2" "$W3" "$X1" "$X2"; do as_seen "$id"; done
read -r _ vy _ vh <<< "$(screen_of 1)"

step "2b. what the pickers of Zoom, Meet and Teams are told, and what sharing one window that is out of view sends"
# Without Screen Recording all of these raise macOS's dialog, which stays on the screen of whoever owns the Mac.
if on_throwaway_mac || [ "$(pointer screen-access)" = true ]; then
probe shareable "$W1" "$W2" "$W3" "$X1" "$X2"
# At the first run on a Mac the tool fell over at both, nothing went red, and the two pictures were missing.
check "ScreenCaptureKit gives a picture of a window that is out of view" probe capture "$W2" "$ARBOR_OUT/share-one-window-out-of-view.png"
probe colours "$ARBOR_OUT/share-one-window-out-of-view.png"
check "and of the one in view" probe capture "$W1" "$ARBOR_OUT/share-one-window-in-view.png"
probe colours "$ARBOR_OUT/share-one-window-in-view.png"
look share-one-window-the-old-way "$X2"
probe colours "$ARBOR_OUT/share-one-window-the-old-way.png"
else
  echo "left out: no Screen Recording permission"
fi

step "3. held: windows out of view are minimized and restored (the reference picture for part 2)"
log_since 0 > /dev/null
for id in "$W2" "$W3"; do ax set "$P1" "$id" AXMinimized yes; done
for id in "$X1" "$X2"; do ax set "$P2" "$id" AXMinimized yes; done
sleep 2
rest_pointer
shot share-reference-none-out-of-view
check "the view did not move" view_is "$HELD"
echo "above the Dock:"
edges share-four-out-of-view share-reference-none-out-of-view "$vy" "$((vy + vh))" 12
echo "the whole height:"
edges share-four-out-of-view share-reference-none-out-of-view 0 100000 4
# A restored window takes the keyboard and comes back where it was: in the corner.
ax set "$P2" "$X1" AXMinimized no &
film held-restore 6
sleep 1.5
check "restored, X1 is out of view again" eventually is parked "$X1"
check "and W1 has the keyboard back" eventually is focused "$W1"
check "the view did not move" view_is "$HELD"
ax set "$P2" "$X2" AXMinimized no
for id in "$W2" "$W3"; do ax set "$P1" "$id" AXMinimized no; sleep 0.6; done
sleep 1.5
for id in "$W2" "$W3" "$X1" "$X2"; do check "window $id is out of view" eventually is parked "$id"; done
check "W1 has the keyboard" eventually is focused "$W1"
check "the view did not move" view_is "$HELD"
check "W1 is where it was" is in_slot "$W1"
log_since 40 "hold|keyboard"

step "3b. held: another app comes forward by itself"
log_since 0 > /dev/null
ax activate "$P2" &
film held-comes-forward 8
sleep 1
ax front
check "its windows stay out of view" is parked "$X1"
check "both of them" is parked "$X2"
check "W1 has the keyboard back" eventually is focused "$W1"
check "the view did not move" view_is "$HELD"
log_since 30 "hold|keyboard"
shot held-after-comes-forward

step "3c. held: ⌘Tab to it is turned away as well"
# ⌘Tab goes to the app used before. That is the second test app only if `ax activate` was obeyed, which macOS 14 and later
# often refuse a tool in the background; otherwise an app of whoever owns the Mac would come forward.
if on_throwaway_mac; then
  log_since 0 > /dev/null
  key cmd+tab
  sleep 1.2
  ax front
  check "its windows stay out of view" is parked "$X1"
  check "W1 has the keyboard back" eventually is focused "$W1"
  check "the view did not move" view_is "$HELD"
  log_since 30 "hold|keyboard"
else
  echo "left out on a person's own Mac"
fi

step "3d. held: keys and drags that would move the view"
for chord in ctrl+opt+space ctrl+opt+up ctrl+opt+right ctrl+opt+0 ctrl+opt+d; do
  # A key that was declined (⌃⌥Space always is where several input sources are on) proves nothing by changing nothing.
  key "$chord" || { check "$chord could be pressed" false; continue; }
  sleep 0.3
  check "$chord changes nothing" view_is "$HELD"
done
check "W1 is where it was" is in_slot "$W1"
# To the left screen edge, where it would dock beside everything else.
# shellcheck disable=SC2046
drag $(titlebar_of "$W1") 3 400 --no-release
shot held-drag-no-preview
check "no drop preview promises what will not happen" not has_overlay 3
release
check "dropped, it goes back to its place" eventually is in_slot "$W1"
check "the view did not move" view_is "$HELD"
for id in "$W2" "$W3" "$X1" "$X2"; do check "window $id is still out of view" is parked "$id"; done

step "3e. held: the three things that showed an audience everything (found on review)"
if key ctrl+opt+shift+f; then
  sleep 0.5
  check "⌃⌥⇧F floats nothing" view_is "$HELD"
else
  check "⌃⌥⇧F could be pressed" false
fi
for id in "$W2" "$W3" "$X1" "$X2"; do check "window $id is still out of view" is parked "$id"; done
# ⌘M on the window being shown.
ax set "$P1" "$W1" AXMinimized yes
sleep 1.5
shot held-and-empty
# Or the checks that follow are about a view that was never empty. So it was at the first run on a Mac: macOS reported the app's next window as focused half a
# second before it reported the minimizing, Arbor sent the keyboard back to W1, and that fetched W1 out of the Dock.
check "W1 stays in the Dock" fails is on_screen "$W1"
check "the view is still held" status_says "the view is held"
for id in "$W2" "$W3" "$X1" "$X2"; do check "with W1 minimized, window $id is still out of view" is parked "$id"; done
ax set "$P1" "$W1" AXMinimized no
check "restored, W1 is where it was" eventually is in_slot "$W1"
check "the view did not move" view_is "$HELD"
# ⌃⌥⎋, kept down. Whether macOS repeats a hot key that stays down is what the log says afterwards.
log_since 0 > /dev/null
key ctrl+opt+escape --down
sleep 0.5
# A key-down that is posted does not repeat by itself as a key under a finger does.
key ctrl+opt+escape --repeat 60
sleep 0.7
check "⌃⌥⎋ released the hold" not status_says "the view is held"
check "kept down for three seconds, it did not go on to pause" not status_says "^paused"
key ctrl+opt+escape --up
for id in "$W2" "$W3" "$X1" "$X2"; do check "released, window $id is still out of view" is parked "$id"; done
log_since 30 "hold|pause"
ctl hold
check "held again" status_says "the view is held"

step "3f. the lock in the menu bar, and the menu"
shot held-menu-bar
# shellcheck disable=SC2046
rightclick $(status_item)
sleep 0.5
shot held-menu
key escape
sleep 0.3

step "4. release, then hold still"
ctl release
key ctrl+opt+space
check "released, ⌃⌥Space shows everything" eventually is on_screen "$W2"
# shellcheck disable=SC2046
click $(titlebar_of "$W1")
check "the click gave W1 the keyboard" eventually is focused "$W1"
ctl zoom "$W1"
check "framed again" eventually is parked "$X1"
ctl hold still
shot still-menu-bar
STILL=$(view)
log_since 0 > /dev/null
sleep 1
ax activate "$P2"
sleep 1.2
check "an app that comes forward by itself stays out of view" is parked "$X1"
check "W1 has the keyboard back" eventually is focused "$W1"
check "the view did not move" view_is "$STILL"
log_since 30 "hold|keyboard"
key ctrl+opt+up
check "the user's own keys move the view" eventually not view_is "$STILL"
ctl zoom "$W1"
check "framed again" eventually is parked "$X1"
sleep 1
# As in 3c.
if on_throwaway_mac; then
  log_since 0 > /dev/null
  key cmd+tab
  sleep 1.2
  ax front
  log_since 30 "hold|keyboard"
  if is parked "$X1" && is parked "$X2"; then
    echo "note: ⌘Tab was taken for the app's own doing; see the seconds in the log lines above"
    check "the view follows ⌘Tab while holding still" false
  else
    check "the view follows ⌘Tab while holding still" true
  fi
else
  echo "left out on a person's own Mac"
fi
summary
ctl release

step "5. a second display to the right: where do windows go that are out of view, and what does each display show?"
# First everything into view: W1 may be out of view by now, and a click where its title bar is then is a click off the display.
ctl show-all
# shellcheck disable=SC2046
click $(titlebar_of "$W1")
ctl zoom "$W1"
check "framed" eventually is parked "$X1"
ctl hold
look_on display-comes 9
if display_add 1280 720 right; then
  looked_on
  check "held, nothing that is out of view lay on a display while one came (the most: $WATCHED of a window)" hardly "$WATCHED"
  summary
  pointer displays
  for id in "$W2" "$W3" "$X1" "$X2"; do as_seen "$id"; done
  check "still held" sh -c "'$ARBOR_BIN/arborctl' status | grep -q 'the view is held'"
  for id in "$W2" "$W3" "$X1" "$X2"; do check "window $id is out of view" is parked "$id"; done
  rest_pointer
  shot two-displays
  panorama two-displays-panorama

  # On GitHub's Macs the first virtual display also changes the size of the main one, so that two changes are mixed above. A further one may not.
  step "5b. held, with two displays: a third comes and goes"
  main_display() { pointer displays | awk '$2 == 0 && $3 == 0 { print $4, $5 }'; }
  main_before=$(main_display)
  look_on third-display-comes 6
  "$ARBOR_VDISPLAY" add 1280 720 "Arbor Test Display 3" --serial 3 > "$ARBOR_OUT/third-display.txt" 2>> "$ARBOR_OUT/vdisplay.log" 9>&- 8>&- 3>&- &
  THIRD_PID=$!
  started "$THIRD_PID"
  at_exit 'kill_started $THIRD_PID'
  looked_on
  pointer displays
  check "there are three displays" test "$(pointer displays | grep -c .)" -eq 3
  check "the main display kept its size ($main_before)" test "$(main_display)" = "$main_before"
  check "held, nothing that is out of view lay on a display while the third came (the most: $WATCHED of a window)" hardly "$WATCHED"
  check "still held" status_says "the view is held"
  look_on third-display-goes 6
  kill -TERM "$THIRD_PID" 2>/dev/null
  wait "$THIRD_PID" 2>/dev/null
  looked_on
  check "the main display kept its size ($main_before)" test "$(main_display)" = "$main_before"
  check "nor while it went (the most: $WATCHED of a window)" hardly "$WATCHED"

  step "5c. held: the second display goes, and the main one changes its size again"
  look_on display-goes 6
  display_remove
  looked_on
  check "held, nothing that is out of view lay on a display meanwhile (the most: $WATCHED of a window)" hardly "$WATCHED"
  summary
  for id in "$W2" "$W3" "$X1" "$X2"; do check "window $id is out of view" eventually is parked "$id"; done
else
  looked_on
fi

step "6. quitting while held brings every window back"
arbor_stop after-quit
for id in "$X1" "$X2"; do check "window $id is back on screen after quitting" eventually is on_screen "$id"; done
exec 8>&-
