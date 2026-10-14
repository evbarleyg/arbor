#!/bin/bash
# day.sh with macOS's Reduce Motion on. Arbor then puts up no stage to move the windows under, so every move of every window shows, and
# nothing is forgiven (docs/VIABLE.md).
#
#   scripts/mac-shell/run.sh scripts/mac-shell/day-still.sh
export DAY_REDUCE_MOTION=on
exec "$BASH" "$(dirname "${BASH_SOURCE[0]}")/day.sh"
