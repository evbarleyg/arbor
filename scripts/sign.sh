#!/bin/bash
# Signs an Arbor.app and says what the signature means for its permissions.
#
#   scripts/sign.sh build/Arbor.app
#
# macOS ties the Accessibility permission to the code signature. It remembers the signature's "designated
# requirement": for an ad-hoc signature that is the hash of this very build, so the next build is a stranger; for a
# signature made with a certificate it names the certificate, so every build signed with it is the same app.
#
# The identity is, in this order:
#   1. $ARBOR_SIGN_IDENTITY: a certificate's name or SHA-1 hash, or - for an ad-hoc signature
#   2. "Arbor Local Signing", when a keychain has it (scripts/make-signing-identity.sh makes it, once)
#   3. ad hoc
# $ARBOR_SIGN_KEYCHAIN names a keychain file to look in instead of the keychains on the search list.
#
# An identity other than those two is taken to be one Apple issued (Developer ID): it gets the hardened runtime,
# which notarization requires, and with ARBOR_RELEASE=1 (make release) a secure timestamp as well.
set -euo pipefail

app=${1:?usage: scripts/sign.sh <Arbor.app>}
local_identity="Arbor Local Signing"
keychain=${ARBOR_SIGN_KEYCHAIN:-}

identity=${ARBOR_SIGN_IDENTITY:-}
if [ -z "$identity" ]; then
  # Without -v, which would list only certificates that are trusted; signing does not need trust.
  # Matched here and not with grep -q, which stops reading early and fails the pipe under pipefail.
  case "$(security find-identity -p codesigning ${keychain:+"$keychain"} 2>/dev/null || true)" in
    *"\"$local_identity\""*) identity=$local_identity ;;
    *) identity=- ;;
  esac
fi

options=(--force --sign "$identity")
if [ -n "$keychain" ] && [ "$identity" != - ]; then options+=(--keychain "$keychain"); fi
case "$identity" in
  - | "$local_identity") options+=(--timestamp=none) ;;
  *)
    options+=(--options runtime)
    if [ "${ARBOR_RELEASE:-}" = 1 ]; then options+=(--timestamp); else options+=(--timestamp=none); fi
    ;;
esac

sign() {
  if ! codesign "${options[@]}" "$@"; then
    echo "sign.sh: codesign could not sign with \"$identity\"." >&2
    if [ "$identity" = "$local_identity" ]; then
      echo "  If macOS asked to use the key, answer Always Allow. Over ssh, run \`security unlock-keychain\` first." >&2
      echo "  \"ambiguous\" means two certificates have the name: scripts/make-signing-identity.sh --remove, then make it again." >&2
    fi
    echo "  ARBOR_SIGN_IDENTITY=- builds with an ad-hoc signature instead." >&2
    exit 1
  fi
}

# Inside out: the bundle's signature covers arborctl's.
sign --identifier com.evbarleyg.arbor.arborctl "$app/Contents/Helpers/arborctl"
sign --identifier com.evbarleyg.arbor "$app"
codesign --verify --deep --strict "$app"

case "$identity" in
  -)
    echo "Signed $app ad hoc. The signature changes with every build, so each new build has to be given"
    echo "  Accessibility permission again. scripts/make-signing-identity.sh, run once, ends that (docs/INSTALL.md)."
    ;;
  "$local_identity")
    echo "Signed $app with \"$identity\", this Mac's own certificate: Accessibility permission, once given"
    echo "  to a build signed with it, carries over to the next."
    ;;
  *)
    echo "Signed $app with \"$identity\" and the hardened runtime: permissions carry over from build to build."
    ;;
esac
