#!/bin/bash
# A walk from the seed 1017: scripts/mac-shell/walk.py 1017 --acts 95 --display two --tiling defaults --control
# Written by a program. Change the program, not this file.
export WALK_WITHOUT_ARBOR=1
exec "$BASH" "$(dirname "${BASH_SOURCE[0]}")/1017.sh"
