33 steps in 132 s, 19 of them judged, 0 with a rule broken. The sampler: samples 2798 seconds 72.5 hz 38.6 cost-ms 2.42 late 3 longest-gap-ms 176 whole-samples 5153 whole-seconds 133.5 whole-late 16.
Input: 30 presses, releases, keys and scrolls reached the apps, half of them within 606 µs, 99 in 100 within 2192 µs, the latest after 2192 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 13, 680, 1986; key 4, 375, 2192; up 13, 556, 1809. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 1, 92134; up 1, 8105.
The round of input `after` (events, half within µs): down 13, 1921; dragged 20, 508; forward 9, 35289; key 13, 330; scroll 28, 324; up 22, 471.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 19 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 19 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 14 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 15 | 0 |  |
| L | no window is lost or stuck | 19 | 0 |  |
| - | what the script itself checked | 19 | 0 |  |

## Findings

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (3, 100 ms) | quiet 998 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 857 ms; blind for 1119 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (4, 346 ms) | quiet 1396 ms; blind for 680 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (5, 371 ms) | quiet 1267 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (6, 329 ms) | quiet 1253 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (5, 330 ms) | quiet 1341 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings |  | quiet 687 ms; blind for 285 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (3, 86 ms) | quiet 963 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w314 ×1 (6, 202 ms) | quiet 794 ms; blind for 607 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (31, 3848 ms) | quiet 1065 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (31, 2922 ms) | quiet 1069 ms |  |  |  |  |  |  |  |  |
| 12 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (31, 4297 ms) | quiet 1477 ms |  |  |  |  |  |  |  |  |
| 13 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (37, 2293 ms) | quiet 1019 ms |  |  |  |  |  |  |  |  |
| 14 | look-around | looks at the screen |  | quiet 374 ms |  |  |  |  |  |  |  |  |
| 15 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 374 ms; blind for 111 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 16 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 425 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 498 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 18 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 419 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 471 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | minimize-notes | presses ⌘M | notes ×1 (11, 288 ms) | quiet 1021 ms; blind for 176 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 21 | restore-notes | clicks notes's icon in the Dock, which brings its minimized window back | notes ×1 (12, 402 ms) | quiet 779 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 22 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 354 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 424 ms; blind for 105 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | hide-safari | presses ⌘H |  | quiet 884 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 25 | unhide-safari | clicks its icon in the Dock |  | quiet 432 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 359 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 422 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 424 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 29 | close-only-notes | presses ⌘W on the only window of notes |  | quiet 1045 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 30 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 476 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 551 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | close-only-safari | presses ⌘W on the only window of safari |  | quiet 739 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 33 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 809 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
