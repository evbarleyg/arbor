#!/bin/bash
# Lays out what the newcomer gets, in the folder the courier pushes: its script, its words of use, and what a stranger sees of Arbor first.
#
#   scripts/newcomer/lay-kit.sh <box> <run> arbor|macos [README.md of the build under test]
#
# "The README's first screen" is its first 45 lines: about what a browser window shows of it before anybody scrolls.
set -euo pipefail
box=${1:?usage: lay-kit.sh <box> <run> arbor|macos [README.md]} run=${2:?} arm=${3:?} readme=${4:-}
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
mkdir -p "$box/screen/check/scripts" "$box/record"
cp "$here/kit/mac" "$box/screen/mac"
chmod +x "$box/screen/mac"
echo "$run" > "$box/screen/run"
awk -v about="$here/kit/about-$arm.md" '$0 == "@ABOUT@" { while ((getline line < about) > 0) print line; next } { print }' "$here/kit/HOWTO.md" > "$box/screen/HOWTO.md"
# What reads every remark before it is sent: the repository's own check, with the two files it reads.
cp "$root/scripts/public-check.py" "$root/scripts/public-check.allow" "$box/screen/check/scripts/"
cp "$root/LICENSE" "$box/screen/check/LICENSE"
if [ "$arm" = arbor ]; then
  [ -f "$readme" ] || { echo "lay-kit.sh: with Arbor it takes the README of the build under test" >&2; exit 64; }
  head -n 45 "$readme" > "$box/screen/README-first-screen.md"
fi
