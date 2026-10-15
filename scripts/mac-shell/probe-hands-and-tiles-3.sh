#!/bin/bash
# The third part of probe-hands-and-tiles.sh, which says what it measures and what it prints: ⌥ with other modifiers beside it (E4), out of
# the menu bar again (B), asked to go above it (C). Nothing here is a check: the output is the point.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-hands-and-tiles-3.sh
PROBE_GROUPS="E4 B C"
source "$(dirname "$0")/probe-hands-and-tiles.sh"
