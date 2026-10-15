57 steps in 227 s, 41 of them judged, 1 with a rule broken. The sampler: samples 6161 seconds 161.1 hz 38.2 cost-ms 2.39 late 21 longest-gap-ms 544 whole-samples 8747 whole-seconds 228.7 whole-late 39.
Input: 16 presses, releases, keys and scrolls reached the apps, half of them within 314 µs, 99 in 100 within 2076 µs, the latest after 2076 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): key 16, 314, 2076. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 30993; up 8, 604.
The round of input `started` (events, half within µs): forward 8, 27795; up 8, 681.
The round of input `last` (events, half within µs): forward 8, 31484; up 8, 1986.
The round of input `after` (events, half within µs): forward 8, 34762; up 8, 295.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 14 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 43 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 9 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 1 | 1 | 47 quit |
| 6 | what a person presses reaches the apps, at once | 13 | 0 |  |
| L | no window is lost or stuck | 43 | 0 |  |
| - | what the script itself checked | 43 | 0 |  |

## Findings

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **47 quit** (chooses Quit Arbor in Arbor's menu): textedit (w461) is 165,65 656×422; its own size was 165,65 673×439 [size-lost]
- ✘ **47 quit** (chooses Quit Arbor in Arbor's menu): terminal (w464) is 40,51 863×499; its own size was 40,51 877×499 [size-lost]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (3, 99 ms) | quiet 1085 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 431 ms; blind for 1703 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (3, 260 ms) | quiet 1443 ms; blind for 214 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (4, 371 ms) | quiet 1307 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (5, 122 ms) | quiet 1058 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (5, 372 ms) | quiet 1275 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (2, 204 ms) | quiet 705 ms; blind for 321 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (3, 71 ms) | quiet 1068 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w477 ×1 (3, 150 ms) | quiet 791 ms; blind for 1079 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (29, 3259 ms) | quiet 1106 ms; blind for 506 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (28, 2320 ms) | quiet 1053 ms |  |  |  |  |  |  |  |  |
| 12 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (28, 4162 ms) | quiet 1397 ms |  |  |  |  |  |  |  |  |
| 13 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (37, 3125 ms) | quiet 1071 ms |  |  |  |  |  |  |  |  |
| 14 | look-around | looks at the screen |  | quiet 386 ms |  |  |  |  |  |  |  |  |
| 15 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 741 ms; blind for 106 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 16 | launch | starts Arbor |  | quiet 1194 ms; blind for 106 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 17 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 710 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 18 | display-plug | the second display: plug | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms) | quiet 401 ms; blind for 544 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 19 | view-home | presses ⌃⌥0 |  | quiet 633 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 20 | display-unplug | the second display: unplug |  | quiet 398 ms; blind for 158 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 21 | view-home | presses ⌃⌥0 |  | quiet 780 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 22 | display-plug | the second display: plug |  | quiet 374 ms; blind for 208 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 23 | view-home | presses ⌃⌥0 |  | quiet 724 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 24 | display-unplug | the second display: unplug |  | quiet 362 ms; blind for 282 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 25 | view-home | presses ⌃⌥0 |  | quiet 672 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 26 | display-plug | the second display: plug |  | quiet 412 ms; blind for 127 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 27 | view-home | presses ⌃⌥0 |  | quiet 635 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 28 | display-left | the second display: left |  | quiet 401 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 29 | view-home | presses ⌃⌥0 |  | quiet 681 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 30 | display-right | the second display: right |  | quiet 368 ms; blind for 109 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 31 | view-home | presses ⌃⌥0 |  | quiet 691 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 32 | display-unplug | the second display: unplug |  | quiet 358 ms; blind for 186 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 33 | view-home | presses ⌃⌥0 |  | quiet 667 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 34 | display-plug | the second display: plug |  | quiet 393 ms; blind for 162 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 35 | view-home | presses ⌃⌥0 |  | quiet 823 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 36 | display-unplug | the second display: unplug |  | quiet 381 ms; blind for 157 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 37 | view-home | presses ⌃⌥0 |  | quiet 798 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 38 | display-plug | the second display: plug |  | quiet 388 ms; blind for 176 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 39 | view-home | presses ⌃⌥0 |  | quiet 717 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 40 | display-unplug | the second display: unplug |  | quiet 382 ms; blind for 118 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 41 | view-home | presses ⌃⌥0 |  | quiet 664 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 42 | display-plug | the second display: plug |  | quiet 390 ms; blind for 135 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 43 | view-home | presses ⌃⌥0 |  | quiet 682 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 44 | display-unplug | the second display: unplug |  | quiet 382 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 45 | view-home | presses ⌃⌥0 |  | quiet 701 ms |  |  | ✔ |  |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 46 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 780 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 47 | quit | chooses Quit Arbor in Arbor's menu |  | quiet 928 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 48 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 679 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 49 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 454 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 406 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 387 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 424 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 53 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 396 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 54 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 391 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 445 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 56 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 369 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 541 ms; blind for 107 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
