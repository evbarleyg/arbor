#!/bin/bash
# The second half of shots-gallery.sh, which see: the tour with Increase Contrast and with Reduce Transparency, and real apps.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-gallery-looks.sh
export GALLERY_PARTS="light-contrast dark-contrast light-opaque apps-light apps-dark"
exec bash "$(dirname "$0")/shots-gallery.sh"
