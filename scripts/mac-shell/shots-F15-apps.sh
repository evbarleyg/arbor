#!/bin/bash
# Real apps as tiles, for real icons and the colours Arbor takes from them (docs/features/F15-appearance-options.md).
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-F15-apps.sh
#
# Only on GitHub's throwaway Macs: it opens ten apps and kills them again, whoever had them open.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "open Safari, Terminal, Notes and seven more apps, arrange their windows, and kill them afterwards"

SCENERY="$ARBOR_ROOT/.build/mac-shell/scenery"

scene() {
  local picture=day file size
  [ "$1" = dark ] && picture=night
  file="$ARBOR_ROOT/.build/mac-shell/scenery-$picture.png"
  size=$(pointer displays | awk 'NR == 1 { print $6, $7 }')
  # shellcheck disable=SC2086
  "$SCENERY" landscape "$picture" $size "$file"
  wallpaper "$file"
  appearance "$1"
}

settings() {
  printf '%s\n' "$1" > "$ARBOR_HOME/settings.json"
  ctl reload-settings
}

pointer_away() { move "$((sx + sw - 40))" "$((sy + 40))"; }

# Real apps, for real icons and the colours Arbor takes from them.
real_apps() {
  local p=$1 name pid pids="" names="Safari Terminal Dictionary Calendar Notes Maps Music Reminders Calculator TextEdit"
  for name in $names; do open -g -a "$name" 2>&1 | head -n 1; done
  sleep 8
  for name in $names; do
    pid=$(pgrep -x "$name" | head -n 1)
    echo "$name: pid ${pid:-none}"
    [ -n "$pid" ] && pids="$pids${pids:+,}$pid"
  done
  ARBOR_EXTRA_PIDS=$pids
  arbor_start 1
  read -r sx sy sw sh <<< "$(arbor_ask screen)"
  summary
  state | python3 -c '
import json, sys
for window in json.load(sys.stdin)["windows"]:
    print(window["id"], window["app"], window["bundleID"], "managed" if window["managed"] else "not managed")'
  pointer_away
  shot "$p-30-apps-floating"
  ctl arrange
  summary
  shot "$p-31-apps-arranged"
  # Columns pass as usable and the windows in them do not, so every window is a tile of its own.
  settings '{"minimumUsableWidth": 100, "minimumUsableHeight": 400}'
  shot "$p-32-apps-window-tiles"
  settings '{"minimumUsableWidth": 100, "minimumUsableHeight": 400, "appColourAmount": 0.5}'
  shot "$p-33-apps-half-colour"
  settings '{"minimumUsableWidth": 100, "minimumUsableHeight": 400, "appColourAmount": 1}'
  shot "$p-34-apps-full-colour"
  # Now the columns do not pass either: a group's tile each.
  settings '{"minimumUsableWidth": 2000}'
  shot "$p-35-apps-group-tiles"
  settings '{}'
  arbor_stop
  ARBOR_EXTRA_PIDS=""
  for name in $names; do pkill -x "$name"; done
  sleep 1
}

arbor_build
if [ -n "${ARBOR_REHEARSAL:-}" ]; then
  SCENERY=true # A rehearsal (rehearse.sh) has no screen to decorate.
elif ! swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/scenery.swift" -o "$SCENERY" \
  > "$ARBOR_OUT/build-scenery.log" 2>&1; then
  cat "$ARBOR_OUT/build-scenery.log"
  die "scripts/mac-shell/scenery.swift did not compile"
fi

scene light
real_apps light
scene dark
real_apps dark
scene light
