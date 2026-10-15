113 steps in 380 s, 96 of them judged, 11 with a rule broken. The sampler: samples 13331 seconds 332.8 hz 40.1 cost-ms 2.87 late 30 longest-gap-ms 669 whole-samples 15269 whole-seconds 381.2 whole-late 49.
Input: 278 presses, releases, keys and scrolls reached the apps, half of them within 628 µs, 99 in 100 within 88443 µs, the latest after 109326 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 21, 749, 5168; dragged 198, 626, 11715; forward 9, 26529, 109326; key 20, 295, 1525; up 30, 780, 51109. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 1, 100541; up 1, 3625.
The round of input `started` (events, half within µs): .
The round of input `last` (events, half within µs): .
The round of input `after` (events, half within µs): .
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 6 | 0 |  |
| 2 | nothing moves that the person did not move | 65 | 2 | 43 leave-full-screen, 80 quit-textedit |
| 3 | no jolts: a window moves once, to where it ends up | 101 | 5 | 16 display-plug, 26 display-plug, 28 display-unplug, 74 launch, 100 display-unplug |
| 4 | the window you switch to comes to the front and into view | 55 | 1 | 69 dock-left |
| 5 | quitting, Float All and pause give windows their own sizes back | 3 | 3 | 70 quit, 75 pause, 103 quit |
| 6 | what a person presses reaches the apps, at once | 42 | 0 |  |
| L | no window is lost or stuck | 101 | 1 | 74 launch |
| - | what the script itself checked | 101 | 0 |  |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **43 leave-full-screen** (presses ⌃⌘F again): safari (w464) is not back where it was after step 41: 138,31 1324×791, it was at 12,43 1576×767 [moved-unasked]
- ✘ **80 quit-textedit** (presses ⌘Q in textedit): calendar (w484) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 332,127 937×600 · +891 ms -936,770 937×600
- ✘ **80 quit-textedit** (presses ⌘Q in textedit): preview (w489) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +891 ms -707,770 708×424
- ✘ **80 quit-textedit** (presses ⌘Q in textedit): mail (w492) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +891 ms -1119,770 1120×630
- ~ **80 quit-textedit** (presses ⌘Q in textedit): w495 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +891 ms -794,877 470×416

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **16 display-plug** (the second display: plug): terminal (w480) moved 2 times [jolt]
  - +0 ms 1,35 1598×784 · +468 ms 0,31 1598×784 · +5676 ms 0,31 1600×791
- ✘ **26 display-plug** (the second display: plug): terminal (w480) moved 2 times [jolt]
  - +0 ms 0,31 1600×791 · +675 ms 0,31 1598×784 · +1024 ms 0,31 1600×791
- ✘ **26 display-plug** (the second display: plug): notes (w483) moved 3 times [jolt]
  - +0 ms 300,165 1000×600 · +27 ms -1140,115 1000×600 · +675 ms 1740,115 1000×600 · +2679 ms 2056,208 1000×600
- ✘ **28 display-unplug** (the second display: unplug): notes (w483) went 200 points out of its way before it ended up [jolt]
  - +0 ms 2056,208 1000×600 · +1 ms 776,308 1000×600 · +157 ms 300,165 1000×600
- ~ **69 dock-left** (presses ctrl+opt+left): the last window came to rest 736 ms after the key or the button [slow]
- ✘ **74 launch** (starts Arbor): settings (w487) moved 2 times [jolt]
  - +0 ms 437,85 723×625 · +482 ms 437,85 723×470 · +752 ms 437,85 723×625
- ~ **76 drag-terminal-to-top-edge** (drags terminal by its title bar against the top edge of the screen and lets go): terminal (w480) changed its size while it was being dragged [jolt]
  - +0 ms 1,31 1600×790 · +838 ms 2,31 1600×790 · +933 ms 9,31 1585×785 · +960 ms 55,31 1492×748 · +997 ms 294,31 1013×559 · +1068 ms 332,31 937×529 · +1076 ms 344,31 914×520 · +1117 ms 361,31 880×506 · +1186 ms 367,31 867×501 · +1239 ms 369,31 864×500 · +1983 ms 370,31 864×500 · +2139 ms 369,31 864×500
- ✘ **100 display-unplug** (the second display: unplug): notes (w483) moved 3 times [jolt]
  - +0 ms 2056,208 1000×600 · +37 ms 297,130 1000×600 · +627 ms 300,165 1000×600 · +2446 ms 456,208 1000×600
- ✘ **100 display-unplug** (the second display: unplug): calendar (w484) moved 2 times [jolt]
  - +0 ms 2224,208 937×600 · +37 ms 420,130 937×600 · +627 ms 464,31 937×600

### Rule 4: the window you switch to comes to the front and into view

- ✘ **69 dock-left** (presses ctrl+opt+left): safari (w464) is not wholly in view: 0% of it, at -573,770 574×791 in 0,31 1600×791 and 1600,31 1920×1049 [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **70 quit** (chooses Quit Arbor in Arbor's menu): textedit (w475) is 165,65 656×422; its own size was 165,65 673×439 [size-lost]
- ✘ **70 quit** (chooses Quit Arbor in Arbor's menu): terminal (w480) is 0,31 1600×790; its own size was 1,35 1598×784 [size-lost]
- ✘ **75 pause** (presses ⌃⌥⎋): textedit (w475) is 165,65 656×422; its own size was 165,65 673×439 [size-lost]
- ✘ **75 pause** (presses ⌃⌥⎋): terminal (w480) is 0,31 1600×790; its own size was 1,35 1598×784 [size-lost]
- ✘ **103 quit** (chooses Quit Arbor in Arbor's menu): terminal (w480) is 0,37 1597×782; its own size was 0,34 1599×785 [size-lost]
- ✘ **103 quit** (chooses Quit Arbor in Arbor's menu): notes (w483) has its size back but not its place: 456,208 1000×600, it was at 2056,208 1000×600 [size-lost]
- ✘ **103 quit** (chooses Quit Arbor in Arbor's menu): calendar (w484) has its size back but not its place: 464,31 937×600, it was at 2224,208 937×600 [size-lost]
- ✘ **103 quit** (chooses Quit Arbor in Arbor's menu): textedit (w928) is 165,65 656×422; its own size was 165,65 673×439 [size-lost]

### Rule L: no window is lost or stuck

- ✘ **74 launch** (starts Arbor): safari (w464) is out of view: 0% of it is on a display, at -573,770 574×791 [lost]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 888 ms; blind for 125 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 422 ms; blind for 974 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (4, 273 ms) | quiet 1239 ms; blind for 424 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (3, 125 ms) | quiet 1101 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (3, 126 ms) | quiet 1136 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×2 (4, 368 ms) | quiet 1346 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×2 (3, 286 ms) | quiet 807 ms; blind for 267 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (4, 129 ms) | quiet 1063 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w495 ×1 (6, 172 ms) | quiet 773 ms; blind for 1021 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (10, 1871 ms) | quiet 1403 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (37, 2310 ms) | quiet 1002 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 412 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 378 ms; blind for 149 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | launch | starts Arbor |  | quiet 1157 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 15 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 372 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 16 | display-plug | the second display: plug | textedit ×1 (1, 0 ms), terminal ×2 (2, 5208 ms) | quiet 352 ms; blind for 669 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 17 | view-home | chooses `home` from Arbor's menu |  | quiet 363 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 18 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 476 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | carry-notes-across | drags notes, which floats, by its title bar onto the other display and lets go |  | quiet 1104 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | display-unplug | the second display: unplug | notes ×1 (1, 0 ms) | quiet 407 ms; blind for 504 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 21 | view-home | chooses `home` from Arbor's menu |  | quiet 355 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 22 | display-plug | the second display: plug | notes ×1 (1, 0 ms) | quiet 356 ms; blind for 234 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 23 | view-home | chooses `home` from Arbor's menu |  | quiet 355 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 24 | display-unplug | the second display: unplug | notes ×1 (1, 0 ms) | quiet 422 ms; blind for 131 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 25 | view-home | chooses `home` from Arbor's menu |  | quiet 369 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 26 | display-plug | the second display: plug | terminal ×2 (2, 349 ms), notes ×3 (3, 2652 ms) | quiet 407 ms; blind for 208 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 27 | view-home | chooses `home` from Arbor's menu |  | quiet 355 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 28 | display-unplug | the second display: unplug | notes ×1 (2, 156 ms) | quiet 405 ms; blind for 156 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 29 | view-home | chooses `home` from Arbor's menu |  | quiet 428 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 30 | view-home | chooses `home` from Arbor's menu |  | quiet 387 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 31 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 524 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 398 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | hide-safari | presses ⌘H |  | quiet 977 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 34 | display-plug | the second display: plug | notes ×1 (1, 0 ms) | quiet 376 ms; blind for 359 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 35 | view-home | chooses `home` from Arbor's menu |  | quiet 379 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 36 | click-notes | clicks notes's title bar |  | quiet 365 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | pin | chooses Keep This Window in View in Arbor's menu, or takes the tick off |  | quiet 372 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 38 | unhide-safari | clicks its icon in the Dock |  | quiet 352 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | view-all | presses ctrl+opt+space |  | quiet 621 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 40 | view-frame | presses ctrl+opt+return | safari ×1 (2, 59 ms) | quiet 841 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 41 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 415 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 355 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 43 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 405 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 44 | view-all | presses ctrl+opt+space |  | quiet 701 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 45 | save-view-1 | chooses `save-view 1` from Arbor's menu |  | quiet 424 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 46 | view-in | chooses `in` from Arbor's menu |  | quiet 402 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 47 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 384 ms; blind for 121 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | click-terminal | clicks terminal's title bar |  | quiet 397 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 360 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | drag-calendar-to-top-edge | drags calendar by its title bar against the top edge of the screen and lets go |  | quiet 420 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | view-desktop | chooses `desktop` from Arbor's menu |  | quiet 376 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 52 | send-across | sends the window in front to the other display | calendar ×1 (1, 0 ms) | quiet 1053 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 53 | view-home | chooses `home` from Arbor's menu |  | quiet 372 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 54 | leave-alone | does nothing for half a minute |  | quiet 355 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 55 | view-all | presses ctrl+opt+space |  | quiet 794 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 56 | send-across | sends the window in front to the other display | calendar ×1 (1, 0 ms) | quiet 1097 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 57 | view-in | chooses `in` from Arbor's menu |  | quiet 373 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 58 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 674 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 59 | dock-down | chooses `dock bottom` from Arbor's menu | settings ×1 (1, 0 ms) | quiet 896 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 60 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 555 ms; blind for 150 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | minimize-notes | presses ⌘M | notes ×1 (19, 475 ms) | quiet 1064 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 62 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 405 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 63 | dock-right | presses ctrl+opt+right | finder ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 822 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 64 | click-terminal | clicks terminal's title bar |  | quiet 475 ms; blind for 113 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 65 | dock-right | presses ctrl+opt+right | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 903 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 66 | restore-notes | clicks notes's icon in the Dock, which brings its minimized window back | notes ×1 (17, 623 ms) | quiet 1030 ms; blind for 147 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 67 | drag-safari-by | drags safari, which floats, by its title bar 144 across and 116 down, and clicks there 0.3 s after letting go |  | quiet 872 ms; blind for 123 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 68 | click-safari | clicks safari's title bar |  | quiet 355 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 69 | dock-left | presses ctrl+opt+left | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 918 ms; blind for 147 ms |  | ✔ | ~ | ✘ |  |  | ✔ | ✔ |
| 70 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (2, 12 ms), terminal ×1 (2, 32 ms), settings ×1 (1, 0 ms) | quiet 797 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 71 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 358 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 72 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 478 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 73 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 493 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 74 | launch | starts Arbor | finder ×1 (1, 0 ms), safari ×1 (2, 192 ms), terminal ×1 (2, 181 ms), settings ×2 (2, 270 ms) | quiet 584 ms |  | ✔ | ✘ |  |  |  | ✘ | ✔ |
| 75 | pause | presses ⌃⌥⎋ | finder ×1 (2, 132 ms), safari ×1 (2, 86 ms), terminal ×1 (1, 0 ms) | quiet 1078 ms |  |  | ✔ | ✔ | ✘ |  | ✔ | ✔ |
| 76 | drag-terminal-to-top-edge | drags terminal by its title bar against the top edge of the screen and lets go | terminal ×1 (10, 318 ms) | quiet 422 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 77 | resume | presses ⌃⌥⎋ | finder ×1 (2, 70 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 1036 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 78 | view-in | chooses `in` from Arbor's menu | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w495 ×1 (1, 0 ms) | quiet 1235 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 79 | dock-icon-textedit | clicks textedit's icon in the Dock | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w495 ×1 (1, 0 ms) | quiet 463 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 80 | quit-textedit | presses ⌘Q in textedit | terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w495 ×1 (1, 0 ms) | quiet 963 ms; blind for 102 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 81 | reopen-textedit | opens textedit's document again |  | quiet 1050 ms; blind for 338 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 82 | dock-icon-settings | clicks settings's icon in the Dock | terminal ×1 (1, 0 ms), settings ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 671 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 83 | undo | presses ctrl+opt+z |  | quiet 777 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 84 | view-back | presses ctrl+opt+[ | terminal ×1 (1, 0 ms), settings ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 946 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 85 | dock-icon-settings | clicks settings's icon in the Dock | terminal ×1 (1, 0 ms), settings ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 425 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 86 | dock-down | chooses `dock bottom` from Arbor's menu |  | quiet 422 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 87 | save-view-2 | chooses `save-view 2` from Arbor's menu |  | quiet 393 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 88 | view-forward | chooses `forward` from Arbor's menu |  | quiet 357 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 89 | view-forward | chooses `forward` from Arbor's menu |  | quiet 358 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 90 | click-wallpaper | clicks on the wallpaper | notes ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 447 ms; blind for 144 ms |  |  | ✔ |  |  | ✔ | ✔ | ✔ |
| 91 | click-wallpaper-again | clicks on the wallpaper again | notes ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 382 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 92 | float-all-here | floats every window of this display | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w495 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 843 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 93 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 454 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 94 | carry-calendar-across | drags calendar, which floats, by its title bar onto the other display and lets go |  | quiet 1018 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 95 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 464 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 96 | mirror | chooses `mirror` from Arbor's menu |  | quiet 415 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 97 | click-notes | clicks notes's title bar |  | quiet 350 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 98 | leave-alone | does nothing for half a minute |  | quiet 413 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 99 | drag-preview-to-top-edge | drags preview by its title bar against the top edge of the screen and lets go | preview ×1 (10, 303 ms) | quiet 367 ms; blind for 124 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 100 | display-unplug | the second display: unplug | terminal ×1 (1, 0 ms), notes ×3 (3, 2409 ms), calendar ×2 (2, 590 ms), textedit ×1 (1, 0 ms) | quiet 599 ms; blind for 590 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 101 | view-home | chooses `home` from Arbor's menu |  | quiet 424 ms |  |  | ✔ |  |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 102 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 371 ms; blind for 160 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 103 | quit | chooses Quit Arbor in Arbor's menu |  | quiet 361 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 104 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 377 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 105 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 476 ms; blind for 126 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 106 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 358 ms; blind for 188 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 107 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 414 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 108 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 474 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 109 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 430 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 110 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 441 ms; blind for 106 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 111 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 566 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 112 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 473 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 113 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 479 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
