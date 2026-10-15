#!/bin/bash
# The top corners, with NO ARBOR. Asked through Accessibility for a place under the menu bar at a top corner of the main display, where does a window end? Part T of
# probe-went-and-came-back-journey.sh, played alone. Nothing here is a verdict: every line is an answer.
#
#   scripts/mac-shell/run.sh --no-preflight "<why>" scripts/mac-shell/probe-the-top-corners.sh
#
# By itself or in one dispatch with others, in any order: it builds the tools it needs (no Arbor) and leaves the Mac as it found it. Under five minutes, the tools' half
# minute included; no step begins after 900 s, and lib.sh ends the script at 1,020 s.
# Why no pre-flight: the fake Mac has no stand-in for vdisplay, apptool or the sampler, so a rehearsal ends with exit code 2 before the first step.
#
# ON RECORD SO FAR: eight calls, all in the middle of a display (x 170 or 220; asked for y 0 and y -50): the window went to the visible top, 31, and kept its x and its
# size. None at a corner.
#
# WHAT IT PLAYS. TEXT (TextEdit, 640×420), LIVES (Notes, 1000×660) and JAVA (jconsole, if it opens within eight seconds, at the size it has). In each of six arrangements each window is asked four times
# with `apptool set-frame` (size, position, size, as Arbor sets a frame), each time from 300 200 on the main display:
#   a  x = the main display's right edge less 1, y = its top          b  the same x, 50 points above the top
#   c  x = its left edge less the window's width plus 1, y = its top  d  the same x, 50 points above the top
# and in t1 and t2 also for two places at the bottom, so that the table can be laid beside another probe's:
#   e  x = the right edge less 1, y = the bottom less 1               f  x = the VISIBLE frame's right edge less 1, the same y; left out where that is e
# The arrangements, in the order they are played, which is the order of their importance should the clock cut any:
#   t2  a display under the main one, wider than it on both sides      t3  a left neighbour that begins 500 points lower      t5  a display above
#   t4  the left neighbour of t3 and one at the right                  t1  the main display alone                             t6  a right neighbour that begins 700 points higher
#
# HOW TO READ IT
#   - `top <arrangement> <NAME> <id> asked <x y w h> | accessibility <x y w h> | server <x y w h> | shown <0.00…1.00> on <display>`, a second after each ask: Accessibility's
#     frame, the window server's, how much of the window is on one display, and which display has most of it. `answer …` before it: what set-frame read back at once.
#   - `dock: …`, once: where the Dock is, the main display's frame and its visible frame.
#   - `displays <step> …` and `visible <arrangement> <display> <x y w h>` say what the arrangement was: every display's frame, and what its menu bar and the Dock leave of it.
#   - top-<arrangement>-<a…f>.png: TEXT at each of its resting places, 24 and those at the bottom. lib.sh's `shot` takes every display: that file is the main one, -d2.png and -d3.png the others,
#     to be told apart by their sizes (1280 wide: the smaller display; 1600, made smaller from 1920: the larger ones).
#   - samples.log has every frame on the way, between `M begin <n> top-<arrangement>-<NAME>-<a…f>` and the next `M begin`.
#   - t3 and t4, asks c and d, are where two rules part: the place lies on no display, 500 points above the left neighbour and a window's width less 1 from the main display. Stopped by
#     the nearest display's menu bar it ends some 531 points down; stopped by that of the display that has most of it, at the main display's visible top.
#   - `!!!`: macOS does not have a display where it was asked for, and `SKIPPED:` names the arrangement that is left out for it.
#
# WHAT IT CANNOT TELL. The displays are virtual, at scale 1. Two or three windows, one playing on one Mac. No Arbor: what Arbor makes of the answers is not asked.
# That no Arbor runs: `pgrep -x Arbor` at the step `arbor`, before the part and after the last step; the script builds and starts none.
#
# Only on GitHub's Macs: it plugs displays in and out, switches the display's size, changes Reduce Motion and puts it back, hides apps, opens and quits three apps.
JOURNEY_ARBOR=no
JOURNEY_PARTS=T
# No Arbor waits a second and a half for the displays to settle here.
JOURNEY_REST=${JOURNEY_REST:-2}
source "$(dirname "${BASH_SOURCE[0]}")/probe-went-and-came-back-journey.sh"
