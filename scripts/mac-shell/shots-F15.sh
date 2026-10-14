#!/bin/bash
# What Arbor draws at rest, in pictures (docs/features/F15-appearance-options.md): the backdrop behind docked
# windows, tiles of all three kinds, the handle in a gap, the drop preview. In light and in dark mode.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-F15.sh      on one of GitHub's Macs
#   scripts/mac-shell/shots-F15.sh                               on your own Mac (about four minutes, hands off)
#
# It arranges only its own test windows. What changes the system (the wallpaper, dark mode, one setting of
# WindowManager, a click on the wallpaper) goes through lib.sh's guards and happens only on GitHub's throwaway
# Macs. shots-F15-apps.sh, which opens real apps for their icons, runs only there.
#
# On a person's Mac nothing of the system changes, and the script is run for its checks:
# - instead of dark mode, Arbor and the test windows alone are told which mode to draw in (ARBOR_APPEARANCE);
# - lib.sh's curtain hangs in front of everything that was open, and so in front of the backdrop too, which lies just
#   above the Desktop's icons. Pictures taken there show tiles, handles and the drop preview, not the backdrop. The window
#   server still says where the backdrop is, which is what the checks ask;
# - the drawn landscape and the sheet of materials are left out: they are there to be looked at.
# `scenery capture` (a picture of some processes' windows and no others) is tried on the throwaway Mac. Once it has been seen to
# work there, it is the way to pictures of the backdrop on a person's Mac.
#
# The pictures are the point; the checks cover what a picture cannot show: that the backdrop lies under
# everything and lets clicks through, and that a gap can still be dragged.
source "$(dirname "$0")/lib.sh"

SCENERY="$ARBOR_ROOT/.build/mac-shell/scenery"
# Settings every session keeps, whatever else a step sets. See `pictures`.
BASE=""

# scene <light|dark>: that mode, and something behind the windows on which darkening and blurring can be seen.
scene() {
  local picture=day file size
  on_throwaway_mac || return 0
  [ "$1" = dark ] && picture=night
  file="$ARBOR_ROOT/.build/mac-shell/scenery-$picture.png"
  size=$(pointer displays | awk 'NR == 1 { print $6, $7 }')
  # shellcheck disable=SC2086
  "$SCENERY" landscape "$picture" $size "$file"
  wallpaper "$file"
  appearance "$1"
}

# materials <light|dark>: every material macOS has to blur with, side by side, to choose one from.
materials() {
  local sheet
  on_throwaway_mac || return 0
  "$SCENERY" materials 4 "$1" &
  sheet=$!
  started "$sheet"
  shot_after 2 "$1-materials"
  arbor_await_exit "$sheet" 60 || kill_started "$sheet"
}

# settings ['"key": value, …']: replace settings.json while Arbor runs.
settings() {
  printf '{%s%s}\n' "$BASE" "${1:+, $1}" > "$ARBOR_HOME/settings.json"
  ctl reload-settings
}

# Out of the way of everything that reacts to it, and short of the corner itself, which may be a hot corner.
pointer_away() { move "$((sx + sw - 40))" "$((sy + 40))"; }

# The backdrop as the window server sees it: far below the normal level, on screen.
backdrop_window() { overlays | awk '$3 < -1000 && $8 == "on"'; }
has_backdrop() { [ -n "$(backdrop_window)" ]; }
has_no_backdrop() { [ -z "$(backdrop_window)" ]; }

# pictures <light|dark>: one session with six test windows.
pictures() {
  local p=$1 x y w h gx gy before after
  if on_throwaway_mac; then
    arbor_start 6
  else
    # AppKit reads both from the defaults, of which a process's arguments are the first place it looks. Only the
    # title bars depend on it, so nothing is lost where it does not work.
    ARBOR_TEST_WINDOWS_ARGS="-NSRequiresAquaSystemAppearance YES"
    [ "$p" = dark ] && ARBOR_TEST_WINDOWS_ARGS="-AppleInterfaceStyle Dark"
    [ -n "${ARBOR_REHEARSAL:-}" ] && ARBOR_TEST_WINDOWS_ARGS=""
    arbor_start 6 "ARBOR_APPEARANCE=$p"
  fi
  read -r sx sy sw sh <<< "$(arbor_ask screen)"
  # The arrangement below was worked out on GitHub's display, 1024 by 674 points without the menu bar and the Dock. On a
  # larger one the same slots would be large enough for their windows, and there would be no tile to look at. So the
  # size below which a slot is a tile, and the distances, grow with the display.
  BASE="\"minimumUsableWidth\": $((240 * sw / 1024)), \"minimumUsableHeight\": $((160 * sh / 674))"
  settings
  pointer_away
  shot "$p-00-nothing-docked"
  check "nothing docked, no backdrop" has_no_backdrop

  step "$p: two columns with the Desktop between them"
  ctl dock "$W1" left
  ctl dock "$W2" right
  pointer_away
  shot "$p-01-two-columns"
  check "the backdrop is on screen" eventually has_backdrop
  echo "Arbor's own windows (id pid level x y w h on owner):"
  overlays
  if on_throwaway_mac; then
    # shellcheck disable=SC2086
    if limit 15 "$SCENERY" capture "$ARBOR_OUT/$p-01b-own-windows-only.png" - $ARBOR_PID $ARBOR_WINDOWS_PID; then
      echo "scenery capture: took $p-01b-own-windows-only.png: Arbor's and the test windows and nothing else should be in it"
    else
      echo "scenery capture: failed with $?"
    fi
  fi

  read -r x y w h <<< "$(frame_of "$W1")"
  # On a person's Mac that click would sweep all their windows aside (see below).
  if on_throwaway_mac; then
    step "$p: clicks go through the backdrop to the Desktop"
    front_app() { lsappinfo info -only name "$(lsappinfo front)" | cut -d '"' -f 4; }
    # shellcheck disable=SC2046
    click $(center_of "$W1")
    echo "in front after a click on a test window: $(front_app)"
    # Between the window and the screen's edge, where only the backdrop is.
    click "$((x - 4))" "$((y + h / 2))"
    sleep 0.5
    echo "in front after a click on the backdrop beside it: $(front_app)"
    check "a click on the backdrop reaches the Finder's Desktop" test "$(front_app)" = Finder
  fi

  step "$p: a drop preview, held over the lower part of the left window"
  # The last window is in front of the other floating ones, so its title bar is free.
  # shellcheck disable=SC2046
  drag $(titlebar_of "$W6") "$((x + w / 2))" "$((y + h - 40))" --no-release
  shot "$p-02-drop-preview"
  check "a drop preview is on screen while the button is held" has_overlay 3
  release
  check "the dragged window docked" eventually is docked "$W6"
  is docked "$W6" || ctl dock "$W6" beside "$W1" bottom

  step "$p: window tiles, a group's tile and the Desktop's tile"
  ctl dock "$W5" beside "$W6" right
  ctl dock "$W3" beside "$W2" bottom
  ctl dock "$W4" beside "$W3" right
  # macOS reports the focus that docking gave a window a moment later, and Arbor may follow it with the camera.
  sleep 0.6
  ctl show-all
  ctl resize "$W1" right "$((110 * sw / 1024))"
  ctl resize "$W2" left "$((60 * sw / 1024))"
  ctl resize "$W6" top "$((-90 * sh / 674))"
  ctl resize "$W3" top "$((-190 * sh / 674))"
  summary
  pointer_away
  shot "$p-03-tiles"

  step "$p: the handle in a gap, under the pointer and while it is dragged"
  read -r gx gy <<< "$(seam_below "$W1")"
  # Beside the handle, which sits in the middle of the gap: the pointer would cover it.
  move "$((gx - 70))" "$gy"
  shot "$p-04-gap-hover"
  read -r _ _ _ before <<< "$(frame_of "$W1")"
  drag "$((gx - 70))" "$gy" "$((gx - 70))" "$((gy + 30))" --no-release
  shot "$p-05-gap-dragged"
  release
  read -r _ _ _ after <<< "$(frame_of "$W1")"
  echo "the window above the gap was $before high and is now $after"
  check "dragging the gap made the window above it about 30 points higher" test "$((after - before))" -ge 20
  read -r gx gy <<< "$(seam_right_of "$W1")"
  move "$gx" "$((gy - 70))"
  shot "$p-06-upright-gap-hover"
  pointer_away
  shot "$p-07-gap-left"

  step "$p: blur"
  settings '"blurBehindArranged": 1'
  shot "$p-10-dim-and-blur"
  settings '"blurBehindArranged": 1, "dimBehindArranged": 0'
  shot "$p-11-blur-alone"
  settings '"blurBehindArranged": 0.6, "dimBehindArranged": 0'
  shot "$p-12-blur-60-alone"
  settings '"blurBehindArranged": 0.3, "dimBehindArranged": 0'
  shot "$p-13-blur-30-alone"

  step "$p: more and less darkening"
  settings '"dimBehindArranged": 0, "desktopEdge": 0'
  shot "$p-14-no-backdrop"
  check "with neither, the backdrop leaves the screen" eventually has_no_backdrop
  settings '"dimBehindArranged": 0.5'
  shot "$p-15-dim-50"

  step "$p: tint"
  settings '"tintBehindArranged": 0.2'
  shot "$p-15b-tint-20"
  settings '"tintBehindArranged": 0.5, "dimBehindArranged": 0'
  shot "$p-15c-tint-50-alone"

  step "$p: tile options"
  settings '"tileStyle": "name"'
  shot "$p-16-names"
  settings '"tileStyle": "plain"'
  shot "$p-16b-plain"
  settings '"appColours": false'
  shot "$p-17-grey"
  settings '"appColourAmount": 1'
  shot "$p-18-full-colour"
  settings '"gapHandles": "hidden"'
  read -r gx gy <<< "$(seam_below "$W1")"
  move "$((gx - 70))" "$gy"
  shot "$p-19-handle-hidden"
  settings

  step "$p: the line around the Desktop"
  ctl float "$W5"
  ctl float "$W6"
  ctl resize "$W1" right "$((-170 * sw / 1024))"
  summary
  pointer_away
  shot "$p-19b-desktop-edge-default"
  settings '"desktopEdge": 0.3'
  shot "$p-19c-desktop-edge-30"
  settings '"desktopEdge": 1, "dimBehindArranged": 0'
  shot "$p-19d-desktop-edge-alone"
  settings

  step "$p: the camera"
  pointer_away
  ctl zoom "$W1"
  shot "$p-20-framed"
  ctl back
  ctl desktop
  shot "$p-21-desktop"
  check "with the Desktop framed, no backdrop" eventually has_no_backdrop
  ctl show-all
  arbor_stop "$p-22-after-quit"
}

step "the Mac"
echo "macOS $(sw_vers -productVersion), $(swift --version 2>&1 | head -n 1)"
arbor_build
grep -E "warning:" "$ARBOR_OUT/build.log" 2>/dev/null | sort -u | head -n 20
if [ -n "${ARBOR_REHEARSAL:-}" ]; then
  SCENERY=true # A rehearsal (rehearse.sh) has no screen to decorate.
elif ! on_throwaway_mac; then
  : # Not used there.
elif ! swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/scenery.swift" -o "$SCENERY" \
  > "$ARBOR_OUT/build-scenery.log" 2>&1; then
  cat "$ARBOR_OUT/build-scenery.log"
  die "scripts/mac-shell/scenery.swift did not compile"
fi
# Since macOS 14 a click on the wallpaper sweeps every window aside, and one step here clicks through the backdrop.
if arbor_may "set \"click wallpaper to reveal desktop\" to Only in Stage Manager and restart WindowManager"; then
  defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false
  killall WindowManager 2>/dev/null
  sleep 1
fi

for mode in light dark; do
  step "$mode mode"
  scene "$mode"
  materials "$mode"
  pictures "$mode"
done
scene light
ls -l "$ARBOR_OUT" | awk '{ print $5, $9 }'
