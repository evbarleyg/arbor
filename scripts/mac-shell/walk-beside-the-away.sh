#!/bin/bash
# "A window would not dock on the right while another window was minimized" (IDEAS I21), played with real browsers at macOS's own settings.
#
#   scripts/mac-shell/run.sh --priority 1 scripts/mac-shell/walk-beside-the-away.sh scripts/mac-shell/walk-beside-the-away-first-build.sh
#
# One road to the complaint needs no Mac (collab/scenarios/67-a-key-acts-on-what-shows.sim): out of a column whose other window is away, the key that moves
# a docked window took a step nobody could see. The questions only a Mac can answer:
#   1. Is a real window in the Dock, or of an app hidden with ⌘H, as absent to Arbor as the stand-ins' is? Then the first build takes two presses in "a column
#      of which one is away", and this one takes one, with every size as it was.
#   2. Is there another road? A browser's window docked on the right, by the key, by the menu and by hand, while a window is in the Dock that floats, that is
#      docked, that is the browser's own second window, that went there before Arbor started.
#   3. By hand against the right edge with macOS's tiling on, where the edge is macOS's (QUESTIONS Q23): what becomes of the window, and WHAT DOES ARBOR SAY, at the
#      last point and a few points short of it?
#
# A walk written by hand (lib-walk.sh): every act is judged as a day's is, each chapter has a trace of its own, and an act that does not apply is left out and said so.
# After each round `told` prints what a reader needs: what Arbor answered and said on screen since the last time, and the windows that show, from left to right.
#
# WALK_OLD_BUILD=<commit>: the same walk with the Arbor of that commit, built beside this one (walk-beside-the-away-first-build.sh).
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"

TOLD=0

# What Arbor answered to the commands and said on screen since the last time, then which of the cast's windows show, from left to right, with their widths.
told() {
  local name window
  echo
  echo "-- told after: $*"
  arbor_log_since "$TOLD" | grep -E "(INFO|DEBUG) +(dock|arrange|float|move)[a-z-]*( [a-z0-9]+)*( failed)?: |said on " | cut -c 1-220 | sed 's/^/   /'
  TOLD=$(arbor_log_lines)
  for name in $WALK_CAST; do
    window=$(window_of "$name")
    shows "$window" 2> /dev/null || continue
    echo "$name $(if is docked "$window" 2> /dev/null; then echo docked; else echo floats; fi) $(real_of "$window")"
  done | sort -n -k 3 | awk '{ printf "   %-9s %-7s x %5d  y %4d  %4d × %d\n", $1, $2, $3, $4, $5, $6 }'
}

# Against the right edge, but let go a few points short of macOS's own: within the band that is macOS's by Q23.
drag_short_of_the_edge() {
  local window own=""
  can_be_dragged "$1" || { left_out "drag_short_of_the_edge $*: nothing to take hold of"; return; }
  window=$(window_of "$1")
  walk_act drag-where-macos-tiles "drag-$1-short-of-the-right-edge" "drags $1 by its title bar towards the right edge of the screen and lets go six points short of it"
  must drag_window "$window" "$((WALK_X + WALK_W - 7))" "$((WALK_Y + WALK_H / 2))" --hold 1
  changed
  if ! { arbor_answers && eventually is docked "$window"; }; then own="own=$window"; fi
  # shellcheck disable=SC2086
  acted drags="$window" moves=docked front="$window" $own
}

# Dock Focused Window ▸ Right, with the pointer.
dock_menu_right() {
  local window
  window=$(front_window)
  [ -n "$window" ] && is managed "$window" 2> /dev/null || { left_out "dock_menu_right: Arbor does not arrange the window in front"; return; }
  walk_act dock-key dock-right-by-menu "chooses Dock Focused Window ▸ Right in Arbor's menu"
  must click_menu "Dock Focused Window" "Right"
  changed
  want "it is docked" eventually is docked "$window"
  acted moves=docked front="$window"
}

# The Arbor of another commit, in a checkout of its own beside this one; the tools and the harness stay this commit's.
if [ -n "${WALK_OLD_BUILD:-}" ]; then
  eval "$(declare -f day_build | sed '1s/day_build/day_build_of_this_commit/')"
  day_build() {
    local old began=$SECONDS
    day_build_of_this_commit
    scratch_dir old-build old
    step "the Arbor of $WALK_OLD_BUILD"
    bounded 120 git -C "$ARBOR_ROOT" fetch --quiet --depth 1 origin "$WALK_OLD_BUILD" || die "that commit cannot be fetched"
    bounded 60 git -C "$ARBOR_ROOT" worktree add --quiet --detach "$old/arbor" FETCH_HEAD || die "no checkout of that commit"
    at_exit "git -C '$ARBOR_ROOT' worktree remove --force '$old/arbor'"
    ( cd "$old/arbor" && bounded 540 swift build --product Arbor && bounded 120 swift build --product arborctl ) > "$ARBOR_OUT/build-old.log" 2>&1 \
      || { tail -n 30 "$ARBOR_OUT/build-old.log"; die "that commit does not build"; }
    ARBOR_BIN="$old/arbor/.build/debug"
    echo "built in $((SECONDS - began)) s: $("$ARBOR_BIN/arborctl" version 2>&1 | head -n 1)"
  }
fi

walk_begin browsers laptop defaults
TOLD=$(arbor_log_lines)

chapter "In the complaint's own words, by the key: a floating window is in the Dock"
switch_to safari
dock_key left
switch_to textedit
minimize
switch_to chrome
dock_key right
told "Safari docked left, TextEdit (floating) in the Dock, ⌃⌥⌘→ on Chrome"
restore textedit
float_all

chapter "A column of which one is away: in the Dock"
switch_to safari
dock_key left
switch_to chrome
dock_key right
drag_onto firefox safari bottom
told "Safari above Firefox, Chrome to their right"
switch_to firefox
minimize
told "Firefox in the Dock: Safari fills the column"
switch_to safari
dock_key left
told "⌃⌥⌘← on Safari: nothing that shows lies beyond"
dock_key right
told "⌃⌥⌘→ on Safari, THE FIRST PRESS: is it to the right of Chrome, with both as wide as before?"
dock_key right
told "⌃⌥⌘→ on Safari, the second press"
restore firefox
told "Firefox is back: beside which window?"
float_all

chapter "A column of which one is away: hidden with ⌘H"
switch_to safari
dock_key left
switch_to chrome
dock_key right
drag_onto firefox safari bottom
switch_to firefox
hide
told "Firefox hidden: Safari fills the column"
switch_to safari
dock_key right
told "⌃⌥⌘→ on Safari, THE FIRST PRESS"
unhide firefox
told "Firefox is back"
float_all

chapter "A docked window is in the Dock, and the browser is docked by the key, by the menu and by hand"
switch_to safari
dock_key left
switch_to edge
dock_key right
minimize
told "Safari docked, Edge docked and in the Dock"
switch_to chrome
dock_key right
told "⌃⌥⌘→ on Chrome, which floated"
float_key
dock_menu_right
told "Chrome floated again; Dock Focused Window ▸ Right"
float_key
drag_onto chrome safari right
told "Chrome floated again; dragged onto the right part of Safari"
restore edge
told "Edge is back"
float_all

chapter "The browser's own other window is in the Dock"
switch_to safari
dock_key left
switch_to chrome
open_new
switch_backtick
minimize
dock_key right
told "Chrome's first window in the Dock, ⌃⌥⌘→ on its second"
restore chrome
close_new
float_all

chapter "By hand against the right edge, which is macOS's"
switch_to safari
dock_key left
switch_to textedit
minimize
drag_short_of_the_edge chrome
told "Chrome let go six points short of the right edge: WHAT DOES ARBOR SAY?"
drag_by chrome -300 0
drag_edge chrome right
told "Chrome let go at the last point of the right edge: WHAT DOES ARBOR SAY?"
switch_to chrome
dock_key right
told "⌃⌥⌘→ on Chrome, out of macOS's tile"
restore textedit
float_all

chapter "It went into the Dock before Arbor started"
walk_quit
switch_to edge
minimize
walk_start
TOLD=$(arbor_log_lines)
switch_to safari
dock_key left
switch_to chrome
dock_key right
told "Edge in the Dock since before the start, ⌃⌥⌘→ on Chrome"
restore edge
told "Edge is back"

walk_end
