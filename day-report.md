84 steps in 326 s, 64 of them judged, 2 with a rule broken. The sampler: samples 9308 seconds 263.2 hz 35.4 cost-ms 2.87 late 50 longest-gap-ms 1353 whole-samples 11553 whole-seconds 326.7 whole-late 89.
Input: 491 presses, releases, keys and scrolls reached the apps, half of them within 585 µs, 99 in 100 within 66744 µs, the latest after 227885 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 47, 678, 13582; dragged 363, 594, 6302; forward 7, 51316, 77032; key 20, 500, 2379; up 54, 443, 227885. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 31385; up 8, 345.
The round of input `after` (events, half within µs): forward 8, 44181; up 8, 2077.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 17 | 0 |  |
| 2 | nothing moves that the person did not move | 70 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 72 | 1 | 60 drag-mail-by |
| 4 | the window you switch to comes to the front and into view | 60 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 47 | 1 | 33 dock-icon-mail |
| L | no window is lost or stuck | 72 | 0 |  |
| - | what the script itself checked | 72 | 0 |  |

## Findings

### Rule 2: nothing moves that the person did not move

- ~ **34 double-click-mail** (double-clicks mail's title bar: macOS zooms the window): w68 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1145 ms 565,185 470×416 · +1217 ms 565,212 470×416 · +1338 ms 565,218 470×416
- ~ **35 double-click-mail-again** (double-clicks it again: macOS takes the window back): w68 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,218 470×416 · +1001 ms 565,211 470×416 · +1152 ms 565,197 470×416 · +1210 ms 565,186 470×416 · +1282 ms 565,179 470×416
- ~ **60 drag-mail-by** (drags mail, which floats, by its title bar -106 across and 8 down, and clicks there 0.3 s after letting go): w68 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +852 ms 561,179 470×416 · +893 ms 557,179 470×416 · +974 ms 554,179 470×416 · +1071 ms 550,180 470×416 · +1138 ms 547,180 470×416 · … 20 more … · +2300 ms 466,186 470×416 · +2395 ms 462,186 470×416 · +2506 ms 459,187 470×416 · +2776 ms 460,187 470×416 · +3490 ms 459,187 470×416

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **60 drag-mail-by** (drags mail, which floats, by its title bar -106 across and 8 down, and clicks there 0.3 s after letting go): w68 of Mail moved 3 times [jolt]
  - +0 ms 565,179 470×416 · +852 ms 561,179 470×416 · +893 ms 557,179 470×416 · +974 ms 554,179 470×416 · +1071 ms 550,180 470×416 · +1138 ms 547,180 470×416 · … 20 more … · +2300 ms 466,186 470×416 · +2395 ms 462,186 470×416 · +2506 ms 459,187 470×416 · +2776 ms 460,187 470×416 · +3490 ms 459,187 470×416
- ~ **75 drag-preview-to-right-edge** (drags preview by its title bar against the right edge of the screen and lets go): preview (w62) changed its size while it was being dragged [jolt]
  - +0 ms 800,44 800×791 · +92 ms 800,72 800×791 · +143 ms 832,58 763×642 · +205 ms 878,85 730×511 · +209 ms 881,85 724×486 · +250 ms 884,85 716×454 · … 22 more … · +1813 ms 1247,383 709×425 · +1863 ms 1264,397 709×425 · +1932 ms 1297,424 709×425 · +2194 ms 1298,424 709×425 · +2273 ms 1297,424 709×425
- ~ **79 drag-textedit-by** (drags textedit, which floats, by its title bar -138 across and 121 down): textedit (w174) changed its size while it was being dragged [jolt]
  - +0 ms -5,35 1600×791 · +73 ms -14,44 1600×791 · +127 ms 80,39 1419×723 · +134 ms 152,43 1264×664 · +157 ms 223,43 1122×610 · +174 ms 281,43 1004×565 · … 25 more … · +1670 ms 334,139 674×440 · +1721 ms 330,143 674×440 · +1787 ms 325,147 674×440 · +2100 ms 326,147 674×440 · +2200 ms 325,147 674×440

### Rule 6: what a person presses reaches the apps, at once

- ✘ **33 dock-icon-mail** (clicks mail's icon in the Dock): the button came up, and the apps heard of it 227 ms later [input-held]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (2, 24 ms) | quiet 665 ms; blind for 273 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 438 ms; blind for 731 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×2 (2, 253 ms) | quiet 1560 ms; blind for 682 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (6, 305 ms) | quiet 1101 ms; blind for 159 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (4, 43 ms), w52 ×2 (12, 985 ms), w54 ×1 (5, 199 ms) | quiet 362 ms; blind for 299 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar |  | quiet 916 ms; blind for 100 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×2 (2, 522 ms) | quiet 460 ms; blind for 521 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview |  | quiet 638 ms; blind for 1276 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | mail ×1 (1, 0 ms), w68 ×1 (3, 169 ms) | quiet 534 ms; blind for 253 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (40, 4224 ms) | quiet 1415 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (34, 2427 ms) | quiet 1117 ms; blind for 101 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 395 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 666 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | click-preview | clicks preview's title bar |  | quiet 372 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 15 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 427 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 16 | click-safari | clicks safari's title bar |  | quiet 364 ms; blind for 104 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | hide-safari | presses ⌘H |  | quiet 751 ms; blind for 107 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 18 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 356 ms; blind for 914 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | new-window-terminal | presses ⌘N in terminal |  | quiet 1137 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 20 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 409 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 21 | unhide-safari | clicks its icon in the Dock |  | quiet 359 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 22 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 489 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 23 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 397 ms; blind for 119 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 357 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | drag-safari-by | drags safari, which floats, by its title bar 143 across and 156 down |  | quiet 1047 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 441 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | drag-settings-by | drags settings, which floats, by its title bar -175 across and 148 down |  | quiet 1043 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 358 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 29 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 387 ms; blind for 149 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | drag-textedit-to-top-edge | drags textedit by its title bar against the top edge of the screen and lets go | textedit ×1 (7, 219 ms) | quiet 1470 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 377 ms; blind for 105 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 32 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 376 ms; blind for 276 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 33 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 434 ms; blind for 239 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 34 | double-click-mail | double-clicks mail's title bar: macOS zooms the window | mail ×1 (4, 309 ms), w68 ×1 (3, 193 ms) | quiet 401 ms; blind for 141 ms | ✔ | ~ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | double-click-mail-again | double-clicks it again: macOS takes the window back | mail ×1 (5, 361 ms), w68 ×1 (4, 281 ms) | quiet 766 ms | ✔ | ~ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 36 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 356 ms; blind for 109 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | quit-safari | presses ⌘Q in safari |  | quiet 1035 ms; blind for 280 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 38 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 412 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | reopen-safari | opens safari's document again |  | quiet 383 ms; blind for 1353 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 40 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 361 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | hide-terminal | presses ⌘H |  | quiet 827 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 42 | quit-safari | presses ⌘Q in safari |  | quiet 810 ms; blind for 142 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 43 | click-mail | clicks mail's title bar |  | quiet 406 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | unhide-terminal | clicks its icon in the Dock |  | quiet 430 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | reopen-safari | opens safari's document again |  | quiet 389 ms; blind for 704 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 46 | leave-alone | does nothing for half a minute |  | quiet 392 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 47 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 471 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | double-click-calendar | double-clicks calendar's title bar: macOS zooms the window | calendar ×1 (9, 377 ms) | quiet 723 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | double-click-calendar-again | double-clicks it again: macOS takes the window back | calendar ×1 (8, 350 ms) | quiet 890 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 441 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | quit-textedit | presses ⌘Q in textedit |  | quiet 822 ms; blind for 120 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 52 | reopen-textedit | opens textedit's document again |  | quiet 712 ms; blind for 306 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 53 | drag-textedit-by | drags textedit, which floats, by its title bar -93 across and 125 down, and clicks there 0.3 s after letting go |  | quiet 978 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 54 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 381 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 407 ms; blind for 139 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 56 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 415 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 57 | double-click-terminal | double-clicks terminal's title bar: macOS zooms the window | terminal ×1 (14, 306 ms) | quiet 731 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 58 | double-click-terminal-again | double-clicks it again: macOS takes the window back | terminal ×1 (15, 298 ms) | quiet 649 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 59 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 428 ms; blind for 105 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | drag-mail-by | drags mail, which floats, by its title bar -106 across and 8 down, and clicks there 0.3 s after letting go | w68 ×3 (30, 2638 ms) | quiet 956 ms | ✔ | ~ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 449 ms; blind for 128 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 62 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 513 ms; blind for 100 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 63 | drag-finder-by | drags finder, which floats, by its title bar 203 across and -36 down |  | quiet 1059 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 64 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 428 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 65 | window-menu-textedit | chooses textedit's first window in the Window menu |  | quiet 895 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 66 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 411 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 67 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 402 ms; blind for 112 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 68 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 373 ms; blind for 447 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 69 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 450 ms; blind for 151 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 70 | minimize-preview | presses ⌘M | preview ×1 (19, 484 ms) | quiet 985 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 71 | restore-preview | clicks its miniature in the Dock | preview ×1 (16, 475 ms) | quiet 771 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 72 | drag-preview-to-right-edge | drags preview by its title bar against the right edge of the screen and lets go | preview ×1 (12, 296 ms) | quiet 1346 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 73 | drag-textedit-to-top-edge | drags textedit by its title bar against the top edge of the screen and lets go | textedit ×1 (8, 309 ms) | quiet 1430 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 74 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 501 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 75 | drag-preview-to-right-edge | drags preview by its title bar against the right edge of the screen and lets go | preview ×1 (8, 293 ms) | quiet 1390 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 76 | click-textedit | clicks textedit's title bar |  | quiet 426 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 77 | minimize-textedit | presses ⌘M | textedit ×1 (7, 276 ms) | quiet 1005 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 78 | restore-textedit | clicks its miniature in the Dock | textedit ×1 (11, 296 ms) | quiet 546 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 79 | drag-textedit-by | drags textedit, which floats, by its title bar -138 across and 121 down | textedit ×1 (2, 45 ms) | quiet 1090 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 80 | drag-safari-to-top-edge | drags safari by its title bar against the top edge of the screen and lets go |  | quiet 1053 ms; blind for 111 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 81 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 414 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 82 | quit-textedit | presses ⌘Q in textedit |  | quiet 753 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 83 | reopen-textedit | opens textedit's document again |  | quiet 508 ms; blind for 327 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 84 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 396 ms; blind for 105 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
