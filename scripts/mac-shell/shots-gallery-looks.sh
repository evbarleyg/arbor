#!/bin/bash
# A part of shots-gallery.sh, which see: the tour with Increase Contrast and with Reduce Transparency, and the panels over red, blue,
# white and black.
export GALLERY_PARTS="grounds-light grounds-dark light-contrast dark-contrast light-opaque"
exec bash "$(dirname "$0")/shots-gallery.sh"
