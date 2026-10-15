#!/bin/bash
# A probe, not a check: what does a window on its way out of macOS's full screen make of a frame it is asked for, and when?
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-full-screen.sh        on one of GitHub's Macs: six minutes
#
# THE QUESTION only a Mac can answer. A docked window that leaves full screen lands where macOS puts it (the frame it had before
# Arbor ever moved it) and goes to its slot a quarter of a second later: two moves. macOS reports the way out as over when
# it begins, 0.7 s before the window shows. Asked for its slot in that time, or before, does the window take it, does it keep
# it, and where does macOS's own animation go?
#
# Without Arbor: fsprobe.swift asks, at one moment per round (PROBE_MOMENTS: never, now = still in full screen, scaffold, left, landed,
# insist = at the report and every 100 ms until it is heard, which is what Arbor does and is played unless told otherwise), the sampler
# writes down every frame the window server showed, and a burst of pictures shows where the animation went.
# Then the same with Arbor: three apps docked, two of them into full screen and out again, four times each.
#
# What comes back: fsprobe-<app>-<n>-<when>.log, samples.log, day-report.md, burst/<app>-<n>-<when>-<ms>.jpg, traces/.
#
# Only on GitHub's Macs: it opens real apps, takes the whole display and changes its size.
source "$(dirname "${BASH_SOURCE[0]}")/lib-day.sh"
needs_throwaway_mac "open real apps, put them into full screen, and switch the display's size"

FSPROBE="$ARBOR_ROOT/.build/mac-shell/fsprobe"
# Where a tool puts the window before full screen, as Arbor puts one into its slot, and what it is asked for on the way out.
SLOT="800 60 620 640"
ROUND=0

bundle_of() {
  case "$1" in
    finder) echo com.apple.finder ;;
    safari) echo com.apple.Safari ;;
    textedit) echo com.apple.TextEdit ;;
  esac
}
window_of() { eval "echo \"\${W_$1:-}\""; }
pid_of() { eval "echo \"\${P_$1:-}\""; }
ms() { perl -MTime::HiRes=time -e 'printf "%d", time * 1000'; }
in_full_screen() { apptool describe "$1" 2>/dev/null | grep -q -i "full"; }

# Pictures as fast as they come, each named by the millisecond it was asked for.
burst() {
  local name=$1 count=$2
  mkdir -p "$ARBOR_OUT/burst"
  while [ "$count" -gt 0 ]; do
    screencapture -x -t jpg "$ARBOR_OUT/burst/$name-$(ms).jpg" 2>> "$ARBOR_OUT/screencapture.log"
    count=$((count - 1))
  done
}

reach() {
  act switch "reach-$1-$ROUND" "clicks $1's title bar, or its Dock icon if that is covered"
  click_window "$(window_of "$1")" || dock_click "$(bundle_of "$1")"
  acted judge=no
}

go_in() {
  local name=$1 window
  window=$(window_of "$name")
  act macos-own "$name-$ROUND-in" "presses ⌃⌘F in $name"
  key ctrl+cmd+f
  sleep 2.5
  acted moves=any leaves=any judge=no
  in_full_screen "$window" || { echo "  $name did not go into full screen: $(apptool describe "$window")"; return 1; }
}

# round <app> <when>
round() {
  local name=$1 when=$2 window pid probe shots tag
  ROUND=$((ROUND + 1))
  tag="$name-$ROUND-$when"
  window=$(window_of "$name")
  pid=$(pid_of "$name")
  step "$tag"
  echo "before: the window server has it at $(real_frame_of "$window")"
  # shellcheck disable=SC2086
  echo "a tool puts it at $SLOT; it takes $(apptool set-frame "$window" $SLOT)"
  reach "$name"
  go_in "$name" || return 1
  # shellcheck disable=SC2086
  "$FSPROBE" "$pid" "$window" "$when" $SLOT --other "$P_finder" --seconds 6 > "$ARBOR_OUT/fsprobe-$tag.log" 2>&1 8>&- 9>&- &
  probe=$!
  started "$probe"
  sleep 1
  act macos-own "$tag-out" "presses ⌃⌘F again; the window is asked for its slot: $when"
  burst "$tag" 16 8>&- 9>&- &
  shots=$!
  started "$shots"
  key ctrl+cmd+f
  ended "$probe" 80 || kill_started "$probe"
  ended "$shots" 50 || kill_started "$shots"
  acted moves=any leaves=any comes="$window"
  echo "after: the window server has it at $(real_frame_of "$window")"
  sed 's/^/    /' "$ARBOR_OUT/fsprobe-$tag.log"
}

# MARK: The Mac

apps_watchdog "${DAY_LIMIT:-900}"
step "the Mac"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m)"
mkdir -p "$(dirname "$FSPROBE")"
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/fsprobe.swift" -o "$FSPROBE" > "$ARBOR_OUT/build-fsprobe.log" 2>&1 \
  || { grep -A 6 "error:" "$ARBOR_OUT/build-fsprobe.log" | head -n 60; die "scripts/mac-shell/fsprobe.swift did not compile"; }
day_build
display_mode 1440x900 1600x900 1680x1050 1920x1080
# GitHub's Macs come with Reduce Motion on. A person's Mac does not, and the way out of full screen is another with it.
macos_reduce_motion off
apps_scratch
sampler_start
watch_start day-macos.log

chapter "The apps are open"
for name in finder safari textedit; do
  act open-close "open-$name" "opens $name"
  case "$name" in
    finder) APP_WAIT=25 meet finder "$(bundle_of finder)" "$APPS_SCRATCH/grove" ;;
    safari) APP_WAIT=25 meet safari "$(bundle_of safari)" "$APPS_SCRATCH/page.html" ;;
    textedit) APP_WAIT=25 meet textedit "$(bundle_of textedit)" "$APPS_SCRATCH/oak.txt" ;;
  esac
  app_dismiss "$APP_PID" || echo "a sheet or dialog stayed in the way"
  acted judge=no
done
[ -n "$W_finder" ] && [ -n "$W_safari" ] && [ -n "$W_textedit" ] || die "not all three apps opened a window"
sleep 2

if [ -z "${PROBE_ONLY_ARBOR:-}" ]; then
  chapter "Without Arbor: asked at one moment per round"
  for name in safari textedit; do
    for when in ${PROBE_MOMENTS:-insist insist insist}; do
      round "$name" "$when"
    done
  done
fi

if [ -z "${PROBE_WITHOUT_ARBOR:-}" ]; then
  chapter "With Arbor"
  act quit-and-start launch "starts Arbor"
  day_launch || die "Arbor did not start"
  acted judge=no
  ROUND=100
  reach finder
  act dock-key dock-finder-left "presses ⌃⌥⌘←"
  key ctrl+opt+cmd+left
  acted moves=any judge=no
  reach safari
  act dock-key dock-safari-right "presses ⌃⌥⌘→"
  key ctrl+opt+cmd+right
  acted moves=any judge=no
  reach textedit
  act dock-key dock-textedit-right "presses ⌃⌥⌘→"
  key ctrl+opt+cmd+right
  acted moves=any judge=no
  brief | sed 's/^/    /'
  for name in safari textedit safari textedit safari textedit safari textedit; do
    ROUND=$((ROUND + 1))
    chapter "With Arbor: $name, round $ROUND"
    reach "$name"
    go_in "$name" || continue
    act macos-own "$name-$ROUND-arbor-out" "presses ⌃⌘F again"
    burst "$name-$ROUND-arbor" 16 8>&- 9>&- &
    shots=$!
    started "$shots"
    key ctrl+cmd+f
    sleep 2
    ended "$shots" 50 || kill_started "$shots"
    acted moves=any leaves=any comes="$(window_of "$name")" front="$(window_of "$name")"
    brief | sed 's/^/    /'
  done
  act quit-and-start quit "quits Arbor"
  ctl quit
  want "Arbor ends within five seconds" day_gone
  acted moves=any judge=no
fi

for picture in "$ARBOR_OUT"/burst/*.jpg; do
  [ -f "$picture" ] && sips --resampleWidth 800 "$picture" > /dev/null 2>&1
done
DAY_KEEP_PICTURES="" day_report
# A probe has learnt something whatever it saw.
exit 0
