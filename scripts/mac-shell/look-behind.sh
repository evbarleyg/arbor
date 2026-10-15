#!/bin/bash
# Out of view: behind, or away? The same few minutes with real apps, played either way, for pictures and films to lay side by side
# (the trial `outOfViewIsBehind`; collab/QUESTIONS.md, Q29, point 8).
#
#   scripts/mac-shell/run.sh --priority 1 scripts/mac-shell/look-away.sh scripts/mac-shell/look-behind.sh     one Mac, one build, ten minutes
#
# What only a Mac can say, and this asks:
# - filled and back, two of four framed: which windows does the window server see move, and how often? What is to be seen meanwhile (the films)?
# - does Accessibility's raise bring what is framed in front of what is left behind, also when the keyboard was in a window that goes behind?
# - what shows through: a gap that was moved by hand, and a window that cannot grow, framed. What does a click there do, either way?
# - what do ⌘Tab and Mission Control show, either way?
# - a display that goes and comes back, and an Arbor that is killed: where is every window then?
# - what breaks: the Desktop, tiles.
#
# What comes back: <nnn>-<slug>.jpg for every step, under the same names either way; <slug>.mov; stack-<nnn>.txt, the cast from the front to the back as the
# window server has it, with frames; day-report.md, which says for every step what moved and how often; the traces.
#
# LOOK=away (look-away.sh) plays it as Arbor ships. The rest of the settings are the second build's as far as this commit has them: no motion, no ring,
# one icon. A rehearsal (rehearse.sh) plays the same lines on test windows, which proves the script and nothing else.
#
# Only on GitHub's Macs: it opens real apps and Mission Control, presses ⌘Tab, plugs a virtual display in and out and kills Arbor.
LOOK=${LOOK:-behind}
DAY_KEEP_PICTURES=1
ARBOR_TIME_LIMIT=560

if [ -z "${ARBOR_REHEARSAL:-}" ]; then
  source "$(dirname "${BASH_SOURCE[0]}")/lib-day.sh"
else
  # The fake Mac has no real apps and no sampler. The steps are the same; what judges them is left out.
  ARBOR_SECOND_APP=2
  source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
  DAY_STEP=0
  chapter() { step "$*"; }
  act() { DAY_STEP=$((DAY_STEP + 1)); DAY_SLUG=$2; echo "-- $DAY_STEP $2: $3"; }
  acted() { shot "$(printf '%03d-%s' "$DAY_STEP" "$DAY_SLUG")" > /dev/null; }
  cmd_tab() { key cmd+tab; }
  snap_now() { shot "$1" > /dev/null; }
  day_report() { :; }
fi
needs_throwaway_mac "open real apps and Mission Control, press ⌘Tab, plug a virtual display in and out, and kill Arbor"

case "$LOOK" in
  behind) SWITCH=true ;;
  away) SWITCH=false ;;
  *) die "LOOK is behind or away, not $LOOK" ;;
esac
SETTINGS="{\"outOfViewIsBehind\": $SWITCH, \"animationDuration\": 0, \"focusRing\": false, \"menuBarControls\": false}"

# The cast from the front to the back, as the window server has it: id x y w h. Beside the step's picture, under its number.
stack() {
  pointer windows --on-screen | awk -v cast=" $A $B $C $D $E " 'index(cast, " " $1 " ") { print $1, $4, $5, $6, $7 }' \
    > "$ARBOR_OUT/$(printf 'stack-%03d' "$DAY_STEP").txt"
  sed 's/^/     /' "$ARBOR_OUT/$(printf 'stack-%03d' "$DAY_STEP").txt"
}
# A step's end: the picture, and the pile.
seen() { acted "$@"; stack; }

# So many seconds of the screen as a film, from now on: mac-shell/<name>.mov. What is filmed is played after a moment, so that the film has a beginning.
REEL=""
reel() {
  [ -z "${ARBOR_REHEARSAL:-}" ] || return 0
  arbor_may_shoot "$1" > /dev/null || return 0
  screencapture -x -v -V "$2" "$ARBOR_OUT/$1.mov" 2>> "$ARBOR_OUT/screencapture.log" 5<&- 6>&- 8>&- 9>&- &
  REEL=$!
  started "$REEL"
  sleep 1
}
reel_ends() {
  [ -n "$REEL" ] || return 0
  ended "$REEL" 120 || echo "the film did not end"
  REEL=""
}

mission_control() {
  if [ -z "${ARBOR_REHEARSAL:-}" ]; then open -a "Mission Control"; fi
  sleep 2
  snap_now "$(printf '%03d-%s' "$DAY_STEP" "$DAY_SLUG")" > /dev/null
  key escape
  sleep 1
}

launch() {
  if [ -z "${ARBOR_REHEARSAL:-}" ]; then day_launch; else arbor_relaunch; fi
}

# MARK: The Mac, the cast, Arbor

if [ -z "${ARBOR_REHEARSAL:-}" ]; then
  apps_watchdog 540
  echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m); out of view is $LOOK"
  day_build
  display_mode 1440x900 1600x900 1680x1050 1920x1080
  # GitHub's Macs come with Reduce Transparency on. A person's Mac does not, and there a sidebar takes its tint from what lies behind the window.
  if arbor_may "switch Reduce Transparency off"; then defaults write com.apple.universalaccess reduceTransparency -bool false; fi
  day_scratch
  sampler_start
  chapter "Before Arbor: five apps are open"
  act open-close open-safari "opens Safari";          meet safari com.apple.Safari "$DAY_DOCUMENTS/$APPS_CANARY-page.html";  acted judge=no
  act open-close open-textedit "opens TextEdit";      meet textedit com.apple.TextEdit "$DAY_DOCUMENTS/$APPS_CANARY-oak.txt";  acted judge=no
  act open-close open-finder "opens a folder";        meet finder com.apple.finder "$DAY_DOCUMENTS/$APPS_CANARY-grove";  acted judge=no
  act open-close open-terminal "opens Terminal";      meet terminal com.apple.Terminal;  acted judge=no
  act open-close open-calculator "opens Calculator";  meet calculator com.apple.calculator;  acted judge=no
  A=$W_safari B=$W_textedit C=$W_finder D=$W_terminal E=$W_calculator
  [ -n "$A" ] && [ -n "$B" ] && [ -n "$C" ] && [ -n "$D" ] && [ -n "$E" ] || die "one of the five apps opened no window"
  arbor_settings "$SETTINGS"
  # No welcome window, no keys of Arbor's: the look is at windows, and every act is a command, the same either way.
  DAY_FACE="ARBOR_NO_PROMPT=1"
  act quit-and-start launch "starts Arbor";  day_launch;  acted
else
  arbor_build
  arbor_settings "$SETTINGS"
  arbor_start 3
  A=$W1 B=$W2 C=$V1 D=$V2 E=$W3
fi
echo "the cast: Safari $A, TextEdit $B, a folder $C, Terminal $D; Calculator $E floats"

chapter "Arranged: Safari over TextEdit, a folder over Terminal; Calculator floats"
act dock-key arranged "docks four, two and two"
ctl dock "$A" left
ctl dock "$C" beside "$A" right
ctl dock "$B" beside "$A" bottom
ctl dock "$D" beside "$C" bottom
seen moves=docked

chapter "Filled, and back"
act switch click-safari "clicks Safari";  click_window "$A";  seen front="$A"
reel fill-and-back 7
act view filled "fills the screen with Safari";  ctl zoom;  seen moves=docked front="$A"
act view back "and comes back";  ctl zoom;  seen moves=docked front="$A"
reel_ends

chapter "Filled: what macOS's own means find"
act view filled-again "fills the screen with Safari again";  ctl zoom;  seen moves=docked front="$A"
act macos-own filled-mission-control "opens Mission Control, looks, and leaves it";  mission_control;  acted judge=no audit=no
act switch filled-cmd-tab-held "holds ⌘ and presses ⇥"
key cmd+tab --down
sleep 0.6
snap_now "$(printf '%03d-%s' "$DAY_STEP" switcher)" > /dev/null
key cmd+tab --up
seen moves=docked
act view everything "shows everything";  ctl show-all;  seen moves=docked

chapter "Two of four"
act switch click-safari-2 "clicks Safari";  click_window "$A";  seen front="$A"
act view filled-3 "fills the screen with it";  ctl zoom;  seen moves=docked front="$A"
reel two-of-four 5
act view two-of-four "steps out: Safari and TextEdit";  ctl out;  seen moves=docked front="$A"
reel_ends
ctl save-view 1
act macos-own two-mission-control "opens Mission Control, looks, and leaves it";  mission_control;  acted judge=no audit=no
act view everything-2 "shows everything";  ctl show-all;  seen moves=docked

chapter "The keyboard is in a window that goes behind"
# In Terminal, bottom right, which TextEdit is about to grow over; and of the two that are framed Safari was used last, so Safari gets the keyboard.
# A Mac's raise lifts a window over everything but the one that has the keyboard: is TextEdit in front of Terminal in the end, and how long is it not?
act switch click-terminal "clicks Terminal";  click_window "$D";  seen front="$D"
reel keyboard-behind 5
act view two-of-four-from-outside "goes to the saved view: Safari and TextEdit";  ctl view 1;  seen moves=docked
reel_ends
act view everything-3 "shows everything";  ctl show-all;  seen moves=docked

chapter "What shows through, and a click on it"
act resize gap-moved "makes the folder taller, so that the gaps no longer line up";  ctl resize "$C" bottom 90;  seen moves=docked
# Where the folder stands now is where it is left, or is not.
take "fx fy fw fh" real_frame_of "$C"
act view two-of-four-strip "goes to Safari and TextEdit: a strip of the folder lies in the gap between them, or the wallpaper does";  ctl view 1;  seen moves=docked
# The middle of the gap below Safari, above the middle of the folder as it stood.
take "x y w h" real_frame_of "$A"
px=$((fx + fw / 2)) py=$((y + h + ARBOR_GAP / 2))
reel click-in-the-gap 5
act switch click-in-the-gap "clicks in the gap between them";  click "$px" "$py";  seen moves=docked
reel_ends
summary
# As a Mac comes, a click on the wallpaper sweeps every window aside, and the next one brings them back.
act switch click-again "clicks there again";  click "$px" "$py";  seen moves=docked
act view everything-4 "shows everything";  ctl show-all;  seen moves=docked
act dock-key calculator-docked "docks Calculator at the right";  ctl dock "$E" right;  seen moves=docked
act view calculator-framed "frames Calculator, which cannot grow";  ctl zoom "$E";  seen moves=docked front="$E"
take "x y w h" real_frame_of "$E"
px=$((x - 160))
[ "$px" -gt 40 ] || px=40
act switch click-beside-calculator "clicks a hand's breadth to the left of it";  click "$px" "$((y + h / 2))";  seen moves=docked
summary
act view everything-5 "shows everything";  ctl show-all;  seen moves=docked
act dock-key calculator-floats "floats Calculator again";  ctl float "$E";  seen moves=docked,$E

chapter "What breaks: the Desktop, tiles"
act view desktop "shows the Desktop";  ctl desktop;  seen moves=docked
act view everything-6 "shows everything";  ctl show-all;  seen moves=docked
act view tiles "no window narrower than 900 points is shown: all are tiles";  ctl set minimumUsableWidth 900;  seen moves=docked tiles=ok
act view no-tiles "and back";  ctl reset minimumUsableWidth;  seen moves=docked

# The fake Mac has one display.
if [ -z "${ARBOR_REHEARSAL:-}" ]; then
chapter "A display that goes"
act display-change plugged "plugs a second display in";  display_add 1280 800 right;  seen moves=docked
act view sent-across "sends the folder and Terminal there";  ctl move-to-display next "$C";  ctl move-to-display next "$D";  seen moves=docked
act view filled-there "fills that display with the folder, and this one with Safari";  ctl zoom "$C";  ctl zoom "$A";  seen moves=docked
panorama "$(printf '%03d-both-displays' "$DAY_STEP")" > /dev/null
act display-change unplugged "pulls the cable";  display_remove;  seen moves=all
summary
act display-change plugged-again "plugs it in again";  display_add 1280 800 right;  seen moves=all
panorama "$(printf '%03d-both-displays' "$DAY_STEP")" > /dev/null
act display-change unplugged-again "and pulls it for good";  display_remove;  seen moves=all
act view everything-7 "shows everything, everywhere";  ctl home;  seen moves=docked
fi

chapter "Arbor is killed"
act switch click-safari-3 "clicks Safari";  click_window "$A";  seen front="$A"
act view filled-4 "fills the screen with it";  ctl zoom;  seen moves=docked front="$A"
act quit-and-start killed "Arbor is killed, as by a crash: this is what its person is left with";  arbor_kill;  seen judge=no audit=no
act macos-own killed-mission-control "opens Mission Control, looks, and leaves it";  mission_control;  acted judge=no audit=no
act quit-and-start started-again "starts Arbor again";  launch;  seen moves=docked
act view everything-8 "shows everything";  ctl show-all;  seen moves=docked

chapter "Quit"
act view filled-5 "fills the screen with Safari";  ctl zoom "$A";  seen moves=docked
act quit-and-start quit "quits Arbor";  arbor_quit;  seen judge=no audit=no
day_report
exit 0
