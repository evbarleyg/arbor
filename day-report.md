101 steps in 363 s, 84 of them judged, 2 with a rule broken. The sampler: samples 10830 seconds 300.5 hz 36.0 cost-ms 2.77 late 46 longest-gap-ms 1472 whole-samples 13132 whole-seconds 364.3 whole-late 82.
Input: 502 presses, releases, keys and scrolls reached the apps, half of them within 596 µs, 99 in 100 within 50136 µs, the latest after 109782 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 65, 578, 7981; dragged 330, 616, 5597; forward 9, 43397, 109782; key 24, 474, 4230; up 74, 437, 81405. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 36176; up 8, 686.
The round of input `after` (events, half within µs): forward 1, 129972; up 1, 6569.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 20 | 0 |  |
| 2 | nothing moves that the person did not move | 83 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 88 | 2 | 18 drag-mail-to-top-edge, 78 drag-mail-by |
| 4 | the window you switch to comes to the front and into view | 73 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 59 | 0 |  |
| L | no window is lost or stuck | 88 | 0 |  |
| - | what the script itself checked | 88 | 0 |  |

## Findings

### Rule 2: nothing moves that the person did not move

- ~ **18 drag-mail-to-top-edge** (drags mail by its title bar against the top edge of the screen and lets go): w72 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +889 ms 566,176 470×416 · +953 ms 567,173 470×416 · +998 ms 569,170 470×416 · +1011 ms 570,167 470×416 · +1137 ms 572,165 470×416 · … 20 more … · +2924 ms 604,138 470×416 · +2990 ms 605,138 470×416 · +3070 ms 607,138 470×416 · +3312 ms 608,138 470×416 · +4775 ms 607,138 470×416
- ~ **65 double-click-mail** (double-clicks mail's title bar: macOS zooms the window): w72 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 607,138 470×416 · +1027 ms 607,139 470×416 · +1035 ms 603,146 470×416 · +1149 ms 595,162 470×416 · +1211 ms 572,205 470×416 · +1294 ms 568,214 470×416 · +1301 ms 565,218 470×416
- ~ **66 double-click-mail-again** (double-clicks it again: macOS takes the window back): w72 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,218 470×416 · +991 ms 566,217 470×416 · +1040 ms 570,209 470×416 · +1116 ms 577,197 470×416 · +1161 ms 589,174 470×416 · +1228 ms 598,155 470×416 · +1280 ms 604,144 470×416 · +1344 ms 607,138 470×416
- ~ **78 drag-mail-by** (drags mail, which floats, by its title bar 158 across and 64 down, and clicks there 0.3 s after letting go): w72 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 607,138 470×416 · +896 ms 612,138 470×416 · +923 ms 617,138 470×416 · +998 ms 622,138 470×416 · +1023 ms 628,138 470×416 · +1076 ms 633,138 470×416 · … 21 more … · +2683 ms 754,138 470×416 · +2689 ms 759,138 470×416 · +2782 ms 765,138 470×416 · +2999 ms 766,138 470×416 · +3716 ms 765,138 470×416

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **18 drag-mail-to-top-edge** (drags mail by its title bar against the top edge of the screen and lets go): w72 of Mail moved 2 times [jolt]
  - +0 ms 565,179 470×416 · +889 ms 566,176 470×416 · +953 ms 567,173 470×416 · +998 ms 569,170 470×416 · +1011 ms 570,167 470×416 · +1137 ms 572,165 470×416 · … 20 more … · +2924 ms 604,138 470×416 · +2990 ms 605,138 470×416 · +3070 ms 607,138 470×416 · +3312 ms 608,138 470×416 · +4775 ms 607,138 470×416
- ~ **52 drag-settings-by** (drags settings, which floats, by its title bar 114 across and 98 down, and clicks there 0.3 s after letting go): settings (w62) changed its size while it was being dragged [jolt]
  - +0 ms 2,35 723×791 · +46 ms 6,38 723×791 · +78 ms 5,38 723×785 · +141 ms 9,41 723×686 · +185 ms 13,44 723×657 · +247 ms 13,44 723×641 · … 24 more … · +1926 ms 100,119 723×626 · +2036 ms 104,123 723×626 · +2101 ms 108,126 723×626 · +2342 ms 109,126 723×626 · +2418 ms 108,126 723×626
- ✘ **78 drag-mail-by** (drags mail, which floats, by its title bar 158 across and 64 down, and clicks there 0.3 s after letting go): w72 of Mail moved 2 times [jolt]
  - +0 ms 607,138 470×416 · +896 ms 612,138 470×416 · +923 ms 617,138 470×416 · +998 ms 622,138 470×416 · +1023 ms 628,138 470×416 · +1076 ms 633,138 470×416 · … 21 more … · +2683 ms 754,138 470×416 · +2689 ms 759,138 470×416 · +2782 ms 765,138 470×416 · +2999 ms 766,138 470×416 · +3716 ms 765,138 470×416
- ~ **83 drag-preview-to-top-edge** (drags preview by its title bar against the top edge of the screen and lets go): preview (w154) changed its size while it was being dragged [jolt]
  - +0 ms 800,31 800×791 · +68 ms 789,31 800×791 · +159 ms 770,31 800×791 · +209 ms 788,31 775×691 · +252 ms 798,31 747×579 · +256 ms 788,31 747×579 · … 23 more … · +1435 ms 565,31 709×425 · +1498 ms 555,31 709×425 · +1534 ms 545,31 709×425 · +1728 ms 546,31 709×425 · +1864 ms 545,31 709×425

### Rule -: what the script itself checked

- ~ **33 drag-notes-by** (drags notes, which floats, by its title bar -155 across and 38 down): the act was not performed: drag_window could not be done [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder |  | quiet 692 ms; blind for 316 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 761 ms; blind for 1428 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (3, 253 ms) | quiet 1366 ms; blind for 485 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (3, 271 ms) | quiet 1015 ms; blind for 105 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (5, 109 ms), w54 ×2 (14, 1110 ms), w56 ×1 (9, 235 ms) | quiet 360 ms; blind for 166 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (6, 354 ms) | quiet 1261 ms; blind for 407 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 392 ms; blind for 422 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview |  | quiet 561 ms; blind for 122 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | mail ×1 (2, 80 ms), w72 ×1 (3, 129 ms) | quiet 699 ms; blind for 1728 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (40, 4242 ms) | quiet 1433 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (37, 2348 ms) | quiet 1085 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 350 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 531 ms; blind for 165 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 373 ms; blind for 104 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 15 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 439 ms; blind for 135 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 16 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 419 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 17 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 392 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 18 | drag-mail-to-top-edge | drags mail by its title bar against the top edge of the screen and lets go | w72 ×2 (30, 3886 ms) | quiet 1059 ms | ✔ | ~ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 378 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | quit-preview | presses ⌘Q in preview |  | quiet 763 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 21 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 466 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 22 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 417 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | new-window-textedit | presses ⌘N in textedit |  | quiet 1214 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 24 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 399 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | drag-terminal-by | drags terminal, which floats, by its title bar -193 across and 50 down |  | quiet 1062 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | reopen-preview | opens preview's document again |  | quiet 607 ms; blind for 967 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 27 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 452 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 380 ms; blind for 145 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 29 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 419 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 30 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 440 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | window-menu-finder | chooses finder's first window in the Window menu |  | quiet 904 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 420 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | drag-notes-by | drags notes, which floats, by its title bar -155 across and 38 down |  | quiet 1018 ms |  |  |  |  |  |  |  | ~ |
| 34 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 390 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | window-menu-textedit | chooses textedit's first window in the Window menu |  | quiet 1298 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 36 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 388 ms; blind for 118 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | hide-calendar | presses ⌘H |  | quiet 832 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 38 | unhide-calendar | clicks its icon in the Dock |  | quiet 401 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 448 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | quit-safari | presses ⌘Q in safari |  | quiet 823 ms; blind for 179 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 41 | reopen-safari | opens safari's document again |  | quiet 361 ms; blind for 661 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 42 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 462 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 43 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 361 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 363 ms; blind for 102 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 384 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 46 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 366 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 47 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 478 ms; blind for 119 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | drag-finder-by | drags finder, which floats, by its title bar 204 across and 90 down, and clicks there 0.3 s after letting go |  | quiet 865 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 554 ms; blind for 101 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | drag-settings-to-left-edge | drags settings by its title bar against the left edge of the screen and lets go | settings ×1 (8, 325 ms) | quiet 1411 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 389 ms; blind for 168 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | drag-settings-by | drags settings, which floats, by its title bar 114 across and 98 down, and clicks there 0.3 s after letting go |  | quiet 907 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 53 | drag-settings-by | drags settings, which floats, by its title bar -291 across and 5 down, and clicks there 0.3 s after letting go |  | quiet 916 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 54 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 399 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 424 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 56 | quit-textedit | presses ⌘Q in textedit |  | quiet 642 ms; blind for 128 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 57 | drag-preview-to-right-edge | drags preview by its title bar against the right edge of the screen and lets go | preview ×1 (14, 334 ms) | quiet 1385 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 58 | reopen-textedit | opens textedit's document again |  | quiet 715 ms; blind for 131 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 59 | click-preview | clicks preview's title bar |  | quiet 379 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 385 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | double-click-finder | double-clicks finder's title bar: macOS zooms the window | finder ×1 (1, 0 ms) | quiet 502 ms; blind for 113 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 62 | double-click-finder-again | double-clicks it again: macOS takes the window back | finder ×1 (1, 0 ms) | quiet 495 ms; blind for 148 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 63 | click-finder | clicks finder's title bar |  | quiet 362 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 64 | hide-finder | presses ⌘H |  | quiet 767 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 65 | double-click-mail | double-clicks mail's title bar: macOS zooms the window | mail ×1 (6, 274 ms), w72 ×1 (6, 274 ms) | quiet 700 ms | ✔ | ~ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 66 | double-click-mail-again | double-clicks it again: macOS takes the window back | mail ×1 (8, 405 ms), w72 ×1 (7, 353 ms) | quiet 853 ms | ✔ | ~ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 67 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 513 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 68 | unhide-finder | clicks its icon in the Dock |  | quiet 701 ms; blind for 357 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 69 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 374 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 70 | minimize-calendar | presses ⌘M | calendar ×1 (17, 439 ms) | quiet 1029 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 71 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 372 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 72 | drag-notes-by | drags notes, which floats, by its title bar -216 across and 144 down, and clicks there 0.3 s after letting go |  | quiet 881 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 73 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 356 ms; blind for 104 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 74 | restore-calendar | clicks its miniature in the Dock | calendar ×1 (18, 580 ms) | quiet 1005 ms; blind for 110 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 75 | double-click-textedit | double-clicks textedit's title bar: macOS zooms the window | textedit ×1 (4, 115 ms) | quiet 749 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 76 | double-click-textedit-again | double-clicks it again: macOS takes the window back | textedit ×1 (11, 340 ms) | quiet 718 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 77 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 425 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 78 | drag-mail-by | drags mail, which floats, by its title bar 158 across and 64 down, and clicks there 0.3 s after letting go | w72 ×2 (31, 2820 ms) | quiet 946 ms; blind for 118 ms | ✔ | ~ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 79 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 396 ms; blind for 155 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 80 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 383 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 81 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 350 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 82 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 408 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 83 | drag-preview-to-top-edge | drags preview by its title bar against the top edge of the screen and lets go | preview ×1 (9, 322 ms) | quiet 1404 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 84 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 354 ms; blind for 108 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 85 | double-click-textedit | double-clicks textedit's title bar: macOS zooms the window | textedit ×1 (13, 368 ms) | quiet 778 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 86 | double-click-textedit-again | double-clicks it again: macOS takes the window back | textedit ×1 (15, 320 ms) | quiet 717 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 87 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 532 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 88 | hide-finder | presses ⌘H |  | quiet 838 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 89 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 425 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 90 | quit-safari | presses ⌘Q in safari |  | quiet 942 ms; blind for 125 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 91 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 427 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 92 | double-click-preview | double-clicks preview's title bar: macOS zooms the window | preview ×1 (9, 332 ms) | quiet 858 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 93 | double-click-preview-again | double-clicks it again: macOS takes the window back | preview ×1 (11, 325 ms) | quiet 671 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 94 | unhide-finder | clicks its icon in the Dock |  | quiet 392 ms; blind for 115 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 95 | reopen-safari | opens safari's document again |  | quiet 429 ms; blind for 1472 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 96 | leave-alone | does nothing for half a minute |  | quiet 393 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 97 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 375 ms; blind for 124 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 98 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 376 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 99 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 423 ms; blind for 146 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 100 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 427 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 101 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 360 ms; blind for 140 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
