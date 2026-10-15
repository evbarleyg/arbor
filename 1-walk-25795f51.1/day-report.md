120 steps in 424 s, 105 of them judged, 10 with a rule broken. The sampler: samples 13709 seconds 360.8 hz 38.0 cost-ms 2.70 late 10 longest-gap-ms 1002 whole-samples 16175 whole-seconds 425.7 whole-late 110.
Input: 397 presses, releases, keys and scrolls reached the apps, half of them within 517 µs, 99 in 100 within 47435 µs, the latest after 75281 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 29, 1108, 3988; dragged 262, 500, 4115; forward 15, 26736, 75281; key 47, 237, 727; up 44, 878, 44379. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 39788; up 8, 727.
The round of input `started` (events, half within µs): forward 8, 30995; up 8, 621.
The round of input `last` (events, half within µs): forward 12, 47430; up 12, 781.
The round of input `after` (events, half within µs): forward 12, 53013; up 12, 870.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 6 | 1 | 22 drag-settings-to-right-edge |
| 2 | nothing moves that the person did not move | 84 | 4 | 41 dock-down, 42 drag-preview-out, 59 dock-right, 92 dock-down |
| 3 | no jolts: a window moves once, to where it ends up | 107 | 2 | 41 dock-down, 99 drag-left-edge-of-textedit |
| 4 | the window you switch to comes to the front and into view | 74 | 3 | 74 drag-left-edge-of-textedit, 84 drag-settings-by, 99 drag-left-edge-of-textedit |
| 5 | quitting, Float All and pause give windows their own sizes back | 4 | 1 | 67 quit |
| 6 | what a person presses reaches the apps, at once | 56 | 0 |  |
| L | no window is lost or stuck | 107 | 0 |  |
| - | what the script itself checked | 107 | 1 | 37 leave-alone |

## Findings

### Rule 1: never fight macOS: where it answers a drag, Arbor stands aside

- ✘ **22 drag-settings-to-right-edge** (drags settings by its title bar against the right edge of the screen and lets go): settings (w61) macOS's tiling preview and Arbor's drop preview were up at the same time [fought]

### Rule 2: nothing moves that the person did not move

- ✘ **41 dock-down** (presses ⌃⌥⌘ and the down arrow): finder (w31) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,120 920×436 · +2755 ms 340,31 920×390
- ✘ **41 dock-down** (presses ⌃⌥⌘ and the down arrow): safari (w34) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×791 · +2755 ms 138,31 1324×390
- ✘ **41 dock-down** (presses ⌃⌥⌘ and the down arrow): terminal (w51) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,51 877×499 · +2755 ms 40,31 877×379
- ✘ **41 dock-down** (presses ⌃⌥⌘ and the down arrow): notes (w54) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +2755 ms 300,31 1000×390
- ✘ **41 dock-down** (presses ⌃⌥⌘ and the down arrow): calendar (w60) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 404,115 936×599 · +2755 ms 404,31 936×503
- ✘ **41 dock-down** (presses ⌃⌥⌘ and the down arrow): settings (w61) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 877,32 723×791 · +2755 ms 877,31 723×470
- ✘ **41 dock-down** (presses ⌃⌥⌘ and the down arrow): mail (w67) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +2755 ms 240,31 1120×390
- ~ **41 dock-down** (presses ⌃⌥⌘ and the down arrow): w69 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +2755 ms 565,83 470×416
- ✘ **41 dock-down** (presses ⌃⌥⌘ and the down arrow): textedit (w128) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +2755 ms 165,31 673×390
- ✘ **42 drag-preview-out** (drags preview out of the arrangement onto the Desktop and lets go): finder (w31) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,31 920×390 · +4645 ms 340,120 920×436
- ✘ **42 drag-preview-out** (drags preview out of the arrangement onto the Desktop and lets go): safari (w34) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×390 · +4645 ms 138,31 1324×790
- ✘ **42 drag-preview-out** (drags preview out of the arrangement onto the Desktop and lets go): terminal (w51) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,31 877×379 · +4645 ms 40,51 877×499
- ✘ **42 drag-preview-out** (drags preview out of the arrangement onto the Desktop and lets go): notes (w54) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,31 1000×390 · +4645 ms 300,105 1000×660
- ✘ **42 drag-preview-out** (drags preview out of the arrangement onto the Desktop and lets go): calendar (w60) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 404,31 936×503 · +4645 ms 404,115 936×599
- ✘ **42 drag-preview-out** (drags preview out of the arrangement onto the Desktop and lets go): settings (w61) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 877,31 723×470 · +4645 ms 877,32 723×790
- ✘ **42 drag-preview-out** (drags preview out of the arrangement onto the Desktop and lets go): mail (w67) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,31 1120×390 · +4645 ms 240,72 1120×630
- ~ **42 drag-preview-out** (drags preview out of the arrangement onto the Desktop and lets go): w69 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,83 470×416 · +4645 ms 565,179 470×416
- ✘ **42 drag-preview-out** (drags preview out of the arrangement onto the Desktop and lets go): textedit (w128) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,31 673×390 · +4645 ms 165,65 673×439
- ✘ **59 dock-right** (presses ⌃⌥⌘ and the right arrow): safari (w34) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×790 · +1095 ms 0,31 794×790
- ✘ **59 dock-right** (presses ⌃⌥⌘ and the right arrow): terminal (w51) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,51 877×499 · +1095 ms 0,51 793×499
- ✘ **59 dock-right** (presses ⌃⌥⌘ and the right arrow): notes (w54) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +1095 ms 0,105 794×660
- ✘ **59 dock-right** (presses ⌃⌥⌘ and the right arrow): calendar (w60) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 404,115 936×599 · +1095 ms 0,115 794×599
- ✘ **59 dock-right** (presses ⌃⌥⌘ and the right arrow): preview (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 451,157 708×424 · +1095 ms 86,157 708×424
- ✘ **59 dock-right** (presses ⌃⌥⌘ and the right arrow): mail (w67) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1095 ms 0,72 881×630
- ~ **59 dock-right** (presses ⌃⌥⌘ and the right arrow): w69 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1095 ms 206,179 470×416
- ✘ **59 dock-right** (presses ⌃⌥⌘ and the right arrow): textedit (w128) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +1095 ms 121,65 673×439
- ✘ **59 dock-right** (presses ⌃⌥⌘ and the right arrow): textedit-new-52 (w169) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 194,94 603×505 · +1095 ms 191,94 603×505
- ✘ **92 dock-down** (presses ⌃⌥⌘ and the down arrow): safari (w34) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×791 · +1128 ms 138,31 1324×390
- ✘ **92 dock-down** (presses ⌃⌥⌘ and the down arrow): terminal (w51) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,51 877×499 · +1128 ms 40,31 877×379
- ✘ **92 dock-down** (presses ⌃⌥⌘ and the down arrow): notes (w54) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +1128 ms 300,31 1000×390
- ✘ **92 dock-down** (presses ⌃⌥⌘ and the down arrow): calendar (w60) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 404,115 936×599 · +1128 ms 404,31 936×503
- ✘ **92 dock-down** (presses ⌃⌥⌘ and the down arrow): mail (w67) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1128 ms 240,31 1120×390
- ~ **92 dock-down** (presses ⌃⌥⌘ and the down arrow): w69 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1128 ms 565,83 470×416
- ✘ **92 dock-down** (presses ⌃⌥⌘ and the down arrow): textedit-new-52 (w169) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 194,94 603×505 · +1128 ms 194,31 603×390
- ✘ **92 dock-down** (presses ⌃⌥⌘ and the down arrow): preview (w198) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +1128 ms 4,31 708×390

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **41 dock-down** (presses ⌃⌥⌘ and the down arrow): the last window came to rest 2477 ms after the key or the button [slow]
- ~ **42 drag-preview-out** (drags preview out of the arrangement onto the Desktop and lets go): the last window came to rest 711 ms after the key or the button [slow]
- ~ **59 dock-right** (presses ⌃⌥⌘ and the right arrow): the last window came to rest 850 ms after the key or the button [slow]
- ~ **65 drag-settings-by** (drags settings, which floats, by its title bar 54 across and 102 down, and clicks there 0.3 s after letting go): settings (w61) changed its size while it was being dragged [jolt]
  - +0 ms 877,35 723×790 · +92 ms 877,42 723×790 · +149 ms 878,38 723×772 · +151 ms 878,38 723×745 · +184 ms 878,38 723×695 · +194 ms 878,38 723×676 · … 24 more … · +1634 ms 923,123 723×626 · +1673 ms 925,127 723×626 · +1727 ms 927,130 723×626 · +1998 ms 928,130 723×626 · +2087 ms 927,130 723×626
- ~ **67 quit** (chooses Quit Arbor in Arbor's menu): w69 of Mail went 238 points out of its way before it ended up [jolt]
  - +0 ms 1805,877 470×416 · +2634 ms 1924,877 470×416 · +2677 ms 565,179 470×416
- ~ **75 view-frame** (presses ⌃⌥↩): the last window came to rest 712 ms after the key or the button [slow]
- ~ **76 view-frame** (presses ⌃⌥↩): the last window came to rest 720 ms after the key or the button [slow]
- ~ **86 view-frame** (presses ⌃⌥↩): the last window came to rest 709 ms after the key or the button [slow]
- ~ **92 dock-down** (presses ⌃⌥⌘ and the down arrow): the last window came to rest 887 ms after the key or the button [slow]
- ~ **93 drag-safari-by** (drags safari, which floats, by its title bar -19 across and 74 down): safari (w34) changed its size while it was being dragged [jolt]
  - +0 ms 138,41 1321×380 · +67 ms 138,43 1321×378 · +113 ms 138,46 1320×375 · +258 ms 138,48 1320×373 · +306 ms 138,51 1319×370 · +392 ms 138,53 1318×368 · … 17 more … · +1901 ms 138,100 1306×321 · +1964 ms 138,103 1306×318 · +2023 ms 138,105 1305×316 · +2334 ms 138,105 1306×316 · +2441 ms 138,105 1305×316
- ~ **97 view-home** (presses ⌃⌥0): the last window came to rest 954 ms after the key or the button [slow]
- ✘ **99 drag-left-edge-of-textedit** (drags the left edge of textedit's window by -30 points): textedit (w128) moved 2 times [jolt]
  - +0 ms 12,433 782×377 · +1172 ms 18,433 776×377 · +1204 ms 19,433 775×377 · +1339 ms 21,433 773×377 · +1372 ms 22,433 772×377 · +1415 ms 23,433 771×377 · … 14 more … · +2416 ms 41,433 753×377 · +2480 ms 42,433 752×377 · +2648 ms 43,433 751×377 · +2774 ms 42,433 752×377 · +3213 ms 12,433 782×377

### Rule 4: the window you switch to comes to the front and into view

- ✘ **74 drag-left-edge-of-textedit** (drags the left edge of textedit's window by 30 points): the app in front changed (to process 17767), and nobody switched [focus]
- ✘ **84 drag-settings-by** (drags settings, which floats, by its title bar 106 across and -30 down, and clicks there 0.3 s after letting go): settings (w61) is not in front: notes (w54) ahead of it, of which 1 cover part of it [behind]
- ✘ **84 drag-settings-by** (drags settings, which floats, by its title bar 106 across and -30 down, and clicks there 0.3 s after letting go): settings (w61) its app is not the one in front (process 11465 is) [focus]
- ✘ **99 drag-left-edge-of-textedit** (drags the left edge of textedit's window by -30 points): the app in front changed (to process 17767), and nobody switched [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **67 quit** (chooses Quit Arbor in Arbor's menu): settings (w61) is 927,130 723×629; its own size was 927,130 723×626 [size-lost]

### Rule -: what the script itself checked

- ~ **33 drag-notes-to-left-edge** (drags notes by its title bar against the left edge of the screen and lets go): the act was not performed: drag_window could not be done [script]
- ✘ **37 leave-alone** (does nothing for half a minute): with nothing to do Arbor used 1.5 % of a core [busy]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (2, 158 ms) | quiet 941 ms; blind for 170 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 430 ms; blind for 2000 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (2, 184 ms) | quiet 870 ms; blind for 732 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (6, 345 ms) | quiet 1089 ms; blind for 138 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (1, 0 ms), w55 ×2 (10, 1050 ms), w57 ×1 (6, 220 ms) | quiet 384 ms; blind for 185 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×2 (4, 382 ms) | quiet 1360 ms; blind for 140 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (2, 246 ms) | quiet 657 ms; blind for 309 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (1, 0 ms) | quiet 498 ms; blind for 212 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | mail ×1 (2, 30 ms), w69 ×1 (3, 108 ms) | quiet 555 ms; blind for 2048 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (40, 4025 ms) | quiet 1442 ms; blind for 120 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (32, 2216 ms) | quiet 1056 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 374 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 726 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | launch | starts Arbor |  | quiet 1150 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 15 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 775 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 16 | cmd-tab-3 | holds ⌘ and presses Tab 3 time(s) |  | quiet 449 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 17 | hold | holds the view, as for a shared screen |  | quiet 375 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 18 | show-desktop-while-held | presses ⌃⌥D, which would show the Desktop: the view is held |  | quiet 788 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 19 | release | lets the view go again |  | quiet 363 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 20 | view-all | presses ⌃⌥Space |  | quiet 693 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 21 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 521 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 22 | drag-settings-to-right-edge | drags settings by its title bar against the right edge of the screen and lets go | settings ×1 (8, 285 ms) | quiet 381 ms | ✘ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 405 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | view-back | presses ⌃⌥[ |  | quiet 828 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 25 | view-out | presses ⌃⌥↑ |  | quiet 812 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 26 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 405 ms; blind for 1002 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | view-all | presses ⌃⌥Space |  | quiet 707 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 28 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 412 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 29 | quit-textedit | presses ⌘Q in textedit |  | quiet 694 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 30 | reopen-textedit | opens textedit's document again |  | quiet 831 ms; blind for 225 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 31 | new-window-textedit | presses ⌘N in textedit |  | quiet 1206 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 32 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 401 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | drag-notes-to-left-edge | drags notes by its title bar against the left edge of the screen and lets go |  | quiet 406 ms |  |  |  |  |  |  |  | ~ |
| 34 | click-new-window | clicks the title bar of the window that ⌘N opened |  | quiet 392 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | close-window | presses ⌘W |  | quiet 1047 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 36 | focus-down | presses ⌃⌥⇧ and the down arrow |  | quiet 356 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 37 | leave-alone | does nothing for half a minute |  | quiet 365 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 38 | view-in | presses ⌃⌥↓ |  | quiet 655 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 39 | view-all | presses ⌃⌥Space |  | quiet 678 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 40 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 441 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | dock-down | presses ⌃⌥⌘ and the down arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1045 ms; blind for 101 ms |  | ✘ | ✘ | ✔ |  |  | ✔ | ✔ |
| 42 | drag-preview-out | drags preview out of the arrangement onto the Desktop and lets go | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1012 ms | ✔ | ✘ | ~ | ✔ | ✔ | ✔ | ✔ | ✔ |
| 43 | focus-down | presses ⌃⌥⇧ and the down arrow |  | quiet 357 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 44 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 419 ms; blind for 105 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | new-window-finder | presses ⌘N in finder |  | quiet 1146 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 46 | view-all | presses ⌃⌥Space |  | quiet 629 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 47 | click-settings | clicks settings's title bar |  | quiet 436 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | pin | chooses Keep This Window in View in Arbor's menu, or takes the tick off |  | quiet 411 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 49 | click-new-window | clicks the title bar of the window that ⌘N opened |  | quiet 363 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | close-window | presses ⌘W |  | quiet 1005 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 51 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 469 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | new-window-textedit | presses ⌘N in textedit |  | quiet 1156 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 53 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 544 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 54 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 414 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | minimize-preview | presses ⌘M | preview ×1 (20, 407 ms) | quiet 1301 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 56 | restore-preview | clicks its miniature in the Dock | preview ×1 (17, 496 ms) | quiet 1060 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | save-view-3 | presses ⌃⌥⇧3 |  | quiet 635 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 58 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 476 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 59 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms), textedit ×1 (1, 0 ms), textedit-new-52 ×1 (1, 0 ms) | quiet 1165 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 60 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 426 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | quit-preview | presses ⌘Q in preview |  | quiet 870 ms; blind for 100 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 62 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms), textedit ×1 (1, 0 ms), textedit-new-52 ×1 (1, 0 ms) | quiet 828 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 63 | window-menu-finder | chooses finder's first window in the Window menu |  | quiet 1362 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 64 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 662 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 65 | drag-settings-by | drags settings, which floats, by its title bar 54 across and 102 down, and clicks there 0.3 s after letting go |  | quiet 979 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 66 | reopen-preview | opens preview's document again |  | quiet 957 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 67 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (2, 50 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (2, 43 ms), w69 ×1 (2, 43 ms), textedit ×1 (1, 0 ms), textedit-new-52 ×1 (1, 0 ms) | quiet 928 ms; blind for 338 ms |  |  | ~ |  | ✘ |  | ✔ | ✔ |
| 68 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 357 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 69 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 389 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 70 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 542 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 71 | launch | starts Arbor | finder ×1 (2, 58 ms) | quiet 867 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 72 | arrange | presses ⌃⌥A | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms), textedit ×1 (1, 0 ms), textedit-new-52 ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 1723 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 73 | view-all | presses ⌃⌥Space |  | quiet 588 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 74 | drag-left-edge-of-textedit | drags the left edge of textedit's window by 30 points |  | quiet 1085 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 75 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), textedit ×1 (1, 0 ms), textedit-new-52 ×1 (1, 0 ms) | quiet 1094 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 76 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), textedit ×1 (1, 0 ms), textedit-new-52 ×1 (1, 0 ms) | quiet 907 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 77 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 480 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 78 | new-window-textedit | presses ⌘N in textedit |  | quiet 1261 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 79 | drag-settings-by | drags settings, which floats, by its title bar -28 across and 58 down, and clicks there 0.3 s after letting go |  | quiet 961 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 80 | click-new-window | clicks the title bar of the window that ⌘N opened |  | quiet 550 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 81 | close-window | presses ⌘W |  | quiet 1080 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 82 | click-finder | clicks finder's title bar |  | quiet 398 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 83 | minimize-finder | presses ⌘M | finder ×1 (11, 257 ms), notes ×1 (1, 0 ms) | quiet 1519 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 84 | drag-settings-by | drags settings, which floats, by its title bar 106 across and -30 down, and clicks there 0.3 s after letting go |  | quiet 945 ms | ✔ | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 85 | restore-finder | clicks its miniature in the Dock | finder ×1 (12, 272 ms), notes ×1 (1, 0 ms) | quiet 1383 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 86 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), textedit ×1 (1, 0 ms), textedit-new-52 ×1 (1, 0 ms) | quiet 968 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 87 | view-right | presses ⌃⌥→ | finder ×1 (1, 0 ms) | quiet 710 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 88 | dock-icon-terminal | clicks terminal's icon in the Dock | terminal ×1 (1, 0 ms) | quiet 511 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 89 | undo | presses ⌃⌥Z | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms), textedit ×1 (1, 0 ms), textedit-new-52 ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 1280 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 90 | view-back | presses ⌃⌥[ | finder ×1 (1, 0 ms) | quiet 686 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 91 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 484 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 92 | dock-down | presses ⌃⌥⌘ and the down arrow | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms), textedit ×1 (1, 0 ms), textedit-new-52 ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 959 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 93 | drag-safari-by | drags safari, which floats, by its title bar -19 across and 74 down |  | quiet 1191 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 94 | view-left | presses ⌃⌥← |  | quiet 741 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 95 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 409 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 96 | new-window-terminal | presses ⌘N in terminal |  | quiet 1226 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 97 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms), textedit ×1 (1, 0 ms), textedit-new-52 ×1 (1, 0 ms), terminal-new-96 ×1 (1, 0 ms) | quiet 1059 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 98 | close-window | presses ⌘W |  | quiet 1071 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 99 | drag-left-edge-of-textedit | drags the left edge of textedit's window by -30 points | textedit ×2 (24, 2041 ms) | quiet 1130 ms |  | ✔ | ✘ | ✘ |  | ✔ | ✔ | ✔ |
| 100 | pause | presses ⌃⌥⎋ | finder ×1 (2, 14 ms), safari ×1 (1, 0 ms), terminal ×1 (2, 22 ms), notes ×1 (2, 11 ms), calendar ×1 (2, 16 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms), textedit ×1 (2, 15 ms), textedit-new-52 ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 1118 ms |  |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 101 | click-terminal | clicks terminal's title bar |  | quiet 439 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 102 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 416 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 103 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 471 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 104 | click-terminal | clicks terminal's title bar |  | quiet 370 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 105 | click-settings | clicks settings's title bar |  | quiet 466 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 106 | click-terminal | clicks terminal's title bar |  | quiet 374 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 107 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 385 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 108 | resume | presses ⌃⌥⎋ | finder ×1 (1, 0 ms), safari ×1 (2, 67 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (2, 66 ms), mail ×1 (2, 58 ms), w69 ×1 (2, 58 ms), textedit ×1 (1, 0 ms), textedit-new-52 ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 1162 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 109 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 799 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 110 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms), textedit ×1 (2, 25 ms), textedit-new-52 ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 915 ms |  |  | ✔ |  | ✔ |  | ✔ | ✔ |
| 111 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 630 ms; blind for 116 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 112 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 409 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 113 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 425 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 114 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 387 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 115 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 411 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 116 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 385 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 117 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 498 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 118 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 505 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 119 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 418 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 120 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 397 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
