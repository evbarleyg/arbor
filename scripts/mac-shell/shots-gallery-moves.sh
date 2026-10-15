#!/bin/bash
# A part of shots-gallery.sh, which see: motion; a large display and a Retina one; real apps; the panels over red, blue, white and black
# with Reduce Transparency.
export GALLERY_PARTS="motion large apps-light apps-dark grounds-light-opaque grounds-dark-opaque"
exec bash "$(dirname "$0")/shots-gallery.sh"
