#!/bin/bash
# The sabotage run: are the detectors awake? The script itself does to real windows what Arbor must never do, one offence at a time, and
# jolts.py has to report every offence by its own detector, by no other, and nothing where nothing was done.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/day-sabotage.sh          on one of GitHub's Macs, from anywhere: three minutes
#
# A detector that is silent all day proves nothing unless it has been seen to speak, on the same Macs, through the same sampler, about
# the same kind of windows (docs/VIABLE.md, "Three controls"). Arbor does not run and is not even built: `apptool set-frame`, `raise`, `activate` and
# `close` are the saboteur, through Accessibility, as Arbor moves windows. What only Arbor's own process can do wrong is done by a program that passes
# for it (impostor.swift). Between the offences there are honest steps, which must stay clean.
#
# What comes back: sabotage.md (step, offence committed, what was reported), and what every day brings back.
# Committed: jolt (moved twice; elsewhere first), moved-unasked, flash, behind, focus, pulled, stuck, slow, size-lost, lost (out of view; gone), told; and by
# the impostor: fought, input-held, busy, left-behind, crash. All sixteen of docs/VIABLE.md.
#
# Only on GitHub's Macs: it opens real apps, moves and closes their windows, and switches the display's size.
DAY_SABOTAGE=1
WALK_WITHOUT_ARBOR=1
WALK_KIND=sabotage
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
needs_throwaway_mac "open real apps, move, cover and close their windows, hold back everybody's mouse-up for a moment, and switch the display's size"

place() { apptool set-frame "$@" > /dev/null; }

# The same Mac, the same cast and the same manifest as a day's, so that the run can be counted as one of its cell.
walk_begin stock laptop defaults
dx=$WALK_X dy=$WALK_Y dw=$WALK_W dh=$WALK_H

chapter "The windows"
act open-close open-second "opens a second document in TextEdit"
known=$(app_windows "$P_textedit")
open -g -b com.apple.TextEdit "$DAY_DOCUMENTS/$APPS_CANARY-elm.txt"
app_await_window "$P_textedit" "$known" 10 || die "TextEdit opened no second window"
label "$NEW_WINDOW" elm
acted setup=1
A=$W_textedit E=$NEW_WINDOW B=$W_finder C=$W_preview D=$W_terminal P_oak=$P_textedit P_shell=$P_terminal
# The others are out of the way: what is played here is about five windows.
act idle lay-out "hides the other apps and puts five windows side by side"
for name in safari notes calendar settings mail; do apptool hide "$(pid_of "$name")"; done
place "$A" 80 80 520 380
place "$E" 140 500 520 300
place "$B" 700 80 560 380
place "$C" 760 500 480 320
place "$D" 1000 300 420 260
sleep 3
acted setup=1 own=all

chapter "Honest steps and offences"
act switch honest-switch "clicks TextEdit's icon in the Dock"
must dock_click com.apple.TextEdit
acted front="$(main_window_of "$P_oak")"
act switch honest-click "clicks the first document's title bar"
must click_window "$A"
acted front="$A"
act dock-key honest-move "a window is moved once, straight to where it ends up"
place "$A" 120 100 520 380
acted moves="$A"
act dock-key honest-resize "a window is given another size and another place, which takes two stages"
place "$A" 60 60 600 420
acted moves="$A"

act dock-key moved-twice "OFFENCE: a window is moved, and half a second later moved again"
place "$A" 160 100 600 420
sleep 0.5
place "$A" 220 100 600 420
acted moves="$A" offence=jolt
act dock-key elsewhere-first "OFFENCE: a window goes somewhere else before it goes where it ends up"
place "$A" 700 300 600 420
# Long enough to be seen: the sampler looks every 26 ms, and what is over sooner shows to nobody.
sleep 0.1
place "$A" 100 100 600 420
acted moves="$A" offence=jolt
act dock-key somebody-else "OFFENCE: a window that the step does not name is moved"
place "$B" 720 120 560 380
acted moves="$A" offence=moved-unasked

act view honest-park "a window is sent out of view, to the corner"
place "$C" "$((dx + dw - 1))" "$((dy + dh - 1))" 480 320
acted moves="$C"
echo "parked at $(real_frame_of "$C")"
act view flashes "OFFENCE: a window that is out of view shows for a moment"
place "$C" 400 300 480 320
sleep 0.1
place "$C" "$((dx + dw - 1))" "$((dy + dh - 1))" 480 320
acted moves=any offence=flash
act view honest-return "it comes back into view"
place "$C" 760 500 480 320
acted moves="$C"

act switch covered "OFFENCE: the window switched to is covered by another one at once"
must click_window "$A"
sleep 0.4
apptool raise "$E"
acted front="$A" offence=behind
act switch honest-click-2 "clicks the first document's title bar"
must click_window "$A"
acted front="$A"
act open-close honest-minimize "Terminal's window is minimized"
apptool minimize "$D"
acted leaves="$D"
act switch keyboard-taken "OFFENCE: after the switch another app, with no window to show, takes the keyboard"
must click_window "$A"
sleep 0.4
apptool activate "$P_shell"
acted front="$A" offence=focus
act switch honest-click-3 "clicks the first document's title bar"
must click_window "$A"
acted front="$A"
act idle comes-forward "OFFENCE: nobody does anything, and an app comes forward by itself"
sleep 1
apptool activate "$P_shell"
sleep 1
acted offence=focus
act switch honest-click-4 "clicks the first document's title bar"
must click_window "$A"
acted front="$A"

read -r x y _ <<< "$(apptool grab "$A")"
act drag honest-drag "drags the first document a little way by its title bar"
must drag_window "$A" "$((x + 120))" "$((y + 60))"
acted drags="$A" place="$A"
read -r x y _ <<< "$(apptool grab "$A")"
act drag out-of-the-hand "OFFENCE: while the button is down the dragged window is pulled away"
must drag_window "$A" "$((x - 120))" "$((y - 60))" --no-release
read -r fx fy fw fh <<< "$(real_of "$A")"
place "$A" "$((fx + 400))" "$((fy + 200))" "$fw" "$fh"
sleep 0.3
place "$A" "$fx" "$fy" "$fw" "$fh"
release
acted drags="$A" place="$A" offence=pulled
read -r x y _ <<< "$(apptool grab "$A")"
act drag dropped-elsewhere "OFFENCE: a window is dragged and let go, and goes somewhere else altogether"
must drag_window "$A" "$((x + 100))" "$((y + 40))"
read -r fx fy fw fh <<< "$(real_of "$A")"
place "$A" "$((fx + 420))" "$((fy + 260))" "$fw" "$fh"
acted drags="$A" offence=stuck
act dock-key honest-move-2 "it is moved back to where the hand left it, which is its own place from now on"
place "$A" "$fx" "$fy" "$fw" "$fh"
acted moves="$A" place="$A"
# Where the hand left it is its own place from now on.
read -r ox oy _ _ <<< "$(real_of "$A")"

act dock-key answers-late "OFFENCE: a key is pressed, and the window moves two seconds later"
key escape
sleep 2
place "$A" 140 100 600 420
acted moves="$A" offence=slow
act idle honest-idle "nobody does anything for three seconds"
sleep 3
acted

act way-out wrong-size "OFFENCE: everything is given back, but one window keeps a size that is not its own"
place "$B" 700 80 560 380
place "$C" 760 500 480 320
place "$E" 140 500 520 300
place "$A" "$ox" "$oy" 640 460
acted moves=any restores=all offence=size-lost
act way-out honest-give-back "now it gets its own size and place back too"
place "$A" "$ox" "$oy" 520 380
acted moves=any restores=all places=1 everything=1
act way-out left-out "OFFENCE: everything should be in view, and one window is in the corner"
place "$B" "$((dx + dw - 1))" "$((dy + dh - 1))" 560 380
acted moves=any everything=1 offence=lost
act view honest-return-2 "it comes back"
place "$B" 700 80 560 380
acted moves="$B"
act idle vanishes "OFFENCE: a window is closed, and nobody asked for that"
apptool close "$E"
acted offence=lost

chapter "What only Arbor's own process can do wrong"
# Called what Arbor's program is called, so that it is told by the same signs: the name of its process, the folder it runs from. In a folder of its own: a
# script after this one on the same Mac shares the build, and must find Arbor there and not this.
ARBOR_BIN="$APPS_TEMP/impostor-bin"
mkdir -p "$ARBOR_BIN"
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/impostor.swift" -o "$ARBOR_BIN/Arbor" > "$ARBOR_OUT/build-impostor.log" 2>&1 \
  || { cat "$ARBOR_OUT/build-impostor.log"; die "scripts/mac-shell/impostor.swift did not compile"; }
# There is no Arbor to ask what it believes.
DAY_NO_AUDIT=1
impostor() {
  rm -f "$APPS_TEMP/impostor"
  mkfifo "$APPS_TEMP/impostor"
  "$ARBOR_BIN/Arbor" < "$APPS_TEMP/impostor" 2>> "$ARBOR_OUT/impostor.log" 5<&- 6>&- 8>&- 9>&- &
  ARBOR_PID=$!
  started "$ARBOR_PID"
  exec 7> "$APPS_TEMP/impostor"
  note "arbor $ARBOR_PID"
  sleep 1
}
tell() { echo "$*" >&7; }
impostor

act switch honest-click-5 "clicks the first document's title bar, with something that passes for Arbor running"
must click_window "$A"
acted front="$A"
act dock-key under-the-stage "a panel covers the whole display, as Arbor's stage does, and under it a window goes about before it ends up: nobody sees that"
tell panel 4 "$dx" "$dy" "$dw" "$dh"
sleep 0.5
read -r fx fy fw fh <<< "$(real_of "$A")"
place "$A" "$((fx + 300))" "$((fy + 200))" "$fw" "$fh"
sleep 0.4
place "$A" "$((fx + 40))" "$fy" "$fw" "$fh"
sleep 0.2
tell unpanel
acted moves="$A"
act dock-key under-no-stage "OFFENCE: the same under a panel that is wholly transparent, as Arbor's is when it rehearses its stage: everybody sees the window go about"
tell panel 4 "$dx" "$dy" "$dw" "$dh" 0
sleep 0.5
read -r fx fy fw fh <<< "$(real_of "$A")"
place "$A" "$((fx + 300))" "$((fy + 200))" "$fw" "$fh"
sleep 0.4
place "$A" "$((fx - 40))" "$fy" "$fw" "$fh"
sleep 0.2
tell unpanel
acted moves="$A" offence=jolt
act switch held-back "OFFENCE: the button comes up, and an event tap keeps that from the apps for a fifth of a second"
tell hold 200 4
sleep 0.5
must click_window "$A"
acted front="$A" offence=input-held
sleep 4
# A round of input with something that passes for Arbor running, which is honest; and one in which a key goes no further.
input_round started
tell drop 1 30
sleep 0.5
WALK_ROUND_SAYS="offence=input-held"
input_round last
WALK_ROUND_SAYS=""
act drag-where-macos-tiles both-previews "OFFENCE: a window is dragged against the menu bar, and a drop preview comes up beside macOS's own"
must drag_window "$A" "$((dx + dw / 2))" "$dy" --no-release
sleep 1
tell panel 3 "$((dx + 12))" "$((dy + 43))" "$((dw - 24))" 400
sleep 0.6
release
tell unpanel
acted drags="$A" own="$A" offence=fought
act drag-where-macos-tiles honest-drag-back "drags it away from the top again"
must drag_window "$A" "$((dx + dw / 2))" "$((dy + 130))"
acted drags="$A" own="$A"
act idle busy-doing-nothing "OFFENCE: nobody does anything, and the process keeps a core busy"
tell spin 8
idle 6
acted offence=busy
act idle honest-idle-2 "nobody does anything, and neither does it"
sleep 3
idle 5
acted
act quit-and-start stays-behind "OFFENCE: it is asked to quit and does, but a second process of its stays"
# Its input stays open and says nothing, so it stays.
sleep 30 | "$ARBOR_BIN/Arbor" > /dev/null 2>&1 5<&- 6>&- 7>&- 8>&- 9>&- &
SECOND=$!
started "$SECOND"
sleep 0.5
tell quit
exec 7>&-
want "it ends within five seconds" day_gone
day_forgets
acted offence=left-behind
kill_started "$SECOND"
impostor
act idle ends-unasked "OFFENCE: nobody does anything, and the process ends"
tell die
exec 7>&-
sleep 1
acted offence=crash

act idle tells "OFFENCE: a window's title is written into a log"
echo "the window is called $APPS_CANARY-oak.txt" > "$ARBOR_OUT/saboteur.log"
acted offence=told

day_report
