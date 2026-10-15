#!/bin/bash
# Nothing is docked. A window is carried onto the second display by hand, once. From then on macOS itself takes it home when that display goes and over again when it
# comes: the most ordinary journey there is, a laptop carried to a desk and away. In the words of lib-walk.sh, by hand.
# The question (board 0.23): does Arbor set that window a frame at any plug or unplug? Played three times on one Mac: without Arbor, with it, without it.
source "$(dirname "${BASH_SOURCE[0]}")/lib-walk.sh"
walk_begin stock two defaults there-and-back
display plug
carry_across notes
display unplug
display plug
display unplug
display plug
display unplug
display plug
display unplug
walk_end
