#!/bin/bash
# Everything Arbor draws, each thing once, in one run: a contact sheet to be LOOKED AT after any change under Sources/ArborKit/UI.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-gallery.sh scripts/mac-shell/shots-gallery-moves.sh \
#     scripts/mac-shell/shots-gallery-looks.sh scripts/mac-shell/shots-offscreen.sh
#
#   shots-gallery.sh          as it ships, with nothing set, light and dark; then the tour of everything Arbor can draw, options
#                             switched on, light and dark
#   shots-gallery-moves.sh    motion; a large display and a Retina one; real apps, light and dark
#   shots-gallery-looks.sh    the tour with Increase Contrast, light and dark, and with Reduce Transparency; the panels over the
#                             worst there is behind them
#   shots-offscreen.sh        what the macOS-only tests draw off screen, at 2x
#
# Four scripts because each has twenty minutes on a hosted Mac; one run, because they share the Mac, the checkout and the build.
#
# The other shots-*.sh follow one feature through all its states, one build and one Mac each. This one takes the same pictures in
# every look, under the same names, so that two looks, or two commits, can be laid side by side: <look>-<number>-<what>.png, and
# <…>-alone-<n>.png for each window of Arbor's own that came up for it, by itself and unscaled. Over a drawn landscape, because
# a black wallpaper hides every shadow and every dark line.
#
# What to ask of each picture: can it be read; is it aligned; does the text fit; does it look as if macOS had drawn it; is it quiet;
# does it say what a person needs, in words they know.
#
# The hosted Macs come with Reduce Transparency switched on, as with Reduce Motion, and every material then comes out as one flat
# colour. The gallery switches it off (`scene`), for the look a Mac comes with; the looks ending in -opaque have it on.
#
# Each session records a trace (docs/TRACES.md), which comes back in traces/.
#
# Only on GitHub's throwaway Macs: the looks are settings of the Mac.
ARBOR_TIME_LIMIT=1100
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "switch dark mode, the wallpaper, Increase Contrast, Reduce Transparency and Reduce Motion, and plug in a display"
# A run brings 40 MB home unless a script asks for more (scripts/ci-keep-output.py), and leaves out the largest pictures first: of the
# third run those were 292 of 709, every whole screen over the landscape among them. The three scripts of the gallery make 131 MB.
echo 160 > "$ARBOR_OUT/keep-mb.txt"

SCENERY="$ARBOR_ROOT/.build/mac-shell/scenery"
AXFIND="$ARBOR_ROOT/.build/mac-shell/axfind"
TITLE="Arbor Settings"
# What to take: looks (light, dark, each also -contrast and -opaque), and the sessions ships-<look>, motion, large, apps-<look> and
# grounds-<look>.
PARTS=${GALLERY_PARTS:-ships-light ships-dark light dark}
mkdir -p "$ARBOR_OUT/traces"

claim() { echo; echo "▸ $*"; }
not() { ! "$@"; }
ax() { "$AXFIND" "$ARBOR_PID" "$@"; }
menu_is_open() { overlays | awk '$3 == 101 && $8 == "on" { found = 1 } END { exit !found }'; }
surface_shows() { [ -n "$(overlays | awk '$3 < -1000 && $8 == "on"')" ]; }
pointer_away() { move "$((sx + sw - 40))" "$((sy + 40))"; }
type_text() {
  local index letter
  for ((index = 0; index < ${#1}; index++)); do
    letter=${1:index:1}
    [ "$letter" = " " ] && letter=space
    key "$letter" > /dev/null || return 1
  done
}

# Arbor's own windows that are on screen.
ids_on() { overlays | awk '$8 == "on" { print $1 }' | sort; }
# has_come "<ids before>": whether a window of Arbor's is on screen that was not.
has_come() { [ -n "$(comm -13 <(echo "$1") <(ids_on))" ]; }
# both <name> "<ids before>" [seconds]: the whole screen, and each window of Arbor's that has come since, alone. On a display
# so large that `shot` makes the picture smaller, also that window with what lies behind it, pixel for pixel: a picture to be
# measured is cropped, never scaled.
both() {
  local id number=1 x y w h
  shot_after "${3:-0.5}" "$1"
  for id in $(comm -13 <(echo "$2") <(ids_on)); do
    ARBOR_SETTLE=0 look "$1-alone-$number" "$id"
    if [ -n "${GALLERY_CROPS:-}" ]; then
      read -r x y w h <<< "$(overlays | awk -v id="$id" '$1 == id { print int($4), int($5), int($6), int($7) }')"
      [ -n "${h:-}" ] && ARBOR_SETTLE=0 closeup "$1-on-glass-$number" "$((x - 12))" "$((y - 12))" "$((w + 24))" "$((h + 24))"
    fi
    number=$((number + 1))
  done
}

# A newer release to be told about: one answer to one question, and gone. (Python's own web server, started as it is, brought up
# "Allow Python to find devices on local networks?" in front of everything for the rest of the job: scripts/mac-shell/serve.py says why.)
answer_about_releases() {
  local body='{"tag_name": "v9.9.9", "html_url": "https://example.invalid/ignored"}'
  [ -z "${ARBOR_REHEARSAL:-}" ] || return 0
  printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %s\r\nConnection: close\r\n\r\n%s' "${#body}" "$body" \
    | nc -l 127.0.0.1 8765 > /dev/null 2>&1 &
  started $!
  # Until it listens: asked a moment too early, Arbor says that GitHub could not be reached (two tours of five, on a hosted Mac).
  local tries=0
  until lsof -nP -iTCP:8765 -sTCP:LISTEN > /dev/null 2>&1 || [ "$tries" -ge 30 ]; do
    sleep 0.1
    tries=$((tries + 1))
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

# The line on screen is switched on for its own pictures only: it stays for seconds, over whatever is taken next. What is an option
# is said out loud, whatever ships: the tour is of everything Arbor can draw.
SETTINGS='{
  "messages": "off",
  "focusRing": true,
  "menuBarControls": true,
  "animationDuration": 0.46,
  "pointerGestures": true,
  "shortcuts": "all",
  "rules": [
    { "app": "com.example.mail", "title": "Inbox", "action": "dock left" },
    { "app": "com.example.player", "action": "float" }
  ],
  "excludedBundleIDs": ["com.example.music"]
}'

# session <name> <windows> [settings]: Arbor as a person has it, with its shortcuts, its menu bar item and a newer release to be told about.
session() {
  arbor_settings "${3:-$SETTINGS}"
  arbor_start "$2" ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0 ARBOR_PANELS_IN_PICTURES=1 \
    ARBOR_RELEASES_URL=http://127.0.0.1:8765/latest.json
  read -r sx sy sw sh <<< "$(arbor_ask screen)"
  ctl trace on "gallery-$1"
  retitle
  pointer_away
}

# Titles as people's windows have them, for Go to…, the minimap and the tiles to show, each with a word in it that must turn up
# nowhere but in the pictures (docs/VIABLE.md, `told`).
CANARY=quokkadoo
TITLES=("Train times to the coast" "Bread without kneading" "Inbox"
  "Budget for the year after next, third draft, with the figures from the meeting in March that nobody has checked yet"
  "Notes on oaks" "Untitled")
retitle() {
  local id index=0
  for id in $ARBOR_WINDOW_IDS; do
    echo "title $id $CANARY ${TITLES[index % ${#TITLES[@]}]}" >&9
    index=$((index + 1))
  done
  sleep 0.4
}

session_over() {
  local file
  ctl trace off
  for file in "$ARBOR_HOME"/traces/*.jsonl; do
    [ -f "$file" ] && cp "$file" "$ARBOR_OUT/traces/${file##*/}"
  done
  arbor_stop "${1:-}"
}

# As a person has it: in a bundle, which is where Arbor's icon, its version and "Open at Login" come from. Still started as every Mac
# shell script starts it, as a child of the script, which is what lets it move windows here. If any of this fails the plain
# binary does, with a blank icon and no version.
in_a_bundle() {
  local app
  scratch_dir gallery-app APP_DIR
  app="$APP_DIR/Arbor.app"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" || return 1
  cp "$ARBOR_BIN/Arbor" "$app/Contents/MacOS/Arbor" || return 1
  # Links: run from inside the bundle they would take its icon and its name for their own.
  ln -s "$ARBOR_BIN/arborctl" "$ARBOR_BIN/ArborTestWindows" "$app/Contents/MacOS/" || return 1
  cp Resources/Info.plist "$app/Contents/Info.plist" || return 1
  limit 60 swift scripts/make-icon.swift "$APP_DIR/Arbor.iconset" > /dev/null \
    && iconutil -c icns "$APP_DIR/Arbor.iconset" -o "$app/Contents/Resources/Arbor.icns"
  # An identifier of its own and no claim on arbor:// URLs; a version to be older than the release it is told about; and leave to
  # ask this Mac over plain http.
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.evbarleyg.arbor.gallery" -c "Delete :CFBundleURLTypes" \
    -c "Set :CFBundleShortVersionString 0.9.0" -c "Add :NSAppTransportSecurity dict" \
    -c "Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true" "$app/Contents/Info.plist" || return 1
  case "$(limit 10 "$app/Contents/MacOS/Arbor" --version 2>&1)" in
    "Arbor 0.9.0"*) ARBOR_BIN="$app/Contents/MacOS"; echo "Arbor runs from a bundle: $("$ARBOR_BIN/Arbor" --version)" ;;
    *) echo "the bundle does not answer as Arbor 0.9.0"; return 1 ;;
  esac
}

# MARK: As it ships

# What a newcomer sees who has changed nothing: no setting is set, so whatever is an option and ships off is not in these
# pictures, and whatever is in them was drawn unasked or in answer to something done. Scored by itself. Windows are arranged by
# commands, since which keys ship is being decided; what a key or a hand brings up is brought up by a key or a hand.
ships() {
  local p="ships-$1" x y w h before

  session "$p" 5 '{}'

  claim "before anything is docked  ($p)"
  shot "$p-01-nothing-docked"
  closeup "$p-01b-the-menu-bar" "$((sx + sw - 420))" 0 420 "$sy"

  claim "a key that can do nothing is answered  ($p)"
  before=$(ids_on)
  key ctrl+opt+z
  both "$p-01c-the-line" "$before" 0.3
  check "on screen" test -f "$ARBOR_OUT/$p-01c-the-line-alone-1.png"
  sleep 3

  claim "two windows docked  ($p)"
  ctl dock "$W1" left
  ctl dock "$W2" right
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  pointer_away
  shot "$p-02-two-docked"

  claim "a third, and a fourth  ($p)"
  ctl dock "$W3" right
  shot "$p-03-three-docked"
  ctl dock "$W4" right
  shot "$p-04-four-docked"

  claim "one fills the screen, and back  ($p)"
  ctl zoom "$W1"
  shot "$p-05-one-fills-the-screen"
  ctl show-all
  shot "$p-06-everything-again"

  claim "a plain drag of a floating window over a docked one  ($p)"
  read -r x y w h <<< "$(frame_of "$W1")"
  # shellcheck disable=SC2046
  drag $(titlebar_of "$W5") "$((x + w / 2))" "$((y + h - 60))" --no-release
  shot "$p-07-a-plain-drag"
  release
  shot "$p-08-let-go"

  claim "the same with ⌘ held  ($p)"
  is docked "$W5" && ctl float "$W5"
  # shellcheck disable=SC2046
  drag $(titlebar_of "$W5") "$((x + w / 2))" "$((y + h - 60))" --mods cmd --no-release
  shot "$p-09-a-drag-with-command"
  release --mods cmd
  shot "$p-10-let-go"

  claim "the pointer over a gap  ($p)"
  read -r x y <<< "$(seam_right_of "$W1")"
  move "$x" "$((y - 70))"
  shot "$p-11-over-a-gap"
  pointer_away

  claim "Go to…  ($p)"
  before=$(ids_on)
  key ctrl+opt+g
  both "$p-12-go-to" "$before"
  key escape

  claim "the menu  ($p)"
  before=$(ids_on)
  # shellcheck disable=SC2046
  rightclick $(status_item)
  both "$p-13-menu" "$before"
  menu_is_open && key escape

  claim "paused, and resumed  ($p)"
  before=$(ids_on)
  key ctrl+opt+escape
  both "$p-15-paused" "$before" 0.5
  before=$(ids_on)
  # shellcheck disable=SC2046
  rightclick $(status_item)
  both "$p-15b-paused-menu" "$before"
  menu_is_open && key escape
  key ctrl+opt+escape
  shot_after 1 "$p-16-resumed"

  claim "the two windows of the first run  ($p)"
  before=$(ids_on)
  ctl check-setup
  both "$p-17-check-setup" "$before" 1
  before=$(ids_on)
  ctl welcome
  both "$p-18-welcome" "$before" 1

  session_over "$p-19-after-quit"
}

# MARK: One look

tour() {
  local p=$1 x y w h gx gy before pane

  session "$p" 6

  claim "the menu bar item, and nothing else, before anything is docked  ($p)"
  shot "$p-01-nothing-docked"
  check "the menu bar item shows" status_item
  check "no surface behind the windows yet" not surface_shows

  claim "the surface behind docked windows, and the line round the focused one  ($p)"
  ctl dock "$W1" left
  ctl dock "$W2" right
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  pointer_away
  shot "$p-02-two-columns"
  check "the surface is on screen" eventually surface_shows

  claim "the drop preview  ($p)"
  read -r x y w h <<< "$(frame_of "$W1")"
  # The last window is in front of the other floating ones, so its title bar is free.
  # shellcheck disable=SC2046
  drag $(titlebar_of "$W6") "$((x + w / 2))" "$((y + h - 40))" --no-release
  shot "$p-03-drop-preview"
  check "it shows while the button is held" has_overlay 3
  release
  check "the window docked where it showed" eventually is docked "$W6"
  is docked "$W6" || ctl dock "$W6" beside "$W1" bottom

  claim "tiles: a window's, a group's, the Desktop's  ($p)"
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
  ctl set tileStyle icon
  shot "$p-05-tiles-icons-alone"
  ctl reset tileStyle
  # The pointer rests on a tile: its help tag has the caption, drawn or not.
  # shellcheck disable=SC2046
  move $(tile_of "$W6")
  shot_after 2.5 "$p-05b-tile-help-tag"
  # A hold begins with the tag up: the title goes from the tile, and the tag with it.
  ctl hold
  shot "$p-05c-tiles-held"
  ctl release
  pointer_away

  claim "the handle in a gap  ($p)"
  read -r gx gy <<< "$(seam_below "$W1")"
  # Beside the handle, which sits in the middle of the gap: the pointer would cover it.
  move "$((gx - 70))" "$gy"
  shot "$p-06-gap-hover"
  drag "$((gx - 70))" "$gy" "$((gx - 70))" "$((gy + 20))" --no-release
  shot "$p-06b-gap-dragged"
  release
  pointer_away

  claim "what the settings make of tiles and of the surface  ($p)"
  ctl set tileStyle plain
  shot "$p-06c-tiles-plain"
  ctl reset tileStyle
  ctl set appColours false
  shot "$p-06d-tiles-grey"
  ctl reset appColours
  ctl set appColourAmount 1
  shot "$p-06e-tiles-full-colour"
  ctl reset appColourAmount
  ctl set dimBehindArranged 0
  shot "$p-06f-no-surface"
  ctl reset dimBehindArranged
  ctl set tintBehindArranged 0.2
  shot "$p-06g-surface-tinted"
  ctl reset tintBehindArranged
  ctl set blurBehindArranged 1
  shot "$p-06h-surface-blurred"
  ctl reset blurBehindArranged
  ctl set desktopEdge 0.3
  shot "$p-06i-desktop-edge-plain-to-see"
  ctl reset desktopEdge

  claim "the rectangle of a ⌃⌥-drag  ($p)"
  read -r x y w h <<< "$(frame_of "$W2")"
  drag "$((x + 30))" "$((y + 60))" "$((x + w - 30))" "$((y + h - 40))" --mods ctrl+opt --no-release
  shot "$p-06j-rectangle"
  check "it shows while the button is held" has_overlay 3
  release --mods ctrl+opt
  sleep 0.6
  shot "$p-06k-framed"
  ctl show-all

  claim "the panel of shortcuts  ($p)"
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  before=$(ids_on)
  key ctrl+opt+shift+/
  both "$p-07-shortcuts" "$before"
  check "it is up" has_come "$before"
  key escape
  check "⎋ puts it away" eventually not has_come "$before"

  claim "Go to…  ($p)"
  before=$(ids_on)
  key ctrl+opt+g
  both "$p-08-go-to" "$before"
  check "it is up" has_come "$before"
  type_text bre
  both "$p-09-go-to-typed" "$before"
  type_text zz
  both "$p-10-go-to-nothing-matches" "$before"
  key escape
  check "⎋ puts it away" eventually not has_come "$before"

  claim "the minimap  ($p)"
  ctl zoom "$W1"
  before=$(ids_on)
  ctl minimap
  both "$p-11-minimap" "$before"
  check "it is up" has_come "$before"
  ctl minimap

  claim "the field for a name  ($p)"
  before=$(ids_on)
  key ctrl+opt+n
  both "$p-12-name-empty" "$before"
  check "it is up" has_come "$before"
  type_text writing
  both "$p-13-name-typed" "$before"
  type_text " and everything else that has to be done before the end of the month"
  both "$p-13b-name-long" "$before"
  key escape

  claim "peek's outline  ($p)"
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

  claim "the menu  ($p)"
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
    claim "the settings window, every pane  ($p)"
    ctl settings-window
    check "it opens" eventually ax window "$TITLE"
    shot "$p-16-settings-on-screen"
    for pane in general windows dragging tabs gestures calls appearance menu-bar apps scripting shortcuts rules; do
      "$ARBOR_BIN/arborctl" settings-window "$pane" > /dev/null 2>&1 || continue
      ARBOR_SETTLE=0.4 look "$p-17-settings-$pane" "$(ax window "$TITLE")"
      # What is behind Advanced. The element is the triangle with its word; the triangle is 25 points into it.
      read -r x y w h <<< "$(ax frame AXDisclosureTriangle Advanced 2> /dev/null)"
      [ -n "${h:-}" ] || continue
      click "$((x + 25))" "$((y + h / 2))"
      ARBOR_SETTLE=0.4 look "$p-17-settings-$pane-advanced" "$(ax window "$TITLE")"
    done
    ctl settings-window close
    check "it closes" eventually not ax window "$TITLE"
  fi

  claim "the answer to Check for Updates…  ($p)"
  before=$(ids_on)
  answer_about_releases
  ctl check-for-updates
  both "$p-18-update" "$before" 2
  check "a window answers" has_come "$before"
  # By its button: ⎋ reaches it only if macOS let Arbor, asked from a terminal, have the keyboard.
  if [ -z "${ARBOR_REHEARSAL:-}" ]; then
    # shellcheck disable=SC2046
    click $(ax point AXButton Later || ax point AXButton OK)
    check "its button puts it away" eventually not has_come "$before"
  fi

  claim "the line on screen  ($p)"
  ctl set messages helpful
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  before=$(ids_on)
  key ctrl+opt+up
  both "$p-19-line-problem" "$before" 0.4
  check "a key that cannot act is answered on screen" test -f "$ARBOR_OUT/$p-19-line-problem-alone-1.png"
  key ctrl+opt+9
  both "$p-20-line-sentence" "$before" 0.4
  key ctrl+opt+return
  both "$p-21-line-hint" "$before" 0.5

  claim "paused  ($p)"
  key ctrl+opt+escape
  both "$p-22-paused" "$before" 0.5
  before=$(ids_on)
  # shellcheck disable=SC2046
  rightclick $(status_item)
  both "$p-22b-paused-menu" "$before"
  menu_is_open && key escape
  key ctrl+opt+escape

  if [ "$p" = light ]; then
    claim "for comparison: how macOS writes the arrow keys in a menu of its own"
    click 260 14
    shot "$p-24-finders-go-menu"
    key escape
  fi

  echo "everything Arbor said on screen in this look:"
  grep -F "said on" "$ARBOR_HOME/arbor.log" | sed 's/.*said on [^:]*: /  /'
  session_over "$p-23-after-quit"
}

# MARK: The worst there is behind a panel

# grounds <look>: every panel that holds words over a saturated red, a saturated blue, white and black, to be measured: words a
# person must read to act at least 4.5 to 1, all others at least 3 (docs/POLISH.md). The Desktop is in view, so the wallpaper
# is all there is behind them.
grounds() {
  local ground hex before
  session "grounds-$1" 2
  ctl dock "$W1" left
  ctl dock "$W2" right
  # The field for a name is 380 points wide and stands over the middle: the Desktop's column has to be wider than that.
  ctl resize "$W1" right -80
  ctl resize "$W2" left -80
  ctl set messages helpful
  for ground in red:ff383c blue:0088ff white:ffffff black:000000; do
    hex=${ground#*:}
    ground=${ground%:*}
    claim "over $ground  ($1)"
    wallpaper "#$hex"
    ctl desktop
    sleep 1
    pointer_away
    before=$(ids_on)
    # By command where a command will do: which keys ship is being decided.
    ctl show-shortcuts
    shot "$1-on-$ground-1-shortcuts"
    check "the panel of shortcuts is up" has_come "$before"
    key escape
    ctl find
    shot "$1-on-$ground-2-go-to"
    type_text bre
    shot "$1-on-$ground-3-go-to-typed"
    key cmd+return
    key down
    key cmd+return
    shot "$1-on-$ground-3b-go-to-ticked"
    type_text zzzz
    shot "$1-on-$ground-3c-go-to-nothing-matches"
    for _ in 1 2 3 4; do key delete; done
    type_text bal
    shot "$1-on-$ground-3d-go-to-commands"
    key escape
    ctl minimap
    shot "$1-on-$ground-4-minimap"
    ctl minimap
    ctl show-all
    ctl ask-name
    shot "$1-on-$ground-5-name"
    type_text writing
    shot "$1-on-$ground-5b-name-typed"
    type_text " and everything else that has to be done by then"
    shot "$1-on-$ground-5c-name-problem"
    key escape
    # A problem's words; then a sentence, the dot, and a hint with keys in it (said three times and not a fourth).
    key ctrl+opt+up
    shot_after 0.4 "$1-on-$ground-6-line-problem"
    sleep 2
    # shellcheck disable=SC2046
    click $(center_of "$W1")
    pointer_away
    key ctrl+opt+return
    ctl desktop
    shot_after 0.2 "$1-on-$ground-6b-line-hint"
    sleep 2
  done
  session_over
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
  GALLERY_CROPS=yes
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
  drag $(titlebar_of "$W4") "$((x + w / 2))" "$((y + h * 3 / 4))" --steps 90 --no-release
  shot retina-04-drop-preview
  check "it shows while the button is held" has_overlay 3
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

  claim "retina: the handle in a gap, peek's outline, the menu"
  read -r x y <<< "$(seam_right_of "$W1")"
  move "$x" "$((y - 70))"
  closeup retina-13-handle-hovered "$((x - 60))" "$((y - 60))" 120 120
  drag "$x" "$((y - 70))" "$((x + 20))" "$((y - 70))" --no-release
  closeup retina-14-handle-dragged "$((x - 40))" "$((y - 60))" 120 120
  release
  ctl zoom "$W1"
  key ctrl+opt+space --down
  sleep 0.9
  read -r x y w h <<< "$(frame_of "$W1")"
  move "$((x + w / 2))" "$((y + h / 2))"
  closeup retina-15-peek-top-left "$((x - 20))" "$((y - 20))" 220 140
  key ctrl+opt+space --up
  ctl show-all

  display_remove
  # Arbor hears of a display that went a second and a half after macOS's last word on it, and a quit before that puts windows
  # back on the display that is gone (seen in this script's first run; known).
  sleep 3
  GALLERY_CROPS=
  session_over large-99-after-quit
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

  claim "real apps: arranged, and as tiles  ($1)"
  ctl arrange
  sleep 1
  shot "apps-$1-01-arranged"
  # Columns pass as usable and the windows in them do not, so every window is a tile of its own.
  ctl set minimumUsableWidth 100
  ctl set minimumUsableHeight 400
  sleep 1
  shot "apps-$1-02-window-tiles"
  ctl set tileStyle icon
  shot "apps-$1-03-window-tiles-icons-alone"
  ctl reset tileStyle
  ctl set minimumUsableWidth 2000
  sleep 1
  shot "apps-$1-04-group-tiles"
  ctl reset minimumUsableWidth
  ctl reset minimumUsableHeight
  sleep 1

  claim "real apps: Go to… and the minimap  ($1)"
  # shellcheck disable=SC2046
  click $(center_of "$W1")
  before=$(ids_on)
  key ctrl+opt+g
  both "apps-$1-05-go-to" "$before"
  key escape
  ctl minimap
  both "apps-$1-06-minimap" "$before"
  ctl minimap

  claim "real apps: motion  ($1)"
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
[ -n "${ARBOR_REHEARSAL:-}" ] || in_a_bundle || echo "no bundle: Arbor runs as a plain binary"
echo "as the Mac comes:"
macos_reduce_motion
macos_increase_contrast
macos_reduce_transparency

# A click on the wallpaper would sweep every window aside, and a pointer that misses a window by a point does click there.
macos_click_wallpaper off
macos_reduce_motion on

for part in $PARTS; do
  step "$part ($(($(date +%s) - ARBOR_RUN_STARTED)) s into the run)"
  case "$part" in
    motion) scene light; motion ;;
    large)
      # The fake Mac has one display, and display_add ends a script that has no tool for a second.
      if [ -n "${ARBOR_REHEARSAL:-}" ]; then echo "large: cannot be rehearsed"; continue; fi
      scene light
      large
      ;;
    apps-*) scene "${part#apps-}"; apps "${part#apps-}" ;;
    grounds-*) scene "${part#grounds-}"; grounds "${part#grounds-}" ;;
    ships-*) scene "${part#ships-}"; ships "${part#ships-}" ;;
    *) scene "$part"; tour "$part" ;;
  esac
done
scene light

claim "a title is drawn and nothing else"
told=$(grep -rIl "$CANARY" "$ARBOR_OUT" 2> /dev/null | sed "s|$ARBOR_OUT/||" | tr '\n' ' ')
check "the word in every title is in nothing the run brings back but the pictures${told:+: $told}" test -z "$told"
ls -l "$ARBOR_OUT" | awk '{ print $5, $9 }'
