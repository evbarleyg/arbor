51 steps in 161 s, 34 of them judged, 1 with a rule broken. The sampler: samples 3483 seconds 96.1 hz 36.2 cost-ms 3.33 late 28 longest-gap-ms 1651 whole-samples 5901 whole-seconds 162.8 whole-late 47.
Input: 55 presses, releases, keys and scrolls reached the apps, half of them within 660 µs, 99 in 100 within 340999 µs, the latest after 340999 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 23, 581, 2200; key 9, 660, 2138; up 23, 860, 340999. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 49993; up 8, 2132.
The round of input `after` (events, half within µs): forward 1, 82911; up 1, 3585.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 37 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 37 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 26 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 25 | 1 | 21 dock-icon-textedit |
| L | no window is lost or stuck | 37 | 0 |  |
| - | what the script itself checked | 37 | 0 |  |

## Findings

### Rule 6: what a person presses reaches the apps, at once

- ✘ **21 dock-icon-textedit** (clicks textedit's icon in the Dock): the button came up, and the apps heard of it 340 ms later [input-held]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (3, 22 ms) | quiet 982 ms; blind for 137 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 405 ms; blind for 2606 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (3, 233 ms) | quiet 1293 ms; blind for 341 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (5, 325 ms) | quiet 1267 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (4, 120 ms) | quiet 1054 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (4, 308 ms) | quiet 1339 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (2, 42 ms) | quiet 603 ms; blind for 335 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (3, 83 ms) | quiet 1036 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w360 ×1 (4, 130 ms) | quiet 738 ms; blind for 861 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (29, 3482 ms) | quiet 1096 ms; blind for 115 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (29, 2833 ms) | quiet 1113 ms |  |  |  |  |  |  |  |  |
| 12 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (30, 3990 ms) | quiet 1401 ms |  |  |  |  |  |  |  |  |
| 13 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (38, 2359 ms) | quiet 1013 ms |  |  |  |  |  |  |  |  |
| 14 | look-around | looks at the screen |  | quiet 422 ms |  |  |  |  |  |  |  |  |
| 15 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 658 ms; blind for 132 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 16 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 386 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 379 ms; blind for 156 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 18 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 377 ms; blind for 108 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | quit-preview | presses ⌘Q in preview |  | quiet 887 ms; blind for 127 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 20 | reopen-preview | opens preview's document again |  | quiet 1042 ms; blind for 142 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 21 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 382 ms; blind for 387 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 22 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 363 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | hide-calendar | presses ⌘H |  | quiet 874 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 24 | unhide-calendar | clicks its icon in the Dock |  | quiet 487 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 428 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 413 ms; blind for 100 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | quit-safari | presses ⌘Q in safari |  | quiet 893 ms; blind for 157 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 28 | reopen-safari | opens safari's document again |  | quiet 353 ms; blind for 1651 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 29 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 572 ms; blind for 207 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 414 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | quit-textedit | presses ⌘Q in textedit |  | quiet 847 ms; blind for 100 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 32 | reopen-textedit | opens textedit's document again |  | quiet 812 ms; blind for 511 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 33 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 384 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 483 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | hide-finder | presses ⌘H |  | quiet 847 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 36 | unhide-finder | clicks its icon in the Dock |  | quiet 471 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 390 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 402 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | minimize-calendar | presses ⌘M | calendar ×1 (16, 486 ms) | quiet 930 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 40 | restore-calendar | clicks its miniature in the Dock | calendar ×1 (13, 427 ms) | quiet 898 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 383 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 433 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | minimize-notes | presses ⌘M | notes ×1 (16, 440 ms) | quiet 1002 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 44 | restore-notes | clicks notes's icon in the Dock, which brings its minimized window back | notes ×1 (16, 486 ms) | quiet 900 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 444 ms; blind for 129 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 46 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 468 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | close-only-preview | presses ⌘W on the only window of preview |  | quiet 1206 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 48 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 405 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 439 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | close-only-calendar | presses ⌘W on the only window of calendar |  | quiet 1063 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 51 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 382 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
