#!/bin/bash
# Builds what nearly every job on a hosted Mac needs, before the job's own work: the products, and the three helper tools that
# `arbor_build` (scripts/mac-shell/lib.sh) compiles for every Mac shell script, to the same places and with the same options.
#   scripts/ci-build.sh [arguments for swift build, e.g. --build-tests]
#
# So that it can be kept (.github/actions/mac-keep-build) as a build and nothing but a build. The scripts that follow build again, find
# nothing to do, and need not know. A helper tool is compiled only if its source is newer than the tool, which is lib.sh's rule too.
# Exits with swift build's exit code: a tool that does not compile is for the script that needs it to report.
set -uo pipefail
# In the current folder, not the one this file is in: the Mac shell workflow brings its own copy to another commit's checkout.
[ -f Package.swift ] || { echo "ci-build.sh: no Package.swift in $PWD" >&2; exit 2; }

stale=()
for tool in pointer curtain vdisplay; do
  for source in "scripts/mac-shell/$tool".*; do
    [ -x ".build/mac-shell/$tool" ] && [ ".build/mac-shell/$tool" -nt "$source" ] || stale+=("$tool")
  done
done
if [ ${#stale[@]} -gt 0 ]; then
  ( scripts/mac-shell/compile-tools.sh "${stale[@]}"; rm -f mac-shell/build-*.log; rmdir mac-shell 2>/dev/null ) &
fi
swift build "$@"
code=$?
wait
exit "$code"
