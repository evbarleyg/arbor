#!/bin/bash
# No column for the Desktop (F68, board 0.6), on real apps at their real smallest sizes: two docks are two halves and the first does not
# move at the second; whoever is left alone stays as it is; Arrange Windows with two to six windows leaves nothing over.
#
#   DAY_KEEP_PICTURES=1 is set here: every step's picture comes back.
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-no-desktop-column.sh
#
# THE QUESTION ONLY A MAC CAN ANSWER: real apps refuse sizes. On 1440 points a half is 702, which Notes (709) and Mail (760) refuse by a little; a third is
# 464, which Safari refuses too. Does each window still move once, to where it ends up, and what does a person see after Arrange Windows?
# Each step is one thing a person does and says what it may move (lib-day.sh); jolts.py reads the samples: `jolt`, `moved-unasked`, `lost`.
# The pictures to look at: <nnn>-arrange-2.jpg to <nnn>-arrange-6.jpg.
#
# By command, not by key: which keys dock and arrange is being decided elsewhere, and what is asked here is where the windows go.
#
# Only on GitHub's Macs: it opens real apps, quits them, and changes the display's size.
export DAY_KEEP_PICTURES=1
source "$(dirname "${BASH_SOURCE[0]}")/lib-day.sh"
needs_throwaway_mac "open six real apps, quit them, and switch the display's size"
apps_watchdog 900

step "the Mac"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m)"
day_build
# The runner's own 1024×768 is smaller than any Mac's.
display_mode 1440x900 1600x900 1680x1050 1920x1080
# GitHub's Macs come with Reduce Motion on: left on, so that Arbor puts up no stage and every move of every window shows.
day_scratch
sampler_start

# x y w h of what Arbor's layout fills: the display's visible frame less the gap all round.
gap=12
right_edge_of() { local x y w h; read -r x y w h <<< "$(slot_of "$1")"; echo $((x + w)); }
left_edge_of() { local x y w h; read -r x y w h <<< "$(slot_of "$1")"; echo "$x"; }
no_desktop() { ! ctl state | grep -q '"desktopFrame"'; }
# Whether the slots or tiles in view reach the same right edge as a window that fills the view would: nothing is left over.
widest_right() {
  local window most=0 edge
  for window in "$@"; do
    edge=$(right_edge_of "$window" 2>/dev/null) || continue
    [ "${edge:-0}" -gt "$most" ] && most=$edge
  done
  echo "$most"
}

open_app() {
  local name=$1 bundle=$2
  shift 2
  act open-close "open-$name" "opens $name"
  APP_WAIT=25 APP_OPEN_LIMIT=90 meet "$name" "$bundle" "$@" || echo "$name opened no standard window"
  case "$name" in mail) ;; *) app_dismiss "$APP_PID" || echo "a sheet or dialog stayed in the way" ;; esac
  acted "${OPEN_AS:-setup=1}"
}

chapter "Before Arbor: two apps are open"
open_app safari com.apple.Safari "$DAY_DOCUMENTS/$APPS_CANARY-page.html"
open_app notes com.apple.Notes

chapter "Two docks are two halves"
act quit-and-start launch "starts Arbor"
day_launch || die "Arbor did not start"
acted moves=none everything=1
welcome=$(arbor_window)
if [ -n "$welcome" ]; then
  act open-close close-welcome "closes Arbor's welcome window with its red button"
  # shellcheck disable=SC2046
  must click $(apptool button "$welcome" close)
  acted
fi
echo "desktopColumn: $(ctl get desktopColumn 2>&1 | tail -n 1)"

act dock-key dock-left "docks Safari at the left"
ctl dock "$W_safari" left
want "it is docked" eventually is docked "$W_safari"
acted moves="$W_safari" first=1
first=$(slot_of "$W_safari")
echo "Safari's slot: $first"

act dock-key dock-right "docks Notes at the right"
ctl dock "$W_notes" right
want "it is docked" eventually is docked "$W_notes"
want "nothing is kept for the Desktop" no_desktop
want "one gap lies between the two" test "$(($(left_edge_of "$W_notes") - $(right_edge_of "$W_safari")))" -eq "$gap"
# Notes will not go as narrow as a half of 1440 by seven points, and Safari can spare them (F61): on such a display Safari may give, once.
acted moves="$W_notes,$W_safari" docked="$W_safari,$W_notes"
echo "Safari's slot: $(slot_of "$W_safari"), Notes': $(slot_of "$W_notes")"
whole=$(right_edge_of "$W_notes")

chapter "Whoever is left alone stays as it is"
# But for what it had lent for the other's sake (the seven points above), which goes back to it: it has the half it had before Notes came.
act dock-key float-notes "floats Notes"
ctl float "$W_notes"
want "Safari has the slot it had before Notes came" has_slot "$W_safari" "$first"
acted moves="$W_notes,$W_safari" restores="$W_notes"

act dock-key dock-right-again "docks Notes at the right again"
ctl dock "$W_notes" right
want "nothing is kept for the Desktop" no_desktop
acted moves="$W_notes,$W_safari"

stays=$(slot_of "$W_notes")
act dock-key float-safari "floats Safari, the one that was docked first"
ctl float "$W_safari"
want "Notes keeps its slot" has_slot "$W_notes" "$stays"
acted moves="$W_safari" restores="$W_safari"

act way-out float-all "floats everything"
ctl float-all
acted moves=any restores=all places=1 everything=1

chapter "Arrange Windows leaves nothing over"
arranged="$W_safari $W_notes"
arrange() {
  local count=$1
  act dock-key "arrange-$count" "chooses Arrange Windows with $count windows open"
  ctl arrange
  want "nothing is kept for the Desktop" no_desktop
  # shellcheck disable=SC2086
  want "what is arranged reaches the right edge" test "$(widest_right $arranged)" -eq "$whole"
  acted moves=any tiles=ok
  brief
}
arrange 2
OPEN_AS="moves=none"
open_app mail com.apple.mail;  arranged="$arranged $W_mail";  arrange 3
open_app textedit com.apple.TextEdit "$DAY_DOCUMENTS/$APPS_CANARY-oak.txt";  arranged="$arranged $W_textedit";  arrange 4
open_app terminal com.apple.Terminal;  arranged="$arranged $W_terminal";  arrange 5
open_app calendar com.apple.iCal;  arranged="$arranged $W_calendar";  arrange 6

chapter "The Desktop is still a place to go"
act view desktop "goes to the Desktop"
ctl desktop
acted moves=docked leaves=any
act view back "and back"
ctl back
acted moves=docked everything=1 tiles=ok

chapter "The way out"
act way-out float-all-at-the-end "floats everything"
ctl float-all
acted moves=any restores=all everything=1
act quit-and-start quit "quits Arbor"
ctl quit
want "Arbor ends within five seconds" day_gone
acted moves=any restores=all everything=1

day_report
