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
# Each script finds in $MAC_SHELL_PART which playing of the whole dispatch it is, and in $MAC_SHELL_PARTS how many there are, over all its Macs: its place
# among run.sh's arguments. A Mac plays a block of them, one after the other, from $MAC_SHELL_FIRST_PART on. All of it is settled before the first
# script begins, and so that a playing that never began shows as that and not as a gap, each one's folder holds a run.json from the start:
#   {"gate": 1, "started": false, "run": "<GitHub's run>", "attempt": n, "part": k, "parts": N, "commit": "<40 hex>"}
# A script that leaves a run.json of its own in mac-shell/ replaces it. One script: 1 and 1.
#
# What has been gathered comes back also if the job is cut off in the middle of the list: the scripts that have run whole, the one that was
# running as far as it got, the rest with their run.json. There is no exit-code.txt at the top then.
#
# Every script gets its turn, whatever became of the one before: they are separate questions. One that is still running after
# MAC_SHELL_LIMIT seconds (1200) is stopped as the job's own time limit would stop it, only that the others still get to run: TERM, which
# the supervisor in lib.sh takes for an interruption and cleans up after, and KILL fifteen seconds later. Its exit code is 124.
#
# EACH SCRIPT FINDS THE MAC AS THE FIRST ONE FOUND IT, or results would depend on the order. After every script but the last the Mac is looked over:
#   put back, and said so      macOS's own tiling and the click on the wallpaper (com.apple.WindowManager), Reduce Motion, light or dark
#   cannot be put back         Accessibility for the runner's processes is gone (`tccutil reset`), there is another number of Spaces or of displays.
#                              What would run on such a Mac would say nothing about Arbor, so the scripts that are left do not run: each says why, and
#                              ends with exit code 75. Give a script that does such a thing the last place, or a run of its own.
# The desktop picture is not looked at: nothing reads it back. Only where there is a `defaults`, so on a Mac.
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

# MARK: the Mac as it was

tool() { local name=$1; shift; [ -x ".build/mac-shell/$name" ] && ".build/mac-shell/$name" "$@" 2>/dev/null; }
# What can be put back: a line for each. "-" where nothing is set.
settings_now() {
  echo "reduce-motion $(defaults read com.apple.universalaccess reduceMotion 2>/dev/null || echo -)"
  echo "appearance $(defaults read -g AppleInterfaceStyle 2>/dev/null || echo Light)"
  echo "window-manager $(defaults export com.apple.WindowManager - 2>/dev/null | cksum | cut -d ' ' -f 1)"
}
# What cannot.
for_good_now() {
  echo "Accessibility for the runner's processes: $(tool pointer ax-access | head -n 1)"
  echo "Spaces: $(tool vdisplay spaces | tr '\n' ';')"
  echo "displays: $(tool pointer displays | wc -l | tr -d ' ')"
}
mac_note() {
  command -v defaults > /dev/null 2>&1 || return 0
  settings_now > "$kept/.settings"
  for_good_now > "$kept/.for-good"
  defaults export com.apple.WindowManager "$kept/.window-manager.plist" 2>/dev/null
}
# Prints what it put back. Returns 1, having printed what differs, if the Mac cannot be made what it was.
mac_put_back() {
  [ -f "$kept/.settings" ] || return 0
  local name was now
  while read -r name was; do
    now=$(settings_now | awk -v name="$name" '$1 == name { print $2 }')
    [ "$now" != "$was" ] || continue
    case "$name" in
      reduce-motion)
        if [ "$was" = - ]; then defaults delete com.apple.universalaccess reduceMotion 2>/dev/null
        else defaults write com.apple.universalaccess reduceMotion -bool "$([ "$was" = 1 ] && echo true || echo false)"; fi ;;
      appearance) tool vdisplay appearance "$(echo "$was" | tr 'DL' 'dl')" > /dev/null ;;
      window-manager)
        defaults import com.apple.WindowManager "$kept/.window-manager.plist" 2>/dev/null
        # It reads its settings when it starts; launchd starts it again.
        killall WindowManager 2>/dev/null
        sleep 1 ;;
    esac
    echo "mac-shell: put back after $1: $name"
  done < "$kept/.settings"
  if ! for_good_now | cmp -s - "$kept/.for-good"; then
    for_good_now | diff "$kept/.for-good" - | sed -n 's/^< /mac-shell: it was:  /p; s/^> /mac-shell: it is:   /p'
    return 1
  fi
}

# The job was cancelled or has run out of time: the script that is running gets the chance to clean up and to leave its logs.
running="" cut_off=""
trap 'cut_off=yes; [ -n "$running" ] && kill -TERM "$running" 2>/dev/null' TERM INT HUP

# The workflow knows how many there are in all, and where this Mac's begin. Without it: what this Mac was given, from 1.
export MAC_SHELL_PARTS=${MAC_SHELL_PARTS:-$#}
first_part=${MAC_SHELL_FIRST_PART:-1}
case "$first_part" in "" | *[!0-9]*) first_part=1 ;; esac

folder_of() { if [ "$total" -eq 1 ]; then echo "$kept"; else echo "$kept/$1-$(basename "$2" .sh)"; fi; }
total=$# number=0
for script in "$@"; do
  number=$((number + 1))
  mkdir -p "$(folder_of "$number" "$script")"
  printf '{"gate": 1, "started": false, "run": "%s", "attempt": %d, "part": %d, "parts": %d, "commit": "%s"}\n' "${GITHUB_RUN_ID:-}" \
    "${GITHUB_RUN_ATTEMPT:-1}" "$((first_part + number - 1))" "$MAC_SHELL_PARTS" "$(git rev-parse HEAD 2>/dev/null)" > "$(folder_of "$number" "$script")/run.json"
done

# gather <number> <script>: what the script said and left goes to its folder, over what lay there.
gather() {
  [ -d "$out" ] || return 0
  cp -R "$out/." "$(folder_of "$1" "$2")/"
  rm -rf "$out"
}
# However this ends, mac-shell/ holds all there is.
finish() {
  [ -d "$kept" ] || return 0
  [ -z "$now_playing" ] || gather "$number" "$now_playing"
  rm -f "$kept/.settings" "$kept/.for-good" "$kept/.window-manager.plist"
  rm -rf "$out"
  mv "$kept" "$out"
}
now_playing=""
trap finish EXIT

[ $# -eq 1 ] || mac_note
spoilt=""

first=0 number=0
for script in "$@"; do
  [ -z "$cut_off" ] || break
  number=$((number + 1))
  now_playing=$script
  export MAC_SHELL_PART=$((first_part + number - 1))
  rm -rf "$out"
  mkdir -p "$out"
  header="# mac-shell: $script at $commit, macOS $system, $(date -u +%Y-%m-%dT%H:%MZ)"
  echo "$header" > "$out/output.txt"
  [ $# -eq 1 ] || echo "::group::$number of $#: $script"
  began=$SECONDS shown=0
  if [ -n "$spoilt" ]; then
    echo "not run: $spoilt left a Mac that cannot be made what it was, and what ran on it now would say nothing about Arbor" >> "$out/output.txt"
    code=75
  elif [ ! -f "$script" ]; then
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
  if [ -z "$spoilt" ] && [ -z "$cut_off" ] && [ "$number" -lt $# ] && ! mac_put_back "$(basename "$script")" >> "$out/output.txt" 2>&1; then
    spoilt=$(basename "$script")
    echo "::warning title=mac-shell::$spoilt left a Mac that cannot be made what it was: the scripts after it do not run"
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
  fi
  gather "$number" "$script"
  now_playing=""
done

if [ -n "$cut_off" ]; then
  echo "::warning title=mac-shell::cut off after $number of $# scripts"
  exit 130
fi
if [ $# -gt 1 ]; then
  echo "$first" > "$kept/exit-code.txt"
  cat "$kept/summary.txt"
  awk '{ gsub(/%/, "%25"); printf "%s%%0A", $0 }' "$kept/summary.txt" | sed 's/^/::notice title=mac-shell summary::/'
  echo
fi
exit "$first"
