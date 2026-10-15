#!/bin/bash
# Runs a dock/zoom/back script through arbor-sim and checks the result, so
# `make check` exercises the real controller end to end without permissions.
set -euo pipefail
cd "$(dirname "$0")/.."

output=$(.build/debug/arbor-sim \
  "open Safari" "open Notes" "open Mail" \
  "dock 101 left" "dock 102 right" "dock 103 beside 101 bottom" \
  "zoom 101" "back" "quiet" "state")

fail() {
  echo "sim smoke test failed: $1"
  echo "$output"
  exit 1
}

grep -q "docked w103 below w101" <<<"$output" || fail "docking beside did not report success"
grep -q "framed w101" <<<"$output" || fail "zoom did not report success"
grep -q "hidden: w102 Notes w103 Mail" <<<"$output" || fail "zoom did not hide the other windows"
grep -q "back to everything" <<<"$output" || fail "back did not return to the overview"
grep -q "n0 desktop" <<<"$output" || fail "state is missing the Desktop"

# Numbers no window or pointer ever has. The simulator and the commands refuse them, which `expect fail` says is
# meant (arbor-sim exits with 1 for a failure nobody expected, and with more than that when it crashes).
output=$(.build/debug/arbor-sim quiet "open Safari" "dock 101 left" \
  "resize 101 right 1e300" "expect fail" "resize 101 right nan" "expect fail" "frame-rect 0 0 inf 5" "expect fail" \
  "cursor 1e300 0" "expect fail" "drag 101 1e300 0" "expect fail" "seam 1e300 0" "expect fail" "seam 0 inf" "expect fail" \
  "pull 101 right -inf" "expect fail" "move 101 0 0 nan 5" "expect fail" \
  "open Notes 500x-inf" "ascii") || fail "an absurd number was accepted, or crashed the simulator"
[ "$(grep -c "at most ±1000000" <<<"$output")" = 3 ] || fail "a command accepted an absurd number"
[ "$(grep -c "^usage: " <<<"$output")" = 6 ] || fail "the simulator accepted an absurd number"
grep -q "w101 Safari" <<<"$output" || fail "the layout did not survive absurd numbers"

# The settings commands on a real file, as the app wires it. The words `settings` and `rule` are the product's: the
# simulator must pass them on (it once had commands of its own by those names).
folder=$(mktemp -d) || fail "no temporary folder"
trap 'rm -rf "$folder"' EXIT
printf '{\n  "gap": 8.0,\n  "myNote": "mine"\n}\n' > "$folder/settings.json"
output=$(.build/debug/arbor-sim quiet "settings-file $folder/settings.json" "set gap 20" "get gap" \
  "rule add com.example.mail dock left title Inbox" "rules" "settings") || fail "a settings command failed"
grep -q "^\* gap = 20 " <<<"$output" || fail "settings does not list the changed gap"
[ "$(head -n 3 "$folder/settings.json")" = "$(printf '{\n  "gap": 20,\n  "myNote": "mine",')" ] \
  || fail "set changed more of settings.json than the gap"

# A film (docs/FILM.md): the simulator's own words and the film's in one script, a line of JSON per frame, and no film of what Arbor refuses.
printf '%s\n' "display 1440x810 bar 24 dock 76" "open Safari 800x500" "mac-tiling off" "launch" "glide window 101 title in 0.2" "press" \
  "glide 3 400 in 0.5" "wait 0.3" "lift" "wait 0.7" "expect docked 101" "tap ctrl+opt+return" "wait 0.6" > "$folder/film.txt"
output=$(.build/debug/arbor-sim film "$folder/film.txt" --out "$folder/film.jsonl") || fail "the film script failed"
grep -q "the button is down on the title bar of w101" <<<"$output" || fail "the film's pointer missed the title bar"
grep -q "^146 frames, 2.43 s at 60 frames a second" <<<"$output" || fail "the film has the wrong length"
[ "$(wc -l < "$folder/film.jsonl" | tr -d ' ')" = 147 ] || fail "a film is a header and one line per frame"
[ "$(grep -c '"stage":' "$folder/film.jsonl")" -ge 60 ] || fail "two motions were not filmed"
echo "tap ctrl+opt+left" >> "$folder/film.txt"
if output=$(.build/debug/arbor-sim film "$folder/film.txt" --out "$folder/film.jsonl"); then fail "a film was made of a key Arbor refused"; fi
grep -q "LINE FAILED: .tap ctrl+opt+left" <<<"$output" || fail "the film does not say which line failed"
[ ! -e "$folder/film.jsonl" ] && [ -s "$folder/film.jsonl.failed" ] || fail "the frames of a film that failed are where a good film's would be"

# The stage's log of its frames (F02, "How motion is measured"): from a rehearsed stage through a trace file to the judge.
output=$(ARBOR_HOME="$folder/stage" .build/debug/arbor-sim quiet "open A" "open B" "open C" "open D" "open E" "open F" "open G" "open H" \
  rehearse-stage "trace on motion" arrange "wait 1" "zoom 101" "wait 0.2" back "wait 1" "trace off") || fail "a trace could not be recorded"
output=$(.build/debug/arbor-sim stage-judge "$folder"/stage/traces/*-motion.jsonl) || fail "the judge finds fault with a rehearsed stage"
grep -q ": 8 stand-ins, lasts 4.* ms, 460 ms planned" <<<"$output" || fail "the judge did not measure a motion of eight windows"
grep -q "retargeted 1 time" <<<"$output" || fail "the judge did not see the second command in mid-motion"
grep -q "^2 motions, none with findings$" <<<"$output" || fail "the judge did not sum up"
output=$(.build/debug/arbor-sim stage-judge gap=0.01 < "$(ls "$folder"/stage/traces/*-motion.jsonl)") && fail "a limit nobody meets was met"
grep -q "✘ gap: .*16.7 ms without a frame" <<<"$output" || fail "the judge did not say what it found"
python3 scripts/trace-check.py "$folder"/stage/traces/*-motion.jsonl > /dev/null || fail "trace-check finds words in the stage's lines"
echo "sim smoke test passed"

# The same for the control socket: the real arborctl against the simulator.
./scripts/watch-smoke.sh
./scripts/cli-smoke.sh
