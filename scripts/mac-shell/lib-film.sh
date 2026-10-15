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
#   film_build                      arbor_build, and compile camera.swift, witness.swift (for pinches), apptool.swift (for display_size), sampler.swift
#   camera_start | camera_stop      start the camera (fails, and says why, where it gets no frames) | stop it
#   sampler_start | sampler_stop    beside the films, where the window server has every window, sixty times a second: mac-shell/samples.log
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
#   trace_ends                      end the session's trace now and keep it (cast_stop does; a scene that quits Arbor has to, before)
#   second_build                    LIGHT = the second build's switches that the commit under test does not ship yet, as JSON; says which, and what no switch can give; films/ships.json
#   key_for <command…>              the shortcut that runs it in the map in effect, or nothing: so that a film follows the keys that ship
#   view_now                        the node the camera is at, for `played`
#   played "<scene>" <view before>  a check that the camera went somewhere: a film in which nothing happens is a Mac's time for nothing
#   glass on|off                    translucent materials, as a Mac comes (on), or Reduce Transparency, as GitHub's Macs come (off)
#   metronome <kind>                a scene of its own: the camera's square, moving in a way that is known (camera.swift)
#   pinch x y <amount> [options]    a pinch at that place (witness.swift)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib-gestures.sh"
needs_throwaway_mac "film the whole display, with whatever is on it"

FILM_CAMERA="$ARBOR_ROOT/.build/mac-shell/camera"
FILM_WITNESS="$ARBOR_ROOT/.build/mac-shell/witness"
FILM_APPTOOL="$ARBOR_ROOT/.build/mac-shell/apptool"
FILM_SAMPLER="$ARBOR_ROOT/.build/mac-shell/sampler"
FILM_SAMPLER_PID=""
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
  local camera witness apptool sampler
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
  swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/sampler.swift" -o "$FILM_SAMPLER" > "$ARBOR_OUT/build-sampler.log" 2>&1 &
  sampler=$!
  arbor_build
  if ! wait "$camera"; then
    grep -A 6 "error:" "$ARBOR_OUT/build-camera.log" | head -n 80
    die "scripts/mac-shell/camera.swift did not compile"
  fi
  # Costs the scenes with a pinch, not the others.
  wait "$witness" || { echo "scripts/mac-shell/witness.swift did not compile: no pinches"; FILM_WITNESS=""; }
  wait "$apptool" || { echo "scripts/mac-shell/apptool.swift did not compile: the display keeps its size"; FILM_APPTOOL=""; }
  wait "$sampler" || { echo "scripts/mac-shell/sampler.swift did not compile: the films go without the window server's account"; FILM_SAMPLER=""; }
}

# A film shows what the display showed. It cannot show where a real window is while a stand-in covers it, which is what decides whether
# the stand-ins may go. The sampler asks the window server, on the same clock and in the same grammar as a film's log, so
# `judge.py home` lays the two side by side. Descriptors 5 and 6 are the script's ends of its fifos.
sampler_start() {
  local tiers=""
  [ -z "${ARBOR_REHEARSAL:-}" ] || { echo "> sampler_start (not rehearsed)"; return 0; }
  [ -n "$FILM_SAMPLER" ] && [ -z "$FILM_SAMPLER_PID" ] || return 0
  scratch_dir sampler FILM_SAMPLER_TEMP
  mkfifo "$FILM_SAMPLER_TEMP/in" "$FILM_SAMPLER_TEMP/out" || die "sampler_start: no fifos in $FILM_SAMPLER_TEMP"
  # As in lib-day.sh: what the runner's agent starts counts as work in the background, and its timers come late.
  if command -v taskpolicy > /dev/null; then tiers="taskpolicy -l 0 -t 0"; fi
  # shellcheck disable=SC2086
  $tiers "$FILM_SAMPLER" "$ARBOR_OUT/samples.log" "$FILM_SAMPLER_TEMP/in" "$FILM_SAMPLER_TEMP/out" --hz 60 \
    2>> "$ARBOR_OUT/sampler.log" 4>&- 7>&- 8>&- 9>&- &
  FILM_SAMPLER_PID=$!
  started "$FILM_SAMPLER_PID"
  # Both ways, so that opening them does not wait for a sampler that ended at once.
  exec 6<> "$FILM_SAMPLER_TEMP/in" 5<> "$FILM_SAMPLER_TEMP/out"
  echo "the sampler writes mac-shell/samples.log (pid $FILM_SAMPLER_PID)"
}

sampler_stop() {
  [ -n "$FILM_SAMPLER_PID" ] || return 0
  kill -0 "$FILM_SAMPLER_PID" 2>/dev/null && echo stop >&6
  exec 6>&- 5<&-
  ended "$FILM_SAMPLER_PID" 30 || kill_started "$FILM_SAMPLER_PID"
  FILM_SAMPLER_PID=""
  echo "samples: $(wc -l < "$ARBOR_OUT/samples.log" | tr -d ' ') lines; $(tail -n 1 "$ARBOR_OUT/samples.log")"
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
  # So that "none" can be told from "nobody looked".
  note "windows $1"
}

# Arbor's own windows that are on screen, as the window server sees them: level x y w h.
film_overlays() {
  [ -n "$ARBOR_PID" ] || return 0
  overlays | awk -v when="$1" '$8 == "on" { print "overlay", when, $3, $4, $5, $6, $7 }' | while read -r line; do note "$line"; done
  # So that "none" can be told from "nobody looked".
  note "overlays $1"
}

hold_drag() {
  local mods="" previous="" word
  for word in "$@"; do
    [ "$previous" = --mods ] && mods=$word
    previous=$word
  done
  drag "$@" --no-release
  sleep 0.5
  film_overlays held
  sleep 0.3
  # Whoever pressed the keys lets go of them: they would stay down for the rest of the script.
  release ${mods:+--mods "$mods"}
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
  film_overlays before
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
    trace_begins
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
  trace_begins
}

cast_is_managed() { "$ARBOR_BIN/arborctl" state 2>/dev/null | python3 "$ARBOR_STATE_PY" ready "$1" 2>/dev/null; }

# Every run on a Mac records what macOS reported and what the apps answered (docs/TRACES.md: numbers, never titles), so that what it
# taught can be replayed anywhere; and the stage's own frames, where Arbor logs them, lie beside the display's.
trace_begins() { ctl trace on "films-$ARBOR_SESSION"; }

trace_ends() {
  local file
  [ -n "$ARBOR_PID" ] || return 0
  # A log that ends with the stage up reads as a stage that never came down.
  sleep 1
  ctl trace off
  mkdir -p "$ARBOR_OUT/traces"
  for file in "$ARBOR_HOME"/traces/*.jsonl; do
    [ -f "$file" ] && cp "$file" "$ARBOR_OUT/traces/${file##*/}"
  done
}

# What the second build ships, for whichever of it the commit under test does not ship yet: the settings to write out, as JSON, into LIGHT. It reads the defaults in the sources, so a film is of what
# ships from the day a default lands, with nobody having to remember. What no switch can give (there is no such key yet, or it does not go that far) is still the first build's in every film. Both are
# said aloud, and left in films/ships.json for the judge, so that nobody takes a film of switches, or of the first build, for a film of what ships.
second_build() {
  mkdir -p "$ARBOR_OUT/films"
  LIGHT=$(python3 - "$ARBOR_ROOT/Sources/ArborCore/Settings.swift" "$ARBOR_OUT/films/ships.json" <<'PYTHON'
import json, re, sys
wanted = {"animationDuration": 0, "focusRing": False, "menuBarControls": False, "dimBehindArranged": 0, "desktopEdge": 0}
source = open(sys.argv[1], encoding="utf-8").read()
def ships(key):
    found = re.search(rf"^\s*public var {key}: \w+ = (\S+)", source, re.M)
    if not found:
        return None
    word = found.group(1)
    return {"true": True, "false": False}.get(word, float(word) if re.fullmatch(r"[0-9.]+", word) else word)
written = {key: value for key, value in wanted.items() if ships(key) is None or ships(key) != value}
still = []
if ships("dragDocks") is None:
    still.append("a plain drag docks")
if ships("arrangeDesktopWeight") != 0:
    still.append("a column is kept for the Desktop")
if ships("windowsThatDoNotFit") is None:
    still.append("what does not fit becomes a tile")
json.dump({"written": written, "still": still}, open(sys.argv[2], "w", encoding="utf-8"))
print(json.dumps(written))
PYTHON
  ) || die "second_build: the defaults cannot be read"
  if [ "$LIGHT" = "{}" ]; then echo "no switch is written out"; else echo "NOT YET AS IT SHIPS: written out, because the commit under test ships otherwise: $LIGHT"; fi
  python3 -c 'import json, sys; still = json.load(open(sys.argv[1]))["still"]; print("STILL THE FIRST BUILD\x27S, and no switch can change it: " + "; ".join(still) if still else "nothing is left of the first build")' \
    "$ARBOR_OUT/films/ships.json"
}

# The line is `<chord> → <command>`; on a keyboard that is not a US one `<chord> (<as it is typed there>) → <command>`.
key_for() { "$ARBOR_BIN/arborctl" bindings 2>/dev/null | awk -v command="$*" '{ key = $1; sub(/^.*→ /, ""); if ($0 == command) { print key; exit } }'; }

view_now() { summary | sed -n 's/.*camera \(n[0-9]*\).*/\1/p' | head -n 1; }
film_elsewhere() { [ "$(view_now)" != "$1" ]; }
played() { check "$1: the camera went somewhere" film_elsewhere "$2"; }

# Read by an app when it starts, like Reduce Motion.
glass() {
  local value=true
  [ "$1" = on ] && value=false
  arbor_may "change the Accessibility setting Reduce Transparency" || return 0
  defaults write com.apple.universalaccess reduceTransparency -bool "$value"
  echo "Reduce Transparency: $(defaults read com.apple.universalaccess reduceTransparency 2>&1 | tail -n 1)"
}

cast_stop() {
  trace_ends
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
