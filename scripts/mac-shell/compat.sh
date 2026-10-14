#!/bin/bash
# The compatibility suite: Arbor against real Mac apps, one drill per app, and a matrix of app × step at the end.
#
#   ARBOR_APPS_HERE=1 scripts/mac-shell/compat.sh [app…]          on your own Mac (the terminal needs Accessibility and Screen
#                                                 Recording): read "On your own Mac" in lib-apps.sh first
#   scripts/mac-shell/run.sh --macs 2 scripts/mac-shell/compat.sh on two of GitHub's, from anywhere: every app, about 15 minutes
#
# Apps: textedit finder safari terminal calculator settings notes preview activity script fontbook calendar maps
# xcode (default: all but xcode; COMPAT_APPS="…" does the same as arguments, for run.sh, which passes none).
# COMPAT_STEPS=open stops each drill after its first step: a survey of what the apps open and how their windows resist.
#
# Each app gets a fresh Arbor and the same drill, through commands and through a real pointer and keyboard, beside two
# well-behaved test windows. After every step the screen is compared with what Arbor believes (compat.py audit) and a
# picture is taken: mac-shell/<app>-<nn>-<step>.jpg. A step is ✔, ✘, odd (it held, but something is worth a look)
# or – (does not apply). mac-shell/matrix.md has the matrix, mac-shell/<app>-story.log everything Arbor logged and
# macOS reported, in order of time. One app failing does not stop the next.
#
# On GitHub's Macs Arbor runs as a person runs it, arranging every regular app, with its shortcuts and its menu bar item. On
# your own Mac it is limited to the app under test and the test windows, so an app that comes back as a new process
# (quit and relaunched, or closed with its last window) is out of its reach, and those steps are skipped. There the
# suite changes no setting, and leaves out every app that is already running: its windows are yours.
source "$(dirname "${BASH_SOURCE[0]}")/lib-apps.sh"

ALL_APPS="textedit finder safari terminal calculator settings notes preview activity script fontbook calendar maps"
# Stop starting drills after this many seconds, and report the rest as not run: the workflow cuts a script off at 20 minutes. All
# thirteen apps take two Macs (run.sh --macs 2).
COMPAT_BUDGET=${COMPAT_BUDGET:-1000}

# What differs between apps. MORE is how a person gets a second window: a shortcut, or another document.
configure() {
  BUNDLE="" FILES="" MORE="" APP_WAIT=15 QUIT=quit
  case "$1" in
    textedit) BUNDLE=com.apple.TextEdit FILES="$APPS_SCRATCH/oak.txt" MORE="open $APPS_SCRATCH/elm.txt" ;;
    # Finder cannot be quit for good; killed, it comes straight back, which is what a relaunch is for it.
    finder) BUNDLE=com.apple.finder FILES="$APPS_SCRATCH/grove" MORE="open $APPS_SCRATCH/copse" QUIT=kill ;;
    safari) BUNDLE=com.apple.Safari FILES="$APPS_SCRATCH/page.html" MORE="key cmd+n" ;;
    terminal) BUNDLE=com.apple.Terminal MORE="key cmd+n" ;;
    calculator) BUNDLE=com.apple.calculator ;;
    settings) BUNDLE=com.apple.systempreferences APP_WAIT=25 ;;
    notes) BUNDLE=com.apple.Notes APP_WAIT=25 ;;
    preview) BUNDLE=com.apple.Preview FILES="$APPS_SCRATCH/leaf.png" MORE="open $APPS_SCRATCH/bark.png" ;;
    activity) BUNDLE=com.apple.ActivityMonitor ;;
    script) BUNDLE=com.apple.ScriptEditor2 FILES="$APPS_SCRATCH/hello.applescript" MORE="key cmd+n" ;;
    fontbook) BUNDLE=com.apple.FontBook APP_WAIT=25 ;;
    calendar) BUNDLE=com.apple.iCal APP_WAIT=25 ;;
    maps) BUNDLE=com.apple.Maps APP_WAIT=25 MORE="key cmd+n" ;;
    xcode) BUNDLE=com.apple.dt.Xcode APP_WAIT=40 ;;
    *) return 1 ;;
  esac
}

# Opens the app under test (again): S is its window, P its process.
subject_open() {
  # shellcheck disable=SC2086
  app_open "$BUNDLE" $FILES
  local code=$?
  S=$APP_WINDOW
  P=$APP_PID
  AUDIT_PIDS="$P"
  return "$code"
}

# Whether Arbor can see process $1: always when it arranges everything, otherwise only the ones it was started with.
reachable() { [ "$SCOPE" = all ] || [ "$1" = "$FIRST_P" ]; }

between() { [ "$1" -ge "$2" ] && [ "$1" -le "$3" ]; }

# Gives the subject a slot it fits, so that the steps after have a window to work on and not a tile. The Desktop
# keeps a column of its own between docked windows, so a third of a small screen is all a window gets at first.
make_room() {
  local x y w h need round=0
  while is tile "$S" && [ "$round" -lt 3 ]; do
    read -r x y w h <<< "$(arbor_ask tile "$S")"
    need=$((MIN_W - w + 24))
    [ "$need" -gt 0 ] || need=120
    echo "a tile in ${w}×${h}; its window wants at least ${MIN_W}×${MIN_H}: widening the slot by $need"
    # The Desktop gives what it has; after that the neighbours have to.
    [ "$round" -eq 0 ] || ctl resize "$C1" left "-$need"
    ctl resize "$S" right "$need"
    sleep 0.6
    round=$((round + 1))
  done
  ! is tile "$S"
}

# The title-bar buttons of a tile's window are parked with it. Frame it, as a click on the tile would.
bring_into_view() {
  in_view "$S" && return 0
  echo "the window is out of view; framing it"
  ctl zoom "$S"
  sleep 0.6
}

# Back to the drill's layout: the subject on the left, the Desktop, the neighbours on the right. Floating first, because
# `dock left` moves a window that is already docked one place over, not to the edge.
go_home() {
  ctl float "$S"
  ctl dock "$S" left
  sleep 0.6
  make_room
}

# A real drag of the subject by its title bar; the button stays down. Fails when no point of it can be grabbed.
grab_and_drag() {
  local x y role
  read -r x y role <<< "$(apptool grab "$S" 2>/dev/null)"
  if [ -z "${x:-}" ]; then
    apptool raise "$S"
    sleep 0.3
    read -r x y role <<< "$(apptool grab "$S" 2>/dev/null)"
  fi
  [ -n "${x:-}" ] || return 1
  echo "grabbing the title bar at $x,$y ($role)"
  mark "drag from $x,$y to $1,$2"
  drag "$x" "$y" "$1" "$2" --no-release
}

held_picture() { snap_now "$(printf '%s-%02d-%s-held' "$APP" "$STEP_INDEX" "$STEP")"; }

drill() {
  local x y w h before after point known old_s home session=all
  APP=$1
  STEP_INDEX=0
  S="" P="" MIN_W=0 MIN_H=0 FIXED="" FIXED_W=""
  configure "$APP" || { echo "compat.sh: no app called $APP"; return 1; }
  if ! on_throwaway_mac && app_running "$BUNDLE"; then
    skip open "it is running already, with somebody's windows"
    return 0
  fi
  [ "$SCOPE" = all ] && watch_start "$APP-macos.log"

  begin open
  subject_open
  want "a standard window opened" test -n "$S"
  if [ -z "$S" ]; then
    [ -n "$P" ] && apptool tree "$P" 3 | head -n 40
    finish no-audit
    drill_end
    return 0
  fi
  FIRST_P=$P
  [ "$SCOPE" = all ] || watch_start "$APP-macos.log" "$P" "$COMPANIONS_PID"
  app_dismiss "$P" || odd "a sheet or dialog stayed in the way"
  [ "$(echo "$APP_WINDOWS" | wc -w)" -eq 1 ] || odd "it opened $(echo "$APP_WINDOWS" | wc -w | tr -d ' ') standard windows"
  LIMITS=$(apptool limits "$S")
  echo "limits: $LIMITS"
  printf '%s\t%s\t%s\n' "$APP" "$(apptool describe "$S" | cut -d ' ' -f 2-)" "$LIMITS" >> "$ARBOR_OUT/limits.tsv"
  read -r MIN_W MIN_H <<< "$(echo "$LIMITS" | awk '{ split($2, a, "x"); printf "%d %d", a[1], a[2] }')"
  [ "$(echo "$LIMITS" | awk '{ print $2 }')" = "$(echo "$LIMITS" | awk '{ print $4 }')" ] && FIXED=yes
  [ "$(echo "$LIMITS" | awk '{ sub(/x.*/, "", $2); print $2 }')" = "$(echo "$LIMITS" | awk '{ sub(/x.*/, "", $4); print $4 }')" ] && FIXED_W=yes
  echo "other things on screen above the ordinary level (id pid level x y w h on owner):"
  pointer windows | awk '$8 == "on" && $3 > 0 && $3 < 20 && $6 > 60' | sed 's/^/  /'
  finish no-audit
  if [ "${COMPAT_STEPS:-all}" = open ]; then
    echo "the top of its Accessibility tree:"
    apptool tree "$P" 2 | head -n 30 | sed 's/^/  /'
    drill_end
    return 0
  fi

  before=$(real_frame_of "$S")
  [ "$SCOPE" = all ] || session="$P $COMPANIONS_PID"
  # shellcheck disable=SC2086
  if ! arbor_start_apps $session $FACE; then
    begin adopt
    want "Arbor started" false
    finish no-audit
    drill_end
    return 0
  fi

  begin adopt
  want "Arbor arranges the window" eventually is managed "$S"
  want "it floats" is floating "$S"
  want "starting Arbor did not move it" test "$(real_frame_of "$S")" = "$before"
  finish

  begin dock-left
  run dock "$S" left
  want "it is docked" eventually is docked "$S"
  is tile "$S" && odd "half the view is too small for it (minimum ${MIN_W}×${MIN_H}): a tile"
  finish

  begin dock-right
  run dock "$C1" right
  want "the neighbour is docked" eventually is docked "$C1"
  is tile "$S" && odd "a third of the view is too small for it (minimum ${MIN_W}×${MIN_H}): a tile"
  finish

  begin dock-below
  run dock "$C2" beside "$C1" bottom
  want "the second neighbour is docked" eventually is docked "$C2"
  make_room || odd "still a tile after widening its slot"
  want "the window is in view" in_view "$S"
  finish

  begin dock-under
  run dock "$C2" beside "$S" bottom
  want "the neighbour is docked" eventually is docked "$C2"
  is tile "$S" && odd "half the height is too small for it (minimum ${MIN_W}×${MIN_H}): a tile"
  finish
  ctl dock "$C2" beside "$C1" bottom
  sleep 0.5
  make_room

  begin zoom
  run zoom "$S"
  want "the window is in view" eventually in_view "$S"
  want "the neighbours are parked" is parked "$C1"
  finish

  begin back
  run back
  want "the window is in view" eventually in_view "$S"
  want "the neighbours are back" in_view "$C1"
  finish

  begin desktop
  run desktop
  want "the window is parked" eventually is parked "$S"
  finish

  begin desktop-back
  run back
  want "the window is in view" eventually in_view "$S"
  finish

  begin float
  run float "$S"
  want "it floats" eventually is floating "$S"
  want "it is on screen" is on_screen "$S"
  finish

  begin drag-to-edge
  read -r x y w h <<< "$(arbor_ask screen)"
  if grab_and_drag "$((x + 3))" "$((y + h / 2))"; then
    want "a drop preview shows while the button is held" has_overlay 3
    held_picture
    release
    want "it is docked after the release" eventually is docked "$S"
  else
    want "its title bar can be grabbed" false
  fi
  finish
  is docked "$S" || ctl dock "$S" left

  begin drag-onto-window
  ctl float "$S"
  sleep 0.6
  read -r x y w h <<< "$(frame_of "$C1")"
  if grab_and_drag "$((x + w * 5 / 6))" "$((y + h / 2))"; then
    want "a drop preview shows while the button is held" has_overlay 3
    held_picture
    release
    want "it is docked after the release" eventually is docked "$S"
    read -r after _ <<< "$(arbor_ask slot "$S" 2>/dev/null || arbor_ask tile "$S" 2>/dev/null)"
    want "it landed to the right of the neighbour" test "${after:-0}" -gt "$x"
    is tile "$S" && odd "half the neighbour's slot is too small for it: a tile"
  else
    want "its title bar can be grabbed" false
  fi
  finish
  go_home

  if in_view "$S"; then
    begin seam-drag
    read -r x y w h <<< "$(slot_of "$S")"
    mark "seam drag"
    drag "$((x + w + ARBOR_GAP / 2))" "$((y + h / 2))" "$((x + w + ARBOR_GAP / 2 + 60))" "$((y + h / 2))"
    sleep 0.4
    read -r _ _ after _ <<< "$(slot_of "$S")"
    echo "the slot was $w wide and is now ${after:-gone}"
    want "the slot grew by about 60 points" between "$((${after:-0} - w))" 45 75
    finish
  else
    skip seam-drag "the window is a tile"
  fi

  if [ -n "$FIXED" ]; then
    skip edge-resize "the window has one size"
  elif [ -n "$FIXED_W" ]; then
    skip edge-resize "the window has one width"
  elif in_view "$S"; then
    begin edge-resize
    read -r _ _ before _ <<< "$(slot_of "$S")"
    read -r x y w h <<< "$(real_of "$S")"
    mark "edge drag"
    drag "$((x + w - 1))" "$((y + h / 2))" "$((x + w - 51))" "$((y + h / 2))" --no-release
    held_picture
    release
    sleep 0.6
    read -r _ _ after _ <<< "$(slot_of "$S")"
    echo "the slot was $before wide and is now ${after:-gone}"
    want "the slot shrank by about 50 points" between "$((before - ${after:-0}))" 35 65
    finish
  else
    skip edge-resize "the window is a tile"
  fi

  bring_into_view
  home=$(slot_of "$S" 2>/dev/null)
  begin minimize
  if point=$(apptool button "$S" minimize 2>/dev/null); then
    # shellcheck disable=SC2086
    click $point
  else
    odd "no yellow button; ⌘M instead"
    app_focus "$S"
    key cmd+m
  fi
  want "Arbor sees it minimized" eventually is minimized "$S"
  want "its slot went to the others" eventually not in_view "$S"
  sleep 0.6
  finish

  begin restore
  mark "unminimize"
  apptool unminimize "$S"
  want "Arbor sees it restored" eventually not is minimized "$S"
  sleep 0.6
  want "it is in view" eventually in_view "$S"
  want "it is back in the slot it had" eventually has_slot "$S" "$home"
  finish
  # Whatever that did to the camera, the next step starts from the whole layout.
  ctl show-all
  sleep 0.5

  bring_into_view
  home=$(slot_of "$S" 2>/dev/null)
  begin hide
  want "a click on its title bar brings its app to the front" app_focus "$S"
  key cmd+h
  want "Arbor sees it hidden" eventually is hidden "$S"
  want "its slot went to the others" eventually not in_view "$S"
  finish

  begin unhide
  mark "unhide"
  # safe anywhere: on a person's Mac an app that was running already was left out at the start, so this one is the script's own
  apptool unhide "$P" || open -g -b "$BUNDLE"
  want "Arbor sees it shown" eventually not is hidden "$S"
  want "it is in view" eventually in_view "$S"
  want "it is back in the slot it had" eventually has_slot "$S" "$home"
  finish
  ctl show-all
  sleep 0.5

  # What a click on its Dock icon or ⌘Tab does. An app with one window reports no change of focused window.
  begin activate-parked
  run zoom "$C1"
  want "the window is parked" eventually is parked "$S"
  mark "activate the app"
  # safe anywhere: on a person's Mac an app that was running already was left out at the start, so this one is the script's own
  open -b "$BUNDLE"
  want "the camera brings the window into view" eventually in_view "$S"
  finish
  ctl show-all
  sleep 0.5

  bring_into_view
  begin close
  if point=$(apptool button "$S" close 2>/dev/null); then
    # shellcheck disable=SC2086
    click $point
    want "Arbor forgot the window" eventually gone "$S"
    want "the neighbours are in view" eventually in_view "$C1"
    sleep 0.5
    kill -0 "$P" 2>/dev/null || echo "the app quit with its last window"
  else
    want "it has a red button" false
  fi
  finish

  old_s=$S
  begin reopen
  subject_open
  want "a standard window opened" test -n "$S"
  [ "$S" = "$old_s" ] && echo "the same window number as before"
  if [ -z "$S" ] || ! reachable "$P"; then
    [ -n "$S" ] && echo "a new process, out of Arbor's reach here"
    finish
    for point in new-window new-window-back quit-app relaunch; do skip "$point" "the app did not come back within Arbor's reach"; done
    quit_arbor
    drill_end
    return 0
  fi
  want "Arbor arranges it" eventually is managed "$S"
  want "it is on screen" is on_screen "$S"
  finish
  ctl dock "$S" left
  sleep 0.6
  make_room

  if [ -n "$MORE" ]; then
    begin new-window
    run zoom "$S"
    sleep 0.5
    known=$(app_windows "$P")
    case "$MORE" in
      key*) app_focus "$S"; key "${MORE#key }" ;;
      # safe anywhere: on a person's Mac an app that was running already was left out at the start, so this one is the script's own
      open*) mark "open another document"; open -b "$BUNDLE" "${MORE#open }" ;;
    esac
    if app_await_window "$P" "$known"; then
      want "Arbor arranges the new window" eventually is managed "$NEW_WINDOW"
      want "the new window is on screen" eventually is on_screen "$NEW_WINDOW"
      is floating "$NEW_WINDOW" && echo "it floats"
    else
      want "a new window opened" false
    fi
    finish

    begin new-window-back
    run back
    finish
    if [ -n "$NEW_WINDOW" ]; then
      apptool close "$NEW_WINDOW"
      eventually gone "$NEW_WINDOW" || echo "note: Arbor still lists the closed window $NEW_WINDOW"
    fi
  else
    skip new-window "the app has one window"
    skip new-window-back "the app has one window"
  fi

  begin quit-app
  run zoom "$S"
  sleep 0.5
  mark "quit the app"
  if [ "$QUIT" = kill ]; then kill -TERM "$P"; apps_forget "$P"; else app_quit "$P"; fi
  want "Arbor forgot the window" eventually gone "$S"
  want "the camera went somewhere with windows" eventually in_view "$C1"
  finish

  if [ "$SCOPE" = all ]; then
    begin relaunch
    subject_open
    want "a standard window opened" test -n "$S"
    if [ -n "$S" ]; then
      want "Arbor arranges it" eventually is managed "$S"
      want "it is on screen" is on_screen "$S"
      want "it went back to its slot" is docked "$S"
    fi
    finish
  else
    skip relaunch "a new process, out of Arbor's reach here"
    S=""
  fi

  quit_arbor
  drill_end
}

# The last step of every drill: with the subject out of view, quit Arbor. Everything has to come back.
quit_arbor() {
  local id
  begin quit-arbor
  if [ -n "$S" ] && reachable "$P" && ! gone "$S"; then
    is docked "$S" || ctl dock "$S" left
    sleep 0.5
    run zoom "$C1"
    want "the window is parked" eventually is parked "$S"
  else
    S=""
    run zoom "$C1"
  fi
  sleep 0.5
  ctl quit
  want "Arbor exits within 5 s" arbor_await_exit "$ARBOR_PID" 50
  for id in $S $C1 $C2; do
    want "window $id is back on screen" eventually is on_screen "$id"
  done
  finish no-audit
}

drill_end() {
  local pid id
  cp "$ARBOR_HOME/arbor.log" "$APPS_TEMP/arbor.log" 2>/dev/null
  arbor_stop
  ARBOR_DEAD=""
  if [ "$QUIT" = kill ]; then
    # Finder stays; its windows go.
    for pid in $APPS_PIDS; do
      for id in $(app_windows "$pid"); do apptool close "$id"; done
      apps_forget "$pid"
    done
  fi
  for pid in $APPS_PIDS; do app_quit "$pid"; done
  watch_stop
  if on_throwaway_mac; then cp "$HOME"/Library/Logs/DiagnosticReports/Arbor*.ips "$ARBOR_OUT/" 2>/dev/null; fi
  # One story: what the script did, what macOS reported, what Arbor logged.
  cat "$APPS_TEMP/arbor.log" "$ARBOR_OUT/$APP-macos.log" 2>/dev/null | sort -s -k 1,1 > "$ARBOR_OUT/$APP-story.log"
  rm -f "$APPS_TEMP/arbor.log" "$ARBOR_OUT/$APP-macos.log" "$ARBOR_OUT"/arbor-[0-9]*.log "$ARBOR_OUT/arbor.log"
  WATCH_FILE=""
}

prepare() {
  apps_watchdog "${COMPAT_LIMIT:-1620}"
  step "the Mac"
  echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m)"
  apps_build
  echo "display modes (w h pixel-w pixel-h): $(apptool modes | tr '\n' ';')"
  # The size of a small MacBook's screen, or the nearest on offer.
  # shellcheck disable=SC2086
  display_mode ${COMPAT_DISPLAY:-1440x900 1600x900 1680x1050 1920x1080}
  apps_scratch
  # macOS's own edge tiling would compete for the drags to the edge. A person's setting, so only on a throwaway Mac.
  if on_throwaway_mac; then macos_tiling off > /dev/null; fi
  companions_start 2
  if on_throwaway_mac || [ -n "${ARBOR_APPS_ALL:-}" ]; then SCOPE=all; else SCOPE=pids; fi
  # Shortcuts, event taps and the menu bar item: on where nobody else's Arbor can be running.
  FACE=""
  if on_throwaway_mac; then FACE="ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0"; fi
  echo "apps before the drills (pid policy state bundle id):"
  apptool apps | sed 's/^/  /'
}

# compat-extras.sh sources this file for the functions above.
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0

# shellcheck disable=SC2086
set -- "$@" ${COMPAT_APPS:-}
# shellcheck disable=SC2086
[ $# -gt 0 ] || set -- $ALL_APPS

# Given to several Macs at once (run.sh --macs 2), each takes every second app: "2/2" is the second Mac of two.
share=${MAC_SHELL_SHARE:-1/1}
if [ "${share#*/}" -gt 1 ] 2>/dev/null; then
  mine="" place=0
  for app in "$@"; do
    [ $((place % ${share#*/} + 1)) -ne "${share%/*}" ] || mine="$mine $app"
    place=$((place + 1))
  done
  echo "Mac ${share%/*} of ${share#*/}:$mine"
  # shellcheck disable=SC2086
  set -- $mine
fi

prepare
for app in "$@"; do
  if [ "$SECONDS" -gt "$COMPAT_BUDGET" ]; then
    APP=$app
    skip open "out of time after $SECONDS s"
    continue
  fi
  started=$SECONDS
  drill "$app"
  echo
  echo "$app: $((SECONDS - started)) s"
done

step "the matrix"
matrix | tee "$ARBOR_OUT/matrix.md"
