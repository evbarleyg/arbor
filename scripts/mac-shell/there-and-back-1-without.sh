#!/bin/bash
# The control of there-and-back.sh: the same acts on the same Mac with no Arbor running.
export WALK_WITHOUT_ARBOR=1
exec "$BASH" "$(dirname "${BASH_SOURCE[0]}")/there-and-back.sh"
