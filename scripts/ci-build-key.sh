#!/bin/bash
# Names a hosted Mac's build folder after everything that goes into it, for .github/actions/mac-setup.
#   scripts/ci-build-key.sh products|tests
#
# Prints, as GitHub's step outputs:
#   key=…      the name of what this job will have built
#   enough=…   a cache whose name matches this pattern (as in the shell's `case`) holds all of it already
#   or<<…      names to build upon if there is none, the most promising first
#
#   build-v1-<system, Xcode, compiler>-<day>-<manifest>-t-<sources>-<tests>     after `swift build --build-tests`
#   build-v1-<system, Xcode, compiler>-<day>-<manifest>-p-<sources>             after `swift build`
#
# Sources and tests are named by Git's hash of their content, so two commits with the same Sources share a build, whatever else
# differs between them: a branch that only adds a Mac shell script builds nothing. The manifest stands before them: a build is never
# built upon one with other targets, whose modules would still lie about and could be imported.
# The day (UTC): however well building upon builds works, the chain is cut once a day.
set -euo pipefail
kind=${1:?usage: scripts/ci-build-key.sh products|tests}

short() { git hash-object --stdin | cut -c 1-16; }
# The runner's image too: the helper tools are compiled for the system they are compiled on. And the tools that build and note, whose meaning
# is part of what a cache means.
made_with=$( { sw_vers -buildVersion; echo "${ImageVersion:-}"; uname -m; xcodebuild -version; swift --version 2>&1; pwd
  cat "$(dirname "$0")/ci-build.sh" "$(dirname "$0")/ci-mtimes.py"; } | short)
manifest=$(git rev-parse HEAD:Package.swift | cut -c 1-16)
# With the helper tools that scripts/ci-build.sh compiles into .build/mac-shell.
sources=$( { git rev-parse HEAD:Sources
  git ls-files -s -- 'scripts/mac-shell/*.swift' 'scripts/mac-shell/*.m' scripts/mac-shell/compile-tools.sh; } | short)
tests=$(git rev-parse HEAD:Tests | cut -c 1-16)
[ -z "$(git status --porcelain -- Package.swift Sources Tests scripts/mac-shell)" ] \
  || { echo "ci-build-key.sh: the checkout differs from its commit, so the commit's hashes do not name it" >&2; exit 2; }

stem="build-v1-$made_with-$(date -u +%F)-$manifest"
case "$kind" in
  tests)
    echo "key=$stem-t-$sources-$tests"
    echo "enough=$stem-t-$sources-$tests"
    printf 'or<<.\n%s\n.\n' "$stem-t-$sources-"$'\n'"$stem-t-"$'\n'"$stem-p-$sources"$'\n'"$stem-p-" ;;
  products)
    echo "key=$stem-p-$sources"
    # With the tests built as well it is no worse.
    echo "enough=$stem-[pt]-$sources*"
    printf 'or<<.\n%s\n.\n' "$stem-t-$sources-"$'\n'"$stem-t-"$'\n'"$stem-p-" ;;
  *) echo "ci-build-key.sh: products or tests, not '$kind'" >&2; exit 64 ;;
esac
