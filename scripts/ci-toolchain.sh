#!/bin/bash
# Gives a hosted Mac another Swift release than its Xcode has.
#   scripts/ci-toolchain.sh [version]      (default: 6.4, as the image of CI's job `linux` has)
#
# Why: GitHub's Macs can be a Swift release behind, and Arbor is to build with a newer one as with theirs (docs/INSTALL.md
# says from which release on). Nothing needs this script in order to build.
# The SDK stays Xcode's; only the compiler comes from swift.org, through swiftly.
#
# For CI only: it installs a toolchain into the home folder and changes the PATH of the steps that follow.
set -euo pipefail
want=${1:-6.4}
have=$(swift --version 2>&1 | sed -nE 's/.*Swift version ([0-9]+\.[0-9]+).*/\1/p' | head -1)
if [ "$have" = "$want" ]; then echo "Swift $have is here already"; exit 0; fi
[ -n "${GITHUB_PATH:-}" ] || { echo "ci-toolchain.sh is for a CI job (no GITHUB_PATH); on your own Mac the Swift of Xcode 26 or later will do" >&2; exit 2; }
echo "the runner has Swift ${have:-none}; installing $want"
cd "$(mktemp -d)"
curl -fsSLO https://download.swift.org/swiftly/darwin/swiftly.pkg
installer -pkg swiftly.pkg -target CurrentUserHomeDirectory
"$HOME/.swiftly/bin/swiftly" init --assume-yes --quiet-shell-followup --skip-install
# shellcheck disable=SC1091
. "$HOME/.swiftly/env.sh"
swiftly install --assume-yes --use "$want"
echo "$HOME/.swiftly/bin" >> "$GITHUB_PATH"
