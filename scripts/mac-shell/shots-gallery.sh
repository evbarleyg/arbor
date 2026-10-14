#!/bin/bash
# Everything Arbor draws, each thing once, in every look macOS can give it: light and dark, each of them plain, with Increase
# Contrast and with Reduce Transparency. A contact sheet, to be LOOKED AT after any change under Sources/ArborKit/UI.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-gallery.sh             light, dark
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-gallery-contrast.sh    the same with Increase Contrast, as System Settings sets it
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-gallery-opaque.sh      the same with Reduce Transparency alone
#
# The other shots-*.sh follow one feature through all its states. This one takes the same two dozen pictures in each look, under the
# same names, so that two looks, or two commits, can be laid side by side: <look>-<number>-<what>.png. Over a drawn landscape, because
# a black wallpaper hides every shadow, every blur and every dark line.
#
# What to ask of each picture: can it be read; is it aligned; does the text fit; does it look as if macOS had drawn it; is it quiet;
# does it say what a person needs, in words they know.
#
# Only on GitHub's throwaway Macs: the looks are settings of the Mac.
ARBOR_TIME_LIMIT=1100
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "switch dark mode, the wallpaper, Increase Contrast, Reduce Transparency and Reduce Motion"

SCENERY="$ARBOR_ROOT/.build/mac-shell/scenery"
AXFIND="$ARBOR_ROOT/.build/mac-shell/axfind"
TITLE="Arbor Settings"
# A look takes two to three minutes, so the six are three runs, which can go side by side: this script takes the plain two, and
# shots-gallery-contrast.sh and shots-gallery-opaque.sh name theirs in GALLERY_LOOKS.
LOOKS=${GALLERY_LOOKS:-light dark}

claim() { echo; echo "▸ $*"; }
not() { ! "$@"; }
ax() { "$AXFIND" "$ARBOR_PID" "$@"; }
# panel_id <level>: Arbor's window at that level that is on screen.
panel_id() { overlays | awk -v level="$1" '$3 == level && $8 == "on" { print $1; exit }'; }
menu_ids() { overlays | awk '$3 == 101 && $8 == "on" { print $1 }'; }
menu_is_open() { [ -n "$(menu_ids)" ]; }
backdrop_shows() { [ -n "$(overlays | awk '$3 < -1000 && $8 == "on"')" ]; }
pointer_away() { move "$((sx + sw - 40))" "$((sy + 40))"; }
type_text() {
  local index
  for ((index = 0; index < ${#1}; index++)); do key "${1:index:1}" > /dev/null || return 1; done
}

# both <name> <level>: the whole screen, and the panel at that level alone and unscaled as <name>-alone.
both() {
  local id
  shot_after "${3:-0.5}" "$1"
  id=$(panel_id "$2")
  [ -n "$id" ] && ARBOR_SETTLE=0 look "$1-alone" "$id"
}

# scene <look>: the Mac's settings for it. Apps read them as they start.
scene() {
  local mode=${1%%-*} picture=day file size
  [ "$mode" = dark ] && picture=night
  file="$ARBOR_ROOT/.build/mac-shell/scenery-$picture.png"
  size=$(pointer displays | awk 'NR == 1 { print $6, $7 }')
  # shellcheck disable=SC2086
  "$SCENERY" landscape "$picture" $size "$file"
  wallpaper "$file"
  appearance "$mode"
  case "$1" in
    *-contrast) macos_increase_contrast on; macos_reduce_transparency on ;;
    *-opaque) macos_increase_contrast off; macos_reduce_transparency on ;;
    *) macos_increase_contrast off; macos_reduce_transparency off ;;
  esac
}

SETTINGS='{
  "minimapDuration": 4,
  "rules": [
    { "app": "com.example.mail", "title": "Inbox", "action": "dock left" },
    { "app": "com.example.player", "action": "float" }
  ],
  "excludedBundleIDs": ["com.example.music"]
}'

tour() {
  local p=$1 x y w h gx gy id pane index

  arbor_settings "$SETTINGS"
  arbor_start 6 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0 ARBOR_PANELS_IN_PICTURES=1 \
    ARBOR_RELEASES_URL=http://127.0.0.1:8765/latest.json
  read -r sx sy sw sh <<< "$(arbor_ask screen)"
  pointer_away

  claim "$p: the menu bar item, and nothing else, before anything is docked"
  shot "$p-01-nothing-docked"
  check "the menu bar item shows" status_item
  check "no surface behind the windows yet" not backdrop_shows

  claim "$p: the line on screen"
  # The last window is in front of the others.
  # shellcheck disable=SC2046
  click $(center_of "$W6")
  key ctrl+opt+down
  both "$p-02-line-nothing-docked" 6 0.4
  check "a key that cannot act is answered on screen" test -n "$(panel_id 6)"
  sleep 3

  claim "$p: the surface behind docked windows, and the line round the focused one"
  ctl dock "$W1" left
  ctl dock "$W2" right
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  pointer_away
  sleep 3
  shot "$p-03-two-columns"
  check "the surface is on screen" eventually backdrop_shows

  claim "$p: the drop preview"
  read -r x y w h <<< "$(frame_of "$W1")"
  # shellcheck disable=SC2046
  drag $(titlebar_of "$W6") "$((x + w / 2))" "$((y + h - 40))" --no-release
  shot "$p-04-drop-preview"
  check "it shows while the button is held" has_overlay 3
  release
  check "the window docked where it showed" eventually is docked "$W6"
  is docked "$W6" || ctl dock "$W6" beside "$W1" bottom

  claim "$p: tiles: a window's, a group's, the Desktop's"
  ctl dock "$W5" beside "$W6" right
  ctl dock "$W3" beside "$W2" bottom
  ctl dock "$W4" beside "$W3" right
  sleep 0.6
  ctl show-all
  ctl resize "$W1" right "$((110 * sw / 1024))"
  ctl resize "$W2" left "$((60 * sw / 1024))"
  ctl resize "$W6" top "$((-90 * sh / 674))"
  ctl resize "$W3" top "$((-190 * sh / 674))"
  pointer_away
  sleep 3
  shot "$p-05-tiles"
  summary

  claim "$p: the handle in a gap"
  read -r gx gy <<< "$(seam_below "$W1")"
  move "$((gx - 70))" "$gy"
  shot "$p-06-gap-hover"
  pointer_away

  claim "$p: the panel of shortcuts"
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  key ctrl+opt+shift+/
  both "$p-07-shortcuts" 5
  check "it is up" test -n "$(panel_id 5)"
  key escape
  check "⎋ puts it away" eventually not has_overlay 5

  claim "$p: Go to…"
  key ctrl+opt+g
  shot "$p-08-go-to"
  type_text 3
  shot "$p-09-go-to-typed"
  key escape

  claim "$p: the minimap"
  ctl zoom "$W1"
  sleep 3
  ctl minimap
  both "$p-10-minimap" 5
  check "it is up" test -n "$(panel_id 5)"
  sleep 4

  claim "$p: a hint, over a framed window"
  ctl show-all
  sleep 3
  key ctrl+opt+return
  both "$p-11-line-hint" 6
  sleep 3

  claim "$p: the field for a name"
  key ctrl+opt+n
  shot "$p-12-name-empty"
  type_text writing
  both "$p-13-name-typed" 8
  check "it is up" test -n "$(panel_id 8)"
  key escape

  claim "$p: peek's outline"
  key ctrl+opt+space --down
  sleep 0.6
  # shellcheck disable=SC2046
  move $(center_of "$W2")
  shot "$p-14-peek"
  check "an outline shows while the keys are down" has_overlay 3
  key ctrl+opt+escape --held
  key ctrl+opt+space --up
  ctl show-all

  claim "$p: the menu"
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  sleep 3
  # shellcheck disable=SC2046
  rightclick $(status_item)
  check "a right click opens it" eventually menu_is_open
  shot "$p-15-menu"
  index=1
  for id in $(menu_ids); do ARBOR_SETTLE=0 look "$p-15-menu-alone-$index" "$id"; index=$((index + 1)); done
  menu_is_open && key escape
  check "⎋ closes it" eventually not menu_is_open

  # A rehearsal has no Accessibility to find the window by.
  if [ -z "${ARBOR_REHEARSAL:-}" ]; then
    claim "$p: the settings window, every pane"
    ctl settings-window
    check "it opens" eventually ax window "$TITLE"
    shot "$p-16-settings-on-screen"
    for pane in general windows dragging tabs gestures appearance menu-bar scripting shortcuts rules apps; do
      "$ARBOR_BIN/arborctl" settings-window "$pane" > /dev/null 2>&1 || continue
      look "$p-17-settings-$pane" "$(ax window "$TITLE")"
    done
    key cmd+w
    check "⌘W closes it" eventually not ax window "$TITLE"
  fi

  claim "$p: the answer to Check for Updates…"
  ctl check-for-updates
  sleep 2
  id=$(overlays | awk '$3 == 3 && $8 == "on" && $7 > 60 { print $1; exit }')
  check "a window answers" test -n "$id"
  shot "$p-18-update-on-screen"
  [ -n "$id" ] && look "$p-18-update-alone" "$id"
  key escape

  claim "$p: paused"
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  key ctrl+opt+escape
  both "$p-19-paused" 6
  sleep 3
  shot "$p-20-paused-at-rest"
  key ctrl+opt+escape
  sleep 1

  echo "everything Arbor said on screen in this look:"
  grep -F "said on" "$ARBOR_HOME/arbor.log" | sed 's/.*said on [^:]*: /  /'
  arbor_stop "$p-21-after-quit"
}

step "the Mac"
echo "macOS $(sw_vers -productVersion)"
arbor_build
if [ -n "${ARBOR_REHEARSAL:-}" ]; then
  SCENERY=true # A rehearsal (rehearse.sh) has no screen to decorate.
else
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/scenery.swift" -o "$SCENERY" > "$ARBOR_OUT/build-scenery.log" 2>&1 \
    || { cat "$ARBOR_OUT/build-scenery.log"; die "scripts/mac-shell/scenery.swift did not compile"; }
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/axfind.swift" -o "$AXFIND" > "$ARBOR_OUT/build-axfind.log" 2>&1 \
    || { cat "$ARBOR_OUT/build-axfind.log"; die "scripts/mac-shell/axfind.swift did not compile"; }
fi

# A newer release to be told about, from this Mac.
scratch_dir gallery-feed FEED
echo '{"tag_name": "v9.9.9", "html_url": "https://example.invalid/ignored"}' > "$FEED/latest.json"
(cd "$FEED" && exec python3 -m http.server 8765 --bind 127.0.0.1 > /dev/null 2>&1) &
started $!

# A click on the wallpaper would sweep every window aside, and a pointer that misses a window by a point does click there.
macos_click_wallpaper off
macos_reduce_motion on

for look in $LOOKS; do
  step "$look"
  scene "$look"
  tour "$look"
done
scene light
ls -l "$ARBOR_OUT" | awk '{ print $5, $9 }'
