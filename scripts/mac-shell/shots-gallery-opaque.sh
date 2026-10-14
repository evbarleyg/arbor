#!/bin/bash
# shots-gallery.sh with Reduce Transparency on. See there.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-gallery-opaque.sh
export GALLERY_LOOKS="light-opaque dark-opaque"
exec bash "$(dirname "$0")/shots-gallery.sh"
