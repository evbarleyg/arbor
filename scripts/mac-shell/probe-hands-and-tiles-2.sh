#!/bin/bash
# The second part of probe-hands-and-tiles.sh, which says what it measures and what it prints: tiles never measured (D).
# Nothing here is a check: the output is the point.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-hands-and-tiles-2.sh
PROBE_GROUPS="D"
source "$(dirname "$0")/probe-hands-and-tiles.sh"
