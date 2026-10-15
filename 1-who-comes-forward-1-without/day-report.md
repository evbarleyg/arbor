49 steps in 153 s, 32 of them judged, 0 with a rule broken. The sampler: samples 2964 seconds 90.8 hz 32.6 cost-ms 3.93 late 22 longest-gap-ms 896 whole-samples 5047 whole-seconds 154.6 whole-late 67.
Input: 55 presses, releases, keys and scrolls reached the apps, half of them within 348 µs, 99 in 100 within 66803 µs, the latest after 66803 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 23, 397, 6138; key 9, 325, 531; up 23, 354, 66803. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 61769; up 8, 2866.
The round of input `after` (events, half within µs): forward 1, 40448; up 1, 4939.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 37 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 37 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 26 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 25 | 0 |  |
| L | no window is lost or stuck | 37 | 0 |  |
| - | what the script itself checked | 37 | 0 |  |

## Findings

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder |  | quiet 624 ms; blind for 208 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 364 ms; blind for 590 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (3, 266 ms) | quiet 1630 ms; blind for 698 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal |  | quiet 947 ms; blind for 864 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (4, 142 ms), w53 ×2 (17, 925 ms), w55 ×1 (9, 220 ms) | quiet 361 ms; blind for 108 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar |  | quiet 957 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings |  | quiet 501 ms; blind for 352 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview |  | quiet 380 ms; blind for 1606 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w67 ×1 (5, 248 ms) | quiet 784 ms; blind for 496 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (38, 4323 ms) | quiet 1393 ms; blind for 120 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (31, 2427 ms) | quiet 1024 ms; blind for 150 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 397 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 625 ms; blind for 171 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 389 ms; blind for 190 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 15 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 411 ms; blind for 165 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 16 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 406 ms; blind for 131 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | quit-preview | presses ⌘Q in preview |  | quiet 930 ms; blind for 202 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 18 | reopen-preview | opens preview's document again |  | quiet 753 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 19 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 354 ms; blind for 267 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 374 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | hide-calendar | presses ⌘H |  | quiet 823 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 22 | unhide-calendar | clicks its icon in the Dock |  | quiet 373 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 368 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 499 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | quit-safari | presses ⌘Q in safari |  | quiet 1004 ms; blind for 110 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 26 | reopen-safari | opens safari's document again |  | quiet 411 ms; blind for 608 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 27 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 562 ms; blind for 896 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 379 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 29 | quit-textedit | presses ⌘Q in textedit |  | quiet 692 ms; blind for 124 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 30 | reopen-textedit | opens textedit's document again |  | quiet 538 ms; blind for 536 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 31 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 367 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 354 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | hide-finder | presses ⌘H |  | quiet 866 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 34 | unhide-finder | clicks its icon in the Dock |  | quiet 406 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 499 ms; blind for 652 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 36 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 379 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | minimize-calendar | presses ⌘M | calendar ×1 (16, 450 ms) | quiet 1000 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 38 | restore-calendar | clicks its miniature in the Dock | calendar ×1 (11, 464 ms) | quiet 965 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 433 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 449 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | minimize-notes | presses ⌘M | notes ×1 (13, 488 ms) | quiet 1020 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 42 | restore-notes | clicks notes's icon in the Dock, which brings its minimized window back | notes ×1 (12, 466 ms) | quiet 1052 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 350 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 444 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | close-only-preview | presses ⌘W on the only window of preview |  | quiet 1164 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 46 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 391 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 436 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | close-only-calendar | presses ⌘W on the only window of calendar |  | quiet 1107 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 49 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 391 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
