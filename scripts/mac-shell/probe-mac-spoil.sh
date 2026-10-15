#!/bin/bash
# Takes Accessibility away from the runner's processes, which nothing can give back: the scripts after it must not run.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "would reset every app's Accessibility permission"
arbor_build
step "taking Accessibility away"
echo "before: $("$ARBOR_POINTER" ax-access)"
tccutil reset Accessibility
echo "after: $("$ARBOR_POINTER" ax-access)"
