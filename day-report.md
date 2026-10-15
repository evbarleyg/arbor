63 steps in 478 s, 48 of them judged, 0 with a rule broken. The sampler: samples 15529 seconds 402.9 hz 38.6 cost-ms 2.30 late 14 longest-gap-ms 690 whole-samples 18483 whole-seconds 479.5 whole-late 148.
Input: 5475 presses, releases, keys and scrolls reached the apps, half of them within 542 µs, 99 in 100 within 3693 µs, the latest after 88419 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 48, 2054, 13899; dragged 5378, 539, 3489; key 1, 2058, 2058; up 48, 1209, 5089. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 58709; up 8, 2127.
The round of input `after` (events, half within µs): forward 1, 56736; up 1, 557.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 39 | 0 |  |
| 2 | nothing moves that the person did not move | 51 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 51 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 48 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 50 | 0 |  |
| L | no window is lost or stuck | 51 | 0 |  |
| - | what the script itself checked | 51 | 0 |  |

## Findings

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 701 ms; blind for 248 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 504 ms; blind for 1299 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (2, 201 ms) | quiet 2270 ms; blind for 1330 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (4, 266 ms) | quiet 1000 ms; blind for 275 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (2, 92 ms), w55 ×2 (8, 1362 ms), w57 ×1 (6, 215 ms) | quiet 376 ms; blind for 274 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (4, 347 ms) | quiet 1305 ms; blind for 266 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 353 ms; blind for 503 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (1, 0 ms) | quiet 361 ms; blind for 1157 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | mail ×1 (2, 61 ms), w73 ×1 (4, 145 ms) | quiet 744 ms; blind for 560 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (39, 4278 ms) | quiet 1442 ms; blind for 128 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (33, 2678 ms) | quiet 1052 ms; blind for 107 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 366 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 721 ms; blind for 135 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 435 ms; blind for 115 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 15 | hide-others | presses ⌥⌘H: every other app is hidden |  | quiet 739 ms; blind for 268 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### The left edge, at 50 points a second

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 16 | carry-to-165-120 | drags textedit by its title bar 0 across and 55 down, at 600 points a second |  | quiet 1026 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | left-out-50 | drags textedit by its title bar -380 across and 0 down, at 50 points a second |  | quiet 1039 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 18 | left-in-50 | drags textedit by its title bar 380 across and 0 down, at 50 points a second |  | quiet 1081 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The left edge, at 150 points a second

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 19 | carry-to-165-120 | drags textedit by its title bar -31 across and 0 down, at 600 points a second |  | quiet 1051 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | left-out-150 | drags textedit by its title bar -380 across and 0 down, at 150 points a second |  | quiet 1030 ms; blind for 149 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | left-in-150 | drags textedit by its title bar 380 across and 0 down, at 150 points a second |  | quiet 1113 ms; blind for 606 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The left edge, at 600 points a second

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 22 | carry-to-165-120 | drags textedit by its title bar -31 across and 0 down, at 600 points a second |  | quiet 1092 ms; blind for 115 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | left-out-600 | drags textedit by its title bar -380 across and 0 down, at 600 points a second |  | quiet 1030 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | left-in-600 | drags textedit by its title bar 380 across and 0 down, at 600 points a second |  | quiet 1009 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The right edge, at 50 points a second

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 25 | carry-to-762-120 | drags textedit by its title bar 588 across and 0 down, at 600 points a second |  | quiet 1091 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | right-out-50 | drags textedit by its title bar 380 across and 0 down, at 50 points a second |  | quiet 1043 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | right-in-50 | drags textedit by its title bar -380 across and 0 down, at 50 points a second |  | quiet 1012 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The right edge, at 150 points a second

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 28 | carry-to-762-120 | drags textedit by its title bar 31 across and 0 down, at 600 points a second |  | quiet 1033 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 29 | right-out-150 | drags textedit by its title bar 380 across and 0 down, at 150 points a second |  | quiet 1014 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | right-in-150 | drags textedit by its title bar -380 across and 0 down, at 150 points a second |  | quiet 1047 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The right edge, at 600 points a second

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 31 | carry-to-762-120 | drags textedit by its title bar 31 across and 0 down, at 600 points a second |  | quiet 1021 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | right-out-600 | drags textedit by its title bar 380 across and 0 down, at 600 points a second |  | quiet 1079 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | right-in-600 | drags textedit by its title bar -380 across and 0 down, at 600 points a second |  | quiet 1006 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The Dock, at 50 points a second

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 34 | carry-to-460-120 | drags textedit by its title bar -271 across and 0 down, at 600 points a second |  | quiet 1026 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | dock-out-50 | drags textedit by its title bar 0 across and 500 down, at 50 points a second |  | quiet 1063 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 36 | dock-in-50 | drags textedit by its title bar 0 across and -500 down, at 50 points a second |  | quiet 1048 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The Dock, at 150 points a second

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 37 | carry-to-460-120 | drags textedit by its title bar 0 across and 63 down, at 600 points a second |  | quiet 1045 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | dock-out-150 | drags textedit by its title bar 0 across and 500 down, at 150 points a second |  | quiet 1055 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | dock-in-150 | drags textedit by its title bar 0 across and -500 down, at 150 points a second |  | quiet 1089 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The Dock, at 600 points a second

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 40 | carry-to-460-120 | drags textedit by its title bar 0 across and 63 down, at 600 points a second |  | quiet 1049 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | dock-out-600 | drags textedit by its title bar 0 across and 500 down, at 600 points a second |  | quiet 1012 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | dock-in-600 | drags textedit by its title bar 0 across and -500 down, at 600 points a second |  | quiet 1030 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The menu bar, at 20 points a second

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 43 | carry-to-460-65 | drags textedit by its title bar 0 across and -36 down, at 600 points a second |  | quiet 1033 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | menu-bar-against-20 | drags textedit by its title bar 0 across and -44 down, at 20 points a second |  | quiet 1065 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | menu-bar-away-20 | drags textedit by its title bar 0 across and 240 down, at 20 points a second |  | quiet 995 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The menu bar, at 50 points a second

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 46 | carry-to-460-65 | drags textedit by its title bar 0 across and -206 down, at 600 points a second |  | quiet 1040 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | menu-bar-against-50 | drags textedit by its title bar 0 across and -44 down, at 50 points a second |  | quiet 1049 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | menu-bar-away-50 | drags textedit by its title bar 0 across and 240 down, at 50 points a second |  | quiet 1086 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The menu bar, at 150 points a second

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 49 | carry-to-460-65 | drags textedit by its title bar 0 across and -206 down, at 600 points a second |  | quiet 1018 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | menu-bar-against-150 | drags textedit by its title bar 0 across and -44 down, at 150 points a second |  | quiet 1058 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | menu-bar-away-150 | drags textedit by its title bar 0 across and 240 down, at 150 points a second |  | quiet 1027 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The menu bar, at 600 points a second

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 52 | carry-to-460-65 | drags textedit by its title bar 0 across and -206 down, at 600 points a second |  | quiet 1032 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 53 | menu-bar-against-600 | drags textedit by its title bar 0 across and -44 down, at 600 points a second |  | quiet 1038 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 54 | menu-bar-away-600 | drags textedit by its title bar 0 across and 240 down, at 600 points a second |  | quiet 1081 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | unhide-mail | clicks its icon in the Dock |  | quiet 466 ms; blind for 103 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 56 | unhide-preview | clicks its icon in the Dock |  | quiet 397 ms; blind for 107 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | unhide-settings | clicks its icon in the Dock |  | quiet 513 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 58 | unhide-calendar | clicks its icon in the Dock |  | quiet 427 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 59 | unhide-notes | clicks its icon in the Dock |  | quiet 473 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | unhide-terminal | clicks its icon in the Dock |  | quiet 409 ms; blind for 690 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | unhide-safari | clicks its icon in the Dock |  | quiet 399 ms; blind for 100 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 62 | unhide-finder | clicks its icon in the Dock |  | quiet 394 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 63 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 356 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
