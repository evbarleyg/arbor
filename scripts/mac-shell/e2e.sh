#!/bin/bash
# Every real-window check in one run of the "Mac shell" workflow, for executors who want to know before they open a
# pull request: builds everything, runs arbor-e2e through scripts/e2e.sh (full screen included) and then the real
# drags of e2e-drag.sh, and brings back the evidence, the build log and Arbor's logs.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/e2e.sh
#
# Exit code: 0 every check passed, 1 a check failed, 2 the build failed, the runner has no Accessibility
# permission, or the test windows never appeared.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 2
mkdir -p mac-shell

echo "runner: $(sw_vers -productName) $(sw_vers -productVersion) on $(uname -m)"
echo "window server session: $(launchctl managername 2>/dev/null || echo unknown)"
if ! swift build > mac-shell/build.log 2>&1; then
  echo "swift build failed. Its errors:"
  grep "error:" mac-shell/build.log | sort -u | head -n 60
  echo "::error title=mac-shell::swift build failed: $(grep -c "error:" mac-shell/build.log) error lines"
  exit 2
fi
grep "warning:" mac-shell/build.log | sort -u | head -n 20

./scripts/e2e.sh --full-screen
code=$?
echo "arbor-e2e exit code: $code"
[ -f collab/evidence/e2e-latest.txt ] && cp collab/evidence/e2e-latest.txt mac-shell/e2e-latest.txt

bash scripts/mac-shell/e2e-drag.sh
drag=$?
echo "e2e-drag exit code: $drag"
[ "$drag" -gt "$code" ] && code=$drag
exit "$code"
