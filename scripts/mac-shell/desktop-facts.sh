#!/bin/bash
# Prints facts about the Desktop of this Mac that F60 (the guard of the Desktop) and F05 (⇧-drag on the Desktop) were written without: what
# the window server lists above the palettes and below the windows on a Mac in daily use, four preferences, and what Finder
# answers about a place where the wallpaper shows. See deskfacts.swift, which is all of it.
#
#   scripts/mac-shell/desktop-facts.sh
#
# Safe on a person's Mac: it reads and prints. No pointer, no keys, no Arbor, nothing started, quit or changed. It writes to .build/mac-shell
# and mac-shell/ only. The output names no app but Apple's own that every Mac has, and no window title. About half a minute, nearly
# all of it the compiler's. Exit code 0, or 1 if the tool does not compile.
cd "$(dirname "$0")/../.." || exit 2
mkdir -p .build/mac-shell mac-shell
if ! swiftc -O -swift-version 5 scripts/mac-shell/deskfacts.swift -o .build/mac-shell/deskfacts > mac-shell/build-deskfacts.log 2>&1; then
  echo "✘ deskfacts does not compile"
  grep -A 4 "error:" mac-shell/build-deskfacts.log | sed "s|$PWD/||g" | head -n 60
  exit 1
fi
.build/mac-shell/deskfacts
