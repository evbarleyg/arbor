#!/bin/bash
# shots-gallery.sh with Increase Contrast on. See there.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-gallery-contrast.sh
export GALLERY_LOOKS="light-contrast dark-contrast"
exec bash "$(dirname "$0")/shots-gallery.sh"
