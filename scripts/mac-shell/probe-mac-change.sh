#!/bin/bash
# Changes every setting scripts/ci-mac-shell.sh is to put back, and leaves them so.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "would change macOS's tiling, the wallpaper click, Reduce Motion and the appearance, and leave them changed"
arbor_build
step "changing everything that can be put back"
macos_tiling off
macos_click_wallpaper off
macos_reduce_motion off
appearance dark
