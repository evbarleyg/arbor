24 steps in 158 s, 1 of them judged, 0 with a rule broken. The sampler: samples 2284 seconds 79.8 hz 28.6 cost-ms 5.94 late 24 longest-gap-ms 624 whole-samples 4546 whole-seconds 158.9 whole-late 153.
Input: 2 presses, releases, keys and scrolls reached the apps, half of them within 2009 µs, 99 in 100 within 2009 µs, the latest after 2009 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 1, 2009, 2009; up 1, 660, 660. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 61216; up 8, 1648.
The round of input `after` (events, half within µs): forward 8, 55670; up 8, 558.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 3 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 11 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 1 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 3 | 0 |  |
| L | no window is lost or stuck | 11 | 0 |  |
| - | what the script itself checked | 11 | 0 |  |

## Findings

### Rule -: what the script itself checked

- ~ **16 carry-notes-across** (drags notes, which floats, by its title bar onto the other display and lets go): the act was not performed: drag_window could not be done [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 695 ms; blind for 237 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 360 ms; blind for 2607 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (3, 287 ms) | quiet 2245 ms; blind for 1343 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×2 (6, 386 ms) | quiet 945 ms; blind for 315 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (1, 0 ms), w55 ×2 (8, 1764 ms), w57 ×1 (7, 217 ms) | quiet 360 ms; blind for 323 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (3, 276 ms) | quiet 1137 ms; blind for 892 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 762 ms; blind for 864 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (1, 0 ms) | quiet 881 ms; blind for 1477 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w73 ×1 (3, 170 ms) | quiet 795 ms; blind for 538 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (37, 4611 ms) | quiet 1363 ms; blind for 149 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (33, 3556 ms) | quiet 1121 ms; blind for 203 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 390 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 663 ms; blind for 275 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | display-plug | the second display: plug | textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 425 ms; blind for 423 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 15 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 426 ms; blind for 271 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 16 | carry-notes-across | drags notes, which floats, by its title bar onto the other display and lets go |  | quiet 1068 ms |  |  |  |  |  |  |  | ~ |
| 17 | display-unplug | the second display: unplug |  | quiet 359 ms; blind for 519 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 18 | display-plug | the second display: plug |  | quiet 367 ms; blind for 295 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 19 | display-unplug | the second display: unplug |  | quiet 381 ms; blind for 464 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 20 | display-plug | the second display: plug |  | quiet 436 ms; blind for 257 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 21 | display-unplug | the second display: unplug |  | quiet 380 ms; blind for 491 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 22 | display-plug | the second display: plug |  | quiet 354 ms; blind for 624 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 23 | display-unplug | the second display: unplug |  | quiet 406 ms; blind for 386 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 24 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 585 ms; blind for 173 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
