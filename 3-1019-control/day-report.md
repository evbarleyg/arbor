58 steps in 297 s, 36 of them judged, 6 with a rule broken. The sampler: samples 9936 seconds 249.1 hz 39.9 cost-ms 2.90 late 31 longest-gap-ms 630 whole-samples 11877 whole-seconds 297.8 whole-late 49.
Input: 259 presses, releases, keys and scrolls reached the apps, half of them within 622 µs, 99 in 100 within 82839 µs, the latest after 129933 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 21, 726, 5443; dragged 198, 603, 4973; forward 7, 881, 129933; key 5, 653, 1046; up 28, 664, 123249. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): down 13, 671; dragged 20, 455; forward 12, 10378; key 13, 599; scroll 28, 340; up 25, 463.
The round of input `after` (events, half within µs): down 13, 715; dragged 20, 380; forward 12, 8919; key 13, 506; scroll 28, 310; up 25, 398.
Judged: no kind. Not down: fewer than 10 such events in a round with Arbor. Not forward: fewer than 10 such events in a round with Arbor. Not up: fewer than 10 such events in a round with Arbor. Not key: fewer than 10 such events in a round with Arbor. Not dragged: fewer than 10 such events in a round with Arbor. Not scroll: fewer than 10 such events in a round with Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 6 | 0 |  |
| 2 | nothing moves that the person did not move | 35 | 2 | 38 minimize-notes, 41 restore-notes |
| 3 | no jolts: a window moves once, to where it ends up | 45 | 3 | 18 display-unplug, 21 display-plug, 28 display-plug |
| 4 | the window you switch to comes to the front and into view | 31 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 29 | 1 | 22 click-wallpaper |
| L | no window is lost or stuck | 45 | 0 |  |
| - | what the script itself checked | 45 | 0 |  |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **38 minimize-notes** (presses ⌘M): calendar (w925) moved and came back, and the step did not name it [moved-unasked]
  - +0 ms 0,31 1600×791 · +1004 ms 0,31 1600×793
- ✘ **41 restore-notes** (clicks notes's icon in the Dock, which brings its minimized window back): calendar (w925) moved and came back, and the step did not name it [moved-unasked]
  - +0 ms 0,31 1600×793 · +1745 ms 0,31 1600×791

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **18 display-unplug** (the second display: unplug): notes (w922) moved 2 times [jolt]
  - +0 ms 2056,192 1000×660 · +10 ms 297,109 1000×660 · +530 ms 300,105 1000×660
- ✘ **21 display-plug** (the second display: plug): notes (w922) moved 2 times [jolt]
  - +0 ms 300,105 1000×660 · +252 ms -1140,70 1000×660 · +678 ms 1740,70 1000×660
- ✘ **21 display-plug** (the second display: plug): calendar (w925) moved 2 times [jolt]
  - +0 ms 128,109 1600×791 · +252 ms 0,109 1600×791 · +678 ms 128,109 1600×791
- ✘ **28 display-plug** (the second display: plug): notes (w922) moved 2 times [jolt]
  - +0 ms 300,105 1000×660 · +25 ms 2060,183 1000×660 · +328 ms 2056,192 1000×660

### Rule 6: what a person presses reaches the apps, at once

- ✘ **22 click-wallpaper** (clicks on the wallpaper): the button came up, and the apps heard of it 123 ms later [input-held]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (3, 114 ms) | quiet 996 ms; blind for 107 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 759 ms; blind for 526 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (4, 317 ms) | quiet 1193 ms; blind for 352 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (3, 250 ms) | quiet 1289 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (1, 0 ms) | quiet 980 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (6, 366 ms) | quiet 1389 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (4, 146 ms) | quiet 491 ms; blind for 446 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (3, 76 ms) | quiet 978 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w932 ×1 (5, 198 ms) | quiet 673 ms; blind for 657 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×1 (29, 2383 ms) | quiet 1037 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (27, 2996 ms) | quiet 1060 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 411 ms |  |  |  |  |  |  |  |  |
| 13 | open-desks | opens the two windows that input is tried on | desk-a ×1 (1, 0 ms), desk-b ×1 (2, 69 ms) | quiet 433 ms; blind for 111 ms |  |  |  |  |  |  |  |  |
| 14 | input-before | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 888 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 15 | display-plug | the second display: plug | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 396 ms; blind for 429 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 16 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 489 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | carry-notes-across | drags notes, which floats, by its title bar onto the other display and lets go |  | quiet 1043 ms; blind for 118 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 18 | display-unplug | the second display: unplug | notes ×2 (2, 520 ms), calendar ×1 (1, 0 ms) | quiet 369 ms; blind for 519 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 19 | display-plug | the second display: plug | notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 443 ms; blind for 303 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 20 | display-unplug | the second display: unplug | notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 365 ms; blind for 469 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 21 | display-plug | the second display: plug | notes ×2 (2, 426 ms), calendar ×2 (2, 426 ms) | quiet 368 ms; blind for 249 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 22 | click-wallpaper | clicks on the wallpaper |  | quiet 370 ms; blind for 139 ms |  |  | ✔ |  |  | ✘ | ✔ | ✔ |
| 23 | click-wallpaper-again | clicks on the wallpaper again |  | quiet 408 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 24 | display-unplug | the second display: unplug | notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 359 ms; blind for 172 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 25 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 426 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 383 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | hide-safari | presses ⌘H |  | quiet 886 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 28 | display-plug | the second display: plug | notes ×2 (2, 303 ms), calendar ×1 (1, 0 ms) | quiet 389 ms; blind for 302 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 29 | click-notes | clicks notes's title bar |  | quiet 366 ms; blind for 185 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | unhide-safari | clicks its icon in the Dock |  | quiet 367 ms; blind for 155 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 385 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 406 ms; blind for 129 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 33 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 379 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 34 | drag-calendar-to-top-edge | drags calendar by its title bar against the top edge of the screen and lets go | calendar ×1 (13, 382 ms) | quiet 1456 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | leave-alone | does nothing for half a minute |  | quiet 374 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 36 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 603 ms; blind for 125 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 469 ms; blind for 258 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | minimize-notes | presses ⌘M | notes ×1 (17, 481 ms), calendar ×1 (1, 0 ms) | quiet 988 ms; blind for 259 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 39 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 410 ms; blind for 175 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 419 ms; blind for 100 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | restore-notes | clicks notes's icon in the Dock, which brings its minimized window back | notes ×1 (19, 774 ms), calendar ×1 (1, 0 ms) | quiet 978 ms; blind for 236 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 363 ms; blind for 136 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | drag-safari-by | drags safari, which floats, by its title bar 144 across and 116 down, and clicks there 0.3 s after letting go |  | quiet 919 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | click-safari | clicks safari's title bar |  | quiet 424 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 429 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 46 | drag-terminal-to-top-edge | drags terminal by its title bar against the top edge of the screen and lets go | terminal ×1 (10, 314 ms) | quiet 1395 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 517 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | quit-textedit | presses ⌘Q in textedit |  | quiet 833 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 49 | reopen-textedit | opens textedit's document again |  | quiet 909 ms; blind for 396 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 50 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 507 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | click-settings | clicks settings's title bar |  | quiet 494 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 514 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 53 | carry-calendar-across | drags calendar, which floats, by its title bar onto the other display and lets go |  | quiet 1049 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 54 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 505 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | leave-alone | does nothing for half a minute |  | quiet 355 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 56 | drag-preview-to-top-edge | drags preview by its title bar against the top edge of the screen and lets go | preview ×1 (15, 334 ms) | quiet 1452 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | display-unplug | the second display: unplug | terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 352 ms; blind for 630 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 58 | input-after | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 915 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
