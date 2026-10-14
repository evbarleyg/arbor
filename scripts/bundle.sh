#!/bin/bash
# Builds build/Arbor.app from the release binaries, stamps its version (scripts/version.sh) and signs it
# (scripts/sign.sh, which explains the choice of signature and what it means for permissions).
#
# $ARBOR_BIN names a folder that already holds the Arbor and arborctl binaries to bundle; `make release` puts
# universal ones there. ARBOR_CONFIGURATION=debug compiles without the optimizer, as `swift build` and the tests do: the
# way out should a toolchain ever fail on the release build alone.
set -euo pipefail
cd "$(dirname "$0")/.."

configuration=${ARBOR_CONFIGURATION:-release}
case "$configuration" in
  release | debug) ;;
  *) echo "bundle.sh: ARBOR_CONFIGURATION is release or debug, not '$configuration'" >&2; exit 64 ;;
esac

bin=${ARBOR_BIN:-}
if [ -z "$bin" ]; then
  swift build -c "$configuration" --product Arbor
  swift build -c "$configuration" --product arborctl
  bin=$(swift build -c "$configuration" --show-bin-path)
fi

app=build/Arbor.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers" "$app/Contents/Resources"
cp "$bin/Arbor" "$app/Contents/MacOS/Arbor"
cp "$bin/arborctl" "$app/Contents/Helpers/arborctl"
cp Resources/Info.plist "$app/Contents/Info.plist"

# The icon is drawn by a script (Info.plist names it as CFBundleIconFile). Arbor works without it, so a failure
# costs the icon and nothing else.
if swift scripts/make-icon.swift build/Arbor.iconset \
  && iconutil -c icns build/Arbor.iconset -o "$app/Contents/Resources/Arbor.icns"; then
  :
else
  echo "warning: could not make the app icon; building Arbor.app without it" >&2
  rm -f "$app/Contents/Resources/Arbor.icns"
fi

./scripts/version.sh --stamp "$app/Contents/Info.plist"
./scripts/sign.sh "$app"
echo "Built $app, version $(./scripts/version.sh)"
