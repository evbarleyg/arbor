30 steps in 141 s, 15 of them judged, 0 with a rule broken. The sampler: samples 3336 seconds 86.1 hz 38.8 cost-ms 2.20 late 13 longest-gap-ms 371 whole-samples 5520 whole-seconds 142.4 whole-late 24.
The round of input `before` (events, half within µs): forward 8, 42731; up 8, 824.
The round of input `after` (events, half within µs): forward 8, 25412; up 8, 590.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 2 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 16 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 0 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 2 | 0 |  |
| L | no window is lost or stuck | 16 | 0 |  |
| - | what the script itself checked | 16 | 0 |  |

## Findings

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (2, 63 ms) | quiet 1093 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 618 ms; blind for 588 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit |  | quiet 907 ms; blind for 1136 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (4, 303 ms) | quiet 1305 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (5, 85 ms) | quiet 990 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (4, 351 ms) | quiet 1378 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (2, 99 ms) | quiet 715 ms; blind for 342 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (3, 124 ms) | quiet 1129 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w942 ×1 (6, 232 ms) | quiet 867 ms; blind for 981 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (30, 3764 ms) | quiet 1025 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (30, 2158 ms) | quiet 1083 ms |  |  |  |  |  |  |  |  |
| 12 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (31, 3823 ms) | quiet 1432 ms |  |  |  |  |  |  |  |  |
| 13 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (36, 2342 ms) | quiet 1028 ms |  |  |  |  |  |  |  |  |
| 14 | look-around | looks at the screen |  | quiet 386 ms |  |  |  |  |  |  |  |  |
| 15 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 726 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 16 | display-plug | the second display: plug | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms) | quiet 380 ms; blind for 371 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 17 | display-unplug | the second display: unplug |  | quiet 358 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 18 | display-plug | the second display: plug |  | quiet 384 ms; blind for 157 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 19 | display-unplug | the second display: unplug |  | quiet 378 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 20 | display-plug | the second display: plug |  | quiet 367 ms; blind for 148 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 21 | display-left | the second display: left |  | quiet 415 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 22 | display-right | the second display: right |  | quiet 350 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 23 | display-unplug | the second display: unplug |  | quiet 402 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 24 | display-plug | the second display: plug |  | quiet 362 ms; blind for 125 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 25 | display-unplug | the second display: unplug |  | quiet 378 ms; blind for 102 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 26 | display-plug | the second display: plug |  | quiet 356 ms; blind for 144 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 27 | display-unplug | the second display: unplug |  | quiet 384 ms; blind for 140 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 28 | display-plug | the second display: plug |  | quiet 376 ms; blind for 136 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 29 | display-unplug | the second display: unplug |  | quiet 362 ms; blind for 211 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 30 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 724 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
