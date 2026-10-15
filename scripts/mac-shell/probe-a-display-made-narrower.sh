#!/bin/bash
# A display made narrower, with NO ARBOR. A window lies wholly in view at a display's right edge; the display is made narrower, so that about a quarter of the window would
# be left showing, its title bar within reach. Does macOS pull it in by itself, how far, and how long after the change? And does it go back when the display is as wide as it
# was? Part N of probe-went-and-came-back-journey.sh, played alone. Nothing here is a verdict: it only says how often a person will meet such a window.
#
#   scripts/mac-shell/run.sh --no-preflight "<why>" scripts/mac-shell/probe-a-display-made-narrower.sh
#
# By itself or in one dispatch with others, in any order: it builds the tools it needs (no Arbor) and leaves the Mac as it found it, the main display's size included. About
# three minutes; no step begins after 900 s, and lib.sh ends the script at 1,020 s.
# Why no pre-flight: the fake Mac has no stand-in for vdisplay, apptool or the sampler, so a rehearsal ends with exit code 2 before the first step.
#
# WHAT IT PLAYS. TEXT (TextEdit) and LIVES (Notes), each put so that it ends at the display's right edge, 427 points wide (a quarter would be left) and then 640 (half); an
# app that does not go that narrow is as narrow as it goes, and `edge` says how much of it would be left.
#   n1 to n8    the MAIN display's own size is switched: 1920×1080, 1600×900, 1920×1080, for each of the two widths
#   n9 to n16   a SECOND display, A, at the right: 1920×1080 is replaced by 1600×900 with the same serial number at the same place, and that by 1920×1080 again. A virtual
#               display cannot change its size, so each replacement is an unplug and a plug: TWO changes, not one
# With a window of Arbor's own test app in LIVES's place it is played by probe-went-and-came-back-unseen.sh, which builds Arbor anyway: JOURNEY_PARTS="N U" there.
#
# HOW TO READ IT
#   - `narrow <step> <NAME> <id> before <x y w h> | accessibility <x y w h> | server <x y w h> | shown <0.00…1.00> on <display> | after <seconds>`: three for each window after each
#     change, half a second, two and five seconds after the command that made it had returned. n3, n6, n11, n14: made narrower. n4, n7, n12, n15: as wide as before.
#   - `edge <step> …`: how wide each window is at the edge, and how much of it the narrower display would leave.
#   - macos-reports.log has what Accessibility reported of both windows, to the millisecond; samples.log every frame; narrow-<step>.png the screen after five seconds.
#   - `modes: …`: the sizes the main display offers. `!!!` and `SKIPPED: n1 to n8` if one of the two is not among them.
#
# WHAT IT CANNOT TELL. A hosted Mac's display and virtual displays, at scale 1: no cable, no monitor's own menu, no change of scaling in System Settings. Two windows, one
# playing on one Mac. That no Arbor runs: `pgrep -x Arbor` before the part, at the step `arbor` and after the last step; the script builds and starts none.
#
# Only on GitHub's Macs: it switches the display's size, plugs displays in and out, changes Reduce Motion and puts it back, hides apps, opens and quits two apps.
JOURNEY_ARBOR=no
JOURNEY_PARTS=N
# No Arbor waits a second and a half for the displays to settle here.
JOURNEY_REST=${JOURNEY_REST:-2}
source "$(dirname "${BASH_SOURCE[0]}")/probe-went-and-came-back-journey.sh"
