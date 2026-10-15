# The acts: one word for each thing a person does to a window, for journeys that are written by a program.
# Source it instead of lib-day.sh (it sources that first); do not run it. walk-sample.sh is an example.
#
#   #!/bin/bash
#   source "$(dirname "$0")/lib-walk.sh"
#   walk_begin stock laptop defaults 4711
#   switch_dock safari;  dock_key left;  switch_click terminal;  drag_onto terminal safari right
#   view frame;  switch_cmdtab 1;  view all;  idle_act;  quit_and_start
#   walk_end
#
# A day written by hand (day.sh) knows at every step what the screen looks like. A walk made from a seed does not. So each act here
# is a step of lib-day.sh's that looks at the state for itself: it knows its kind (docs/VIABLE.md, "Across what"), what it may move ("What an act
# may move"), and which window has to end in front. **An act that does not apply is left out**, with a line in the output and no step: there is no
# second window to close, nothing is docked to drag onto. What a person would do first is done first, as an act of its own: a window that is covered is brought
# forward before it is dragged. So whoever writes the walk needs to know the
# words and nothing else, and may be blind to the state. An act that does apply and cannot be performed is a finding, as in lib-day.sh (`must`).
#
# <app> is a name of the cast's: finder safari textedit terminal notes calendar settings preview mail.
#
#   walk_begin <cast> <display> <tiling> [seed [commit]]   the Mac (stock | laptop desk two | defaults off), the apps, macOS seen to tile or not to, Arbor started
#                                                     and its welcome closed. WALK_WITHOUT_ARBOR=1: the control, in which Arbor's own acts are left out.
#                                                     WALK_REDUCE_MOTION=on: no stage, so every move of every window shows. WALK_KIND=sit: what run.json calls it
#   walk_end                                          Arbor quit if it runs, every window reached, the report
#   chapter "<title>"                                 lib-day.sh's: a heading, and a new trace
#
#   switch_dock <app>            clicks its icon in the Dock            switch_click <app>     clicks its window's title bar
#   switch_to <app>              the way a person gets at a window: its title bar if a free point of it shows, otherwise its icon in the Dock
#   switch_cmdtab [n]            ⌘ down, ⇥ n times, ⌘ up                switch_backtick        ⌘` : the app's next window
#   switch_menu <app>            its first window's line in the Window menu (the app is brought forward first, which is an act of its own)
#   tile_click [n]               clicks the n-th tile that stands in for a window (1): the real window comes wholly into view, with the keyboard
#   focus_key left|right|up|down ⌃⌥⇧ + arrow: the nearest window that way      summon <app>           taken, and not played yet
#   open_new                     ⌘N in the app in front                 close_new              ⌘W, if the window in front is one that open_new opened
#   minimize | restore [app]     ⌘M on the window in front | a click on its miniature in the Dock. A walk cannot know which window was in front: if that
#   hide | unhide [app]          ⌘H on the app in front | a click on its icon in the Dock        app is not the one, whichever was last comes back
#   quit_app <app> | reopen <app>                     ⌘Q (the app is brought forward first) | its document opened again. textedit preview safari
#   dock_key left|right|up|down  ⌃⌥⌘ + arrow on the window in front     float_key              ⌃⌥F, if it is docked
#   arrange_key                  ⌃⌥A: every window is docked            undo | redo            ⌃⌥Z | ⌃⌥⇧Z
#   rotate | mirror              ⌃⌥R | ⌃⌥⇧R on the window in front's group                     pin        `arborctl toggle-pin`: the menu's, it has no key
#   drag_onto <app> <app> left|right|top|bottom       by its title bar onto that part of the other's window, which has to be docked and in view
#   drag_out <app>               a docked window, onto the Desktop      drag_by <app> <dx> <dy> [click]   a floating one, that far
#   drag_edge <app> left|right|top                    against that edge of the display, where macOS tiles too
#   view frame|out|in|left|right|back|forward|all|home|desktop               (all: ⌃⌥Space tapped; home: ⌃⌥0, every display)
#   peek                         ⌃⌥Space held for a second and a half, then let go             save_view <1-9> | view_n <1-9>     ⌃⌥⇧digit | ⌃⌥digit
#   resize_gap <app> <points>    the gap to the right of its docked window, dragged that far     resize_key grow|shrink|balance
#   resize_edge <app> left|right|top|bottom <points>  its docked window's own edge, dragged that far outwards (inwards if negative)
#   full_screen on|off           ⌃⌘F in the app in front                wallpaper_click        a click on a bare spot, and a second one
#   title_double_click <app>     a double-click on its title bar, which macOS answers by zooming the window, and a second one, which takes it back
#   pause | resume | float_all | float_all_here       (the last: `arborctl float-all here`)
#   hold_view                    `arborctl hold`, a key that would move the view and must not, `arborctl release`: three acts. (release_view: taken, does nothing)
#   display plug|unplug|left|right|smaller|larger     a second, virtual display: plugged in to the right at 1920×1080, unplugged, moved to that side of the main
#                                                     one, unplugged and plugged in again at 1280×800 or 1920×1080. In the cell `two` alone
#   send_across | move_to_display                     `arborctl move-to-display next` for the window in front, which is what the menu does: it has no key yet
#   quit_and_start               Quit from Arbor's menu, every app's window reached by its Dock icon, Arbor started again
#   idle_act                     half a minute of nothing
source "$(dirname "${BASH_SOURCE[0]}")/lib-day.sh"
needs_throwaway_mac "open a dozen real apps, press ⌘Q and ⌘W in them, click in the Dock and on the wallpaper, and switch the display's size"

WALK_CAST=""
WALK_ACTS=0
WALK_LEFT_OUT=0
# The windows open_new opened and nobody has closed, the newest first; what is minimized; what is hidden (names).
WALK_NEW=""
WALK_MINIMIZED=""
WALK_HIDDEN=""
WALK_PAUSED="" WALK_BEFORE_PAUSE="" WALK_MOVED_IN_PAUSE=""
WALK_FULL_SCREEN=""
# Whether this walk may have a second display, and whether it is plugged in.
WALK_TWO=""
WALK_SECOND=""
WALK_NEXT_SIZE=""
# The last step after which everything was in view and the arrangement has not changed since: where Show Everything has to lead back to.
WALK_HOME=""

with_arbor() { [ -z "${WALK_WITHOUT_ARBOR:-}" ]; }

bundle_of() {
  case "$1" in
    finder) echo com.apple.finder ;;
    safari) echo com.apple.Safari ;;
    textedit) echo com.apple.TextEdit ;;
    terminal) echo com.apple.Terminal ;;
    notes) echo com.apple.Notes ;;
    calendar) echo com.apple.iCal ;;
    settings) echo com.apple.systempreferences ;;
    preview) echo com.apple.Preview ;;
    mail) echo com.apple.mail ;;
    *) return 1 ;;
  esac
}

document_of() {
  case "$1" in
    finder) echo "$DAY_DOCUMENTS/$APPS_CANARY-grove" ;;
    safari) echo "$DAY_DOCUMENTS/$APPS_CANARY-page.html" ;;
    textedit) echo "$DAY_DOCUMENTS/$APPS_CANARY-oak.txt" ;;
    preview) echo "$DAY_DOCUMENTS/$APPS_CANARY-leaf.png" ;;
  esac
}

window_of() { eval "echo \"\${W_$1:-}\""; }
pid_of() { eval "echo \"\${P_$1:-}\""; }
front_pid() { apptool front | cut -d ' ' -f 1; }
front_window() { apptool focused 2>/dev/null | cut -d ' ' -f 1; }
name_of_pid() {
  local name
  for name in $WALK_CAST; do [ "$(pid_of "$name")" = "$1" ] && { echo "$name"; return 0; }; done
  return 1
}
listed() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }
without() {
  local word kept=""
  for word in $2; do [ "$word" = "$1" ] || kept="$kept $word"; done
  echo "${kept# }"
}

# MARK: Whether an act applies

left_out() {
  WALK_LEFT_OUT=$((WALK_LEFT_OUT + 1))
  echo
  echo "-- left out: $*"
  return 0
}

# A member of the cast whose window is there to be seen or to be brought into view.
present() {
  listed "$1" "$WALK_CAST" && [ -n "$(window_of "$1")" ] && kill -0 "$(pid_of "$1")" 2>/dev/null \
    && ! listed "$1" "$WALK_MINIMIZED" && ! listed "$1" "$WALK_HIDDEN"
}

# At least nine tenths of it are on a display.
shows() { is on_screen "$1" 2>/dev/null; }
arbor_acts() { with_arbor && arbor_answers && [ -z "$WALK_PAUSED" ] && [ -z "$WALK_FULL_SCREEN" ]; }

# The arrangement, or a window's own frame, has changed: there is no going back to how things were.
changed() { WALK_HOME=""; }
# There and back is nothing: what is minimized or hidden and comes back with the very next act leaves every window where it was.
leaving() { eval "WALK_LEFT_$1=$DAY_STEP"; }
came_back() {
  local left
  eval "left=\${WALK_LEFT_$1:-0}"
  [ "$left" -eq $((DAY_STEP - 1)) ] && echo "returns=$((left - 1))"
}
# Everything is in view: from here a way there and back has to end here.
at_home() { WALK_HOME=$DAY_STEP; }
back_home() { [ -n "$WALK_HOME" ] && echo "returns=$WALK_HOME"; }

walk_act() {
  WALK_ACTS=$((WALK_ACTS + 1))
  # During a pause, anything but these changes what there is to come back to. The one drag that can be played then is of a floating window.
  case "$1" in idle | drag | way-out) ;; *) WALK_BEFORE_PAUSE="" ;; esac
  act "$@"
}

# MARK: Switching

switch_dock() {
  present "$1" || { left_out "switch_dock $1: it has no window to come forward"; return; }
  walk_act switch "dock-icon-$1" "clicks $1's icon in the Dock"
  must dock_click "$(bundle_of "$1")"
  acted front="$(main_window_of "$(pid_of "$1")")"
}

switch_click() {
  present "$1" && apptool grab "$(window_of "$1")" > /dev/null 2>&1 || { left_out "switch_click $1: no free point of its title bar shows"; return; }
  walk_act switch "click-$1" "clicks $1's title bar"
  must click_window "$(window_of "$1")"
  acted front="$(window_of "$1")"
}

switch_to() {
  if present "$1" && apptool grab "$(window_of "$1")" > /dev/null 2>&1; then switch_click "$1"; else switch_dock "$1"; fi
}

switch_cmdtab() {
  walk_act switch "cmd-tab-${1:-1}" "holds ⌘ and presses Tab ${1:-1} time(s)"
  cmd_tab "${1:-1}"
  sleep 0.5
  acted front="$(main_window_of "$(front_pid)")"
}

switch_backtick() {
  local pid
  pid=$(front_pid)
  [ "$(app_windows "$pid" | wc -w)" -ge 2 ] || { left_out "switch_backtick: the app in front has one window"; return; }
  walk_act switch cmd-backtick "presses ⌘\` for the app's next window"
  key 'cmd+`'
  sleep 0.3
  acted front="$(main_window_of "$pid")"
}

switch_menu() {
  present "$1" || { left_out "switch_menu $1: it has no window"; return; }
  [ "$(front_pid)" = "$(pid_of "$1")" ] || switch_dock "$1"
  walk_act switch "window-menu-$1" "chooses $1's first window in the Window menu"
  must window_menu "$(window_of "$1")"
  acted front="$(window_of "$1")"
}

tile_click() {
  local window place x y w h tile
  arbor_acts || { left_out "tile_click: Arbor is not acting"; return; }
  day_ids
  tile=$(echo "$DAY_TILES" | tr ',' '\n' | sed -n "${1:-1}p")
  [ -n "$tile" ] || { left_out "tile_click ${1:-1}: no such tile stands in for a window"; return; }
  window=${tile%%@*} place=${tile#*@}
  IFS=: read -r x y w h <<< "$place"
  walk_act tile-click click-tile "clicks the tile that stands in for a window"
  click "$((x + w / 2))" "$((y + h / 2))"
  acted moves=any front="$window"
}

focus_key() {
  arbor_acts || { left_out "focus_key $1: Arbor is not acting"; return; }
  case "$1" in left | right | up | down) ;; *) die "focus_key: left, right, up or down, not $1" ;; esac
  walk_act switch "focus-$1" "presses ⌃⌥⇧ and the $1 arrow"
  key "ctrl+opt+shift+$1"
  sleep 0.4
  # With no window that way in view, the view goes to the neighbouring space.
  acted moves=any front="$(front_window)"
}

# A summoned window is sent out of view again as soon as the keyboard goes elsewhere, and only `home`, a dock or Float All bring it back: every act after it
# would have to know. Until they do, the word is taken and nothing is played.
summon() { left_out "summon $1: not played yet"; }

# MARK: Windows come and go

open_new() {
  local pid known name
  pid=$(front_pid)
  name=$(name_of_pid "$pid") || { left_out "open_new: the app in front is not of the cast"; return; }
  case "$name" in safari | textedit | finder | terminal) ;; *) left_out "open_new: ⌘N in $name is no new window"; return ;; esac
  known=$(app_windows "$pid")
  walk_act open-close "new-window-$name" "presses ⌘N in $name"
  key cmd+n
  if app_await_window "$pid" "$known" 8; then
    label "$NEW_WINDOW" "$name-new-$DAY_STEP"
    WALK_NEW="$NEW_WINDOW $WALK_NEW"
  fi
  # A new window stays where its app put it, and nothing else moves. Over a framed window the view may have to make room.
  acted front="$NEW_WINDOW"
}

close_new() {
  local window
  window=$(front_window)
  if [ -z "$window" ] || ! listed "$window" "$WALK_NEW"; then
    window=${WALK_NEW%% *}
    [ -n "$window" ] && apptool grab "$window" > /dev/null 2>&1 || { left_out "close_new: no window that open_new opened is within reach"; return; }
    walk_act switch click-new-window "clicks the title bar of the window that ⌘N opened"
    must click_window "$window"
    acted front="$window"
    [ "$(front_window)" = "$window" ] || { left_out "close_new: the window that ⌘N opened did not come forward, and ⌘W would close another"; return; }
  fi
  walk_act open-close close-window "presses ⌘W"
  key cmd+w
  WALK_NEW=$(without "$window" "$WALK_NEW")
  acted leaves="$window" moves=docked
}

minimize() {
  local window name
  window=$(front_window)
  name=$(name_of_pid "$(front_pid)") && [ "$window" = "$(window_of "$name")" ] || { left_out "minimize: the window in front is not a first window of the cast's"; return; }
  walk_act open-close "minimize-$name" "presses ⌘M"
  leaving "$name"
  key cmd+m
  WALK_MINIMIZED="$WALK_MINIMIZED $name"
  changed
  acted moves=docked leaves="$window"
}

restore() {
  local x y window
  [ -n "${1:-}" ] && listed "$1" "$WALK_MINIMIZED" || set -- "${WALK_MINIMIZED##* }"
  [ -n "${1:-}" ] || { left_out "restore: nothing is minimized"; return; }
  window=$(window_of "$1")
  walk_act open-close "restore-$1" "clicks its miniature in the Dock"
  read -r x y <<< "$(apptool dock-window "$window" 2>/dev/null)"
  if [ -n "${x:-}" ]; then click "$x" "$y"; move "$x" "$((y - 200))"; else must false; fi
  WALK_MINIMIZED=$(without "$1" "$WALK_MINIMIZED")
  # shellcheck disable=SC2046
  acted moves=docked comes="$window" front="$window" $(came_back "$1")
}

hide() {
  local name pid gone
  pid=$(front_pid)
  name=$(name_of_pid "$pid") || { left_out "hide: the app in front is not of the cast"; return; }
  gone=$(app_windows "$pid" | tr ' ' ',')
  walk_act open-close "hide-$name" "presses ⌘H"
  leaving "$name"
  key cmd+h
  WALK_HIDDEN="$WALK_HIDDEN $name"
  changed
  acted moves=docked leaves="$gone"
}

unhide() {
  [ -n "${1:-}" ] && listed "$1" "$WALK_HIDDEN" || set -- "${WALK_HIDDEN##* }"
  [ -n "${1:-}" ] || { left_out "unhide: nothing is hidden"; return; }
  walk_act open-close "unhide-$1" "clicks its icon in the Dock"
  must dock_click "$(bundle_of "$1")"
  WALK_HIDDEN=$(without "$1" "$WALK_HIDDEN")
  # shellcheck disable=SC2046
  acted moves=docked comes="$(window_of "$1")" front="$(main_window_of "$(pid_of "$1")")" $(came_back "$1")
}

quit_app() {
  local pid gone id
  case "$1" in textedit | preview | safari) ;; *) left_out "quit_app $1: only apps whose document can be opened again"; return ;; esac
  present "$1" || { left_out "quit_app $1: it is not there"; return; }
  pid=$(pid_of "$1")
  [ "$(front_pid)" = "$pid" ] || switch_dock "$1"
  [ "$(front_pid)" = "$pid" ] || { left_out "quit_app $1: it did not come forward, and ⌘Q would quit another"; return; }
  gone=$(app_windows "$pid")
  walk_act open-close "quit-$1" "presses ⌘Q in $1"
  key cmd+q
  arbor_await_exit "$pid" 50 && apps_forget "$pid"
  for id in $gone; do WALK_NEW=$(without "$id" "$WALK_NEW"); done
  eval "W_$1= P_$1="
  changed
  acted moves=docked leaves="$(echo "$gone" | tr ' ' ',')"
}

reopen() {
  listed "$1" "$WALK_CAST" && [ -z "$(window_of "$1")" ] && [ -n "$(document_of "$1")" ] || { left_out "reopen $1: it was not quit"; return; }
  walk_act open-close "reopen-$1" "opens $1's document again"
  # Not in the background: a person who opens a document gets its app in front.
  open -b "$(bundle_of "$1")" "$(document_of "$1")"
  sleep 1
  meet "$1" "$(bundle_of "$1")" "$(document_of "$1")"
  changed
  acted moves=docked front="$(window_of "$1")"
}

# MARK: Arranging

dock_key() {
  local window
  arbor_acts || { left_out "dock_key $1: Arbor is not acting"; return; }
  window=$(front_window)
  [ -n "$window" ] && is managed "$window" 2>/dev/null || { left_out "dock_key $1: Arbor does not arrange the window in front"; return; }
  walk_act dock-key "dock-$1" "presses ⌃⌥⌘ and the $1 arrow"
  key "ctrl+opt+cmd+$1"
  changed
  want "it is docked" eventually is docked "$window"
  acted moves=docked front="$window"
}

float_key() {
  local window
  arbor_acts || { left_out "float_key: Arbor is not acting"; return; }
  window=$(front_window)
  [ -n "$window" ] && is docked "$window" 2>/dev/null || { left_out "float_key: the window in front is not docked"; return; }
  walk_act dock-key float "presses ⌃⌥F"
  key ctrl+opt+f
  changed
  acted moves=docked front="$window" restores="$window"
}

# One of Arbor's keys that changes the arrangement as a whole. $1 slug, $2 what is pressed, $3 the chord, then what `acted` is to hold it to.
arrangement_key() {
  local slug=$1 keys=$2 chord=$3
  shift 3
  arbor_acts || { left_out "$slug: Arbor is not acting"; return; }
  walk_act dock-key "$slug" "presses $keys"
  key "$chord"
  changed
  acted "$@"
}
# Every window on the display is docked, so every one of them may move.
arrange_key() { arrangement_key arrange "⌃⌥A" ctrl+opt+a moves=any; }
# What comes back may have floated, been docked or been out of view.
undo() { arrangement_key undo "⌃⌥Z" ctrl+opt+z moves=any; }
redo() { arrangement_key redo "⌃⌥⇧Z" ctrl+opt+shift+z moves=any; }
rotate() { arrangement_key rotate "⌃⌥R" ctrl+opt+r moves=docked; }
mirror() { arrangement_key mirror "⌃⌥⇧R" ctrl+opt+shift+r moves=docked; }

pin() {
  local window
  arbor_acts || { left_out "pin: Arbor is not acting"; return; }
  window=$(front_window)
  [ -n "$window" ] && is managed "$window" 2>/dev/null || { left_out "pin: Arbor does not arrange the window in front"; return; }
  walk_act dock-key pin "chooses Keep This Window in View in Arbor's menu, or takes the tick off"
  must ctl toggle-pin
  changed
  # A docked one floats first.
  acted moves=docked front="$window"
}

# can_be_dragged <app>: present, in view, and a free point of its title bar shows. A window that is covered is brought forward first, as a person would.
can_be_dragged() {
  present "$1" && shows "$(window_of "$1")" || return 1
  apptool grab "$(window_of "$1")" > /dev/null 2>&1 && return 0
  switch_dock "$1"
  shows "$(window_of "$1")" && apptool grab "$(window_of "$1")" > /dev/null 2>&1
}

drag_onto() {
  local x y w h px py window target
  arbor_acts || { left_out "drag_onto $*: Arbor is not acting"; return; }
  [ "$1" != "$2" ] && can_be_dragged "$1" && present "$2" || { left_out "drag_onto $*: nothing to take hold of"; return; }
  window=$(window_of "$1") target=$(window_of "$2")
  is docked "$target" 2>/dev/null && in_view "$target" || { left_out "drag_onto $*: $2 is not docked and in view"; return; }
  read -r x y w h <<< "$(frame_of "$target")"
  case "$3" in
    left) px=$((x + w / 6)) py=$((y + h / 2)) ;;
    right) px=$((x + w * 5 / 6)) py=$((y + h / 2)) ;;
    top) px=$((x + w / 2)) py=$((y + h / 6)) ;;
    bottom) px=$((x + w / 2)) py=$((y + h * 5 / 6)) ;;
    *) die "drag_onto: left, right, top or bottom, not $3" ;;
  esac
  walk_act drag "drag-$1-onto-$2-$3" "drags $1 by its title bar onto the $3 part of $2 and lets go"
  must drag_window "$window" "$px" "$py"
  changed
  [ -n "$DAY_UNDONE" ] || want "it is docked" eventually is docked "$window"
  acted drags="$window" moves=docked front="$window"
}

drag_out() {
  local x y w h window
  arbor_acts || { left_out "drag_out $1: Arbor is not acting"; return; }
  can_be_dragged "$1" && is docked "$(window_of "$1")" 2>/dev/null || { left_out "drag_out $1: it is not docked and in reach"; return; }
  read -r x y w h <<< "$(arbor_ask desktop 2>/dev/null)"
  [ -n "${w:-}" ] || { left_out "drag_out $1: the Desktop is out of view"; return; }
  window=$(window_of "$1")
  walk_act drag "drag-$1-out" "drags $1 out of the arrangement onto the Desktop and lets go"
  must drag_window "$window" "$((x + w / 2))" "$((y + h / 3))"
  changed
  [ -n "$DAY_UNDONE" ] || want "it floats" eventually is floating "$window"
  acted drags="$window" moves=docked front="$window" restores="$window" place="$window"
}

drag_by() {
  local x y role window
  can_be_dragged "$1" || { left_out "drag_by $*: nothing to take hold of"; return; }
  window=$(window_of "$1")
  if with_arbor && arbor_answers && is docked "$window" 2>/dev/null; then left_out "drag_by $*: it is docked"; return; fi
  read -r x y role <<< "$(apptool grab "$window")"
  # Not into the menu bar, the Dock or an edge, where macOS has ideas of its own.
  x=$((x + $2)) y=$((y + $3))
  [ "$x" -gt $((WALK_X + 60)) ] && [ "$x" -lt $((WALK_X + WALK_W - 60)) ] && [ "$y" -gt $((WALK_Y + 80)) ] && [ "$y" -lt $((WALK_Y + WALK_H - 260)) ] \
    || { left_out "drag_by $*: that would end at an edge"; return; }
  # The point is one of its title bar's at which nothing but the window answers, so the click after the drop does nothing but arrive.
  walk_act drag "drag-$1-by" "drags $1, which floats, by its title bar $2 across and $3 down${4:+, and clicks there 0.3 s after letting go}"
  must drag_window "$window" "$x" "$y" ${4:+--then-click}
  changed
  [ -z "$WALK_PAUSED" ] || WALK_MOVED_IN_PAUSE="${WALK_MOVED_IN_PAUSE:+$WALK_MOVED_IN_PAUSE,}$window"
  # Its size too: macOS gives a window it had tiled its earlier size back under the hand.
  acted drags="$window" front="$window" own="$window"
}

drag_edge() {
  local px py window own=""
  can_be_dragged "$1" || { left_out "drag_edge $*: nothing to take hold of"; return; }
  window=$(window_of "$1")
  case "$2" in
    left) px=$WALK_X py=$((WALK_Y + WALK_H / 2)) ;;
    right) px=$((WALK_X + WALK_W - 1)) py=$((WALK_Y + WALK_H / 2)) ;;
    top) px=$((WALK_X + WALK_W / 2)) py=$WALK_Y ;;
    *) die "drag_edge: left, right or top, not $2" ;;
  esac
  walk_act drag-where-macos-tiles "drag-$1-to-$2-edge" "drags $1 by its title bar against the $2 edge of the screen and lets go"
  must drag_window "$window" "$px" "$py" --hold 1
  changed
  # Docked by Arbor, or tiled by macOS with Arbor standing aside: then that is where its person put it, and its own frame from now on.
  if ! { with_arbor && arbor_answers && eventually is docked "$window"; }; then own="own=$window"; fi
  acted drags="$window" moves=docked front="$window" $own
}

resize_gap() {
  local x y window
  arbor_acts || { left_out "resize_gap $*: Arbor is not acting"; return; }
  present "$1" || { left_out "resize_gap $*: it is not there"; return; }
  window=$(window_of "$1")
  is docked "$window" 2>/dev/null && in_view "$window" || { left_out "resize_gap $*: it is not docked and in view"; return; }
  read -r x y <<< "$(seam_right_of "$window")"
  [ "$x" -lt $((WALK_X + WALK_W - 40)) ] || { left_out "resize_gap $*: there is no gap to its right"; return; }
  # A floating window may lie over the gap, and would take the press.
  [ "$(apptool top-at "$x" "$y" 2>/dev/null | cut -d ' ' -f 2)" = "$ARBOR_PID" ] || { left_out "resize_gap $*: something lies over the gap"; return; }
  walk_act resize "drag-gap-beside-$1" "drags the gap to the right of $1 by $2 points"
  drag "$x" "$y" "$((x + $2))" "$y"
  changed
  acted moves=docked
}

resize_edge() {
  local x y w h px py tx ty window
  arbor_acts || { left_out "resize_edge $*: Arbor is not acting"; return; }
  present "$1" || { left_out "resize_edge $*: it is not there"; return; }
  window=$(window_of "$1")
  is docked "$window" 2>/dev/null && in_view "$window" || { left_out "resize_edge $*: it is not docked and in view"; return; }
  read -r x y w h <<< "$(real_of "$window")"
  case "$2" in
    left) px=$((x + 1)) py=$((y + h / 2)) tx=$((px - $3)) ty=$py ;;
    right) px=$((x + w - 1)) py=$((y + h / 2)) tx=$((px + $3)) ty=$py ;;
    top) px=$((x + w / 2)) py=$((y + 1)) tx=$px ty=$((py - $3)) ;;
    bottom) px=$((x + w / 2)) py=$((y + h - 1)) tx=$px ty=$((py + $3)) ;;
    *) die "resize_edge: left, right, top or bottom, not $2" ;;
  esac
  [ "$(apptool top-at "$px" "$py" 2>/dev/null | cut -d ' ' -f 1)" = "$window" ] || { left_out "resize_edge $*: something lies over that edge"; return; }
  walk_act resize "drag-$2-edge-of-$1" "drags the $2 edge of $1's window by $3 points"
  drag "$px" "$py" "$tx" "$ty"
  changed
  acted moves=docked
}

resize_key() {
  local window chord keys
  arbor_acts || { left_out "resize_key $1: Arbor is not acting"; return; }
  window=$(front_window)
  [ -n "$window" ] && is docked "$window" 2>/dev/null || { left_out "resize_key $1: the window in front is not docked"; return; }
  case "$1" in
    grow) chord=ctrl+opt+cmd+= keys="⌃⌥⌘=" ;;
    shrink) chord=ctrl+opt+cmd+- keys="⌃⌥⌘-" ;;
    balance) chord=ctrl+opt+cmd+0 keys="⌃⌥⌘0" ;;
    *) die "resize_key: grow, shrink or balance, not $1" ;;
  esac
  walk_act resize "$1" "presses $keys"
  key "$chord"
  changed
  acted moves=docked front="$window"
}

# MARK: The view

view() {
  local chord keys window wants=""
  arbor_acts || { left_out "view $1: Arbor is not acting"; return; }
  window=$(front_window)
  case "$1" in
    frame)
      [ -n "$window" ] && is managed "$window" 2>/dev/null || { left_out "view frame: Arbor does not arrange the window in front"; return; }
      chord=ctrl+opt+return keys="⌃⌥↩" wants="front=$window" ;;
    out) chord=ctrl+opt+up keys="⌃⌥↑" ;;
    in) chord=ctrl+opt+down keys="⌃⌥↓" ;;
    left) chord=ctrl+opt+left keys="⌃⌥←" ;;
    right) chord=ctrl+opt+right keys="⌃⌥→" ;;
    back) chord="ctrl+opt+[" keys="⌃⌥[" ;;
    forward) chord="ctrl+opt+]" keys="⌃⌥]" ;;
    desktop) chord=ctrl+opt+d keys="⌃⌥D" ;;
    # Show Everything is about one display.
    all) chord=ctrl+opt+space keys="⌃⌥Space"; [ -n "$WALK_SECOND" ] || wants="everything=1 tiles=ok $(back_home)" ;;
    home) chord=ctrl+opt+0 keys="⌃⌥0" wants="everything=1 tiles=ok $(back_home)" ;;
    *) die "view: no such move: $1" ;;
  esac
  walk_act view "view-$1" "presses $keys"
  key "$chord"
  # shellcheck disable=SC2086
  acted moves=any $wants
  case "$1" in
    all) [ -n "$WALK_SECOND" ] || at_home ;;
    home) at_home ;;
  esac
}

peek() {
  arbor_acts || { left_out "peek: Arbor is not acting"; return; }
  walk_act view peek "holds ⌃⌥Space for a second and a half and lets go"
  key ctrl+opt+space --down
  sleep 1.5
  key ctrl+opt+space --up
  acted moves=any
}

save_view() {
  arbor_acts || { left_out "save_view $1: Arbor is not acting"; return; }
  case "$1" in [1-9]) ;; *) die "save_view: 1 to 9, not $1" ;; esac
  walk_act view "save-view-$1" "presses ⌃⌥⇧$1"
  key "ctrl+opt+shift+$1"
  # Remembering where one looks moves nothing.
  acted
}

view_n() {
  arbor_acts || { left_out "view_n $1: Arbor is not acting"; return; }
  case "$1" in [1-9]) ;; *) die "view_n: 1 to 9, not $1" ;; esac
  walk_act view "view-$1" "presses ⌃⌥$1"
  key "ctrl+opt+$1"
  acted moves=any
}

# MARK: macOS's own

full_screen() {
  local window
  case "$1" in
    on)
      [ -z "$WALK_FULL_SCREEN" ] || { left_out "full_screen on: a window is in full screen already"; return; }
      present safari || { left_out "full_screen on: played in Safari, which is not there"; return; }
      [ "$(name_of_pid "$(front_pid)")" = safari ] || switch_dock safari
      window=$(front_window)
      [ "$(name_of_pid "$(front_pid)")" = safari ] && [ -n "$window" ] || { left_out "full_screen on: Safari did not come forward"; return; }
      walk_act macos-own full-screen "presses ⌃⌘F in Safari"
      key ctrl+cmd+f
      sleep 2
      WALK_FULL_SCREEN="$window $DAY_STEP"
      acted moves=any leaves=any audit=no ;;
    off)
      [ -n "$WALK_FULL_SCREEN" ] || { left_out "full_screen off: nothing is in full screen"; return; }
      window=${WALK_FULL_SCREEN% *}
      walk_act macos-own leave-full-screen "presses ⌃⌘F again"
      key ctrl+cmd+f
      sleep 2
      # Every window is where it was before.
      acted moves=any leaves=any comes="$window" front="$window" returns="$((${WALK_FULL_SCREEN#* } - 1))"
      WALK_FULL_SCREEN="" ;;
    *) die "full_screen: on or off, not $1" ;;
  esac
}

title_double_click() {
  local x y role window before=$DAY_STEP
  can_be_dragged "$1" || { left_out "title_double_click $1: no free point of its title bar shows"; return; }
  window=$(window_of "$1")
  read -r x y role <<< "$(apptool grab "$window")"
  walk_act macos-own "double-click-$1" "double-clicks $1's title bar: macOS zooms the window"
  dblclick "$x" "$y"
  move "$x" "$((y + 120))"
  # macOS's frame stays, and nobody else moves.
  acted zooms="$window" front="$window"
  read -r x y role <<< "$(apptool grab "$window" 2>/dev/null)"
  [ -n "${x:-}" ] || { changed; left_out "title_double_click $1: no free point of its title bar shows for the second one"; return; }
  walk_act macos-own "double-click-$1-again" "double-clicks it again: macOS takes the window back"
  dblclick "$x" "$y"
  move "$x" "$((y + 120))"
  acted zooms="$window" front="$window" returns="$before"
}

wallpaper_click() {
  local spot before=$DAY_STEP
  [ -z "$WALK_FULL_SCREEN" ] && spot=$(bare_spot) || { left_out "wallpaper_click: no bare spot of wallpaper shows"; return; }
  walk_act macos-own click-wallpaper "clicks on the wallpaper"
  # shellcheck disable=SC2086
  click $spot
  sleep 1
  acted moves=any leaves=any audit=no
  walk_act macos-own click-wallpaper-again "clicks on the wallpaper again"
  # shellcheck disable=SC2086
  click $spot
  sleep 1
  acted moves=any leaves=any returns="$before"
}

# MARK: Displays

# A display comes, goes, moves or changes size: the windows on the displays concerned may move; afterwards nothing is lost.
display() {
  local width=1920 height=1080
  [ -n "$WALK_TWO" ] && [ -z "$WALK_FULL_SCREEN" ] || { left_out "display $1: this walk has one display"; return; }
  case "$1" in
    plug) [ -z "$WALK_SECOND" ] || { left_out "display plug: it is plugged in"; return; } ;;
    unplug | left | right) [ -n "$WALK_SECOND" ] || { left_out "display $1: it is not plugged in"; return; } ;;
    # Another size is another display in its place: two things that happen, so two acts.
    smaller | larger)
      [ -n "$WALK_SECOND" ] || { left_out "display $1: it is not plugged in"; return; }
      display unplug
      [ "$1" = larger ] || WALK_NEXT_SIZE="1280 800"
      display plug
      return ;;
    *) die "display: no such change: $1" ;;
  esac
  walk_act display-change "display-$1" "the second display: $1"
  case "$1" in
    plug)
      read -r width height <<< "${WALK_NEXT_SIZE:-1920 1080}"
      WALK_NEXT_SIZE=""
      display_add "$width" "$height" right
      WALK_SECOND=yes ;;
    unplug) display_remove; WALK_SECOND="" ;;
    left | right) display_move "$1" ;;
  esac
  sleep 2
  # macOS gives the main display another size when the virtual one comes and goes.
  read -r _ WALK_X WALK_Y WALK_W WALK_H _ <<< "$(pointer displays | head -n 1)"
  changed
  acted moves=any leaves=any
  # The view may be framed, with windows out of view by rights. Whether one is lost shows when everything is asked for.
  view home
}

move_to_display() { send_across; }

send_across() {
  local window
  arbor_acts && [ -n "$WALK_SECOND" ] || { left_out "send_across: there is no second display, or Arbor is not acting"; return; }
  window=$(front_window)
  [ -n "$window" ] && is managed "$window" 2>/dev/null || { left_out "send_across: Arbor does not arrange the window in front"; return; }
  walk_act dock-key send-across "sends the window in front to the other display"
  must ctl move-to-display next
  changed
  # Where it lands there is its place from now on.
  acted moves=docked,"$window" front="$window" place="$window"
}

# MARK: The ways out

# A pause is as if Arbor had quit, and it comes back (QUESTIONS Q21): every window at its own frame and nothing raised, then everything as it was.
pause() {
  local front
  arbor_acts || { left_out "pause: Arbor is not acting"; return; }
  front=$(front_window)
  walk_act way-out pause "presses ⌃⌥⎋"
  key ctrl+opt+escape
  WALK_PAUSED=yes WALK_BEFORE_PAUSE=$((DAY_STEP - 1)) WALK_MOVED_IN_PAUSE=""
  changed
  acted moves=any restores=all places=1 everything=1 ${front:+front="$front"}
}

resume() {
  [ -n "$WALK_PAUSED" ] || { left_out "resume: Arbor is not paused"; return; }
  walk_act way-out resume "presses ⌃⌥⎋"
  key ctrl+opt+escape
  WALK_PAUSED=""
  # A floating window its person moved meanwhile stays where they put it.
  acted moves=any ${WALK_BEFORE_PAUSE:+returns="$WALK_BEFORE_PAUSE" ${WALK_MOVED_IN_PAUSE:+but="$WALK_MOVED_IN_PAUSE"}}
  WALK_BEFORE_PAUSE=""
  # The pause ended the trace.
  day_trace
}

float_all() {
  arbor_acts || { left_out "float_all: Arbor is not acting"; return; }
  walk_act way-out float-all "presses ⌃⌥⇧F"
  key ctrl+opt+shift+f
  acted moves=any restores=all places=1 everything=1
  at_home
}

float_all_here() {
  arbor_acts || { left_out "float_all_here: Arbor is not acting"; return; }
  walk_act way-out float-all-here "floats every window of this display"
  must ctl float-all here
  changed
  # With one display that is all of them.
  if [ -z "$WALK_SECOND" ]; then acted moves=any restores=all places=1 everything=1; at_home; else acted moves=any; fi
}

# Held, the view stays where it is whatever is pressed, and windows out of view stay there, so hardly an act means what it means otherwise. So the three
# belong together: the hold, a key that would move the view and must not, and the release.
hold_view() {
  arbor_acts || { left_out "hold_view: Arbor is not acting"; return; }
  walk_act way-out hold "holds the view, as for a shared screen"
  must ctl hold || { acted; return; }
  acted
  walk_act view show-desktop-while-held "presses ⌃⌥D, which would show the Desktop: the view is held"
  key ctrl+opt+d
  acted
  walk_act way-out release "lets the view go again"
  must ctl release
  # What waited to come into view may do so now.
  acted moves=any
}
release_view() { left_out "release_view: hold_view lets go by itself"; }

walk_quit() {
  walk_act quit-and-start quit "chooses Quit Arbor in Arbor's menu"
  must arbor_menu up return
  want "Arbor ends within five seconds" day_gone
  WALK_PAUSED="" WALK_BEFORE_PAUSE=""
  acted moves=any restores=all places=1 everything=1
}

walk_roll_call() {
  local name
  for name in $WALK_CAST; do switch_dock "$name"; done
}

walk_start() {
  local welcome
  walk_act quit-and-start launch "starts Arbor"
  day_launch || die "Arbor did not start"
  # What was docked when it stopped may go back. No window that is in view goes out of view.
  acted moves=docked everything=1
  # What Arbor has to say at its first start lies in the middle of the screen, over the windows. A person reads it and closes it.
  welcome=$(arbor_window)
  if [ -n "$welcome" ]; then
    walk_act open-close close-welcome "closes Arbor's welcome window with its red button"
    # shellcheck disable=SC2046
    must click $(apptool button "$welcome" close)
    acted
  fi
  changed
}

quit_and_start() {
  with_arbor && arbor_answers && [ -z "$WALK_FULL_SCREEN" ] || { left_out "quit_and_start: Arbor is not running"; return; }
  walk_quit
  walk_roll_call
  walk_start
}

idle_act() {
  walk_act idle leave-alone "does nothing for half a minute"
  idle 30
  acted
}

# MARK: The beginning and the end

walk_open() {
  local name=$1 document
  document=$(document_of "$name")
  act open-close "open-$name" "opens $name"
  # shellcheck disable=SC2086
  if APP_WAIT=25 meet "$name" "$(bundle_of "$name")" ${document:+"$document"}; then
    # Mail without an account asks for one in a sheet, and swaps its windows for others when the sheet is answered. It is left alone: a window with a sheet.
    [ "$name" = mail ] || app_dismiss "$APP_PID" || echo "a sheet or dialog stayed in the way"
    WALK_CAST="$WALK_CAST $name"
  else
    echo "$name opened no standard window: the walk goes on without it"
    eval "W_$name= P_$name="
  fi
  acted setup=1
}

fills_the_display() {
  local x y w h
  read -r x y w h <<< "$(real_of "$1")"
  [ "${w:-0}" -ge $((WALK_W - 40)) ] && [ "${h:-0}" -ge $((WALK_H - 160)) ]
}

walk_begin() {
  local cast=${1:-stock} display=${2:-laptop} tiling=${3:-defaults} seed=${4:-} commit=${5:-} name listed probe seen
  apps_watchdog "${WALK_LIMIT:-1060}"
  step "the Mac"
  echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m)"
  if with_arbor; then day_build; else day_build_tools; fi
  # The runner's own 1024×768 is smaller than any Mac's.
  case "$display" in
    laptop) display_mode 1440x900 1600x900 1680x1050 1920x1080 ;;
    desk) display_mode 1920x1080 ;;
    two) display_mode 1440x900 1600x900 1680x1050 1920x1080; WALK_TWO=yes ;;
    *) die "walk_begin: laptop, desk or two, not $display" ;;
  esac
  case "$tiling" in
    defaults)
      echo "macOS's own window management, as it comes:"
      # A script before this one on the same Mac may have switched it off.
      if defaults read com.apple.WindowManager 2>/dev/null | grep -Eq "EnableTil|EnableTopTil|EnableStandardClick"; then
        for name in EnableTilingByEdgeDrag EnableTopTilingByEdgeDrag EnableTilingOptionAccelerator EnableStandardClickToShowDesktop; do
          defaults delete com.apple.WindowManager "$name" 2>/dev/null
        done
        killall WindowManager 2>/dev/null
        sleep 1
      fi
      macos_tiling
      macos_click_wallpaper ;;
    off)
      echo "macOS's own window management, switched off:"
      defaults write com.apple.WindowManager EnableTilingOptionAccelerator -bool false
      macos_tiling off
      macos_click_wallpaper off ;;
    *) die "walk_begin: defaults or off, not $tiling" ;;
  esac
  # GitHub's Macs come with Reduce Motion on. A person's Mac does not, and with it on Arbor shows no motion.
  macos_reduce_motion "${WALK_REDUCE_MOTION:-off}"
  day_scratch
  sampler_start
  watch_start day-macos.log
  note "tiling $tiling"
  read -r _ WALK_X WALK_Y WALK_W WALK_H _ <<< "$(pointer displays | head -n 1)"

  chapter "Before Arbor: the apps are open already"
  case "$cast" in
    stock) for name in finder safari textedit terminal notes calendar settings preview mail; do walk_open "$name"; done ;;
    *) die "walk_begin: no cast called $cast" ;;
  esac
  # The Dock grows with every app that joins it, and the space between it and the menu bar shrinks.
  sleep 3
  # An app may have swapped the window it opened with for another meanwhile: Mail's first one gives way to its real one.
  for name in $WALK_CAST; do
    listed=$(app_windows "$(pid_of "$name")")
    case " $listed " in
      *" $(window_of "$name") "*) ;;
      *) [ -z "$listed" ] || { eval "W_$name=\${listed%% *}"; label "$(window_of "$name")" "$name"; } ;;
    esac
  done
  echo "the cast:$WALK_CAST"
  [ "$(echo "$WALK_CAST" | wc -w)" -ge 6 ] || die "fewer than six apps opened a window: no walk to speak of"

  # A switch that is written and not obeyed proves nothing: before anything counts, macOS is seen to fill the screen, or not to.
  probe=$(window_of calendar)
  [ -n "$probe" ] || probe=$(window_of "${WALK_CAST##* }")
  act drag-where-macos-tiles tiling-acts "without Arbor: drags a window by its title bar against the menu bar and lets go"
  # All of it in front, so that the middle of its title bar is free.
  dock_click "$(bundle_of "$(name_of_pid "$(pointer windows | awk -v id="$probe" '$1 == id { print $2 }')")")"
  sleep 0.5
  must drag_window "$probe" "$((WALK_X + WALK_W / 2))" "$WALK_Y" --hold 1
  acted setup=1
  if eventually fills_the_display "$probe"; then seen=true; else seen=false; fi
  echo "macOS's tiling was seen to act: $seen"
  if [ "$tiling" = defaults ]; then check "macOS's own tiling acts" test "$seen" = true; else check "macOS's own tiling is off" test "$seen" = false; fi
  act drag-where-macos-tiles tiling-acts-back "drags it away again, a hand's breadth down"
  must drag_window "$probe" "$((WALK_X + WALK_W / 2))" "$((WALK_Y + 130))"
  acted setup=1
  act idle look-around "looks at the screen"
  sleep 2
  acted setup=1 own=all

  day_manifest kind "\"$(if [ -n "${WALK_KIND:-}" ]; then echo "$WALK_KIND"; elif ! with_arbor; then echo control; elif [ -n "$seed" ]; then echo walk; else echo day; fi)\""
  day_manifest seed "\"$seed\""
  # The commit the seed was taken from, which is the one being judged if nobody chose the seed.
  day_manifest seed_commit "\"$commit\""
  day_manifest tiling "\"$tiling\""
  day_manifest tiling_seen_to_act "$seen"
  day_manifest display "\"$display\""
  day_manifest cast "\"$cast\""
  day_manifest apps "[$(for name in $WALK_CAST; do printf '"%s",' "$(bundle_of "$name")"; done | sed 's/,$//')]"

  chapter "The walk"
  if with_arbor; then walk_start; fi
  at_home
}

walk_end() {
  if [ -n "$WALK_FULL_SCREEN" ]; then full_screen off; fi
  if [ -n "$WALK_SECOND" ]; then display unplug; fi
  if [ -n "$WALK_PAUSED" ]; then resume; fi
  while [ -n "${WALK_HIDDEN// /}" ]; do unhide; done
  while [ -n "${WALK_MINIMIZED// /}" ]; do restore; done
  if with_arbor && arbor_answers; then
    chapter "The end"
    walk_quit
    walk_roll_call
  fi
  echo
  echo "$WALK_ACTS acts, $WALK_LEFT_OUT left out because they did not apply"
  day_manifest acts_left_out "$WALK_LEFT_OUT"
  day_report
}
