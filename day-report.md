101 steps in 372 s, 84 of them judged, 3 with a rule broken. The sampler: samples 10873 seconds 302.0 hz 36.0 cost-ms 2.95 late 41 longest-gap-ms 1388 whole-samples 13439 whole-seconds 373.3 whole-late 138.
Input: 502 presses, releases, keys and scrolls reached the apps, half of them within 639 µs, 99 in 100 within 35348 µs, the latest after 72796 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 66, 650, 4500; dragged 330, 706, 11097; forward 8, 35590, 72796; key 24, 433, 884; up 74, 533, 62120. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 43285; up 8, 1685.
The round of input `after` (events, half within µs): forward 1, 74440; up 1, 826.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 20 | 0 |  |
| 2 | nothing moves that the person did not move | 83 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 88 | 3 | 18 drag-mail-to-top-edge, 50 drag-settings-to-left-edge, 78 drag-mail-by |
| 4 | the window you switch to comes to the front and into view | 73 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 59 | 0 |  |
| L | no window is lost or stuck | 88 | 0 |  |
| - | what the script itself checked | 88 | 0 |  |

## Findings

### Rule 2: nothing moves that the person did not move

- ~ **18 drag-mail-to-top-edge** (drags mail by its title bar against the top edge of the screen and lets go): w73 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +856 ms 566,176 470×416 · +964 ms 567,173 470×416 · +1030 ms 569,170 470×416 · +1122 ms 570,167 470×416 · +1199 ms 572,165 470×416 · … 19 more … · +2456 ms 604,138 470×416 · +2519 ms 605,138 470×416 · +2579 ms 607,138 470×416 · +2810 ms 608,138 470×416 · +4187 ms 607,138 470×416
- ~ **65 double-click-mail** (double-clicks mail's title bar: macOS zooms the window): w73 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 607,138 470×416 · +1116 ms 600,151 470×416 · +1123 ms 589,172 470×416 · +1242 ms 577,195 470×416 · +1347 ms 566,218 470×416 · +1460 ms 565,218 470×416
- ~ **66 double-click-mail-again** (double-clicks it again: macOS takes the window back): w73 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,218 470×416 · +881 ms 566,217 470×416 · +943 ms 572,206 470×416 · +1050 ms 586,177 470×416 · +1116 ms 598,156 470×416 · +1175 ms 606,140 470×416 · +1282 ms 607,138 470×416
- ~ **78 drag-mail-by** (drags mail, which floats, by its title bar 158 across and 64 down, and clicks there 0.3 s after letting go): w73 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 607,138 470×416 · +837 ms 612,138 470×416 · +869 ms 617,138 470×416 · +993 ms 628,138 470×416 · +1037 ms 633,138 470×416 · +1079 ms 638,138 470×416 · … 20 more … · +2404 ms 754,138 470×416 · +2454 ms 759,138 470×416 · +2461 ms 765,138 470×416 · +2737 ms 766,138 470×416 · +3437 ms 765,138 470×416

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **18 drag-mail-to-top-edge** (drags mail by its title bar against the top edge of the screen and lets go): w73 of Mail moved 2 times [jolt]
  - +0 ms 565,179 470×416 · +856 ms 566,176 470×416 · +964 ms 567,173 470×416 · +1030 ms 569,170 470×416 · +1122 ms 570,167 470×416 · +1199 ms 572,165 470×416 · … 19 more … · +2456 ms 604,138 470×416 · +2519 ms 605,138 470×416 · +2579 ms 607,138 470×416 · +2810 ms 608,138 470×416 · +4187 ms 607,138 470×416
- ✘ **50 drag-settings-to-left-edge** (drags settings by its title bar against the left edge of the screen and lets go): settings (w63) was 53 points ahead of the pointer's travel and 0 behind it at the most [pulled]
  - +0 ms 410,96 723×625 · +119 ms 356,120 723×625 · +204 ms 303,143 723×625 · +248 ms 250,167 723×625 · +351 ms 223,179 723×625 · +440 ms 196,190 723×625 · … 15 more … · +1641 ms -294,357 723×625 · +1689 ms -321,369 723×625 · +1703 ms -347,381 723×625 · +1902 ms -346,381 723×625 · +3434 ms -347,381 723×625
- ~ **52 drag-settings-by** (drags settings, which floats, by its title bar 114 across and 98 down, and clicks there 0.3 s after letting go): settings (w63) changed its size while it was being dragged [jolt]
  - +0 ms 2,35 723×791 · +63 ms 6,38 723×791 · +106 ms 6,38 723×790 · +147 ms 5,38 723×773 · +215 ms 9,41 723×671 · +297 ms 13,44 723×638 · … 16 more … · +1761 ms 100,119 723×626 · +1851 ms 104,123 723×626 · +1926 ms 108,126 723×626 · +2209 ms 109,126 723×626 · +2317 ms 108,126 723×626
- ✘ **78 drag-mail-by** (drags mail, which floats, by its title bar 158 across and 64 down, and clicks there 0.3 s after letting go): w73 of Mail moved 3 times [jolt]
  - +0 ms 607,138 470×416 · +837 ms 612,138 470×416 · +869 ms 617,138 470×416 · +993 ms 628,138 470×416 · +1037 ms 633,138 470×416 · +1079 ms 638,138 470×416 · … 20 more … · +2404 ms 754,138 470×416 · +2454 ms 759,138 470×416 · +2461 ms 765,138 470×416 · +2737 ms 766,138 470×416 · +3437 ms 765,138 470×416
- ~ **83 drag-preview-to-top-edge** (drags preview by its title bar against the top edge of the screen and lets go): preview (w155) changed its size while it was being dragged [jolt]
  - +0 ms 789,31 800×791 · +23 ms 770,31 800×791 · +76 ms 786,31 780×708 · +89 ms 792,31 764×647 · +98 ms 782,31 764×647 · +123 ms 786,31 751×593 · … 24 more … · +1618 ms 565,31 709×425 · +1714 ms 555,31 709×425 · +1721 ms 545,31 709×425 · +1939 ms 546,31 709×425 · +2057 ms 545,31 709×425

### Rule -: what the script itself checked

- ~ **33 drag-notes-by** (drags notes, which floats, by its title bar -155 across and 38 down): the act was not performed: drag_window could not be done [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (2, 103 ms) | quiet 725 ms; blind for 225 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 455 ms; blind for 1616 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (1, 0 ms) | quiet 499 ms; blind for 313 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (3, 336 ms) | quiet 980 ms; blind for 592 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (4, 85 ms), w55 ×2 (9, 1510 ms), w57 ×1 (7, 225 ms) | quiet 366 ms; blind for 141 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (4, 343 ms) | quiet 1286 ms; blind for 123 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×2 (2, 425 ms) | quiet 1213 ms; blind for 425 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview |  | quiet 1665 ms; blind for 1372 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | mail ×1 (3, 65 ms), w73 ×1 (5, 207 ms) | quiet 630 ms; blind for 642 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (39, 3939 ms) | quiet 1406 ms; blind for 139 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (38, 2480 ms) | quiet 1075 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 352 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 544 ms; blind for 144 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 432 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 15 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 385 ms; blind for 117 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 16 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 428 ms; blind for 128 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 17 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 359 ms; blind for 135 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 18 | drag-mail-to-top-edge | drags mail by its title bar against the top edge of the screen and lets go | w73 ×2 (29, 3331 ms) | quiet 1032 ms | ✔ | ~ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 367 ms; blind for 128 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | quit-preview | presses ⌘Q in preview |  | quiet 791 ms; blind for 165 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 21 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 422 ms; blind for 100 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 22 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 634 ms; blind for 128 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | new-window-textedit | presses ⌘N in textedit |  | quiet 1053 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 24 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 394 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | drag-terminal-by | drags terminal, which floats, by its title bar -193 across and 50 down |  | quiet 1013 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | reopen-preview | opens preview's document again |  | quiet 926 ms; blind for 519 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 27 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 525 ms; blind for 120 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 436 ms; blind for 198 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 29 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 396 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 30 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 370 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | window-menu-finder | chooses finder's first window in the Window menu |  | quiet 957 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 414 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | drag-notes-by | drags notes, which floats, by its title bar -155 across and 38 down |  | quiet 1038 ms |  |  |  |  |  |  |  | ~ |
| 34 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 481 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | window-menu-textedit | chooses textedit's first window in the Window menu |  | quiet 1310 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 36 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 439 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | hide-calendar | presses ⌘H |  | quiet 879 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 38 | unhide-calendar | clicks its icon in the Dock |  | quiet 461 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 456 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | quit-safari | presses ⌘Q in safari |  | quiet 926 ms; blind for 190 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 41 | reopen-safari | opens safari's document again |  | quiet 408 ms; blind for 1388 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 42 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 413 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 43 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 380 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 376 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 357 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 46 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 358 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 47 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 354 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | drag-finder-by | drags finder, which floats, by its title bar 204 across and 90 down, and clicks there 0.3 s after letting go |  | quiet 893 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 447 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | drag-settings-to-left-edge | drags settings by its title bar against the left edge of the screen and lets go | settings ×1 (7, 269 ms) | quiet 1363 ms | ✔ | ✔ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 430 ms; blind for 152 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | drag-settings-by | drags settings, which floats, by its title bar 114 across and 98 down, and clicks there 0.3 s after letting go |  | quiet 997 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 53 | drag-settings-by | drags settings, which floats, by its title bar -291 across and 5 down, and clicks there 0.3 s after letting go |  | quiet 864 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 54 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 396 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 373 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 56 | quit-textedit | presses ⌘Q in textedit |  | quiet 740 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 57 | drag-preview-to-right-edge | drags preview by its title bar against the right edge of the screen and lets go | preview ×1 (9, 283 ms) | quiet 1387 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 58 | reopen-textedit | opens textedit's document again |  | quiet 812 ms; blind for 346 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 59 | click-preview | clicks preview's title bar |  | quiet 497 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 469 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | double-click-finder | double-clicks finder's title bar: macOS zooms the window | finder ×1 (1, 0 ms) | quiet 355 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 62 | double-click-finder-again | double-clicks it again: macOS takes the window back | finder ×1 (1, 0 ms) | quiet 472 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 63 | click-finder | clicks finder's title bar |  | quiet 385 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 64 | hide-finder | presses ⌘H |  | quiet 778 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 65 | double-click-mail | double-clicks mail's title bar: macOS zooms the window | mail ×1 (6, 472 ms), w73 ×1 (5, 344 ms) | quiet 931 ms | ✔ | ~ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 66 | double-click-mail-again | double-clicks it again: macOS takes the window back | mail ×1 (6, 401 ms), w73 ×1 (6, 401 ms) | quiet 903 ms | ✔ | ~ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 67 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 369 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 68 | unhide-finder | clicks its icon in the Dock |  | quiet 416 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 69 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 404 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 70 | minimize-calendar | presses ⌘M | calendar ×1 (19, 450 ms) | quiet 1057 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 71 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 429 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 72 | drag-notes-by | drags notes, which floats, by its title bar -216 across and 144 down, and clicks there 0.3 s after letting go |  | quiet 944 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 73 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 365 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 74 | restore-calendar | clicks its miniature in the Dock | calendar ×1 (17, 454 ms) | quiet 943 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 75 | double-click-textedit | double-clicks textedit's title bar: macOS zooms the window | textedit ×1 (14, 328 ms) | quiet 742 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 76 | double-click-textedit-again | double-clicks it again: macOS takes the window back | textedit ×1 (11, 348 ms) | quiet 729 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 77 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 360 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 78 | drag-mail-by | drags mail, which floats, by its title bar 158 across and 64 down, and clicks there 0.3 s after letting go | w73 ×3 (30, 2600 ms) | quiet 949 ms; blind for 100 ms | ✔ | ~ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 79 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 504 ms; blind for 138 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 80 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 389 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 81 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 423 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 82 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 456 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 83 | drag-preview-to-top-edge | drags preview by its title bar against the top edge of the screen and lets go | preview ×1 (8, 346 ms) | quiet 1439 ms; blind for 106 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 84 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 389 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 85 | double-click-textedit | double-clicks textedit's title bar: macOS zooms the window | textedit ×1 (12, 386 ms) | quiet 905 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 86 | double-click-textedit-again | double-clicks it again: macOS takes the window back | textedit ×1 (11, 341 ms) | quiet 753 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 87 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 470 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 88 | hide-finder | presses ⌘H |  | quiet 944 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 89 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 363 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 90 | quit-safari | presses ⌘Q in safari |  | quiet 865 ms; blind for 140 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 91 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 463 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 92 | double-click-preview | double-clicks preview's title bar: macOS zooms the window | preview ×1 (15, 341 ms) | quiet 793 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 93 | double-click-preview-again | double-clicks it again: macOS takes the window back | preview ×1 (12, 335 ms) | quiet 777 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 94 | unhide-finder | clicks its icon in the Dock |  | quiet 443 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 95 | reopen-safari | opens safari's document again |  | quiet 402 ms; blind for 1013 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 96 | leave-alone | does nothing for half a minute |  | quiet 383 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 97 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 420 ms; blind for 126 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 98 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 387 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 99 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 387 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 100 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 362 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 101 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 435 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
