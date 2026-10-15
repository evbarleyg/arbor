#!/bin/bash
# The control of nothing-docked.sh: the same acts on the same Mac with no Arbor running.
export WALK_WITHOUT_ARBOR=1
exec "$BASH" "$(dirname "${BASH_SOURCE[0]}")/nothing-docked.sh"
