#!/bin/bash
# The films of films-light.sh once more, with Arbor waiting for one app after the other at a layout, as it did before it asked them side by side:
# the control. Sent together with films-light.sh, both play on one Mac from one build, minutes apart, so that what differs between the films is that.
#
#   scripts/mac-shell/rehearse.sh scripts/mac-shell/films-light-one-by-one.sh                               on Linux, first, for nothing
#   scripts/mac-shell/run.sh scripts/mac-shell/films-light-one-by-one.sh scripts/mac-shell/films-light.sh   about twenty minutes on a hosted Mac
#   scripts/polish/judge.py acts .mac-shell/<folder>/<1-films-light-one-by-one | 2-films-light>             anywhere, afterwards: the numbers of every act
#
# What only a Mac can answer: with the apps asked side by side, is there a frame in which a window covers what neither its old frame nor its new one
# covers; in how many pieces does an act arrive; and how much later does the first change show? (With real apps, seen at the window server: a third
# of the time from the first change to the last and a third of the pieces, and the first change at 78 ms instead of 46.)
# The cast is test windows of four apps, which obey within milliseconds: what slow apps gain, probe-together.sh measures.
export ARBOR_ONE_BY_ONE=1
source "$(dirname "$0")/films-light.sh"
