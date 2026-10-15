#!/bin/bash
# Builds this commit the way `make install` builds it, and looks at what comes out. On a Mac; about three minutes.
#
#   scripts/candidate-check.sh
#
# Why: every build CI makes is a debug build. What
# a person installs is compiled with -c release, bundled, stamped and signed by scripts nothing else runs. A release
# candidate ought to have been through that once before its first `make install` is somebody's morning.
#
# When: by hand, or from a Mac shell script, on the commit that is to be released. Nothing runs it by itself.
#
# It changes nothing outside this checkout (.build and build/, both ignored by Git) and a temporary folder of its own.
# The signature is ad hoc (ARBOR_SIGN_IDENTITY=-), so that no keychain is even read. Nothing is installed, opened or started as
# an app: the two binaries are only asked for their version, which they answer without becoming anything, and with
# ARBOR_HOME in the temporary folder, so that arborctl cannot reach an Arbor that is running. Should Arbor take the question
# for none and start after all, it has ten seconds to live, nobody's windows, no shortcuts, no menu bar item, no questions
# and no watchdog.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

[ $# -eq 0 ] || { echo "usage: scripts/candidate-check.sh" >&2; exit 64; }
[ "$(uname)" = Darwin ] || { echo "candidate-check.sh: bundles and signatures exist only on macOS" >&2; exit 1; }

work=$(mktemp -d /tmp/arbor-candidate.XXXXXX) || { echo "candidate-check.sh: no temporary folder" >&2; exit 2; }
trap 'rm -rf "${work:?}"' EXIT
export ARBOR_HOME="$work/home"
unset ARBOR_SOCKET
mkdir -p "$ARBOR_HOME"

failed=0
check() {  # check "<what should hold>" <command…>
  local what=$1
  shift
  if "$@" >/dev/null 2>&1; then echo "  ✔ $what"; else echo "  ✘ $what"; failed=1; fi
}
same() { [ -n "$1" ] && [ "$1" = "$2" ]; }
# What this prints is pasted into comments. Where the checkout lies is nobody's business: the path may hold names of
# a person's own folders. The compiler names files by the path without symbolic links (/private/tmp for /tmp).
here=$(pwd -P)
tidy() { sed -e "s#$here/##g" -e "s#$PWD/##g" -e "s#$(dirname "$here")#…#g" -e "s#$HOME#~#g"; }
stamp() { plutil -extract "$1" raw build/Arbor.app/Contents/Info.plist; }
version_of() {
  perl -e 'alarm 10; exec @ARGV or exit 127' env ARBOR_ONLY_PIDS=1 ARBOR_NO_PROMPT=1 ARBOR_NO_HOTKEYS=1 ARBOR_NO_STATUS_ITEM=1 \
    ARBOR_NO_WATCHDOG=1 "$1" --version 2>&1
}

echo "candidate check: make app at $(git rev-parse --short HEAD), signed ad hoc"
started=$SECONDS
if ! ARBOR_SIGN_IDENTITY=- make app > "$work/make-app.log" 2>&1; then
  echo "candidate check failed: \`make app\` does not get through, so neither would \`make install\`"
  grep "error:" "$work/make-app.log" | sort -u | head -n 25 | tidy
  tail -n 12 "$work/make-app.log" | tidy
  exit 1
fi
echo "  ✔ make app: compiled with -c release, bundled, stamped and signed in $((SECONDS - started)) s"

app=build/Arbor.app
expected=$(./scripts/version.sh)
check "codesign --verify --deep --strict passes" codesign --verify --deep --strict "$app"
check "arborctl has an identifier of its own" \
  sh -c "codesign --display --verbose=3 $app/Contents/Helpers/arborctl 2>&1 | grep -qx 'Identifier=com.evbarleyg.arbor.arborctl'"
check "the property list is valid" plutil -lint "$app/Contents/Info.plist"
check "the version is stamped" same "$(stamp CFBundleShortVersionString)" "$(./scripts/version.sh version)"
check "the build number is stamped" same "$(stamp CFBundleVersion)" "$(./scripts/version.sh build)"
check "the commit is stamped" same "$(stamp ArborCommit)" "$(./scripts/version.sh commit)"
check "so is the kind of signature" same "$(stamp ArborSignature)" adhoc
check "Arbor --version answers, and leaves" same "$(version_of "$app/Contents/MacOS/Arbor")" "Arbor $expected"
check "arborctl --version answers" same "$(version_of "$app/Contents/Helpers/arborctl")" "arborctl $expected"

if [ "$failed" -ne 0 ]; then
  echo "candidate check failed; the end of make app's output:"
  tail -n 12 "$work/make-app.log" | tidy
  exit 1
fi
echo "candidate check passed: Arbor $expected"
