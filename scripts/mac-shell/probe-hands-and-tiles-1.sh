#!/bin/bash
# The first part of probe-hands-and-tiles.sh, which says what it measures and what it prints: a hand lets go low (A), the ⌥ key (E).
# Nothing here is a check: the output is the point.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-hands-and-tiles-1.sh
PROBE_GROUPS="A E"
source "$(dirname "$0")/probe-hands-and-tiles.sh"
