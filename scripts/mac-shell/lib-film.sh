# Films for Mac shell scripts: lib.sh's sessions, with every frame the display showed kept while a scene plays.
# Source it instead of lib.sh (it sources that first); do not run it. films.sh is the long example.
#
#   #!/bin/bash
#   source "$(dirname "$0")/lib-film.sh"
#   film_build;  camera_start
#   arbor_start 4 ARBOR_NO_HOTKEYS=0
#   scene zoom-in camera "presses ⌃⌥↩ on a docked window";  key ctrl+opt+return;  scene_end
#   arbor_stop;  camera_stop
#
# A picture says what Arbor looks like at rest. Half of how it feels is what happens in the half second between two
# pictures, and nobody is there to watch it. So camera.swift keeps every frame, with the moment the display showed it and the moment
# the key or the button went down, and scripts/polish/judge.py measures the films afterwards, anywhere, against
# docs/POLISH.md: how long, how eased, how many motions, what flickered, flashed or hopped. What cannot be measured is looked at,
# frame by frame, on the sheets the judge lays out.
#
# A scene is ONE thing a person does, done as a person does it: with real keys and a real pointer, not with the command behind them.
# A film shows the whole display, so all of this is for GitHub's Macs only.
#
#   film_build                      arbor_build, and compile camera.swift, witness.swift (for pinches) and apptool.swift (for display_size)
#   camera_start | camera_stop      start the camera (fails, and says why, where it gets no frames) | stop it
#   display_size <w> <h>            switch the display to that size, if it offers it, with the camera stopped meanwhile
#   scene <name> <kind> "<what the person does>"      a film begins: mac-shell/films/<name>/. The kind tells the judge which checks
#                                     apply (docs/POLISH.md): camera, structure, drag, hold, instant, panel, control
#   note <text…>                    a mark in the film's log
#   hold_drag x1 y1 x2 y2 [options] a drag that waits before it lets go, and notes which panels of Arbor's are up meanwhile
#   scene_end [seconds]             let things come to rest for that long (2.5), then end the film
#   cast_build                      make four small apps of ArborTestWindows, each with a name and an icon of its own
#   cast_start [count] [NAME=v…]    arbor_start, with every test window another app's, as a person's windows are: W1…Wcount (4; eight are two to an app)
#   cast_stop [name]                arbor_stop, and the cast goes home
#   tell <n> <command…>             a command for the app of the nth window (Sources/ArborTestWindows/Commands.swift)
#   metronome <kind>                a scene of its own: the camera's square, moving in a way that is known (camera.swift)
#   pinch x y <amount> [options]    a pinch at that place (witness.swift)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
needs_throwaway_mac "film the whole display, with whatever is on it"

FILM_CAMERA="$ARBOR_ROOT/.build/mac-shell/camera"
FILM_WITNESS="$ARBOR_ROOT/.build/mac-shell/witness"
FILM_APPTOOL="$ARBOR_ROOT/.build/mac-shell/apptool"
# A rehearsal has no display to film: the stand-in keeps the log and takes no pictures.
[ -n "${ARBOR_REHEARSAL:-}" ] && FILM_CAMERA="$ARBOR_ROOT/scripts/mac-shell/rehearse/camera"
FILM_CAMERA_PID=""
# What arbor_start opens where there is no cast.
FILM_TEST_WINDOWS=$ARBOR_TEST_WINDOWS
FILM_SCENE=""
FILM_COUNT=0
FILM_CAMERAS=0
FILM_CAMERA_ARGS=""

film_build() {
  local camera witness apptool
  if [ -n "${ARBOR_REHEARSAL:-}" ]; then
    arbor_build
    return 0
  fi
  mkdir -p "$(dirname "$FILM_CAMERA")"
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/camera.swift" -o "$FILM_CAMERA" > "$ARBOR_OUT/build-camera.log" 2>&1 &
  camera=$!
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/witness.swift" -o "$FILM_WITNESS" > "$ARBOR_OUT/build-witness.log" 2>&1 &
  witness=$!
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/apptool.swift" -o "$FILM_APPTOOL" > "$ARBOR_OUT/build-apptool.log" 2>&1 &
  apptool=$!
  arbor_build
  if ! wait "$camera"; then
    grep -A 6 "error:" "$ARBOR_OUT/build-camera.log" | head -n 80
    die "scripts/mac-shell/camera.swift did not compile"
  fi
  # Costs the scenes with a pinch, not the others.
  wait "$witness" || { echo "scripts/mac-shell/witness.swift did not compile: no pinches"; FILM_WITNESS=""; }
  wait "$apptool" || { echo "scripts/mac-shell/apptool.swift did not compile: the display keeps its size"; FILM_APPTOOL=""; }
}

# Descriptor 4 is the script's end of the camera's stdin.
camera_start() {
  local log
  [ -z "$FILM_CAMERA_PID" ] || return 0
  [ $# -eq 0 ] || FILM_CAMERA_ARGS=$*
  FILM_CAMERAS=$((FILM_CAMERAS + 1))
  log="$ARBOR_OUT/camera-$FILM_CAMERAS.log"
  scratch_dir film FILM_TEMP
  mkfifo "$FILM_TEMP/commands" || die "camera_start: no fifo in $FILM_TEMP"
  mkdir -p "$ARBOR_OUT/films"
  # shellcheck disable=SC2086
  "$FILM_CAMERA" $FILM_CAMERA_ARGS < "$FILM_TEMP/commands" > "$log" 2>&1 7>&- 8>&- 9>&- &
  FILM_CAMERA_PID=$!
  started "$FILM_CAMERA_PID"
  exec 4> "$FILM_TEMP/commands"
  film_await 150 grep -q -E "^camera-(ready|failed)" "$log"
  cat "$log"
  grep -q "^camera-ready" "$log" && return 0
  camera_gone
  return 1
}

# Nobody reads the other end any more: whoever wrote there would be ended by the signal.
camera_gone() {
  exec 4>&-
  [ -z "$FILM_CAMERA_PID" ] || kill_started "$FILM_CAMERA_PID"
  FILM_CAMERA_PID=""
  FILM_SCENE=""
}

# Whether the camera is still there. It ends itself when its stream stops.
camera_rolls() {
  [ -n "$FILM_CAMERA_PID" ] || return 1
  kill -0 "$FILM_CAMERA_PID" 2>/dev/null && return 0
  echo "the camera is gone: $(tail -n 1 "$ARBOR_OUT/camera-$FILM_CAMERAS.log")"
  camera_gone
  return 1
}

camera_stop() {
  [ -n "$FILM_CAMERA_PID" ] || return 0
  echo stop >&4
  exec 4>&-
  ended "$FILM_CAMERA_PID" 30 || kill_started "$FILM_CAMERA_PID"
  FILM_CAMERA_PID=""
  echo "films: $FILM_COUNT, $(du -sk "$ARBOR_OUT/films" | cut -f 1) KB"
}

# The camera is told the display's size when it starts.
display_size() {
  [ -n "${ARBOR_REHEARSAL:-}" ] && { echo "> display_size $* (not rehearsed)"; return 0; }
  [ -n "$FILM_APPTOOL" ] || return 1
  camera_stop
  "$FILM_APPTOOL" set-mode "$1" "$2" || echo "the display does not offer $1 x $2"
  sleep 2
  pointer displays
  camera_start || { echo "display_size: the camera did not come back"; return 1; }
}

# film_await <tenths of a second> <command…>
film_await() {
  local tries=$1
  shift
  while [ "$tries" -gt 0 ]; do
    "$@" && return 0
    sleep 0.1
    tries=$((tries - 1))
  done
  return 1
}

note() { [ -n "$FILM_CAMERA_PID" ] && echo "mark $*" >&4; }
# A camera that dies between the look and the line must not take the script with it.
trap '' PIPE

# Where Arbor believes every window is, for the judge to hold against what the display showed. Ids, never titles.
film_windows() {
  [ -n "$ARBOR_PID" ] || return 0
  "$ARBOR_BIN/arborctl" state 2>/dev/null | python3 -c '
import json, sys
try:
    state = json.load(sys.stdin)["state"]
except (ValueError, KeyError):
    sys.exit(0)
for window in state["windows"]:
    (x, y), (w, h) = window["frame"]
    how = "parked" if window.get("parked") else "docked" if window.get("docked") else "floating"
    print(sys.argv[1], window["id"], round(x, 2), round(y, 2), round(w, 2), round(h, 2), how)
' "$1" | while read -r line; do note "$line"; done
}

# Arbor's own windows that are on screen, as the window server sees them: level x y w h.
film_overlays() {
  [ -n "$ARBOR_PID" ] || return 0
  overlays | awk -v when="$1" '$8 == "on" { print "overlay", when, $3, $4, $5, $6, $7 }' | while read -r line; do note "$line"; done
}

hold_drag() {
  drag "$@" --no-release
  sleep 0.5
  film_overlays held
  sleep 0.3
  release
}

scene() {
  local name=$1 kind=$2
  shift 2
  camera_rolls || { echo "scene $name: no camera"; return 1; }
  [ -z "$FILM_SCENE" ] || scene_end 0
  step "scene $name: $*"
  FILM_SCENE=$name
  mkdir -p "$ARBOR_OUT/films/$name"
  echo "begin $ARBOR_OUT/films/$name" >&4
  film_await 40 test -f "$ARBOR_OUT/films/$name/rolling" || { echo "scene $name: the camera does not roll"; FILM_SCENE=""; return 1; }
  note "scene $name"
  note "kind $kind"
  note "text $*"
  film_windows before
  # Seen at rest first: what the first frame of a motion differs from.
  sleep 0.4
  note "action"
}

scene_end() {
  local name=$FILM_SCENE
  [ -n "$name" ] || return 0
  sleep "${1:-2.5}"
  camera_rolls || return 1
  film_windows after
  film_overlays after
  echo end >&4
  FILM_SCENE=""
  if film_await 200 test -f "$ARBOR_OUT/films/$name/done"; then
    FILM_COUNT=$((FILM_COUNT + 1))
    rm -f "$ARBOR_OUT/films/$name/rolling" "$ARBOR_OUT/films/$name/done"
    echo "film: mac-shell/films/$name/: $(tail -n 1 "$ARBOR_OUT/films/$name/film.log" | cut -d ' ' -f 3-)"
    ! grep " L " "$ARBOR_OUT/films/$name/film.log" || echo "film $name: THE CAMERA RAN OUT OF ROOM: its end is missing"
  else
    echo "film $name: the camera did not finish it"
    return 1
  fi
}

metronome() {
  scene "metronome-$1" control "the camera's own square: $1" || return 1
  echo "metronome $1" >&4
  scene_end 2.4
}

pinch() {
  [ -n "${ARBOR_REHEARSAL:-}" ] && { echo "> pinch $* (not rehearsed)"; return 0; }
  [ -n "$FILM_WITNESS" ] || { echo "> pinch $*: skipped, no witness"; return 1; }
  echo "> pinch $*"
  "$FILM_WITNESS" pinch "$@"
}

# MARK: The cast

# While Arbor moves a window it shows a card in the colour of the app's icon, with the icon on it. Test windows of one app all turn
# into the same card, which is harder on the eye than a person's own desk, and leaves the judge's ruler no way to tell them apart where
# they overlap. So each window gets an app of its own: a copy of ArborTestWindows in a bundle with a name and an icon, the
# icon in the colour of the window, which here stands for knowing one's apps.
FILM_CAST=""
FILM_CAST_PIDS=""
FILM_CAST_NAMES="Oak Elm Ash Fir"
FILM_CAST_COLOURS="214,58,62 20,120,230 44,170,80 232,128,36"

cast_name() { echo "$FILM_CAST_NAMES" | cut -d ' ' -f "$1"; }

cast_build() {
  local n name app
  [ -z "${ARBOR_REHEARSAL:-}" ] || return 0
  scratch_dir cast FILM_CAST
  for n in 1 2 3 4; do
    name=$(cast_name "$n")
    app="$FILM_CAST/$name.app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    cp "$ARBOR_BIN/ArborTestWindows" "$app/Contents/MacOS/$name"
    # A rounded square with as many white bars as the window's number.
    python3 - "$FILM_CAST/$name.png" "$(echo "$FILM_CAST_COLOURS" | cut -d ' ' -f "$n")" "$n" << 'PYTHON'
import struct, sys, zlib
path, colour, bars = sys.argv[1], tuple(int(word) for word in sys.argv[2].split(",")), int(sys.argv[3])
side, margin, radius = 512, 50, 110
rows = []
for y in range(side):
    row = bytearray([0])
    for x in range(side):
        dx = max(margin + radius - x, x - (side - margin - radius - 1), 0)
        dy = max(margin + radius - y, y - (side - margin - radius - 1), 0)
        inside = margin <= x < side - margin and margin <= y < side - margin and dx * dx + dy * dy <= radius * radius
        bar = 170 <= y < 342 and any(abs(x - (256 + (2 * index - bars + 1) * 34)) < 16 for index in range(bars))
        row += bytes((255, 255, 255, 255) if inside and bar else colour + (255,) if inside else (0, 0, 0, 0))
    rows.append(bytes(row))
def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
with open(path, "wb") as file:
    file.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", side, side, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(b"".join(rows))) + chunk(b"IEND", b""))
PYTHON
    sips -s format icns "$FILM_CAST/$name.png" --out "$app/Contents/Resources/icon.icns" > /dev/null 2>> "$ARBOR_OUT/cast.log"
    cat > "$app/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>$name</string>
  <key>CFBundleIdentifier</key><string>dev.arbor.cast.$name</string>
  <key>CFBundleName</key><string>$name</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>icon</string>
</dict></plist>
PLIST
    [ -s "$app/Contents/Resources/icon.icns" ] || { echo "cast_build: no icon for $name: one app for all windows"; FILM_CAST=""; return 1; }
  done
  echo "the cast: $FILM_CAST_NAMES"
}

cast_start() {
  local count=4 per apps a n first name pid pids="" id ids
  case "${1:-}" in "" | *[!0-9]*) ;; *) count=$1; shift ;; esac
  if [ -z "$FILM_CAST" ]; then
    arbor_start "$count" "$@"
    return
  fi
  # Up to four windows, an app each; more are dealt out evenly among four apps.
  per=$(((count + 3) / 4))
  apps=$((count / per))
  [ $((apps * per)) -eq "$count" ] || die "cast_start: $count windows cannot be dealt out evenly among four apps"
  # The last app is arbor_start's own, so that it opens last and lies in front, as the last window of one app does.
  a=1
  while [ "$a" -lt "$apps" ]; do
    name=$(cast_name "$a")
    rm -f "$FILM_CAST/in-$a" "$FILM_CAST/hello-$a"
    mkfifo "$FILM_CAST/in-$a" || die "cast_start: no fifo in $FILM_CAST"
    # shellcheck disable=SC2086
    "$FILM_CAST/$name.app/Contents/MacOS/$name" --count "$per" --first $(((a - 1) * per + 1)) ${ARBOR_TEST_WINDOWS_ARGS:-} \
      < "$FILM_CAST/in-$a" > "$FILM_CAST/hello-$a" 2>> "$ARBOR_OUT/test-windows.log" 4>&- 7>&- 8>&- 9>&- &
    pid=$!
    started "$pid"
    pids="$pids $pid"
    # The app lives until nobody holds the other end of its stdin. This does, so that `tell` can come and go.
    sleep 100000 > "$FILM_CAST/in-$a" 4>&- 7>&- 8>&- 9>&- &
    started $!
    FILM_CAST_PIDS="$FILM_CAST_PIDS $pid $!"
    a=$((a + 1))
  done
  ids=""
  a=1
  for pid in $pids; do
    film_await 100 test -s "$FILM_CAST/hello-$a" || die "the cast's $(cast_name "$a") did not report its windows"
    ids="$ids $(python3 -c 'import json, sys; print(*json.loads(sys.argv[1])["windows"])' "$(head -n 1 "$FILM_CAST/hello-$a")")"
    a=$((a + 1))
  done
  name=$(cast_name "$apps")
  # shellcheck disable=SC2086
  ARBOR_EXTRA_PIDS=$(echo $pids | tr ' ' ',')
  ARBOR_TEST_WINDOWS="$FILM_CAST/$name.app/Contents/MacOS/$name"
  ARBOR_TEST_WINDOWS_ARGS="${ARBOR_TEST_WINDOWS_ARGS:-} --first $((count - per + 1))" arbor_start "$per" "$@"
  ARBOR_WINDOW_IDS="$ids $ARBOR_WINDOW_IDS"
  n=0
  for id in $ARBOR_WINDOW_IDS; do
    n=$((n + 1))
    eval "W$n=$id"
  done
  [ "$n" -eq "$count" ] || die "cast_start: $n windows for $count"
  FILM_CAST_COUNT=$count
  FILM_CAST_PER=$per
  film_await 50 cast_is_managed "$count" || echo "cast_start: Arbor does not manage all $count windows"
  # Apps that start side by side pile their windows up as it comes. In the order of their numbers, the last in front and its app
  # active, as the windows of one app lie.
  n=1
  while [ "$n" -le "$count" ]; do
    eval "tell $n \"front \$W$n\""
    sleep 0.2
    n=$((n + 1))
  done
  tell "$count" activate
  sleep 0.5
  echo "the cast's windows:$ARBOR_WINDOW_IDS"
}

cast_is_managed() { "$ARBOR_BIN/arborctl" state 2>/dev/null | python3 "$ARBOR_STATE_PY" ready "$1" 2>/dev/null; }

cast_stop() {
  arbor_stop "$@"
  # shellcheck disable=SC2086
  [ -z "$FILM_CAST_PIDS" ] || kill_started $FILM_CAST_PIDS
  FILM_CAST_PIDS=""
  ARBOR_EXTRA_PIDS=""
  ARBOR_TEST_WINDOWS=$FILM_TEST_WINDOWS
}

tell() {
  local n=$1
  shift
  # The app the nth window belongs to; the last app's stdin is the one arbor_start holds.
  if [ -z "$FILM_CAST" ] || [ "$n" -gt $((${FILM_CAST_COUNT:-4} - ${FILM_CAST_PER:-1})) ]; then
    echo "$*" >&9
  else
    echo "$*" > "$FILM_CAST/in-$(((n + ${FILM_CAST_PER:-1} - 1) / ${FILM_CAST_PER:-1}))"
  fi
}
