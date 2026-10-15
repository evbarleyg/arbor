#!/bin/bash
# The courier of the newcomer's rig: the one process on the hosted Mac that can push, and all it does is push two folders.
#
#   printf '%s\n' "$TOKEN" | sudo bash scripts/newcomer/courier.sh <box> <remote url> <run>        (an empty line: no token, for a rehearsal)
#
# The rig (rig.py) does whatever it is told from afar with a real pointer and real keys, in an account whose every process can read every
# other's environment and files, and pictures of that screen are public within seconds. So the token is kept out of that account: it
# comes in on standard input, never in an argument, a file or the environment of anything that lasts, and the workflow starts a copy of
# this file that is root's own, as root, which looks for its tools in the system's folders alone. It dies with the job, as the token does.
# That keeps the token from showing by accident. It is no wall: the account may use sudo without a password (scripts/newcomer/README.md).
#
# They talk through files in <box>, which is the rig's:
#   request      "<number> screen|record", written by the rig: push <box>/screen, or <box>/record, as it is now
#   answer-<n>   written here when that is done: 0, or git's exit code after three tries
#                "<number> goodbye": delete newcomer-start/<run>, which has done its work
#   stop         the rig's script has ended: so does the courier
# Each push is one commit without history, pushed with force to mac-shell-out/newcomer.<run>.screen or .record: a branch holds the newest
# state and nothing else, as the output of a Mac shell run does, and goes the same way after a day (scripts/housekeeping.py).
set -uo pipefail
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
box=${1:?usage: courier.sh <box> <remote url> <run>} remote=${2:?} run=${3:?}
IFS= read -r token || token=""
case "$run" in *[!A-Za-z0-9-]* | "") echo "courier: not a run's name" >&2; exit 64 ;; esac
[ -d "$box" ] || { echo "courier: no folder $box" >&2; exit 64; }
store=$(mktemp -d) || exit 2
[ -n "$store" ] || exit 2
trap 'rm -rf "${store:?}"' EXIT

export GIT_TERMINAL_PROMPT=0 GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=mac-shell GIT_AUTHOR_EMAIL=mac-shell@users.noreply.github.com
export GIT_COMMITTER_NAME=mac-shell GIT_COMMITTER_EMAIL=mac-shell@users.noreply.github.com
git init --quiet --bare "$store/git" || exit 2

# deliver <folder's name> <number>
deliver() {
  local tree commit try code=1
  # The folder is the rig's account's, and this is root: what is a link to somewhere else is not followed there.
  [ -d "$box/$1" ] && [ ! -L "$box/$1" ] || return 1
  rm -f "$store/index"
  GIT_INDEX_FILE="$store/index" git --git-dir="$store/git" --work-tree="$box/$1" add --all || return 1
  tree=$(GIT_INDEX_FILE="$store/index" git --git-dir="$store/git" write-tree) || return 1
  commit=$(git --git-dir="$store/git" commit-tree "$tree" -m "mac-shell: newcomer $run, $1 $2") || return 1
  for try in 1 2 3; do
    push --force "$commit:refs/heads/mac-shell-out/newcomer.$run.$1"
    code=$?
    [ "$code" -ne 0 ] || break
    sleep "$try"
  done
  return "$code"
}

# push <git push's arguments after the remote>
push() {
  if [ -n "$token" ]; then
    # In the environment of this one command, which is root's, for as long as the push takes.
    GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="http.https://github.com/.extraheader" \
      GIT_CONFIG_VALUE_0="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$token" | base64 | tr -d '\n')" \
      git --git-dir="$store/git" push --quiet "$remote" "$@"
  else
    git --git-dir="$store/git" push --quiet "$remote" "$@"
  fi
}

answer() {
  rm -f "$box/answer-$1" "$box/answer-$1.new"
  echo "$2" > "$box/answer-$1.new" && mv "$box/answer-$1.new" "$box/answer-$1"
}

last=0 pushes=0
while [ ! -e "$box/stop" ]; do
  number="" what=""
  [ -f "$box/request" ] && read -r number what < "$box/request"
  case "$number" in "" | *[!0-9]*) sleep 0.05; continue ;; esac
  [ "$number" -gt "$last" ] || { sleep 0.05; continue; }
  last=$number
  case "$what" in
    screen | record)
      deliver "$what" "$number"
      answer "$number" $?
      pushes=$((pushes + 1))
      # What was pushed and replaced is of no use to anybody.
      [ $((pushes % 50)) -ne 0 ] || git --git-dir="$store/git" gc --quiet --prune=now 2>/dev/null ;;
    goodbye)
      push --delete "refs/heads/newcomer-start/$run"
      answer "$number" $? ;;
    *) answer "$number" 64 ;;
  esac
done
echo "courier: $pushes pushes"
