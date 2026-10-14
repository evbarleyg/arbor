#!/bin/bash
# The control for day.sh: the same day without Arbor, leaving out the steps that are Arbor's own keys.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/day-control.sh
#
# What jolts.py finds here is macOS's doing or an app's: a window that an app moves by itself when it comes forward, what full
# screen or a click on the wallpaper does to the others. A finding of the real day that shows up here too is no fault of Arbor's.
export DAY_WITHOUT_ARBOR=1
exec "$BASH" "$(dirname "${BASH_SOURCE[0]}")/day.sh"
