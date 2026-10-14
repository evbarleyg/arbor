#!/bin/bash
# What real apps do that the drill in compat.sh has no step for: native tabs, sheets and panels, full screen, a window that
# resizes itself, the green button, Arbor starting again. Same harness, same verdicts, a matrix of its own (mac-shell/extras.md).
#
#   scripts/mac-shell/compat-extras.sh [experiment…]
#
# Experiments: tabs-finder tabs-terminal tabs-textedit tabs-safari sheet dialog font titlebar restart fullscreen (default: all, in
# that order; COMPAT_EXTRAS="…" does the same as arguments). Full screen comes last: it changes Spaces, and a Mac that
# did not come back from that is no place for another experiment.
source "$(dirname "${BASH_SOURCE[0]}")/compat.sh"
CELLS="$ARBOR_OUT/extras.tsv"
ALL_EXTRAS="tabs-finder tabs-terminal tabs-textedit tabs-safari sheet dialog font titlebar restart fullscreen"

# Opens an app from compat.sh's table, starts Arbor, docks the app's window left and a neighbour right.
# experiment <name> <app>
experiment() {
  local session=all
  APP=$1
  STEP_INDEX=0
  S="" P="" MIN_W=0 MIN_H=0
  configure "$2"
  if ! on_throwaway_mac && app_running "$BUNDLE"; then
    skip setup "$2 is running already, with somebody's windows"
    return 1
  fi
  [ "$SCOPE" = all ] && watch_start "$APP-macos.log"
  begin setup
  subject_open
  want "a standard window opened" test -n "$S"
  if [ -z "$S" ]; then
    finish no-audit
    drill_end
    return 1
  fi
  FIRST_P=$P
  [ "$SCOPE" = all ] || { watch_start "$APP-macos.log" "$P" "$COMPANIONS_PID"; session="$P $COMPANIONS_PID"; }
  app_dismiss "$P"
  read -r MIN_W MIN_H <<< "$(apptool limits "$S" | awk '{ split($2, a, "x"); printf "%d %d", a[1], a[2] }')"
  # shellcheck disable=SC2086
  if ! arbor_start_apps $session $FACE; then
    want "Arbor started" false
    finish no-audit
    drill_end
    return 1
  fi
  run dock "$S" left
  run dock "$C1" right
  sleep 0.5
  make_room
  want "the window is in view" in_view "$S"
  finish
}

# The three views of an app's windows side by side: Accessibility's, the window server's, Arbor's.
three_views() {
  echo "Accessibility lists (id role subrole x y w h flags):"
  apptool windows "$P" | sed 's/^/  /'
  echo "the window server has (id pid level x y w h on owner):"
  pointer windows | awk -v pid="$P" '$2 == pid && $6 > 60' | sed 's/^/  /'
  echo "Arbor believes:"
  brief | sed 's/^/  /'
}

docked_of_app() { "$ARBOR_BIN/arborctl" state | python3 "$ARBOR_COMPAT_PY" ids "$P" | wc -w | tr -d ' '; }

# The window of the app that a person sees now: on screen for the window server, at the ordinary level, of some size,
# and not parked in a corner.
showing() {
  local id
  for id in $(pointer windows | awk -v pid="$P" '$2 == pid && $3 == 0 && $8 == "on" && $6 > 200 { print $1 }'); do
    if [ "$(pointer visible "$id" | tr -d .)" -ge 50 ]; then
      echo "$id"
      return 0
    fi
  done
}

# Whether window $1 is where the frame "$2" says, give or take a row or column of character cells.
sits_at() {
  local x y w h sx sy sw sh
  read -r x y w h <<< "$(real_of "${1:-0}" 2>/dev/null)"
  read -r sx sy sw sh <<< "$2"
  [ -n "${h:-}" ] && [ -n "${sh:-}" ] || return 1
  between "$((x - sx))" -2 2 && between "$((y - sy))" -2 2 && between "$((sw - w))" -2 24 && between "$((sh - h))" -2 24
}

# Native tabs: every tab is a window of its own, and only the selected one is on screen.
# tabs <app> <how to open a tab>
tabs() {
  local slot shown
  experiment "tabs-$1" "$1" || return 0
  slot=$(slot_of "$S")

  begin new-tab
  want "a click on its title bar brings its app to the front" app_focus "$S"
  case "$2" in
    key*) key "${2#key }" ;;
    # safe anywhere: on a person's Mac an app that was running already was left out at the start, so this one is the script's own
    open*) mark "open another document"; open -b "$BUNDLE" "${2#open }" ;;
  esac
  sleep 1.2
  three_views
  shown=$(showing)
  echo "showing: ${shown:-nothing}; the tab's window ${S}'s slot was $slot"
  want "what shows is where the slot is" sits_at "$shown" "$slot"
  want "Arbor has the window that shows in that slot" eventually has_slot "${shown:-0}" "$slot"
  finish

  begin switch-tab
  key ctrl+tab
  sleep 1
  three_views
  shown=$(showing)
  want "what shows is where the slot is" sits_at "$shown" "$slot"
  want "Arbor has the window that shows in that slot" eventually has_slot "${shown:-0}" "$slot"
  finish

  begin zoom-neighbour
  run zoom "$C1"
  sleep 0.5
  want "nothing of the app shows" test -z "$(showing)"
  finish

  begin back
  run back
  sleep 0.5
  shown=$(showing)
  want "what shows is where the slot is" sits_at "$shown" "$slot"
  finish

  begin close-tab
  shown=$(showing)
  [ -n "$shown" ] && app_focus "$shown"
  key cmd+w
  sleep 1
  three_views
  shown=$(showing)
  want "what shows is where the slot is" sits_at "$shown" "$slot"
  want "Arbor arranges one window of the app" test "$(docked_of_app)" = 1
  finish

  S=$(showing)
  quit_arbor
  drill_end
}

# A sheet belongs to its window: it has to travel with it, and Arbor has to leave it alone (T64).
sheet() {
  local id
  experiment sheet textedit || return 0

  begin open-sheet
  want "a click on its title bar brings its app to the front" app_focus "$S"
  key cmd+shift+p
  sleep 1.2
  three_views
  want "the window has a sheet" test -n "$(apptool describe "$S" | grep sheets=)"
  want "Arbor arranges one window of the app" test "$(docked_of_app)" = 1
  finish

  for id in zoom back desktop; do
    begin "sheet-$id"
    if [ "$id" = zoom ]; then run zoom "$S"; else run "$id"; fi
    sleep 0.6
    echo "the window server has (id pid level x y w h on owner):"
    pointer windows | awk -v pid="$P" '$2 == pid && $6 > 60' | sed 's/^/  /'
    finish
  done

  begin sheet-desktop-back
  run back
  want "the window still has its sheet" test -n "$(apptool describe "$S" | grep sheets=)"
  finish
  apptool press "$P" "Cancel" || key escape
  sleep 0.6

  quit_arbor
  drill_end
}

# Terminal keeps its rows and columns when the font grows, so the window resizes itself out of its slot.
font() {
  local round x y w h
  experiment font terminal || return 0
  for round in 1 2 3; do
    begin "bigger-$round"
    [ "$round" -eq 1 ] && want "a click on its title bar brings its app to the front" app_focus "$S"
    echo "before: window $(real_frame_of "$S"), slot $(slot_of "$S")"
    key cmd+shift+=
    sleep 0.15
    echo "at once: window $(real_frame_of "$S")"
    sleep 1
    echo "a second later: window $(real_frame_of "$S")"
    want "the window is still in view" in_view "$S"
    finish
  done
  ctl show-all
  go_home
  begin seam-with-cells
  read -r x y w h <<< "$(slot_of "$S")"
  drag "$((x + w + ARBOR_GAP / 2))" "$((y + h / 2))" "$((x + w + ARBOR_GAP / 2 + 37))" "$((y + h / 2))"
  sleep 0.5
  echo "slot $(slot_of "$S"), window $(real_frame_of "$S")"
  want "the window is still in view" in_view "$S"
  finish
  quit_arbor
  drill_end
}

# What people do to a title bar besides dragging it: a double-click, and the green button.
titlebar() {
  local x y role point
  experiment titlebar textedit || return 0

  begin double-click
  read -r x y role <<< "$(apptool grab "$S")"
  echo "before: $(real_frame_of "$S")"
  dblclick "$x" "$y"
  sleep 0.3
  echo "at once: $(real_frame_of "$S")"
  sleep 1.2
  echo "later: $(real_frame_of "$S")"
  want "it is docked" is docked "$S"
  finish

  begin option-green-button
  ctl show-all
  sleep 0.5
  if point=$(apptool button "$S" zoom); then
    # ⌥-click zooms the window; a plain click would take it to full screen.
    # shellcheck disable=SC2086
    click $point --mods opt
    sleep 1.5
    echo "later: $(real_frame_of "$S")"
  fi
  want "it is docked" is docked "$S"
  finish

  begin cmd-drag-behind
  # Moving a window of an app in the background by ⌘-dragging its title bar does not bring it forward.
  app_focus "$C1"
  read -r x y role <<< "$(apptool grab "$S")"
  drag "$x" "$y" "$((x + 200))" "$((y + 200))" --mods cmd
  sleep 1
  finish

  quit_arbor
  drill_end
}

# A panel of the app's own (TextEdit's Open panel) is not a standard window: Arbor leaves it alone (T64). What becomes of it
# when its app's window goes out of view?
dialog() {
  experiment dialog textedit || return 0

  begin open-panel
  want "a click on its title bar brings its app to the front" app_focus "$S"
  key cmd+o
  sleep 1.5
  three_views
  want "Arbor arranges one window of the app" test "$(docked_of_app)" = 1
  want "the window kept its slot" in_view "$S"
  finish

  begin panel-zoom-neighbour
  run zoom "$C1"
  sleep 0.6
  three_views
  finish

  begin panel-back
  run back
  want "the window is in view" eventually in_view "$S"
  finish
  apptool press "$P" "Cancel" || key escape
  sleep 0.6

  quit_arbor
  drill_end
}

# Quits Arbor (or kills it) and starts it again on the same home folder, so that it finds its saved arrangement.
arbor_again() {
  local session=all
  [ "$SCOPE" = all ] || session="$P $COMPANIONS_PID"
  mark "Arbor goes ($1) and comes back"
  if [ "$1" = kill ]; then kill -KILL "$ARBOR_PID"; else ctl quit; fi
  apps_end "$ARBOR_PID"
  ARBOR_PID=""
  sleep 0.5
  # shellcheck disable=SC2086
  arbor_start_apps $session $FACE
  sleep 0.5
}

# Arrangements are saved and restored when Arbor starts again (T60), whatever state the windows are in by then.
restart() {
  local home
  experiment restart textedit || return 0
  home=$(slot_of "$S")
  # The arrangement is saved half a second after a change.
  sleep 1

  begin plain
  arbor_again quit
  want "the window is docked" is docked "$S"
  want "it is in the slot it had" eventually has_slot "$S" "$home"
  want "so is the neighbour" in_view "$C1"
  finish

  begin minimized
  apptool minimize "$S"
  eventually is minimized "$S"
  sleep 1.5
  arbor_again quit
  echo "Accessibility lists:"
  apptool windows "$P" | sed 's/^/  /'
  want "Arbor knows the minimized window" is managed "$S"
  want "it is still docked" is docked "$S"
  apptool unminimize "$S"
  sleep 1.5
  want "restored, it is in the slot it had" eventually has_slot "$S" "$home"
  finish
  is docked "$S" || go_home
  ctl show-all
  sleep 1

  begin hidden
  apptool hide "$P"
  eventually is hidden "$S"
  sleep 1
  arbor_again quit
  want "Arbor knows the hidden window" is managed "$S"
  want "it is still docked" is docked "$S"
  apptool unhide "$P"
  sleep 1.5
  want "shown, it is in the slot it had" eventually has_slot "$S" "$home"
  finish
  is docked "$S" || go_home
  ctl show-all
  sleep 1

  begin killed-while-zoomed
  run zoom "$C1"
  want "the window is parked" eventually is parked "$S"
  sleep 1
  arbor_again kill
  echo "after the kill and the restart the window is at $(real_frame_of "$S")"
  run show-all
  want "the window is in the slot it had" eventually has_slot "$S" "$home"
  want "it is on screen" eventually is on_screen "$S"
  finish

  quit_arbor
  drill_end
}

# Full screen is macOS's own (T63): Arbor has to let go of the window, and take it back afterwards.
fullscreen() {
  local x y w h
  experiment fullscreen textedit || return 0

  begin enter
  want "a click on its title bar brings its app to the front" app_focus "$S"
  read -r x y w h <<< "$(arbor_ask screen)"
  move "$((x + w / 2))" "$((y + h / 2))"
  key ctrl+cmd+f
  sleep 3
  three_views
  want "the window is in full screen" test -n "$(apptool describe "$S" | grep fullscreen)"
  sleep 2
  want "and still is two seconds later" test -n "$(apptool describe "$S" | grep fullscreen)"
  finish

  begin leave
  key ctrl+cmd+f
  sleep 3.5
  three_views
  want "the window left full screen" test -z "$(apptool describe "$S" | grep fullscreen)"
  want "it is docked" is docked "$S"
  want "it is in view" eventually in_view "$S"
  finish

  quit_arbor
  drill_end
}

# shellcheck disable=SC2086
set -- "$@" ${COMPAT_EXTRAS:-}
# shellcheck disable=SC2086
[ $# -gt 0 ] || set -- $ALL_EXTRAS

prepare
for name in "$@"; do
  started=$SECONDS
  case "$name" in
    tabs-finder) tabs finder "key cmd+t" ;;
    tabs-terminal) tabs terminal "key cmd+t" ;;
    tabs-safari) tabs safari "key cmd+t" ;;
    tabs-textedit)
      # "Prefer tabs when opening documents: always", a setting many people have. Theirs, so only on a throwaway Mac.
      if on_throwaway_mac; then
        defaults write NSGlobalDomain AppleWindowTabbingMode -string always
        tabs textedit "open $APPS_SCRATCH/elm.txt"
        defaults delete NSGlobalDomain AppleWindowTabbingMode
      else
        APP=tabs-textedit
        skip setup "needs the system-wide tab setting changed"
      fi ;;
    sheet | dialog | font | titlebar | restart | fullscreen) "$name" ;;
    *) echo "compat-extras.sh: no experiment called $name" ;;
  esac
  echo
  echo "$name: $((SECONDS - started)) s"
done

step "the matrix"
matrix | tee "$ARBOR_OUT/extras.md"
