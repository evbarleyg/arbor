#!/bin/bash
# Gives a hosted Mac the Swift release the project is built with.
#   scripts/ci-toolchain.sh [version]      (default: 6.4, as the Linux job's image has)
#
# Why: GitHub's Macs can be a Swift release behind. Swift 6.3.3 crashes while compiling Sources/ArborKit/UI/SettingsListViews.swift
# ("fatal error encountered during compilation") and cannot infer a generic parameter that 6.4 can, so there the build fails
# before a single test runs. The SDK stays Xcode's; only the compiler comes from swift.org, through swiftly.
#
# Installing takes a minute and a half, so .github/actions/mac-setup puts back what an earlier job installed (~/.swiftly and
# ~/Library/Developer/Toolchains) before it calls this. What was put back is used only if it answers with the right version.
# `installed=true` among the step's outputs says that there is something new to keep.
#
# For CI only: it installs a toolchain into the home folder and changes the PATH of the steps that follow.
set -euo pipefail
want=${1:-6.4}
version_of() { "$1" --version 2>&1 | sed -nE 's/.*Swift version ([0-9]+\.[0-9]+).*/\1/p' | head -1; }
have=$(version_of swift)
if [ "$have" = "$want" ]; then echo "Swift $have is here already"; exit 0; fi
[ -n "${GITHUB_PATH:-}" ] || { echo "ci-toolchain.sh is for a CI job (no GITHUB_PATH); on your own Mac install Xcode 27 or swift.org's toolchain" >&2; exit 2; }

if [ -x "$HOME/.swiftly/bin/swift" ]; then
  kept=$(version_of "$HOME/.swiftly/bin/swift" || true)
  if [ "$kept" = "$want" ]; then
    echo "the runner has Swift ${have:-none}; using the $want an earlier job installed"
    echo "$HOME/.swiftly/bin" >> "$GITHUB_PATH"
    exit 0
  fi
  echo "what an earlier job installed answers '${kept:-nothing}', not $want: away with it"
  rm -rf "$HOME/.swiftly" "$HOME/Library/Developer/Toolchains"
fi

echo "the runner has Swift ${have:-none}; installing $want"
cd "$(mktemp -d)"
curl -fsSLO https://download.swift.org/swiftly/darwin/swiftly.pkg
installer -pkg swiftly.pkg -target CurrentUserHomeDirectory
"$HOME/.swiftly/bin/swiftly" init --assume-yes --quiet-shell-followup --skip-install
# shellcheck disable=SC1091
. "$HOME/.swiftly/env.sh"
swiftly install --assume-yes --use "$want"
du -sh "$HOME/.swiftly" "$HOME/Library/Developer/Toolchains" | sed "s|$HOME|~|"
echo "$HOME/.swiftly/bin" >> "$GITHUB_PATH"
[ -z "${GITHUB_OUTPUT:-}" ] || echo "installed=true" >> "$GITHUB_OUTPUT"
