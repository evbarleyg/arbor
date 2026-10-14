#!/bin/sh
# `make hooks`: has git run scripts/public-check.py before every push from this clone and its worktrees, and looks through the
# clone for history from somewhere else (scripts/public-clone.py). The first thing to do in a clone; again whenever the
# check has changed, for the copy that branches without the check are read with. Fails when the hook could not be installed
# or the clone is not clean.
#
# The hook goes into the clone's own hooks folder and not through `core.hooksPath scripts/git-hooks`: that path would
# lead into the checked-out tree, where a branch from before the check has no such folder, and git takes a missing
# hook for no hook.
set -u
here=$(cd "$(dirname "$0")" && pwd) || exit 1
gitdir=$(git rev-parse --git-common-dir) || exit 1
common=$(cd "$gitdir" && pwd) || exit 1

install_hook() {
  elsewhere=$(git config --get core.hooksPath || true)
  if [ -n "$elsewhere" ]; then
    echo "make hooks: git is told to look for hooks in $elsewhere (core.hooksPath), so one in $common/hooks would never run."
    echo "NOTHING CHECKS WHAT IS PUSHED FROM THIS CLONE. Unset that, or have the pre-push hook there run scripts/git-hooks/pre-push."
    return 1
  fi
  if [ -e "$common/hooks/pre-push" ] && ! grep -q "^# arbor's pre-push hook" "$common/hooks/pre-push"; then
    echo "make hooks: $common/hooks/pre-push is somebody else's hook and stays."
    echo "NOTHING CHECKS WHAT IS PUSHED FROM THIS CLONE. Have that hook run scripts/git-hooks/pre-push too."
    return 1
  fi
  mkdir -p "$common/hooks" "$common/arbor-public-check" &&
    cp "$here/../public-check.py" "$here/../public-check.allow" "$common/arbor-public-check/" &&
    cp "$here/pre-push" "$common/hooks/pre-push" &&
    chmod +x "$common/hooks/pre-push" &&
    echo "git now runs scripts/public-check.py before every push from this clone"
}

install_hook
hook=$?
# Whatever became of the hook: what the clone holds is a question of its own.
python3 "$here/../public-clone.py"
clone=$?
[ "$hook" -eq 0 ] || exit 1
exit "$clone"
