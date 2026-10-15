#!/bin/bash
# A walk from the seed 1015: scripts/mac-shell/walk.py 1015 --acts 110 --display two --tiling defaults --control
# Written by a program. Change the program, not this file.
export WALK_WITHOUT_ARBOR=1
exec "$BASH" "$(dirname "${BASH_SOURCE[0]}")/1015.sh"
