#!/bin/bash
# The same acts on the same Mac by Arbor as built from several commits, filmed: does a change show on a display, and which way?
#
#   scripts/mac-shell/rehearse.sh scripts/mac-shell/films-arms.sh     on Linux, first, for nothing (one arm, a test window for Safari)
#   scripts/mac-shell/run.sh scripts/mac-shell/films-arms.sh          about a quarter of an hour on a hosted Mac
#   scripts/polish/arms.py .mac-shell/films-arms-<run id> test|safari|crowd|apps   anywhere, afterwards
#
# A count of requests on Linux says how often Arbor asks. It cannot say what a person sees: whether a Mac draws the state between two askings. That depends on how long the state lasts and on how
# fast the app draws. So the acts are played twice: on a test window, and on one Safari window on a page of one flat colour. By real keys, without motion; each arm's Arbor built here from its own commit, so that Mac, macOS, apps and camera are the same for all;
# and macOS's own tiling of the same Safari window, with no Arbor running, as the bar. What is counted, act by act: the frames in which the window is seen at the size of the end
# and the place of the start, or anywhere outside what its old frame and its new one cover.
#
# ARMS: name=commit, in the order they are played. `head` is the commit under test, whose build the harness has made anyway. A commit must be given in full: the Mac's clone is one commit deep.
# name=commit+commit is the first with, laid over it, the files that the second changed, those of the stand-ins (Sources/ArborTesting) left out, which are no part of the app: for two cures that have
# not been put together yet. It is played only if each of those files is the same in the first commit as in the second's parent, so that it is what any merge of the two would build the app from.
ARMS="base=7bd65058bb96f37b81624aba645f86b036d7206d orders=43d9145153b6d39ac4a345f2f2174a459c26ed35 barrier=075199b018d5cfa4ef2a7a34c46690afe4e76085"
# PLAYS: what every arm plays.
#   test, safari   nine acts on one window: every side once, a quit and a launch, the first side again
#   crowd, apps    many windows, eight test windows or six real apps and a test window, on a large display: Arrange, fill, everything, back, ROUNDS times over. How many frames a state is on the display
#                  is chance, so whoever compares frames plays each arm five times; and the first round of a session is kept apart, since what is done for the first time differs.
PLAYS="crowd apps"
ROUNDS=5
ARBOR_TIME_LIMIT=1800
source "$(dirname "$0")/lib-film.sh"
needs_throwaway_mac "film the whole display, open Safari, and build other commits in this clone"

# The same in every arm, whatever each ships: the five switches of the second build (`second_build` in lib-film.sh), so that the ground between the windows is the bare wallpaper.
LIGHT='{"animationDuration": 0, "focusRing": false, "menuBarControls": false, "dimBehindArranged": 0, "desktopEdge": 0}'
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
  scene_end "${REST:-1.6}"
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

# open_real <bundle id> [<file>]: a real app with one window, for `apps`. Its process goes into REAL_PIDS, its window into REAL_WINDOWS.
open_real() {
  local bundle=$1 pid window
  shift
  arbor_within 30 open -g -b "$bundle" "$@" || { echo "$bundle did not open"; return 1; }
  film_await 150 "$FILM_APPTOOL" pid "$bundle" > /dev/null || { echo "$bundle did not start"; return 1; }
  pid=$("$FILM_APPTOOL" pid "$bundle")
  started "$pid"
  "$FILM_APPTOOL" wait-window "$pid" 25 > /dev/null
  window=$("$FILM_APPTOOL" windows "$pid" | awk '$3 == "AXStandardWindow" { print $1; exit }')
  [ -n "$window" ] || { echo "$bundle has no window"; return 1; }
  REAL_PIDS="${REAL_PIDS:+$REAL_PIDS,}$pid"
  REAL_WINDOWS="$REAL_WINDOWS $window"
  echo "$bundle: pid $pid, window $window"
}

# play_many <arm> crowd|apps
play_many() {
  local arm=$1 cast=$2 p="$1-$2" round REST=1.3
  # A playing takes about two minutes.
  if [ "$SECONDS" -gt $((ARBOR_TIME_LIMIT - 190)) ]; then echo "arm $arm, $cast: NOT PLAYED, no time left"; return 0; fi
  ARBOR_BIN="$ARMS_DIR/$arm"
  [ -n "${ARBOR_REHEARSAL:-}" ] && ARBOR_BIN=$HEAD_BIN
  arbor_settings "$LIGHT"
  if [ "$cast" = crowd ] || [ -z "$REAL_PIDS" ]; then
    cast_start 8 $FACE
    TARGET=$W8
  else
    ARBOR_EXTRA_PIDS=$REAL_PIDS
    arbor_start 1 $FACE
    ctl trace on "arm-$p" || true
    # shellcheck disable=SC2086
    set -- $REAL_WINDOWS
    TARGET=${1:-$W1}
  fi
  sleep 3
  round=1
  while [ "$round" -le "$ROUNDS" ]; do
    ctl float-all
    sleep 1.5
    # On top of the pile, so that the click meets it and no other: the same window fills in every round.
    [ "$TARGET" != "${W8:-}" ] || tell 8 "front $W8"
    front
    act "$p-$round-arrange" "arranges every window" arrange
    act "$p-$round-fill" "fills the screen with one of them" zoom
    act "$p-$round-everything" "shows everything again" show-all
    key "$(key_for zoom)"
    sleep 1.3
    act "$p-$round-back" "goes back" back
    round=$((round + 1))
  done
  summary
  if [ "$cast" = crowd ] || [ -z "$REAL_PIDS" ]; then
    cast_stop
  else
    ctl trace off || true
    arbor_stop
  fi
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
cast_build
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
  if [ "$SECONDS" -gt 700 ] && [ "$commit" != head ]; then echo "arm $name: NOT BUILT, no time left"; continue; fi
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

plays() { case " $PLAYS " in *" $1 "*) return 0 ;; esac; return 1; }

# The bare desk: the wallpaper as the display shows it.
scene ground bare "the bare desk"
scene_end 0.3

safari_opens() {
  [ -z "$SAFARI" ] && [ -z "${ARBOR_REHEARSAL:-}" ] || return 0
  scratch_dir arms-page PAGE_DIR
  printf '<!doctype html><title>page</title><body style="margin:0;background:#ff8d28"></body>\n' > "$PAGE_DIR/page.html"
  open_real com.apple.Safari "$PAGE_DIR/page.html" || die "no Safari"
  SAFARI_PID=$REAL_PIDS
  SAFARI=${REAL_WINDOWS# }
  sleep 3
}

# In this order, so that nothing lies on the desk that is not played: a window that nobody manages would show where the others have left, and hide a hole.
SAFARI="" SAFARI_PID="" TARGET="" REAL_PIDS="" REAL_WINDOWS=""
if plays test; then
  for arm in $PLAYED; do
    step "arm $arm, a test window"
    play "$arm" test
  done
fi

if plays crowd; then
  display_size 1920 1080
  for arm in $PLAYED; do
    step "arm $arm, eight test windows"
    play_many "$arm" crowd
  done
  display_size 1024 768
fi

if plays safari; then
  step "Safari, on a page of one colour"
  safari_opens
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
  fi
fi

if plays apps; then
  step "six real apps, on a ground that no app has"
  display_size 1920 1080
  # Black is what a dark window is made of, and grey what a light one is: on either a window could pass for the ground.
  wallpaper "#ff00c8"
  scene apps-ground bare "the bare desk"
  scene_end 0.3
  safari_opens
  if [ -z "${ARBOR_REHEARSAL:-}" ]; then
    printf 'An oak.\n' > "$PAGE_DIR/oak.txt"
    printf 'return 1\n' > "$PAGE_DIR/one.applescript"
    python3 -c 'import struct, sys, zlib
row = b"\0" + bytes((0, 136, 255)) * 400
data = zlib.compress(row * 300)
def chunk(kind, body): return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))
open(sys.argv[1], "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 400, 300, 8, 2, 0, 0, 0)) + chunk(b"IDAT", data) + chunk(b"IEND", b""))' "$PAGE_DIR/blue.png"
    # One that does not come is left out, and said to be: the arms are still alike.
    open_real com.apple.TextEdit "$PAGE_DIR/oak.txt"
    open_real com.apple.Terminal
    open_real com.apple.Preview "$PAGE_DIR/blue.png"
    open_real com.apple.ScriptEditor2 "$PAGE_DIR/one.applescript"
    open_real com.apple.ActivityMonitor
    sleep 3
  fi
  for arm in $PLAYED; do
    step "arm $arm, real apps"
    play_many "$arm" apps
  done
  wallpaper "#000000"
  display_size 1024 768
fi

for pid in $(echo "$REAL_PIDS" | tr ',' ' '); do
  "$FILM_APPTOOL" quit "$pid" > /dev/null 2>&1
  ended "$pid" 30 || kill_started "$pid"
done

sampler_stop
camera_stop
