#!/bin/bash
# What identifies a build of Arbor, and the stamp that puts it into an app bundle.
#
#   scripts/version.sh                      0.9.0 (build 214, 47a2ba9)
#   scripts/version.sh version              0.9.0
#   scripts/version.sh build                214
#   scripts/version.sh commit               47a2ba9
#   scripts/version.sh --stamp <Info.plist> writes the three into a bundle's Info.plist (macOS)
#
# The version is written down in one place, the VERSION file. $ARBOR_VERSION replaces it for one build, which
# is how the release workflow makes release candidates. The build number is the number of commits that lead to
# HEAD; the commit is HEAD's short hash, with -dirty when what goes into the app has uncommitted changes.
# Without Git (a source archive) they are 0 and "unknown". Nothing is generated for the compiler: the app and
# arborctl read the stamp back when they start (Sources/ArborCore/BuildInfo.swift).
set -euo pipefail
cd "$(dirname "$0")/.."

version=${ARBOR_VERSION:-$(tr -d '[:space:]' < VERSION)}
# It ends up in file names, URLs and a property list.
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "version.sh: '$version' is not a version like 0.9.0 or 0.9.0-rc.1" >&2
  exit 1
fi

build=0
commit=unknown
if git rev-parse --verify --quiet HEAD >/dev/null 2>&1; then
  build=$(git rev-list --count HEAD)
  commit=$(git rev-parse --short HEAD)
  git diff --quiet HEAD -- Sources Resources Package.swift VERSION || commit="$commit-dirty"
fi

case "${1:-}" in
  "") echo "$version (build $build, $commit)" ;;
  version) echo "$version" ;;
  build) echo "$build" ;;
  commit) echo "$commit" ;;
  --stamp)
    plist=${2:?usage: scripts/version.sh --stamp <Info.plist>}
    plutil -replace CFBundleShortVersionString -string "$version" "$plist"
    plutil -replace CFBundleVersion -string "$build" "$plist"
    plutil -replace ArborCommit -string "$commit" "$plist"
    ;;
  *)
    echo "usage: scripts/version.sh [version|build|commit|--stamp <Info.plist>]" >&2
    exit 64
    ;;
esac
