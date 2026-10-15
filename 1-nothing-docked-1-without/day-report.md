28 steps in 159 s, 13 of them judged, 0 with a rule broken. The sampler: samples 2915 seconds 91.9 hz 31.7 cost-ms 3.68 late 23 longest-gap-ms 539 whole-samples 5071 whole-seconds 159.9 whole-late 126.
The round of input `before` (events, half within µs): forward 8, 33596; up 8, 845.
The round of input `after` (events, half within µs): forward 8, 38081; up 8, 1249.
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
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 533 ms; blind for 398 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 446 ms; blind for 2731 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (2, 185 ms) | quiet 1074 ms; blind for 320 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (3, 276 ms) | quiet 906 ms; blind for 245 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (2, 71 ms), w53 ×2 (10, 1220 ms), w55 ×2 (5, 1190 ms) | quiet 357 ms; blind for 137 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (4, 363 ms) | quiet 1305 ms; blind for 123 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings |  | quiet 493 ms; blind for 241 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (2, 83 ms) | quiet 570 ms; blind for 628 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | mail ×1 (2, 51 ms), w67 ×1 (4, 184 ms) | quiet 693 ms; blind for 421 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (32, 4302 ms) | quiet 1350 ms; blind for 131 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (37, 2536 ms) | quiet 1060 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 432 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 713 ms; blind for 152 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | display-plug | the second display: plug | textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 365 ms; blind for 539 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 15 | display-unplug | the second display: unplug |  | quiet 375 ms; blind for 141 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 16 | display-plug | the second display: plug |  | quiet 371 ms; blind for 209 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 17 | display-unplug | the second display: unplug |  | quiet 375 ms; blind for 415 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 18 | display-plug | the second display: plug |  | quiet 407 ms; blind for 182 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 19 | display-left | the second display: left |  | quiet 385 ms; blind for 128 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 20 | display-right | the second display: right |  | quiet 376 ms; blind for 107 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 21 | display-unplug | the second display: unplug |  | quiet 430 ms; blind for 223 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 22 | display-plug | the second display: plug |  | quiet 368 ms; blind for 205 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 23 | display-unplug | the second display: unplug |  | quiet 356 ms; blind for 191 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 24 | display-plug | the second display: plug |  | quiet 421 ms; blind for 210 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 25 | display-unplug | the second display: unplug |  | quiet 366 ms; blind for 278 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 26 | display-plug | the second display: plug |  | quiet 421 ms; blind for 208 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 27 | display-unplug | the second display: unplug |  | quiet 393 ms; blind for 165 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 28 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 716 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
