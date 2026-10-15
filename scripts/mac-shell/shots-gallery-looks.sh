#!/bin/bash
# A part of shots-gallery.sh, which see: the tour with Increase Contrast and with Reduce Transparency.
export GALLERY_PARTS="light-contrast dark-contrast light-opaque"
exec bash "$(dirname "$0")/shots-gallery.sh"
