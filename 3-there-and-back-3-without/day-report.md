24 steps in 116 s, 5 of them judged, 6 with a rule broken. The sampler: samples 2540 seconds 70.5 hz 36.0 cost-ms 3.97 late 13 longest-gap-ms 685 whole-samples 4220 whole-seconds 117.1 whole-late 33.
Input: 37 presses, releases, keys and scrolls reached the apps, half of them within 597 µs, 99 in 100 within 3700 µs, the latest after 3700 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 2, 2274, 2274; dragged 33, 597, 3700; up 2, 1629, 1629. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 39954; up 8, 959.
The round of input `after` (events, half within µs): forward 8, 34361; up 8, 1428.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 1 | 0 |  |
| 2 | nothing moves that the person did not move | 4 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 12 | 6 | 17 display-unplug, 18 display-plug, 19 display-unplug, 20 display-plug, 21 display-unplug, 22 display-plug |
| 4 | the window you switch to comes to the front and into view | 2 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 4 | 0 |  |
| L | no window is lost or stuck | 12 | 0 |  |
| - | what the script itself checked | 12 | 0 |  |

## Findings

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **17 display-unplug** (the second display: unplug): notes (w720) moved 2 times [jolt]
  - +0 ms 2056,208 1000×600 · +16 ms 297,130 1000×600 · +399 ms 300,165 1000×600
- ✘ **18 display-plug** (the second display: plug): notes (w720) moved 2 times [jolt]
  - +0 ms 300,165 1000×600 · +42 ms 2060,264 1000×600 · +728 ms 2056,208 1000×600
- ✘ **19 display-unplug** (the second display: unplug): notes (w720) moved 2 times [jolt]
  - +0 ms 2056,208 1000×600 · +-3 ms 297,130 1000×600 · +555 ms 300,165 1000×600
- ✘ **20 display-plug** (the second display: plug): notes (w720) moved 2 times [jolt]
  - +0 ms 300,165 1000×600 · +40 ms 2060,264 1000×600 · +371 ms 2056,208 1000×600
- ✘ **21 display-unplug** (the second display: unplug): notes (w720) moved 2 times [jolt]
  - +0 ms 2056,208 1000×600 · +2 ms 297,130 1000×600 · +558 ms 300,165 1000×600
- ✘ **22 display-plug** (the second display: plug): notes (w720) moved 2 times [jolt]
  - +0 ms 300,165 1000×600 · +34 ms 2060,264 1000×600 · +332 ms 2056,208 1000×600

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (3, 87 ms) | quiet 951 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 357 ms; blind for 1209 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (5, 333 ms) | quiet 1358 ms; blind for 206 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (5, 337 ms) | quiet 1173 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (4, 56 ms) | quiet 1005 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar |  | quiet 968 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings |  | quiet 700 ms; blind for 352 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (4, 86 ms) | quiet 1026 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w732 ×1 (3, 136 ms) | quiet 740 ms; blind for 1194 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (37, 4241 ms) | quiet 1382 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (36, 2997 ms) | quiet 1070 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 386 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 679 ms; blind for 188 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | display-plug | the second display: plug | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms) | quiet 405 ms; blind for 312 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 15 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 418 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 16 | carry-notes-across | drags notes, which floats, by its title bar onto the other display and lets go |  | quiet 1047 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | display-unplug | the second display: unplug | notes ×2 (2, 383 ms) | quiet 357 ms; blind for 382 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 18 | display-plug | the second display: plug | notes ×2 (2, 686 ms) | quiet 412 ms; blind for 685 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 19 | display-unplug | the second display: unplug | notes ×2 (2, 558 ms) | quiet 359 ms; blind for 558 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 20 | display-plug | the second display: plug | notes ×2 (2, 331 ms) | quiet 361 ms; blind for 331 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 21 | display-unplug | the second display: unplug | notes ×2 (2, 556 ms) | quiet 374 ms; blind for 555 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 22 | display-plug | the second display: plug | notes ×2 (2, 298 ms) | quiet 353 ms; blind for 298 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 23 | display-unplug | the second display: unplug | notes ×1 (1, 0 ms) | quiet 391 ms; blind for 177 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 24 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 633 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
