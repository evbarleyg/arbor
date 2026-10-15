#!/bin/bash
# who-comes-forward.sh without Arbor.
export WALK_WITHOUT_ARBOR=1
exec "$BASH" "$(dirname "${BASH_SOURCE[0]}")/who-comes-forward.sh"
