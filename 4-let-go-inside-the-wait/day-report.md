41 steps in 202 s, 25 of them judged, 2 with a rule broken. The sampler: samples 5299 seconds 138.5 hz 38.3 cost-ms 2.44 late 12 longest-gap-ms 395 whole-samples 7774 whole-seconds 203.2 whole-late 32.
Input: 5 presses, releases, keys and scrolls reached the apps, half of them within 468 µs, 99 in 100 within 2456 µs, the latest after 2456 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): key 5, 468, 2456. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 39786; up 8, 1906.
The round of input `started` (events, half within µs): forward 8, 34720; up 8, 2992.
The round of input `last` (events, half within µs): forward 8, 32840; up 8, 1251.
The round of input `after` (events, half within µs): forward 8, 24512; up 8, 899.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 17 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 27 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 9 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 1 | 1 | 31 quit |
| 6 | what a person presses reaches the apps, at once | 13 | 0 |  |
| L | no window is lost or stuck | 27 | 0 |  |
| - | what the script itself checked | 27 | 1 | 21 launch |

## Findings

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **31 quit** (chooses Quit Arbor in Arbor's menu): textedit (w1018) is 165,65 656×422; its own size was 165,65 673×439 [size-lost]
- ✘ **31 quit** (chooses Quit Arbor in Arbor's menu): terminal (w1021) is 40,51 863×499; its own size was 40,51 877×499 [size-lost]

### Rule -: what the script itself checked

- ✘ **21 launch** (starts Arbor): with nothing to do Arbor used 1.2 % of a core [busy]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 944 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 402 ms; blind for 1452 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (4, 280 ms) | quiet 1270 ms; blind for 257 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×2 (4, 365 ms) | quiet 1234 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (4, 70 ms) | quiet 970 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar |  | quiet 933 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (3, 140 ms) | quiet 490 ms; blind for 302 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (5, 100 ms) | quiet 1045 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w1034 ×1 (2, 188 ms) | quiet 767 ms; blind for 1544 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (32, 3691 ms) | quiet 1051 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (31, 2294 ms) | quiet 1050 ms |  |  |  |  |  |  |  |  |
| 12 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (28, 4125 ms) | quiet 1365 ms |  |  |  |  |  |  |  |  |
| 13 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (34, 2946 ms) | quiet 1077 ms |  |  |  |  |  |  |  |  |
| 14 | look-around | looks at the screen |  | quiet 432 ms |  |  |  |  |  |  |  |  |
| 15 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 695 ms; blind for 147 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 16 | launch | starts Arbor |  | quiet 1213 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 17 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 740 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 18 | display-plug-and-quit | the second display: plug, and within the second Arbor is told: quit | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms) | quiet 390 ms; blind for 395 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 19 | launch | starts Arbor |  | quiet 390 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 20 | display-unplug-and-quit | the second display: unplug, and within the second Arbor is told: quit |  | quiet 369 ms; blind for 219 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 21 | launch | starts Arbor |  | quiet 365 ms |  | ✔ | ✔ |  |  |  | ✔ | ✘ |
| 22 | display-plug-and-pause | the second display: plug, and within the second Arbor is told: pause |  | quiet 395 ms; blind for 191 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 23 | resume | presses ⌃⌥⎋ |  | quiet 759 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 24 | display-unplug-and-pause | the second display: unplug, and within the second Arbor is told: pause |  | quiet 350 ms; blind for 364 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 25 | resume | presses ⌃⌥⎋ |  | quiet 827 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 26 | display-plug-and-pause | the second display: plug, and within the second Arbor is told: pause |  | quiet 357 ms; blind for 245 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 27 | resume | presses ⌃⌥⎋ |  | quiet 632 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 28 | display-unplug-and-quit | the second display: unplug, and within the second Arbor is told: quit |  | quiet 356 ms; blind for 190 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 29 | launch | starts Arbor |  | quiet 367 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 30 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 738 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 31 | quit | chooses Quit Arbor in Arbor's menu |  | quiet 353 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 32 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 701 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 33 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 424 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 377 ms; blind for 103 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 422 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 36 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 400 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 354 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 382 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 566 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 385 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 572 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
