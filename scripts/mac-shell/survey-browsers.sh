#!/bin/bash
# The browsers alone, out of survey-casts.sh: how Chrome, Firefox and Edge open on a hosted Mac that has never run them, and whether ⌘N gives each a second window. And what the
# icon of a Java app is called in the Dock.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/survey-browsers.sh          three minutes; Arbor is not built
SURVEY_ONLY="chrome firefox edge"
source "$(dirname "${BASH_SOURCE[0]}")/survey-casts.sh"
