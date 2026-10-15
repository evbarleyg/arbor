47 steps in 206 s, 26 of them judged, 5 with a rule broken. The sampler: samples 5011 seconds 137.1 hz 36.6 cost-ms 3.03 late 30 longest-gap-ms 744 whole-samples 7580 whole-seconds 207.4 whole-late 51.
Input: 39 presses, releases, keys and scrolls reached the apps, half of them within 2591 µs, 99 in 100 within 22333 µs, the latest after 22333 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 2, 10810, 10810; dragged 33, 2709, 22333; key 2, 658, 658; up 2, 1689, 1689. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 42143; up 8, 511.
The round of input `started` (events, half within µs): forward 8, 36061; up 8, 3715.
The round of input `last` (events, half within µs): forward 8, 45788; up 8, 5762.
The round of input `after` (events, half within µs): forward 8, 39761; up 8, 478.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 1 | 0 |  |
| 2 | nothing moves that the person did not move | 16 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 33 | 4 | 21 carry-notes-across, 22 display-unplug, 26 display-unplug, 32 display-plug |
| 4 | the window you switch to comes to the front and into view | 11 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 1 | 1 | 37 quit |
| 6 | what a person presses reaches the apps, at once | 15 | 0 |  |
| L | no window is lost or stuck | 33 | 0 |  |
| - | what the script itself checked | 33 | 0 |  |

## Findings

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **21 carry-notes-across** (drags notes, which floats, by its title bar onto the other display and lets go): notes (w369) moved 59 points further than the pointer did, 2810 ms into the step [pulled]
  - +0 ms 358,166 1000×600 · +71 ms 417,167 1000×600 · +129 ms 475,169 1000×600 · +197 ms 534,170 1000×600 · +268 ms 592,172 1000×600 · +404 ms 651,173 1000×600 · … 15 more … · +1766 ms 1880,203 1000×600 · +1879 ms 1997,206 1000×600 · +1946 ms 2056,208 1000×600 · +2153 ms 2057,208 1000×600 · +2830 ms 2056,208 1000×600
- ✘ **22 display-unplug** (the second display: unplug): notes (w369) moved 2 times [jolt]
  - +0 ms 2056,208 1000×600 · +21 ms 297,130 1000×600 · +549 ms 300,165 1000×600
- ✘ **26 display-unplug** (the second display: unplug): notes (w369) went 70 points out of its way before it ended up [jolt]
  - +0 ms 2056,208 1000×600 · +-2 ms 297,130 1000×600 · +189 ms 300,165 1000×600
- ✘ **32 display-plug** (the second display: plug): notes (w369) moved 2 times [jolt]
  - +0 ms 300,165 1000×600 · +62 ms 2060,264 1000×600 · +466 ms 2056,208 1000×600

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **37 quit** (chooses Quit Arbor in Arbor's menu): textedit (w363) is 165,65 656×422; its own size was 165,65 673×439 [size-lost]
- ✘ **37 quit** (chooses Quit Arbor in Arbor's menu): terminal (w366) is 40,51 863×499; its own size was 40,51 877×499 [size-lost]
- ✘ **37 quit** (chooses Quit Arbor in Arbor's menu): notes (w369) has its size back but not its place: 300,165 1000×600, it was at 2056,208 1000×600 [size-lost]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (2, 54 ms) | quiet 1064 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 416 ms; blind for 1351 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (3, 230 ms) | quiet 1211 ms; blind for 305 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (5, 322 ms) | quiet 1291 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (4, 138 ms) | quiet 1056 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×2 (4, 338 ms) | quiet 1363 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×2 (2, 364 ms) | quiet 881 ms; blind for 463 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (3, 62 ms) | quiet 1062 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w379 ×1 (4, 232 ms) | quiet 757 ms; blind for 1549 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (28, 2248 ms) | quiet 1041 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (31, 3004 ms) | quiet 1027 ms |  |  |  |  |  |  |  |  |
| 12 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (27, 4547 ms) | quiet 1428 ms |  |  |  |  |  |  |  |  |
| 13 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (31, 2280 ms) | quiet 1031 ms; blind for 179 ms |  |  |  |  |  |  |  |  |
| 14 | look-around | looks at the screen |  | quiet 394 ms |  |  |  |  |  |  |  |  |
| 15 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 628 ms; blind for 408 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 16 | launch | starts Arbor |  | quiet 1180 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 17 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 676 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 18 | display-plug | the second display: plug | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms) | quiet 401 ms; blind for 744 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 19 | view-home | chooses `home` from Arbor's menu |  | quiet 403 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 20 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 367 ms; blind for 137 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | carry-notes-across | drags notes, which floats, by its title bar onto the other display and lets go |  | quiet 1172 ms; blind for 241 ms | ✔ | ✔ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 22 | display-unplug | the second display: unplug | notes ×2 (2, 528 ms) | quiet 398 ms; blind for 527 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 23 | view-home | chooses `home` from Arbor's menu |  | quiet 371 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 24 | display-plug | the second display: plug | notes ×1 (1, 0 ms) | quiet 356 ms; blind for 431 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 25 | view-home | chooses `home` from Arbor's menu |  | quiet 437 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 26 | display-unplug | the second display: unplug | notes ×1 (2, 191 ms) | quiet 378 ms; blind for 190 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 27 | view-home | chooses `home` from Arbor's menu |  | quiet 402 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 28 | display-plug | the second display: plug | notes ×1 (1, 0 ms) | quiet 412 ms; blind for 338 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 29 | view-home | chooses `home` from Arbor's menu |  | quiet 378 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 30 | display-unplug | the second display: unplug | notes ×1 (1, 0 ms) | quiet 407 ms; blind for 266 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 31 | view-home | chooses `home` from Arbor's menu |  | quiet 381 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 32 | display-plug | the second display: plug | notes ×2 (2, 404 ms) | quiet 373 ms; blind for 404 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 33 | view-home | chooses `home` from Arbor's menu |  | quiet 364 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 34 | display-unplug | the second display: unplug | notes ×1 (1, 0 ms) | quiet 370 ms; blind for 222 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 35 | view-home | chooses `home` from Arbor's menu |  | quiet 369 ms |  |  | ✔ |  |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 36 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 642 ms; blind for 240 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 37 | quit | chooses Quit Arbor in Arbor's menu |  | quiet 786 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 38 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 811 ms; blind for 156 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 39 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 455 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 404 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 379 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 453 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 430 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 472 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 558 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 46 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 370 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 379 ms; blind for 120 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
