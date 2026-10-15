#!/bin/bash
# macOS shows its desktop, and Arbor takes nothing of it for anybody's hand.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-sweep.sh
#
# As macOS comes, a click on the wallpaper sweeps every window aside, and the next click, on the wallpaper or on the strip of a window
# that still shows, brings them back. It is a picture: the window server lists the windows at the sides of the display, and
# Accessibility has them where they are (collab/reports/2026-10-14-the-desktop-is-shown.md). A press on a strip brings them back with
# the button still down, so the window under the pointer leaps across the display in the window server's list. Arbor once
# took that for a drag, at the edge of the display, where it docks. This script clicks, slips and pulls as a person does, and asks:
#   - every window is where it was, docked or floating as it was;
#   - no drop preview showed while the button was down;
#   - Arbor was told of no drag and set no frame (by the trace, which comes back as traces/sweep.jsonl);
#   - what is laid out meanwhile is laid out unseen: no stage goes up over the bare desktop, and nothing moves once they are back.
# And so that a rule that sees no drags and shows no motion at all does not pass: a real drag, slow and flung, is still a drag, the same
# layout with nothing swept is shown as motion, and a command given while the windows are aside still does what it says.
#
# With sampler.swift beside it (it comes with `make day`), every frame of every window on screen is written down sixty times a second, as
# samples.log, for whoever wants to count how often each window moved.
#
# Only on GitHub's Macs: it clicks on the wallpaper, which sweeps aside whatever is open.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "click on the wallpaper again and again, which sweeps every window on the Mac aside"

SAMPLER="$ARBOR_ROOT/.build/mac-shell/sampler"
SAMPLER_PID=""
TRACING=""

# MARK: Helpers

sampler_start() {
  [ -z "${ARBOR_REHEARSAL:-}" ] && [ -f "$ARBOR_ROOT/scripts/mac-shell/sampler.swift" ] || return 0
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/sampler.swift" -o "$SAMPLER" > "$ARBOR_OUT/build-sampler.log" 2>&1 \
    || { echo "sampler.swift did not compile: no samples.log"; return 0; }
  mkfifo "$ARBOR_SESSION_DIR/sampler-in" "$ARBOR_SESSION_DIR/sampler-out"
  "$SAMPLER" "$ARBOR_OUT/samples.log" "$ARBOR_SESSION_DIR/sampler-in" "$ARBOR_SESSION_DIR/sampler-out" --hz 60 \
    2>> "$ARBOR_OUT/sampler-stderr.log" 7>&- 8>&- 9>&- &
  SAMPLER_PID=$!
  started "$SAMPLER_PID"
  exec 6> "$ARBOR_SESSION_DIR/sampler-in" 5< "$ARBOR_SESSION_DIR/sampler-out"
}

sampler_stop() {
  [ -n "$SAMPLER_PID" ] || return 0
  echo stop >&6
  exec 6>&- 5<&-
  ended "$SAMPLER_PID" 30 || kill_started "$SAMPLER_PID"
  SAMPLER_PID=""
}

# A heading, and a mark in the trace and in the samples.
act() {
  step "$*"
  [ -n "$SAMPLER_PID" ] && echo "mark $*" >&6
  [ -n "$TRACING" ] && "$ARBOR_BIN/arborctl" trace note "$*" > /dev/null 2>&1
  return 0
}

server_frames() { local id; for id in $ARBOR_WINDOW_IDS; do printf '%s | ' "$(real_frame_of "$id")"; done; }
believed_frames() { local id; for id in $ARBOR_WINDOW_IDS; do printf '%s | ' "$(frame_of "$id")"; done; }
arrangement() { "$ARBOR_BIN/arborctl" layout --ids; }

# At least two test windows are mostly out of view. (Nothing is parked here: the view is on everything.)
is_swept() {
  local id out=0
  for id in $ARBOR_WINDOW_IDS; do
    [ "$("$ARBOR_POINTER" visible "$id" | tr -d .)" -lt 50 ] && out=$((out + 1))
  done
  [ "$out" -ge 2 ]
}
not_swept() { ! is_swept; }
no_preview() { ! has_overlay 3; }
same() { [ "$1" = "$2" ] || { echo "    got      $1" >&3; echo "    expected $2" >&3; return 1; }; }
# `check` silences what it runs; descriptor 3 still reaches the output.
exec 3>&1

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

# strip_of <window> [points]: x y, the middle of what still shows of a window that is swept aside, between the menu bar and the Dock;
# or, of a window at the left or the right, that many points from the edge of the display.
strip_of() {
  local x y w h dx dy dw dh vx vy vw vh
  read -r x y w h <<< "$(real_frame_of "$1")"
  read -r dx dy dw dh <<< "$(display_frame_of 1)"
  read -r vx vy vw vh <<< "$(screen_of 1)"
  python3 - "${2:--1}" "$x" "$y" "$w" "$h" "$dx" "$dw" "$vy" "$vh" << 'END'
import sys
edge, x, y, w, h, dx, dw, vy, vh = (float(word) for word in sys.argv[1:])
left, top, right, bottom = max(x, dx), max(y, vy + 1), min(x + w, dx + dw), min(y + h, vy + vh)
if right - left < 2 or bottom - top < 2:
    sys.exit(1)
px = (left + right) / 2
if edge >= 0:
    px = dx + edge if x < dx else dx + dw - 1 - edge
print(int(px), int((top + bottom) / 2))
END
}

# Notes how things are, then clicks on the wallpaper. Ends the script if macOS sweeps nothing: nothing below would mean anything.
sweep() {
  AT_REST=$(server_frames)
  BELIEVED=$(believed_frames)
  ARRANGED=$(arrangement)
  read -r BARE_X BARE_Y <<< "$(bare_spot)"
  [ -n "${BARE_X:-}" ] || die "no bare spot of wallpaper shows"
  pointer click "$BARE_X" "$BARE_Y"
  sleep 1.5
  is_swept || die "a click on the wallpaper at $BARE_X,$BARE_Y swept nothing aside: is \"click wallpaper to reveal desktop\" on?"
  echo "swept aside by a click at $BARE_X,$BARE_Y: $(server_frames)"
}

as_before() {
  check "they are back" eventually not_swept
  sleep 1
  check "every window is where it was, by the window server" same "$(server_frames)" "$AT_REST"
  check "and where Arbor believes it" same "$(believed_frames)" "$BELIEVED"
  check "the arrangement is what it was" same "$(arrangement)" "$ARRANGED"
}

# press_strip <window> <dx> <dy> <hold> [points from the edge]: presses on what shows of it, goes that far, rests, and lets go.
press_strip() {
  local spot sx sy
  spot=$(strip_of "$1" "${5:--1}") || { check "a strip of $1 shows" false; pointer click "$BARE_X" "$BARE_Y"; return; }
  read -r sx sy <<< "$spot"
  drag "$sx" "$sy" "$((sx + $2))" "$((sy + $3))" --steps 6 --duration 0.25 --hold "$4" --no-release
  check "no drop preview shows while the button is down" no_preview
  release
}

# How often the stage has gone up so far, by Arbor's own log. (It can be down again within a few hundredths of a second, between two looks at
# the window server's list.)
stages() { grep -c "stage up" "$ARBOR_HOME/arbor.log"; }

# trace_count <from note> <to note> <pattern>: how many lines between the two remarks hold the pattern.
trace_count() {
  python3 - "$ARBOR_OUT/traces/sweep.jsonl" "$@" << 'END'
import json, sys
path, start, end, pattern = sys.argv[1:]
inside = count = 0
for line in open(path):
    note = json.loads(line).get("note", "")
    if note.startswith(start):
        inside = 1
    elif note.startswith(end):
        inside = 0
    elif inside and pattern in line:
        count += 1
print(count)
END
}

# MARK: The checks

arbor_build
macos_click_wallpaper
# GitHub's Macs come with Reduce Motion on; a person's Mac does not, and with it on Arbor shows no motion.
macos_reduce_motion off
# And the motion is an option, which Arbor ships without (collab/QUESTIONS.md, Q29): that no stage goes up over a bare desktop says nothing where none ever does.
arbor_settings '{"animationDuration": 0.46}'
# As an ordinary app, with an icon in the Dock and a place in ⌘Tab.
ARBOR_TEST_WINDOWS_ARGS="--regular"
arbor_start 5
sampler_start
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W5" bottom
sleep 1
# Two floating windows side by side at the top of the Desktop. macOS takes them up, where their strips show below the menu bar; what it
# takes down waits behind the Dock.
read -r dx dy dw dh <<< "$(arbor_ask desktop)"
echo "move $W3 $dx $((dy + 10)) $((dw / 2 - 6)) 200" >&9
echo "move $W4 $((dx + dw / 2 + 6)) $((dy + 10)) $((dw / 2 - 6)) 200" >&9
sleep 1
summary
if "$ARBOR_BIN/arborctl" trace on sweep > /dev/null 2>&1; then
  TRACING=1
elif [ -n "${ARBOR_REHEARSAL:-}" ]; then
  echo "(a rehearsal has no traces: what rests on one is left out)"
else
  die "no trace could be started, and half of what is asked here rests on it"
fi

act "s1 a click on the wallpaper, and another"
sweep
check "Arbor goes on believing them where they are" same "$(believed_frames)" "$BELIEVED"
shot 1-swept
pointer click "$BARE_X" "$BARE_Y"
as_before

act "s2 a click on a docked window's strip that slips by three points"
sweep
press_strip "$W1" 3 3 0.1
as_before
check "$W1 is docked" is docked "$W1"

act "s3 a press on a floating window's strip that slips and rests, longer than a drop target takes"
sweep
press_strip "$W3" 3 3 0.8
as_before
check "$W3 is floating" is floating "$W3"
check "$W4 is floating" is floating "$W4"

act "s4 somebody tries to pull a docked window in by its strip"
sweep
press_strip "$W2" -150 10 0.8
as_before
check "$W2 is docked" is docked "$W2"

act "s5 and a floating one"
sweep
press_strip "$W4" 10 150 0.8
as_before
check "$W3 is floating" is floating "$W3"
check "$W4 is floating" is floating "$W4"

act "s6 the control: with nothing swept, a layout is shown as motion"
# A command that gives nobody the keyboard, so that it ends no sweep. Not a window that is minimized: the Dock grows by it, the display's
# visible frame with the Dock, and a layout for another frame is never shown as motion.
before=$(stages)
ctl resize "$W1" right 40
sleep 1.5
if [ -z "${ARBOR_REHEARSAL:-}" ]; then check "the stage went up" test "$(stages)" -eq $((before + 1)); fi
summary

act "s7 the same while they are aside: unseen"
sweep
before=$(stages)
ctl resize "$W1" right -40
sleep 1.5
check "no stage went up over the bare desktop" test "$(stages)" -eq "$before"
check "they are still aside" is_swept
MEANWHILE=$(believed_frames)
ARRANGED=$(arrangement)
check "Arbor has laid out meanwhile" test "$MEANWHILE" != "$BELIEVED"
shot 7-laid-out-while-swept
echo "and a press on the outermost point of a strip, of a window that comes back with another size"
press_strip "$W1" 3 3 0.8 1
check "they are back" eventually not_swept
sleep 1
check "every window is where Arbor put it meanwhile, by the window server" same "$(server_frames)" "$MEANWHILE"
check "and where Arbor believes it" same "$(believed_frames)" "$MEANWHILE"
check "the arrangement is what it was" same "$(arrangement)" "$ARRANGED"
summary

act "s8 the control: a real drag is still a drag"
read -r fx fy fw fh <<< "$(real_frame_of "$W4")"
# shellcheck disable=SC2046
click $(titlebar_of "$W4")
sleep 0.5
read -r tx ty <<< "$(titlebar_of "$W4")"
drag "$tx" "$ty" "$tx" "$((ty + 60))" --steps 20 --duration 0.5
sleep 1
check "the window went along, sixty points down" arbor_close "$(real_frame_of "$W4")" "$fx $((fy + 60)) $fw $fh"

act "s9 the control: so is one that is flung"
drag "$tx" "$((ty + 60))" "$tx" "$ty" --steps 3 --duration 0.05
sleep 1
check "the window went along, sixty points up" arbor_close "$(real_frame_of "$W4")" "$fx $fy $fw $fh"

act "s10 a command given while they are aside does what it says, and brings them back"
sweep
ctl focus "$W2"
as_before
check "$W2 has the keyboard" eventually is focused "$W2"

act "s11 the end"
if [ -n "$TRACING" ]; then
  ctl trace off
  mkdir -p "$ARBOR_OUT/traces"
  cp "$ARBOR_HOME"/traces/*-sweep.jsonl "$ARBOR_OUT/traces/sweep.jsonl"
  check "from the first click to the last pull Arbor was told of no drag" same "$(trace_count "s1 " "s6 " '"dragBegan"')" 0
  check "of no resize by hand" same "$(trace_count "s1 " "s6 " '"resizeBegan"')" 0
  check "and of no window moved by hand" same "$(trace_count "s1 " "s6 " '"user":true')" 0
  check "it showed no drop preview" same "$(trace_count "s1 " "s6 " '"showDropPreview"')" 0
  check "and it set no frame" same "$(trace_count "s1 " "s6 " '"setFrame"')" 0
  check "nor was it told of a drag of the window that came back with another size" same "$(trace_count "s7 " "s8 " '"dragBegan"')" 0
  check "or of a resize by hand" same "$(trace_count "s7 " "s8 " '"resizeBegan"')" 0
  check "and it showed no drop preview" same "$(trace_count "s7 " "s8 " '"showDropPreview"')" 0
  check "the two real drags were drags" same "$(trace_count "s8 " "s10 " '"dragBegan"')" 2
fi
sampler_stop
arbor_stop
