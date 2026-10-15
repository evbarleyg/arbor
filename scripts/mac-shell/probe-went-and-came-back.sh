#!/bin/bash
# Floating windows that LIVE on a second display, WITH ARBOR RUNNING, while that display goes and comes back: what do Arbor's own moves add to what macOS
# does by itself, and what do they undo of it? The second playing. Nothing here is a verdict: the output, the samples and the traces are the point.
#
#   scripts/mac-shell/run.sh --no-preflight "<why>" scripts/mac-shell/probe-went-and-came-back-control.sh scripts/mac-shell/probe-went-and-came-back.sh
#
# Both in ONE dispatch, so that they play one after the other on the same Mac: the control is the same journey with no Arbor, and the answer is the
# difference between the two. IN EITHER ORDER: each builds what it needs and leaves the Mac as it found it, so "Arbor first on a fresh Mac" is the same
# two paths the other way round. About five and a half minutes, the control four and a half; no step begins after 900 s, and lib.sh ends the script at 1,020 s.
# Why no pre-flight: the fake Mac has no stand-in for vdisplay, apptool or the sampler, so a rehearsal ends with exit code 2 before the first step.
#
# WHAT THE FIRST PLAYING SHOWED. One hosted Mac, macOS 26.6.2, the control first; one window wholly on A (Notes'), one across the edge (Terminal's), both put
# through Accessibility; a commit without the change that lets floating windows keep their frames.
#   - macOS alone brought both windows back to the frame they last had on A, 6 of 6, once after B, another display, had come and gone. When B came, neither stirred.
#   - With Arbor running macOS did the same, at least 1.5 s before Arbor was told. The window on A went nowhere with Arbor that it did not go without.
#   - The place on A was that run's own, not inherited from the control: at the second script's first plug of A the window stayed on the main display.
#   - Arbor made no call of any kind to the window on A, and nine setFrame calls to the one across the edge in ten changes: seven that move it, two that ask
#     for where it is. THAT SAYS NOTHING OF ITS FETCHING, which never had the window on A on its list: at the first unplug the window reported its way home
#     2 ms before macOS spoke of its screens, passed for moved by its person, and was filed under the main display; Arbor's log said "remembering 1 window(s)"
#     where two were A's, and after every return its account had the window under the main display while it lay wholly on A. Hence four windows this time.
#
# WHAT THIS ONE ASKS (probe-went-and-came-back-journey.sh has the steps, every line of the output and every file that comes back)
#   S   Does Arbor remember, and fetch, the windows that lie wholly on A? Four of them, of four apps, one not Apple's. After every unplug and plug of A `books` holds
#       the number in Arbor's log ("remembering N", "N … returned") against the number its own account had under A, and that against the number that lie on A
#       by the window server; `!!!` says when one is smaller than the next.
#       And a window that a HAND dropped across the edge, beside one put there through Accessibility: are the two treated alike?
#   F   While A is there and two windows hang over the main display's right edge, a display comes and goes elsewhere: does either window move?
#   M   While A is away one of its windows is moved on the main display through Accessibility, another by the pointer. A comes back: do they stay or go?
#   L   The same absence, thirty seconds long.
#   D   Straight after that return: a window is docked and framed on the MAIN display. Is a window that lies on A taken out of view? (`parked`)
#   H   A hidden app's window and a minimized window, both on A. A goes; they are unhidden and restored: is each whole, and within reach? (`whole`, `share`)
#   P1  Windows that Arbor keeps out of view, with a display under both bottom corners of the main one: which corner does it choose? (`corner`) And how many
#       setFrame calls go to each after each `displaysChanged`? (the trace)
#
# Arbor runs as a person runs it, all but its welcome window: every regular app's windows, shortcuts, event taps and menu bar item on, the settings it ships
# with, not paused, nothing docked until d1. A trace is recorded of each part (ARBOR_RECORD=1).
#
# HOW TO READ IT
#   - `at <step> <NAME> …` here against the same line of the control, less the 40 and 30 points by which the control's places differ: where the two differ
#     besides, Arbor did it, or kept macOS from it.
#   - `arbor <step> | …` has the display whose workspace holds each window, `share <step> …` the display it lies on: the two should agree.
#   - samples.log says by which road and when; the trace says who: after each `displaysChanged`, the setFrame calls to each window (ids: the `window` lines).
#   - a line that begins `!!!` spoils the comparison or is one of four findings, `SKIPPED:` names what was not played.
#
# WHAT IT CANNOT TELL. The displays are virtual: no cable, lid, dock or sleep, and each is gone the moment its process ends. Seven windows of six apps, one playing
# on one Mac. No app that hangs. The second script to play finds a Mac that has met the displays before (`> plug` says what difference that made).
#
# Only on GitHub's Macs: it plugs displays in and out, switches the display's size, changes Reduce Motion and puts it back, hides apps, drags windows, opens and quits six apps.
JOURNEY_ARBOR=yes
ARBOR_RECORD=1
source "$(dirname "${BASH_SOURCE[0]}")/probe-went-and-came-back-journey.sh"
