#!/bin/bash
# reality.sh's journeys on a Mac with the Dock at the right. For a plain branch; beside reality.sh plain, first, in the same run:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/reality.sh scripts/mac-shell/reality-dock-left.sh scripts/mac-shell/reality-dock-right.sh scripts/mac-shell/reality-second-display.sh
#
# Measured so far, with the Dock at the bottom: a size call that grows a window where it stands stops at the DISPLAY's right edge. Whether with the Dock at the right it stops at the Dock's left
# edge, a point short of it, or at the display's edge, nobody has measured. The journeys dock windows into the right half and the right third.
# Only on GitHub's Macs, as reality.sh is: it moves the Dock, and puts it back at its end.
source "$(dirname "$0")/reality-variants.sh"
reality_before() { dock_to right; }
source "$(dirname "$0")/reality.sh"
# The Dock is still at the right. What is to be seen of a window out of view there, and how far macOS lets one go elsewhere (the board, 1.95).
out_of_view_beside_the_dock
