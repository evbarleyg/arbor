#!/bin/bash
# reality.sh's journeys on a Mac with a second display, which is there when Arbor starts (the board, 0.19). For a plain branch; beside reality.sh plain, first, in the same run:
#
#   scripts/mac-shell/run.sh scripts/mac-shell/reality.sh scripts/mac-shell/reality-dock-left.sh scripts/mac-shell/reality-second-display.sh
#
# The display is virtual (vdisplay.m), 1280×720, to the right. On GitHub's Macs plugging it in also makes the main display 1920×1080, where it was 1024×768: so this differs from the plain run in two
# things, the second display and the main one's size. The journeys open their windows on the main display. At the end of `commands` a docked window is sent to the next display and on to the next again.
# Only on GitHub's Macs, as reality.sh is.
source "$(dirname "$0")/reality-variants.sh"
reality_before() { a_second_display; }
source "$(dirname "$0")/reality.sh"
