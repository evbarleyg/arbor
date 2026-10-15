62 steps in 179 s, 46 of them judged, 1 with a rule broken. The sampler: samples 4359 seconds 117.1 hz 37.2 cost-ms 2.17 late 12 longest-gap-ms 1008 whole-samples 6708 whole-seconds 180.2 whole-late 26.
Input: 57 presses, releases, keys and scrolls reached the apps, half of them within 569 µs, 99 in 100 within 80314 µs, the latest after 80314 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 23, 759, 5380; key 11, 278, 368; up 23, 815, 80314. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 32829; up 8, 730.
The round of input `started` (events, half within µs): forward 8, 38988; up 8, 386.
The round of input `last` (events, half within µs): forward 1, 19873; up 1, 2018.
The round of input `after` (events, half within µs): .
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 47 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 48 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 33 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 1 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 33 | 0 |  |
| L | no window is lost or stuck | 48 | 0 |  |
| - | what the script itself checked | 48 | 1 | 54 quit |

## Findings

### Rule -: what the script itself checked

- ✘ **54 quit** (chooses Quit Arbor in Arbor's menu): Arbor's process ended, and nobody asked it to [crash]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (2, 62 ms) | quiet 994 ms; blind for 136 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 792 ms; blind for 1008 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (4, 307 ms) | quiet 1235 ms; blind for 288 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (6, 362 ms) | quiet 1221 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (4, 95 ms) | quiet 1079 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar |  | quiet 960 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (2, 25 ms) | quiet 383 ms; blind for 598 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (2, 53 ms) | quiet 1092 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w198 ×1 (5, 249 ms) | quiet 782 ms; blind for 691 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×1 (29, 2177 ms) | quiet 1123 ms; blind for 131 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (28, 2003 ms) | quiet 1078 ms |  |  |  |  |  |  |  |  |
| 12 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (30, 4278 ms) | quiet 1389 ms |  |  |  |  |  |  |  |  |
| 13 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (41, 3281 ms) | quiet 1026 ms |  |  |  |  |  |  |  |  |
| 14 | look-around | looks at the screen |  | quiet 367 ms |  |  |  |  |  |  |  |  |
| 15 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 752 ms; blind for 219 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 16 | launch | starts Arbor |  | quiet 1016 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 17 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 741 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 18 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 417 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 443 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 386 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | quit-preview | presses ⌘Q in preview |  | quiet 792 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 22 | reopen-preview | opens preview's document again |  | quiet 731 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 23 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 414 ms; blind for 299 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 421 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | hide-calendar | presses ⌘H |  | quiet 850 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 26 | unhide-calendar | clicks its icon in the Dock |  | quiet 365 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 362 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 388 ms; blind for 107 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 29 | quit-safari | presses ⌘Q in safari |  | quiet 786 ms; blind for 108 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 30 | reopen-safari | opens safari's document again |  | quiet 368 ms; blind for 1008 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 31 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 375 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 462 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | quit-textedit | presses ⌘Q in textedit |  | quiet 784 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 34 | reopen-textedit | opens textedit's document again |  | quiet 801 ms; blind for 248 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 35 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 424 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 36 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 432 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | hide-finder | presses ⌘H |  | quiet 910 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 38 | unhide-finder | clicks its icon in the Dock |  | quiet 364 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 397 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 394 ms; blind for 100 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | minimize-calendar | presses ⌘M | calendar ×1 (17, 484 ms) | quiet 1110 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 42 | restore-calendar | clicks its miniature in the Dock | calendar ×1 (16, 438 ms) | quiet 973 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 373 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 436 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | minimize-notes | presses ⌘M | notes ×1 (15, 440 ms) | quiet 1003 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 46 | restore-notes | clicks notes's icon in the Dock, which brings its minimized window back | notes ×1 (14, 470 ms) | quiet 964 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 484 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 428 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | close-only-preview | presses ⌘W on the only window of preview |  | quiet 1253 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 50 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 358 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 377 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | close-only-calendar | presses ⌘W on the only window of calendar |  | quiet 964 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 53 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 422 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 54 | quit | chooses Quit Arbor in Arbor's menu |  | quiet 947 ms |  |  | ✔ |  | ✔ |  | ✔ | ✘ |
| 55 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 386 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 56 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 471 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 370 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 58 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 401 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 59 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 357 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 488 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 396 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 62 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 432 ms; blind for 170 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
