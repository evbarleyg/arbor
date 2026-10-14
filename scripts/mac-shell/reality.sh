#!/bin/bash
# The same steps on a hosted Mac and in a rehearsal, written down after every step so that the two can be compared: `make reality`.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/reality.sh         the real app, real windows, the real pointer and keyboard
#   scripts/mac-shell/rehearse.sh scripts/mac-shell/reality.sh    the real controller on the stand-ins, on Linux
#   scripts/reality-diff.py <the Mac's reality folder> <the rehearsal's>
#
# Thousands of tests pass against the stand-ins, and the serious faults are found on real Macs all the same, because the stand-ins are
# more polite than macOS. This script is the instrument that says where: it checks nothing and expects nothing. It plays journeys,
# each in an Arbor session of its own, and after every step `observe` lets things settle and appends one line of JSON to
# mac-shell/reality/<journey>.jsonl: what Arbor believes, what the window server shows, and what crossed the seam between Arbor and the
# window system since the step before, taken from a trace. reality.py has the form, which names nothing that differs between the worlds for
# no reason (window ids, process ids, times). Every difference that is left is a lie of the stand-ins or a fault of Arbor.
#
# The journeys:
#   commands   what arbor-e2e's first session does over the socket: dock, zoom, back, resize, float, arrange, the gap, the Desktop, quit
#   apps       what windows and apps do by themselves: minimize, restore, hide, unhide, close, open, another app coming forward
#   edges      title-bar drags with the real pointer to the left, top and right screen edge, each looked at while held and after
#   pointer    e2e-drag.sh's steps and a few more: a window's edge, onto another window, a double-click, a press inside, a seam, out onto
#              the Desktop, a click on a tile
#   keys       a click on a window, then shortcuts on the real keyboard
# `reality.sh commands keys` plays only those.
#
# macOS stays as it comes: its own tiling at the screen edges is not switched off, because that is where people live.
#
# A step aims at where the window server has a window, as a person does, not at where Arbor believes it is. A step that waits for something an
# app does (a window gone from the screen, an app in front) waits for what the window server says, for three seconds at most, and goes on.
#
# Only on GitHub's Macs: what it writes down is compared with a rehearsal of their display, and it takes the pointer and the keyboard for minutes.
ARBOR_TIME_LIMIT=1080
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "take the pointer and the keyboard for ten minutes, to write down what means something only on the display a rehearsal has"

REALITY="$ARBOR_OUT/reality"
REALITY_PY="$ARBOR_ROOT/scripts/mac-shell/reality.py"
mkdir -p "$REALITY/traces"
scratch_dir reality REALITY_WORK
# The same wait in both worlds: echoes, put-backs and saves arrive up to a second after the last thing that happened.
REALITY_SETTLE=1
JOURNEY=""
STEP=0
NAMES=""
TRACE=""
PROCESSES=""
OTHER_PID=""
OTHER=""
WANTED=" $* "

wanted() { [ "$WANTED" = "  " ] || case "$WANTED" in *" $1 "*) ;; *) return 1 ;; esac; }
not() { ! "$@"; }

# MARK: Observing

arbor_runs() { [ -n "$ARBOR_PID" ] && kill -0 "$ARBOR_PID" 2>/dev/null; }

# One look at both sides, as a line of JSON.
look_now() {
  "$ARBOR_BIN/arborctl" state > "$REALITY_WORK/state" 2>/dev/null
  pointer windows > "$REALITY_WORK/windows"
  pointer windows --on-screen > "$REALITY_WORK/on-screen"
  pointer keyboard > "$REALITY_WORK/keyboard"
  # shellcheck disable=SC2086
  python3 "$REALITY_PY" look "$REALITY_WORK" "$NAMES" $PROCESSES
}

# observe "<step>": waits, looks until two looks in a row agree (four seconds at most: what has not come to rest by then is written down
# as not settled, and counted apart), marks the place in the trace and writes the line.
observe() {
  local label=$1 tries=0 settled=no before="" now=""
  STEP=$((STEP + 1))
  sleep "$REALITY_SETTLE"
  while [ "$tries" -lt 10 ]; do
    now=$(look_now)
    if [ -n "$now" ] && [ "$now" = "$before" ]; then
      settled=yes
      break
    fi
    before=$now
    tries=$((tries + 1))
    sleep 0.3
  done
  printf '%s\n' "$now" > "$REALITY_WORK/look"
  # Also what writes out the lines a trace holds back during a drag.
  arbor_runs && "$ARBOR_BIN/arborctl" trace note "reality: $label" > /dev/null
  # shellcheck disable=SC2086
  python3 "$REALITY_PY" line "$JOURNEY" "$label" "$STEP" "$settled" "$REALITY_WORK/look" "$NAMES" "$TRACE" $PROCESSES \
    >> "$REALITY/$JOURNEY.jsonl" || die "could not write down $JOURNEY/$label"
  echo "observed $JOURNEY/$label$([ "$settled" = yes ] || echo " (it had not come to rest)")"
}

# journey <name> [count] [NAME=value…]: a session, its windows named W1, W2… (a second app's after the first's), and a trace.
journey() {
  local id number=0
  JOURNEY=$1
  shift
  step "journey: $JOURNEY"
  STEP=0
  NAMES="$REALITY_WORK/$JOURNEY.names"
  : > "$NAMES"
  : > "$REALITY/$JOURNEY.jsonl"
  arbor_start "$@"
  PROCESSES="arbor=$ARBOR_PID test-windows=$ARBOR_WINDOWS_PID${OTHER_PID:+ second-app=$OTHER_PID}"
  for id in $ARBOR_WINDOW_IDS $OTHER; do
    number=$((number + 1))
    echo "$id W$number" >> "$NAMES"
  done
  "$ARBOR_BIN/arborctl" trace on "$JOURNEY" || die "no trace of $JOURNEY"
  TRACE=$(ls "$ARBOR_HOME/traces/"*"-$JOURNEY.jsonl" 2>/dev/null | head -n 1)
  [ -n "$TRACE" ] || die "the trace of $JOURNEY is not where traces go"
  read -r sx sy sw sh <<< "$(arbor_ask screen)"
  [ -n "$sh" ] || die "Arbor does not say how large the display is"
  observe "start"
}

# Quits, looks at where that leaves the windows, and ends the session.
journey_ends() {
  echo "> quit"
  "$ARBOR_BIN/arborctl" quit
  ended "$ARBOR_PID" 50 || echo "Arbor is still running five seconds after quit"
  observe "quit"
  cp "$TRACE" "$REALITY/traces/$JOURNEY.jsonl"
  arbor_stop
}

# does "<step>" <command…>: one step and what came of it.
does() {
  local label=$1
  shift
  "$@"
  observe "$label"
}

# MARK: Where a person would point

# at <window> <x> <y>: a point of the window where the window server has it; the expressions may use x, y, w and h. Prints nothing for a window
# that is gone, and the pointer tool then refuses the step for want of a place.
at() {
  local x y w h
  read -r x y w h <<< "$(real_frame_of "$1" 2>/dev/null)"
  [ -n "$h" ] || return 1
  x=${x%.*} y=${y%.*} w=${w%.*} h=${h%.*}
  echo "$(($2)) $(($3))"
}
title_of() { at "$1" "x + w / 2" "y + 12"; }
middle_of() { at "$1" "x + w / 2" "y + h / 2"; }

shows() { pointer windows --on-screen | awk -v id="$1" '$1 == id { found = 1 } END { exit !found }'; }
in_front() { [ "$(pointer front 2>/dev/null)" = "$1" ]; }
has_windows() { [ "$(pointer windows --pid "$ARBOR_WINDOWS_PID" | wc -l | tr -d ' ')" -ge "$1" ]; }

# tw <command…>: the first test app does something to its own windows (descriptor 9 is its stdin).
tw() {
  echo "> test windows: $*"
  echo "$*" >&9
}

# MARK: The journeys

arbor_build
step "the Mac"
echo "macOS $(sw_vers -productVersion)"
pointer displays
macos_tiling

if wanted commands; then
  journey commands 3
  does "dock W1 left" ctl dock "$W1" left
  does "dock W2 right" ctl dock "$W2" right
  does "dock W3 below W1" ctl dock "$W3" beside "$W1" bottom
  does "zoom W1" ctl zoom "$W1"
  does "back" ctl back
  does "resize W1 right 100" ctl resize "$W1" right 100
  does "float W2" ctl float "$W2"
  does "arrange" ctl arrange
  does "set gap 40" ctl set gap 40
  does "set gap 12" ctl set gap 12
  does "desktop" ctl desktop
  does "show-all" ctl show-all
  does "zoom W3" ctl zoom "$W3"
  journey_ends
fi

if wanted apps; then
  # The second app has to be there before Arbor, which is told whose windows to arrange when it starts.
  mkfifo "$ARBOR_SESSION_DIR/other-stdin"
  "${ARBOR_TEST_WINDOWS_2:-$ARBOR_BIN/ArborTestWindows}" --count 1 < "$ARBOR_SESSION_DIR/other-stdin" > "$ARBOR_SESSION_DIR/other-hello" \
    2>> "$ARBOR_OUT/test-windows.log" 9>&- &
  OTHER_PID=$!
  started "$OTHER_PID"
  exec 8> "$ARBOR_SESSION_DIR/other-stdin"
  said() { [ -s "$ARBOR_SESSION_DIR/other-hello" ]; }
  eventually said || die "the second app did not report its window"
  OTHER=$(python3 -c 'import json, sys; print(json.loads(sys.argv[1])["windows"][0])' "$(head -n 1 "$ARBOR_SESSION_DIR/other-hello")") \
    || die "the second app did not report its window"
  ARBOR_EXTRA_PIDS=$OTHER_PID
  journey apps 3
  ARBOR_EXTRA_PIDS=""
  W4=$OTHER
  does "dock W1 left" ctl dock "$W1" left
  does "dock W2 right" ctl dock "$W2" right

  tw minimize "$W1"
  eventually not shows "$W1"
  observe "the app minimizes docked W1"
  tw restore "$W1"
  eventually shows "$W1"
  observe "the app restores W1"

  tw hide
  eventually not shows "$W2"
  observe "the app hides"
  tw unhide
  eventually shows "$W2"
  observe "the app shows again"

  tw close "$W2"
  eventually not shows "$W2"
  observe "docked W2 closes"
  # Nobody expects it back when Arbor quits.
  ARBOR_WINDOW_IDS="$W1 $W3"

  echo "> test windows: one more window, as ⌘N opens it"
  kill -USR2 "$ARBOR_WINDOWS_PID"
  eventually has_windows 3
  observe "a new window opens"

  echo "> the second app comes forward"
  kill -USR1 "$OTHER_PID"
  eventually in_front "$OTHER_PID"
  observe "the second app comes forward"
  echo "> the first app comes forward"
  kill -USR1 "$ARBOR_WINDOWS_PID"
  eventually in_front "$ARBOR_WINDOWS_PID"
  observe "the first app comes forward"

  does "dock W4 right" ctl dock "$W4" right
  does "zoom W1" ctl zoom "$W1"
  echo "> the second app comes forward, its window out of view"
  kill -USR1 "$OTHER_PID"
  eventually in_front "$OTHER_PID"
  observe "the second app comes forward, its window out of view"
  journey_ends
  exec 8>&-
  kill_started "$OTHER_PID"
  OTHER_PID=""
  OTHER=""
fi

if wanted edges; then
  journey edges 3
  # Three points short of the edge, as the other scripts stop; the last window goes all the way, where a hand pushes against it.
  # shellcheck disable=SC2046
  does "W3 held at the left edge" drag $(title_of "$W3") $((sx + 3)) $((sy + sh / 2)) --no-release
  does "W3 let go at the left edge" release
  # shellcheck disable=SC2046
  does "W2 held at the top edge" drag $(title_of "$W2") $((sx + sw * 3 / 4)) $((sy + 2)) --no-release
  does "W2 let go at the top edge" release
  # shellcheck disable=SC2046
  does "W1 held at the right edge" drag $(title_of "$W1") $((sx + sw - 1)) $((sy + sh / 2)) --no-release
  does "W1 let go at the right edge" release
  journey_ends
fi

if wanted pointer; then
  # The first window refuses to be smaller than 700×500, so a small slot turns it into a tile.
  ARBOR_TEST_WINDOWS_ARGS="--min-size 1:700x500"
  journey pointer 3
  ARBOR_TEST_WINDOWS_ARGS=""
  # shellcheck disable=SC2046
  does "drag W3 to the left edge" drag $(title_of "$W3") $((sx + 3)) $((sy + sh / 2))
  # shellcheck disable=SC2046
  does "drag W3's right edge 60 to the right" drag $(at "$W3" "x + w - 1" "y + h / 2") $(at "$W3" "x + w + 59" "y + h / 2")
  # shellcheck disable=SC2046
  does "drag W2 onto the right of W3" drag $(title_of "$W2") $(at "$W3" "x + w * 85 / 100" "y + h / 2")
  # shellcheck disable=SC2046
  does "double-click W3's title bar" dblclick $(title_of "$W3")
  # shellcheck disable=SC2046
  does "press inside W3 and move, held" drag $(middle_of "$W3") $(at "$W3" "x + w / 2 + 90" "y + h / 2 + 60") --no-release
  does "let go inside W3" release
  # shellcheck disable=SC2046
  does "drag the seam right of W3 20 to the left" drag $(at "$W3" "x + w + $ARBOR_GAP / 2" "y + h / 2") $(at "$W3" "x + w + $ARBOR_GAP / 2 - 20" "y + h / 2")
  # Near the top of the Desktop: a window as tall as its slot let go of half way down would hang off the display.
  read -r dx dy dw _ <<< "$(arbor_ask desktop)"
  # shellcheck disable=SC2046
  does "drag W2 out onto the Desktop" drag $(title_of "$W2") $((${dx:-0} + ${dw:-0} / 2)) $((${dy:-0} + 60))
  does "dock W1, too big for its slot, below W3" ctl dock "$W1" beside "$W3" bottom
  does "show-all" ctl show-all
  # shellcheck disable=SC2046
  does "click the tile" click $(tile_of "$W1")
  journey_ends
fi

if wanted keys; then
  journey keys 3 ARBOR_NO_HOTKEYS=0
  does "dock W1 left" ctl dock "$W1" left
  does "dock W2 right" ctl dock "$W2" right
  # shellcheck disable=SC2046
  does "click W1" click $(middle_of "$W1")
  does "⌃⌥↩ zoom" key ctrl+opt+return
  does "⌃⌥Space show-all" key ctrl+opt+space
  does "⌃⌥⇧→ focus right" key ctrl+opt+shift+right
  does "⌃⌥⇧→ focus right again" key ctrl+opt+shift+right
  does "⌃⌥⇧← focus left" key ctrl+opt+shift+left
  does "⌃⌥↩ zoom what has the focus" key ctrl+opt+return
  does "⌃⌥[ back" key "ctrl+opt+["
  does "⌃⌥F float" key ctrl+opt+f
  does "⌃⌥F dock again" key ctrl+opt+f
  does "⌃⌥D desktop" key ctrl+opt+d
  journey_ends
fi

step "written down"
wc -l "$REALITY"/*.jsonl
# arbor_stop's own checks are printed above. The verdict on what was written down is reality-diff.py's, so they do not decide how this ends.
ARBOR_FAILED=0
