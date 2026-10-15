#!/bin/bash
# A real browser and a real editor, hung over the edge of the screen by a real drag, docked, and given back: whole, where they hung?
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-own-size-apps.sh
#
# check-own-size.sh asks the same of test windows, to the point. This asks what only real apps can say: do Safari and TextEdit, which have toolbars,
# limits and manners of their own, come back from a slot with no room for their size as their person left them? Without Arbor a Mac costs
# that person nothing. With it, a browser 1188 wide came back 969 wide at every Quit: cut at the edge of the screen, which lets no window
# grow across it where it stands (Sources/ArborKit/Controller/Controller+TheScreensAnswer.swift).
#
# For each app: over the right edge, then over the bottom; given back by Float All, a pause and Quit. What Arbor asked of the window is printed
# from arbor.log.
#
# Only on GitHub's Macs: it opens real apps, drags their windows about and switches the display's size.
source "$(dirname "${BASH_SOURCE[0]}")/lib-apps.sh"
needs_throwaway_mac "open Safari and TextEdit, drag their windows over the edges of the screen, and switch the display's size"

is_at() { [ "$(real_of "$1" | sed 's/ $//')" = "$2" ] || { echo "    it is at $(real_of "$1"), not at $2"; return 1; }; }
asked_of() { arbor_log_since "$ARBOR_STEP_MARK" | grep -E "w$1\b" | tail -n 8 | cut -c 26-200 | sed 's/^/    (/; s/$/)/' || true; }

# hung <id> <dx> <dy>: taken by its title bar, where no control is, and carried that far. Sets HUNG to where it then is.
hung() {
  local id=$1 gx gy role
  read -r gx gy role <<< "$(apptool grab "$id")"
  [ -n "$gy" ] || { check "its title bar can be taken hold of" false; return 1; }
  drag "${gx%.*}" "${gy%.*}" "$((${gx%.*} + $2))" "$((${gy%.*} + $3))" --steps 24 --duration 0.8
  sleep 1.5
  HUNG=$(real_of "$id" | sed 's/ $//')
  echo "    it hangs at $HUNG"
}

# story <id> <name> <edge>
story() {
  local id=$1 name=$2 edge=$3 way x y w h
  for way in float-all pause quit; do
    claim "$name, hung over the $edge by a real drag, docked where there is no room for its size, given back by $way"
    case "$edge" in
      "right edge")
        apptool set-frame "$id" "$((sx + sw - wide - 60))" "$((sy + 60))" "$wide" 500 > /dev/null
        sleep 1
        hung "$id" 360 0 || continue
        read -r x y w h <<< "$HUNG"
        check "the case: it hangs over the right edge" test "$((x + w))" -gt "$((fx + fw))"
        ctl dock "$C1" left
        ctl dock "$id" right ;;
      bottom)
        apptool set-frame "$id" "$((sx + sw / 2))" "$((sy + 20))" 640 "$tall" > /dev/null
        sleep 1
        hung "$id" 0 300 || continue
        read -r x y w h <<< "$HUNG"
        check "the case: it hangs over the bottom" test "$((y + h))" -gt "$((sy + sh))"
        ctl dock "$C1" left
        ctl dock "$id" beside "$C1" bottom ;;
    esac
    check "it is docked, in view" eventually in_view "$id"
    brief
    if [ "$way" = quit ]; then arbor_quit; else ctl "$way"; fi
    check "it is where it hung, whole" eventually is_at "$id" "$HUNG"
    sleep 1.5
    check "and stays there" is_at "$id" "$HUNG"
    [ "$way" = quit ] || asked_of "$id"
    snap "$name-${edge// /-}-$way"
    case "$way" in
      pause) ctl resume; sleep 1; ctl float-all > /dev/null ;;
      quit) arbor_start_apps "$SAFARI_PID" "$EDIT_PID" "$COMPANIONS_PID" || die "Arbor did not start again"; ctl float-all > /dev/null ;;
    esac
    sleep 1
  done
}

apps_build
apps_scratch
apps_watchdog 1000
display_mode 1440x900 1600x900 1680x1050 1920x1080

step "Safari, TextEdit and a test window"
app_open com.apple.Safari "$APPS_SCRATCH/page.html" || die "no Safari"
app_dismiss "$APP_PID" || echo "a sheet or dialog stayed in the way"
SAFARI_PID=$APP_PID SAFARI=$APP_WINDOW
app_open com.apple.TextEdit "$APPS_SCRATCH/oak.txt" || die "no TextEdit"
EDIT_PID=$APP_PID EDIT=$APP_WINDOW
companions_start 1
arbor_start_apps "$SAFARI_PID" "$EDIT_PID" "$COMPANIONS_PID" || die "Arbor did not start"
# Apps have just joined the Dock, which changes the visible frame for a second or so.
sleep 3
take "sx sy sw sh" screen_of 1
take "fx fy fw fh" display_frame_of 1
echo "the visible frame is $sx $sy $sw $sh, the display $fx $fy $fw $fh"
wide=$((sw * 2 / 3)) tall=$((sh - 120))

story "$SAFARI" Safari "right edge"
story "$EDIT" TextEdit "right edge"
story "$SAFARI" Safari bottom
story "$EDIT" TextEdit bottom

arbor_stop
companions_stop
app_quit "$EDIT_PID"
app_quit "$SAFARI_PID"
