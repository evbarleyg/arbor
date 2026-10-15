#!/bin/bash
# The control for probe-went-and-came-back.sh: the same journey, step for step, with NO ARBOR. What macOS alone does with windows that live on a second
# display, and with windows that lie across its edge, while that display goes and comes back. The second playing. Nothing here is a verdict.
#
#   scripts/mac-shell/run.sh --no-preflight "<why>" scripts/mac-shell/probe-went-and-came-back-control.sh scripts/mac-shell/probe-went-and-came-back.sh
#
# Both in ONE dispatch, so that they play one after the other on the same Mac, in either order. About four and a half minutes; no step begins after 900 s.
# Why no pre-flight: the fake Mac has no stand-in for vdisplay, apptool or the sampler, so a rehearsal ends with exit code 2 before the first step.
#
# That no Arbor runs: this script builds the tools alone and starts no Arbor; `pgrep -x Arbor` is asked at the step `arbor`, where the other script starts
# its own, and the script ends there if a process is found; it is asked again after the last step, and the output says what it found both times.
# The steps have the same names in both scripts, and the same numbers up to l2. D and P1, which are Arbor's own commands, are left out.
# EVERY PLACE IS 40 POINTS FURTHER RIGHT AND 30 FURTHER DOWN than with Arbor, so that a place one script inherits from the other shows.
#
# HOW TO READ IT. probe-went-and-came-back-journey.sh has the steps, every line of the output and every file that comes back. In short:
#   - `at <step> <NAME> <id> ax … server …`, four seconds after each step. After a plug of A (s4, s8, m4, l2, h4) against the last put (s2, m5, h0): does it come back to
#     the frame it had on A? After an unplug (s3, s5, m1, l1, h2, z1): where does it go? f1 to f4: does a window that hangs over the edge move at a change elsewhere?
#     m4: do the two that were moved while A was away stay or go? h2, h3: where are a hidden and a minimized window, and are they whole when they are back?
#   - `share <step> <NAME> …` says which display each window lies on, and how much of it.
#   - samples.log says by which road and how soon; macos-reports.log what Accessibility reported of the windows, and when.
#   - a line that begins `!!!` spoils the comparison, `SKIPPED:` names what was not played.
#
# WHAT IT CANNOT TELL. The displays are virtual: no cable, lid, dock or sleep. Seven windows of six apps, one playing on one Mac. The second script to play
# finds a Mac that has met the displays before (`> plug` says what difference that made).
#
# Only on GitHub's Macs: it plugs displays in and out, switches the display's size, changes Reduce Motion and puts it back, hides apps, drags windows, opens and quits six apps.
JOURNEY_ARBOR=no
source "$(dirname "${BASH_SOURCE[0]}")/probe-went-and-came-back-journey.sh"
