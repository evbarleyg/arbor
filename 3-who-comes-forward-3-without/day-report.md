41 steps in 143 s, 24 of them judged, 2 with a rule broken. The sampler: samples 2696 seconds 75.2 hz 35.9 cost-ms 3.49 late 24 longest-gap-ms 1687 whole-samples 5162 whole-seconds 144.0 whole-late 47.
Input: 38 presses, releases, keys and scrolls reached the apps, half of them within 745 µs, 99 in 100 within 286095 µs, the latest after 286095 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 16, 793, 286095; key 6, 631, 924; up 16, 745, 183713. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 52235; up 8, 1194.
The round of input `after` (events, half within µs): forward 1, 83775; up 1, 3644.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 27 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 27 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 19 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 18 | 2 | 17 dock-icon-mail, 21 dock-icon-textedit |
| L | no window is lost or stuck | 27 | 0 |  |
| - | what the script itself checked | 27 | 0 |  |

## Findings

### Rule 6: what a person presses reaches the apps, at once

- ✘ **17 dock-icon-mail** (clicks mail's icon in the Dock): the button came up, and the apps heard of it 160 ms later [input-held]
- ✘ **21 dock-icon-textedit** (clicks textedit's icon in the Dock): the button came up, and the apps heard of it 183 ms later [input-held]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 880 ms; blind for 106 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 369 ms; blind for 1539 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (2, 224 ms) | quiet 1120 ms; blind for 547 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×2 (6, 370 ms) | quiet 1260 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (4, 103 ms) | quiet 1057 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (7, 350 ms) | quiet 1357 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×2 (2, 656 ms) | quiet 919 ms; blind for 647 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (6, 103 ms) | quiet 943 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w356 ×1 (5, 121 ms) | quiet 688 ms; blind for 902 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (30, 3592 ms) | quiet 1066 ms; blind for 136 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (30, 2174 ms) | quiet 1077 ms |  |  |  |  |  |  |  |  |
| 12 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (32, 4157 ms) | quiet 1437 ms |  |  |  |  |  |  |  |  |
| 13 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (34, 2200 ms) | quiet 1036 ms |  |  |  |  |  |  |  |  |
| 14 | look-around | looks at the screen |  | quiet 398 ms |  |  |  |  |  |  |  |  |
| 15 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 617 ms; blind for 159 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 16 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 390 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 377 ms; blind for 190 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 18 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 441 ms; blind for 162 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | quit-preview | presses ⌘Q in preview |  | quiet 946 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 20 | reopen-preview | opens preview's document again |  | quiet 1081 ms; blind for 201 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 21 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 354 ms; blind for 688 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 22 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 558 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | hide-calendar | presses ⌘H |  | quiet 931 ms; blind for 125 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 24 | unhide-calendar | clicks its icon in the Dock |  | quiet 403 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 370 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 359 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | quit-safari | presses ⌘Q in safari |  | quiet 994 ms; blind for 164 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 28 | reopen-safari | opens safari's document again |  | quiet 430 ms; blind for 1687 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 29 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 500 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 365 ms; blind for 115 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | quit-textedit | presses ⌘Q in textedit |  | quiet 860 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 32 | reopen-textedit | opens textedit's document again |  | quiet 803 ms; blind for 363 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 33 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 416 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 547 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | hide-finder | presses ⌘H |  | quiet 929 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 36 | unhide-finder | clicks its icon in the Dock |  | quiet 400 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 424 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 447 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | minimize-calendar | presses ⌘M | calendar ×1 (21, 437 ms) | quiet 1003 ms; blind for 117 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 40 | restore-calendar | clicks its miniature in the Dock | calendar ×1 (18, 507 ms) | quiet 1004 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 389 ms; blind for 105 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
