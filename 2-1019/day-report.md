118 steps in 382 s, 100 of them judged, 9 with a rule broken. The sampler: samples 13555 seconds 337.9 hz 40.1 cost-ms 2.68 late 24 longest-gap-ms 927 whole-samples 15383 whole-seconds 383.4 whole-late 41.
Input: 307 presses, releases, keys and scrolls reached the apps, half of them within 532 µs, 99 in 100 within 20596 µs, the latest after 127625 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 21, 579, 3016; dragged 198, 544, 2752; forward 12, 794, 127625; key 43, 267, 1870; up 33, 710, 49583. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 1, 73508; up 1, 5864.
The round of input `started` (events, half within µs): .
The round of input `last` (events, half within µs): .
The round of input `after` (events, half within µs): .
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 6 | 0 |  |
| 2 | nothing moves that the person did not move | 67 | 1 | 83 quit-textedit |
| 3 | no jolts: a window moves once, to where it ends up | 106 | 3 | 26 display-plug, 36 display-plug, 105 display-unplug |
| 4 | the window you switch to comes to the front and into view | 56 | 1 | 71 dock-left |
| 5 | quitting, Float All and pause give windows their own sizes back | 3 | 3 | 72 quit, 77 pause, 108 quit |
| 6 | what a person presses reaches the apps, at once | 45 | 0 |  |
| L | no window is lost or stuck | 106 | 1 | 76 launch |
| - | what the script itself checked | 106 | 0 |  |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **83 quit-textedit** (presses ⌘Q in textedit): calendar (w706) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 478,31 909×791 · +921 ms -908,770 909×791
- ✘ **83 quit-textedit** (presses ⌘Q in textedit): preview (w711) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +921 ms -707,770 708×424
- ✘ **83 quit-textedit** (presses ⌘Q in textedit): mail (w712) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +921 ms -1119,770 1120×630
- ~ **83 quit-textedit** (presses ⌘Q in textedit): w715 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +921 ms -794,877 470×416

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **26 display-plug** (the second display: plug): notes (w705) moved 2 times [jolt]
  - +0 ms 426,158 1000×660 · +190 ms -1081,97 1000×660 · +782 ms 1799,97 1000×660
- ✘ **26 display-plug** (the second display: plug): calendar (w706) moved 2 times [jolt]
  - +0 ms 415,115 909×791 · +190 ms 415,109 909×791 · +782 ms 415,115 909×791
- ✘ **36 display-plug** (the second display: plug): notes (w705) went 338 points out of its way before it ended up [jolt]
  - +0 ms 426,158 1000×660 · +16 ms 2253,276 1000×660 · +173 ms 2084,180 1000×660
- ✘ **105 display-unplug** (the second display: unplug): notes (w705) moved 3 times [jolt]
  - +0 ms 2084,180 1000×660 · +48 ms 315,102 1000×660 · +976 ms 426,158 1000×660 · +2751 ms 484,162 1000×660
- ✘ **105 display-unplug** (the second display: unplug): calendar (w706) moved 3 times [jolt]
  - +0 ms 2238,180 909×791 · +48 ms 436,67 909×791 · +976 ms 478,31 909×791 · +2810 ms 638,31 909×791

### Rule 4: the window you switch to comes to the front and into view

- ✘ **71 dock-left** (presses ⌃⌥⌘ and the left arrow): safari (w690) is not wholly in view: 0% of it, at -573,770 574×791 in 0,31 1600×791 and 1600,31 1920×1049 [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **72 quit** (chooses Quit Arbor in Arbor's menu): textedit (w699) is 165,65 656×422; its own size was 165,65 673×439 [size-lost]
- ✘ **72 quit** (chooses Quit Arbor in Arbor's menu): terminal (w704) is 369,177 863×499; its own size was 369,177 877×499 [size-lost]
- ✘ **77 pause** (presses ⌃⌥⎋): textedit (w699) is 165,65 656×422; its own size was 165,65 673×439 [size-lost]
- ✘ **77 pause** (presses ⌃⌥⎋): terminal (w704) is 369,177 863×499; its own size was 369,177 877×499 [size-lost]
- ✘ **108 quit** (chooses Quit Arbor in Arbor's menu): terminal (w704) is 366,31 862×497; its own size was 1,35 1598×784 [size-lost]
- ✘ **108 quit** (chooses Quit Arbor in Arbor's menu): notes (w705) has its size back but not its place: 484,162 1000×660, it was at 2084,180 1000×660 [size-lost]
- ✘ **108 quit** (chooses Quit Arbor in Arbor's menu): calendar (w706) has its size back but not its place: 638,31 909×791, it was at 2238,180 909×791 [size-lost]
- ✘ **108 quit** (chooses Quit Arbor in Arbor's menu): textedit (w1149) is 165,65 656×422; its own size was 165,65 673×439 [size-lost]

### Rule L: no window is lost or stuck

- ✘ **76 launch** (starts Arbor): safari (w690) is out of view: 0% of it is on a display, at -573,770 574×791 [lost]
- ✘ **76 launch** (starts Arbor): settings (w709) is out of view: 0% of it is on a display, at -722,770 723×470 [lost]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (2, 29 ms) | quiet 986 ms; blind for 105 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 490 ms; blind for 943 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (3, 251 ms) | quiet 1188 ms; blind for 189 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×2 (5, 375 ms) | quiet 1263 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (5, 119 ms) | quiet 1021 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (4, 105 ms) | quiet 1063 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×2 (3, 402 ms) | quiet 700 ms; blind for 425 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (5, 144 ms) | quiet 1162 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w715 ×1 (8, 282 ms) | quiet 700 ms; blind for 1165 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (36, 4011 ms) | quiet 1446 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (39, 3124 ms) | quiet 1119 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 372 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 352 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | launch | starts Arbor |  | quiet 1264 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 15 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 390 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 16 | display-plug | the second display: plug | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 396 ms; blind for 640 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 17 | view-home | presses ⌃⌥0 |  | quiet 649 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 18 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 356 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | carry-notes-across | drags notes, which floats, by its title bar onto the other display and lets go |  | quiet 1045 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | display-unplug | the second display: unplug | notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 368 ms; blind for 452 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 21 | view-home | presses ⌃⌥0 |  | quiet 773 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 22 | display-plug | the second display: plug | notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 364 ms; blind for 463 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 23 | view-home | presses ⌃⌥0 |  | quiet 732 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 24 | display-unplug | the second display: unplug | notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 375 ms; blind for 220 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 25 | view-home | presses ⌃⌥0 |  | quiet 764 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 26 | display-plug | the second display: plug | notes ×2 (2, 592 ms), calendar ×2 (2, 592 ms) | quiet 365 ms; blind for 176 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 27 | view-home | presses ⌃⌥0 |  | quiet 866 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 28 | click-wallpaper | clicks on the wallpaper | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w715 ×1 (1, 0 ms) | quiet 492 ms; blind for 118 ms |  |  | ✔ |  |  | ✔ | ✔ | ✔ |
| 29 | click-wallpaper-again | clicks on the wallpaper again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w715 ×1 (1, 0 ms) | quiet 424 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 30 | display-unplug | the second display: unplug | notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 428 ms; blind for 557 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 31 | view-home | presses ⌃⌥0 |  | quiet 622 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 32 | view-home | presses ⌃⌥0 |  | quiet 706 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 33 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 420 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 409 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | hide-safari | presses ⌘H |  | quiet 861 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 36 | display-plug | the second display: plug | notes ×1 (2, 157 ms), calendar ×1 (1, 0 ms) | quiet 364 ms; blind for 157 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 37 | view-home | presses ⌃⌥0 |  | quiet 677 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 38 | click-notes | clicks notes's title bar |  | quiet 382 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | pin | chooses Keep This Window in View in Arbor's menu, or takes the tick off |  | quiet 363 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 40 | unhide-safari | clicks its icon in the Dock |  | quiet 383 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | view-all | presses ⌃⌥Space |  | quiet 767 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 42 | view-frame | presses ⌃⌥↩ |  | quiet 816 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 43 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 416 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 441 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 45 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 385 ms; blind for 100 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 46 | view-all | presses ⌃⌥Space |  | quiet 697 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 47 | save-view-1 | presses ⌃⌥⇧1 |  | quiet 537 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 48 | view-in | presses ⌃⌥↓ |  | quiet 714 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 49 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 453 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 363 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | drag-calendar-to-top-edge | drags calendar by its title bar against the top edge of the screen and lets go |  | quiet 374 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | view-desktop | presses ⌃⌥D |  | quiet 657 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 53 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 426 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 54 | send-across | sends the window in front to the other display | terminal ×1 (1, 0 ms) | quiet 1106 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 55 | view-home | presses ⌃⌥0 |  | quiet 703 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 56 | leave-alone | does nothing for half a minute |  | quiet 439 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 57 | view-all | presses ⌃⌥Space |  | quiet 652 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 58 | send-across | sends the window in front to the other display | terminal ×1 (1, 0 ms) | quiet 1093 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 59 | view-in | presses ⌃⌥↓ |  | quiet 599 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 60 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 507 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | dock-down | presses ⌃⌥⌘ and the down arrow | settings ×1 (1, 0 ms) | quiet 716 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 62 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 392 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 63 | minimize-notes | presses ⌘M | notes ×1 (19, 471 ms) | quiet 1140 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 64 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 426 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 65 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 546 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 66 | click-terminal | clicks terminal's title bar |  | quiet 357 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 67 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 980 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 68 | restore-notes | clicks notes's icon in the Dock, which brings its minimized window back | notes ×1 (20, 492 ms) | quiet 1075 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 69 | drag-safari-by | drags safari, which floats, by its title bar 144 across and 116 down, and clicks there 0.3 s after letting go |  | quiet 929 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 70 | click-safari | clicks safari's title bar |  | quiet 407 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 71 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 634 ms |  | ✔ | ✔ | ✘ |  |  | ✔ | ✔ |
| 72 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (3, 136 ms), safari ×1 (2, 12 ms), terminal ×1 (2, 21 ms), settings ×1 (1, 0 ms) | quiet 825 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 73 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 368 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 74 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 398 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 75 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 447 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 76 | launch | starts Arbor | finder ×1 (2, 57 ms), safari ×1 (2, 107 ms), terminal ×1 (2, 107 ms), settings ×1 (2, 63 ms) | quiet 927 ms |  | ✔ | ✔ |  |  |  | ✘ | ✔ |
| 77 | pause | presses ⌃⌥⎋ | finder ×1 (2, 80 ms), safari ×1 (1, 0 ms), terminal ×1 (2, 11 ms), settings ×1 (2, 10 ms) | quiet 971 ms |  |  | ✔ | ✔ | ✘ |  | ✔ | ✔ |
| 78 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 397 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 79 | drag-terminal-to-top-edge | drags terminal by its title bar against the top edge of the screen and lets go | terminal ×1 (9, 376 ms) | quiet 382 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 80 | resume | presses ⌃⌥⎋ | finder ×1 (2, 49 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 1099 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 81 | view-in | presses ⌃⌥↓ | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w715 ×1 (1, 0 ms) | quiet 1014 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 82 | dock-icon-textedit | clicks textedit's icon in the Dock | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w715 ×1 (1, 0 ms) | quiet 524 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 83 | quit-textedit | presses ⌘Q in textedit | terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w715 ×1 (1, 0 ms) | quiet 901 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 84 | reopen-textedit | opens textedit's document again |  | quiet 1109 ms; blind for 763 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 85 | view-left | presses ⌃⌥← | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 979 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 86 | dock-icon-settings | clicks settings's icon in the Dock | finder ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 622 ms; blind for 105 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 87 | undo | presses ⌃⌥Z |  | quiet 712 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 88 | view-back | presses ⌃⌥[ | finder ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 836 ms; blind for 103 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 89 | dock-icon-settings | clicks settings's icon in the Dock | finder ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 422 ms; blind for 162 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 90 | dock-down | presses ⌃⌥⌘ and the down arrow |  | quiet 666 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 91 | save-view-2 | presses ⌃⌥⇧2 |  | quiet 681 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 92 | view-forward | presses ⌃⌥] |  | quiet 629 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 93 | view-forward | presses ⌃⌥] |  | quiet 727 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 94 | click-wallpaper | clicks on the wallpaper | notes ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 427 ms; blind for 158 ms |  |  | ✔ |  |  | ✔ | ✔ | ✔ |
| 95 | click-wallpaper-again | clicks on the wallpaper again | notes ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 377 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 96 | float-all-here | floats every window of this display | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w715 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 910 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 97 | view-left | presses ⌃⌥← |  | quiet 722 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 98 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 425 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 99 | carry-calendar-across | drags calendar, which floats, by its title bar onto the other display and lets go |  | quiet 987 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 100 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 571 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 101 | mirror | presses ⌃⌥⇧R |  | quiet 448 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 102 | click-notes | clicks notes's title bar |  | quiet 394 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 103 | leave-alone | does nothing for half a minute |  | quiet 350 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 104 | drag-preview-to-top-edge | drags preview by its title bar against the top edge of the screen and lets go | preview ×1 (10, 323 ms) | quiet 353 ms; blind for 157 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 105 | display-unplug | the second display: unplug | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×3 (3, 2703 ms), calendar ×3 (3, 2762 ms), textedit ×1 (1, 0 ms) | quiet 441 ms; blind for 927 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 106 | view-home | presses ⌃⌥0 |  | quiet 678 ms; blind for 200 ms |  |  | ✔ |  |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 107 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 353 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 108 | quit | chooses Quit Arbor in Arbor's menu |  | quiet 354 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 109 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 417 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 110 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 430 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 111 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 418 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 112 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 396 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 113 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 372 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 114 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 419 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 115 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 509 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 116 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 572 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 117 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 373 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 118 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 434 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
