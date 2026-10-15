#!/bin/bash
# The same steps on a hosted Mac and in a rehearsal, written down after every step so that the two can be compared: `make reality`.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/reality.sh         the real app, real windows, the real pointer and keyboard
#   scripts/mac-shell/rehearse.sh scripts/mac-shell/reality.sh    the real controller on the stand-ins, on Linux
#   scripts/reality-diff.py <the Mac's reality folder> <the rehearsal's>
#
# Thousands of tests pass against the stand-ins, and the serious faults are found on real Macs all the same, because the stand-ins are
# more polite than macOS. This script is the instrument that says where. It expects nothing of a step: the only checks are lib.sh's own at the end of
# a session (Arbor quits, the windows are back on screen). It plays journeys, each in an Arbor session of its own, and after every step `observe` lets things settle and appends one line of JSON to
# mac-shell/reality/<journey>.jsonl: what Arbor believes, what the window server shows, and what crossed the seam between Arbor and the
# window system since the step before, taken from a trace. reality.py has the form, which names nothing that differs between the worlds for
# no reason (window ids, process ids, times). Every difference that is left is a lie of the stand-ins or a fault of Arbor.
#
# The journeys:
#   commands   what arbor-e2e's first session does over the socket: dock, zoom, back, resize, float, arrange, the gap, the Desktop, quit
#   apps       what windows and apps do by themselves: minimize, restore, hide, unhide, close, open, another app coming forward
#   edges      title-bar drags with the real pointer all the way to the left, top and right screen edge, each looked at while held and after. With
#              macOS's tiling on, as a Mac comes, those edges are macOS's: Arbor stands aside, macOS tiles, and the question is whether the
#              stand-ins tile as macOS does
#   pointer    e2e-drag.sh's steps and a few more: to the bottom edge, a window's edge, onto another window, a double-click, a press inside, a
#              seam, out onto the Desktop, a click on a tile
#   keys       a click on a window, then shortcuts on the real keyboard
# REALITY_JOURNEYS="commands keys" plays only those: for a rehearsal while working on one of them. A Mac plays them all.
#
# macOS stays as it comes: its own tiling at the screen edges is not switched off, because that is where people live. Where a journey is about
# docked windows it gets its first one by the bottom edge, which is Arbor's, and a command. No journey needs an event tap (`pointerGestures`): no pinch, no ⌃⌥ scroll or rectangle.
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
# Which Arbor this is: a recording is compared with rehearsals for as long as it lies in the repository, and Arbor moves on meanwhile.
git -C "$ARBOR_ROOT" rev-parse HEAD > "$REALITY/commit.txt" 2>/dev/null || rm -f "$REALITY/commit.txt"
scratch_dir reality REALITY_WORK
# The same wait in both worlds: echoes, put-backs and saves arrive up to a second after the last thing that happened.
REALITY_SETTLE=1
JOURNEY=""
STEP=0
NAMES=""
TRACE=""
PROCESSES=""
OTHER_PID=""
# The journey's own trace is the one that is recorded.
ARBOR_RECORD=""
JOURNEYS="commands apps edges pointer keys"

for name in ${REALITY_JOURNEYS:-}; do
  case " $JOURNEYS " in *" $name "*) ;; *) die "there is no journey '$name': $JOURNEYS" ;; esac
done
wanted() { case " ${REALITY_JOURNEYS:-$JOURNEYS} " in *" $1 "*) ;; *) return 1 ;; esac; }
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
  # Also what writes out the lines a trace holds back during a drag. Without the mark this step would be given the reports of the one before.
  if arbor_runs; then
    "$ARBOR_BIN/arborctl" trace note "reality: $label" > /dev/null || die "the trace of $JOURNEY has ended before its journey: $("$ARBOR_BIN/arborctl" trace status 2>&1)"
  fi
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
  PROCESSES="arbor=$ARBOR_PID test-windows=$ARBOR_WINDOWS_PID${ARBOR_WINDOWS_PID_2:+ second-app=$ARBOR_WINDOWS_PID_2}"
  for id in $ARBOR_WINDOW_IDS; do
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

# Ends the session, with a look at where quitting has left the windows before they close.
after_quit() {
  observe "quit"
  cp "$TRACE" "$REALITY/traces/$JOURNEY.jsonl"
}
journey_ends() {
  ARBOR_AFTER_QUIT=after_quit
  arbor_stop
  ARBOR_AFTER_QUIT=""
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
in_front() { [ "$(pointer keyboard | cut -d ' ' -f 1)" = "$1" ]; }
# On screen: a test window that was closed stays in the window server's list.
has_windows() { [ "$(pointer windows --pid "$ARBOR_WINDOWS_PID" --on-screen | wc -l | tr -d ' ')" -ge "$1" ]; }

# pushed <name> <window> <edge> <x> <y>: by its title bar all the way to a screen edge, looked at while held and after. Its app brings it forward
# first: the window pushed before it lies where macOS has tiled it, over this one's title bar as likely as not, and would be what the press takes.
pushed() {
  local before
  does "the app brings $1 forward" tw front "$2"
  before=$(real_frame_of "$2")
  # shellcheck disable=SC2046
  does "$1 held at the $3 edge" drag $(title_of "$2") "$4" "$5" --no-release
  check "$1 came along to the $3 edge" test "$(real_frame_of "$2")" != "$before"
  does "$1 let go at the $3 edge" release
}

# MARK: The journeys

arbor_build
step "the Mac"
echo "macOS $(sw_vers -productVersion)"
pointer displays
macos_tiling
# The same journeys on a Mac that is changed first: reality-dock-left.sh and reality-second-display.sh define this and then read this file in.
if declare -F reality_before > /dev/null; then reality_before; fi

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
  if [ -n "${REALITY_SECOND_DISPLAY:-}" ]; then
    # From the smaller display to the larger and back, or the other way round. In a model the window arrived short; no Mac has been asked.
    does "show-all before the move" ctl show-all
    does "dock W1 left again" ctl dock "$W1" left
    does "move W1 to the next display" ctl move-to-display next "$W1"
    does "move W1 to the next display again" ctl move-to-display next "$W1"
  fi
  journey_ends
fi

if wanted apps; then
  ARBOR_SECOND_APP=1
  journey apps 3
  ARBOR_SECOND_APP=0
  W4=$V1
  OTHER_PID=$ARBOR_WINDOWS_PID_2
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
  ARBOR_WINDOW_IDS="$W1 $W3 $W4"

  echo "> test windows: one more window, as ⌘N opens it"
  kill -USR2 "$ARBOR_WINDOWS_PID"
  eventually has_windows 3
  observe "a new window opens"

  # The second app has been in front since the first one hid.
  echo "> the first app comes forward"
  kill -USR1 "$ARBOR_WINDOWS_PID"
  eventually in_front "$ARBOR_WINDOWS_PID"
  observe "the first app comes forward"
  echo "> the second app comes forward"
  kill -USR1 "$OTHER_PID"
  eventually in_front "$OTHER_PID"
  observe "the second app comes forward"

  does "dock W4 right" ctl dock "$W4" right
  does "zoom W1" ctl zoom "$W1"
  echo "> the second app comes forward, its window out of view"
  kill -USR1 "$OTHER_PID"
  eventually in_front "$OTHER_PID"
  observe "the second app comes forward, its window out of view"
  journey_ends
fi

if wanted edges; then
  journey edges 3
  # All the way, where a hand pushes against the edge and macOS's own tiling takes the window.
  read -r fx fy fw _ <<< "$(arbor_ask display-frame)"
  [ -n "$fw" ] || die "Arbor does not say where the display is"
  pushed W3 "$W3" left "$fx" $((sy + sh / 2))
  pushed W2 "$W2" top $((sx + sw * 3 / 4)) "$fy"
  pushed W1 "$W1" right $((fx + fw - 1)) $((sy + sh / 2))
  journey_ends
fi

if wanted pointer; then
  # The first window refuses to be smaller than 700×500, so a small slot turns it into a tile.
  ARBOR_TEST_WINDOWS_ARGS="--min-size 1:700x500"
  journey pointer 3
  ARBOR_TEST_WINDOWS_ARGS=""
  # shellcheck disable=SC2046
  does "drag W3 to the bottom edge" drag $(title_of "$W3") $((sx + sw / 2)) $((sy + sh - 3))
  # The bottom edge is the one that is Arbor's whatever macOS tiles. The rest wants the window on the left, which is macOS's to drag to.
  does "dock W3 left" ctl dock "$W3" left
  # shellcheck disable=SC2046
  does "drag W3's right edge 60 to the right" drag $(at "$W3" "x + w - 1" "y + h / 2") $(at "$W3" "x + w + 59" "y + h / 2")
  # shellcheck disable=SC2046
  does "drag W2 onto the right of W3" drag $(title_of "$W2") $(at "$W3" "x + w * 85 / 100" "y + h / 2")
  # shellcheck disable=SC2046
  does "double-click W3's title bar" dblclick $(title_of "$W3")
  # macOS's zoom of a docked window stays, over everything else. A second double-click is how a person undoes it, and what comes after is about what lies beneath.
  # shellcheck disable=SC2046
  does "double-click W3's title bar again" dblclick $(title_of "$W3")
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
