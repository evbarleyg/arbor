#!/bin/bash
# What macOS reports, and what it does, while it shows the desktop: a probe, not a check.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-sweep.sh
#
# As macOS comes, a click on the wallpaper sweeps every window aside and the next one brings them back. The window server
# moves them and tells nobody. The questions only a Mac can answer:
#   1. What do Accessibility, the window list and the workspace say during a sweep and after it: which frames, which notices, in
#      what order, how long does it take? Does the Dock or WindowManager announce it?
#   2. What tells a sweep from a person who moves a window?
#   3. What becomes of a window whose frame is set through Accessibility while it is swept aside, and of the sweep?
#   4. What else ends a sweep: another app coming forward, ⌘Tab, a raise, a click on the strip of a window that still shows, a
#      new window?
#   5. Is F11 (Show Desktop) the same thing?
#   6. What does Arbor do today: at rest, at a command that lays out, at a focus command, at a pause, at Quit?
#
# What comes back: output.txt (both views of every window after every act), views.log (twoviews.swift: both views sixty times a
# second, with every notice), samples.log (sampler.swift: every window on screen, of all levels), traces/ (what Arbor was
# told and what it did), arbor.log, pictures.
#
# Only on GitHub's Macs: it clicks on the wallpaper, which sweeps aside whatever is open.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "click on the wallpaper again and again, which sweeps every window on the Mac aside"

TOOLS="$ARBOR_ROOT/.build/mac-shell"
VIEWS_LOG="$ARBOR_OUT/views.log"
VIEWS_PID=""
SAMPLER_PID=""
rehearsing() { [ -n "${ARBOR_REHEARSAL:-}" ]; }

# MARK: Tools

compile_tools() {
  local name pids="" pid
  rehearsing && return 0
  mkdir -p "$TOOLS"
  for name in twoviews sampler apptool; do
    swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/$name.swift" -o "$TOOLS/$name" > "$ARBOR_OUT/build-$name.log" 2>&1 &
    pids="$pids $!"
  done
  arbor_build
  for pid in $pids; do
    wait "$pid" || { grep -A 6 "error:" "$ARBOR_OUT"/build-twoviews.log "$ARBOR_OUT"/build-sampler.log "$ARBOR_OUT"/build-apptool.log | head -n 60; die "a tool did not compile"; }
  done
}

milliseconds() { perl -MTime::HiRes=time -e 'printf "%d", time * 1000'; }

# A heading in the output and a mark in both logs.
act() {
  echo
  echo "-- $*"
  echo "$(milliseconds) M $*" >> "$VIEWS_LOG"
  [ -n "$SAMPLER_PID" ] && echo "mark $*" >&6
  if [ -n "$ARBOR_PID" ] && [ -n "${TRACING:-}" ]; then "$ARBOR_BIN/arborctl" trace note "$*" > /dev/null 2>&1; fi
  return 0
}

watchers_start() {
  rehearsing && return 0
  "$TOOLS/twoviews" watch "$VIEWS_LOG" "$ARBOR_WINDOWS_PID" 2>> "$ARBOR_OUT/twoviews-stderr.log" 7>&- 8>&- 9>&- &
  VIEWS_PID=$!
  started "$VIEWS_PID"
  mkfifo "$ARBOR_SESSION_DIR/sampler-in" "$ARBOR_SESSION_DIR/sampler-out"
  "$TOOLS/sampler" "$ARBOR_OUT/samples.log" "$ARBOR_SESSION_DIR/sampler-in" "$ARBOR_SESSION_DIR/sampler-out" --hz 60 \
    2>> "$ARBOR_OUT/sampler-stderr.log" 7>&- 8>&- 9>&- &
  SAMPLER_PID=$!
  started "$SAMPLER_PID"
  exec 6> "$ARBOR_SESSION_DIR/sampler-in" 5< "$ARBOR_SESSION_DIR/sampler-out"
}

watchers_stop() {
  rehearsing && return 0
  [ -n "$SAMPLER_PID" ] && { echo stop >&6; exec 6>&- 5<&-; ended "$SAMPLER_PID" 30 || kill_started "$SAMPLER_PID"; }
  [ -n "$VIEWS_PID" ] && kill_started "$VIEWS_PID"
  SAMPLER_PID=""
  VIEWS_PID=""
}

# Both views of every test window, now.
views() {
  local id
  if rehearsing; then
    for id in $ARBOR_WINDOW_IDS; do echo "  $id | ax ? | server $(real_frame_of "$id")"; done
  else
    "$TOOLS/twoviews" now "$ARBOR_WINDOWS_PID" | sed 's/^/  /'
  fi
}

server_frames() { local id; for id in $ARBOR_WINDOW_IDS; do printf '%s | ' "$(real_frame_of "$id")"; done; }

apptool() {
  echo "> apptool $*"
  if rehearsing; then return 0; fi
  "$TOOLS/apptool" "$@" 2>&1 | sed 's/^/  /'
}

tw() {
  echo "> test windows: $*"
  echo "$*" >&9
  sleep 0.4
}

front() { rehearsing || echo "  in front: $("$TOOLS/apptool" front)"; }

# x y: a point between the menu bar and the Dock that no ordinary window covers. (The Dock has a window as wide as the display.)
bare_spot() {
  local x y w h
  read -r x y w h <<< "$(screen_of 1)"
  "$ARBOR_POINTER" windows --on-screen | awk -v x="$x" -v y="$y" -v w="$w" -v h="$h" '
    $3 == 0 { n++; wx[n] = $4; wy[n] = $5; ww[n] = $6; wh[n] = $7 }
    END {
      for (py = y + h - 25; py > y + 20; py -= 20)
        for (px = x + w - 25; px > x + 20; px -= 20) {
          free = 1
          for (i = 1; i <= n; i++)
            if (px >= wx[i] - 8 && px <= wx[i] + ww[i] + 8 && py >= wy[i] - 8 && py <= wy[i] + wh[i] + 8) { free = 0; break }
          if (free) { print px, py; exit }
        }
      exit 1
    }'
}

# The frames at rest, to compare with. Set by `rest`.
AT_REST=""
rest() { AT_REST=$(server_frames); }
as_at_rest() { [ "$(server_frames)" = "$AT_REST" ]; }
# By what the screen shows, whatever an act has done to single windows meanwhile: at least two test windows are mostly out of view.
# (Nothing is parked when this is asked: the view is on everything.)
is_swept() {
  local id out=0
  for id in $ARBOR_WINDOW_IDS; do
    [ "$("$ARBOR_POINTER" visible "$id" | tr -d .)" -lt 50 ] && out=$((out + 1))
  done
  [ "$out" -ge 2 ]
}

sweep() {
  if is_swept; then
    echo "  (still swept from before: a click to end that first)"
    pointer click "$BARE_X" "$BARE_Y"
    sleep 1.5
  fi
  rest
  # shellcheck disable=SC2086
  read -r BARE_X BARE_Y <<< "$(bare_spot)"
  [ -n "${BARE_X:-}" ] || { echo "no bare spot of wallpaper shows"; return 1; }
  pointer click "$BARE_X" "$BARE_Y"
  sleep 1.5
  if is_swept; then echo "  swept (a click at $BARE_X,$BARE_Y)"; else echo "  NOT SWEPT by a click at $BARE_X,$BARE_Y"; return 1; fi
}

# After an act that may or may not have ended the sweep.
verdict() {
  views
  front
  if is_swept; then echo "  => STILL SWEPT"; else echo "  => the sweep is over"; fi
  if as_at_rest; then echo "  => every window is where it was at rest"; else echo "  => the window server's frames differ from those at rest"; fi
}

back() {
  if ! is_swept; then return 0; fi
  echo "  (a click on the wallpaper at $BARE_X,$BARE_Y, to end the sweep)"
  pointer click "$BARE_X" "$BARE_Y"
  sleep 1.5
  views
  if is_swept; then echo "  => STILL SWEPT AFTER THAT CLICK"; fi
  if as_at_rest; then echo "  => back: every window is where it was at rest"; else echo "  => back, but the frames differ from those at rest"; fi
}

# x y: a point of the window that still shows while it is swept aside.
strip_of() {
  local x y w h dx dy dw dh
  read -r x y w h <<< "$(real_frame_of "$1")"
  read -r dx dy dw dh <<< "$(display_frame_of 1)"
  python3 - "$x" "$y" "$w" "$h" "$dx" "$dy" "$dw" "$dh" << 'END'
import sys
x, y, w, h, dx, dy, dw, dh = (float(word) for word in sys.argv[1:])
left, top, right, bottom = max(x, dx), max(y, dy + 32), min(x + w, dx + dw), min(y + h, dy + dh)
if right - left < 2 or bottom - top < 2:
    sys.exit(1)
print(int((left + right) / 2), int((top + bottom) / 2))
END
}

beliefs() {
  local id
  for id in $ARBOR_WINDOW_IDS; do echo "  $id: Arbor believes $(frame_of "$id"), the window server has $(real_frame_of "$id")"; done
}

all_windows() { "$ARBOR_POINTER" windows --on-screen | sed 's/^/  /'; }

# MARK: The probe

if rehearsing; then arbor_build; else compile_tools; fi
sw_vers 2>/dev/null | sed 's/^/  /'
macos_click_wallpaper
macos_tiling
# GitHub's Macs come with Reduce Motion on; a person's Mac does not.
macos_reduce_motion off
"$ARBOR_POINTER" displays

step "part 1: macOS by itself (Arbor is paused and has docked nothing)"
# As an ordinary app, with an icon in the Dock and a place in ⌘Tab.
ARBOR_TEST_WINDOWS_ARGS="--regular"
arbor_start 4
watchers_start
ctl pause
sleep 1

act "1.0 at rest"
views
front
all_windows

act "1.1 a click on the wallpaper"
sweep
verdict
all_windows
shot 11-swept

act "1.2 a second click on the wallpaper"
back
all_windows

act "1.3 swept; then a frame is set through Accessibility, somewhere else in view"
if sweep; then
  apptool set-frame "$W1" 120 120 420 300
  sleep 1.5
  verdict
  shot 13-a-frame-set-while-swept
  back
  act "1.3b the window is put where it was"
  # shellcheck disable=SC2086
  apptool set-frame "$W1" $(echo "$AT_REST" | cut -d '|' -f 1)
  sleep 1
  views
fi

act "1.4 swept; then the frame Accessibility reports is set again, unchanged"
if sweep; then
  # shellcheck disable=SC2086
  apptool set-frame "$W2" $(echo "$AT_REST" | cut -d '|' -f 2)
  sleep 1.5
  verdict
  back
fi

act "1.5 swept; then the app moves its own window"
if sweep; then
  tw move "$W3" 200 200 400 300
  sleep 1.5
  verdict
  back
  # shellcheck disable=SC2086
  tw move "$W3" $(echo "$AT_REST" | cut -d '|' -f 3)
  sleep 1
fi

act "1.6 swept; then a window is raised through Accessibility (AXRaise, AXMain)"
if sweep; then
  apptool raise "$W3"
  sleep 1.5
  verdict
  back
fi

act "1.7 swept; then the windows' app is brought forward (NSRunningApplication.activate)"
if sweep; then
  apptool activate "$ARBOR_WINDOWS_PID"
  sleep 1.5
  verdict
  back
fi

act "1.8 swept; then ⌘Tab"
if sweep; then
  key cmd+tab
  sleep 1.5
  verdict
  back
fi

act "1.9 swept; then a click on the strip of a window that still shows"
if sweep; then
  if spot=$(strip_of "$W1"); then
    # shellcheck disable=SC2086
    pointer click $spot
    sleep 1.5
    verdict
  else
    echo "  nothing of $W1 shows"
  fi
  back
fi

act "1.10 swept; then the app opens a new window"
if sweep; then
  tw open 300 200 300 200
  sleep 1.5
  verdict
  all_windows
  back
fi

act "1.11 swept; then a window is minimized through Accessibility, and restored"
if sweep; then
  apptool minimize "$W4"
  sleep 1.5
  verdict
  apptool unminimize "$W4"
  sleep 1.5
  verdict
  back
fi

act "1.12 F11, Show Desktop"
rest
key f11
sleep 1.5
verdict
all_windows
if is_swept; then
  act "1.12b F11 again"
  key f11
  sleep 1.5
  verdict
fi
if is_swept; then echo "  F11 did not bring them back"; read -r BARE_X BARE_Y <<< "$(bare_spot)"; back; fi

act "1.14 a person moves a window: a real drag of a second"
rest
# shellcheck disable=SC2046
read -r tx ty <<< "$(titlebar_of "$W1")"
drag "$tx" "$ty" "$((tx + 200))" "$((ty + 120))" --steps 60 --duration 1
sleep 1
views
drag "$((tx + 200))" "$((ty + 120))" "$tx" "$ty" --steps 10 --duration 0.15
sleep 1
views

act "1.15 swept, and left alone for twelve seconds"
if sweep; then
  sleep 12
  verdict
  back
fi

ctl resume
sleep 1

step "part 2: Arbor as it is today, with two windows docked and two floating"
ctl dock "$W1" left
ctl dock "$W2" right
sleep 1
summary
ctl trace on sweep
TRACING=1

act "2.0 at rest"
views
overlays | sed 's/^/  /'

act "2.1 a click on the wallpaper"
if sweep; then
  verdict
  summary
  overlays | sed 's/^/  /'
  shot 21-swept-with-arbor
  act "2.1b a second click"
  back
  summary
fi

act "2.2 swept; then a command that only moves the keyboard: focus"
if sweep; then
  ctl focus "$W2"
  sleep 1.5
  verdict
  back
fi

act "2.3 swept; then a command that lays out: a third window is docked"
if sweep; then
  ctl dock "$W3" bottom
  sleep 2
  verdict
  summary
  shot 23-docked-while-swept
  back
  summary
  shot 23b-afterwards
  beliefs
fi
ctl float "$W3"
sleep 1
summary

act "2.4 swept; then the view changes: zoom on one window, and back to everything"
if sweep; then
  ctl zoom "$W1"
  sleep 2
  verdict
  shot 24-zoomed-while-swept
  ctl show-all
  sleep 2
  verdict
  back
  beliefs
fi

act "2.5 swept; then a press on a docked window's strip that slips by three points"
if sweep; then
  if spot=$(strip_of "$W1"); then
    read -r sx sy <<< "$spot"
    drag "$sx" "$sy" "$((sx + 3))" "$((sy + 3))" --steps 4 --duration 0.2
    sleep 2
    verdict
    summary
  fi
  back
fi

act "2.6 swept, and left alone for twelve seconds"
if sweep; then
  sleep 12
  verdict
  back
fi

act "2.7 swept; then a window closes"
if sweep; then
  tw close "$W4"
  ARBOR_WINDOW_IDS="$W1 $W2 $W3"
  sleep 2
  verdict
  summary
  back
fi

act "2.8 swept; then pause, which gives windows their own frames back"
if sweep; then
  ctl pause
  sleep 2
  verdict
  back
  ctl resume
  sleep 2
  views
  summary
fi

act "2.9 Reduce Motion on, as GitHub's Macs come: one sweep and back"
macos_reduce_motion on
if sweep; then
  verdict
  back
fi
macos_reduce_motion off

act "2.10 swept; then Quit"
sweep
ctl trace off
TRACING=""
mkdir -p "$ARBOR_OUT/traces"
cp "$ARBOR_HOME"/traces/*.jsonl "$ARBOR_OUT/traces/" 2>/dev/null
echo "> quit"
"$ARBOR_BIN/arborctl" quit
sleep 2.5
views
shot 210-quit-while-swept
if is_swept; then echo "  => STILL SWEPT"; else echo "  => the sweep is over"; fi
back
shot 210b-afterwards
watchers_stop
arbor_stop
echo "the probe is over"
