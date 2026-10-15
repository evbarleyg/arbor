#!/bin/bash
# What Arbor says on screen to somebody who pressed a key: the line low on the display (why nothing happened, hints for newcomers,
# `messages`), and the panel of shortcuts.
# A30 says on screen what happened, A66 the shortcuts on screen.
source "$(dirname "$0")/../lib.sh"
arbor_build

# Window levels: the line is three above floating panels, the panel of shortcuts two.
LINE=6
PANEL=5
# The fake Mac records the line and the panel and lists neither among the windows, nor does its panel take the keyboard. What asks
# the window server for them, or types into the panel, is left out of a rehearsal.
real() { [ -n "${ARBOR_REHEARSAL:-}" ] || "$@"; }
# said <text>: Arbor has said that on screen since the claim began. The debug log has every line it shows.
said() {
  arbor_log_since "$ARBOR_STEP_MARK" | grep -F "said on " | grep -F -e "$1" > /dev/null || { echo "Arbor has not said: $1"; return 1; }
}
said_times() {
  local times
  times=$(arbor_log_since "$ARBOR_STEP_MARK" | grep -F "said on " | grep -c -F -e "$1")
  [ "$times" -eq "$2" ] || { echo "said $times times, not $2: $1"; return 1; }
}
said_nothing() {
  local line
  line=$(arbor_log_since "$ARBOR_STEP_MARK" | grep -F "said on " | tail -n 1 | sed 's/.*said on [^:]*: //')
  [ -z "$line" ] || { echo "Arbor said: $line"; return 1; }
}
# The middle of the line, by the window server. A rehearsal takes the place `HeadsUpModel` gives it: its foot 56 points above the
# foot of the screen.
line_point() {
  if [ -n "${ARBOR_REHEARSAL:-}" ]; then
    # shellcheck disable=SC2046
    arbor_point $(screen_of 1) "x + w / 2" "y + h - 70"
  else
    overlay_frame $LINE | awk '{ print int($1 + $3 / 2), int($2 + $4 / 2) }'
  fi
}
# The reply to the last ⌃⌥⇧/, which tells whether the panel was up when it was pressed.
last_answer_is() {
  arbor_log_since "$ARBOR_STEP_MARK" | grep -F "INFO  show-shortcuts: " | tail -n 1 | grep -F -e "$1" > /dev/null \
    || { echo "the last answer to show-shortcuts is not: $1"; return 1; }
}

arbor_start 2 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0

claim "⌃⌥↓ with nothing docked: a line on screen says what to do, leaves the keyboard where it is, and goes by itself"
proves A30
click_window "$W1"
check "⌃⌥↓ reaches Arbor" pressed ctrl+opt+down in
check "Arbor says why nothing happened" eventually said "Nothing is docked yet"
real check "the line is on screen" eventually has_overlay $LINE
keys=$(events_of "$W1" key)
key_to "$W1" x
check "a letter typed meanwhile goes to the window" eventually received "$W1" key -gt "$keys"
# A line stays 0.06 s a letter, this one four seconds, and then it fades.
sleep 4
real check "the line has gone by itself" eventually fails has_overlay $LINE

claim "the first docks are explained three times and not a fourth, also after Arbor has been started again"
proves A30
for round in first second; do
  check "⌃⌥⌘← docks the focused window, the $round time" pressed ctrl+opt+cmd+left dock left
  check "⌃⌥F floats it again, the $round time" pressed ctrl+opt+f toggle-float
done
check "explained twice so far" eventually said_times "Docked · ⌃⌥↩ frames it" 2
arbor_quit
arbor_relaunch
click_window "$W1"
for round in third fourth; do
  check "⌃⌥⌘← docks the focused window, the $round time" pressed ctrl+opt+cmd+left dock left
  check "⌃⌥F floats it again, the $round time" pressed ctrl+opt+f toggle-float
done
check "a third time after the restart, and not a fourth" stays said_times "Docked · ⌃⌥↩ frames it" 3

claim "⌃⌥↑ with everything in view is answered on screen; the same command from a terminal is answered there and not on screen"
proves A30
check "⌃⌥↑ reaches Arbor" pressed ctrl+opt+up out
check "Arbor says that everything is showing already" eventually said_times "Already showing everything" 1
check "arborctl gets the same answer" says "already showing everything" arborctl out
check "which is not said on screen again" stays said_times "Already showing everything" 1

claim "set messages to off by command: nothing is said on screen; reset it: the line is back"
proves A30
check "set messages off succeeds" ctl set messages off
check "⌃⌥↑ reaches Arbor" pressed ctrl+opt+up out
check "nothing is said" stays said_nothing
real check "and nothing is on screen" fails has_overlay $LINE
check "reset messages succeeds" ctl reset messages
check "⌃⌥↑ reaches Arbor again" pressed ctrl+opt+up out
check "and is answered on screen" eventually said "Already showing everything"

claim "set messages to all by command: a dock that is no longer explained is still confirmed"
proves A30
click_window "$W1"
check "⌃⌥⌘← docks the focused window" pressed ctrl+opt+cmd+left dock left
check "at first nothing is said: the hint has been shown often enough" stays said_nothing
check "⌃⌥F floats it again" pressed ctrl+opt+f toggle-float
check "set messages all succeeds" ctl set messages all
check "⌃⌥⌘← docks it once more" pressed ctrl+opt+cmd+left dock left
check "now the reply is said" eventually said "at the left edge"
check "reset messages succeeds" ctl reset messages

claim "click on the line while it shows over a window: the click goes through to the window"
proves A30
check "⌃⌥↩ frames the focused window" pressed ctrl+opt+return zoom
check "it fills the screen" eventually fills "$W1"
# A long sentence, which stays three seconds and more.
check "⌃⌥9 reaches Arbor" pressed ctrl+opt+9 view 9
check "Arbor says which keys save that view" eventually said "⌃⌥⇧9 saves where you are looking"
real check "the line is on screen" eventually has_overlay $LINE
downs=$(events_of "$W1" down)
# Not `take`, which would end the section: a line that is not there costs this claim only.
if point=$(line_point) && [ -n "$point" ]; then
  # shellcheck disable=SC2086
  click $point
  real check "the line is still up" has_overlay $LINE
  check "the window under the line got the press" eventually received "$W1" down -gt "$downs"
else
  check "the window server says where the line is" false
fi
check "it still has the keyboard" is focused "$W1"
ctl show-all
ctl float "$W1"

claim "⌃⌥⇧/ shows the panel of shortcuts, and the same keys put it away"
proves A66
click_window "$W1"
check "⌃⌥⇧/ reaches Arbor" pressed ctrl+opt+shift+/ show-shortcuts
check "Arbor shows the shortcuts" eventually last_answer_is "any key or click puts them away"
real check "the panel is on screen" eventually has_overlay $PANEL
real check "it has the keyboard" eventually logged "the panel of shortcuts is up, with the keyboard"
check "the app behind stays the one in front" front_is "$ARBOR_WINDOWS_PID"
check "⌃⌥⇧/ again" pressed ctrl+opt+shift+/ show-shortcuts
check "Arbor puts them away" eventually last_answer_is "put the shortcuts away"
real check "the panel is gone" eventually fails has_overlay $PANEL
check "the window has the keyboard" eventually is focused "$W1"

claim "one of Arbor's own shortcuts puts the panel of shortcuts away and does its own job"
proves A66
ctl dock "$W1" left
check "⌃⌥⇧/ reaches Arbor" pressed ctrl+opt+shift+/ show-shortcuts
check "Arbor shows the shortcuts" eventually last_answer_is "any key or click puts them away"
check "⌃⌥↩ reaches Arbor" pressed ctrl+opt+return zoom
check "the focused window fills the screen" eventually fills "$W1"
real check "the panel is gone" eventually fails has_overlay $PANEL
check "⌃⌥⇧/ reaches Arbor again" pressed ctrl+opt+shift+/ show-shortcuts
check "and shows them: they had been put away" eventually last_answer_is "any key or click puts them away"
key escape
real check "⎋ puts the panel away" eventually fails has_overlay $PANEL
ctl show-all

claim "choose Keyboard Shortcuts… from the menu and type a letter: the panel goes, and the window behind gets not that letter but the next"
proves A66
click_window "$W1"
check "the submenu's item can be clicked" click_menu "Help" "Keyboard Shortcuts…"
check "Arbor ran show-shortcuts" eventually ran show-shortcuts
check "Arbor shows the shortcuts" eventually last_answer_is "any key or click puts them away"
real check "the panel is on screen" eventually has_overlay $PANEL
keys=$(events_of "$W1" key)
real key x
real check "the panel is gone" eventually fails has_overlay $PANEL
real check "it was the letter that put it away" logged "the panel of shortcuts is put away by a key"
real check "the window behind did not get the letter" stays received "$W1" key -eq "$keys"
# In a rehearsal the panel is still up here, and lets the letter through.
key_to "$W1" x
check "it gets the next one" eventually received "$W1" key -gt "$keys"

arbor_stop
