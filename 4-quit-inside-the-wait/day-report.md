37 steps in 153 s, 22 of them judged, 1 with a rule broken. The sampler: samples 3446 seconds 91.2 hz 37.8 cost-ms 2.95 late 6 longest-gap-ms 348 whole-samples 5812 whole-seconds 153.8 whole-late 21.
Input: 2 presses, releases, keys and scrolls reached the apps, half of them within 480 µs, 99 in 100 within 480 µs, the latest after 480 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): key 2, 480, 480. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 27963; up 8, 507.
The round of input `started` (events, half within µs): forward 8, 31062; up 8, 777.
The round of input `last` (events, half within µs): forward 8, 42314; up 8, 1090.
The round of input `after` (events, half within µs): forward 8, 44671; up 8, 1762.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 18 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 23 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 9 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 1 | 1 | 27 quit |
| 6 | what a person presses reaches the apps, at once | 13 | 0 |  |
| L | no window is lost or stuck | 23 | 0 |  |
| - | what the script itself checked | 23 | 0 |  |

## Findings

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **27 quit** (chooses Quit Arbor in Arbor's menu): textedit (w1341) is 165,65 656×422; its own size was 165,65 673×439 [size-lost]
- ✘ **27 quit** (chooses Quit Arbor in Arbor's menu): terminal (w1344) is 40,51 863×499; its own size was 40,51 877×499 [size-lost]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (3, 95 ms) | quiet 971 ms; blind for 102 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 382 ms; blind for 1913 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (5, 333 ms) | quiet 1259 ms; blind for 563 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (6, 352 ms) | quiet 1237 ms; blind for 136 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (3, 95 ms) | quiet 1023 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (3, 281 ms) | quiet 1331 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 492 ms; blind for 475 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (3, 73 ms) | quiet 1025 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w1356 ×1 (5, 174 ms) | quiet 806 ms; blind for 783 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×1 (27, 2109 ms) | quiet 1041 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (29, 2953 ms) | quiet 1123 ms |  |  |  |  |  |  |  |  |
| 12 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (33, 4100 ms) | quiet 1440 ms |  |  |  |  |  |  |  |  |
| 13 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (35, 2144 ms) | quiet 999 ms |  |  |  |  |  |  |  |  |
| 14 | look-around | looks at the screen |  | quiet 421 ms |  |  |  |  |  |  |  |  |
| 15 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 707 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 16 | launch | starts Arbor |  | quiet 1259 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 17 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 730 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 18 | display-plug-and-quit | the second display: plug, and Arbor is quit within the second | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms) | quiet 404 ms; blind for 348 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 19 | launch | starts Arbor |  | quiet 371 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 20 | display-unplug-and-quit | the second display: unplug, and Arbor is quit within the second |  | quiet 377 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 21 | launch | starts Arbor |  | quiet 366 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 22 | display-plug-and-quit | the second display: plug, and Arbor is quit within the second |  | quiet 398 ms; blind for 114 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 23 | launch | starts Arbor |  | quiet 439 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 24 | display-unplug-and-quit | the second display: unplug, and Arbor is quit within the second |  | quiet 392 ms; blind for 111 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 25 | launch | starts Arbor |  | quiet 353 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 26 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 742 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 27 | quit | chooses Quit Arbor in Arbor's menu |  | quiet 431 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 28 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 754 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 29 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 394 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 424 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 435 ms; blind for 109 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 389 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 427 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 429 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 412 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 36 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 365 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 350 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
