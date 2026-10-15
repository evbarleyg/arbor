#!/bin/bash
# input-taps.sh with its session 3: `guardDesktopClicks`, which keeps a click on the wallpaper from sweeping every window aside (F60).
#   scripts/mac-shell/run.sh scripts/mac-shell/input-taps-with-the-guard.sh      (about five minutes)
#
# The guard ships off and is shelved. At both playings on hosted Macs on 2026-10-15 thirteen of the session's checks failed: the guard leaves a
# click alone where it takes some small window for one that waits for it, Arbor's own line of words after a shortcut among them. For whoever takes
# the guard up again. Last on its Mac, or alone: as input-taps.sh, it ends by taking the Accessibility permission away.
ARBOR_INPUT_TAPS_GUARD=1
source "$(dirname "${BASH_SOURCE[0]}")/input-taps.sh"
