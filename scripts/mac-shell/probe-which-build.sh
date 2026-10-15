#!/bin/bash
# Which build does a script drive, and does that build start, dock a window and quit?
source "$(dirname "$0")/lib.sh"
arbor_build
step "which build"
echo "configuration: $ARBOR_CONFIGURATION; drives ${ARBOR_BIN#"$ARBOR_ROOT"/}"
echo "Arbor: $(wc -c < "$ARBOR_BIN/Arbor" | tr -d ' ') bytes"
echo "in .build: $(ls "$ARBOR_ROOT/.build" | tr '\n' ' ')"
step "a session"
arbor_start 2
ctl dock "$W1" left
summary
arbor_stop
