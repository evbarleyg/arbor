#!/bin/bash
# A desk session Arbor never saw. Floating windows live on a second display. The display goes while Arbor runs; Arbor quits; the display comes and goes once more
# with no Arbor to see it; Arbor is started again, on the state it saved, and then the display comes back. What does Arbor make of windows that macOS has had on
# that display, and dropped again, in between? Part U of probe-went-and-came-back-journey.sh, played alone. Nothing here is a verdict.
#
#   scripts/mac-shell/run.sh --no-preflight "<why>" scripts/mac-shell/probe-went-and-came-back-unseen.sh
#
# By itself, or in one dispatch with the other two, in any order: it builds what it needs and leaves the Mac as it found it. About five and a half minutes with part N; no step begins
# after 900 s, and lib.sh ends the script at 1,020 s. It needs no control: the steps at which no Arbor runs (u3, u4, u9, u10) are macOS alone, on the same windows.
# Why no pre-flight: the fake Mac has no stand-in for vdisplay, apptool or the sampler, so a rehearsal ends with exit code 2 before the first step.
#
# Part N, a display made narrower, rides along (JOURNEY_PARTS="N U" below; U alone: JOURNEY_PARTS=U). It is played before Arbor is started, has a window of Arbor's own test app beside TextEdit's, because
# this script builds Arbor anyway, and takes a minute and a half more (part_N in the journey).
#
# THE WINDOWS: LIVES (Notes), TEXT (TextEdit), JAVA (jconsole, if it opens) and PICTURE (Preview), all put wholly on A through Accessibility; DESK (Script Editor), a
# bystander on the main display. Nothing is docked. Arbor runs as a person runs it, all but its welcome window, with the settings it ships with.
#
# WHAT IT ASKS, step by step (part_U in the journey has them all, and every line of the output)
#   u1   A goes, Arbor running: where do the windows wait on the main display? (`waits`)          u2   Arbor quits: does that move them? (`waits`)
#   u3   A comes, no Arbor: does macOS put each back at the very frame it had on A? (`back`)
#   u4   A goes, no Arbor: where does macOS drop each? To the point where it waited at u2, or at u1? (`drops`)
#   u5   Arbor is started again: does it move anything? (`moved`; `set`: its setFrame calls to each window in the new trace, up to the next step)
#   u6   A comes: who brings the windows back? (`books`; `who`: did macOS report a move before Arbor was told of the displays, and how many setFrame calls followed)
#   u7   A goes.   u8 to u13: the same once more, with PICTURE's app hidden and TEXT minimized before the unplug that Arbor does not see (u9h), and shown again once Arbor
#        runs and A is back (u12s: `whole`, `share`)
#
# HOW TO READ IT
#   - `waits`, `back`, `drops`, `moved` compare frames to the point, by the window server. `at`, `share`, `arbor … |` and `books` are as in the other two scripts.
#   - `set` and `who` are counted from the traces -U2 and -U3. A TRACE BEGINS ONLY WHEN ARBOR ANSWERS: a frame it sets before
#     that is in no trace. `moved`, samples.log (every frame between `M begin <n> arbor-u5` and the next `M begin`) and macos-reports.log would show it.
#   - arbor-<script>.log ends with the first quit, -2.log with the second, -3.log with the last; each begins with what the one before holds.
#   - a line that begins `!!!` spoils the reading or is one of the journey's findings, `SKIPPED:` names what was not played.
#
# WHAT IT CANNOT TELL. The displays are virtual: no cable, lid, dock or sleep. The Mac is not restarted, nobody logs out, and the apps run on from u0 to the
# end: a real night between two desk sessions may have none of that. Five windows of five apps, one playing on one Mac.
#
# Only on GitHub's Macs: it plugs displays in and out, switches the display's size, changes Reduce Motion and puts it back, hides apps, opens and quits five apps.
JOURNEY_ARBOR=yes
ARBOR_RECORD=1
JOURNEY_PARTS="N U"
source "$(dirname "${BASH_SOURCE[0]}")/probe-went-and-came-back-journey.sh"
