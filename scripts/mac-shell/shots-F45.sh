#!/bin/bash
# F45 on real windows: a window that is a tile because it refused its slot is asked again where nobody can see.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/shots-F45.sh
#
# What only a Mac can settle:
# - does a real window that is resized in its corner stay out of view all the while (nothing flickers);
# - does a window that really cannot shrink stay a tile, with its neighbours untouched, however often it is asked;
# - does `relayout`, which tries in view, end with the tile and the neighbours where they were;
# - does a window whose app has lowered its minimum since come back into its slot by itself.
#
# The interval is set to three seconds (`tileRetryMinutes` 0.05), so that a run does not take ten minutes.
source "$(dirname "$0")/lib.sh"

# The largest share of the window seen on a display while `show-all` lays the display out <count> times.
most_seen_during_layouts() {
  local id=$1 count=$2 most=0 seen
  while [ "$count" -gt 0 ]; do
    "$ARBOR_BIN/arborctl" show-all > /dev/null &
    for _ in 1 2 3 4 5 6; do
      seen=$(pointer visible "$id")
      most=$(awk 'BEGIN { print (ARGV[1] > ARGV[2]) ? ARGV[1] : ARGV[2] }' "$seen" "$most")
    done
    wait $!
    sleep 0.4
    count=$((count - 1))
  done
  echo "$most"
}
at_most() { awk 'BEGIN { exit !(ARGV[1] <= ARGV[2]) }' "$1" "$2"; }
questions() { grep -c "still refuses the size of its slot" "$ARBOR_HOME/arbor.log"; }
in_its_slot() { [ "$(arbor_ask slot "$1" 2>/dev/null)" = "$(real_frame_of "$1")" ]; }
# Sends ArborTestWindows a request; fails if it is one that does not answer requests.
ask_test_windows() {
  local before tries=0
  before=$(wc -l < "$ARBOR_SESSION_DIR/hello")
  echo "$*" >&9
  while [ "$(wc -l < "$ARBOR_SESSION_DIR/hello")" -le "$before" ]; do
    [ "$tries" -ge 15 ] && return 1
    sleep 0.1
    tries=$((tries + 1))
  done
  tail -n 1 "$ARBOR_SESSION_DIR/hello" | grep -q '"ok":true'
}

arbor_build
# On a large screen Arbor would make room for it instead (F61), and there would be no tile to show.
arbor_settings '{"tileRetryMinutes": 0.05, "makeRoom": false}'
# The third window refuses to be smaller than 700×500.
ARBOR_TEST_WINDOWS_ARGS=${ARBOR_TEST_WINDOWS_ARGS:---min-size 3:700x500}
arbor_start 3

step "a window that cannot shrink to its slot becomes a tile"
ctl dock "$W1" left
ctl dock "$W2" right
ctl dock "$W3" beside "$W2" bottom
ctl show-all
check "it is a tile" eventually is tile "$W3"
check "it is out of view" eventually at_most "$(pointer visible "$W3")" 0.01
shot 01-tile
summary
F1=$(real_frame_of "$W1"); F2=$(real_frame_of "$W2")

step "asked every three seconds for about ten, it never shows, and nothing else moves"
before=$(questions)
most=$(most_seen_during_layouts "$W3" 20)
asked=$(($(questions) - before))
echo "asked $asked times; at most $most of it was on a display at any of 120 looks"
check "it was asked at all" test "$asked" -ge 2
check "and not with every layout" test "$asked" -le 8
check "it never came into view" at_most "$most" 0.01
check "it is still a tile" is tile "$W3"
check "the first window has not moved" test "$(real_frame_of "$W1")" = "$F1"
check "the second window has not moved" test "$(real_frame_of "$W2")" = "$F2"
echo "it is parked at $(real_frame_of "$W3")"
"$ARBOR_BIN/arborctl" show-all > /dev/null &
film 02-while-asked 4
wait $!

step "relayout tries in view, and ends where it began"
ctl relayout &
film 03-relayout 4
wait $!
check "it is a tile again" eventually is tile "$W3"
check "it is out of view again" eventually at_most "$(pointer visible "$W3")" 0.01
check "the first window is where it was" eventually test "$(real_frame_of "$W1")" = "$F1"
check "the second window is where it was" eventually test "$(real_frame_of "$W2")" = "$F2"
shot 04-after-relayout

step "the app lowers its minimum: the window comes back by itself"
# The real-window suite's ArborTestWindows answers `min`. The one before it takes `min-size` and says nothing.
ask_test_windows "min $W3 200x150" || echo "min-size $W3 200 150" >&9
sleep 3.5
"$ARBOR_BIN/arborctl" show-all > /dev/null &
film 05-coming-back 4
wait $!
check "it is no longer a tile" eventually sh -c "! '$ARBOR_BIN/arborctl' state | python3 '$ARBOR_STATE_PY' is $W3 tile"
check "it is in its slot" eventually in_its_slot "$W3"
check "the first window has not moved" test "$(real_frame_of "$W1")" = "$F1"
shot 06-back
summary

arbor_stop 07-after-quit
