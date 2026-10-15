#!/bin/bash
# The control of stranger-3deb36a.3-docked.sh: the same file, played without Arbor. It cannot dock: what else moved when the windows were docked, and after, is what differs.
export WALK_WITHOUT_ARBOR=1
exec "$BASH" "$(dirname "${BASH_SOURCE[0]}")/stranger-3deb36a.3-docked.sh"
