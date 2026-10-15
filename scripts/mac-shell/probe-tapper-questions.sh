#!/bin/bash
# Which cheap question turns at the instant macOS withdraws a tapper's right, how long after the first event that is dropped, and what does asking cost?
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-tapper-questions.sh      (about six minutes; README-permission-probes.md says how to read it)
#
# probe-permission-loss.sh with other rounds and a quicker stream: the bare tapper alone (asker.swift, `tap`), which asks five questions every 10 ms on a thread of their own
# (`tapIsEnabled` of its own tap, `AXIsProcessTrusted`, `CGPreflightListenEventAccess`, `CGPreflightPostEventAccess`, a trial `tapCreate`), writes down every change of answer and every word
# of macOS's that its tap was switched off, and says at its end what one call of each costs. The stream is clicks alone, every 20 ms, so that the moment of the first
# dropped event is known to 20 ms. By tccutil's road, with one round by the row and a word and controls in which nothing is taken.
# And: does a tap that is in but switched OFF ever start the drop? One tap, off; one off and one on for a kind of event that never comes; one switched on only three seconds after the withdrawal
# (does switching on then start it, or is it refused?). And a tool with no tap but a global NSEvent monitor.
export ROUNDS="by_tccutil:bare-tapper by_tccutil:bare-tapper-off by_tccutil:bare-tapper-off by_tccutil:bare-tapper-off+idle by_tccutil:bare-tapper-off+idle by_tccutil:bare-tapper-late by_tccutil:bare-tapper-late \
by_tccutil:bare-monitor by_tccutil:bare-monitor by_tccutil:bare-tapper by_the_row_and_a_word:bare-tapper nothing:bare-tapper nothing:bare-tapper-off"
export BEAT=20 KINDS=click
exec bash "$(dirname "$0")/probe-permission-loss.sh"
