#!/bin/bash
# Which cheap question turns at the instant macOS withdraws a tapper's right, how long after the first event that is dropped, and what does asking cost?
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-tapper-questions.sh      (about four minutes; README-permission-probes.md says how to read it)
#
# probe-permission-loss.sh with other rounds and a quicker stream: the bare tapper alone (asker.swift, `tap`), which asks five questions every 10 ms on a thread of their own
# (`tapIsEnabled` of its own tap, `AXIsProcessTrusted`, `CGPreflightListenEventAccess`, `CGPreflightPostEventAccess`, a trial `tapCreate`), writes down every change of answer and every word
# of macOS's that its tap was switched off, and says at its end what one call of each costs. The stream is clicks alone, every 20 ms, so that the moment of the first
# dropped event is known to 20 ms. Four rounds by tccutil's road, one by the row deleted and tccd killed, one by the row and a word, one in which nothing is taken.
export ROUNDS="by_tccutil:bare-tapper by_tccutil:bare-tapper by_tccutil:bare-tapper by_tccutil:bare-tapper by_the_row:bare-tapper by_the_row_and_a_word:bare-tapper nothing:bare-tapper"
export BEAT=20 KINDS=click
exec bash "$(dirname "$0")/probe-permission-loss.sh"
