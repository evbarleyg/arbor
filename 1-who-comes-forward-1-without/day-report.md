39 steps in 163 s, 20 of them judged, 2 with a rule broken. The sampler: samples 2364 seconds 84.0 hz 28.1 cost-ms 5.63 late 31 longest-gap-ms 1724 whole-samples 4633 whole-seconds 164.6 whole-late 149.
Input: 38 presses, releases, keys and scrolls reached the apps, half of them within 966 µs, 99 in 100 within 217254 µs, the latest after 217254 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 16, 989, 3966; key 6, 1632, 15898; up 16, 893, 217254. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 57655; up 8, 6184.
The round of input `after` (events, half within µs): forward 1, 52798; up 1, 439.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 27 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 27 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 19 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 18 | 2 | 16 dock-icon-preview, 19 dock-icon-textedit |
| L | no window is lost or stuck | 27 | 0 |  |
| - | what the script itself checked | 27 | 0 |  |

## Findings

### Rule 6: what a person presses reaches the apps, at once

- ✘ **16 dock-icon-preview** (clicks preview's icon in the Dock): the button came up, and the apps heard of it 110 ms later [input-held]
- ✘ **19 dock-icon-textedit** (clicks textedit's icon in the Dock): the button came up, and the apps heard of it 217 ms later [input-held]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (2, 71 ms) | quiet 638 ms; blind for 363 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 460 ms; blind for 1839 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (1, 0 ms) | quiet 633 ms; blind for 704 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (1, 0 ms) | quiet 916 ms; blind for 656 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (1, 0 ms), w51 ×2 (12, 1748 ms), w53 ×1 (9, 257 ms) | quiet 360 ms; blind for 363 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (4, 327 ms) | quiet 1348 ms; blind for 135 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings |  | quiet 504 ms; blind for 1038 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview |  | quiet 842 ms; blind for 2362 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | mail ×1 (1, 0 ms) | quiet 837 ms; blind for 1279 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (40, 4432 ms) | quiet 1387 ms; blind for 120 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (35, 2438 ms) | quiet 1042 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 368 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 668 ms; blind for 404 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 443 ms; blind for 129 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 15 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 419 ms; blind for 159 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 16 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 409 ms; blind for 134 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 17 | quit-preview | presses ⌘Q in preview |  | quiet 646 ms; blind for 160 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 18 | reopen-preview | opens preview's document again |  | quiet 941 ms; blind for 182 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 19 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 382 ms; blind for 549 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 20 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 374 ms; blind for 149 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | hide-calendar | presses ⌘H |  | quiet 885 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 22 | unhide-calendar | clicks its icon in the Dock |  | quiet 382 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 463 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 436 ms; blind for 134 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | quit-safari | presses ⌘Q in safari |  | quiet 993 ms; blind for 253 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 26 | reopen-safari | opens safari's document again |  | quiet 396 ms; blind for 1724 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 27 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 429 ms; blind for 382 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 378 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 29 | quit-textedit | presses ⌘Q in textedit |  | quiet 673 ms; blind for 114 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 30 | reopen-textedit | opens textedit's document again |  | quiet 912 ms; blind for 348 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 31 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 412 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 387 ms; blind for 121 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | hide-finder | presses ⌘H |  | quiet 957 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 34 | unhide-finder | clicks its icon in the Dock |  | quiet 506 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 420 ms; blind for 1128 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 36 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 392 ms; blind for 111 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | minimize-calendar | presses ⌘M | calendar ×1 (16, 450 ms) | quiet 920 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 38 | restore-calendar | clicks its miniature in the Dock | calendar ×1 (20, 493 ms) | quiet 894 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 399 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
