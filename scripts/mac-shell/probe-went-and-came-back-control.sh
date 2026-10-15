#!/bin/bash
# The control for probe-went-and-came-back.sh: the same journey, step for step, with NO ARBOR. What macOS alone does with a window that lives on a second
# display, and with one that lies across its edge, while that display goes and comes back. Nothing here is a verdict.
#
#   scripts/mac-shell/run.sh --no-preflight "<why>" scripts/mac-shell/probe-went-and-came-back-control.sh scripts/mac-shell/probe-went-and-came-back.sh
#
# Both in ONE dispatch, so that they play one after the other on the same Mac. About three minutes after the build; no step begins after 900 s.
# Why no pre-flight: the fake Mac has no stand-in for vdisplay, apptool or the sampler, so a rehearsal ends with exit code 2 before the first step.
#
# That no Arbor runs: this script builds the tools alone and starts no Arbor; `pgrep -x Arbor` is asked at the step `arbor`, where the other script starts
# its own, and the script ends there if a process is found; it is asked again after the last step, and the output says what it found both times.
# The steps have the same names in both scripts, and the same numbers up to s11. P1, which is about what Arbor keeps out of view, is left out.
#
# HOW TO READ IT. probe-went-and-came-back-journey.sh has the steps, every line of the output and every file that comes back. In short:
#   - `at <step> LIVES|STRADDLES <id> ax … server …`, four seconds after each step: at s3, s5, s7, s9 and s11 against s0 (does it go home?); at s4, s8 and s10 against
#     s2 (does it go back to the point it had on A?); s8 after it has been on B, which is another display. STRADDLES: does it flip at every change?
#   - samples.log says by which road and how soon; macos-reports.log what Accessibility reported of the two windows, and when.
#   - a line that begins `!!!` spoils the comparison, `SKIPPED:` names what was not played.
#
# WHAT IT CANNOT TELL. The displays are virtual: no cable, lid, dock or sleep. Two windows of two apps, both put through Accessibility and not by a
# hand, one playing on one Mac. The second script to play finds a Mac that has met the displays before (`> plug` says what difference that made).
#
# Only on GitHub's Macs: it plugs displays in and out, switches the display's size, changes Reduce Motion and puts it back, hides apps, opens and quits two.
JOURNEY_ARBOR=no
source "$(dirname "${BASH_SOURCE[0]}")/probe-went-and-came-back-journey.sh"
