#!/bin/bash
# What the "Mac shell" workflow does with the scripts it was given, on the hosted Mac: runs them one after the other and keeps what
# each said and left apart from the others'.
#   scripts/ci-mac-shell.sh <script>…        in the checkout the scripts are from
#
# Several scripts share one Mac, one checkout and one build: what a run costs before its first script starts is paid once.
#
# What is in mac-shell/ afterwards, and comes back to whoever started the run:
#   one script      output.txt, exit-code.txt and whatever the script left there: as it has always been
#   several         a folder for each, 1-<name>/, 2-<name>/, …, with exactly that in it; summary.txt, a line for each; and
#                   exit-code.txt, the first exit code that is not 0
#
# Every script gets its turn, whatever became of the one before: they are separate questions. One that is still running after
# MAC_SHELL_LIMIT seconds (1200) is stopped as the job's own time limit would stop it, only that the others still get to run: TERM, which
# the supervisor in lib.sh takes for an interruption and cleans up after, and KILL fifteen seconds later. Its exit code is 124.
#
# Readers that can reach only the REST API get each exit code and the end of each output as check annotations.
# Exits with what it wrote to exit-code.txt. Written for bash 3.2, macOS's own.
set -uo pipefail
[ $# -gt 0 ] || { echo "usage: scripts/ci-mac-shell.sh <script>…" >&2; exit 64; }
limit=${MAC_SHELL_LIMIT:-1200}
out=mac-shell
kept=$(mktemp -d) || exit 2
summary=${GITHUB_STEP_SUMMARY:-/dev/null}
commit=$(git rev-parse --short HEAD 2>/dev/null)
system=$(sw_vers -productVersion 2>/dev/null || uname -s)

# show <file>: print what has been added to it since the last time.
show() {
  local size
  size=$(wc -c < "$1" | tr -d ' ')
  [ "${size:-0}" -gt "$shown" ] || return 0
  tail -c "+$((shown + 1))" "$1" | head -c "$((size - shown))"
  shown=$size
}

# The job was cancelled or has run out of time: the script that is running gets the chance to clean up and to leave its logs.
running=""
trap '[ -n "$running" ] && kill -TERM "$running" 2>/dev/null' TERM INT HUP

first=0 number=0
for script in "$@"; do
  number=$((number + 1))
  rm -rf "$out"
  mkdir -p "$out"
  header="# mac-shell: $script at $commit, macOS $system, $(date -u +%Y-%m-%dT%H:%MZ)"
  echo "$header" > "$out/output.txt"
  [ $# -eq 1 ] || echo "::group::$number of $#: $script"
  began=$SECONDS shown=0
  if [ ! -f "$script" ]; then
    echo "::error::no file '$script' at $commit"
    echo "no file '$script' at $commit" >> "$out/output.txt"
    code=2
  else
    # Into a file and shown from there, not through a pipe: so the exit code is the script's, and a process the script leaves behind, holding
    # the pipe open, cannot hold up the scripts after it.
    bash "$script" >> "$out/output.txt" 2>&1 < /dev/null &
    running=$!
    stopped=""
    while kill -0 "$running" 2>/dev/null; do
      show "$out/output.txt"
      if [ -z "$stopped" ] && [ $((SECONDS - began)) -ge "$limit" ]; then
        stopped=$SECONDS
        echo "mac-shell: still running after $limit s: stopping it" >> "$out/output.txt"
        kill -TERM "$running" 2>/dev/null
      elif [ -n "$stopped" ] && [ $((SECONDS - stopped)) -ge 15 ]; then
        kill -KILL "$running" 2>/dev/null
      fi
      sleep 0.5
    done
    wait "$running"
    code=$?
    running=""
    [ -z "$stopped" ] || code=124
  fi
  echo "exit code $code" >> "$out/output.txt"
  show "$out/output.txt"
  echo "$code" > "$out/exit-code.txt"
  [ $# -eq 1 ] || echo "::endgroup::"
  [ "$first" -ne 0 ] || first=$code

  echo "::notice title=mac-shell exit code::$script exited with $code"
  tail -n 40 "$out/output.txt" | cut -c 1-200 | awk '{ gsub(/%/, "%25"); printf "%s%%0A", $0 }' \
    | sed "s|^|::notice title=mac-shell output (tail) of $(basename "$script")::|"
  echo
  {
    echo "## mac-shell: $script"
    echo
    echo "$header; exit code $code"
    echo
    echo '```'
    tail -c "$((60000 / $#))" "$out/output.txt"
    echo '```'
  } >> "$summary"

  if [ $# -gt 1 ]; then
    counts=$(grep -E "^[0-9]+ passed, [0-9]+ failed" "$out/output.txt" | tail -n 1)
    printf '%2d %-32s exit %-3s %4d s  %s\n' "$number" "$(basename "$script")" "$code" "$((SECONDS - began))" "$counts" >> "$kept/summary.txt"
    mv "$out" "$kept/$number-$(basename "$script" .sh)"
  fi
done

if [ $# -gt 1 ]; then
  rm -rf "$out"
  mv "$kept" "$out"
  echo "$first" > "$out/exit-code.txt"
  cat "$out/summary.txt"
  awk '{ gsub(/%/, "%25"); printf "%s%%0A", $0 }' "$out/summary.txt" | sed 's/^/::notice title=mac-shell summary::/'
  echo
else
  rmdir "$kept" 2>/dev/null
fi
exit "$first"
