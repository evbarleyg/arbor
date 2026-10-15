33 steps in 166 s, 21 of them judged, 0 with a rule broken. The sampler: samples 2594 seconds 85.3 hz 30.4 cost-ms 5.39 late 3 longest-gap-ms 120 whole-samples 5104 whole-seconds 167.8 whole-late 138.
Input: 34 presses, releases, keys and scrolls reached the apps, half of them within 400 µs, 99 in 100 within 85507 µs, the latest after 85507 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 15, 391, 15167; key 4, 368, 380; up 15, 424, 85507. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 42705; up 8, 649.
The round of input `after` (events, half within µs): down 13, 994; dragged 20, 230; forward 9, 26809; key 13, 339; scroll 28, 244; up 22, 404.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 20 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 21 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 14 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 17 | 0 |  |
| L | no window is lost or stuck | 21 | 0 |  |
| - | what the script itself checked | 21 | 0 |  |

## Findings

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 500 ms; blind for 409 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 1367 ms; blind for 1996 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (1, 0 ms) | quiet 986 ms; blind for 705 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (1, 0 ms) | quiet 538 ms; blind for 445 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (3, 55 ms), w55 ×2 (10, 2102 ms), w57 ×1 (5, 212 ms) | quiet 432 ms; blind for 789 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (3, 323 ms) | quiet 1275 ms; blind for 353 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings |  | quiet 422 ms; blind for 1136 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview |  | quiet 554 ms; blind for 1966 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | mail ×1 (2, 98 ms), w73 ×1 (2, 121 ms) | quiet 612 ms; blind for 438 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (40, 4438 ms) | quiet 1457 ms; blind for 154 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (36, 2155 ms) | quiet 1024 ms; blind for 101 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 373 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 695 ms; blind for 120 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 411 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 15 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 356 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 16 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 450 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 371 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 18 | minimize-notes | presses ⌘M | notes ×1 (15, 433 ms) | quiet 1029 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 19 | restore-notes | clicks notes's icon in the Dock, which brings its minimized window back | notes ×1 (11, 426 ms) | quiet 929 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 416 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 433 ms; blind for 105 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 22 | hide-safari | presses ⌘H |  | quiet 846 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 23 | unhide-safari | clicks its icon in the Dock |  | quiet 351 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 371 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | click-wallpaper | clicks on the wallpaper | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 418 ms |  |  | ✔ |  |  | ✔ | ✔ | ✔ |
| 26 | click-wallpaper-again | clicks on the wallpaper again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 375 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 27 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 409 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 437 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 29 | close-only-notes | presses ⌘W on the only window of notes |  | quiet 1103 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 30 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 407 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 365 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | close-only-safari | presses ⌘W on the only window of safari |  | quiet 766 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 33 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 850 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
