#!/bin/bash
# "Never log window titles" (CLAUDE.md), nor the names people give to spaces, nor what they type into Go to…: people paste
# arbor.log into bug reports. This gives windows, spaces and searches words that occur nowhere else, runs them through every
# command that takes text, with debug logging on, also where commands are refused (a held view, a pause, nonsense), and
# looks for those words in the log. Part of `make check`. **A new command that takes text gets a line here.**
#
# Not secrets, and allowed in the log: bundle ids and app names (`exclude`, `summon`), the name of a trace, settings.
set -uo pipefail
cd "$(dirname "$0")/.."
sim=.build/debug/arbor-sim
[ -x "$sim" ] || { echo "privacy smoke test: $sim is not built"; exit 1; }
home=$(mktemp -d) || exit 1
trap '[ -n "${ARBOR_KEEP:-}" ] || rm -rf "$home"' EXIT

# Commands that fail are part of it, so the simulator's exit code says nothing.
ARBOR_HOME=$home ARBOR_DEBUG=1 "$sim" quiet \
  "open Safari" "open Mail" "open Notes" \
  "title 101 TITLEWORD one" "title 102 TITLEWORD two" "title 103 TITLEWORD three" \
  "dock 101 left" "dock 102 right" "zoom 101" "name NAMEWORD" "show-all" "go NAMEWORD" "go NAMEWORDx" "spaces" \
  "find TITLEWORD" "find TITLEWORD two" "find QUERYWORD" "reveal 103" \
  "rule add com.example.safari float title TITLEWORD" "rules" "rule change 1 com.example.safari ignore title TITLEWORD" \
  "rule remove 1" "layout --titles" "layout Safari:TITLEWORD | Mail" "layout \"Safari\" \"TITLEWORD one\" | Mail" \
  "bind ctrl+opt+j go NAMEWORD" "bind ctrl+opt+k find TITLEWORD" "bindings" "key ctrl+opt+j" "key ctrl+opt+k" \
  "hold" "go NAMEWORD" "find TITLEWORD" "name NAMEWORD2" "unname NAMEWORD" "key ctrl+opt+j" "release" \
  "pause" "go NAMEWORD" "find TITLEWORD" "name NAMEWORD3" "resume" \
  "unbind ctrl+opt+j" "unbind ctrl+opt+k" "unname NAMEWORD" "unname NAMEWORDy" \
  "title 101 TITLEWORD four" "minimize 101" "restore 101" "close 101" "close 102" \
  "state" "ascii" "menu" "doctor" "status" \
  "nonsense TITLEWORD" "dock TITLEWORD left" "zoom TITLEWORD" "name" "find" > "$home/out.txt" 2>&1

[ -s "$home/arbor.log" ] || { echo "privacy smoke test FAILED: nothing was logged, so nothing was tried"; exit 1; }
grep -q "DEBUG" "$home/arbor.log" || { echo "privacy smoke test FAILED: no debug lines, so half of it was not tried"; exit 1; }
# The words did reach Arbor: replies may say them.
grep -q "NAMEWORD" "$home/out.txt" || { echo "privacy smoke test FAILED: the names never arrived"; exit 1; }
if grep -n -e TITLEWORD -e NAMEWORD -e QUERYWORD "$home/arbor.log"; then
  echo "privacy smoke test FAILED: the lines above are in arbor.log"
  exit 1
fi

# Act two: the words are in the FILES Arbor starts on, in every place where a person can write words of their own, sound and damaged
# alike, and a trace is recorded besides. What is told to whoever asks (`doctor`, `settings`, `rules`, `displays`) is one thing; the same
# sentences also reach the log and the trace by other paths (what `doctor` finds wrong is logged at every launch), and there the words
# must not be. **A new setting that takes words, and a new way for an entry to be refused, get a line in these files.**
files=$home/files
mkdir -p "$files"
cat > "$files/settings.json" <<'JSON'
{
  "rules": [
    {"app": "com.example.safari", "title": "RULEWORD one", "action": "float"},
    {"app": "com.example.mail", "title": "RULEWORD two", "action": "OWNWORD"},
    {"title": "RULEWORD without an app", "action": "float"},
    {"app": "com.example.notes", "title": ["RULEWORD", "in a list"], "action": "float"},
    "RULEWORD that is no rule at all"
  ],
  "displays": [
    {"match": "DISPLAYWORD's iPad", "gap": 30},
    {"match": "DISPLAYWORD two", "gap": "OWNWORD"},
    {"match": "DISPLAYWORD three", "OWNWORDKey": 1},
    {"match": "DISPLAYWORD four"},
    {"match": ["DISPLAYWORD"], "gap": 10},
    {"gap": 10, "remark": "DISPLAYWORD without a match"},
    "DISPLAYWORD that is no entry at all"
  ],
  "holdStillFor": ["com.example.zoom HOLDWORD meeting", "HOLDWORD", "", 7, ["HOLDWORD"], "com.example.x  HOLDWORD   spaced"],
  "bindings": {
    "ctrl+opt+j": "go NAMEWORD", "ctrl+opt+k": "find TITLEWORD", "ctrl+opt+l": "layout Safari~TITLEWORD | Mail",
    "ctrl+opt+m": "rule add com.example.safari float title RULEWORD", "ctrl+opt+n": "BINDWORD", "ctrl+opt+o": "go",
    "ctrl+opt+p": "name BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD BINDWORD",
    "ctrl+opt+s": "bind ctrl+opt+t go NAMEWORD", "ctrl+opt+u": "bind ctrl+opt+v bind ctrl+opt+w find TITLEWORD", "ctrl+opt+x": "bind BINDWORD go NAMEWORD",
    "ctrl+opt+y": "layout @OWNWORD Safari | Mail", "ctrl+opt+z": "the OWNWORD",
    "BINDWORD+j": "home", "ctrl+opt+q": 7, "ctrl+opt+r": ["BINDWORD"]
  },
  "gap": "OWNWORD", "tileStyle": "OWNWORD", "newWindows": ["OWNWORD"], "OWNWORDKey": "OWNWORD", "animationDuration": {"OWNWORD": 1},
  "excludedBundleIDs": ["com.example.books", 7]
}
JSON
# OWNWORD stands where one of Arbor's own words was wanted (an action, a style, a key, a number): a slip is something a person typed too. The
# log says where it is, `doctor` says what. Not tried: a word where a bundle id was wanted. The log holds bundle ids, by design.
words="OWNWORD RULEWORD DISPLAYWORD HOLDWORD BINDWORD TITLEWORD NAMEWORD QUERYWORD"

# A state.json with names in it, as Arbor writes it, and one of them damaged by hand afterwards.
ARBOR_HOME=$home/first "$sim" quiet "open Safari" "open Notes" "open Mail" "dock 101 left" "dock 102 right" "zoom 101" "name NAMEWORD one" \
  "show-all" "zoom 102" "name NAMEWORD two" "show-all" "save-state $files/state.json" > /dev/null 2>&1
grep -q NAMEWORD "$files/state.json" || { echo "privacy smoke test FAILED: the names are not in state.json, so nothing was tried"; exit 1; }

second=$home/second
for state in sound damaged unreadable; do
  [ "$state" != damaged ] || sed -i.bak 's/"NAMEWORD two"/["NAMEWORD two"]/' "$files/state.json"
  # A quote too few, inside a title: Arbor says where it stopped reading, and quotes the place to whoever asks.
  [ "$state" != unreadable ] || sed -i.bak 's/"RULEWORD one"/"RULEWORD one/' "$files/settings.json"
  ARBOR_HOME=$second ARBOR_DEBUG=1 "$sim" launch --state "$files/state.json" --settings "$files/settings.json" --windows 3 --displays 2 quiet \
    "trace on files" "settings-file $files/settings.json" \
    "title 101 TITLEWORD one" "title 102 TITLEWORD two" "doctor" "status" "settings" "rules" "displays" "bindings" "spaces" "menu" "state" \
    "reload-settings" "doctor" "key ctrl+opt+j" "key ctrl+opt+k" "key ctrl+opt+l" "key ctrl+opt+m" "key ctrl+opt+n" "key ctrl+opt+p" "key ctrl+opt+y" \
    "open Safari" "open Zoom" "title 105 HOLDWORD meeting" "displays 1" "displays 2" "set gap 20" "get gap" "reset gap" \
    "rule move 1 2" "rule remove 1" "display main gap 30" "go NAMEWORD" "unname NAMEWORD one" "undo" "redo" \
    "layout @OWNWORD Safari | Mail" "set tileStyle OWNWORD" "set gap OWNWORD" "set OWNWORD 3" "get OWNWORD" "reset OWNWORD" "dock 101 OWNWORD" "dock OWNWORD" "arrange OWNWORD" \
    "display OWNWORD gap 3" "display main OWNWORD 3" "display main gap OWNWORD" "rule add com.example.books OWNWORD" "rule OWNWORD" \
    "zoom OWNWORD" "resize OWNWORD 10" "resize left OWNWORD" "focus OWNWORD" "move OWNWORD" "bind OWNWORD home" \
    "unbind OWNWORD" "key OWNWORD" "trace OWNWORD" "help OWNWORD" "OWNWORD" "OWNWORD OWNWORD" "set focusRingColour OWNWORD" "set newWindows OWNWORD" \
    "pause" "resume" "hold" "release" "health" "trace off" "quit-check" >> "$home/out2.txt" 2>&1
done

for word in OWNWORD BINDWORD RULEWORD DISPLAYWORD HOLDWORD NAMEWORD; do
  grep -q "$word" "$home/out2.txt" || { echo "privacy smoke test FAILED: $word never arrived: no reply says it, so nothing was tried"; exit 1; }
done
[ -s "$second/arbor.log" ] || { echo "privacy smoke test FAILED: act two logged nothing"; exit 1; }
grep -q "cannot be read" "$home/out2.txt" || { echo "privacy smoke test FAILED: the settings.json that cannot be read was read"; exit 1; }
grep -q "setup:" "$second/arbor.log" || { echo "privacy smoke test FAILED: what doctor finds wrong was not logged at launch, so that path was not tried"; exit 1; }
grep -q "bindings: skipped" "$second/arbor.log" || { echo "privacy smoke test FAILED: the shortcuts skipped were not logged at launch, so that path was not tried"; exit 1; }
grep -q "tileStyle cannot be used" "$second/arbor.log" || { echo "privacy smoke test FAILED: what is wrong in settings.json was not logged, so that path was not tried"; exit 1; }
ls "$second"/traces/*.jsonl > /dev/null 2>&1 || { echo "privacy smoke test FAILED: no trace was recorded"; exit 1; }
failed=0
for word in $words; do
  if grep -n -i -- "$word" "$second"/arbor.log* "$second"/traces/*.jsonl | cut -c 1-260; then failed=1; fi
done
[ "$failed" = 0 ] || { echo "privacy smoke test FAILED: the lines above are in arbor.log or in a trace"; exit 1; }
echo "privacy smoke test passed"
