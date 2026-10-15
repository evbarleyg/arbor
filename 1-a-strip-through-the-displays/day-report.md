45 steps in 275 s, 26 of them judged, 2 with a rule broken. The sampler: samples 6643 seconds 198.3 hz 33.5 cost-ms 4.10 late 33 longest-gap-ms 1988 whole-samples 9273 whole-seconds 276.8 whole-late 146.
Input: 109 presses, releases, keys and scrolls reached the apps, half of them within 1449 µs, 99 in 100 within 21547 µs, the latest after 28832 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 4, 6946, 20081; dragged 99, 1456, 28832; key 2, 17256, 17256; up 4, 1010, 1211. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 70907; up 8, 4916.
The round of input `started` (events, half within µs): forward 8, 40168; up 8, 1086.
The round of input `last` (events, half within µs): forward 9, 37891; up 9, 2760.
The round of input `after` (events, half within µs): forward 8, 38093; up 8, 1674.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 3 | 0 |  |
| 2 | nothing moves that the person did not move | 19 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 32 | 1 | 29 display-plug |
| 4 | the window you switch to comes to the front and into view | 14 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 1 | 1 | 35 quit |
| 6 | what a person presses reaches the apps, at once | 17 | 0 |  |
| L | no window is lost or stuck | 32 | 0 |  |
| - | what the script itself checked | 32 | 0 |  |

## Findings

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **29 display-plug** (the second display: plug): notes (w50) moved 2 times [jolt]
  - +0 ms -406,105 1000×660 · +209 ms 0,105 1000×660 · +929 ms -406,105 1000×660

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **35 quit** (chooses Quit Arbor in Arbor's menu): textedit (w43) is 165,65 656×422; its own size was 165,65 673×439 [size-lost]
- ✘ **35 quit** (chooses Quit Arbor in Arbor's menu): terminal (w49) is 40,51 863×499; its own size was 40,51 877×499 [size-lost]
- ✘ **35 quit** (chooses Quit Arbor in Arbor's menu): notes (w50) has its size back but not its place: 0,105 1000×660, it was at -406,105 1000×660 [size-lost]

### Rule -: what the script itself checked

- ~ **17 push-notes-aside** (drags notes, which floats, by its title bar towards the left edge of the screen and lets go): the act was not performed: drag_window could not be done [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder |  | quiet 466 ms; blind for 282 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 398 ms; blind for 1337 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (2, 214 ms) | quiet 724 ms; blind for 1325 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (4, 245 ms) | quiet 984 ms; blind for 362 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | w51 ×2 (8, 1568 ms), w53 ×1 (6, 220 ms) | quiet 406 ms; blind for 449 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (5, 324 ms) | quiet 1306 ms; blind for 130 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 422 ms; blind for 653 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview |  | quiet 479 ms; blind for 1790 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 527 ms; blind for 376 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (37, 4157 ms) | quiet 1433 ms; blind for 135 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (36, 2603 ms) | quiet 1042 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 433 ms; blind for 116 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 783 ms; blind for 163 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | launch | starts Arbor |  | quiet 1253 ms; blind for 165 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 15 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 619 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 16 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 397 ms; blind for 266 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | push-notes-aside | drags notes, which floats, by its title bar towards the left edge of the screen and lets go |  | quiet 1054 ms; blind for 130 ms |  |  |  |  |  |  |  | ~ |
| 18 | push-notes-aside | drags notes, which floats, by its title bar towards the left edge of the screen and lets go |  | quiet 999 ms; blind for 101 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | push-notes-aside | drags notes, which floats, by its title bar towards the left edge of the screen and lets go |  | quiet 1101 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | push-notes-aside | drags notes, which floats, by its title bar towards the left edge of the screen and lets go |  | quiet 1021 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | display-plug | the second display: plug | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 377 ms; blind for 1988 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 22 | view-home | chooses `home` from Arbor's menu |  | quiet 353 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 23 | display-unplug | the second display: unplug | notes ×1 (1, 0 ms) | quiet 376 ms; blind for 603 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 24 | view-home | chooses `home` from Arbor's menu |  | quiet 356 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 25 | display-plug | the second display: plug | notes ×1 (1, 0 ms) | quiet 356 ms; blind for 317 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 26 | view-home | chooses `home` from Arbor's menu |  | quiet 364 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 27 | display-unplug | the second display: unplug | notes ×1 (1, 0 ms) | quiet 416 ms; blind for 498 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 28 | view-home | chooses `home` from Arbor's menu |  | quiet 377 ms; blind for 122 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 29 | display-plug | the second display: plug | notes ×2 (2, 720 ms) | quiet 351 ms; blind for 357 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 30 | view-home | chooses `home` from Arbor's menu |  | quiet 374 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 31 | display-unplug | the second display: unplug | notes ×1 (1, 0 ms) | quiet 367 ms; blind for 248 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 32 | view-home | chooses `home` from Arbor's menu |  | quiet 372 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 33 | leave-alone | does nothing for half a minute |  | quiet 368 ms; blind for 177 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 34 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 663 ms; blind for 222 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 35 | quit | chooses Quit Arbor in Arbor's menu |  | quiet 800 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 36 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 653 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 37 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 432 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 430 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 405 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 707 ms; blind for 127 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 415 ms; blind for 103 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 436 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 630 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 397 ms; blind for 101 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 366 ms; blind for 193 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
