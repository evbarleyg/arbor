#!/bin/bash
# A docked window that is left to macOS, at macOS's defaults, with test windows and then with real TextEdit and Safari (board 1.56 and 1.67;
# QUESTIONS Q23).
#
# What only a Mac can say: whether macOS takes a window or leaves it alone, and what the window is like afterwards. The script does not know
# beforehand what macOS will do. It goes by whether Arbor says in its log that it gave the window its own size, and holds Arbor to the one or
# the other:
#   left alone (Arbor sized it):      its own size, at least half of it in view, out of the arrangement;
#   taken (moved or sized by macOS):  it stays as macOS made it.
# Never: as large as its slot for good. Three roads: thrown into the menu bar and let go at once; carried out and let go with ⌥ and nothing else
# held (every event of the drag carries it, as a hand's would); rested in the menu bar. After each, Float All, and off the tile if macOS made
# one. At the end a throw, and Quit at once. With the test window and TextEdit, besides: let go with ⌥ at four heights, the lower ones so that its own frame hangs
# over the Dock, and beside each the control, the same window dragged out with ⌘ and let go at the same point, which takes its own size at the
# drop by the same call. What a window takes depends on where it stands.
# Sizes are the window server's. WHEN Arbor set which frame is in the trace that comes back (mac-shell/traces/): no setFrame on the window
# within 0.5 s of the mouse-up, and one after it or none.
source "$(dirname "$0")/lib-apps.sh"
export ARBOR_RECORD=1

size_of() { real_frame_of "$1" | awk '{ printf "%d %d", $3 + 0.5, $4 + 0.5 }'; }
same_size() { local a b c d; read -r a b <<< "$1"; read -r c d <<< "$2"; about "$a" "$c" && about "$b" "$d"; }
has_size() { same_size "$(size_of "$1")" "$2"; }
differ() { ! same_size "$1" "$2"; }
# How often Arbor has said that it gave <window> its own size out of a slot.
sizings() { grep -c "w$1 is out of its slot and took its own size" "$ARBOR_HOME/arbor.log" 2> /dev/null || true; }
half_in_view() {
  local share
  share=$(arbor_share_in_view "$1") || return 1
  [ "$share" -ge 50 ] || { echo "only $share % of it is to be seen: $(real_frame_of "$1")"; return 1; }
}

# grab <window>: a point of its title bar that can be pressed, into GX GY.
grab() {
  local role
  if [ "$KIND" = test ]; then
    take "GX GY" titlebar_of "$1"
    return 0
  fi
  read -r GX GY role <<< "$(apptool grab "$1" 2> /dev/null)"
  if [ -z "${GX:-}" ]; then
    apptool raise "$1"
    sleep 0.3
    read -r GX GY role <<< "$(apptool grab "$1" 2> /dev/null)"
  fi
  [ -n "${GX:-}" ]
}

# Not inside `check`, which runs what it is given in a shell of its own.
take_hold() {
  GX="" GY=""
  grab "$1"
  check "its title bar can be grabbed" test -n "$GX"
}

# From GX GY: carried out of its slot, so that Arbor has seen the drag, then into the menu bar in one leap and let go 0.05 s later. macOS fills the
# screen only for a pointer that has rested there for 0.1 to 0.2 s.
throw() {
  drag "$GX" "$GY" 512 220 --no-release
  release 512 8
}

both_docked() {
  ctl float-all > /dev/null
  sleep 1
  ctl dock "$A" left
  ctl dock "$B" right
  # Room is made for a wide window a moment after it is docked.
  eventually in_view "$A" || true
  eventually in_view "$B" || true
  sleep 1.5
}

# judge <words> <window> <own size> <slot's size> <sizings before>: two seconds after it was let go.
judge() {
  local words=$1 window=$2 own=$3 slot=$4 before=$5 made
  sleep 2
  made=$(size_of "$window")
  check "$words: it is out of the arrangement" is floating "$window"
  check "$words: it is not as large as its slot ($slot): $(real_frame_of "$window")" differ "$made" "$slot"
  if [ "$(sizings "$window")" != "$before" ]; then
    echo "$words: macOS LEFT IT ALONE, and Arbor sized it; it is at $(real_frame_of "$window")"
    check "$words: left alone, it has its own size, $own" has_size "$window" "$own"
    check "$words: left alone, at least half of it is in view" half_in_view "$window"
    made=$own
  else
    echo "$words: macOS TOOK IT; it is at $(real_frame_of "$window")"
    check "$words: taken, it stays as macOS made it" stays has_size "$window" "$made"
  fi
  ctl float-all
  sleep 1
  check "$words: Float All leaves it that size: $(size_of "$window")" has_size "$window" "$made"
  # (A tile as large as its own size: there is nothing to tell apart.)
  same_size "$made" "$own" && return 0
  # Off its tile: macOS gives it the size it took it at, which was the slot's and nobody's choice.
  claim "$words: it is dragged off macOS's tile and let go over the middle of the screen"
  take_hold "$window"
  drag "$GX" "$GY" 500 320 --hold 0.5
  sleep 2
  check "off its tile it has its own size, $own, not the slot's, $slot: $(real_frame_of "$window")" has_size "$window" "$own"
}

# roads <name> <window>: $A and $B are the two windows, of which it is one.
roads() {
  local name=$1 window=$2 own slot before
  ctl float-all > /dev/null
  sleep 1
  own=$(size_of "$window")
  echo "== $name: w$window, its own size $own"

  claim "$name, docked, is thrown into the menu bar and let go at once"
  both_docked
  slot=$(size_of "$window")
  check "docked, it is as large as its slot ($slot), which is not its own size" differ "$slot" "$own"
  take_hold "$window"
  before=$(sizings "$window")
  throw
  judge "$name thrown" "$window" "$own" "$slot" "$before"

  claim "$name, docked, is carried out and let go with ⌥ and nothing else held"
  both_docked
  slot=$(size_of "$window")
  take_hold "$window"
  before=$(sizings "$window")
  drag "$GX" "$GY" 512 200 --hold 0.8 --mods opt
  judge "$name with ⌥" "$window" "$own" "$slot" "$before"

  claim "$name, docked, rests in the menu bar for a second and is let go"
  both_docked
  slot=$(size_of "$window")
  take_hold "$window"
  before=$(sizings "$window")
  drag "$GX" "$GY" 512 4 --hold 1.2
  judge "$name rested" "$window" "$own" "$slot" "$before"
}

# heights <name> <window>: what it takes depends on where it stands. Each round begins with the size it floats at just then.
heights() {
  local name=$1 window=$2 y key own
  for y in 150 300 320 420; do
    for key in opt cmd; do
      claim "$name, docked, is let go at 512,$y with $key held"
      ctl float-all > /dev/null
      sleep 1
      own=$(size_of "$window")
      both_docked
      take_hold "$window"
      drag "$GX" "$GY" 512 "$y" --hold 0.8 --mods "$key"
      sleep 2
      echo "$name at $y with $key: own $own; it is at $(real_frame_of "$window")"
      check "$name at $y with $key: it has its own size, $own" has_size "$window" "$own"
    done
  done
}

# the_end <name of A>: a throw, and Arbor quits at once.
the_end() {
  local own_a own_b slot
  claim "Both are docked, $1 is thrown into the menu bar, and Arbor quits"
  ctl float-all > /dev/null
  sleep 1
  own_a=$(size_of "$A") own_b=$(size_of "$B")
  both_docked
  slot=$(size_of "$A")
  take_hold "$A"
  throw
  arbor_quit
  sleep 1
  echo "after Quit: $(real_frame_of "$A") (own $own_a, slot $slot); $(real_frame_of "$B") (own $own_b)"
  check "after Quit the other has its own size" has_size "$B" "$own_b"
  check "after Quit the thrown one is not as large as its slot" differ "$(size_of "$A")" "$slot"
}

arbor_build
macos_tiling on > /dev/null
echo "macOS's own tiling: $(macos_tiling)"

step "Test windows"
KIND=test
arbor_start 2
A=$W1 B=$W2
roads "a test window" "$W1"
heights "a test window" "$W1"
the_end "the first"
arbor_relaunch
arbor_stop

[ -z "${ARBOR_REHEARSAL:-}" ] || { echo; echo "the real apps are skipped: a rehearsal has none"; exit 0; }

step "TextEdit and Safari"
KIND=app
apps_build
apps_scratch
apps_watchdog 600
app_open com.apple.TextEdit "$APPS_SCRATCH/oak.txt"
TEXTEDIT_PID=$APP_PID A=$APP_WINDOW
app_open com.apple.Safari "$APPS_SCRATCH/page.html"
SAFARI_PID=$APP_PID B=$APP_WINDOW
app_dismiss "$SAFARI_PID"
check "TextEdit and Safari each have a window" test -n "$A" -a -n "$B"
arbor_start_apps "$TEXTEDIT_PID" "$SAFARI_PID"
# arbor_start records by itself; this start does not.
ctl trace on check-left-alone-apps > /dev/null 2>&1 || echo "note: the apps' session is not recorded"
roads TextEdit "$A"
heights TextEdit "$A"
roads Safari "$B"
the_end TextEdit
arbor_ended
app_quit "$TEXTEDIT_PID"
app_quit "$SAFARI_PID"
