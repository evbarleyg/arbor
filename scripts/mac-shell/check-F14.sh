#!/bin/bash
# F14 on real windows, with real double-clicks (docs/features/F14-double-click-actions.md). This run decides whether the two
# switches ship on: unattended, on a hosted Mac, in under ten minutes.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/check-F14.sh
#
# Twice, with macOS's own tiling and its wallpaper click as macOS comes and with both switched off: a docked window's
# title bar frames it, in one move, and macOS's own action does not run as well; the framed window's title bar goes back; a
# floating window's title bar, the gaps, a window's content and a double-click with ⌘ held are left alone, and the apps get both
# clicks, also of an app that hangs; two slow clicks are two clicks; a second press that turns into a drag is given back; a third click is the app's; `pause`
# takes the taps away and `resume` brings them back; taps that go away give back a press they hold. In sessions of its own, so that what macOS does
# at a click on the wallpaper counts against nothing else: the Desktop and back.
# Then once each: a tile opens on one click and the second click of a double-click reaches nobody. As Arbor ships: no
# tap of F14's, and how late clicks arrive without one, to compare. macOS set to Minimize and to Do Nothing: Arbor leaves title
# bars alone and says why. Safari: its address field and buttons keep their double-clicks, its empty toolbar is Arbor's.
# Last, while there is time, not checks but a survey: what stock apps have in the top of their windows.
#
# What it brings back to be judged: a trace of every double-click (traces/), the frames each window went through
# (frames-*.txt), what a witness at the far end of the taps saw of every press and how late (witness.txt), arbor.log and pictures.
# It ends with a verdict for each switch: `titleBarDoubleClick` and `desktopDoubleClick` are decided one by one.
#
# What only a Mac can answer: whether a press that is held back and swallowed keeps macOS's own action from running; whether one
# that is given back arrives whole; how long the look at what is under the pointer holds a click that is not Arbor's;
# whether a running Arbor sees the setting change in System Settings.
#
# On a person's Mac only the sessions on test windows run, once, with that Mac's settings as they are and without the
# Desktop's double-click. The rest changes settings of the system's, arranges, opens and quits real apps and clicks on the
# wallpaper, so it runs on GitHub's throwaway Macs alone.
source "$(dirname "$0")/lib-double-click.sh"
# The switch above every event tap, and the other gestures beside these, whatever Arbor ships with.
source "$(dirname "$0")/lib-gestures.sh"

# nothing_at <x> <y>: no ordinary window of anybody's is under the point, as the window server sees it
nothing_at() {
  pointer windows | awk -v x="$1" -v y="$2" \
    '$8 == "on" && $3 == 0 && x >= $4 && x < $4 + $6 && y >= $5 && y < $5 + $7 { found = 1 } END { exit found }'
}
tap_log() {
  echo "what the tap saw (arbor.log):"
  grep -i -E "double-click|second click|event tap" "$ARBOR_HOME/arbor.log" | tail -n "${1:-30}" | cut -c 1-260 | sed 's/^/    /'
}
# Every session has a log of its own.
no_install_logged() { ! grep -q "double-click event taps installed" "$ARBOR_HOME/arbor.log"; }
installs_logged() { [ "$(grep -c "double-click event taps installed" "$ARBOR_HOME/arbor.log")" -eq "$1" ]; }
once() { [ "$1" = "?" ] || [ "$1" -eq 1 ]; }
# `doctor` ends with 1 when it has found a problem of any kind, which is not what is asked here.
doctor_says() {
  local text
  text=$("$ARBOR_BIN/arborctl" doctor 2>&1)
  echo "$text" | grep -q "$1"
}
# within_10_ms <µs> <µs>: the first is less than 10 ms more than the second
within_10_ms() { [ $(($1 - $2)) -lt 10000 ]; }
# The one click that has to wait for an answer: the second of a pair in the top of a docked window, which turns out to be the app's.
within_50_ms() { [ $(($1 - $2)) -lt 50000 ]; }
within_100_ms() { [ $(($1 - $2)) -lt 100000 ]; }

# Every check counts for one of the two switches.
ABOUT=title
COUNTED=0
TITLE_FAILED=0
DESKTOP_FAILED=0
about() {
  local new=$((ARBOR_FAILED - COUNTED))
  COUNTED=$ARBOR_FAILED
  if [ "$ABOUT" = desktop ]; then DESKTOP_FAILED=$((DESKTOP_FAILED + new)); else TITLE_FAILED=$((TITLE_FAILED + new)); fi
  ABOUT=$1
}
# The rectangle's tap on mouse-downs has the same mask, and is on as Arbor comes.
two_taps_on_mouse_downs() { [ "$(arbor_taps | grep -c "mask=0x2 enabled=true")" -eq 2 ]; }
laid_out_and_installed() {
  "$ARBOR_BIN/arborctl" relayout > /dev/null
  installs_logged "$1"
}

# clicks_that_are_not_arbors <window>: two dozen clicks and a dozen double-clicks in its content. Sets LATE_DOWN and LATE_UP.
clicks_that_are_not_arbors() {
  local spot _
  spot=$(center_of "$1")
  mark "clicks that are not Arbor's"
  # shellcheck disable=SC2086
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
    pointer click $spot
    sleep 0.6
    pointer click $spot
    sleep 0.6
    pointer click $spot 2
    sleep 0.6
  done
  LATE_DOWN=$(late down)
  LATE_UP=$(late up)
  echo "mouse-downs, median and second largest delay in µs: $LATE_DOWN"
  echo "mouse-ups: $LATE_UP"
  check "every one of them arrived: 48 mouse-downs" reached '^down ' 48
  check "and 48 mouse-ups" reached '^up ' 48
}

# title_bars <label>: the session that is played at both settings of macOS's own window management.
title_bars() {
  local label=$1 slot beside floating bar inner zoomed sx sy sw sh dx dy dw dh zx zy zw before asked after laid
  about title
  step "$label: title bars"
  arbor_settings "{\"titleBarDoubleClick\": true, $ARBOR_GESTURES_ON}"
  arbor_start 3 ARBOR_NO_HOTKEYS=0
  read -r sx sy sw sh <<< "$(arbor_ask screen)"
  inner="$((sx + ARBOR_GAP)) $((sy + ARBOR_GAP)) $((sw - 2 * ARBOR_GAP)) $((sh - 2 * ARBOR_GAP))"
  ctl dock "$W1" left
  ctl dock "$W2" right
  sleep 0.7
  summary
  shot "$label-01-docked"
  slot=$(real_frame_of "$W1")
  beside=$(real_frame_of "$W2")
  floating=$(real_frame_of "$W3")
  bar=$(titlebar_of "$W1")
  if [ -n "$WITNESS_PID" ]; then
    arbor_taps
    check "the tap on mouse-downs is on, beside the rectangle's" two_taps_on_mouse_downs
    check "the tap on the rest of a hidden click is installed with it, paused" tap_is 0x46 false
  fi

  step "$label: double-click a docked window's title bar"
  mark "a title bar"
  laid=$(layouts)
  trace_on "$label-docked" "a double-click on a docked window's title bar, which Arbor takes"
  # shellcheck disable=SC2086
  frames_during "$W1" "$ARBOR_OUT/frames-$label-1.txt" dblclick $bar
  trace_off "$label-docked"
  check "the view frames the window" eventually camera_on "$W1"
  if [ -n "$WITNESS_PID" ]; then
    check "the app got the first mouse-down and not the second" reached '^down ' 1
    check "and the first mouse-up and not the second" reached '^up ' 1
    check "what it got was the first click" reached '^down .*clicks=1 ' 1
    check "the tap on the rest of the click is paused again" tap_is 0x46 false
  fi
  check "it fills the view" eventually real_frame_is "$W1" "$inner"
  check "the other docked window is out of view" eventually is parked "$W2"
  # shellcheck disable=SC2086
  check "macOS did not zoom it as well" never_outside "$ARBOR_OUT/frames-$label-1.txt" $inner
  check "it went there by one road" one_road "$ARBOR_OUT/frames-$label-1.txt"
  check "Arbor laid out once: nothing had to be put back afterwards" same "$(($(layouts) - laid))" 1
  check "Arbor set its frame once" once "$(moves_of "$W1")"
  check "it has the keyboard" eventually is focused "$W1"
  shot "$label-02-framed"
  summary

  step "$label: double-click the framed window's title bar"
  laid=$(layouts)
  trace_on "$label-framed" "a double-click on the framed window's title bar"
  # shellcheck disable=SC2046
  frames_during "$W1" "$ARBOR_OUT/frames-$label-2.txt" dblclick $(titlebar_of "$W1")
  trace_off "$label-framed"
  check "the view is back on everything" eventually camera_on root
  check "the window is back in its slot" eventually real_frame_is "$W1" "$slot"
  check "the other docked window is back where it was" eventually real_frame_is "$W2" "$beside"
  check "and the floating one" eventually real_frame_is "$W3" "$floating"
  # shellcheck disable=SC2086
  check "macOS did not zoom it this time either" never_outside "$ARBOR_OUT/frames-$label-2.txt" $inner
  check "it went back by one road" one_road "$ARBOR_OUT/frames-$label-2.txt"
  check "Arbor laid out once" same "$(($(layouts) - laid))" 1
  check "Arbor set its frame once" once "$(moves_of "$W1")"
  shot "$label-03-back"

  step "$label: a floating window's title bar is macOS's"
  mark "a floating window's title bar"
  trace_on "$label-floating" "a double-click on a floating window's title bar, which is macOS's"
  # shellcheck disable=SC2046
  frames_during "$W3" "$ARBOR_OUT/frames-$label-3.txt" must dblclick $(titlebar_of "$W3")
  trace_off "$label-floating"
  check "the view stayed" camera_on root
  [ -n "$WITNESS_PID" ] && check "the app got both clicks" reached '^down ' 2
  check "Arbor set no frame" arbor_moved_nothing
  check "the docked windows stayed" real_frame_is "$W1" "$slot"
  check "both of them" real_frame_is "$W2" "$beside"
  check "whatever macOS did with it, it did once" one_road "$ARBOR_OUT/frames-$label-3.txt"
  zoomed=$(real_frame_of "$W3")
  echo "the floating window was at $floating and is at $zoomed (macOS's own action is welcome here)"
  shot "$label-04-floating"
  # It covers everything now. macOS's second double-click sends it back.
  read -r zx zy zw _ <<< "$zoomed"
  must dblclick "$((${zx%.*} + ${zw%.*} / 2))" "$((${zy%.*} + 12))"
  if ! eventually real_frame_is "$W3" "$floating"; then
    echo "note: macOS did not send it back: $(real_frame_of "$W3"). Its app does, or it would cover all that follows"
    # Descriptor 9 is the test windows' stdin.
    echo "move $W3 $floating" >&9
    sleep 0.7
  fi
  check "the view stayed" camera_on root

  step "$label: the gaps are nobody's"
  before=$(summary | sed 's/ focused//')
  mark "the gap between a docked window and the Desktop"
  # shellcheck disable=SC2046
  must dblclick $(seam_right_of "$W1")
  sleep 0.6
  check "between a docked window and the Desktop: the view stayed" camera_on root
  check "and nothing moved" same "$(summary | sed 's/ focused//')" "$before"
  if on_throwaway_mac; then
    # Wallpaper shows there, and what a click on that does is macOS's: two of them end where they began.
    mark "the gap at the edge of the screen"
    must dblclick "$((sx + ARBOR_GAP / 2))" "$((sy + sh / 2))"
    sleep 1.5
    check "at the edge of the screen: the view stayed" camera_on root
    [ -n "$WITNESS_PID" ] && check "whoever is there got both clicks" reached '^down ' 2
    check "and every window is where it was" eventually real_frame_is "$W1" "$slot"
  fi

  step "$label: double-clicks that are the apps'"
  # Which window is focused may change: the clicks are the app's.
  before=$(summary | sed 's/ focused//')
  mark "a window's content"
  # shellcheck disable=SC2046
  must dblclick $(center_of "$W1")
  sleep 0.6
  check "inside a docked window's content: nothing moved" same "$(summary | sed 's/ focused//')" "$before"
  [ -n "$WITNESS_PID" ] && check "the app got both clicks" reached '^down ' 2
  trace_on "$label-command-held" "a double-click with ⌘ held on a docked window's title bar, which is macOS's"
  # shellcheck disable=SC2046
  frames_during "$W2" "$ARBOR_OUT/frames-$label-4.txt" must dblclick $(titlebar_of "$W2") --mods cmd
  trace_off "$label-command-held"
  check "with ⌘ held on a title bar: the view stayed" camera_on root
  check "Arbor set no frame: whatever macOS made of it stays" arbor_moved_nothing
  check "and it did it once" one_road "$ARBOR_OUT/frames-$label-4.txt"
  # The next layout takes the window back.
  ctl show-all
  check "showing everything takes the window back" eventually real_frame_is "$W2" "$beside"

  step "$label: two slow clicks on a title bar are two clicks"
  mark "two slow clicks"
  # shellcheck disable=SC2046
  must click $(titlebar_of "$W1")
  sleep 1.2
  # shellcheck disable=SC2046
  must click $(titlebar_of "$W1")
  sleep 0.6
  check "the view stayed" camera_on root
  check "the window stayed" real_frame_is "$W1" "$slot"
  [ -n "$WITNESS_PID" ] && check "the app got both, each as a first click" reached '^down .*clicks=1 ' 2

  step "$label: click a docked window's title bar and at once drag it away: a drag, not a double-click"
  # Also how a trackpad set up to drag with a double tap drags anything.
  read -r dx dy dw dh <<< "$(arbor_ask desktop)"
  mark "a second press that drags"
  # shellcheck disable=SC2046
  must click $(titlebar_of "$W2")
  # shellcheck disable=SC2046
  must drag $(titlebar_of "$W2") "$((dx + dw / 2))" "$((dy + 40))" --clicks 2
  check "the view stayed" camera_on root
  check "the window went with the pointer: it floats now" eventually is floating "$W2"
  if [ -n "$WITNESS_PID" ]; then
    check "the app got the second mouse-down after all, from Arbor" reached '^down .*clicks=2 mark=arbor' 1
    check "once" reached '^down ' 2
    check "and both mouse-ups" reached '^up ' 2
    check "the tap on what follows a press is paused again" tap_is 0x46 false
  fi
  shot "$label-05-dragged-out"
  ctl dock "$W2" right
  sleep 0.7
  summary

  step "$label: a triple click: the third is the app's, and macOS makes nothing of it"
  laid=$(layouts)
  # shellcheck disable=SC2046
  frames_during "$W1" "$ARBOR_OUT/frames-$label-5.txt" click $(titlebar_of "$W1") 3
  check "the view frames the window" eventually camera_on "$W1"
  # shellcheck disable=SC2086
  check "macOS did not zoom it" never_outside "$ARBOR_OUT/frames-$label-5.txt" $inner
  check "one road" one_road "$ARBOR_OUT/frames-$label-5.txt"
  check "Arbor laid out once" same "$(($(layouts) - laid))" 1
  ctl show-all
  sleep 0.7

  step "$label: an app that hangs keeps its click, and holds nobody up"
  bar=$(titlebar_of "$W1")
  # Descriptor 9 is the test windows' stdin.
  echo "hang 4" >&9
  sleep 0.5
  mark "a title bar of an app that hangs"
  # shellcheck disable=SC2086
  must dblclick $bar
  # shellcheck disable=SC2046
  pointer click $(center_of "$W2")
  if [ -n "$WITNESS_PID" ]; then
    check "all three clicks got past the taps" reached '^down ' 3
    read -r _ asked _ <<< "$(late down clicks=2)"
    echo "the second mouse-down waited $asked µs for an app that does not answer"
    check "which is under 100 ms" within_100_ms "$asked" 0
    after=$(since_the_mark | grep '^down .*clicks=1 ' | tail -n 1 | sed 's/.*delay_us=\([0-9-]*\).*/\1/')
    echo "the click after it took ${after:-?} µs"
    check "and the click after it was not held up" within_10_ms "${after:-99999}" 0
  fi
  check "the view stayed: when in doubt the click is not Arbor's" camera_on root
  # Awake again, the app finds the double-click, and what macOS makes of it stays.
  sleep 5
  check "the view stayed" camera_on root
  ctl show-all
  check "showing everything puts the window into its slot" eventually real_frame_is "$W1" "$slot"

  step "$label: pause takes the taps away, resume brings them back"
  ctl pause
  check "the log says that the taps are gone" eventually grep -q "double-click event taps removed" "$ARBOR_HOME/arbor.log"
  [ -n "$WITNESS_PID" ] && check "the window server lists no tap of Arbor's" eventually no_taps
  sleep 0.7
  # Wherever the pause has left the window.
  read -r zx zy zw _ <<< "$(real_frame_of "$W1")"
  click "$((${zx%.*} + ${zw%.*} / 2))" "$((${zy%.*} + 12))"
  sleep 0.8
  mark "a title bar during a pause"
  must dblclick "$((${zx%.*} + ${zw%.*} / 2))" "$((${zy%.*} + 12))"
  sleep 1
  [ -n "$WITNESS_PID" ] && check "the app got both clicks" reached '^down ' 2
  echo "the window is at $(real_frame_of "$W1") (macOS's own action is welcome here)"
  ctl resume
  check "the log says that they are back" installs_logged 2
  ctl show-all
  sleep 0.7

  step "$label: the taps go away while they hold a press back: the app gets it after all"
  bar=$(titlebar_of "$W1")
  mark "a press held back when the switch goes off"
  # shellcheck disable=SC2086
  must click $bar
  # The second press, and the button stays down.
  # shellcheck disable=SC2086
  must drag $bar $bar --clicks 2 --no-release
  [ -n "$WITNESS_PID" ] && check "the second press is held back" reached '^down ' 1
  ctl set titleBarDoubleClick false
  sleep 0.3
  [ -n "$WITNESS_PID" ] && check "given back when the taps go, marked as Arbor's" reached '^down .*clicks=2 mark=arbor' 1
  release
  sleep 1
  if [ -n "$WITNESS_PID" ]; then
    check "the app has two mouse-downs" reached '^down ' 2
    check "and two mouse-ups" reached '^up ' 2
  fi
  check "the view stayed: nothing of Arbor's ran as well" camera_on root
  echo "the window is at $(real_frame_of "$W1") (macOS's own action is welcome here, and stays)"
  ctl set titleBarDoubleClick true
  check "the taps are back" eventually installs_logged 3
  [ -n "$WITNESS_PID" ] && check "paused again, the one on the rest of a click" eventually tap_is 0x46 false
  ctl show-all
  sleep 0.7
  summary
  # shellcheck disable=SC2046
  dblclick $(titlebar_of "$W1")
  check "a double-click frames the window as before" eventually camera_on "$W1"
  ctl show-all
  sleep 0.7

  if [ -n "$WITNESS_PID" ] && [ -z "$ON_DOWN" ]; then
    step "$label: how late clicks that are not Arbor's arrive, past the tap"
    clicks_that_are_not_arbors "$W2"
    ON_DOWN=$LATE_DOWN
    ON_UP=$LATE_UP
  fi
  tap_log 40
  arbor_stop
}

# the_desktop <label>: a session of its own.
the_desktop() {
  local label=$1 slot floating dx dy dw dh bare_x bare_y
  about desktop
  step "$label: double-click the Desktop"
  arbor_settings "{\"desktopDoubleClick\": true, $ARBOR_GESTURES_ON}"
  arbor_start 3 ARBOR_NO_HOTKEYS=0
  ctl dock "$W1" left
  ctl dock "$W2" right
  sleep 0.7
  summary
  read -r dx dy dw dh <<< "$(arbor_ask desktop)"
  bare_x=$((dx + dw / 2))
  bare_y=$((dy + dh - 30))
  echo "the Desktop is at $dx $dy $dw $dh; the floating window at $(frame_of "$W3")"
  [ -n "$AX_ROLES" ] && echo "Finder says of $bare_x $bare_y: $(limit 5 "$AX_ROLES" at "$(pgrep -x Finder)" "$bare_x" "$bare_y")"
  if nothing_at "$bare_x" "$bare_y"; then
    slot=$(real_frame_of "$W1")
    floating=$(real_frame_of "$W3")
    mark "the Desktop"
    trace_on "$label-desktop" "a double-click on the bare Desktop"
    frames_during "$W3" "$ARBOR_OUT/frames-$label-desktop-1.txt" dblclick "$bare_x" "$bare_y"
    trace_off "$label-desktop"
    [ -n "$WITNESS_PID" ] && echo "mouse-downs that got past the taps: $(since_the_mark | grep -c '^down ')"
    check "the view is on the Desktop" eventually camera_on desktop
    check "the docked windows are out of view" eventually is parked "$W1"
    check "the floating window is in view" eventually is on_screen "$W3"
    # It may move once, to the place it has on a Desktop with the whole view. Swept aside by macOS it goes out and comes back.
    check "and moved once at most: macOS did not sweep it aside at the first click" one_road "$ARBOR_OUT/frames-$label-desktop-1.txt"
    shot "$label-desktop-1"
    frames_during "$W1" "$ARBOR_OUT/frames-$label-desktop-2.txt" dblclick "$bare_x" "$bare_y"
    check "again: the view is back on everything" eventually camera_on root
    check "the docked window is back in its slot" eventually real_frame_is "$W1" "$slot"
    check "by one road" one_road "$ARBOR_OUT/frames-$label-desktop-2.txt"
    check "the floating window is where it was" eventually real_frame_is "$W3" "$floating"
    shot "$label-desktop-2"
  else
    echo "somebody's window is at $bare_x $bare_y: not double-clicking there"
  fi
  tap_log 20
  arbor_stop
  about title
}

arbor_build
AX_ROLES="$ARBOR_ROOT/.build/mac-shell/ax-roles"
if arbor_is_current "$ARBOR_ROOT/scripts/mac-shell/ax-roles.swift" "$AX_ROLES" \
  || swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/ax-roles.swift" -o "$AX_ROLES" > "$ARBOR_OUT/build-ax-roles.log" 2>&1; then
  :
else
  AX_ROLES=""
  echo "ax-roles.swift did not compile; no survey:"
  head -n 30 "$ARBOR_OUT/build-ax-roles.log"
fi
witness_start 900
ON_DOWN=""
ON_UP=""
OFF_DOWN=""
title_bar_action as-it-is

if on_throwaway_mac; then
  step "macOS's own window management as macOS comes"
  title_bar_action default
  macos_tiling on
  macos_click_wallpaper on
  title_bars defaults
  the_desktop defaults
  step "macOS's own window management switched off"
  macos_tiling off
  macos_click_wallpaper off
  title_bars off
  the_desktop off
else
  # Icons and widgets lie below the ordinary windows, where `nothing_at` does not look, and a click on the wallpaper would sweep
  # a person's windows aside: no double-click on the Desktop here.
  title_bars as-it-is
fi

about title
step "a tile opens on one click; the second click of a double-click reaches nobody"
ARBOR_TEST_WINDOWS_ARGS="--min-size 3:700x500"
arbor_settings "{\"titleBarDoubleClick\": true, $ARBOR_GESTURES_ON}"
arbor_start 3 ARBOR_NO_HOTKEYS=0
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W2" top
# The focus that docking gives the window can come back a moment later and move the view onto it.
sleep 0.7
is tile "$W3" || ctl show-all
summary
shot 10-tile
if check "the window that cannot shrink is a tile" is tile "$W3"; then
  read -r tx ty <<< "$(tile_of "$W3")"
  read -r _ tile_top _ _ <<< "$(arbor_ask tile "$W3")"
  read -r sx sy sw sh <<< "$(arbor_ask screen)"
  # Near the tile's top edge: where the framed window will have its title bar.
  mark "a tile"
  frames_during "$W3" "$ARBOR_OUT/frames-tile.txt" dblclick "$tx" "$((tile_top + 10))"
  check "the double-click opened the tile" eventually camera_on "$W3"
  check "and the view is still on the window seconds later" camera_on "$W3"
  [ -n "$WITNESS_PID" ] && check "the second click reached nobody" reached '^down ' 1
  check "so macOS made nothing of it on the title bar that came under the pointer" \
    real_frame_is "$W3" "$((sx + ARBOR_GAP)) $((sy + ARBOR_GAP)) $((sw - 2 * ARBOR_GAP)) $((sh - 2 * ARBOR_GAP))"
  shot 11-tile-opened
  summary
  ctl show-all
  click "$tx" "$ty"
  check "one click opens it too" eventually camera_on "$W3"
fi
tap_log 20
arbor_stop
ARBOR_TEST_WINDOWS_ARGS=""

step "the settings as they ship"
arbor_settings '{}'
arbor_start 2 ARBOR_NO_HOTKEYS=0
ships="$("$ARBOR_BIN/arborctl" get titleBarDoubleClick) $("$ARBOR_BIN/arborctl" get desktopDoubleClick)"
echo "titleBarDoubleClick and desktopDoubleClick ship as: $ships"
if [ "$ships" = "false false" ]; then
  check "with both switches off the log says nothing of taps for double-clicks" no_install_logged
  [ -n "$WITNESS_PID" ] && check "and the window server lists none" no_double_click_tap
fi
arbor_stop

if [ -n "$WITNESS_PID" ]; then
  step "how late the same clicks arrive without F14's taps"
  arbor_settings "{\"titleBarDoubleClick\": false, \"desktopDoubleClick\": false, $ARBOR_GESTURES_ON}"
  arbor_start 2 ARBOR_NO_HOTKEYS=0
  ctl dock "$W1" left
  ctl dock "$W2" right
  sleep 0.7
  check "the window server lists no tap for double-clicks" no_double_click_tap
  clicks_that_are_not_arbors "$W2"
  OFF_DOWN=$LATE_DOWN
  read -r _ on_median on_worst <<< "$ON_DOWN"
  read -r _ off_median off_worst <<< "$LATE_DOWN"
  echo "a mouse-down that is not Arbor's: median $on_median µs with the taps, $off_median µs without; second largest $on_worst and $off_worst"
  check "the taps add under 10 ms to a mouse-down that is not Arbor's (median)" within_10_ms "$on_median" "$off_median"
  check "and to the slowest but one" within_10_ms "$on_worst" "$off_worst"
  read -r _ on_median on_worst <<< "$ON_UP"
  read -r _ off_median off_worst <<< "$LATE_UP"
  echo "a mouse-up: median $on_median µs with the taps, $off_median µs without; second largest $on_worst and $off_worst"
  check "under 10 ms to a mouse-up (median)" within_10_ms "$on_median" "$off_median"
  check "and to the slowest but one" within_10_ms "$on_worst" "$off_worst"
  arbor_stop
fi

if on_throwaway_mac; then
  for action in Minimize None; do
    step "macOS is set to $action: Arbor leaves title bars alone"
    title_bar_action "$action"
    arbor_settings "{\"titleBarDoubleClick\": true, $ARBOR_GESTURES_ON}"
    arbor_start 2 ARBOR_NO_HOTKEYS=0
    ctl dock "$W1" left
    ctl dock "$W2" right
    sleep 0.7
    slot=$(real_frame_of "$W1")
    check "the log says why" grep -q "so Arbor leaves title bars alone" "$ARBOR_HOME/arbor.log"
    check "doctor says why" doctor_says "so Arbor leaves title bars alone"
    check "no tap for double-clicks was installed" no_install_logged
    [ -n "$WITNESS_PID" ] && check "the window server lists none" no_double_click_tap
    mark "a title bar, macOS set to $action"
    # shellcheck disable=SC2046
    frames_during "$W1" "$ARBOR_OUT/frames-$action.txt" must dblclick $(titlebar_of "$W1")
    check "the view stayed" camera_on root
    [ -n "$WITNESS_PID" ] && check "the app got both clicks" reached '^down ' 2
    if [ "$action" = Minimize ]; then
      check "macOS minimized the window, as its person asked" eventually is minimized "$W1"
      # Descriptor 9 is the test windows' stdin.
      echo "restore $W1" >&9
      check "back from the Dock it is in its slot" eventually real_frame_is "$W1" "$slot"
    else
      check "nothing happened, as its person asked" stayed "$ARBOR_OUT/frames-$action.txt"
      step "the setting goes back to what macOS comes with while Arbor runs"
      title_bar_action default
      # The news of a changed setting may take a moment to reach a running app.
      check "the taps are installed at a layout soon after" eventually laid_out_and_installed 1
      # shellcheck disable=SC2046
      dblclick $(titlebar_of "$W1")
      check "and a double-click frames the window" eventually camera_on "$W1"
    fi
    tap_log 12
    arbor_stop
  done
  title_bar_action default
fi

on_throwaway_mac || echo "a person's Mac: leaving out Safari and the survey of stock apps, which run only on GitHub's Macs"
if on_throwaway_mac && [ "$SECONDS" -lt 450 ]; then
  step "a real app with controls in the top of its window"
  open -a Safari
  sleep 5
  safari=$(pgrep -x Safari | head -n 1)
  S=""
  if [ -n "$safari" ] && [ -n "$AX_ROLES" ]; then
    arbor_settings "{\"titleBarDoubleClick\": true, $ARBOR_GESTURES_ON}"
    ARBOR_EXTRA_PIDS=$safari
    arbor_start 1 ARBOR_NO_HOTKEYS=0
    S=$(state | python3 -c '
import json, sys
print(next((w["id"] for w in json.load(sys.stdin)["windows"] if w["managed"] and w["pid"] == int(sys.argv[1])), ""))' "$safari")
    [ -n "$S" ] || { echo "Safari has no window that Arbor arranges"; arbor_stop; }
  fi
  if [ -n "$S" ]; then
    read -r sx sy sw sh <<< "$(arbor_ask screen)"
    inner="$((sx + ARBOR_GAP)) $((sy + ARBOR_GAP)) $((sw - 2 * ARBOR_GAP)) $((sh - 2 * ARBOR_GAP))"
    ctl dock "$S" left
    ctl zoom "$S"
    sleep 0.7
    summary
    read -r x y w _ <<< "$(frame_of "$S")"
    # Asked once: it is hundreds of questions, and an app may be slow to answer.
    limit 30 "$AX_ROLES" strip "$safari" > "$ARBOR_OUT/safari-roles.txt" 2>&1
    sed -n '/20 points down/,/27 points down/p' "$ARBOR_OUT/safari-roles.txt" | cut -c 1-120
    shot 25-safari-framed
    read -r _ plain _ <<< "${OFF_DOWN:-0 0 0}"
    mark "Safari's address field"
    dblclick "$((x + w / 2))" "$((y + 22))"
    sleep 0.7
    check "a double-click in the address field is Safari's: the view stayed" camera_on "$S"
    if [ -n "$WITNESS_PID" ]; then
      check "Safari got both clicks" reached '^down ' 2
      read -r _ asked _ <<< "$(late down clicks=2)"
      echo "the second mouse-down waited $asked µs while Arbor asked what is under the pointer; a plain one takes $plain µs"
      check "which is under 50 ms more than a click takes anyway" within_50_ms "$asked" "$plain"
    fi
    shot 26-safari-address-field
    key escape
    key escape
    mark "a button in Safari's toolbar"
    dblclick "$((x + 115))" "$((y + 22))"
    sleep 0.7
    check "two quick clicks on a toolbar button are Safari's" camera_on "$S"
    if [ -n "$WITNESS_PID" ]; then
      read -r _ asked _ <<< "$(late down clicks=2)"
      echo "the second mouse-down waited $asked µs"
      check "under 50 ms more than a click takes anyway" within_50_ms "$asked" "$plain"
    fi
    shot 26b-safari-button-clicked-twice
    empty=$(awk '/12 points down/ { row = 1; next } /points down/ { row = 0 }
      row && $NF == "AXWindow" && $(NF - 2) == "AXToolbar" && NF == 5 { split($2, ends, "…"); print int((ends[1] + ends[2]) / 2); exit }' "$ARBOR_OUT/safari-roles.txt")
    echo "an empty part of the toolbar is ${empty:-nowhere} points from the left"
    if [ -n "$empty" ]; then
      frames_during "$S" "$ARBOR_OUT/frames-safari.txt" dblclick "$((x + empty))" "$((y + 12))"
      check "a double-click on the empty toolbar of the framed window goes back" eventually camera_on root
      # shellcheck disable=SC2086
      check "and macOS did not zoom Safari" never_outside "$ARBOR_OUT/frames-safari.txt" $inner
      check "one road" one_road "$ARBOR_OUT/frames-safari.txt"
      shot 27-safari-back
    fi
    summary
    tap_log 20
    arbor_stop
  fi
  ARBOR_EXTRA_PIDS=""
  on_throwaway_mac && pkill -x Safari
fi
witness_stop

about title
echo
echo "VERDICT titleBarDoubleClick: $([ "$TITLE_FAILED" -eq 0 ] && echo "nothing failed" || echo "$TITLE_FAILED failed")"
echo "VERDICT desktopDoubleClick: $([ "$DESKTOP_FAILED" -eq 0 ] && echo "nothing failed" || echo "$DESKTOP_FAILED failed")"
echo "after $SECONDS seconds"

# Not checks: for the lists of roles in ArborCore/DoubleClick.swift. Only while the ten minutes allow it.
if on_throwaway_mac && [ -n "$AX_ROLES" ] && [ "$SECONDS" -lt 450 ]; then
  step "survey: a file on the Desktop"
  touch "$HOME/Desktop/arbor-F14.txt"
  sleep 2
  limit 10 "$AX_ROLES" icons > "$ARBOR_OUT/icons.txt" 2>&1
  echo "icons at: $(tr '\n' ';' < "$ARBOR_OUT/icons.txt")"
  read -r ix iy <<< "$(head -n 1 "$ARBOR_OUT/icons.txt")"
  if [ -n "${ix:-}" ]; then echo "Finder says of the icon: $(limit 5 "$AX_ROLES" at "$(pgrep -x Finder)" "$ix" "$iy")"; fi
  rm -f "$HOME/Desktop/arbor-F14.txt"

  step "survey: the top of stock apps' windows"
  for app in TextEdit Terminal "System Settings" Notes; do
    open -a "$app" 2>/dev/null || { echo "$app: cannot open"; continue; }
  done
  open "$HOME" 2>/dev/null
  sleep 6
  for app in Finder TextEdit Terminal "System Settings" Notes; do
    pid=$(pgrep -x "$app" | head -n 1)
    echo "-- $app (${pid:-not running})"
    [ -n "$pid" ] && [ "$SECONDS" -lt 540 ] && limit 15 "$AX_ROLES" strip "$pid" 2>&1 | cut -c 1-200 | head -n 60
  done
  shot 40-stock-apps
  for app in TextEdit Terminal "System Settings" Notes; do pkill -x "$app" 2>/dev/null; done
fi
exit 0
