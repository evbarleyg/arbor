88 steps in 277 s, 75 of them judged, 10 with a rule broken. The sampler: samples 10976 seconds 277.7 hz 39.5 cost-ms 2.23 late 2592 longest-gap-ms 1215.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 59 | 3 | 18 float, 38 dock-right, 45 quit-preview |
| 3 | no jolts: a window moves once, to where it ends up | 76 | 1 | 80 resume |
| 4 | the window you switch to comes to the front and into view | 48 | 2 | 37 click-settings, 79 click-settings |
| 5 | quitting, Float All and pause give windows their own sizes back | 4 | 2 | 50 quit, 81 quit |
| L | no window is lost or stuck | 76 | 1 | 58 launch |
| - | what the script itself checked | 76 | 1 | 29 leave-alone |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **18 float** (presses ⌃⌥F): finder (w376) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,433 920×389 · +930 ms 340,120 920×436
- ✘ **18 float** (presses ⌃⌥F): safari (w379) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,433 1324×389 · +930 ms 138,31 1324×790
- ✘ **18 float** (presses ⌃⌥F): terminal (w393) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 97,433 877×379 · +930 ms 97,239 877×499
- ✘ **18 float** (presses ⌃⌥F): notes (w394) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,433 800×389 · +930 ms 0,31 800×790
- ✘ **18 float** (presses ⌃⌥F): calendar (w397) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 404,319 936×503 · +930 ms 404,115 936×599
- ✘ **18 float** (presses ⌃⌥F): settings (w398) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,352 723×470 · +930 ms 437,85 723×625
- ✘ **18 float** (presses ⌃⌥F): preview (w402) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,433 708×389 · +930 ms 4,35 708×424
- ✘ **38 dock-right** (presses ⌃⌥⌘ and the right arrow): notes (w394) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 800×790 · +1043 ms 0,31 794×790
- ✘ **45 quit-preview** (presses ⌘Q in preview): finder (w376) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,120 920×436 · +961 ms 1599,770 920×436
- ✘ **45 quit-preview** (presses ⌘Q in preview): terminal (w393) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 97,239 877×499 · +961 ms 1599,790 877×499
- ✘ **45 quit-preview** (presses ⌘Q in preview): notes (w394) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 800×791 · +961 ms 1599,770 800×791
- ✘ **45 quit-preview** (presses ⌘Q in preview): calendar (w397) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 404,115 936×599 · +961 ms 1599,770 936×599
- ✘ **45 quit-preview** (presses ⌘Q in preview): settings (w398) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +961 ms 1599,770 723×625

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **16 dock-up** (presses ⌃⌥⌘ and the up arrow): the last window came to rest 1158 ms after the key or the button [slow]
- ~ **18 float** (presses ⌃⌥F): the last window came to rest 724 ms after the key or the button [slow]
- ~ **39 dock-left** (presses ⌃⌥⌘ and the left arrow): the last window came to rest 732 ms after the key or the button [slow]
- ~ **63 view-out** (presses ⌃⌥↑): the last window came to rest 767 ms after the key or the button [slow]
- ✘ **80 resume** (presses ⌃⌥⎋): textedit (w390) moved 2 times [jolt]
  - +0 ms 464,31 673×439 · +255 ms 1599,790 673×439 · +962 ms 12,43 1576×767
- ~ **80 resume** (presses ⌃⌥⎋): the last window came to rest 743 ms after the key or the button [slow]

### Rule 4: the window you switch to comes to the front and into view

- ✘ **37 click-settings** (clicks settings's title bar): settings (w398) is not in front: textedit (w390), notes (w394), preview (w484) ahead of it, of which 3 cover part of it [behind]
- ✘ **37 click-settings** (clicks settings's title bar): settings (w398) its app is not the one in front (process 39090 is) [focus]
- ✘ **79 click-settings** (clicks settings's title bar): settings (w398) is not in front: textedit (w390), notes (w394), finder (w376), terminal-new-71 (w560) ahead of it, of which 7 cover part of it [behind]
- ✘ **79 click-settings** (clicks settings's title bar): settings (w398) its app is not the one in front (process 39090 is) [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **50 quit** (chooses Quit Arbor in Arbor's menu): textedit (w390) has its size back but not its place: 464,31 673×439, it was at 165,65 673×439 [size-lost]
- ✘ **81 quit** (chooses Quit Arbor in Arbor's menu): textedit (w390) has its size back but not its place: 464,31 673×439, it was at 165,65 673×439 [size-lost]

### Rule L: no window is lost or stuck

- ✘ **58 launch** (starts Arbor): textedit (w390) is out of view: 0% of it is on the display, at 1599,790 673×439 [lost]

### Rule -: what the script itself checked

- ✘ **29 leave-alone** (does nothing for half a minute): with nothing to do Arbor used 1.6 % of a core [busy]
- ~ **66 new-window-finder** (presses ⌘N in finder): floating w550 and docked w390 overlap by 780×436 [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder |  | quiet 836 ms; blind for 917 ms |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 380 ms; blind for 1215 ms |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×2 (4, 330 ms) | quiet 1278 ms; blind for 358 ms |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (6, 358 ms) | quiet 1265 ms; blind for 75 ms |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (8, 348 ms) | quiet 1231 ms; blind for 77 ms |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (6, 332 ms) | quiet 1246 ms; blind for 76 ms |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (2, 26 ms) | quiet 403 ms; blind for 527 ms |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (3, 97 ms) | quiet 986 ms; blind for 68 ms |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail |  | quiet 368 ms; blind for 790 ms |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go |  | quiet 1002 ms; blind for 82 ms |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down |  | quiet 1048 ms; blind for 78 ms |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 352 ms; blind for 76 ms |  |  |  |  |  |  |  |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 13 | launch | starts Arbor |  | quiet 1010 ms; blind for 73 ms |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 14 | view-back | presses ⌃⌥[ |  | quiet 755 ms; blind for 71 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 15 | click-textedit | clicks textedit's title bar |  | quiet 375 ms; blind for 98 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 16 | dock-up | presses ⌃⌥⌘ and the up arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 1419 ms; blind for 75 ms |  | ✔ | ~ | ✔ |  | ✔ | ✔ |
| 17 | click-textedit | clicks textedit's title bar |  | quiet 431 ms; blind for 73 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 18 | float | presses ⌃⌥F | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 914 ms; blind for 66 ms |  | ✘ | ~ | ✔ | ✔ | ✔ | ✔ |
| 19 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 359 ms; blind for 78 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 20 | hide-textedit | presses ⌘H |  | quiet 897 ms; blind for 80 ms |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 21 | unhide-textedit | clicks its icon in the Dock |  | quiet 419 ms; blind for 73 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 22 | click-textedit | clicks textedit's title bar |  | quiet 359 ms; blind for 66 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 23 | hide-textedit | presses ⌘H |  | quiet 926 ms; blind for 68 ms |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 24 | view-out | presses ⌃⌥↑ |  | quiet 637 ms; blind for 77 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 25 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 424 ms; blind for 87 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 26 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 356 ms; blind for 89 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 27 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 376 ms; blind for 101 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 28 | hide-safari | presses ⌘H |  | quiet 729 ms; blind for 134 ms |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 29 | leave-alone | does nothing for half a minute |  | quiet 376 ms; blind for 83 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✘ |
| 30 | unhide-textedit | clicks its icon in the Dock |  | quiet 605 ms; blind for 163 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 31 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 489 ms; blind for 107 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 32 | quit-preview | presses ⌘Q in preview |  | quiet 897 ms; blind for 118 ms |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 33 | view-left | presses ⌃⌥← |  | quiet 768 ms; blind for 75 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 34 | reopen-preview | opens preview's document again |  | quiet 942 ms; blind for 87 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 35 | view-back | presses ⌃⌥[ |  | quiet 439 ms; blind for 519 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 36 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 560 ms; blind for 70 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 37 | click-settings | clicks settings's title bar |  | quiet 351 ms; blind for 70 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ |
| 38 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 859 ms; blind for 81 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 39 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 788 ms; blind for 75 ms |  | ✔ | ~ | ✔ |  | ✔ | ✔ |
| 40 | view-forward | presses ⌃⌥] |  | quiet 615 ms; blind for 67 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 41 | view-out | presses ⌃⌥↑ |  | quiet 770 ms; blind for 68 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 42 | view-in | presses ⌃⌥↓ | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 832 ms; blind for 70 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 43 | dock-down | presses ⌃⌥⌘ and the down arrow |  | quiet 729 ms; blind for 77 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 44 | dock-icon-preview | clicks preview's icon in the Dock | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 684 ms; blind for 79 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 45 | quit-preview | presses ⌘Q in preview | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 901 ms; blind for 89 ms |  | ✘ | ✔ |  |  | ✔ | ✔ |
| 46 | dock-icon-finder | clicks finder's icon in the Dock | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 668 ms; blind for 78 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 47 | hide-finder | presses ⌘H |  | quiet 882 ms; blind for 68 ms |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 48 | reopen-preview | opens preview's document again |  | quiet 1023 ms; blind for 83 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 49 | unhide-finder | clicks its icon in the Dock |  | quiet 468 ms; blind for 139 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 50 | quit | chooses Quit Arbor in Arbor's menu | textedit ×1 (1, 0 ms) | quiet 922 ms; blind for 75 ms |  |  | ✔ |  | ✘ | ✔ | ✔ |
| 51 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 366 ms; blind for 75 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 52 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 456 ms; blind for 80 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 53 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 494 ms; blind for 77 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 54 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 396 ms; blind for 68 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 55 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 385 ms; blind for 66 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 56 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 545 ms; blind for 67 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 57 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 375 ms; blind for 77 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 58 | launch | starts Arbor | textedit ×1 (1, 0 ms) | quiet 944 ms; blind for 76 ms |  | ✔ | ✔ |  |  | ✘ | ✔ |
| 59 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 572 ms; blind for 70 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 60 | new-window-terminal | presses ⌘N in terminal |  | quiet 1192 ms; blind for 74 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 61 | click-wallpaper | clicks on the wallpaper |  | quiet 359 ms; blind for 72 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 62 | click-wallpaper-again | clicks on the wallpaper again |  | quiet 400 ms; blind for 77 ms |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 63 | view-out | presses ⌃⌥↑ | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), terminal-new-60 ×1 (1, 0 ms) | quiet 908 ms; blind for 70 ms |  |  | ~ |  |  | ✔ | ✔ |
| 64 | leave-alone | does nothing for half a minute |  | quiet 389 ms; blind for 84 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 65 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 522 ms; blind for 90 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 66 | new-window-finder | presses ⌘N in finder |  | quiet 1047 ms; blind for 111 ms |  | ✔ | ✔ | ✔ |  | ✔ | ~ |
| 67 | close-window | presses ⌘W | finder-new-66 ×1 (3, 117 ms) | quiet 1080 ms; blind for 71 ms |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 68 | cmd-tab-3 | holds ⌘ and presses Tab 3 time(s) |  | quiet 535 ms; blind for 74 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 69 | view-in | presses ⌃⌥↓ | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), terminal-new-60 ×1 (1, 0 ms) | quiet 918 ms; blind for 76 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 70 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 494 ms; blind for 76 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 71 | new-window-terminal | presses ⌘N in terminal |  | quiet 1181 ms; blind for 76 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 72 | cmd-tab-2 | holds ⌘ and presses Tab 2 time(s) |  | quiet 468 ms; blind for 78 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 73 | view-left | presses ⌃⌥← | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), terminal-new-60 ×1 (1, 0 ms), terminal-new-71 ×1 (1, 0 ms) | quiet 862 ms; blind for 75 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 74 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 507 ms; blind for 76 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 75 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), terminal-new-60 ×1 (1, 0 ms), terminal-new-71 ×1 (1, 0 ms) | quiet 445 ms; blind for 78 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 76 | click-wallpaper | clicks on the wallpaper |  | quiet 355 ms; blind for 79 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 77 | click-wallpaper-again | clicks on the wallpaper again |  | quiet 395 ms; blind for 71 ms |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 78 | pause | presses ⌃⌥⎋ | textedit ×1 (1, 0 ms) | quiet 740 ms; blind for 67 ms |  |  | ✔ |  | ✔ | ✔ | ✔ |
| 79 | click-settings | clicks settings's title bar |  | quiet 447 ms; blind for 79 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ |
| 80 | resume | presses ⌃⌥⎋ | finder ×1 (1, 0 ms), textedit ×2 (2, 707 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), terminal-new-60 ×1 (1, 0 ms), terminal-new-71 ×1 (1, 0 ms) | quiet 993 ms; blind for 75 ms |  |  | ✘ |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 81 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), terminal-new-60 ×1 (1, 0 ms), terminal-new-71 ×1 (1, 0 ms) | quiet 858 ms; blind for 74 ms |  |  | ✔ |  | ✘ | ✔ | ✔ |
| 82 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 411 ms; blind for 74 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 83 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 366 ms; blind for 68 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 84 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 484 ms; blind for 76 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 85 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 490 ms; blind for 73 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 86 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 436 ms; blind for 70 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 87 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 540 ms; blind for 65 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 88 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 427 ms; blind for 69 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
