#!/bin/bash
# A floating window that LIVES on a second display, WITH ARBOR RUNNING, while that display goes and comes back: what do Arbor's own moves add to what
# macOS does by itself, and what do they undo of it? Nothing here is a verdict: the output, the samples and the trace are the point.
#
#   scripts/mac-shell/run.sh --no-preflight "<why>" scripts/mac-shell/probe-went-and-came-back-control.sh scripts/mac-shell/probe-went-and-came-back.sh
#
# Both in ONE dispatch, so that they play one after the other on the same Mac: the control is the same journey with no Arbor, and the answer is the
# difference between the two. About four minutes after the build, the control three; no step begins after 900 s, and lib.sh ends the script at 1,020 s.
# Why no pre-flight: the fake Mac has no stand-in for vdisplay, apptool or the sampler, so a rehearsal ends with exit code 2 before the first step.
#
# What was seen before, on hosted Macs (macOS 26.6, virtual displays). A window that lay WHOLLY on the second display came back to the point it had there,
# size included, when THAT display came back: 5 of 5. Twice Notes with no Arbor running, once of them after the display had been there in another
# size meanwhile; and three test windows of one app with Arbor running, which seem to have been docked, although Arbor had set all three
# elsewhere while one display was there. Always before Arbor was told of the displays, by a second and a half. Another display at the same
# frame fetched none of three. A window that HANGS OVER AN EDGE of the main display flipped between two places at every change of displays,
# whichever displays there were: 19 of 19. Not seen: a floating window of a real app that lives on the second display, with Arbor running. The
# pointer's carry did not take it across in that journey, and in all of them every plug was one and the same display to macOS, whatever its size.
#
# Arbor runs as a person runs it, all but its welcome window: every regular app's windows, shortcuts, event taps and menu bar item on, the settings it
# ships with, not paused, nothing docked. Both windows FLOAT, or the script ends. A trace is recorded from before s0 (ARBOR_RECORD=1).
# After the journey, if the clock allows, P1: a window that Arbor keeps out of view, with a display below the main one, through five changes of displays.
#
# HOW TO READ IT. probe-went-and-came-back-journey.sh has the steps, every line of the output and every file that comes back. In short:
#   - `at <step> LIVES …` here against the same line of the control: where they differ, Arbor did it, or kept macOS from it. s8 is the telling step.
#   - samples.log says by which road and when: every frame of both windows between `M begin <n> display-<step>-…` and the next `M begin`.
#   - the trace says who: after each `displaysChanged`, the setFrame calls to the two windows (their ids are in the `window` lines), and before it what
#     macOS reported of them. In the P1 trace: how many setFrame calls go to LIVES, which is out of view, after each `displaysChanged`.
#   - a line that begins `!!!` spoils the comparison, `SKIPPED:` names what was not played.
#
# WHAT IT CANNOT TELL. The displays are virtual: no cable, lid, dock or sleep, and each is gone the moment its process ends. Two windows of two apps,
# both put through Accessibility and not by a hand, one playing on one Mac. The second script to play finds a Mac that has met the displays before (`> plug`
# says what difference that made). Docked windows are not asked about outside P1.
#
# Only on GitHub's Macs: it plugs displays in and out, switches the display's size, changes Reduce Motion and puts it back, hides apps, opens and quits two.
JOURNEY_ARBOR=yes
ARBOR_RECORD=1
source "$(dirname "${BASH_SOURCE[0]}")/probe-went-and-came-back-journey.sh"
