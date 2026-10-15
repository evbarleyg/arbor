#!/bin/bash
# Real drags on real windows (F17, H4): `make e2e-drag`, and a step of CI's real-window job.
#
# arbor-e2e drives Arbor with commands. What a person does with the mouse takes another road into Arbor: the window
# server moves the window, Arbor's event monitor sees the button and the pointer, and the Accessibility layer has to
# work out from the window's frame whether this is a drag, an edge resize or neither. This script walks that road with
# the scripted pointer the Mac shell sessions use (lib.sh, pointer.swift), on three test windows of its own.
#
# macOS tiles dragged windows itself, and a Mac comes with that switched on. So the whole journey is played at both settings: on GitHub's
# Macs with the tiling on, as a Mac comes, and once more with it switched off; on a person's Mac once, as it is set, because the
# setting is theirs. On GitHub's Macs the setting is first seen to act, or not to, on a window that Arbor does not know.
#
# After every drop (collab/QUESTIONS.md, Q17: nothing of Arbor's takes the mouse-up): the button is up within 100 ms, a click where the
# preview was, half a second after the drop and before anything else is asked, arrives in the window, and the window ends where the preview was.
# The first round plays Arbor as it ships, which is without an event tap. The second has every gesture switched on, so that Arbor's taps
# lie in the way of each press and release: only then can a release be late through Arbor's fault.
#
# As Arbor ships, a plain drag only moves a window and ⌘ held during the drag docks (`dragDocks`). lib.sh's `drag` holds ⌘ by itself when it
# takes a window by its title bar; the steps about plain drags say --plain.
#
# Needs Accessibility for the terminal it runs from. Exit code 0: every check passed; 1: one failed; 2: no session, or a round that
# did not get to its end.
source "$(dirname "$0")/lib.sh"
source "$(dirname "$0")/lib-gestures.sh"

# same_frame <window> <x y w h>: whether Arbor's layout and the window server both have the window there, give or take 3.
same_frame() {
  local id=$1 kind now
  shift
  for kind in slot real; do
    if [ "$kind" = slot ]; then now=$(arbor_ask slot "$id") || return 1; else now=$(real_frame_of "$id"); fi
    python3 -c 'import sys; a = sys.argv[1].split(); b = sys.argv[2:6]
sys.exit(0 if all(abs(float(x) - float(y)) <= 3 for x, y in zip(a, b)) else 1)' "$now" "$@" || return 1
  done
}

not() { ! "$@"; }

# within <number> <low> <high>
within() { [ "$1" -ge "$2" ] && [ "$1" -le "$3" ]; }

# near <window> <x y w h>: whether the window server has it there, give or take 12: macOS can be told to leave margins around its tiles.
near() {
  python3 -c 'import sys; a = sys.argv[1].split(); b = sys.argv[2:6]
sys.exit(0 if len(a) == 4 and all(abs(float(x) - float(y)) <= 12 for x, y in zip(a, b)) else 1)' "$(real_frame_of "$1")" "$2" "$3" "$4" "$5"
}

# Whether the pointer is within the drop preview, which is the one panel of Arbor's at level 3.
pointer_in_preview() {
  local px py rest
  read -r px py rest <<< "$(pointer where)"
  inside "${px%.*} ${py%.*} 1 1" "$(overlay_frame 3)"
}

# is_at <window> "<x y w h>": whether the window server has it there, give or take 3.
is_at() { arbor_close "$(real_frame_of "$1")" "$2"; }

# Arbor says so when a button that it saw go down is up again without its having seen the release. In this step: one release that was
# missed is one ✘, under the drag it belongs to. A log that cannot be read says nothing.
release_was_seen() { [ -r "$ARBOR_HOME/arbor.log" ] && fails logged "was not seen"; }

# timed_release [x y]: lets go and says how long the login session still had the button down. 100 ms: a Mac without Arbor took 57 once in
# 118 releases (Q17). With a place: and clicks there as soon as the pointer tool gets there, which on GitHub's Macs is about half a second after
# the release (Q17 says 300 ms). Out of the same call of the tool, because two calls, with what this file does between them, lie 0.6 to
# 0.8 s apart there. CLICKED_AFTER: how many milliseconds it was.
timed_release() {
  local took hand
  CLICKED_AFTER=""
  # The release carries what the hand holds, which comes up after the button and before the click.
  hand=$(arbor_hand_lets_go)
  # Letting go is never declined, and a click is: on a person's Mac it has to land on something of the session's.
  if [ $# -eq 2 ] && arbor_input_is_ours click "$1" "$2"; then
    echo "> release --timed --then-click $1,$2 $hand"
    # shellcheck disable=SC2086
    read -r took CLICKED_AFTER <<< "$(pointer release --timed --then-click "$1,$2" $hand)"
  else
    echo "> release --timed $hand"
    # shellcheck disable=SC2086
    took=$(pointer release --timed $hand)
  fi
  check "the button is up within 100 ms (after ${took:-?} ms)" test "${took:-1000}" -le 100
}

# carry <window> <x> <y> [options of drag]: takes it by its title bar, brings it there and holds it. How many presses its content has had
# is asked first: an app whose window is in the hand need not answer, and after the drop there is no time to ask.
carry() {
  local id=$1
  shift
  PRESSES=$(events_of "$id" down)
  # shellcheck disable=SC2046
  drag $(titlebar_of "$id") "$@" --no-release
}

# drop <window>: after `carry`, with the preview showing, lets go, and asks what Q17 asks of every drop.
drop() {
  local id=$1 preview x y w h
  preview=$(overlay_frame 3)
  if check "a drop preview shows while the button is held" test -n "$preview"; then
    read -r x y w h <<< "$preview"
    # The click comes with the release. Everything else that is asked takes a second and more, and a panel that outstays the drop by half a
    # second, or takes the mouse while it fades, would be gone by then. Off the middle, where the window's label is, and well inside
    # what the preview covered.
    timed_release $((${x%.*} + ${w%.*} / 3)) $((${y%.*} + ${h%.*} * 2 / 3))
  else
    timed_release
  fi
  check "a click where the preview was, ${CLICKED_AFTER:-?} ms after the drop, arrives in the window" eventually test_presses "$id" $((PRESSES + 1))
  check "the window docks on release" eventually is docked "$id"
  check "it ends where the preview was" eventually is_at "$id" "$preview"
  check "Arbor saw the release" release_was_seen
  check "no preview is left behind" eventually not has_overlay 3
}
test_presses() { [ "$(events_of "$1" down)" = "$2" ]; }

# unmoved <window> <x y w h>: the window server has it exactly there.
unmoved() { [ "$(real_frame_of "$1")" = "$2" ]; }

# left_where <window> "<x y w h>": the window server has it where the hand had it. Or higher, if that was with its title bar behind the Dock: macOS
# pulls such a window up within milliseconds of the release, to 28 points above the end of the visible frame, and asks nobody
# (docs/REALITY.md, a-title-bar-let-go-behind-the-dock-is-pulled-up). The fake Mac leaves it hanging.
left_where() {
  local x y w h line=$((sy + sh - 28))
  read -r x y w h <<< "$2"
  arbor_close "$(real_frame_of "$1")" "$2" || { [ "${y%.*}" -gt "$line" ] && arbor_close "$(real_frame_of "$1")" "$x $line $w $h"; }
}

# plainly <window> <x> <y> <where, in words>: dragged there with nothing held and let go. Nothing of Arbor's shows, it floats where it was
# let go, and the two others have not moved by a point.
plainly() {
  local id=$1 x=$2 y=$3 where=$4 other held start before=""
  for other in "$W1" "$W2" "$W3"; do [ "$other" = "$id" ] || before="$before $other:$(real_frame_of "$other" | tr ' ' ,)"; done
  start=$(real_frame_of "$id")
  drag_window "$id" "$x" "$y" --plain --hold 0.6 --no-release
  check "$where: the window is in the hand" not unmoved "$id" "$start"
  check "$where: no preview" not has_overlay 3
  held=$(real_frame_of "$id")
  timed_release
  sleep 1
  check "$where: it floats" is floating "$id"
  check "$where: where it was let go" left_where "$id" "$held"
  for other in $before; do
    check "$where: window ${other%%:*} has not moved" unmoved "${other%%:*}" "$(echo "${other#*:}" | tr , ' ')"
  done
}

# Whether one of macOS's switches is on; `macos_tiles` asks for either. A key that is not there means on, from macOS 15 on, the first that tiles.
macos_has_on() {
  case "$(sw_vers -productVersion)" in 1[0-4].*) return 1 ;; esac
  [ "$(defaults read com.apple.WindowManager "$1" 2>/dev/null || echo 1)" = 1 ]
}

# A switch that is written and not obeyed proves nothing. One window that Arbor does not know, before Arbor starts: held in the menu bar
# and let go, does macOS fill the screen with it? $1: yes or no, what it is to be.
# macOS does not answer every drag (lib-walk.sh: its preview has been seen to come, to go within 3 ms and to stay away, with the pointer at
# rest in the menu bar). So that it acts is said by one drag of three, and that it does not by two of two.
first_display() { pointer displays | awk 'NR == 1 { print $2, $3, $4, $5 }'; }
tiling_is_seen() {
  local expected=$1 try x y w h dx dy dw dh acts=no
  if ! on_throwaway_mac; then
    # No curtain hangs yet between the test windows and the person's own, and the menu bar is theirs.
    echo "not asked on a person's Mac, where nothing is pressed before the session has begun: the settings are taken at their word"
    return 0
  fi
  arbor_make_room || exit 77
  arbor_open_app 1 "$ARBOR_TEST_WINDOWS" 1
  take "dx dy dw dh" first_display
  for try in 1 2 3; do
    take "x y w h" real_frame_of "$W1"
    drag $((${x%.*} + ${w%.*} / 2)) $((${y%.*} + 12)) $((${dx%.*} + ${dw%.*} / 2)) $((${dy%.*} + 10)) --hold 1
    sleep 1.5
    take "x y w h" real_frame_of "$W1"
    echo "without Arbor, a window let go in the menu bar ends at $x $y $w $h"
    [ "${w%.*}" -ge $((${dw%.*} - 40)) ] && acts=yes
    if [ "$acts" = yes ] || { [ "$expected" = no ] && [ "$try" -ge 2 ]; }; then break; fi
    # Away again, a hand's breadth down: a window that lies under the menu bar does not move when it is pushed up.
    drag $((${x%.*} + ${w%.*} / 2)) $((${y%.*} + 12)) $((${dx%.*} + ${dw%.*} / 2)) $((${dy%.*} + 170))
  done
  arbor_close_windows
  check "macOS's own tiling is seen to act: $expected" test "$acts" = "$expected"
}

# left_to_macos <window> <x y: where to let go> <x y w h: macOS's tile>
left_to_macos() {
  local id=$1 x=$2 y=$3
  shift 3
  # shellcheck disable=SC2046
  drag $(titlebar_of "$id") "$x" "$y" --hold 1 --no-release
  check "Arbor shows no preview beside macOS's" not has_overlay 3
  timed_release
  check "macOS gives it its tile" eventually near "$id" "$@"
  # Arbor used to pull it back half a second after macOS had finished.
  sleep 2
  check "where it stays" near "$id" "$@"
  check "it floats" is floating "$id"
  check "and Arbor knows where it is" arbor_close "$(frame_of "$id")" "$(real_frame_of "$id")"
  check "Arbor saw the release" release_was_seen
  summary
}

# journey <as-shipped|taps> [then-off]: then-off switches macOS's tiling off at the end, while Arbor runs.
journey() {
  local before held start own tx ty
  if [ "$1" = taps ]; then
    arbor_settings "{$ARBOR_GESTURES_ON}"
    arbor_start 3 ARBOR_NO_HOTKEYS=0
    check "Arbor's event taps are in the way of every press and release" eventually grep -q "rectangle event taps installed" "$ARBOR_HOME/arbor.log"
  else
    arbor_start 3
  fi
  read -r sx sy sw sh <<< "$(arbor_ask screen)"
  # The whole display: its first point is macOS's, which with the Dock on the left is not where the visible part begins.
  read -r fx fy fw fh <<< "$(display_frame_of 1)"
  summary

  step "plain drags to the four screen edges: nothing of Arbor's shows and nothing docks"
  # Three points short of the display's last: macOS, as it comes, takes a window only at the very last point and in the menu bar.
  plainly "$W1" $((sx + 3)) $((sy + sh / 2)) "the left edge"
  plainly "$W1" $((sx + sw - 3)) $((sy + sh / 2)) "the right edge"
  plainly "$W1" $((sx + sw / 2)) $((sy + 3)) "the top edge"
  plainly "$W1" $((sx + sw / 2)) $((sy + sh - 3)) "the bottom edge"
  plainly "$W1" $((sx + sw * 3 / 5)) $((sy + sh / 3)) "back in the middle"
  check "nothing is docked" arbor_ask count docked 0
  summary

  step "drag a window by its title bar to the left screen edge"
  before=$(real_frame_of "$W3")
  carry "$W3" $((sx + 3)) $((sy + sh / 2))
  # The window server moves a window that is dragged by its title bar, and Arbor has no part in that. Once the first press took hold of
  # nothing. Every later step then failed, pressing wherever empty answers
  # made it press (`drag -1 0 59 0`), and nothing was left to tell why (an alert that an earlier step of the job had left lay over the title
  # bars). So: what the Mac looks like, and no step further.
  if ! check "the window follows the pointer" test "$(real_frame_of "$W3")" != "$before"; then
    release
    arbor_mac_facts
    shot the-press-took-hold-of-nothing
    die "the first press at the title bar of window $W3 moved nothing, so this run says nothing about Arbor: see the facts above it"
  fi
  if macos_has_on EnableTilingByEdgeDrag; then
    # A hand pushes on to the last point, which is macOS's, so with its tiling on the whole edge is: Arbor offers nothing on the way there.
    check "with macOS's tiling on Arbor offers nothing along the edge" not has_overlay 3
    held=$(real_frame_of "$W3")
    timed_release
    sleep 1.5
    check "let go short of macOS's point, the window floats" is floating "$W3"
    check "where it was let go" arbor_close "$(real_frame_of "$W3")" "$held"
    check "Arbor saw the release" release_was_seen
    # The keys and the commands stay Arbor's, and the journey goes on from a docked window.
    ctl dock "$W3" left
    check "a command docks it" eventually is docked "$W3"
  else
    drop "$W3"
  fi
  read -r x3 y3 w3 h3 <<< "$(arbor_ask slot "$W3")"
  check "it sits at the left edge" [ "$x3" -le $((sx + 30)) ]
  summary

  step "drag the right edge of the docked window 60 points to the right"
  read -r dx dy dw dh <<< "$(arbor_ask desktop)"
  drag $((x3 + w3 - 1)) $((y3 + h3 / 2)) $((x3 + w3 + 59)) $((y3 + h3 / 2))
  check "the window is 60 points wider" eventually same_frame "$W3" "$x3" "$y3" $((w3 + 60)) "$h3"
  read -r dx2 dy2 dw2 dh2 <<< "$(arbor_ask desktop)"
  check "the Desktop gave up the space" within "$dw2" $((dw - 63)) $((dw - 57))
  read -r x3 y3 w3 h3 <<< "$(arbor_ask slot "$W3")"
  summary

  step "drag another window onto the right part of the docked one"
  carry "$W2" $((x3 + w3 * 85 / 100)) $((y3 + h3 / 2))
  # The preview lies under the pointer here, in front of every window. It is only looked at: the release goes through it.
  check "the pointer is inside the drop preview" pointer_in_preview
  drop "$W2"
  read -r x3 y3 w3 h3 <<< "$(arbor_ask slot "$W3")"
  read -r x2 y2 w2 h2 <<< "$(arbor_ask slot "$W2")"
  check "to the right of the first" [ "$x2" -ge $((x3 + w3)) ]
  summary

  step "a plain drag onto the edge of a docked window"
  # shellcheck disable=SC2046
  plainly "$W1" $(zone_of "$W3" bottom) "the lower part of a docked window"

  step "⌘ goes down with the window held there, and comes up again"
  drag_window "$W1" $((sx + sw * 3 / 5)) $((sy + sh / 3)) --plain
  start=$(real_frame_of "$W1")
  # shellcheck disable=SC2046
  drag_window "$W1" $(zone_of "$W3" bottom) --plain --hold 0.6 --no-release
  check "the window is in the hand" not unmoved "$W1" "$start"
  check "nothing held: no preview" not has_overlay 3
  key cmd --down
  check "⌘ down: the preview comes, with the pointer at rest" eventually has_overlay 3
  key cmd --up
  check "⌘ up: it goes" eventually not has_overlay 3
  release
  sleep 1
  check "let go without the key, the window floats" is floating "$W1"
  check "the docked windows are in their slots" eventually same_frame "$W3" "$x3" "$y3" "$w3" "$h3"
  drag_window "$W1" $((sx + sw * 3 / 5)) $((sy + sh / 3)) --plain
  summary

  step "a click on a docked window's title bar that slips by a few points"
  read -r tx ty <<< "$(titlebar_of "$W3")"
  drag "$tx" "$ty" $((tx + 6)) $((ty + 4)) --plain --steps 3 --duration 0.1 --hold 0
  check "it is still docked" stays is docked "$W3"
  check "and back in its slot" eventually same_frame "$W3" "$x3" "$y3" "$w3" "$h3"
  check "no seam moved" eventually same_frame "$W2" "$x2" "$y2" "$w2" "$h2"

  step "double-click the title bar of a docked window (H5)"
  # shellcheck disable=SC2046
  dblclick $(titlebar_of "$W3")
  sleep 1.5
  # What macOS makes of it stays (check-macos-double-click.sh looks closer). Whatever that is here, nothing else moves,
  check "no seam moved" eventually same_frame "$W2" "$x2" "$y2" "$w2" "$h2"
  check "the window is still docked" is docked "$W3"
  # and one command takes the window back.
  ctl show-all
  check "showing everything puts the window into its slot" eventually same_frame "$W3" "$x3" "$y3" "$w3" "$h3"

  step "press inside a docked window and move the pointer"
  drag $((x3 + w3 / 2)) $((y3 + h3 / 2)) $((x3 + w3 / 2 + 90)) $((y3 + h3 / 2 + 60)) --no-release
  check "that is not a drag: no preview" not has_overlay 3
  release
  check "the window is in its slot" eventually same_frame "$W3" "$x3" "$y3" "$w3" "$h3"

  step "drag a docked window out onto the Desktop"
  read -r dx dy dw dh <<< "$(arbor_ask desktop)"
  # Near the top of the Desktop: the pointer holds the title bar, and a window as tall as its slot let go of half way down
  # would hang off the bottom of the display, where "back on screen" at the end does not find enough of it.
  # shellcheck disable=SC2046
  drag $(titlebar_of "$W2") $((dx + dw / 2)) $((dy + 60))
  check "it floats" eventually is floating "$W2"
  check "the first window is still docked" is docked "$W3"
  check "Arbor saw the release" release_was_seen
  summary

  step "a docked window dragged plainly comes out wherever it is let go"
  own=$(real_frame_of "$W2" | awk '{ print int($3 + 0.5), int($4 + 0.5) }')
  ctl dock "$W2" right
  check "docked again" eventually is docked "$W2"
  read -r x3 y3 w3 h3 <<< "$(arbor_ask slot "$W3")"
  # Over the middle of the other docked window, from where a ⌘-drag goes home.
  # shellcheck disable=SC2046
  drag $(titlebar_of "$W2") $((x3 + w3 / 2)) $((y3 + h3 / 2)) --plain --hold 0.6 --no-release
  check "no preview" not has_overlay 3
  timed_release
  check "it floats" eventually is floating "$W2"
  check "at the size it had before it was docked" eventually [ "$(real_frame_of "$W2" | awk '{ print int($3 + 0.5), int($4 + 0.5) }')" = "$own" ]
  check "the other is still docked, in its slot" eventually is in_slot "$W3"
  check "Arbor saw the release" release_was_seen
  # Back to where the journey had it, clear of what comes next.
  # shellcheck disable=SC2046
  drag $(titlebar_of "$W2") $((dx + dw / 2)) $((dy + 60)) --plain
  summary

  step "drag a floating window to the bottom edge, which is Arbor's at every setting"
  carry "$W2" $((sx + sw * 2 / 3)) $((sy + sh - 3))
  drop "$W2"
  ctl float "$W2"
  check "it floats again" eventually is floating "$W2"
  summary

  # At the first and the last point of the display's width macOS gives a window a half or a quarter of the screen, in the menu bar all of it. It
  # asks nobody, so there Arbor stands aside (MacTiling.swift). Before it did, two previews showed, and the window went into
  # Arbor's slot, to macOS's tile and back. With the switches off the same places are Arbor's.
  step "let go of a docked window at the very edge of the screen, where macOS tiles"
  if macos_has_on EnableTilingByEdgeDrag; then
    left_to_macos "$W3" "$fx" $((sy + sh / 2)) "$sx" "$sy" $((sw / 2)) "$sh"
  else
    # The one that floats: a docked one let go over its own slot, which reaches to this edge, only goes back.
    carry "$W2" "$fx" $((sy + sh / 2)) --hold 1
    drop "$W2"
    ctl float "$W2"
    summary
  fi

  step "let go of a floating window in the menu bar, where macOS fills the screen"
  if macos_has_on EnableTopTilingByEdgeDrag; then
    left_to_macos "$W2" $((sx + sw / 2)) $(((fy + sy) / 2)) "$sx" "$sy" "$sw" "$sh"
  else
    carry "$W2" $((sx + sw / 2)) $(((fy + sy) / 2)) --hold 1
    drop "$W2"
    summary
  fi

  if [ "${2:-}" = then-off ]; then
    step "macOS's tiling is switched off while Arbor runs: from the next drag on the menu bar is Arbor's"
    macos_tiling off
    # Away from the top first: a window that lies under the menu bar already does not move when it is pushed up, and what does not move is not dragged.
    # shellcheck disable=SC2046
    drag $(titlebar_of "$W2") $((sx + sw / 2)) $((sy + 200))
    carry "$W2" $((sx + sw / 2)) $(((fy + sy) / 2)) --hold 1
    drop "$W2"
    summary
  fi

  arbor_stop
}

# play "<what the setting is called>" <yes|no: whether macOS tiles> <as-shipped|taps> [then-off]
ROUNDS=0
WANTED=1
play() {
  step "MACOS'S OWN TILING: $1"
  macos_tiling
  tiling_is_seen "$2"
  journey "$3" "${4:-}"
  ROUNDS=$((ROUNDS + 1))
}

echo "This takes over the real pointer for one to three minutes. Hands off the mouse until it says it is done."
arbor_build
if ! on_throwaway_mac; then
  # A setting of the person's, not of the session's.
  play "as this Mac is set" "$(macos_has_on EnableTopTilingByEdgeDrag && echo yes || echo no)" as-shipped
elif case "$(sw_vers -productVersion)" in 1[0-4].*) true ;; *) false ;; esac; then
  play "this macOS has none" no taps
else
  # Whatever ends the script. And on first: a script that ran before this one on the same Mac may have left it off, and then both rounds
  # would be the second.
  at_exit "macos_tiling on > /dev/null"
  if ! macos_has_on EnableTilingByEdgeDrag || ! macos_has_on EnableTopTilingByEdgeDrag; then macos_tiling on > /dev/null; fi
  WANTED=2
  play "on, as a Mac comes" yes as-shipped then-off
  play "switched off" no taps
fi
# An answer that never came makes bash give up on the whole command it is in the middle of, which is everything above, and go on with the next
# line as if nothing had happened: no check made, exit code 0. So this is a command of its own.
[ "$ROUNDS" -eq "$WANTED" ] || die "$ROUNDS of $WANTED rounds got to the end: see the error above"
echo "Done: the pointer is yours again."
