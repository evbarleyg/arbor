#!/bin/bash
# A docked window is dragged out and let go lower and lower, so that its own frame ends in the Dock's strip (board 0.22's rest), with a test
# window and then with real TextEdit beside Safari. The window leaves by the ordinary road, which gives it its own size at the drop.
# check-own-size.sh has the same drop with a test window, three times over, by a fast drag and before a Quit; this one has the heights and the real app.
#
# What only a Mac can say: what a window answers to a size whose foot would land in the strip. Seen: from a foot off the display it stops on
# the display's bottom, taller than asked. The script holds Arbor to two things:
#   on the screen: its own size, at every height (a ✘ low down says how much too tall it stands, and is for whoever reads it to weigh);
#   in the books:  its own size never creeps: after each low drop it is docked again and let go at 150, where nothing is in the way, and
#                  has the size it had when the script began.
# KEY=plain (the default): nothing is held, as whoever only moves a window: a plain drag takes a docked window out. KEY=cmd: ⌘ held all the way.
# What was asked and what was answered, call by call, is in the trace that comes back (mac-shell/traces/): both sessions are recorded.
source "$(dirname "$0")/lib-apps.sh"
export ARBOR_RECORD=1
KEY=${KEY:-plain}

size_of() { real_frame_of "$1" | awk '{ printf "%d %d", $3 + 0.5, $4 + 0.5 }'; }
same_size() { local a b c d; read -r a b <<< "$1"; read -r c d <<< "$2"; about "$a" "$c" && about "$b" "$d"; }
has_size() { same_size "$(size_of "$1")" "$2"; }

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

# out <window> <y>: docked, dragged out and let go at 512,<y>.
out() {
  both_docked
  take_hold "$1"
  if [ "$KEY" = plain ]; then drag "$GX" "$GY" 512 "$2" --hold 0.8 --plain; else drag "$GX" "$GY" 512 "$2" --hold 0.8 --mods "$KEY"; fi
  sleep 2
}

# low <name> <window>
low() {
  local name=$1 window=$2 y own
  ctl float-all > /dev/null
  sleep 1
  own=$(size_of "$window")
  echo "== $name: w$window, its own size $own"
  for y in 150 300 320 420; do
    claim "$name, docked, is dragged out and let go at 512,$y"
    out "$window" "$y"
    check "$name at $y: it is out of the arrangement" is floating "$window"
    echo "$name at $y: own $own; it is at $(real_frame_of "$window")"
    check "$name at $y: on the screen it has its own size, $own" has_size "$window" "$own"
    claim "$name is docked again and let go at 512,150, where nothing is in the way"
    out "$window" 150
    echo "$name at 150 after $y: own $own; it is at $(real_frame_of "$window")"
    check "$name at 150 after $y: its own size has not crept: $own" has_size "$window" "$own"
  done
}

arbor_build
macos_tiling on > /dev/null
echo "macOS's own tiling: $(macos_tiling); the key: $KEY"

step "Test windows"
KIND=test
arbor_start 2
A=$W1 B=$W2
low "a test window" "$W1"
arbor_stop

[ -z "${ARBOR_REHEARSAL:-}" ] || { echo; echo "the real apps are skipped: a rehearsal has none"; exit 0; }

step "TextEdit beside Safari"
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
ctl trace on check-let-go-low-apps > /dev/null 2>&1 || echo "note: the apps' session is not recorded"
low TextEdit "$A"
arbor_quit
arbor_ended
app_quit "$TEXTEDIT_PID"
app_quit "$SAFARI_PID"
