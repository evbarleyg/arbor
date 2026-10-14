#!/bin/bash
# Everything Arbor draws, each thing once, in one run: a contact sheet to be LOOKED AT after any change under Sources/ArborKit/UI.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-gallery.sh             light and dark; motion; a large display and a Retina one
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-gallery-looks.sh       Increase Contrast and Reduce Transparency, light and dark;
#                                                                           real apps
#
# The other shots-*.sh follow one feature through all its states, one build and one Mac each. This one takes the same pictures in
# every look, under the same names, so that two looks, or two commits, can be laid side by side: <look>-<number>-<what>.png, and
# <…>-alone-<n>.png for each window of Arbor's own that came up for it, by itself and unscaled. Over a drawn landscape, because
# a black wallpaper hides every shadow and every dark line.
#
# What to ask of each picture: can it be read; is it aligned; does the text fit; does it look as if macOS had drawn it; is it quiet;
# does it say what a person needs, in words they know.
#
# What a hosted Mac cannot show: translucency. Every material macOS has comes out as one flat colour there (shots-F15.sh's sheet of
# materials), which is also what a person with Reduce Transparency sees.
#
# Each session records a trace (docs/TRACES.md), which comes back in traces/.
#
# Only on GitHub's throwaway Macs: the looks are settings of the Mac.
ARBOR_TIME_LIMIT=1100
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "switch dark mode, the wallpaper, Increase Contrast, Reduce Transparency and Reduce Motion, and plug in a display"

SCENERY="$ARBOR_ROOT/.build/mac-shell/scenery"
AXFIND="$ARBOR_ROOT/.build/mac-shell/axfind"
TITLE="Arbor Settings"
# What to take: looks (light, dark, each also -contrast and -opaque), and the sessions motion, large, apps-light and apps-dark.
PARTS=${GALLERY_PARTS:-light dark motion large}
mkdir -p "$ARBOR_OUT/traces"

claim() { echo; echo "▸ $*"; }
not() { ! "$@"; }
ax() { "$AXFIND" "$ARBOR_PID" "$@"; }
menu_is_open() { overlays | awk '$3 == 101 && $8 == "on" { found = 1 } END { exit !found }'; }
surface_shows() { [ -n "$(overlays | awk '$3 < -1000 && $8 == "on"')" ]; }
pointer_away() { move "$((sx + sw - 40))" "$((sy + 40))"; }
type_text() {
  local index
  for ((index = 0; index < ${#1}; index++)); do key "${1:index:1}" > /dev/null || return 1; done
}

# Arbor's own windows that are on screen.
ids_on() { overlays | awk '$8 == "on" { print $1 }' | sort; }
# has_come "<ids before>": whether a window of Arbor's is on screen that was not.
has_come() { [ -n "$(comm -13 <(echo "$1") <(ids_on))" ]; }
# both <name> "<ids before>" [seconds]: the whole screen, and each window of Arbor's that has come since, alone.
both() {
  local id number=1
  shot_after "${3:-0.5}" "$1"
  for id in $(comm -13 <(echo "$2") <(ids_on)); do
    ARBOR_SETTLE=0 look "$1-alone-$number" "$id"
    number=$((number + 1))
  done
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
    # As the switch in System Settings leaves them: it takes Reduce Transparency along.
    *-contrast) macos_increase_contrast on; macos_reduce_transparency on ;;
    *-opaque) macos_increase_contrast off; macos_reduce_transparency on ;;
    *) macos_increase_contrast off; macos_reduce_transparency off ;;
  esac
}

# The line on screen is switched on for its own pictures only: it stays for seconds, over whatever is taken next.
SETTINGS='{
  "messages": "off",
  "rules": [
    { "app": "com.example.mail", "title": "Inbox", "action": "dock left" },
    { "app": "com.example.player", "action": "float" }
  ],
  "excludedBundleIDs": ["com.example.music"]
}'

# session <name> <windows>: Arbor as a person has it, with its shortcuts, its menu bar item and a newer release to be told about.
session() {
  arbor_settings "$SETTINGS"
  arbor_start "$2" ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0 ARBOR_PANELS_IN_PICTURES=1 \
    ARBOR_RELEASES_URL=http://127.0.0.1:8765/latest.json
  read -r sx sy sw sh <<< "$(arbor_ask screen)"
  ctl trace on "gallery-$1"
  pointer_away
}

session_over() {
  local file
  ctl trace off
  for file in "$ARBOR_HOME"/traces/*.jsonl; do
    [ -f "$file" ] && cp "$file" "$ARBOR_OUT/traces/${file##*/}"
  done
  arbor_stop "${1:-}"
}

# MARK: One look

tour() {
  local p=$1 x y w h gx gy before pane

  session "$p" 6

  claim "$p: the menu bar item, and nothing else, before anything is docked"
  shot "$p-01-nothing-docked"
  check "the menu bar item shows" status_item
  check "no surface behind the windows yet" not surface_shows

  claim "$p: the surface behind docked windows, and the line round the focused one"
  ctl dock "$W1" left
  ctl dock "$W2" right
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  pointer_away
  shot "$p-02-two-columns"
  check "the surface is on screen" eventually surface_shows

  claim "$p: the drop preview"
  read -r x y w h <<< "$(frame_of "$W1")"
  # The last window is in front of the other floating ones, so its title bar is free.
  # shellcheck disable=SC2046
  drag $(titlebar_of "$W6") "$((x + w / 2))" "$((y + h - 40))" --no-release
  shot "$p-03-drop-preview"
  check "it shows while the button is held" has_overlay 3
  release
  check "the window docked where it showed" eventually is docked "$W6"
  is docked "$W6" || ctl dock "$W6" beside "$W1" bottom

  claim "$p: tiles: a window's, a group's, the Desktop's"
  ctl dock "$W5" beside "$W6" right
  ctl dock "$W3" beside "$W2" bottom
  ctl dock "$W4" beside "$W3" right
  # macOS reports the focus that docking gave a window a moment later, and Arbor may follow it with the view.
  sleep 0.6
  ctl show-all
  ctl resize "$W1" right "$((110 * sw / 1024))"
  ctl resize "$W2" left "$((60 * sw / 1024))"
  ctl resize "$W6" top "$((-90 * sh / 674))"
  ctl resize "$W3" top "$((-190 * sh / 674))"
  pointer_away
  shot "$p-04-tiles"
  check "a window is a tile" is tile "$W6"
  ctl set tileStyle name
  shot "$p-05-tiles-with-names"
  ctl reset tileStyle

  claim "$p: the handle in a gap"
  read -r gx gy <<< "$(seam_below "$W1")"
  # Beside the handle, which sits in the middle of the gap: the pointer would cover it.
  move "$((gx - 70))" "$gy"
  shot "$p-06-gap-hover"
  pointer_away

  claim "$p: the panel of shortcuts"
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  before=$(ids_on)
  key ctrl+opt+shift+/
  both "$p-07-shortcuts" "$before"
  check "it is up" has_come "$before"
  key escape
  check "⎋ puts it away" eventually not has_come "$before"

  claim "$p: Go to…"
  before=$(ids_on)
  key ctrl+opt+g
  both "$p-08-go-to" "$before"
  check "it is up" has_come "$before"
  type_text 3
  both "$p-09-go-to-typed" "$before"
  type_text zz
  both "$p-10-go-to-nothing-matches" "$before"
  key escape
  check "⎋ puts it away" eventually not has_come "$before"

  claim "$p: the minimap"
  ctl zoom "$W1"
  before=$(ids_on)
  ctl minimap
  both "$p-11-minimap" "$before"
  check "it is up" has_come "$before"
  ctl minimap

  claim "$p: the field for a name"
  before=$(ids_on)
  key ctrl+opt+n
  both "$p-12-name-empty" "$before"
  check "it is up" has_come "$before"
  type_text writing
  both "$p-13-name-typed" "$before"
  key escape

  claim "$p: peek's outline"
  before=$(ids_on)
  key ctrl+opt+space --down
  sleep 0.6
  # shellcheck disable=SC2046
  move $(center_of "$W2")
  shot "$p-14-peek"
  check "an outline shows while the keys are down" has_come "$before"
  key ctrl+opt+escape --held
  key ctrl+opt+space --up
  ctl show-all

  claim "$p: the menu"
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  before=$(ids_on)
  # shellcheck disable=SC2046
  rightclick $(status_item)
  check "a right click opens it" eventually menu_is_open
  both "$p-15-menu" "$before"
  menu_is_open && key escape
  check "⎋ closes it" eventually not menu_is_open

  # A rehearsal has no Accessibility to find the window by.
  if [ -z "${ARBOR_REHEARSAL:-}" ]; then
    claim "$p: the settings window, every pane"
    ctl settings-window
    check "it opens" eventually ax window "$TITLE"
    shot "$p-16-settings-on-screen"
    for pane in general windows dragging tabs gestures calls appearance menu-bar apps scripting shortcuts rules; do
      "$ARBOR_BIN/arborctl" settings-window "$pane" > /dev/null 2>&1 || continue
      ARBOR_SETTLE=0.4 look "$p-17-settings-$pane" "$(ax window "$TITLE")"
    done
    ctl settings-window close
    check "it closes" eventually not ax window "$TITLE"
  fi

  claim "$p: the answer to Check for Updates…"
  before=$(ids_on)
  ctl check-for-updates
  both "$p-18-update" "$before" 2
  check "a window answers" has_come "$before"
  key escape

  claim "$p: the line on screen"
  ctl set messages helpful
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  before=$(ids_on)
  key ctrl+opt+up
  both "$p-19-line-problem" "$before" 0.4
  check "a key that cannot act is answered on screen" has_come "$before"
  key ctrl+opt+9
  both "$p-20-line-sentence" "$before" 0.4
  key ctrl+opt+return
  both "$p-21-line-hint" "$before" 0.5

  claim "$p: paused"
  key ctrl+opt+escape
  both "$p-22-paused" "$before" 0.5
  key ctrl+opt+escape

  echo "everything Arbor said on screen in this look:"
  grep -F "said on" "$ARBOR_HOME/arbor.log" | sed 's/.*said on [^:]*: /  /'
  session_over "$p-23-after-quit"
}

# MARK: Motion

# Windows travel as stand-ins: their app's colour and icon. At the speed it ships with, a picture about every 70 ms.
motion() {
  macos_reduce_motion off
  session motion 4
  claim "motion: framing a window, and back"
  ctl dock "$W1" left
  ctl dock "$W2" right
  ctl dock "$W3" beside "$W2" bottom
  sleep 1
  ctl zoom "$W1" &
  film motion-1-frame 6
  wait $!
  sleep 0.6
  ctl show-all &
  film motion-2-everything 6
  wait $!
  sleep 0.6
  claim "motion: docking"
  ctl dock "$W4" beside "$W1" bottom &
  film motion-3-dock 6
  wait $!
  sleep 0.6
  check "nothing of the stage is left" not has_overlay 4
  session_over
  macos_reduce_motion on
}

# MARK: A large display, and a Retina one

# The hosted Mac's own display is 1024 by 768 at one pixel to the point: the menu does not fit it, and nothing fine can be judged on it.
# Plugging in a virtual display makes the main one 1920 by 1080, and the virtual one can have two pixels to the point.
large() {
  local before pair id x y w h dx dy dw dh

  session large 5
  ARBOR_DISPLAY_ARGS=--hidpi
  if ! display_add 1440 900 right; then
    session_over
    return
  fi
  read -r sx sy sw sh <<< "$(screen_of 1)"
  read -r dx dy dw dh <<< "$(screen_of 2)"
  echo "the main display's visible frame: $sx $sy $sw $sh; the Retina one's: $dx $dy $dw $dh"

  claim "large: the whole menu, and its submenus"
  ctl dock "$W5" left
  # shellcheck disable=SC2046
  click $(center_of "$W5")
  before=$(ids_on)
  # shellcheck disable=SC2046
  rightclick $(status_item)
  check "a right click opens it" eventually menu_is_open
  both large-01-menu "$before"
  for pair in "sa 02-saved-views" "do 03-dock" "ad 04-adjust" "he 05-help"; do
    menu_is_open || break
    type_text "${pair%% *}"
    key right
    both "large-${pair##* }" "$before" 0.4
    key left
    # Long enough for the menu to take the next letters for a new word.
    sleep 1.2
  done
  if menu_is_open; then
    type_text he
    key right
    type_text ab
    key return
    both large-06-about "$before" 1
  fi
  menu_is_open && key escape
  menu_is_open && key escape

  claim "retina: the line round the focused window, the surface, tiles"
  for id in "$W1" "$W2" "$W3" "$W4"; do ctl move-to-display 2 "$id"; done
  sleep 1
  ctl dock "$W1" left
  ctl dock "$W2" right
  ctl dock "$W3" beside "$W2" bottom
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  move "$((dx + dw - 40))" "$((dy + 40))"
  shot retina-01-docked
  read -r x y w h <<< "$(frame_of "$W1")"
  check "the window is on the Retina display" inside "$x $y $w $h" "$dx $dy $dw $dh"
  closeup retina-02-ring-top-left "$((x - 16))" "$((y - 16))" 200 120
  closeup retina-03-ring-bottom-right "$((x + w - 184))" "$((y + h - 104))" 200 120

  # shellcheck disable=SC2046
  drag $(titlebar_of "$W4") "$((x + w / 2))" "$((y + h - 40))" --no-release
  shot retina-04-drop-preview
  closeup retina-05-drop-preview-corner "$((x - 16))" "$((y + h / 2 - 40))" 300 160
  release
  sleep 0.5

  ctl set minimumUsableHeight 600
  ctl set tileStyle name
  move "$((dx + dw - 40))" "$((dy + 40))"
  shot retina-06-tiles
  read -r x y w h <<< "$(arbor_ask tile "$W2")"
  [ -n "${h:-}" ] && closeup retina-07-tile "$((x - 16))" "$((y - 16))" "$((w + 32))" "$((h + 32))"
  ctl reset minimumUsableHeight
  ctl reset tileStyle

  claim "retina: the panels"
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  before=$(ids_on)
  key ctrl+opt+shift+/
  both retina-08-shortcuts "$before"
  key escape
  key ctrl+opt+g
  both retina-09-go-to "$before"
  key escape
  ctl minimap
  both retina-10-minimap "$before"
  ctl minimap
  key ctrl+opt+n
  type_text writing
  both retina-11-name "$before"
  key escape
  ctl set messages helpful
  key ctrl+opt+return
  both retina-12-line-hint "$before"
  ctl show-all

  display_remove
  session_over
}

# MARK: Real apps

# Real icons, and the colours Arbor takes from them: in tiles, in Go to…, in the minimap, and while windows move.
apps() {
  local name pid pids="" before names="Safari Terminal Dictionary Calendar Notes Maps Music Reminders Calculator TextEdit"
  macos_reduce_motion off
  for name in $names; do open -g -a "$name" 2>&1 | head -n 1; done
  sleep 8
  for name in $names; do
    pid=$(pgrep -x "$name" | head -n 1)
    [ -n "$pid" ] && pids="$pids${pids:+,}$pid"
  done
  ARBOR_EXTRA_PIDS=$pids
  session "apps-$1" 1

  claim "apps-$1: arranged, and as tiles"
  ctl arrange
  sleep 1
  shot "apps-$1-01-arranged"
  # Columns pass as usable and the windows in them do not, so every window is a tile of its own.
  ctl set minimumUsableWidth 100
  ctl set minimumUsableHeight 400
  sleep 1
  shot "apps-$1-02-window-tiles"
  ctl set tileStyle name
  shot "apps-$1-03-window-tiles-with-names"
  ctl reset tileStyle
  ctl set minimumUsableWidth 2000
  sleep 1
  shot "apps-$1-04-group-tiles"
  ctl reset minimumUsableWidth
  ctl reset minimumUsableHeight
  sleep 1

  claim "apps-$1: Go to… and the minimap"
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  before=$(ids_on)
  key ctrl+opt+g
  both "apps-$1-05-go-to" "$before"
  key escape
  ctl minimap
  both "apps-$1-06-minimap" "$before"
  ctl minimap

  claim "apps-$1: motion"
  ctl zoom "$W1" &
  film "apps-$1-07-frame" 6
  wait $!
  sleep 0.6
  ctl show-all &
  film "apps-$1-08-everything" 6
  wait $!
  sleep 0.6

  session_over
  ARBOR_EXTRA_PIDS=""
  for name in $names; do pkill -x "$name"; done
  macos_reduce_motion on
  sleep 1
}

# MARK: The run

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
echo "as the Mac comes:"
macos_reduce_motion
macos_increase_contrast
macos_reduce_transparency

# A newer release to be told about.
scratch_dir gallery-feed FEED
echo '{"tag_name": "v9.9.9", "html_url": "https://example.invalid/ignored"}' > "$FEED/latest.json"
(cd "$FEED" && exec python3 -m http.server 8765 --bind 127.0.0.1 > /dev/null 2>&1) &
started $!

# A click on the wallpaper would sweep every window aside, and a pointer that misses a window by a point does click there.
macos_click_wallpaper off
macos_reduce_motion on

for part in $PARTS; do
  step "$part"
  case "$part" in
    motion) scene light; motion ;;
    large) scene light; large ;;
    apps-*) scene "${part#apps-}"; apps "${part#apps-}" ;;
    *) scene "$part"; tour "$part" ;;
  esac
done
scene light
ls -l "$ARBOR_OUT" | awk '{ print $5, $9 }'
