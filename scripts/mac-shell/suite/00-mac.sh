#!/bin/bash
# Says what Mac this is: half of a surprise in a later section is explained here. Nothing that tells whose it is: the
# output gets pasted and committed.
source "$(dirname "$0")/../lib.sh"

echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m), bash $BASH_VERSION, $(python3 --version 2>&1)"
# The one above is whichever comes first in the PATH. This is the one the Command Line Tools bring, which is what `make check` meets on a Mac that has no other.
echo "/usr/bin/python3: $(/usr/bin/python3 --version 2>&1)"
swift --version 2>&1 | head -n 1
arbor_build

claim "the Mac lets Arbor and the suite work"
echo "displays (id x y w h pixel-width pixel-height scale):"
pointer displays
check "a child process may use Accessibility" test "$(pointer ax-access)" = true
if on_throwaway_mac || [ -n "${ARBOR_SHOTS:-}" ]; then
  check "a child process may record the screen" test "$(pointer screen-access)" = true
fi
check "there is a display" test "$(pointer displays | wc -l)" -ge 1
check "no mouse button is down" test "$(pointer where | awk '{ print $3 }')" = up


# Where macOS tiles at the screen's edges Arbor stands aside (docs/TESTING.md). It is a setting of the person's, not of the
# session, so only a throwaway Mac has it switched off (`screen_edges_dock`).
if on_throwaway_mac; then
  screen_edges_dock
  macos_tiling
  echo "windows on screen (id pid layer x y w h on owner):"
  pointer windows | awk '$8 == "on"' | head -n 20
else
  macos_tiling
fi
