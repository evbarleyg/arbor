#!/bin/bash
# Builds everything a release consists of. `make release` runs it. In build/:
#
#   Arbor.app                      for Apple silicon and Intel, signed as scripts/sign.sh describes
#   Arbor-<version>.zip, .dmg      the app; the disk image also holds a link to /Applications to drag it onto
#   Arbor-<version>-checksums.txt  their SHA-256 sums (shasum -a 256 -c)
#   Arbor-<version>-notes.md       the release notes (scripts/release-notes.sh)
#   arbor.rb                       the Homebrew cask, filled in from packaging/arbor.rb
#
# With $ARBOR_NOTARY_PROFILE, the name of a keychain profile made with `xcrun notarytool store-credentials`, the app
# and the disk image are also notarized by Apple and stapled. That needs $ARBOR_SIGN_IDENTITY to be a
# "Developer ID Application" certificate. Without it a downloaded copy has to be let past Gatekeeper by hand, which
# the notes explain.
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(./scripts/version.sh version)
app=build/Arbor.app
zip=build/Arbor-$version.zip
dmg=build/Arbor-$version.dmg
profile=${ARBOR_NOTARY_PROFILE:-}
export ARBOR_RELEASE=1

if [ -n "$profile" ]; then
  case "${ARBOR_SIGN_IDENTITY:-}" in
    "Developer ID Application"*) ;;
    *)
      echo "release.sh: Apple notarizes only what a Developer ID signed. Set ARBOR_SIGN_IDENTITY to the name of your" >&2
      echo "  \"Developer ID Application: …\" certificate, or leave ARBOR_NOTARY_PROFILE unset." >&2
      exit 1
      ;;
  esac
fi

step() { echo; echo "== $*"; }

build_products() {
  local product
  for product in Arbor arborctl; do
    swift build -c release "$@" --product "$product" || return 1
  done
}

step "Building Arbor $(./scripts/version.sh) for Apple silicon and Intel"
if build_products --arch arm64 --arch x86_64; then
  bin=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
else
  echo "This toolchain does not build both at once: building each by itself and joining them"
  build_products --arch arm64
  build_products --arch x86_64
  bin=.build/universal
  mkdir -p "$bin"
  for product in Arbor arborctl; do
    lipo -create -output "$bin/$product" \
      "$(swift build -c release --arch arm64 --show-bin-path)/$product" \
      "$(swift build -c release --arch x86_64 --show-bin-path)/$product"
  done
fi
ARBOR_BIN=$bin ./scripts/bundle.sh
for binary in "$app/Contents/MacOS/Arbor" "$app/Contents/Helpers/arborctl"; do
  for architecture in arm64 x86_64; do
    case " $(lipo -archs "$binary") " in
      *" $architecture "*) ;;
      *) echo "release.sh: $binary has no $architecture part, only $(lipo -archs "$binary")" >&2; exit 1 ;;
    esac
  done
done

# Apple's answer is a ticket; stapling attaches it, so that the first launch needs no network.
notarize() {
  xcrun notarytool submit "$1" --keychain-profile "$profile" --wait
}

rm -f build/Arbor-*.zip build/Arbor-*.dmg build/Arbor-*-checksums.txt build/Arbor-*-notes.md build/arbor.rb
if [ -n "$profile" ]; then
  step "Notarizing the app"
  ditto -c -k --keepParent "$app" "$zip"
  notarize "$zip"
  xcrun stapler staple "$app"
  rm -f "$zip"  # it holds the app from before the ticket
fi

step "Packing"
ditto -c -k --keepParent "$app" "$zip"

staging=$(mktemp -d) || { echo "release.sh: no temporary folder" >&2; exit 1; }
trap 'rm -rf "${staging:?}"' EXIT
cp -R "$app" "$staging/Arbor.app"
ln -s /Applications "$staging/Applications"
# hdiutil now and then finds its own scratch image "busy", mostly on CI machines.
tries=0
until hdiutil create -quiet -volname "Arbor $version" -srcfolder "$staging" -format UDZO -ov "$dmg"; do
  tries=$((tries + 1))
  [ "$tries" -lt 3 ] || { echo "release.sh: hdiutil could not make $dmg" >&2; exit 1; }
  sleep 2
done

if [ -n "$profile" ]; then
  step "Notarizing the disk image"
  codesign --force --sign "$ARBOR_SIGN_IDENTITY" --timestamp "$dmg"
  notarize "$dmg"
  xcrun stapler staple "$dmg"
  spctl --assess --type execute --verbose=2 "$app"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
  export ARBOR_NOTARIZED=1
fi

(cd build && shasum -a 256 "$(basename "$zip")" "$(basename "$dmg")" > "Arbor-$version-checksums.txt")
sum=$(shasum -a 256 "$dmg" | cut -d ' ' -f 1)
# Without the comment at the top, which is about the template.
grep -v '^#' packaging/arbor.rb | sed -e "s/@VERSION@/$version/g" -e "s/@SHA256@/$sum/g" > build/arbor.rb
./scripts/release-notes.sh > "build/Arbor-$version-notes.md"

step "Arbor $(./scripts/version.sh)"
echo "architectures: $(lipo -archs "$app/Contents/MacOS/Arbor")"
codesign --display --verbose=2 "$app" 2>&1 | grep -E '^(Identifier|Authority|Signature|TeamIdentifier|Runtime|CodeDirectory)' || true
if [ -z "$profile" ]; then echo "not notarized (ARBOR_NOTARY_PROFILE is not set)"; fi
ls -l "$zip" "$dmg" "build/Arbor-$version-checksums.txt" "build/Arbor-$version-notes.md" build/arbor.rb
cat "build/Arbor-$version-checksums.txt"
