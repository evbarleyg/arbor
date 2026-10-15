#!/bin/bash
# reality.sh's journeys on a Mac with the Dock at the left (the board, 0.19). For a plain branch; beside reality.sh plain, first, in the same run:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/reality.sh scripts/mac-shell/reality-dock-left.sh scripts/mac-shell/reality-dock-right.sh scripts/mac-shell/reality-second-display.sh
#
# Measured so far: a window asked to grow where it stands stops at the visible bottom less 1 with the Dock at the bottom, and at the display's right edge. Whether it stops at a Dock at the left nobody has
# measured. The journey `edges` drags all the way to the left edge, where the Dock now stands: whatever happens there is the finding.
# Only on GitHub's Macs, as reality.sh is: it moves the Dock, and puts it back at its end.
source "$(dirname "$0")/reality-variants.sh"
reality_before() { dock_to left; }
source "$(dirname "$0")/reality.sh"
