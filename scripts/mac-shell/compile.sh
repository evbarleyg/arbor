#!/bin/bash
# Compiles everything on a Mac and does nothing else: the way to find out whether macOS-only code builds
# without opening or pushing to a pull request.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/compile.sh
#
# Prints the errors and warnings; the whole output comes back as build.log. Exits with swift build's exit code.
cd "$(dirname "$0")/../.." || exit 2
mkdir -p mac-shell

# On GitHub's Macs the workflow has built already (scripts/ci-build.sh), upon an earlier run's build if there was one: its log comes first. So the
# errors are all here, but of the warnings only those about what had to be compiled again.
cat .build/ci-build.log > mac-shell/build.log 2>/dev/null
swift build >> mac-shell/build.log 2>&1
code=$?
# The compiler repeats a message for every file that sees it, and under an excerpt of the source.
grep -E "^/.*: (error|warning):|^error:" mac-shell/build.log | sed "s|^$PWD/||" | sort -u | head -n 100
tail -n 1 mac-shell/build.log
exit "$code"
