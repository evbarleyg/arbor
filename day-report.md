114 steps in 551 s, 96 of them judged, 5 with a rule broken. The sampler: samples 17878 seconds 483.3 hz 37.0 cost-ms 2.57 late 60 longest-gap-ms 2275 whole-samples 20450 whole-seconds 552.8 whole-late 101.
Input: 504 presses, releases, keys and scrolls reached the apps, half of them within 561 µs, 99 in 100 within 41490 µs, the latest after 132222 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 67, 646, 5008; dragged 330, 538, 8532; forward 7, 31906, 65433; key 26, 429, 10399; up 74, 533, 132222. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 65946; up 8, 4489.
The round of input `started` (events, half within µs): forward 8, 35626; up 8, 712.
The round of input `last` (events, half within µs): forward 1, 71064; up 1, 519.
The round of input `after` (events, half within µs): .
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 20 | 0 |  |
| 2 | nothing moves that the person did not move | 95 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 101 | 1 | 20 drag-mail-to-top-edge |
| 4 | the window you switch to comes to the front and into view | 82 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 1 | 1 | 104 quit |
| 6 | what a person presses reaches the apps, at once | 69 | 2 | 16 dock-icon-safari, 53 dock-icon-mail |
| L | no window is lost or stuck | 101 | 0 |  |
| - | what the script itself checked | 101 | 2 | 98 leave-alone, 104 quit |

## Findings

### Rule 2: nothing moves that the person did not move

- ~ **20 drag-mail-to-top-edge** (drags mail by its title bar against the top edge of the screen and lets go): w73 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +834 ms 566,176 470×416 · +893 ms 567,173 470×416 · +947 ms 569,170 470×416 · +1043 ms 570,167 470×416 · +1090 ms 572,165 470×416 · … 22 more … · +2713 ms 604,138 470×416 · +2817 ms 605,138 470×416 · +2881 ms 607,138 470×416 · +3178 ms 608,138 470×416 · +4666 ms 607,138 470×416
- ~ **67 double-click-mail** (double-clicks mail's title bar: macOS zooms the window): w73 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 607,138 470×416 · +967 ms 604,144 470×416 · +1034 ms 598,157 470×416 · +1084 ms 587,177 470×416 · +1134 ms 577,195 470×416 · +1196 ms 569,211 470×416 · +1258 ms 565,218 470×416
- ~ **68 double-click-mail-again** (double-clicks it again: macOS takes the window back): w73 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,218 470×416 · +933 ms 566,218 470×416 · +982 ms 570,209 470×416 · +1053 ms 583,185 470×416 · +1091 ms 593,165 470×416 · +1137 ms 600,152 470×416 · +1190 ms 606,140 470×416 · +1302 ms 607,138 470×416
- ~ **80 drag-mail-by** (drags mail, which floats, by its title bar 158 across and 64 down, and clicks there 0.3 s after letting go): w73 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 607,138 470×416 · +795 ms 612,138 470×416 · +884 ms 617,138 470×416 · +937 ms 622,138 470×416 · +1009 ms 628,138 470×416 · +1083 ms 633,138 470×416 · … 20 more … · +2408 ms 754,138 470×416 · +2469 ms 759,138 470×416 · +2505 ms 765,138 470×416 · +2739 ms 766,138 470×416 · +2858 ms 765,138 470×416

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **20 drag-mail-to-top-edge** (drags mail by its title bar against the top edge of the screen and lets go): w73 of Mail moved 3 times [jolt]
  - +0 ms 565,179 470×416 · +834 ms 566,176 470×416 · +893 ms 567,173 470×416 · +947 ms 569,170 470×416 · +1043 ms 570,167 470×416 · +1090 ms 572,165 470×416 · … 22 more … · +2713 ms 604,138 470×416 · +2817 ms 605,138 470×416 · +2881 ms 607,138 470×416 · +3178 ms 608,138 470×416 · +4666 ms 607,138 470×416
- ~ **54 drag-settings-by** (drags settings, which floats, by its title bar 114 across and 98 down, and clicks there 0.3 s after letting go): settings (w63) changed its size while it was being dragged [jolt]
  - +0 ms 2,35 723×791 · +56 ms 6,38 723×791 · +65 ms 5,38 723×788 · +84 ms 5,38 723×767 · +133 ms 9,41 723×690 · +226 ms 13,44 723×642 · … 25 more … · +1823 ms 100,119 723×626 · +1883 ms 104,123 723×626 · +1924 ms 108,126 723×626 · +2126 ms 109,126 723×626 · +2259 ms 108,126 723×626
- ~ **85 drag-preview-to-top-edge** (drags preview by its title bar against the top edge of the screen and lets go): preview (w164) changed its size while it was being dragged [jolt]
  - +0 ms 789,31 800×791 · +34 ms 770,31 800×791 · +74 ms 783,31 790×748 · +130 ms 798,31 747×577 · +166 ms 796,31 723×481 · +214 ms 799,31 715×452 · … 26 more … · +1690 ms 565,31 709×425 · +1742 ms 555,31 709×425 · +1787 ms 545,31 709×425 · +2071 ms 546,31 709×425 · +2176 ms 545,31 709×425

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **104 quit** (chooses Quit Arbor in Arbor's menu): w73 of Mail has its size back but not its place: 765,138 470×416, it was at 565,179 470×416 [size-lost]

### Rule 6: what a person presses reaches the apps, at once

- ✘ **16 dock-icon-safari** (clicks safari's icon in the Dock): the button came up, and the apps heard of it 132 ms later [input-held]
- ✘ **53 dock-icon-mail** (clicks mail's icon in the Dock): the button came up, and the apps heard of it 124 ms later [input-held]

### Rule -: what the script itself checked

- ~ **35 drag-notes-by** (drags notes, which floats, by its title bar -155 across and 38 down): the act was not performed: drag_window could not be done [script]
- ✘ **98 leave-alone** (does nothing for half a minute): with nothing to do Arbor used 1.3 % of a core [busy]
- ✘ **104 quit** (chooses Quit Arbor in Arbor's menu): Arbor's process ended, and nobody asked it to [crash]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×2 (2, 260 ms) | quiet 1006 ms; blind for 259 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 372 ms; blind for 1425 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (4, 301 ms) | quiet 2106 ms; blind for 1113 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (5, 284 ms) | quiet 970 ms; blind for 289 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (4, 88 ms), w55 ×2 (16, 1260 ms), w57 ×1 (7, 235 ms) | quiet 396 ms; blind for 864 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×2 (4, 379 ms) | quiet 1246 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 393 ms; blind for 646 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview |  | quiet 418 ms; blind for 937 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w73 ×1 (4, 93 ms) | quiet 454 ms; blind for 1020 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (34, 4344 ms) | quiet 1384 ms; blind for 218 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (37, 2642 ms) | quiet 1061 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 415 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 699 ms; blind for 193 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | launch | starts Arbor |  | quiet 1033 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 15 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 607 ms; blind for 227 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 16 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 458 ms; blind for 254 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 17 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 377 ms; blind for 133 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 18 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 385 ms; blind for 127 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 19 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 424 ms; blind for 157 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | drag-mail-to-top-edge | drags mail by its title bar against the top edge of the screen and lets go | w73 ×3 (32, 3832 ms) | quiet 350 ms | ✔ | ~ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 369 ms; blind for 160 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 22 | quit-preview | presses ⌘Q in preview |  | quiet 763 ms; blind for 204 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 23 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 432 ms; blind for 129 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 374 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | new-window-textedit | presses ⌘N in textedit |  | quiet 1205 ms; blind for 152 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 26 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 406 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | drag-terminal-by | drags terminal, which floats, by its title bar -193 across and 50 down |  | quiet 1011 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | reopen-preview | opens preview's document again |  | quiet 749 ms; blind for 1102 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 29 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 384 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 369 ms; blind for 155 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 31 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 382 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 32 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 388 ms; blind for 139 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | window-menu-finder | chooses finder's first window in the Window menu |  | quiet 982 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 358 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | drag-notes-by | drags notes, which floats, by its title bar -155 across and 38 down |  | quiet 1033 ms |  |  |  |  |  |  |  | ~ |
| 36 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 380 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | window-menu-textedit | chooses textedit's first window in the Window menu |  | quiet 1280 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 424 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | hide-calendar | presses ⌘H |  | quiet 953 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 40 | unhide-calendar | clicks its icon in the Dock |  | quiet 394 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 380 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | quit-safari | presses ⌘Q in safari |  | quiet 880 ms; blind for 214 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 43 | reopen-safari | opens safari's document again |  | quiet 369 ms; blind for 2275 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 44 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 387 ms; blind for 121 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 45 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 433 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 46 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 401 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 374 ms; blind for 144 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 48 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 351 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 49 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 422 ms; blind for 111 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | drag-finder-by | drags finder, which floats, by its title bar 204 across and 90 down, and clicks there 0.3 s after letting go |  | quiet 964 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 558 ms; blind for 115 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | drag-settings-to-left-edge | drags settings by its title bar against the left edge of the screen and lets go | settings ×1 (7, 243 ms) | quiet 357 ms; blind for 152 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 53 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 411 ms; blind for 207 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 54 | drag-settings-by | drags settings, which floats, by its title bar 114 across and 98 down, and clicks there 0.3 s after letting go |  | quiet 932 ms; blind for 486 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | drag-settings-by | drags settings, which floats, by its title bar -291 across and 5 down, and clicks there 0.3 s after letting go |  | quiet 882 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 56 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 384 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 522 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 58 | quit-textedit | presses ⌘Q in textedit |  | quiet 799 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 59 | drag-preview-to-right-edge | drags preview by its title bar against the right edge of the screen and lets go | preview ×1 (14, 348 ms) | quiet 380 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | reopen-textedit | opens textedit's document again |  | quiet 775 ms; blind for 211 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 61 | click-preview | clicks preview's title bar |  | quiet 563 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 62 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 485 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 63 | double-click-finder | double-clicks finder's title bar: macOS zooms the window | finder ×1 (1, 0 ms) | quiet 592 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 64 | double-click-finder-again | double-clicks it again: macOS takes the window back | finder ×1 (1, 0 ms) | quiet 376 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 65 | click-finder | clicks finder's title bar |  | quiet 401 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 66 | hide-finder | presses ⌘H |  | quiet 877 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 67 | double-click-mail | double-clicks mail's title bar: macOS zooms the window | mail ×1 (7, 354 ms), w73 ×1 (6, 291 ms) | quiet 814 ms; blind for 107 ms | ✔ | ~ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 68 | double-click-mail-again | double-clicks it again: macOS takes the window back | mail ×1 (7, 369 ms), w73 ×1 (7, 369 ms) | quiet 999 ms | ✔ | ~ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 69 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 460 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 70 | unhide-finder | clicks its icon in the Dock |  | quiet 377 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 71 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 357 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 72 | minimize-calendar | presses ⌘M | calendar ×1 (15, 413 ms) | quiet 1016 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 73 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 534 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 74 | drag-notes-by | drags notes, which floats, by its title bar -216 across and 144 down, and clicks there 0.3 s after letting go |  | quiet 1002 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 75 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 459 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 76 | restore-calendar | clicks its miniature in the Dock | calendar ×1 (24, 484 ms) | quiet 824 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 77 | double-click-textedit | double-clicks textedit's title bar: macOS zooms the window | textedit ×1 (7, 207 ms) | quiet 687 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 78 | double-click-textedit-again | double-clicks it again: macOS takes the window back | textedit ×1 (12, 346 ms) | quiet 724 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 79 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 496 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 80 | drag-mail-by | drags mail, which floats, by its title bar 158 across and 64 down, and clicks there 0.3 s after letting go | w73 ×1 (30, 2063 ms) | quiet 936 ms | ✔ | ~ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 81 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 413 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 82 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 401 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 83 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 389 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 84 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 470 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 85 | drag-preview-to-top-edge | drags preview by its title bar against the top edge of the screen and lets go | preview ×1 (9, 335 ms) | quiet 357 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 86 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 483 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 87 | double-click-textedit | double-clicks textedit's title bar: macOS zooms the window | textedit ×1 (10, 345 ms) | quiet 803 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 88 | double-click-textedit-again | double-clicks it again: macOS takes the window back | textedit ×1 (14, 351 ms) | quiet 755 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 89 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 373 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 90 | hide-finder | presses ⌘H |  | quiet 888 ms; blind for 124 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 91 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 371 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 92 | quit-safari | presses ⌘Q in safari |  | quiet 971 ms; blind for 224 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 93 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 445 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 94 | double-click-preview | double-clicks preview's title bar: macOS zooms the window | preview ×1 (13, 391 ms) | quiet 739 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 95 | double-click-preview-again | double-clicks it again: macOS takes the window back | preview ×1 (14, 356 ms) | quiet 908 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 96 | unhide-finder | clicks its icon in the Dock |  | quiet 552 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 97 | reopen-safari | opens safari's document again |  | quiet 389 ms; blind for 1415 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 98 | leave-alone | does nothing for half a minute |  | quiet 372 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 99 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 362 ms; blind for 172 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 100 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 386 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 101 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 366 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 102 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 408 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 103 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 411 ms; blind for 101 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 104 | quit | chooses Quit Arbor in Arbor's menu |  | quiet 887 ms |  |  | ✔ |  | ✘ |  | ✔ | ✘ |
| 105 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 381 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 106 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 384 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 107 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 438 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 108 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 397 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 109 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 415 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 110 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 526 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 111 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 396 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 112 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 586 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 113 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 467 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 114 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 359 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
