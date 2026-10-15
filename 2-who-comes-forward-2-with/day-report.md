54 steps in 199 s, 36 of them judged, 1 with a rule broken. The sampler: samples 4468 seconds 122.9 hz 36.4 cost-ms 2.86 late 27 longest-gap-ms 1192 whole-samples 7284 whole-seconds 200.3 whole-late 47.
Input: 40 presses, releases, keys and scrolls reached the apps, half of them within 733 µs, 99 in 100 within 52721 µs, the latest after 52721 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 16, 894, 1490; key 8, 545, 4292; up 16, 682, 52721. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 51430; up 8, 3140.
The round of input `started` (events, half within µs): forward 8, 48918; up 8, 2893.
The round of input `last` (events, half within µs): forward 1, 58664; up 1, 3777.
The round of input `after` (events, half within µs): .
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 39 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 40 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 28 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 1 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 28 | 0 |  |
| L | no window is lost or stuck | 40 | 0 |  |
| - | what the script itself checked | 40 | 1 | 44 quit |

## Findings

### Rule -: what the script itself checked

- ✘ **44 quit** (chooses Quit Arbor in Arbor's menu): Arbor's process ended, and nobody asked it to [crash]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 718 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 358 ms; blind for 1988 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (3, 242 ms) | quiet 1276 ms; blind for 555 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (5, 337 ms) | quiet 1077 ms; blind for 128 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (2, 72 ms) | quiet 921 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (4, 355 ms) | quiet 1078 ms; blind for 108 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (3, 261 ms) | quiet 530 ms; blind for 409 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (1, 0 ms) | quiet 967 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w190 ×1 (3, 87 ms) | quiet 516 ms; blind for 1058 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (31, 4051 ms) | quiet 1113 ms; blind for 170 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (27, 2804 ms) | quiet 1016 ms |  |  |  |  |  |  |  |  |
| 12 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (30, 4126 ms) | quiet 1419 ms |  |  |  |  |  |  |  |  |
| 13 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (35, 3081 ms) | quiet 1038 ms |  |  |  |  |  |  |  |  |
| 14 | look-around | looks at the screen |  | quiet 377 ms |  |  |  |  |  |  |  |  |
| 15 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 726 ms; blind for 138 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 16 | launch | starts Arbor |  | quiet 579 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 17 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 724 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 18 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 351 ms; blind for 300 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 544 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 352 ms; blind for 102 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | quit-preview | presses ⌘Q in preview |  | quiet 956 ms; blind for 145 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 22 | reopen-preview | opens preview's document again |  | quiet 1024 ms; blind for 680 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 23 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 393 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 430 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | hide-calendar | presses ⌘H |  | quiet 876 ms; blind for 173 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 26 | unhide-calendar | clicks its icon in the Dock |  | quiet 467 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 437 ms; blind for 123 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 394 ms; blind for 107 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 29 | quit-safari | presses ⌘Q in safari |  | quiet 913 ms; blind for 203 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 30 | reopen-safari | opens safari's document again |  | quiet 393 ms; blind for 1192 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 31 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 421 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 380 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | quit-textedit | presses ⌘Q in textedit |  | quiet 843 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 34 | reopen-textedit | opens textedit's document again |  | quiet 670 ms; blind for 452 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 35 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 435 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 36 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 548 ms; blind for 105 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | hide-finder | presses ⌘H |  | quiet 967 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 38 | unhide-finder | clicks its icon in the Dock |  | quiet 384 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 555 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 474 ms; blind for 114 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | minimize-calendar | presses ⌘M | calendar ×1 (16, 453 ms) | quiet 1063 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 42 | restore-calendar | clicks its miniature in the Dock | calendar ×1 (14, 392 ms) | quiet 822 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 43 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 364 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 44 | quit | chooses Quit Arbor in Arbor's menu |  | quiet 949 ms |  |  | ✔ |  | ✔ |  | ✔ | ✘ |
| 45 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 426 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 46 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 379 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 529 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 364 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 436 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 401 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 363 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 548 ms; blind for 118 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 53 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 390 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 54 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 389 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
