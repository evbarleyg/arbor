103 steps in 392 s, 85 of them judged, 13 with a rule broken. The sampler: samples 12562 seconds 335.6 hz 37.4 cost-ms 3.17 late 58 longest-gap-ms 1275 whole-samples 14718 whole-seconds 393.2 whole-late 111.
Input: 465 presses, releases, keys and scrolls reached the apps, half of them within 670 µs, 99 in 100 within 58280 µs, the latest after 97879 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 47, 787, 3948; dragged 330, 670, 6032; forward 8, 45726, 97879; key 25, 320, 920; up 55, 633, 94515. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 31907; up 8, 655.
The round of input `started` (events, half within µs): forward 8, 28461; up 8, 1006.
The round of input `last` (events, half within µs): forward 1, 82800; up 1, 17798.
The round of input `after` (events, half within µs): .
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 16 | 2 | 80 drag-preview-to-right-edge, 83 drag-preview-to-right-edge |
| 2 | nothing moves that the person did not move | 87 | 9 | 17 dock-left, 32 drag-safari-by, 34 drag-settings-by, 60 drag-textedit-by, 71 drag-finder-by, 81 drag-textedit-to-top-edge, 85 minimize-textedit, 86 restore-textedit, 87 drag-textedit-by |
| 3 | no jolts: a window moves once, to where it ends up | 90 | 2 | 34 drag-settings-by, 80 drag-preview-to-right-edge |
| 4 | the window you switch to comes to the front and into view | 73 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 1 | 1 | 93 quit |
| 6 | what a person presses reaches the apps, at once | 59 | 0 |  |
| L | no window is lost or stuck | 90 | 0 |  |
| - | what the script itself checked | 90 | 2 | 53 leave-alone, 93 quit |

## Findings

### Rule 1: never fight macOS: where it answers a drag, Arbor stands aside

- ✘ **80 drag-preview-to-right-edge** (drags preview by its title bar against the right edge of the screen and lets go): preview (w61) macOS's tiling preview and Arbor's drop preview were up at the same time [fought]
- ✘ **80 drag-preview-to-right-edge** (drags preview by its title bar against the right edge of the screen and lets go): preview (w61) macOS answered the drag and tiled the window, and it was moved again afterwards [fought]
- ✘ **83 drag-preview-to-right-edge** (drags preview by its title bar against the right edge of the screen and lets go): preview (w61) macOS's tiling preview and Arbor's drop preview were up at the same time [fought]

### Rule 2: nothing moves that the person did not move

- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): finder (w30) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,120 920×436 · +1586 ms 806,120 794×436
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): safari (w33) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×791 · +1586 ms 806,31 794×791
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): textedit (w43) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +1586 ms 806,65 673×439
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): terminal (w49) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,51 877×499 · +1586 ms 806,51 793×499
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): notes (w52) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +1586 ms 806,105 794×660
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): calendar (w58) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 404,115 936×599 · +1586 ms 806,115 794×599
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): settings (w59) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +1586 ms 806,85 723×625
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): mail (w65) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1586 ms 719,72 881×630
- ~ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): w67 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1586 ms 925,179 470×416
- ✘ **32 drag-safari-by** (drags safari, which floats, by its title bar 143 across and 156 down): notes (w52) moved, and the step did not name it [moved-unasked]
  - +0 ms 879,43 709×767 · +4625 ms 879,433 709×377
- ✘ **34 drag-settings-by** (drags settings, which floats, by its title bar -175 across and 148 down): safari (w33) moved, and the step did not name it [moved-unasked]
  - +0 ms 879,43 709×378 · +4548 ms 1014,43 574×378
- ~ **41 double-click-mail** (double-clicks mail's title bar: macOS zooms the window): w67 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 925,179 470×416 · +884 ms 923,179 470×416 · +1001 ms 895,182 470×416 · +1065 ms 794,193 470×416 · +1084 ms 680,206 470×416 · +1210 ms 566,218 470×416 · +1274 ms 565,218 470×416
- ~ **42 double-click-mail-again** (double-clicks it again: macOS takes the window back): w67 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,218 470×416 · +816 ms 566,218 470×416 · +856 ms 576,217 470×416 · +916 ms 613,213 470×416 · +949 ms 679,206 470×416 · +989 ms 744,199 470×416 · +1042 ms 811,191 470×416 · +1116 ms 867,185 470×416 · +1145 ms 913,180 470×416 · +1199 ms 925,179 470×416
- ✘ **60 drag-textedit-by** (drags textedit, which floats, by its title bar -93 across and 125 down, and clicks there 0.3 s after letting go): preview (w61) moved, and the step did not name it [moved-unasked]
  - +0 ms 12,43 708×767 · +4165 ms 12,433 708×377
- ✘ **71 drag-finder-by** (drags finder, which floats, by its title bar 203 across and -36 down): notes (w52) moved, and the step did not name it [moved-unasked]
  - +0 ms 879,433 709×377 · +4391 ms 879,487 709×323
- ✘ **81 drag-textedit-to-top-edge** (drags textedit by its title bar against the top edge of the screen and lets go): terminal (w49) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,51 795×499 · +5152 ms 0,51 263×499
- ✘ **81 drag-textedit-to-top-edge** (drags textedit by its title bar against the top edge of the screen and lets go): calendar (w58) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,115 794×599 · +5152 ms 0,115 680×599
- ✘ **81 drag-textedit-to-top-edge** (drags textedit by its title bar against the top edge of the screen and lets go): mail (w65) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 719,72 881×630 · +5152 ms 0,72 881×630
- ~ **81 drag-textedit-to-top-edge** (drags textedit by its title bar against the top edge of the screen and lets go): w67 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 925,179 470×416 · +5152 ms 206,179 470×416
- ✘ **85 minimize-textedit** (presses ⌘M): safari (w194) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1014,43 574×378 · +1428 ms 0,43 574×378
- ✘ **86 restore-textedit** (clicks its miniature in the Dock): safari (w194) is not back where it was after step 84: 0,43 574×378, it was at 1014,43 574×378 [moved-unasked]
- ✘ **87 drag-textedit-by** (drags textedit, which floats, by its title bar -138 across and 121 down): finder (w30) moved, and the step did not name it [moved-unasked]
  - +0 ms 274,43 1314×252 · +4539 ms 937,43 651×252

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **32 drag-safari-by** (drags safari, which floats, by its title bar 143 across and 156 down): the last window came to rest 719 ms after the key or the button [slow]
- ✘ **34 drag-settings-by** (drags settings, which floats, by its title bar -175 across and 148 down): settings (w59) ended neither where it was let go nor where the preview was: let go at 704,185 723×625, the preview at 879,43 349×378, now at 1599,770 723×470 [stuck]
  - +0 ms 704,185 723×625 · +758 ms 1599,770 723×470
- ~ **71 drag-finder-by** (drags finder, which floats, by its title bar 203 across and -36 down): the last window came to rest 778 ms after the key or the button [slow]
- ✘ **80 drag-preview-to-right-edge** (drags preview by its title bar against the right edge of the screen and lets go): preview (w61) was 43 points ahead of the pointer's travel and 0 behind it at the most [pulled]
  - +0 ms 23,433 708×377 · +66 ms 65,433 708×377 · +129 ms 150,433 708×377 · +262 ms 193,433 708×377 · +321 ms 236,433 708×377 · +362 ms 278,434 708×377 · … 18 more … · +1955 ms 1216,437 708×377 · +1966 ms 1259,437 708×377 · +2020 ms 1302,438 708×377 · +2224 ms 1303,438 708×377 · +2353 ms 1302,438 708×377
- ✘ **80 drag-preview-to-right-edge** (drags preview by its title bar against the right edge of the screen and lets go): preview (w61) moved 2 times [jolt]
  - +0 ms 1302,438 708×377 · +1528 ms 1299,436 709×380 · +2211 ms 800,31 800×791
- ~ **83 drag-preview-to-right-edge** (drags preview by its title bar against the right edge of the screen and lets go): preview (w61) changed its size while it was being dragged [jolt]
  - +0 ms 800,44 800×791 · +102 ms 800,72 800×791 · +172 ms 834,58 757×596 · +187 ms 839,58 745×540 · +210 ms 844,58 735×495 · +227 ms 863,71 727×462 · … 27 more … · +1903 ms 1280,410 709×378 · +1958 ms 1297,424 709×378 · +2192 ms 1298,424 709×378 · +2283 ms 1297,424 709×378 · +3772 ms 1253,389 717×415
- ~ **87 drag-textedit-by** (drags textedit, which floats, by its title bar -138 across and 121 down): textedit (w212) changed its size while it was being dragged [jolt]
  - +0 ms -5,35 1600×791 · +85 ms -14,44 1600×791 · +114 ms -14,44 1588×791 · +176 ms 194,39 1190×780 · +233 ms 363,43 840×771 · +278 ms 406,43 752×769 · … 25 more … · +1956 ms 317,139 709×768 · +2006 ms 313,143 709×768 · +2079 ms 308,147 709×768 · +2271 ms 309,147 709×768 · +2411 ms 308,147 709×768

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **93 quit** (chooses Quit Arbor in Arbor's menu): finder (w30) is 340,120 920×436; its own size was 879,43 709×252 [size-lost]
- ✘ **93 quit** (chooses Quit Arbor in Arbor's menu): terminal (w49) is 806,51 795×499; its own size was 40,51 877×499 [size-lost]
- ✘ **93 quit** (chooses Quit Arbor in Arbor's menu): calendar (w58) is 806,115 794×599; its own size was 404,115 936×599 [size-lost]
- ✘ **93 quit** (chooses Quit Arbor in Arbor's menu): settings (w59) is 437,85 723×625; its own size was 1599,770 723×470 [size-lost]
- ✘ **93 quit** (chooses Quit Arbor in Arbor's menu): w67 of Mail has its size back but not its place: 925,179 470×416, it was at 565,179 470×416 [size-lost]

### Rule -: what the script itself checked

- ✘ **53 leave-alone** (does nothing for half a minute): with nothing to do Arbor used 1.4 % of a core [busy]
- ~ **68 drag-mail-by** (drags mail, which floats, by its title bar -106 across and 8 down, and clicks there 0.3 s after letting go): the act was not performed: drag_window could not be done [script]
- ✘ **93 quit** (chooses Quit Arbor in Arbor's menu): Arbor's process ended, and nobody asked it to [crash]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 783 ms; blind for 204 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 362 ms; blind for 659 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (3, 269 ms) | quiet 1401 ms; blind for 760 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (5, 353 ms) | quiet 1134 ms; blind for 246 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (3, 94 ms), w53 ×2 (15, 1122 ms), w55 ×1 (9, 251 ms) | quiet 369 ms; blind for 149 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×2 (5, 426 ms) | quiet 1363 ms; blind for 124 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings |  | quiet 462 ms; blind for 404 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (2, 70 ms) | quiet 975 ms; blind for 118 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | mail ×1 (2, 42 ms), w67 ×1 (7, 214 ms) | quiet 912 ms; blind for 1672 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (41, 4466 ms) | quiet 1410 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (38, 2357 ms) | quiet 1083 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 389 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 669 ms; blind for 658 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | launch | starts Arbor |  | quiet 1070 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 15 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 839 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 16 | click-preview | clicks preview's title bar |  | quiet 481 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w67 ×1 (1, 0 ms) | quiet 942 ms; blind for 161 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 18 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 404 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | dock-right | presses ⌃⌥⌘ and the right arrow | notes ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 860 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 20 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 537 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | hide-safari | presses ⌘H |  | quiet 934 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 22 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 517 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | new-window-terminal | presses ⌘N in terminal |  | quiet 1135 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 24 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 541 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 25 | unhide-safari | clicks its icon in the Dock |  | quiet 351 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 490 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 27 | click-new-window | clicks the title bar of the window that ⌘N opened |  | quiet 439 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | close-window | presses ⌘W |  | quiet 1096 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 29 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 470 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 447 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 561 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | drag-safari-by | drags safari, which floats, by its title bar 143 across and 156 down | safari ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 1120 ms | ✔ | ✘ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 690 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | drag-settings-by | drags settings, which floats, by its title bar -175 across and 148 down | safari ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 1528 ms | ✔ | ✘ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 428 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 36 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 423 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | drag-textedit-to-top-edge | drags textedit by its title bar against the top edge of the screen and lets go | textedit ×1 (5, 187 ms) | quiet 386 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 474 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 39 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 414 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 40 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 609 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | double-click-mail | double-clicks mail's title bar: macOS zooms the window | mail ×1 (6, 390 ms), w67 ×1 (6, 390 ms) | quiet 970 ms | ✔ | ~ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | double-click-mail-again | double-clicks it again: macOS takes the window back | mail ×1 (9, 383 ms), w67 ×1 (9, 383 ms) | quiet 791 ms | ✔ | ~ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 412 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | quit-safari | presses ⌘Q in safari |  | quiet 1119 ms; blind for 235 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 45 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 360 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 46 | reopen-safari | opens safari's document again |  | quiet 1003 ms; blind for 1275 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 47 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 414 ms; blind for 100 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | hide-terminal | presses ⌘H |  | quiet 790 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 49 | quit-safari | presses ⌘Q in safari |  | quiet 950 ms; blind for 230 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 50 | click-mail | clicks mail's title bar |  | quiet 401 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | unhide-terminal | clicks its icon in the Dock |  | quiet 532 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | reopen-safari | opens safari's document again |  | quiet 392 ms; blind for 1018 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 53 | leave-alone | does nothing for half a minute |  | quiet 366 ms; blind for 103 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 54 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 495 ms; blind for 150 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | double-click-calendar | double-clicks calendar's title bar: macOS zooms the window | calendar ×1 (12, 417 ms) | quiet 835 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 56 | double-click-calendar-again | double-clicks it again: macOS takes the window back | calendar ×1 (10, 324 ms) | quiet 782 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 404 ms; blind for 107 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 58 | quit-textedit | presses ⌘Q in textedit |  | quiet 897 ms; blind for 122 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 59 | reopen-textedit | opens textedit's document again |  | quiet 1016 ms; blind for 539 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 60 | drag-textedit-by | drags textedit, which floats, by its title bar -93 across and 125 down, and clicks there 0.3 s after letting go | preview ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 992 ms | ✔ | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 437 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 62 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 393 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 63 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 351 ms; blind for 100 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 64 | click-preview | clicks preview's title bar |  | quiet 579 ms; blind for 228 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 65 | double-click-terminal | double-clicks terminal's title bar: macOS zooms the window | terminal ×1 (11, 340 ms) | quiet 764 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 66 | double-click-terminal-again | double-clicks it again: macOS takes the window back | terminal ×1 (12, 337 ms) | quiet 691 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 67 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 393 ms; blind for 174 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 68 | drag-mail-by | drags mail, which floats, by its title bar -106 across and 8 down, and clicks there 0.3 s after letting go |  | quiet 1063 ms |  |  |  |  |  |  |  | ~ |
| 69 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 432 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 70 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 489 ms; blind for 114 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 71 | drag-finder-by | drags finder, which floats, by its title bar 203 across and -36 down | finder ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 1441 ms | ✔ | ✘ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 72 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 523 ms; blind for 137 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 73 | window-menu-textedit | chooses textedit's first window in the Window menu |  | quiet 1311 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 74 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 465 ms; blind for 112 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 75 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 390 ms; blind for 109 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 76 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 412 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 77 | click-preview | clicks preview's title bar |  | quiet 365 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 78 | minimize-preview | presses ⌘M | preview ×1 (22, 440 ms), textedit ×1 (1, 0 ms) | quiet 1524 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 79 | restore-preview | clicks its miniature in the Dock | preview ×1 (17, 496 ms), textedit ×1 (1, 0 ms) | quiet 1043 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 80 | drag-preview-to-right-edge | drags preview by its title bar against the right edge of the screen and lets go | preview ×2 (2, 683 ms), textedit ×1 (1, 0 ms) | quiet 392 ms | ✘ | ✔ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 81 | drag-textedit-to-top-edge | drags textedit by its title bar against the top edge of the screen and lets go | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), mail ×1 (1, 0 ms), w67 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 396 ms; blind for 140 ms | ✔ | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 82 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 402 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 83 | drag-preview-to-right-edge | drags preview by its title bar against the right edge of the screen and lets go | preview ×1 (9, 276 ms) | quiet 396 ms | ✘ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 84 | click-textedit | clicks textedit's title bar |  | quiet 434 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 85 | minimize-textedit | presses ⌘M | safari ×1 (1, 0 ms), textedit ×1 (12, 280 ms) | quiet 1436 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 86 | restore-textedit | clicks its miniature in the Dock | textedit ×1 (8, 280 ms) | quiet 954 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 87 | drag-textedit-by | drags textedit, which floats, by its title bar -138 across and 121 down | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1180 ms | ✔ | ✘ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 88 | drag-safari-to-top-edge | drags safari by its title bar against the top edge of the screen and lets go | safari ×1 (6, 279 ms) | quiet 369 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 89 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 376 ms; blind for 108 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 90 | quit-textedit | presses ⌘Q in textedit | finder ×1 (1, 0 ms) | quiet 1046 ms; blind for 131 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 91 | reopen-textedit | opens textedit's document again |  | quiet 1513 ms; blind for 608 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 92 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 352 ms; blind for 128 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 93 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (2, 15 ms), terminal ×1 (1, 0 ms), notes ×1 (2, 7 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w67 ×1 (1, 0 ms) | quiet 644 ms |  |  | ✔ |  | ✘ |  | ✔ | ✘ |
| 94 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 404 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 95 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 377 ms; blind for 129 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 96 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 379 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 97 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 392 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 98 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 408 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 99 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 382 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 100 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 402 ms; blind for 102 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 101 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 384 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 102 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 363 ms; blind for 148 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 103 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 392 ms; blind for 114 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
