#!/bin/bash
# A part of shots-gallery.sh, which see: motion, a large display and a Retina one, and real apps.
export GALLERY_PARTS="motion large apps-light apps-dark"
exec bash "$(dirname "$0")/shots-gallery.sh"
