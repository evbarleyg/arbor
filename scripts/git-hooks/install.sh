#!/bin/sh
# `make hooks`: has git run scripts/public-check.py before every push from this clone and its worktrees, has it merge
# collab/parity.json and collab/reality.json by what they mean (scripts/mergeable.py), and looks through the
# clone for history from somewhere else (scripts/public-clone.py). The first thing to do in a clone; again whenever the
# check has changed, for the copy that branches without the check are read with. Fails when the hook could not be installed,
# the clone knows of no private words, or it is not clean.
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
    rm -rf "$common/arbor-public-check"/integrated-* &&
    cp "$here/pre-push" "$common/hooks/pre-push" &&
    chmod +x "$common/hooks/pre-push" &&
    echo "git now runs scripts/public-check.py before every push from this clone"
}

# Two settings lie in the clone and nowhere else. A machine that starts again may bring the clone back with its settings as they first were: hook, branches
# and worktrees are there, these are gone, and nothing in the repository can say where the list is. So they are kept beside the kept check, and put back.
settings() {
  mkdir -p "$common/arbor-public-check" || return 1
  for key in privateWords rulesRead; do
    kept="$common/arbor-public-check/arbor.$key"
    now=$(git config --get "arbor.$key" || true)
    if [ -n "$now" ]; then
      printf '%s\n' "$now" > "$kept"
    elif [ -s "$kept" ] && git config "arbor.$key" "$(cat "$kept")"; then
      echo "make hooks: arbor.$key WAS GONE from this clone's settings, and is put back as it was when \`make hooks\` was last said"
    fi
  done
  [ -z "$(git config --get arbor.privateWords || true)" ] && [ -z "${PUBLIC_CHECK_WORDS:-}" ] || return 0
  echo "make hooks: THIS CLONE KNOWS OF NO PRIVATE WORDS, and the hook lets nothing go from it to the public repository."
  echo "git config arbor.privateWords <path>; whoever has no such list says so: git config arbor.privateWords /dev/null (docs/PUBLIC.md). Then: make hooks"
  return 1
}

install_hook
hook=$?
settings
settings=$?
python3 "$here/../mergeable.py" --install
driver=$?
# Whatever became of the hook: what the clone holds is a question of its own.
python3 "$here/../public-clone.py"
clone=$?
[ "$hook" -eq 0 ] && [ "$driver" -eq 0 ] && [ "$settings" -eq 0 ] || exit 1
# It still fails: a clone that holds what must not be pushed is not ready for work. But nobody should take that for a hook that is not there.
[ "$clone" -eq 0 ] || echo "make hooks: THE HOOK IS IN and reads every push. What is wrong is what the look through the clone says, above."
exit "$clone"
