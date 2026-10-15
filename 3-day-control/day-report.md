85 steps in 290 s, 71 of them judged, 0 with a rule broken. The sampler: samples 9513 seconds 244.0 hz 39.0 cost-ms 2.04 late 9 longest-gap-ms 280 whole-samples 11351 whole-seconds 291.1 whole-late 29.
Input: 232 presses, releases, keys and scrolls reached the apps, half of them within 496 µs, 99 in 100 within 48984 µs, the latest after 73519 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 53, 565, 3525; dragged 99, 494, 1945; forward 6, 45604, 73519; key 15, 348, 544; up 59, 471, 63466. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 35795; up 8, 948.
The round of input `after` (events, half within µs): forward 7, 43588; up 7, 731.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 7 | 0 |  |
| 2 | nothing moves that the person did not move | 70 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 72 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 62 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 55 | 0 |  |
| L | no window is lost or stuck | 72 | 0 |  |
| - | what the script itself checked | 72 | 0 |  |

## Findings

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **78 drag-calendar-by** (drags calendar, which floats, by its title bar 0 across and 118 down, and clicks there 0.3 s after letting go): calendar (w496) changed its size while it was being dragged [jolt]
  - +0 ms 0,34 1600×791 · +33 ms 0,42 1600×791 · +107 ms 78,38 1414×740 · +157 ms 225,38 1063×645 · +200 ms 258,42 985×623 · +207 ms 267,42 962×617 · … 20 more … · +1691 ms 289,137 910×603 · +1758 ms 289,141 910×603 · +1853 ms 289,145 910×603 · +2117 ms 290,145 910×603 · +2182 ms 289,145 910×603

### Rule -: what the script itself checked

- ~ **75 drag-notes-to-left-edge** (drags notes by its title bar against the left edge of the screen and lets go): the act was not performed: drag_window could not be done [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (4, 124 ms) | quiet 950 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 408 ms; blind for 820 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (6, 310 ms) | quiet 1201 ms; blind for 356 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (6, 316 ms) | quiet 1299 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (8, 376 ms) | quiet 1316 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×2 (5, 391 ms) | quiet 1388 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×2 (3, 288 ms) | quiet 743 ms; blind for 296 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (4, 97 ms) | quiet 996 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w503 ×1 (7, 210 ms) | quiet 749 ms; blind for 862 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (37, 4232 ms) | quiet 1463 ms; blind for 126 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (34, 2409 ms) | quiet 1068 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 410 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 697 ms; blind for 102 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | leave-alone | does nothing for half a minute |  | quiet 377 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### Switching between apps, nothing docked yet

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 15 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 378 ms; blind for 121 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 16 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 418 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 418 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 18 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 390 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 447 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 550 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 449 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 22 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 482 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 404 ms; blind for 115 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 399 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 25 | cmd-tab-2 | holds ⌘ and presses Tab 2 time(s) |  | quiet 433 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### The first docks, by key

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 26 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 366 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | click-safari | clicks safari's title bar |  | quiet 414 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 386 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### Docking by real drags

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 29 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 404 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### Sizes

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 30 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 451 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### Switching between apps, with an arrangement

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 31 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 371 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 389 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 414 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 402 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 414 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 36 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 399 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 541 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 387 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 524 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 425 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### The view goes in and out

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 41 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 388 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 426 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 378 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 44 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 422 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | click-safari | clicks safari's title bar |  | quiet 455 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### Windows come and go

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 46 | click-safari | clicks safari's title bar |  | quiet 447 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | new-window-safari | presses ⌘N in safari |  | quiet 692 ms; blind for 280 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 48 | window-menu-safari | chooses safari's first window in the Window menu |  | quiet 1346 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | cmd-backtick | presses ⌘` for the app's next window |  | quiet 408 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 50 | close-window | presses ⌘W |  | quiet 849 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 51 | click-safari | clicks safari's title bar |  | quiet 393 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | new-window-safari | presses ⌘N in safari |  | quiet 1034 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 53 | close-window | presses ⌘W |  | quiet 781 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 54 | click-safari | clicks safari's title bar |  | quiet 388 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | minimize-safari | presses ⌘M | safari ×1 (8, 274 ms) | quiet 1025 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 56 | restore-safari | clicks its miniature in the Dock | safari ×1 (6, 269 ms) | quiet 718 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 467 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 58 | hide-finder | presses ⌘H |  | quiet 827 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 59 | unhide-finder | clicks its icon in the Dock |  | quiet 357 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 357 ms; blind for 129 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | quit-textedit | presses ⌘Q in textedit |  | quiet 862 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 62 | reopen-textedit | opens textedit's document again |  | quiet 793 ms; blind for 230 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### Full screen

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 63 | click-safari | clicks safari's title bar |  | quiet 389 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 64 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 361 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 65 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 371 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### A click lands on the wallpaper, a double-click on a title bar

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 66 | click-wallpaper | clicks on the wallpaper | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w503 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 371 ms |  |  | ✔ |  |  | ✔ | ✔ | ✔ |
| 67 | click-wallpaper-again | clicks on the wallpaper again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w503 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 386 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 68 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 363 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 69 | double-click-finder | double-clicks finder's title bar: macOS zooms the window | finder ×1 (12, 360 ms) | quiet 811 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 70 | double-click-finder-again | double-clicks it again: macOS takes the window back | finder ×1 (12, 286 ms) | quiet 808 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 71 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 430 ms; blind for 103 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 72 | double-click-calendar | double-clicks calendar's title bar: macOS zooms the window | calendar ×1 (9, 330 ms) | quiet 686 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 73 | double-click-calendar-again | double-clicks it again: macOS takes the window back | calendar ×1 (13, 367 ms) | quiet 662 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### Where macOS tiles too

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 74 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 358 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 75 | drag-notes-to-left-edge | drags notes by its title bar against the left edge of the screen and lets go |  | quiet 1025 ms |  |  |  |  |  |  |  | ~ |
| 76 | click-calendar | clicks calendar's title bar |  | quiet 371 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 77 | drag-calendar-to-top-edge | drags calendar by its title bar against the top edge of the screen and lets go | calendar ×1 (7, 316 ms) | quiet 1381 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 78 | drag-calendar-by | drags calendar, which floats, by its title bar 0 across and 118 down, and clicks there 0.3 s after letting go | calendar ×1 (2, 40 ms) | quiet 919 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |

### The ways out

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 79 | click-safari | clicks safari's title bar |  | quiet 380 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 80 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 368 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 81 | drag-calendar-by | drags calendar, which floats, by its title bar 60 across and 60 down |  | quiet 1055 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 82 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 381 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 83 | click-safari | clicks safari's title bar |  | quiet 364 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### Quit, and the next morning

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 84 | leave-alone | does nothing for half a minute |  | quiet 380 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 85 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 655 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
