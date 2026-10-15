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
# THE STAGE: two displays, the second virtual, on each a test window of another app's (w1, w2), one of which has the keyboard. FINDER IN FOUR STATES,
# and a way is clean only if it is clean in all four:
#   covered     a window on each display (f1, f2), each partly under the test window there. Played with the keyboard on either display
#   none        no window open
#   minimized   its only window in the Dock
#   elsewhere   its only window on another Space of the main display. macOS ships with "When switching to an application, switch to a
#               Space with open windows for the application" on: a way that changes the Space is not clean, whatever else it does
# Every round of a state begins alike, for what one leaves behind must not colour the next: after a click on the wallpaper Finder's focus
# is the Desktop, and an activation might then raise nothing. So where Finder has windows in view they are clicked first, f1 last, which
# makes it Finder's own key window; then the test windows, so that they lie on top.
# EACH WAY, from a process that is what Arbor is, an accessory app that is not in front (whohaskeys.swift):
#   activate            NSRunningApplication.activate with no options
#   frontmost           AXFrontmost on Finder's app element
#   element             AXFocused on the Desktop's own element, found where the wallpaper shows
#   element+frontmost, element+activate     the Desktop first, so that it is what Finder has to bring forward
#   itself              the accessory app activates itself and has no window for the keyboard
# BESIDE THEM, the control: a click on the wallpaper by the real pointer, which is how a person gives Finder the keyboard.
# OF EACH: who is in front and where keys go, by NSWorkspace and by Accessibility; the window server's order of the windows on screen, front
# to back, and their frames, before and a second after; which Space each display shows; and which test window counted a plain j.
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
F1=""
F2=""

# finder_opens <variable> <folder>: one more Finder window, on the Space that shows.
finder_opens() {
  local known=""
  [ -z "${FINDER_PID:-}" ] || known=$(app_windows "$FINDER_PID")
  app_open com.apple.finder "$2" > /dev/null
  FINDER_PID=$APP_PID
  app_await_window "$FINDER_PID" "$known" 8 || die "Finder opened no window for $2"
  eval "$1=$NEW_WINDOW"
}
finder_closes() {
  local id
  for id in "$@"; do
    [ -z "$id" ] || apptool close "$id" > /dev/null 2>&1
  done
  sleep 1
}

# x y w h of the display at the origin, and of the other.
display_at() { pointer displays | awk -v which="$1" '(($2 == 0 && $3 == 0) ? "main" : "second") == which { print $2, $3, $4, $5; exit }'; }
# Where the test window and Finder's lie on a display, the one partly over the other, with room for the wallpaper to their right.
place() {
  local x y w h
  take "x y w h" display_at "$1"
  case "$2" in
    test) tw move "$3" $((x + 400)) $((y + 260)) 520 380 ;;
    finder) apptool set-frame "$3" $((x + 120)) $((y + 120)) 560 400 > /dev/null ;;
  esac
  eval "BARE_$1=\"$((x + w - 60)) $((y + h / 2))\""
}
place main test "$W1"
place second test "$W2"

label() {
  case "$1" in
    "$W1") echo w1 ;; "$W2") echo w2 ;; "${F1:-none}") echo f1 ;; "${F2:-none}") echo f2 ;;
    *) echo "another($1)" ;;
  esac
}
# The test windows, and whatever Finder has on screen at their level, front to back as the window server lists them.
order() {
  local id
  "$ARBOR_POINTER" windows --on-screen \
    | awk -v ours=" $W1 $W2 " -v finder="$FINDER_PID" '$3 == 0 && (index(ours, " " $1 " ") || $2 == finder) { print $1 }' \
    | while read -r id; do printf '%s ' "$(label "$id")"; done
}
frames() {
  local id
  for id in "$W1" "$W2" $F1 $F2; do printf '%s: %s; ' "$(label "$id")" "$(real_frame_of "$id")"; done
}
# Of each display: how many Spaces, and which one shows.
showing() { spaces | awk '{ printf "%s of %s; ", $3, $2 }'; }
# shellcheck disable=SC2086
report() {
  "$WHO" report $NAMES | sed -E "s/its-window=($W1)( |$)/its-window=w1 /; s/its-window=($W2)( |$)/its-window=w2 /; \
    s/its-window=(${F1:-none})( |$)/its-window=f1 /; s/its-window=(${F2:-none})( |$)/its-window=f2 /"
}
who() { say "  $1: $(report)"; }
# comes_before <a> <b> "<order>"
comes_before() { case " $3" in *" $1 "*" $2 "*) ;; *) echo "the order is: $3"; return 1 ;; esac; }
on_top() { local now; now=$(order); comes_before w1 f1 "$now" && comes_before w2 f2 "$now"; }
only_the_test_windows() { case "$(order)" in "w1 w2 " | "w2 w1 ") ;; *) echo "on screen: $(order)"; return 1 ;; esac; }
keys_go_to() { case "$(report)" in *"front=test-windows "*"its-window=$1 "*) ;; *) report; return 1 ;; esac; }
# Of the display that has more than one. Which line of the list is whose is not said.
on_space() { [ "$(spaces | awk '$2 > 1 { print $3; exit }')" = "$1" ]; }
# ⌃← and ⌃→ switch the Spaces of the display the pointer is on.
# shellcheck disable=SC2086
go() {
  move $BARE_main > /dev/null
  space_go "$1" > /dev/null
}

begin() {
  case "$STATE" in
    covered)
      # By their title bars: a click inside could open something.
      app_focus "$F2" > /dev/null
      app_focus "$F1" > /dev/null ;;
    minimized)
      # A way may have fetched it out of the Dock.
      only_the_test_windows > /dev/null || { apptool minimize "$F1" > /dev/null; sleep 2; } ;;
    elsewhere)
      on_space 1 || go left ;;
  esac
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
  if [ "$STATE" = covered ]; then
    check "$ROUND: it begins with each test window over the Finder window of its display" on_top
  else
    check "$ROUND: it begins with no window of Finder's on screen" only_the_test_windows
  fi
  check "$ROUND: and with the keyboard in $HAS" keys_go_to "$HAS"
}

# round <main|second> "<what is tried>" <command…>
round() {
  local where=$1 way=$2 before after stood stand shown shows one two rises=no moves=no space=same
  ROUND="Finder $STATE, from the $where display: $way"
  shift 2
  # What has been found so far must come home.
  if [ "$SECONDS" -gt 960 ]; then
    say "RESULT | $ROUND | NOT PLAYED: no time left"
    return 0
  fi
  step "$ROUND"
  begin "$where"
  say "--- $ROUND"
  who "before"
  before=$(order)
  stood=$(frames)
  shown=$(showing)
  "$@" >> "$NOTES" 2>&1
  sleep 1
  after=$(order)
  stand=$(frames)
  shows=$(showing)
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
  [ "$shown" = "$shows" ] || space="CHANGED: $shown -> $shows"
  say "  front to back: $before-> $after"
  say "RESULT | $ROUND | rises: $rises | moves: $moves | Space: $space | the j: w1 +$one, w2 +$two | $(report)"
  # A picture where there is something to see.
  if [ "$rises$space" != nosame ] || [ "$STATE $where" = "covered main" ]; then
    PICTURE=$((PICTURE + 1))
    panorama "$(printf %02d "$PICTURE")-$STATE-$where-$(echo "$way" | tr -c 'a-z+\n' '-' | cut -c 1-24)"
  fi
}
PICTURE=0

# shellcheck disable=SC2086
give() { "$WHO" give "$1" "$FINDER_PID" $BARE; }
# It has to last while the round looks. What it sees for itself goes into the notes too.
# shellcheck disable=SC2086
takes_it_itself() {
  "$WHO" take 6 $NAMES 9>&- 8>&- 3>&- &
  TAKER=$!
  started "$TAKER"
}

# every_way <main|second>
every_way() {
  eval "BARE=\$BARE_$1"
  say ""
  say "=== Finder $STATE; the keyboard begins on the $1 display; the wallpaper shows at $BARE"
  # shellcheck disable=SC2086
  round "$1" "the control, a click on the wallpaper" click $BARE
  round "$1" "activate" give activate
  round "$1" "frontmost" give frontmost
  round "$1" "element" give element
  round "$1" "element+frontmost" give element+frontmost
  round "$1" "element+activate" give element+activate
  TAKER=""
  round "$1" "an accessory app activates itself" takes_it_itself
  [ -z "$TAKER" ] || wait "$TAKER" 2> /dev/null
  sleep 0.5
  who "once that app has ended"
}

STATE=covered
finder_opens F1 "$APPS_SCRATCH/grove"
finder_opens F2 "$APPS_SCRATCH/copse"
NAMES="test-windows=$ARBOR_WINDOWS_PID Finder=$FINDER_PID"
place main finder "$F1"
place second finder "$F2"
sleep 1
say "# probe-finder-gets-the-keyboard.sh $(date -u +%Y-%m-%dT%H:%MZ) on macOS $(sw_vers -productVersion), commit $(git rev-parse --short HEAD). Arbor is not running."
say "# keys-go-to is Accessibility's focused application, its-window that application's focused window, its-element the role of its focused element."
say "# Frames: $(frames)"
say "# \"switch to a Space with open windows for the application\" (AppleSpacesSwitchOnActivate; unset means on): $(defaults read -g AppleSpacesSwitchOnActivate 2> /dev/null || echo unset)"
every_way main
every_way second

STATE=none
finder_closes "$F1" "$F2"
F1=""
F2=""
every_way main

STATE=minimized
finder_opens F1 "$APPS_SCRATCH/grove"
place main finder "$F1"
apptool minimize "$F1" > /dev/null
sleep 2
every_way main
apptool unminimize "$F1" > /dev/null 2>&1
sleep 2
finder_closes "$F1"
F1=""

STATE=elsewhere
# shellcheck disable=SC2086
move $BARE_main
space_add
go right
check "the main display shows a second Space" on_space 2
finder_opens F1 "$APPS_SCRATCH/grove"
place main finder "$F1"
sleep 1
say "# on the second Space: $(showing) on screen: $(order)"
check "Finder's window is on it, and the test window of that display is not" test "$(order | tr -d ' ' | tr -d 'w2')" = f1
go left
check "the first Space shows again" on_space 1
every_way main

step "What it leaves"
on_space 2 || go right
finder_closes "$F1"
go left
arbor_close_windows
echo
echo "=== finder-keyboard.txt, its RESULT lines"
grep "^RESULT" "$NOTES"
