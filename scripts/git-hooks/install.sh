#!/bin/sh
# `make hooks`: has git run scripts/public-check.py before every push from this clone and its worktrees. Once per clone;
# again whenever the check has changed, for the copy that branches without the check are read with.
#
# The hook goes into the clone's own hooks folder and not through `core.hooksPath scripts/git-hooks`: that path would
# lead into the checked-out tree, where a branch from before the check has no such folder, and git takes a missing
# hook for no hook.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
common=$(cd "$(git rev-parse --git-common-dir)" && pwd)

elsewhere=$(git config --get core.hooksPath || true)
if [ -n "$elsewhere" ]; then
  echo "make hooks: git is told to look for hooks in $elsewhere (core.hooksPath), so one in $common/hooks would never run." >&2
  echo "Unset that, or have the pre-push hook there run scripts/git-hooks/pre-push." >&2
  exit 1
fi
if [ -e "$common/hooks/pre-push" ] && ! grep -q "^# arbor's pre-push hook" "$common/hooks/pre-push"; then
  echo "make hooks: $common/hooks/pre-push is somebody else's hook and stays. Have it run scripts/git-hooks/pre-push too." >&2
  exit 1
fi
mkdir -p "$common/hooks" "$common/arbor-public-check"
cp "$here/../public-check.py" "$here/../public-check.allow" "$common/arbor-public-check/"
cp "$here/pre-push" "$common/hooks/pre-push"
chmod +x "$common/hooks/pre-push"
echo "git now runs scripts/public-check.py before every push from this clone"
