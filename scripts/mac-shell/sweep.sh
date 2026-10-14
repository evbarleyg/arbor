#!/bin/bash
# Cleans up after a Mac shell script that was cut off together with its supervisor (kill -9 of both, a caller's own time limit, a
# crash of the terminal): lets go of the mouse button and of every key, stops the processes that run had put on record,
# and removes its folders under /tmp. Every script does the same before it starts; this one does nothing else.
# Safe on a person's Mac: it touches only what the record of such a run names.
source "$(dirname "$0")/lib.sh"
echo "nothing is left of earlier runs"
