#!/bin/bash
# F43, "say what happened", on a real Mac: the heads-up line and the panel of shortcuts, brought up by real key
# presses, light and dark, over the wallpaper and over windows.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-F43.sh
#
# On a person's Mac it changes nothing of theirs: Arbor's own panels are made light or dark with ARBOR_APPEARANCE. Only
# on one of GitHub's throwaway Macs does it also switch the whole Mac's appearance, the wallpaper and Reduce Motion, and
# plug in a second display (lib.sh's helpers decline elsewhere).
#
# The pictures are for looking at (is the line legible, is the panel tidy); the checks cover what a picture cannot
# show: the line takes neither the keyboard nor clicks and goes by itself, the panel takes the keyboard and
# goes at a key, a click, one of Arbor's own shortcuts and a pause.
ARBOR_SHORTCUTS=all  # it presses keys of the whole map, of which nine ship
source "$(dirname "$0")/lib.sh"

LINE=6   # window levels: the line is three above `.floating`, the panel two
PANEL=5

# The last thing Arbor said on screen, from the debug log.
last_line() { grep -F "said on" "$ARBOR_HOME/arbor.log" | tail -n 1 | sed 's/.*said on [^:]*: //'; }
said() { last_line | grep -qF "$1"; }
not() { ! "$@"; }
logged() { grep -qF "$1" "$ARBOR_HOME/arbor.log"; }
# panel_at <level>: x y w h of Arbor's window at that level, in whole points for bash's arithmetic.
panel_at() { overlays | awk -v level="$1" '$3 == level && $8 == "on" { printf "%d %d %d %d\n", $4, $5, $6, $7; exit }'; }

# tour <prefix>: the same five pictures in whatever look the Mac has now. Expects W1 docked and focused, everything
# in view.
tour() {
  step "$1: a problem, over the Desktop"
  key ctrl+opt+up
  shot_after 0.4 "$1-1-problem"
  check "⌃⌥↑ with everything in view is explained" said "Already showing everything"

  step "$1: a longer sentence that names keys"
  key ctrl+opt+9
  shot_after 0.4 "$1-2-sentence"
  check "⌃⌥9 says which keys save view 9" said "⌃⌥⇧9 saves where you are looking"

  step "$1: a hint, over a window"
  key ctrl+opt+return
  shot_after 0.5 "$1-3-hint"
  check "framing a window says where the others went" said "out of view, not closed"
  key ctrl+opt+shift+2
  shot_after 0.4 "$1-4-change"
  check "saving a view is confirmed" said "Saved view 2"
  # By command: with two input sources set up, macOS takes ⌃⌥Space to switch keyboards, and the key is not what is being proved.
  ctl show-all

  step "$1: the shortcuts"
  key ctrl+opt+shift+/
  shot_after 0.5 "$1-5-shortcuts"
  check "⌃⌥⇧/ brings up the panel" has_overlay $PANEL
  key escape
  check "⎋ puts it away" eventually not has_overlay $PANEL
}

arbor_build

# MARK: Light mode, with motion

macos_reduce_motion off
appearance light
step "session 1: light mode"
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0 ARBOR_APPEARANCE=light
# Its lower left corner: the other windows cover the rest.
# shellcheck disable=SC2046
click $(arbor_point $(frame_of "$W1") "x + 20" "y + h - 20")
check "the click focused the first window" eventually is focused "$W1"

step "a key that seems dead"
key ctrl+opt+down
shot_after 0.4 01-nothing-docked
check "⌃⌥↓ with nothing docked says what to do" said "Nothing is docked yet"
check "the line is on screen" has_overlay $LINE
echo "Arbor's own windows (id pid level x y w h on owner):"
overlays
check "the window keeps the keyboard" is focused "$W1"

step "the first dock"
key ctrl+opt+cmd+left
shot_after 0.4 02-docked
check "the first dock is explained" said "Docked"
check "and names the keys that frame it" said "⌃⌥↩ frames it"
check "the window keeps the keyboard" is focused "$W1"

step "the line comes and goes"
sleep 3
check "the line went by itself" not has_overlay $LINE
key ctrl+opt+up &
film 03-fade-in 4
wait $!
sleep 0.9
film 04-fade-out 6
sleep 1.5
check "and is gone again" not has_overlay $LINE

step "clicks go through the line"
key ctrl+opt+up
sleep 0.3
read -r lx ly lw lh <<< "$(panel_at $LINE)"
echo "the line is at ${lx:-?} ${ly:-?} ${lw:-?} ${lh:-?}"
if [ -n "${lx:-}" ]; then
  ctl float "$W1"
  ctl dock "$W2" bottom
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  check "another window has the keyboard" eventually is focused "$W1"
  key ctrl+opt+up
  sleep 0.3
  check "the line is up" has_overlay $LINE
  click "$((lx + lw / 2))" "$((ly + lh / 2))"
  check "a click on the line lands on the window under it" eventually is focused "$W2"
  ctl float "$W2"
  ctl dock "$W1" left
  # shellcheck disable=SC2046
  click $(center_of "$W1")
fi

tour light
wallpaper "#d8d8d8" && tour light-on-light

step "what ends the panel"
key ctrl+opt+shift+/
check "the panel is up" eventually has_overlay $PANEL
check "it has the keyboard" logged "the panel of shortcuts is up, with the keyboard"
key x
check "any key puts it away" eventually not has_overlay $PANEL
check "and the key went to the panel, not to the app" logged "put away by a key"
check "the window has the keyboard again" is focused "$W1"
key ctrl+opt+shift+/
check "up again" eventually has_overlay $PANEL
key ctrl+opt+shift+/
check "the same keys put it away" eventually not has_overlay $PANEL
key ctrl+opt+shift+/
check "up again" eventually has_overlay $PANEL
# shellcheck disable=SC2046
click $(arbor_point $(frame_of "$W1") "x + 20" "y + h - 20")
check "a click elsewhere puts it away" eventually not has_overlay $PANEL
key ctrl+opt+shift+/
check "up again" eventually has_overlay $PANEL
read -r px py pw ph <<< "$(panel_at $PANEL)"
echo "the panel is at ${px:-?} ${py:-?} ${pw:-?} ${ph:-?}"
# Only where the panel is known to be: without it this would be a click at 0 20, the Apple menu.
if [ -n "${px:-}" ]; then
  click "$((px + pw / 2))" "$((py + 20))"
  check "a click on it puts it away" eventually not has_overlay $PANEL
else
  check "the panel's place is known" false
  key escape
fi
key ctrl+opt+shift+/
check "up again" eventually has_overlay $PANEL
key ctrl+opt+return
check "one of Arbor's own shortcuts puts it away" eventually not has_overlay $PANEL
check "and does its own job" eventually is parked "$W2"
ctl show-all
grep -F "panel of shortcuts" "$ARBOR_HOME/arbor.log" | cut -c 26-

step "the menu"
# A right click: a plain one in the middle of the item presses one of its buttons.
if open_menu; then
  # Keyboard Shortcuts… is the first row of Help ▸. The first Escape may close only the submenu.
  key h; key e; key right
  shot 20-menu
  key escape; key escape
fi

step "pausing"
key ctrl+opt+shift+/
check "the panel is up" eventually has_overlay $PANEL
key ctrl+opt+escape
shot_after 0.5 21-paused
check "pausing puts the panel away" not has_overlay $PANEL
check "and says whose the keys are now, and how to come back" said "Arbor is paused: its keys are the apps’ again · ⌃⌥⎋ resumes"
sleep 4
check "then nothing of Arbor's is left on screen" not has_overlay $LINE
key ctrl+opt+escape
shot_after 0.4 22-resumed
check "resuming is confirmed" said "Resumed"

step "the user's own shortcuts, and every reply"
arbor_settings '{"messages": "all", "bindings": {"ctrl+opt+e": "show-all", "ctrl+opt+space": null, "ctrl+opt+5": "arrange all", "ctrl+opt+cmd+h": "dock left"}}'
ctl reload-settings
key ctrl+opt+shift+/
shot_after 0.5 23-own-shortcuts
key escape
key ctrl+opt+return
shot_after 0.4 24-every-reply
key ctrl+opt+e
echo "everything Arbor said in this session:"
grep -F "said on" "$ARBOR_HOME/arbor.log" | sed 's/.*said on [^:]*: /  /'
arbor_stop 25-after-quit

# MARK: Dark mode, with "Reduce motion"

macos_reduce_motion on
appearance dark
step "session 2: dark mode, Reduce motion"
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_APPEARANCE=dark
# shellcheck disable=SC2046
click $(arbor_point $(frame_of "$W1") "x + 20" "y + h - 20")
check "the click focused the first window" eventually is focused "$W1"
key ctrl+opt+cmd+left
shot_after 0.3 30-dark-docked
sleep 2
tour dark
wallpaper gradient && tour dark-on-a-gradient
key ctrl+opt+up &
film 31-no-fade 3
wait $!

step "two displays: the line and the panel go where the command acted"
if display_add 1280 800 right; then
  read -r dx dy dw dh <<< "$(screen_of 2)"
  echo "the second display's visible frame: $dx $dy $dw $dh"
  move "$((dx + dw / 2))" "$((dy + dh / 2))"
  key ctrl+opt+up
  sleep 0.3
  read -r lx ly lw lh <<< "$(panel_at $LINE)"
  echo "the line is at ${lx:-?} ${ly:-?} ${lw:-?} ${lh:-?}"
  check "the line is on the second display" inside "${lx:-0} ${ly:-0} ${lw:-0} ${lh:-0}" "$dx $dy $dw $dh"
  shot_after 0.1 40-second-display-line
  key ctrl+opt+shift+/
  check "the panel is up" eventually has_overlay $PANEL
  read -r px py pw ph <<< "$(panel_at $PANEL)"
  check "the panel is on the second display" inside "${px:-0} ${py:-0} ${pw:-0} ${ph:-0}" "$dx $dy $dw $dh"
  shot 41-second-display-shortcuts
  key escape
  display_remove
fi
arbor_stop

appearance light
macos_reduce_motion off
ls -l "$ARBOR_OUT" | awk '{ print $5, $9 }'
