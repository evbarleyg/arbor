#!/bin/bash
# The same acts on the same Mac by Arbor as built from several commits, filmed: does a change show on a display, and which way?
#
#   scripts/mac-shell/rehearse.sh scripts/mac-shell/films-arms.sh     on Linux, first, for nothing (one arm, a test window for Safari)
#   scripts/mac-shell/run.sh scripts/mac-shell/films-arms.sh          about a quarter of an hour on a hosted Mac
#   scripts/polish/arms.py .mac-shell/films-arms-<run id> test|safari   anywhere, afterwards
#
# A count of requests on Linux says how often Arbor asks. It cannot say what a person sees: whether a Mac draws the state between two askings. That depends on how long the state lasts and on how
# fast the app draws. So the acts are played twice: on a test window, and on one Safari window on a page of one flat colour. By real keys, without motion; each arm's Arbor built here from its own commit, so that Mac, macOS, apps and camera are the same for all;
# and macOS's own tiling of the same Safari window, with no Arbor running, as the bar. What is counted, act by act: the frames in which the window is seen at the size of the end
# and the place of the start, or anywhere outside what its old frame and its new one cover.
#
# ARMS: name=commit, in the order they are played. `head` is the commit under test, whose build the harness has made anyway. A commit must be given in full: the Mac's clone is one commit deep.
# name=commit+commit is the first with, laid over it, the files that the second changed, those of the stand-ins (Sources/ArborTesting) left out, which are no part of the app: for two cures that have
# not been put together yet. It is played only if each of those files is the same in the first commit as in the second's parent, so that it is what any merge of the two would build the app from.
#   before  the trunk before sizes were asked for where a window stands
#   head    the trunk
#   asks    nobody in view is asked to grow where it stands (the controller)
#   order   between size and place a window lies within its old frame or its new one (the layer's order of calls)
#   both    the two together
ASKS=cc9df278a708ecf06c2237cee8e0fab6479e3a13
ORDER=1cab79797b5c216d8314dfaaaf40b3932fed13e9
ARMS="before=07b2bfc5da482ddcbfc25156abfddffc49f605ba head asks=$ASKS order=$ORDER both=$ASKS+$ORDER"
ARBOR_TIME_LIMIT=1150
source "$(dirname "$0")/lib-film.sh"
needs_throwaway_mac "film the whole display, open Safari, and build other commits in this clone"

LIGHT='{"animationDuration": 0, "focusRing": false, "menuBarControls": false}'
FACE="ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0"
ARMS_DIR="$ARBOR_ROOT/.build/arms"
HEAD_BIN=$ARBOR_BIN

# arm_build <name> <commit>: Arbor and arborctl as that commit has them, into $ARMS_DIR/<name>. In place, upon the build that is there: only what differs is compiled.
arm_build() {
  local name=$1 commit=${2%%+*} over="" started=$SECONDS file
  [ "$commit" != head ] || return 0
  case "$2" in *+*) over=${2#*+} ;; esac
  mkdir -p "$ARMS_DIR/$name"
  arms_restore
  git -C "$ARBOR_ROOT" fetch --quiet --depth 1 origin "$commit" || { echo "arm $name: $commit cannot be fetched"; return 1; }
  # Exactly that commit's sources: what has come since would not compile against them. Files that are the same keep their dates, so they are not compiled again.
  git -C "$ARBOR_ROOT" diff --name-only --diff-filter=A "$commit" HEAD -- Sources | while IFS= read -r file; do rm -f "$ARBOR_ROOT/$file"; done
  git -C "$ARBOR_ROOT" checkout --quiet "$commit" -- Sources Package.swift || { echo "arm $name: $commit cannot be checked out"; return 1; }
  if [ -n "$over" ]; then
    git -C "$ARBOR_ROOT" fetch --quiet --depth 2 origin "$over" || { echo "arm $name: $over cannot be fetched"; return 1; }
    for file in $(git -C "$ARBOR_ROOT" diff --name-only "$over~1" "$over" -- Sources ':!Sources/ArborTesting'); do
      git -C "$ARBOR_ROOT" diff --quiet "$commit" "$over~1" -- "$file" || { echo "arm $name: both commits change $file: they are for their authors to put together"; return 1; }
      git -C "$ARBOR_ROOT" checkout --quiet "$over" -- "$file" || { echo "arm $name: $file of $over cannot be checked out"; return 1; }
      echo "arm $name: $file is ${over:0:8}'s"
    done
  fi
  if (cd "$ARBOR_ROOT" && swift build --product Arbor && swift build --product arborctl) > "$ARBOR_OUT/build-arm-$name.log" 2>&1; then
    cp "$HEAD_BIN/Arbor" "$HEAD_BIN/arborctl" "$ARMS_DIR/$name/"
    echo "arm $name: built ${commit:0:8}${over:+ with ${over:0:8}} in $((SECONDS - started))s"
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
  point=$("$FILM_APPTOOL" grab "$TARGET" 2>/dev/null | cut -d ' ' -f 1,2)
  [ -n "$point" ] || point=$(titlebar_of "$TARGET")
  # shellcheck disable=SC2086
  click $point
  sleep 0.6
}

# act <name> "<what the person does>" <command…>: by the key that does it in that arm's own map; where none does, by the command, which no camera can time.
act() {
  local name=$1 text=$2 chord
  shift 2
  chord=$(key_for "$@")
  if [ -n "$chord" ]; then
    scene "$name" instant "$text ($chord)"
    key "$chord"
  else
    scene "$name" told "$text (no key does: the command)"
    ctl "$@"
  fi
  scene_end 1.6
}

# Where every playing begins: floating, in the middle, at a size that is no slot's.
home() {
  ctl float-all
  sleep 1
  if [ "$TARGET" = "$W1" ]; then
    tell 1 "move $W1 260 120 574 380"
  else
    "$FILM_APPTOOL" set-frame "$TARGET" 260 120 574 380 > /dev/null
    # The harness's own test window, out of the way.
    tell 1 "move $W1 760 560 240 130"
  fi
  sleep 1.2
}

# play <arm> test|safari: the acts of one arm on one window. A size that Arbor has not seen in this run is asked for differently from one it has: so every side once, then a quit and a launch,
# and the first side again.
play() {
  local arm=$1 cast=$2 p="$1-$2"
  # A playing takes about a minute. One that is cut off by the time limit would take the films of all the others with it.
  if [ "$SECONDS" -gt $((ARBOR_TIME_LIMIT - 130)) ]; then echo "arm $arm, $cast: NOT PLAYED, no time left"; return 0; fi
  ARBOR_BIN="$ARMS_DIR/$arm"
  [ -n "${ARBOR_REHEARSAL:-}" ] && ARBOR_BIN=$HEAD_BIN
  arbor_settings "$LIGHT"
  ARBOR_EXTRA_PIDS=""
  [ "$cast" = test ] || ARBOR_EXTRA_PIDS=$SAFARI_PID
  arbor_start 1 $FACE
  TARGET=$W1
  [ "$cast" = test ] || [ -z "$SAFARI" ] || TARGET=$SAFARI
  sleep 3
  ctl trace on "arm-$p" || true
  home
  front
  act "$p-1-dock-left" "docks it at the left" dock left
  act "$p-2-float" "floats it" toggle-float
  act "$p-3-dock-right" "docks it at the right" dock right
  act "$p-4-float" "floats it" toggle-float
  act "$p-5-dock-top" "docks it at the top" dock top
  summary
  sleep 1
  ctl trace off || true
  scene "$p-6-quit" told "quits Arbor"
  ctl quit
  scene_end 1.6
  arbor_ended
  scene "$p-7-launch" told "starts Arbor again"
  arbor_relaunch
  scene_end 2.5
  front
  act "$p-8-float" "floats it" toggle-float
  act "$p-9-dock-left" "docks it at the left: the first dock after a launch" dock left
  summary
  arbor_stop
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
  # The films need a minute for each playing: an arm that could not be built in time is left out, and said to be.
  if [ "$SECONDS" -gt 480 ] && [ "$commit" != head ]; then echo "arm $name: NOT BUILT, no time left"; continue; fi
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

SAFARI="" SAFARI_PID="" TARGET=""
for arm in $PLAYED; do
  step "arm $arm, a test window"
  play "$arm" test
done

step "Safari, on a page of one colour"
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
  step "arm $arm, Safari"
  play "$arm" safari
done

step "macOS alone, the same window: no Arbor is running"
TARGET=$SAFARI
[ -n "${ARBOR_REHEARSAL:-}" ] || "$FILM_APPTOOL" set-frame "$SAFARI" 260 120 574 380 > /dev/null
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
