#!/bin/bash
# Runs when an agent's session starts in this repository (.claude/settings.json), before the agent does anything. What it
# prints, the agent reads.
#
# The repository is public (docs/PUBLIC.md), and the two things every session has to do first were sentences in a brief:
# have git check every push, and look through the clone it was given for history from somewhere else. `make hooks` does
# both, in about a second. It changes nothing but this clone's own pre-push hook. It never fails the session: an agent that
# has been told what is wrong can put it right, one that was never started cannot.
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" 2>/dev/null && top=$(git rev-parse --show-toplevel 2>/dev/null) && cd "$top" || exit 0
[ -x scripts/git-hooks/install.sh ] || exit 0
./scripts/git-hooks/install.sh 2>&1
exit 0
