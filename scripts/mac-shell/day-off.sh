#!/bin/bash
# day.sh with macOS's own window management switched off (edges, menu bar, ⌥, the wallpaper click): the other half of docs/VIABLE.md's cells.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/day-off.sh
export DAY_TILING=off
exec "$BASH" "$(dirname "${BASH_SOURCE[0]}")/day.sh"
