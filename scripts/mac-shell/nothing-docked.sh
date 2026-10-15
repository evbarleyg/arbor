#!/bin/bash
# Nothing is docked. Nine real apps float, and the second display comes, goes, changes its size and its side: fourteen changes. In the words of lib-walk.sh, by hand.
# The question (board 0.23): at a change of displays macOS itself moves and resizes windows on the display that stays. Does Arbor set a frame to any of them?
# Played three times on one Mac: without Arbor, with it, without it.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
walk_begin stock two defaults nothing-docked
display plug
display unplug
display plug
display smaller
display left
display right
display unplug
display plug
display larger
display unplug
display plug
display unplug
walk_end
