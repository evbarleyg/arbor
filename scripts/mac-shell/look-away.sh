#!/bin/bash
# The control for look-behind.sh: the same minutes as Arbor ships, with what is out of view at the display's corner.
#
#   scripts/mac-shell/run.sh --priority 1 scripts/mac-shell/look-away.sh scripts/mac-shell/look-behind.sh
#
# The pictures and films have the same names either way, to be laid side by side.
export LOOK=away
exec "$BASH" "$(dirname "${BASH_SOURCE[0]}")/look-behind.sh"
