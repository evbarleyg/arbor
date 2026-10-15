#!/bin/bash
# Full screen, which macOS does on a Space of its own. Last, because it is the section most likely to leave the Mac in
# a state that would confuse the others.
# T63 full-screen apps and other Spaces are left to macOS.
source "$(dirname "$0")/../lib.sh"
if [ -n "${ARBOR_REHEARSAL:-}" ]; then
  echo "full screen is the window server's doing: there is nothing to rehearse"
  exit 0
fi
arbor_build
arbor_start 3
ctl dock "$W1" left
ctl dock "$W2" right
first=$(resting_frame_of "$W1")
second=$(resting_frame_of "$W2")
# Nearly as wide as the display: wider than any slot.
read -r _ _ _ screen_w _ <<< "$(pointer displays | head -n 1)"
wide=$((screen_w - 30))

claim "a floating window goes full screen: Arbor leaves it and everything else alone"
proves T63
tw full-screen "$W3"
sleep 3
summary
take "_ _ w h" resting_frame_of "$W3"
echo "the full-screen window is $w × $h"
check "the window covers the display" eventually wider_than "$W3" "$wide"
check "Arbor keeps running" ctl status
check "it does not shrink the window back" stays wider_than "$W3" "$wide"

claim "it leaves full screen: the arrangement is as it was"
proves T63
tw full-screen "$W3"
sleep 3
summary
check "the window is small again" eventually narrower_than "$W3" "$wide"
# shellcheck disable=SC2086
check "the first docked window is where it was" eventually frame_is "$W1" $first
# shellcheck disable=SC2086
check "the second too" eventually frame_is "$W2" $second
check "both are docked" count docked 2
settled

claim "a docked window goes full screen and comes back: it returns to its slot"
proves T63
tw full-screen "$W1"
sleep 3
summary
check "the window covers the display" eventually wider_than "$W1" "$wide"
check "Arbor does not fight it" stays wider_than "$W1" "$wide"
tw full-screen "$W1"
sleep 3
summary
# shellcheck disable=SC2086
check "it is back in its slot" eventually frame_is "$W1" $first
# shellcheck disable=SC2086
check "its neighbour is where it was" eventually frame_is "$W2" $second
settled

arbor_stop
