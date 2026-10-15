111 steps in 483 s, 92 of them judged, 18 with a rule broken. The sampler: samples 16258 seconds 414.2 hz 39.3 cost-ms 3.57 late 46 longest-gap-ms 1734 whole-samples 19018 whole-seconds 484.5 whole-late 59.
Input: 340 presses, releases, keys and scrolls reached the apps, half of them within 748 µs, 99 in 100 within 37271 µs, the latest after 127423 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 23, 1219, 14314; dragged 230, 809, 8902; forward 7, 22623, 127423; key 50, 357, 1594; up 30, 753, 37282. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): down 13, 920; dragged 32, 526; forward 12, 25426; key 13, 293; scroll 28, 323; up 25, 557.
The round of input `started` (events, half within µs): down 13, 1514; dragged 32, 617; forward 13, 29831; key 13, 349; scroll 28, 351; up 26, 622.
The round of input `last` (events, half within µs): .
The round of input `after` (events, half within µs): forward 9, 30569; up 9, 430.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 6 | 0 |  |
| 2 | nothing moves that the person did not move | 75 | 5 | 20 dock-up, 31 dock-left, 37 dock-right, 39 dock-right, 47 drag-finder-to-top-edge |
| 3 | no jolts: a window moves once, to where it ends up | 97 | 6 | 41 drag-calendar-onto-notes-bottom, 44 drag-preview-onto-textedit-bottom, 47 drag-finder-to-top-edge, 71 launch, 81 drag-safari-to-left-edge, 83 drag-safari-to-right-edge |
| 4 | the window you switch to comes to the front and into view | 69 | 2 | 19 click-calendar, 92 drag-top-edge-of-preview |
| 5 | quitting, Float All and pause give windows their own sizes back | 4 | 3 | 49 float-all, 67 quit, 101 quit |
| 6 | what a person presses reaches the apps, at once | 45 | 0 |  |
| L | no window is lost or stuck | 97 | 4 | 49 float-all, 51 view-all, 55 view-all, 71 launch |
| - | what the script itself checked | 97 | 2 | 18 leave-alone, 44 drag-preview-onto-textedit-bottom |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **20 dock-up** (presses ⌃⌥⌘ and the up arrow): finder (w309) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,120 920×436 · +1549 ms 340,433 920×389
- ✘ **20 dock-up** (presses ⌃⌥⌘ and the up arrow): safari (w312) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,105 1306×316 · +1549 ms 138,433 1306×316
- ✘ **20 dock-up** (presses ⌃⌥⌘ and the up arrow): terminal (w326) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,51 877×499 · +1549 ms 40,433 877×379
- ✘ **20 dock-up** (presses ⌃⌥⌘ and the up arrow): notes (w329) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +1549 ms 300,433 1000×389
- ✘ **20 dock-up** (presses ⌃⌥⌘ and the up arrow): calendar (w330) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 464,118 936×599 · +1549 ms 464,319 936×503
- ✘ **20 dock-up** (presses ⌃⌥⌘ and the up arrow): settings (w333) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 877,140 723×629 · +1549 ms 877,352 723×470
- ✘ **20 dock-up** (presses ⌃⌥⌘ and the up arrow): preview (w335) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +1549 ms 4,433 708×389
- ✘ **20 dock-up** (presses ⌃⌥⌘ and the up arrow): mail (w338) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1549 ms 240,433 1120×389
- ~ **20 dock-up** (presses ⌃⌥⌘ and the up arrow): w341 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1549 ms 565,485 470×416
- ✘ **31 dock-left** (presses ⌃⌥⌘ and the left arrow): finder (w309) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,120 920×436 · +1308 ms 806,120 794×436
- ✘ **31 dock-left** (presses ⌃⌥⌘ and the left arrow): textedit (w323) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +1308 ms 806,65 673×439
- ✘ **31 dock-left** (presses ⌃⌥⌘ and the left arrow): terminal (w326) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,51 877×499 · +1308 ms 806,51 793×499
- ✘ **31 dock-left** (presses ⌃⌥⌘ and the left arrow): notes (w329) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +1308 ms 806,105 794×660
- ✘ **31 dock-left** (presses ⌃⌥⌘ and the left arrow): calendar (w330) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 464,118 936×599 · +1308 ms 806,118 794×599
- ✘ **31 dock-left** (presses ⌃⌥⌘ and the left arrow): mail (w338) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1308 ms 729,72 871×630
- ~ **31 dock-left** (presses ⌃⌥⌘ and the left arrow): w341 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1308 ms 930,179 470×416
- ✘ **37 dock-right** (presses ⌃⌥⌘ and the right arrow): finder (w309) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,120 920×436 · +929 ms 0,120 794×436
- ✘ **37 dock-right** (presses ⌃⌥⌘ and the right arrow): textedit (w323) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +929 ms 121,65 673×439
- ✘ **37 dock-right** (presses ⌃⌥⌘ and the right arrow): terminal (w326) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,51 877×499 · +929 ms 0,51 793×499
- ✘ **37 dock-right** (presses ⌃⌥⌘ and the right arrow): calendar (w330) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 464,118 936×599 · +929 ms 0,118 794×599
- ✘ **37 dock-right** (presses ⌃⌥⌘ and the right arrow): settings (w333) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 877,140 723×629 · +929 ms 71,140 723×629
- ✘ **37 dock-right** (presses ⌃⌥⌘ and the right arrow): mail (w338) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +929 ms 0,72 871×630
- ~ **37 dock-right** (presses ⌃⌥⌘ and the right arrow): w341 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +929 ms 201,179 470×416
- ✘ **39 dock-right** (presses ⌃⌥⌘ and the right arrow): finder (w309) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,120 794×436 · +1035 ms 0,120 501×436
- ✘ **39 dock-right** (presses ⌃⌥⌘ and the right arrow): terminal (w326) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,51 793×499 · +1035 ms 0,51 338×499
- ✘ **39 dock-right** (presses ⌃⌥⌘ and the right arrow): calendar (w330) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,118 794×599 · +1035 ms 0,118 680×599
- ✘ **39 dock-right** (presses ⌃⌥⌘ and the right arrow): settings (w333) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 71,140 723×629 · +1035 ms 0,140 723×629
- ✘ **39 dock-right** (presses ⌃⌥⌘ and the right arrow): preview (w402) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +1035 ms 0,35 708×424
- ✘ **47 drag-finder-to-top-edge** (drags finder by its title bar against the top edge of the screen and lets go): terminal (w326) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,51 338×499 · +5662 ms 0,318 338×499
- ✘ **47 drag-finder-to-top-edge** (drags finder by its title bar against the top edge of the screen and lets go): settings (w333) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,140 723×629 · +5662 ms 0,318 723×504
- ✘ **47 drag-finder-to-top-edge** (drags finder by its title bar against the top edge of the screen and lets go): mail (w338) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,72 871×630 · +5662 ms 0,318 871×504
- ~ **47 drag-finder-to-top-edge** (drags finder by its title bar against the top edge of the screen and lets go): w341 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 201,179 470×416 · +5662 ms 201,370 470×416
- ~ **71 launch** (starts Arbor): w341 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +838 ms 441,124 470×416 · +843 ms 213,614 470×416 · +1210 ms 1800,822 470×416
- ~ **75 quit-textedit** (presses ⌘Q in textedit): w341 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 1800,822 470×416 · +1224 ms 565,218 470×416

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **22 pause** (presses ⌃⌥⎋): w341 of Mail went 110 points out of its way before it ended up [jolt]
  - +0 ms 565,485 470×416 · +466 ms 565,124 470×416 · +547 ms 565,179 470×416
- ~ **23 resume** (presses ⌃⌥⎋): w341 of Mail went 110 points out of its way before it ended up [jolt]
  - +0 ms 565,179 470×416 · +376 ms 565,124 470×416 · +386 ms 565,485 470×416
- ~ **31 dock-left** (presses ⌃⌥⌘ and the left arrow): the last window came to rest 1157 ms after the key or the button [slow]
- ~ **34 view-out** (presses ⌃⌥↑): the last window came to rest 1247 ms after the key or the button [slow]
- ~ **39 dock-right** (presses ⌃⌥⌘ and the right arrow): the last window came to rest 881 ms after the key or the button [slow]
- ✘ **41 drag-calendar-onto-notes-bottom** (drags calendar by its title bar onto the bottom part of notes and lets go): calendar (w330) ended neither where it was let go nor where the preview was: let go at 86,669 680×599, the preview at 350,307 709×503, now at 1599,770 709×503 [stuck]
  - +0 ms 86,669 680×599 · +943 ms 1599,770 709×503
- ~ **41 drag-calendar-onto-notes-bottom** (drags calendar by its title bar onto the bottom part of notes and lets go): the last window came to rest 856 ms after the key or the button [slow]
- ✘ **44 drag-preview-onto-textedit-bottom** (drags preview by its title bar onto the bottom part of textedit and lets go): preview (w402) was 43 points ahead of the pointer's travel and 0 behind it at the most [pulled]
  - +0 ms 0,56 708×424 · +137 ms 34,77 708×424 · +205 ms 103,98 708×424 · +281 ms 137,119 708×424 · +362 ms 171,140 708×424 · +434 ms 205,162 708×424 · … 19 more … · +1787 ms 892,624 708×424 · +1815 ms 926,645 708×424 · +1910 ms 988,666 708×424 · +1978 ms 1023,688 708×424 · +2362 ms 1022,688 708×424
- ✘ **47 drag-finder-to-top-edge** (drags finder by its title bar against the top edge of the screen and lets go): finder (w309) ended neither where it was let go nor where the preview was: let go at 530,31 501×436, the preview at 12,43 1576×160, now at 12,43 1576×263 [stuck]
  - +0 ms 530,31 501×436 · +1212 ms 12,43 1576×263
- ~ **49 float-all** (presses ⌃⌥⇧F): the last window came to rest 996 ms after the key or the button [slow]
- ~ **63 arrange** (presses ⌃⌥A): the last window came to rest 1250 ms after the key or the button [slow]
- ✘ **71 launch** (starts Arbor): finder (w309) moved 2 times [jolt]
  - +0 ms 340,120 920×436 · +400 ms 275,294 501×252 · +1089 ms 274,294 501×252 · +1338 ms 274,294 709×252 · +1387 ms 400,375 709×252 · +1491 ms 1599,770 709×252
- ✘ **71 launch** (starts Arbor): textedit (w323) moved 2 times [jolt]
  - +0 ms 165,65 673×439 · +410 ms 165,65 251×247 · +477 ms 12,303 251×247 · +1338 ms 12,303 376×247
- ✘ **71 launch** (starts Arbor): terminal (w326) moved 2 times [jolt]
  - +0 ms 40,51 877×499 · +477 ms 14,45 247×244 · +1116 ms 12,43 247×244 · +1152 ms 13,45 247×244 · +1387 ms 13,45 373×244
- ✘ **71 launch** (starts Arbor): notes (w329) moved 2 times [jolt]
  - +0 ms 300,105 1000×660 · +498 ms 300,105 709×320 · +554 ms 275,43 709×320 · +1210 ms 1599,770 709×320 · +1387 ms 400,43 709×320
- ✘ **71 launch** (starts Arbor): calendar (w330) moved 2 times [jolt]
  - +0 ms 464,118 936×599 · +599 ms 464,118 708×503 · +653 ms 788,43 708×503 · +1210 ms 1599,770 708×503
- ✘ **71 launch** (starts Arbor): settings (w333) moved 3 times [jolt]
  - +0 ms 877,140 723×629 · +704 ms 788,303 723×470 · +1116 ms 773,157 723×470 · +1491 ms 1599,770 723×470
- ✘ **71 launch** (starts Arbor): mail (w338) moved 2 times [jolt]
  - +0 ms 240,72 1120×630 · +838 ms 240,72 871×248 · +843 ms 12,562 871×248 · +1210 ms 1599,770 871×248
- ✘ **71 launch** (starts Arbor): w341 of Mail moved 2 times [jolt]
  - +0 ms 565,179 470×416 · +838 ms 441,124 470×416 · +843 ms 213,614 470×416 · +1210 ms 1800,822 470×416
- ✘ **71 launch** (starts Arbor): preview (w402) moved 2 times [jolt]
  - +0 ms 892,398 708×424 · +888 ms 788,562 708×248 · +1152 ms 788,562 723×224 · +1165 ms 773,639 723×224 · +1387 ms 1121,562 708×248 · +1495 ms 1599,770 708×248
- ✘ **71 launch** (starts Arbor): finder-new-60 (w462) moved 2 times [jolt]
  - +0 ms 369,149 920×436 · +1040 ms 275,558 501×252 · +1210 ms 274,558 501×252 · +1491 ms 400,598 709×252 · +1495 ms 1599,770 709×252
- ~ **80 dock-down** (presses ⌃⌥⌘ and the down arrow): the last window came to rest 1230 ms after the key or the button [slow]
- ✘ **81 drag-safari-to-left-edge** (drags safari by its title bar against the left edge of the screen and lets go): safari (w527) ended neither where it was let go nor where the preview was: let go at -924,313 1306×316, the preview at 12,43 474×767, now at 12,43 681×767 [stuck]
  - +0 ms -924,313 1306×316 · +1545 ms 12,43 681×767
- ✘ **83 drag-safari-to-right-edge** (drags safari by its title bar against the right edge of the screen and lets go): safari (w527) was 45 points ahead of the pointer's travel and 0 behind it at the most [pulled]
  - +0 ms 67,67 681×767 · +74 ms 156,94 681×767 · +78 ms 201,107 681×767 · +125 ms 245,120 681×767 · +173 ms 290,133 681×767 · +236 ms 334,146 681×767 · … 20 more … · +1865 ms 1269,436 681×767 · +1952 ms 1313,449 681×767 · +2024 ms 1358,463 681×767 · +2356 ms 1359,463 681×767 · +3918 ms 1358,463 681×767
- ~ **96 balance** (presses ⌃⌥⌘0): the last window came to rest 818 ms after the key or the button [slow]

### Rule 4: the window you switch to comes to the front and into view

- ✘ **19 click-calendar** (clicks calendar's title bar): calendar (w330) is not in front: textedit (w323), preview (w335) ahead of it, of which 2 cover part of it [behind]
- ✘ **19 click-calendar** (clicks calendar's title bar): calendar (w330) its app is not the one in front (process 40167 is) [focus]
- ✘ **92 drag-top-edge-of-preview** (drags the top edge of preview's window by 30 points): the app in front changed (to process 51463), and nobody switched [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **49 float-all** (presses ⌃⌥⇧F): preview (w402) has its size back but not its place: 1022,688 708×424, it was at 4,35 708×424 [size-lost]
- ✘ **67 quit** (chooses Quit Arbor in Arbor's menu): preview (w402) has its size back but not its place: 892,398 708×424, it was at 4,35 708×424 [size-lost]
- ✘ **101 quit** (chooses Quit Arbor in Arbor's menu): preview (w402) has its size back but not its place: 892,398 708×424, it was at 4,35 708×424 [size-lost]
- ✘ **101 quit** (chooses Quit Arbor in Arbor's menu): safari (w559) has its size back but not its place: 919,55 681×767, it was at 1347,397 681×767 [size-lost]

### Rule L: no window is lost or stuck

- ✘ **49 float-all** (presses ⌃⌥⇧F): preview (w402) is out of view: 41% of it is on a display, at 1022,688 708×424 [lost]
- ✘ **51 view-all** (presses ⌃⌥Space): preview (w402) is out of view: 41% of it is on a display, at 1022,688 708×424 [lost]
- ✘ **55 view-all** (presses ⌃⌥Space): preview (w402) is out of view: 41% of it is on a display, at 1022,688 708×424 [lost]
- ✘ **71 launch** (starts Arbor): finder (w309) is out of view: 0% of it is on a display, at 1599,770 709×252 [lost]
- ✘ **71 launch** (starts Arbor): calendar (w330) is out of view: 0% of it is on a display, at 1599,770 708×503 [lost]
- ✘ **71 launch** (starts Arbor): settings (w333) is out of view: 0% of it is on a display, at 1599,770 723×470 [lost]
- ✘ **71 launch** (starts Arbor): mail (w338) is out of view: 0% of it is on a display, at 1599,770 871×248 [lost]
- ✘ **71 launch** (starts Arbor): preview (w402) is out of view: 0% of it is on a display, at 1599,770 708×248 [lost]
- ✘ **71 launch** (starts Arbor): finder-new-60 (w462) is out of view: 0% of it is on a display, at 1599,770 709×252 [lost]

### Rule -: what the script itself checked

- ✘ **18 leave-alone** (does nothing for half a minute): with nothing to do Arbor used 1.4 % of a core [busy]
- ✘ **44 drag-preview-onto-textedit-bottom** (drags preview by its title bar onto the bottom part of textedit and lets go): not so: it is docked [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (2, 47 ms) | quiet 939 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 410 ms; blind for 2037 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (4, 205 ms) | quiet 1097 ms; blind for 382 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (7, 342 ms) | quiet 1233 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (6, 140 ms) | quiet 1079 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (3, 266 ms) | quiet 1399 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 439 ms; blind for 471 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (6, 84 ms) | quiet 1006 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w341 ×1 (6, 100 ms) | quiet 687 ms; blind for 964 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (30, 3699 ms) | quiet 1081 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (28, 2795 ms) | quiet 1056 ms |  |  |  |  |  |  |  |  |
| 12 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (21, 3708 ms) | quiet 1054 ms |  |  |  |  |  |  |  |  |
| 13 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (32, 2944 ms) | quiet 1021 ms |  |  |  |  |  |  |  |  |
| 14 | look-around | looks at the screen |  | quiet 373 ms |  |  |  |  |  |  |  |  |
| 15 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 818 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 16 | launch | starts Arbor |  | quiet 379 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 17 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 884 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 18 | leave-alone | does nothing for half a minute |  | quiet 379 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 19 | click-calendar | clicks calendar's title bar |  | quiet 451 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 20 | dock-up | presses ⌃⌥⌘ and the up arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w341 ×1 (1, 0 ms) | quiet 932 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 21 | view-back | presses ⌃⌥[ |  | quiet 638 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 22 | pause | presses ⌃⌥⎋ | finder ×1 (2, 26 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (2, 70 ms), settings ×1 (2, 29 ms), preview ×1 (1, 0 ms), mail ×1 (2, 81 ms), w341 ×1 (2, 81 ms) | quiet 1099 ms |  |  | ~ | ✔ | ✔ |  | ✔ | ✔ |
| 23 | resume | presses ⌃⌥⎋ | finder ×1 (2, 86 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (2, 37 ms), settings ×1 (1, 0 ms), preview ×1 (2, 11 ms), mail ×1 (2, 10 ms), w341 ×1 (2, 10 ms) | quiet 1093 ms |  | ✔ | ~ |  |  |  | ✔ | ✔ |
| 24 | view-right | presses ⌃⌥→ |  | quiet 656 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 25 | click-textedit | clicks textedit's title bar |  | quiet 414 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | undo | presses ⌃⌥Z | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w341 ×1 (1, 0 ms) | quiet 1145 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 27 | cmd-tab-3 | holds ⌘ and presses Tab 3 time(s) |  | quiet 440 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 28 | cmd-tab-2 | holds ⌘ and presses Tab 2 time(s) |  | quiet 426 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 29 | quit-preview | presses ⌘Q in preview |  | quiet 994 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 30 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 409 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), mail ×1 (1, 0 ms), w341 ×1 (1, 0 ms) | quiet 1231 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 32 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w341 ×1 (1, 0 ms) | quiet 1185 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 33 | reopen-preview | opens preview's document again |  | quiet 992 ms; blind for 108 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 34 | view-out | presses ⌃⌥↑ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w341 ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 1211 ms; blind for 499 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 35 | view-back | presses ⌃⌥[ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w341 ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 851 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 36 | dock-icon-notes | clicks notes's icon in the Dock | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w341 ×1 (1, 0 ms) | quiet 703 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w341 ×1 (1, 0 ms) | quiet 1169 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 38 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 490 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 1131 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 40 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 492 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | drag-calendar-onto-notes-bottom | drags calendar by its title bar onto the bottom part of notes and lets go | notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 1035 ms | ✔ | ✔ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 556 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | minimize-settings | presses ⌘M | settings ×1 (24, 470 ms) | quiet 1448 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 44 | drag-preview-onto-textedit-bottom | drags preview by its title bar onto the bottom part of textedit and lets go |  | quiet 397 ms | ✔ | ✔ | ✘ | ✔ |  | ✔ | ✔ | ✘ |
| 45 | restore-settings | clicks settings's icon in the Dock, which brings its minimized window back | settings ×1 (17, 464 ms) | quiet 1107 ms; blind for 136 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 46 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 518 ms; blind for 104 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | drag-finder-to-top-edge | drags finder by its title bar against the top edge of the screen and lets go | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w341 ×1 (1, 0 ms) | quiet 969 ms | ✔ | ✘ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 889 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 49 | float-all | presses ⌃⌥⇧F | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w341 ×1 (1, 0 ms) | quiet 1631 ms |  |  | ~ |  | ✘ |  | ✘ | ✔ |
| 50 | view-frame | presses ⌃⌥↩ |  | quiet 607 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 51 | view-all | presses ⌃⌥Space |  | quiet 684 ms |  | ✔ | ✔ |  |  |  | ✘ | ✔ |
| 52 | cmd-tab-2 | holds ⌘ and presses Tab 2 time(s) |  | quiet 535 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 53 | cmd-tab-2 | holds ⌘ and presses Tab 2 time(s) |  | quiet 427 ms; blind for 109 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 54 | click-mail | clicks mail's title bar |  | quiet 393 ms; blind for 104 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | view-all | presses ⌃⌥Space |  | quiet 737 ms |  | ✔ | ✔ |  |  |  | ✘ | ✔ |
| 56 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 432 ms; blind for 110 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 504 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 58 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 413 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 59 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 420 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | new-window-finder | presses ⌘N in finder |  | quiet 1135 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 61 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 387 ms; blind for 125 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 62 | quit-safari | presses ⌘Q in safari |  | quiet 873 ms; blind for 212 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 63 | arrange | presses ⌃⌥A | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w341 ×1 (1, 0 ms), preview ×1 (1, 0 ms), finder-new-60 ×1 (1, 0 ms) | quiet 1839 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 64 | view-all | presses ⌃⌥Space |  | quiet 739 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 65 | click-tile | clicks the tile that stands in for a window | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), mail ×1 (1, 0 ms), w341 ×1 (1, 0 ms), preview ×1 (1, 0 ms), finder-new-60 ×1 (1, 0 ms) | quiet 1545 ms |  |  | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 66 | reopen-safari | opens safari's document again |  | quiet 883 ms; blind for 1136 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 67 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (2, 30 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w341 ×1 (1, 0 ms), preview ×1 (2, 50 ms), finder-new-60 ×1 (2, 24 ms) | quiet 798 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 68 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 350 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 69 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 435 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 70 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 559 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 71 | launch | starts Arbor | finder ×2 (5, 1091 ms), textedit ×2 (3, 928 ms), terminal ×2 (4, 910 ms), notes ×2 (4, 889 ms), calendar ×2 (3, 611 ms), settings ×3 (3, 787 ms), mail ×2 (3, 372 ms), w341 ×2 (3, 372 ms), preview ×2 (5, 607 ms), finder-new-60 ×2 (4, 455 ms) | quiet 857 ms |  | ~ | ✘ |  |  |  | ✘ | ✔ |
| 72 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 371 ms; blind for 110 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 73 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 358 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 74 | quit-safari | presses ⌘Q in safari | calendar ×1 (1, 0 ms), finder-new-60 ×1 (1, 0 ms) | quiet 1628 ms; blind for 152 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 75 | quit-textedit | presses ⌘Q in textedit | terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), mail ×1 (1, 0 ms), w341 ×1 (1, 0 ms), finder-new-60 ×1 (1, 0 ms) | quiet 1315 ms; blind for 173 ms |  | ~ | ✔ |  |  |  | ✔ | ✔ |
| 76 | reopen-safari | opens safari's document again |  | quiet 927 ms; blind for 1734 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 77 | reopen-textedit | opens textedit's document again |  | quiet 1144 ms; blind for 295 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 78 | dock-icon-finder | clicks finder's icon in the Dock | mail ×1 (1, 0 ms), w341 ×1 (1, 0 ms), finder-new-60 ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 612 ms; blind for 108 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 79 | view-home | presses ⌃⌥0 | terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), finder-new-60 ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 995 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 80 | dock-down | presses ⌃⌥⌘ and the down arrow | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), preview ×1 (1, 0 ms), finder-new-60 ×1 (1, 0 ms) | quiet 1203 ms |  | ✔ | ~ | ✔ |  |  | ✔ | ✔ |
| 81 | drag-safari-to-left-edge | drags safari by its title bar against the left edge of the screen and lets go | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), preview ×1 (1, 0 ms), finder-new-60 ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 1027 ms; blind for 161 ms | ✔ | ✔ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 82 | view-all | presses ⌃⌥Space |  | quiet 720 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 83 | drag-safari-to-right-edge | drags safari by its title bar against the right edge of the screen and lets go | safari ×1 (1, 0 ms) | quiet 1342 ms | ✔ | ✔ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 84 | view-all | presses ⌃⌥Space |  | quiet 732 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 85 | quit-safari | presses ⌘Q in safari | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), preview ×1 (1, 0 ms), finder-new-60 ×1 (1, 0 ms) | quiet 1175 ms; blind for 126 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 86 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 454 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 87 | view-left | presses ⌃⌥← |  | quiet 698 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 88 | view-all | presses ⌃⌥Space |  | quiet 721 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 89 | reopen-safari | opens safari's document again |  | quiet 515 ms; blind for 857 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 90 | drag-safari-to-right-edge | drags safari by its title bar against the right edge of the screen and lets go |  | quiet 436 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 91 | view-left | presses ⌃⌥← |  | quiet 710 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 92 | drag-top-edge-of-preview | drags the top edge of preview's window by 30 points | preview ×1 (6, 446 ms) | quiet 1063 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 93 | click-preview | clicks preview's title bar |  | quiet 442 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 94 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), preview ×1 (1, 0 ms), finder-new-60 ×1 (1, 0 ms), textedit ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 1283 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 95 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), preview ×1 (1, 0 ms), finder-new-60 ×1 (1, 0 ms), textedit ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 888 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 96 | balance | presses ⌃⌥⌘0 | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 744 ms |  | ✔ | ~ | ✔ |  |  | ✔ | ✔ |
| 97 | dock-icon-settings | clicks settings's icon in the Dock | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), finder-new-60 ×1 (1, 0 ms), textedit ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 868 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 98 | minimize-settings | presses ⌘M | calendar ×1 (1, 0 ms), settings ×1 (20, 432 ms), preview ×1 (1, 0 ms) | quiet 1502 ms; blind for 100 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 99 | restore-settings | clicks settings's icon in the Dock, which brings its minimized window back | calendar ×1 (1, 0 ms), settings ×1 (17, 539 ms), preview ×1 (1, 0 ms) | quiet 1194 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 100 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 401 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 101 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (2, 62 ms), terminal ×1 (2, 62 ms), notes ×1 (2, 8 ms), calendar ×1 (2, 89 ms), settings ×1 (1, 0 ms), mail ×1 (2, 51 ms), w341 ×1 (2, 51 ms), preview ×1 (1, 0 ms), finder-new-60 ×1 (1, 0 ms), textedit ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 808 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 102 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 428 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 103 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 384 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 104 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 395 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 105 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 400 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 106 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 534 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 107 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 425 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 108 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 493 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 109 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 501 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 110 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 414 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 111 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 414 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
