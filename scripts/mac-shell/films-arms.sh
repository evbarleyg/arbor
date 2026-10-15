#!/bin/bash
# The same acts on the same Mac by Arbor as built from several commits, filmed: does a change show on a display, and which way?
#
#   scripts/mac-shell/rehearse.sh scripts/mac-shell/films-arms.sh     on Linux, first, for nothing (one arm, a test window for Safari)
#   scripts/mac-shell/run.sh scripts/mac-shell/films-arms.sh          about a quarter of an hour on a hosted Mac
#   scripts/polish/judge.py acts .mac-shell/films-arms-<run id>       anywhere, afterwards
#
# A count of requests on Linux says how often Arbor asks. It cannot say what a person sees: whether a Mac draws the state between two askings. So: one Safari window on a page of one flat
# colour, which the judge's ruler can follow; the acts by real keys, without motion; each arm's Arbor built here from its own commit, so that Mac, macOS, Safari and camera are the same for all;
# and macOS's own tiling of the same window, with no Arbor running, as the bar. What is counted, act by act: the frames in which the window is seen at the size of the end
# and the place of the start, or anywhere outside what its old frame and its new one cover.
#
# ARMS: name=commit, in the order they are played. `head` is the commit under test, whose build the harness has made anyway. A commit must be given in full: the Mac's clone is one commit deep.
ARMS="before=07b2bfc5da482ddcbfc25156abfddffc49f605ba head"
ARBOR_TIME_LIMIT=1150
source "$(dirname "$0")/lib-film.sh"
needs_throwaway_mac "film the whole display, open Safari, and build other commits in this clone"

LIGHT='{"animationDuration": 0, "focusRing": false, "menuBarControls": false}'
FACE="ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0"
ARMS_DIR="$ARBOR_ROOT/.build/arms"
HEAD_BIN=$ARBOR_BIN

# arm_build <name> <commit>: Arbor and arborctl as that commit has them, into $ARMS_DIR/<name>. In place, upon the build that is there: only what differs is compiled.
arm_build() {
  local name=$1 commit=$2 started=$SECONDS file
  [ "$commit" != head ] || return 0
  mkdir -p "$ARMS_DIR/$name"
  arms_restore
  git -C "$ARBOR_ROOT" fetch --quiet --depth 1 origin "$commit" || { echo "arm $name: $commit cannot be fetched"; return 1; }
  # Exactly that commit's sources: what has come since would not compile against them. Files that are the same keep their dates, so they are not compiled again.
  git -C "$ARBOR_ROOT" diff --name-only --diff-filter=A "$commit" HEAD -- Sources | while IFS= read -r file; do rm -f "$ARBOR_ROOT/$file"; done
  git -C "$ARBOR_ROOT" checkout --quiet "$commit" -- Sources Package.swift || { echo "arm $name: $commit cannot be checked out"; return 1; }
  if (cd "$ARBOR_ROOT" && swift build --product Arbor && swift build --product arborctl) > "$ARBOR_OUT/build-arm-$name.log" 2>&1; then
    cp "$HEAD_BIN/Arbor" "$HEAD_BIN/arborctl" "$ARMS_DIR/$name/"
    echo "arm $name: built ${commit:0:8} in $((SECONDS - started))s"
  else
    grep "error:" "$ARBOR_OUT/build-arm-$name.log" | sort -u | head -n 10
    echo "arm $name: ${commit:0:8} did not build"
    rm -rf "${ARMS_DIR:?}/$name"
  fi
}

# The clone as it was checked out. It is a throwaway Mac's: nothing of anybody's is in it.
arms_restore() { git -C "$ARBOR_ROOT" reset --quiet --hard HEAD; }

front() {
  local point
  point=$("$FILM_APPTOOL" grab "$SAFARI" 2>/dev/null | cut -d ' ' -f 1,2)
  [ -n "$point" ] || point=$(titlebar_of "$SAFARI")
  # shellcheck disable=SC2086
  click $point
  sleep 0.6
}

act() {
  scene "$1" instant "$2 ($3)"
  key "$3"
  scene_end 1.6
}

# The acts of one arm. A size that Arbor has not seen in this run is asked for differently from one it has: so every side once, then a quit and a launch, and the first side again.
play() {
  local arm=$1
  ARBOR_BIN="$ARMS_DIR/$arm"
  [ -n "${ARBOR_REHEARSAL:-}" ] && ARBOR_BIN=$HEAD_BIN
  arbor_settings "$LIGHT"
  ARBOR_EXTRA_PIDS=$SAFARI_PID
  arbor_start 1 $FACE
  [ -n "$SAFARI" ] || SAFARI=$W1
  sleep 3
  # The harness's own test window, out of the way.
  [ "$SAFARI" = "$W1" ] || tell 1 "move $W1 760 560 240 130"
  ctl trace on "arm-$arm" || true
  tell_safari_home
  front
  act "$arm-1-dock-left" "docks Safari at the left" ctrl+opt+cmd+left
  act "$arm-2-float" "floats it" ctrl+opt+f
  act "$arm-3-dock-right" "docks it at the right" ctrl+opt+cmd+right
  act "$arm-4-float" "floats it" ctrl+opt+f
  act "$arm-5-dock-top" "docks it at the top" ctrl+opt+cmd+up
  summary
  sleep 1
  ctl trace off || true
  scene "$arm-6-quit" instant "quits Arbor"
  ctl quit
  scene_end 1.6
  arbor_ended
  scene "$arm-7-launch" instant "starts Arbor again"
  arbor_relaunch
  scene_end 2.5
  front
  act "$arm-8-float" "floats it" ctrl+opt+f
  act "$arm-9-dock-left" "docks it at the left: the first dock after a launch" ctrl+opt+cmd+left
  summary
  arbor_stop
}

# Where every arm begins: floating, in the middle, at a size that is no slot's.
tell_safari_home() {
  ctl float-all
  sleep 1
  [ -n "${ARBOR_REHEARSAL:-}" ] || "$FILM_APPTOOL" set-frame "$SAFARI" 260 120 520 380 > /dev/null
  sleep 1.2
}

macos() {
  local name=$1 inner=$3
  front
  scene "$name" bare "$2"
  if [ -n "${ARBOR_REHEARSAL:-}" ]; then
    echo "> System Events: Safari: Move & Resize $inner (not rehearsed)"
  else
    arbor_within 10 osascript -e "tell application \"System Events\" to tell process \"Safari\" to click menu item \"$inner\" of menu 1 of menu item \"Move & Resize\" of menu \"Window\" of menu bar 1" \
      > /dev/null || echo "macos $name: System Events could not press $inner"
  fi
  scene_end 1.6
}

film_build
step "the arms"
# Now, while the build that is there is the commit's under test.
mkdir -p "$ARMS_DIR/head"
[ -n "${ARBOR_REHEARSAL:-}" ] || cp "$HEAD_BIN/Arbor" "$HEAD_BIN/arborctl" "$ARMS_DIR/head/" || die "no build of the commit under test"
PLAYED=""
for arm in $ARMS; do
  name=${arm%%=*} commit=${arm#*=}
  if [ -n "${ARBOR_REHEARSAL:-}" ]; then
    [ "$commit" = head ] && PLAYED="$PLAYED $name"
    continue
  fi
  # The films need five minutes: an arm that could not be built in time is left out, and said to be.
  if [ "$SECONDS" -gt 620 ] && [ "$commit" != head ]; then echo "arm $name: no time left to build it"; continue; fi
  arm_build "$name" "$commit"
  [ -x "$ARMS_DIR/$name/Arbor" ] && PLAYED="$PLAYED $name"
done
[ -n "${ARBOR_REHEARSAL:-}" ] || arms_restore
echo "arms:$PLAYED, after $SECONDS s"

step "the Mac"
pointer displays
macos_reduce_motion off
glass on
macos_tiling
wallpaper "#000000"
camera_start || die "no camera"
sampler_start
ARBOR_TEST_WINDOWS_ARGS="--regular"

step "the camera's own square"
metronome good

step "Safari, on a page of one colour"
SAFARI="" SAFARI_PID=""
if [ -z "${ARBOR_REHEARSAL:-}" ]; then
  scratch_dir arms-page PAGE_DIR
  printf '<!doctype html><title>page</title><body style="margin:0;background:#ff8d28"></body>\n' > "$PAGE_DIR/page.html"
  arbor_within 30 open -g -b com.apple.Safari "$PAGE_DIR/page.html" || die "Safari did not open"
  film_await 150 "$FILM_APPTOOL" pid com.apple.Safari > /dev/null || die "Safari did not start"
  SAFARI_PID=$("$FILM_APPTOOL" pid com.apple.Safari)
  started "$SAFARI_PID"
  "$FILM_APPTOOL" wait-window "$SAFARI_PID" 20
  SAFARI=$("$FILM_APPTOOL" windows "$SAFARI_PID" | awk '$3 == "AXStandardWindow" { print $1; exit }')
  [ -n "$SAFARI" ] || die "Safari has no window"
  echo "Safari: pid $SAFARI_PID, window $SAFARI"
  sleep 3
fi

for arm in $PLAYED; do
  step "arm $arm"
  play "$arm"
done

step "macOS alone, the same window: no Arbor is running"
[ -n "${ARBOR_REHEARSAL:-}" ] || "$FILM_APPTOOL" set-frame "$SAFARI" 260 120 520 380 > /dev/null
sleep 1.2
if [ -z "${ARBOR_REHEARSAL:-}" ]; then
  macos macos-left "chooses Window ▸ Move & Resize ▸ Left" "Left"
  macos macos-right "chooses Window ▸ Move & Resize ▸ Right" "Right"
  macos macos-top "chooses Window ▸ Move & Resize ▸ Top" "Top"
  macos macos-previous "chooses Window ▸ Move & Resize ▸ Return to Previous Size" "Return to Previous Size"
  "$FILM_APPTOOL" quit "$SAFARI_PID" > /dev/null 2>&1
  ended "$SAFARI_PID" 50 || kill_started "$SAFARI_PID"
fi

sampler_stop
camera_stop
