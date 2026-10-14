#!/bin/bash
# The sabotage run: are the detectors awake? The script itself does to real windows what Arbor must never do, one offence at a time, and
# jolts.py has to report every offence by its own detector, by no other, and nothing where nothing was done.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/day-sabotage.sh          on one of GitHub's Macs, from anywhere: three minutes
#
# A detector that is silent all day proves nothing unless it has been seen to speak, on the same Macs, through the same sampler, about
# the same kind of windows (docs/VIABLE.md, "Three controls"). Arbor does not run and is not even built: `apptool set-frame`, `raise`, `activate` and
# `close` are the saboteur, through Accessibility, as Arbor moves windows. Between the offences there are honest steps, which must stay clean.
#
# What comes back: sabotage.md (step, offence committed, what was reported), and what every day brings back.
# Committed so far: jolt (moved twice; elsewhere first), moved-unasked, flash, behind, focus, pulled, slow, size-lost, lost (out of view; gone).
#
# Only on GitHub's Macs: it opens real apps, moves and closes their windows, and switches the display's size.
DAY_SABOTAGE=1
source "$(dirname "${BASH_SOURCE[0]}")/lib-day.sh"
needs_throwaway_mac "open real apps, move, cover and close their windows, click in the Dock, and switch the display's size"

place() { apptool set-frame "$@" > /dev/null; }

apps_watchdog 500
step "the Mac"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m)"
day_build_tools
display_mode 1440x900 1600x900 1680x1050 1920x1080
apps_scratch
sampler_start
day_manifest kind '"sabotage"'
read -r _ dx dy dw dh _ <<< "$(pointer displays | head -n 1)"

chapter "The windows"
act open-close open-textedit "opens a document in TextEdit"
meet oak com.apple.TextEdit "$APPS_SCRATCH/oak.txt" || die "TextEdit opened no window"
acted judge=no
act open-close open-second "opens a second one"
known=$(app_windows "$P_oak")
open -g -b com.apple.TextEdit "$APPS_SCRATCH/elm.txt"
app_await_window "$P_oak" "$known" 10 || die "TextEdit opened no second window"
label "$NEW_WINDOW" elm
acted judge=no
act open-close open-finder "opens a folder in Finder"
meet grove com.apple.finder "$APPS_SCRATCH/grove" || die "Finder opened no window"
acted judge=no
act open-close open-preview "opens a picture in Preview"
meet leaf com.apple.Preview "$APPS_SCRATCH/leaf.png" || die "Preview opened no window"
acted judge=no
act open-close open-terminal "opens Terminal"
meet shell com.apple.Terminal || die "Terminal opened no window"
acted judge=no
A=$W_oak E=$NEW_WINDOW B=$W_grove C=$W_leaf D=$W_shell
act idle lay-out "puts them side by side"
place "$A" 80 80 520 380
place "$E" 140 500 520 300
place "$B" 700 80 560 380
place "$C" 760 500 480 320
place "$D" 1000 300 420 260
sleep 3
acted judge=no own=all

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

day_report
