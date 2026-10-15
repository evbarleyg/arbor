114 steps in 523 s, 96 of them judged, 4 with a rule broken. The sampler: samples 17667 seconds 464.8 hz 38.0 cost-ms 2.22 late 33 longest-gap-ms 1425 whole-samples 19930 whole-seconds 524.3 whole-late 74.
Input: 504 presses, releases, keys and scrolls reached the apps, half of them within 628 µs, 99 in 100 within 43916 µs, the latest after 138958 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 67, 701, 7932; dragged 330, 674, 6562; forward 7, 43916, 51683; key 26, 350, 799; up 74, 534, 138958. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 23998; up 8, 433.
The round of input `started` (events, half within µs): forward 8, 20139; up 8, 510.
The round of input `last` (events, half within µs): forward 1, 42243; up 1, 768.
The round of input `after` (events, half within µs): .
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 20 | 0 |  |
| 2 | nothing moves that the person did not move | 95 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 101 | 2 | 20 drag-mail-to-top-edge, 80 drag-mail-by |
| 4 | the window you switch to comes to the front and into view | 82 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 1 | 1 | 104 quit |
| 6 | what a person presses reaches the apps, at once | 69 | 1 | 21 dock-icon-preview |
| L | no window is lost or stuck | 101 | 0 |  |
| - | what the script itself checked | 101 | 1 | 104 quit |

## Findings

### Rule 2: nothing moves that the person did not move

- ~ **20 drag-mail-to-top-edge** (drags mail by its title bar against the top edge of the screen and lets go): w68 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +907 ms 566,176 470×416 · +972 ms 567,173 470×416 · +1045 ms 569,170 470×416 · +1087 ms 570,167 470×416 · +1127 ms 572,165 470×416 · … 21 more … · +2722 ms 604,138 470×416 · +2766 ms 605,138 470×416 · +2832 ms 607,138 470×416 · +3083 ms 608,138 470×416 · +4555 ms 607,138 470×416
- ~ **67 double-click-mail** (double-clicks mail's title bar: macOS zooms the window): w68 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 607,138 470×416 · +913 ms 607,139 470×416 · +976 ms 602,147 470×416 · +1016 ms 594,163 470×416 · +1111 ms 584,183 470×416 · +1169 ms 572,204 470×416 · +1202 ms 567,216 470×416 · +1261 ms 565,218 470×416
- ~ **68 double-click-mail-again** (double-clicks it again: macOS takes the window back): w68 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,218 470×416 · +812 ms 566,218 470×416 · +890 ms 568,213 470×416 · +958 ms 578,195 470×416 · +993 ms 587,176 470×416 · +1045 ms 596,160 470×416 · +1110 ms 605,143 470×416 · +1155 ms 607,138 470×416
- ~ **80 drag-mail-by** (drags mail, which floats, by its title bar 158 across and 64 down, and clicks there 0.3 s after letting go): w68 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 607,138 470×416 · +728 ms 612,138 470×416 · +829 ms 617,138 470×416 · +902 ms 622,138 470×416 · +1014 ms 628,138 470×416 · +1113 ms 638,138 470×416 · … 21 more … · +2485 ms 754,138 470×416 · +2597 ms 759,138 470×416 · +2656 ms 765,138 470×416 · +2841 ms 766,138 470×416 · +3548 ms 765,138 470×416

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **20 drag-mail-to-top-edge** (drags mail by its title bar against the top edge of the screen and lets go): w68 of Mail moved 3 times [jolt]
  - +0 ms 565,179 470×416 · +907 ms 566,176 470×416 · +972 ms 567,173 470×416 · +1045 ms 569,170 470×416 · +1087 ms 570,167 470×416 · +1127 ms 572,165 470×416 · … 21 more … · +2722 ms 604,138 470×416 · +2766 ms 605,138 470×416 · +2832 ms 607,138 470×416 · +3083 ms 608,138 470×416 · +4555 ms 607,138 470×416
- ~ **54 drag-settings-by** (drags settings, which floats, by its title bar 114 across and 98 down, and clicks there 0.3 s after letting go): settings (w60) changed its size while it was being dragged [jolt]
  - +0 ms 2,35 723×791 · +3 ms 6,38 723×791 · +57 ms 6,38 723×790 · +81 ms 5,38 723×744 · +166 ms 9,41 723×651 · +208 ms 9,41 723×638 · … 23 more … · +1651 ms 100,119 723×626 · +1736 ms 104,123 723×626 · +1834 ms 108,126 723×626 · +2072 ms 109,126 723×626 · +2163 ms 108,126 723×626
- ✘ **80 drag-mail-by** (drags mail, which floats, by its title bar 158 across and 64 down, and clicks there 0.3 s after letting go): w68 of Mail moved 2 times [jolt]
  - +0 ms 607,138 470×416 · +728 ms 612,138 470×416 · +829 ms 617,138 470×416 · +902 ms 622,138 470×416 · +1014 ms 628,138 470×416 · +1113 ms 638,138 470×416 · … 21 more … · +2485 ms 754,138 470×416 · +2597 ms 759,138 470×416 · +2656 ms 765,138 470×416 · +2841 ms 766,138 470×416 · +3548 ms 765,138 470×416
- ~ **85 drag-preview-to-top-edge** (drags preview by its title bar against the top edge of the screen and lets go): preview (w156) changed its size while it was being dragged [jolt]
  - +0 ms 789,31 800×791 · +56 ms 770,31 800×791 · +110 ms 770,31 774×686 · +118 ms 788,31 774×686 · +133 ms 794,31 759×627 · +166 ms 802,31 736×535 · … 24 more … · +1561 ms 555,31 709×425 · +1634 ms 545,31 709×425 · +1900 ms 546,31 709×425 · +1993 ms 545,31 709×425 · +3494 ms 538,31 719×430

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **104 quit** (chooses Quit Arbor in Arbor's menu): w68 of Mail has its size back but not its place: 765,138 470×416, it was at 565,179 470×416 [size-lost]

### Rule 6: what a person presses reaches the apps, at once

- ✘ **21 dock-icon-preview** (clicks preview's icon in the Dock): the button came up, and the apps heard of it 138 ms later [input-held]

### Rule -: what the script itself checked

- ~ **35 drag-notes-by** (drags notes, which floats, by its title bar -155 across and 38 down): the act was not performed: drag_window could not be done [script]
- ✘ **104 quit** (chooses Quit Arbor in Arbor's menu): Arbor's process ended, and nobody asked it to [crash]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder |  | quiet 675 ms; blind for 272 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 398 ms; blind for 1041 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (4, 276 ms) | quiet 1775 ms; blind for 824 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (2, 192 ms) | quiet 1088 ms; blind for 373 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (5, 99 ms), w54 ×2 (15, 1071 ms), w56 ×1 (8, 224 ms) | quiet 365 ms; blind for 125 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×2 (4, 344 ms) | quiet 1418 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 894 ms; blind for 482 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (4, 63 ms) | quiet 905 ms; blind for 663 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | mail ×1 (4, 68 ms), w68 ×1 (1, 0 ms) | quiet 737 ms; blind for 694 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (36, 4047 ms) | quiet 1464 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (35, 2402 ms) | quiet 1084 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 407 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 750 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | launch | starts Arbor |  | quiet 1033 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 15 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 640 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 16 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 360 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 351 ms; blind for 144 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 18 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 362 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 19 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 420 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | drag-mail-to-top-edge | drags mail by its title bar against the top edge of the screen and lets go | w68 ×3 (31, 3648 ms) | quiet 370 ms | ✔ | ~ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 394 ms; blind for 143 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 22 | quit-preview | presses ⌘Q in preview |  | quiet 586 ms; blind for 181 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 23 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 405 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 389 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | new-window-textedit | presses ⌘N in textedit |  | quiet 1107 ms; blind for 205 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 26 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 379 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | drag-terminal-by | drags terminal, which floats, by its title bar -193 across and 50 down |  | quiet 1070 ms; blind for 152 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | reopen-preview | opens preview's document again |  | quiet 980 ms; blind for 441 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 29 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 429 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 434 ms; blind for 138 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 31 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 375 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 32 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 445 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | window-menu-finder | chooses finder's first window in the Window menu |  | quiet 872 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 429 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | drag-notes-by | drags notes, which floats, by its title bar -155 across and 38 down |  | quiet 1015 ms |  |  |  |  |  |  |  | ~ |
| 36 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 369 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | window-menu-textedit | chooses textedit's first window in the Window menu |  | quiet 1281 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 495 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | hide-calendar | presses ⌘H |  | quiet 724 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 40 | unhide-calendar | clicks its icon in the Dock |  | quiet 483 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 419 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | quit-safari | presses ⌘Q in safari |  | quiet 872 ms; blind for 171 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 43 | reopen-safari | opens safari's document again |  | quiet 425 ms; blind for 845 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 44 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 404 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 45 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 395 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 46 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 382 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 354 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 48 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 391 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 49 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 364 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | drag-finder-by | drags finder, which floats, by its title bar 204 across and 90 down, and clicks there 0.3 s after letting go |  | quiet 906 ms; blind for 138 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 510 ms; blind for 454 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | drag-settings-to-left-edge | drags settings by its title bar against the left edge of the screen and lets go | settings ×1 (8, 285 ms) | quiet 376 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 53 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 399 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 54 | drag-settings-by | drags settings, which floats, by its title bar 114 across and 98 down, and clicks there 0.3 s after letting go |  | quiet 918 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | drag-settings-by | drags settings, which floats, by its title bar -291 across and 5 down, and clicks there 0.3 s after letting go |  | quiet 1006 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 56 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 409 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 479 ms; blind for 113 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 58 | quit-textedit | presses ⌘Q in textedit |  | quiet 861 ms; blind for 156 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 59 | drag-preview-to-right-edge | drags preview by its title bar against the right edge of the screen and lets go | preview ×1 (11, 319 ms) | quiet 381 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | reopen-textedit | opens textedit's document again |  | quiet 912 ms; blind for 416 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 61 | click-preview | clicks preview's title bar |  | quiet 417 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 62 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 554 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 63 | double-click-finder | double-clicks finder's title bar: macOS zooms the window | finder ×1 (1, 0 ms) | quiet 416 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 64 | double-click-finder-again | double-clicks it again: macOS takes the window back | finder ×1 (1, 0 ms) | quiet 457 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 65 | click-finder | clicks finder's title bar |  | quiet 374 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 66 | hide-finder | presses ⌘H |  | quiet 877 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 67 | double-click-mail | double-clicks mail's title bar: macOS zooms the window | mail ×1 (7, 348 ms), w68 ×1 (7, 348 ms) | quiet 943 ms | ✔ | ~ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 68 | double-click-mail-again | double-clicks it again: macOS takes the window back | mail ×1 (8, 398 ms), w68 ×1 (7, 343 ms) | quiet 782 ms | ✔ | ~ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 69 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 357 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 70 | unhide-finder | clicks its icon in the Dock |  | quiet 351 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 71 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 577 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 72 | minimize-calendar | presses ⌘M | calendar ×1 (23, 500 ms) | quiet 949 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 73 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 375 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 74 | drag-notes-by | drags notes, which floats, by its title bar -216 across and 144 down, and clicks there 0.3 s after letting go |  | quiet 848 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 75 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 404 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 76 | restore-calendar | clicks its miniature in the Dock | calendar ×1 (15, 513 ms) | quiet 913 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 77 | double-click-textedit | double-clicks textedit's title bar: macOS zooms the window | textedit ×1 (9, 238 ms) | quiet 700 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 78 | double-click-textedit-again | double-clicks it again: macOS takes the window back | textedit ×1 (11, 327 ms) | quiet 802 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 79 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 483 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 80 | drag-mail-by | drags mail, which floats, by its title bar 158 across and 64 down, and clicks there 0.3 s after letting go | w68 ×2 (31, 2820 ms) | quiet 892 ms | ✔ | ~ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 81 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 418 ms; blind for 100 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 82 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 415 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 83 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 403 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 84 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 449 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 85 | drag-preview-to-top-edge | drags preview by its title bar against the top edge of the screen and lets go | preview ×1 (10, 315 ms) | quiet 385 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 86 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 357 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 87 | double-click-textedit | double-clicks textedit's title bar: macOS zooms the window | textedit ×1 (10, 354 ms) | quiet 696 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 88 | double-click-textedit-again | double-clicks it again: macOS takes the window back | textedit ×1 (10, 322 ms) | quiet 794 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 89 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 371 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 90 | hide-finder | presses ⌘H |  | quiet 825 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 91 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 362 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 92 | quit-safari | presses ⌘Q in safari |  | quiet 785 ms; blind for 137 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 93 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 405 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 94 | double-click-preview | double-clicks preview's title bar: macOS zooms the window | preview ×1 (12, 385 ms) | quiet 802 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 95 | double-click-preview-again | double-clicks it again: macOS takes the window back | preview ×1 (13, 350 ms) | quiet 830 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 96 | unhide-finder | clicks its icon in the Dock |  | quiet 483 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 97 | reopen-safari | opens safari's document again |  | quiet 352 ms; blind for 1425 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 98 | leave-alone | does nothing for half a minute |  | quiet 367 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 99 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 420 ms; blind for 100 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 100 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 395 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 101 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 431 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 102 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 429 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 103 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 419 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 104 | quit | chooses Quit Arbor in Arbor's menu |  | quiet 856 ms |  |  | ✔ |  | ✘ |  | ✔ | ✘ |
| 105 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 364 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 106 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 455 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 107 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 387 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 108 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 354 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 109 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 496 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 110 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 409 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 111 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 472 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 112 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 488 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 113 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 388 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 114 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 494 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
