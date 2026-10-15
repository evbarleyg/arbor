#!/bin/bash
# The pictures the tests draw without a screen (docs/TESTING.md, "Pictures without a screen"), brought back to be looked at: tiles, the
# surface, the line on screen, the panel of shortcuts, Go to…, the minimap, the menu bar item and the settings window, each in the light
# and the dark look at one and at two pixels to the point. And the verdict of those tests, which run nowhere but on a Mac.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-offscreen.sh
#
# What they cannot show is what the window server adds: shadows, levels, what lies in front of what. shots-gallery.sh has that.
#
# Safe anywhere: it builds, runs tests that open no window and read nothing from the screen, and copies what they drew.
ARBOR_TIME_LIMIT=1100
source "$(dirname "$0")/lib.sh"

SUITES='AccentInkPictureTests|StandInPictureTests|PanelGroundPictureTests|PreviewVariantsPictureTests|UpdateAlertTests|AppearancePictures|FinderDrawingTests|HeadsUpPictureTests|MenuBarDrawingTests|MinimapDrawingTests|SettingsWindowPictureTests|TileDrawingTests'

step "build, tests included"
started_at=$(date +%s)
if ! swift build --build-tests > "$ARBOR_OUT/build-tests.log" 2>&1; then
  grep -E "error:" "$ARBOR_OUT/build-tests.log" | sort -u | head -n 40
  die "the tests did not build"
fi
echo "built in $(($(date +%s) - started_at)) s"

step "the tests that draw"
swift test --skip-build --filter "$SUITES" > "$ARBOR_OUT/tests.log" 2>&1
code=$?
grep -E "^✘|recorded an issue|Test run with" "$ARBOR_OUT/tests.log" | cut -c 1-400
check "every test that draws passes" test "$code" -eq 0

step "what they drew"
if [ -d .build/pictures ]; then
  cp -R .build/pictures "$ARBOR_OUT/pictures"
  find "$ARBOR_OUT/pictures" -name '*.png' | wc -l | awk '{ print $1, "pictures" }'
  du -sh "$ARBOR_OUT/pictures" | awk '{ print $1 }'
fi
check "there are pictures" test -d "$ARBOR_OUT/pictures"
