#!/bin/bash
# Can Finder be given the keyboard so that nothing rises, nothing moves, and a letter lands in no window?
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-finder-gets-the-keyboard.sh
#
# "Else to Finder" is the product owner's answer wherever Arbor must take the keyboard out of a window nobody sees and has no window in view
# to give it to: a held view that its person has emptied, a key of their own that leaves nothing in view. It has never been built, or seen
# on a Mac. By Apple's words an activation brings an app's main and key windows forward, and a Finder window that rises over docked
# ones is a move nobody asked for. An older answer was that Arbor takes the keyboard itself, so that keys go to nobody; that was never
# seen either (probe-keyboard.sh). Nothing is built before this has spoken.
#
# Nothing here is a check of Arbor, which does not run. The output is the point: finder-keyboard.txt in the output folder, a RESULT line a
# round. The checks only say that each round began as it should.
#
# THE STAGE: two displays, the second virtual. On each a Finder window (f1, f2) partly under a test window of another app's (w1, w2). Every
# round begins alike: f2 and f1 are clicked, so that f1 is Finder's own key window, then the test windows, so that they lie on top and
# one of them has the keyboard. What a round leaves behind must not colour the next: after a click on the wallpaper Finder's focus is
# the Desktop, and an activation might then raise nothing.
# EACH WAY, from a process that is what Arbor is, an accessory app that is not in front (whohaskeys.swift):
#   activate            NSRunningApplication.activate with no options
#   frontmost           AXFrontmost on Finder's app element
#   element             AXFocused on the Desktop's own element, found where the wallpaper shows
#   element+frontmost, element+activate     the Desktop first, so that it is what Finder has to bring forward
#   itself              the accessory app activates itself and has no window for the keyboard
# BESIDE THEM, the control: a click on the wallpaper by the real pointer, which is how a person gives Finder the keyboard.
# OF EACH: who is in front and where keys go, by NSWorkspace and by Accessibility; the window server's order of the four windows, front to
# back, and their frames, before and a second after; and which test window counted a plain j.
#
# It opens Finder windows on two throwaway folders, clicks the wallpaper and plugs in a display: only on GitHub's Macs.
source "$(dirname "$0")/lib-apps.sh"

needs_throwaway_mac "open Finder windows, click the wallpaper and plug in a virtual display"
# 64 is what a rehearsal ends with where the fake Mac lacks something: it has no Finder, no compiler and one display.
if [ -n "${ARBOR_REHEARSAL_DIR:-}" ]; then
  echo "cannot be rehearsed: the fake Mac has no Finder and no second display"
  exit 64
fi

apps_build
WHO="$ARBOR_ROOT/.build/mac-shell/whohaskeys"
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/whohaskeys.swift" -o "$WHO" > "$ARBOR_OUT/build-whohaskeys.log" 2>&1 || {
  cat "$ARBOR_OUT/build-whohaskeys.log"
  die "scripts/mac-shell/whohaskeys.swift did not compile"
}
NOTES="$ARBOR_OUT/finder-keyboard.txt"
say() { echo "$*" | tee -a "$NOTES"; }

apps_scratch
display_add 1280 800 right
arbor_make_room || exit 77
# An ordinary app, with a menu bar of its own: who owns the menu bar is one of the questions.
arbor_open_app 1 "$ARBOR_TEST_WINDOWS" 2 --regular

app_open com.apple.finder "$APPS_SCRATCH/grove" || die "Finder opened no window"
FINDER_PID=$APP_PID
F1=$APP_WINDOW
WERE_OPEN=$APP_WINDOWS
app_open com.apple.finder "$APPS_SCRATCH/copse" > /dev/null
app_await_window "$FINDER_PID" "$WERE_OPEN" 8 || die "Finder opened no second window"
F2=$NEW_WINDOW
NAMES="test-windows=$ARBOR_WINDOWS_PID Finder=$FINDER_PID"

# x y w h of the display at the origin, and of the other.
display_at() { pointer displays | awk -v main="$1" '(($2 == 0 && $3 == 0) ? "main" : "second") == main { print $2, $3, $4, $5; exit }'; }
# stage <main|second> <Finder's window> <the test window>: the one partly under the other, and room for the wallpaper to their right.
stage() {
  local x y w h
  take "x y w h" display_at "$1"
  apptool set-frame "$2" $((x + 120)) $((y + 120)) 560 400 > /dev/null
  tw move "$3" $((x + 400)) $((y + 260)) 520 380
  eval "BARE_$1=\"$((x + w - 60)) $((y + h / 2))\""
}
stage main "$F1" "$W1"
stage second "$F2" "$W2"
sleep 1

label() {
  case "$1" in
    "$W1") echo w1 ;; "$W2") echo w2 ;; "$F1") echo f1 ;; "$F2") echo f2 ;;
    *) echo "another($1)" ;;
  esac
}
# The four, and whatever else Finder has on screen at their level, front to back as the window server lists them.
order() {
  local id
  "$ARBOR_POINTER" windows --on-screen \
    | awk -v ours=" $W1 $W2 " -v finder="$FINDER_PID" '$3 == 0 && (index(ours, " " $1 " ") || $2 == finder) { print $1 }' \
    | while read -r id; do printf '%s ' "$(label "$id")"; done
}
frames() {
  local id
  for id in "$W1" "$W2" "$F1" "$F2"; do printf '%s: %s; ' "$(label "$id")" "$(real_frame_of "$id")"; done
}
# shellcheck disable=SC2086
report() { "$WHO" report $NAMES | sed -E "s/its-window=$F1( |$)/its-window=f1 /; s/its-window=$F2( |$)/its-window=f2 /; s/its-window=$W1( |$)/its-window=w1 /; s/its-window=$W2( |$)/its-window=w2 /"; }
who() { say "  $1: $(report)"; }
# before <a> <b> "<order>"
comes_before() { case " $3" in *" $1 "*" $2 "*) ;; *) echo "the order is: $3"; return 1 ;; esac; }
on_top() { local now; now=$(order); comes_before w1 f1 "$now" && comes_before w2 f2 "$now"; }
keys_go_to() { case "$(report)" in *"front=test-windows "*"its-window=$1 "*) ;; *) report; return 1 ;; esac; }

begin() {
  # By their title bars: a click inside could open something.
  app_focus "$F2" > /dev/null
  app_focus "$F1" > /dev/null
  if [ "$1" = main ]; then
    click_window "$W2" > /dev/null
    click_window "$W1" > /dev/null
    HAS=w1
  else
    click_window "$W1" > /dev/null
    click_window "$W2" > /dev/null
    HAS=w2
  fi
  sleep 0.7
  check "$ROUND: it begins with each test window over the Finder window of its display" on_top
  check "$ROUND: and with the keyboard in $HAS" keys_go_to "$HAS"
}

# round <picture> <main|second> "<what is tried>" <command…>
round() {
  local picture=$1 where=$2 before after stood stand one two rises=no moves=no
  ROUND="$3, from the $where display"
  shift 3
  step "$ROUND"
  begin "$where"
  say "--- $ROUND"
  who "before"
  before=$(order)
  stood=$(frames)
  "$@" >> "$NOTES" 2>&1
  sleep 1
  after=$(order)
  stand=$(frames)
  who "a second after"
  one=$(events_of "$W1" key)
  two=$(events_of "$W2" key)
  key j > /dev/null
  sleep 0.5
  one=$(($(events_of "$W1" key) - one))
  two=$(($(events_of "$W2" key) - two))
  who "after a j"
  [ "$before" = "$after" ] || rises="YES"
  [ "$stood" = "$stand" ] || moves="YES: $stood -> $stand"
  say "  front to back: $before-> $after"
  say "RESULT | $ROUND | rises: $rises | moves: $moves | the j: w1 +$one, w2 +$two | $(report)"
  panorama "$picture-$where"
}

# shellcheck disable=SC2086
give() { "$WHO" give "$1" "$FINDER_PID" $BARE; }
# It has to last while the round looks. What it sees for itself goes into the notes too.
# shellcheck disable=SC2086
takes_it_itself() {
  "$WHO" take 8 $NAMES 9>&- 8>&- 3>&- &
  TAKER=$!
  started "$TAKER"
}

say "# probe-finder-gets-the-keyboard.sh $(date -u +%Y-%m-%dT%H:%MZ) on macOS $(sw_vers -productVersion), commit $(git rev-parse --short HEAD). Arbor is not running."
say "# w1 over f1 on the main display, w2 over f2 on the second. keys-go-to is Accessibility's focused application, its-window that application's focused window,"
say "# its-element the role of its focused element. Frames: $(frames)"

for where in main second; do
  eval "BARE=\$BARE_$where"
  say ""
  say "=== the keyboard begins on the $where display; the wallpaper shows at $BARE"
  # shellcheck disable=SC2086
  round 1-click "$where" "the control: a click on the wallpaper" click $BARE
  round 2-activate "$where" "activate" give activate
  round 3-frontmost "$where" "frontmost" give frontmost
  round 4-element "$where" "element" give element
  round 5-element-frontmost "$where" "element+frontmost" give element+frontmost
  round 6-element-activate "$where" "element+activate" give element+activate
  round 7-itself "$where" "an accessory app activates itself" takes_it_itself
  wait "$TAKER" 2> /dev/null
  sleep 0.5
  who "once that app has ended"
done

step "What it leaves"
apptool close "$F1" > /dev/null 2>&1
apptool close "$F2" > /dev/null 2>&1
arbor_close_windows
echo
echo "=== finder-keyboard.txt, its RESULT lines"
grep "^RESULT" "$NOTES"
