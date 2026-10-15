61 steps in 299 s, 47 of them judged, 4 with a rule broken. The sampler: samples 9979 seconds 251.2 hz 39.7 cost-ms 2.37 late 14 longest-gap-ms 776 whole-samples 11922 whole-seconds 300.1 whole-late 31.
Input: 285 presses, releases, keys and scrolls reached the apps, half of them within 547 µs, 99 in 100 within 39239 µs, the latest after 65603 µs.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 8 | 0 |  |
| 2 | nothing moves that the person did not move | 48 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 48 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 45 | 3 | 43 drag-calendar-by, 44 drag-safari-by, 53 click-new-window |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 38 | 0 |  |
| L | no window is lost or stuck | 48 | 0 |  |
| - | what the script itself checked | 48 | 1 | 38 drag-mail-to-right-edge |

## Findings

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **33 drag-terminal-to-right-edge** (drags terminal by its title bar against the right edge of the screen and lets go): terminal (w724) changed its size while it was being dragged [jolt]
  - +0 ms 812,31 800×784 · +10 ms 839,44 800×784 · +41 ms 839,44 803×775 · +49 ms 839,44 814×735 · +87 ms 839,44 839×643 · +94 ms 804,44 839×643 · … 25 more … · +1485 ms 1113,383 877×500 · +1562 ms 1126,397 877×500 · +1618 ms 1139,410 877×500 · +1899 ms 1140,410 877×500 · +1950 ms 1139,410 877×500
- ~ **43 drag-calendar-by** (drags calendar, which floats, by its title bar 32 across and 53 down): calendar (w731) changed its size while it was being dragged [jolt]
  - +0 ms 801,33 801×791 · +70 ms 802,35 801×791 · +136 ms 803,37 801×791 · +177 ms 803,37 809×791 · +242 ms 755,36 873×791 · +276 ms 743,36 891×791 · … 23 more … · +1733 ms 756,79 909×791 · +1831 ms 757,80 909×791 · +1887 ms 758,82 909×791 · +2193 ms 759,82 909×791 · +2304 ms 758,82 909×791
- ~ **55 drag-textedit-to-right-edge** (drags textedit by its title bar against the right edge of the screen and lets go): textedit (w721) changed its size while it was being dragged [jolt]
  - +0 ms 28,44 800×791 · +78 ms 57,72 800×791 · +145 ms 57,72 741×627 · +151 ms 112,58 741×627 · +172 ms 128,58 724×579 · +217 ms 209,85 700×512 · … 22 more … · +1491 ms 844,370 674×440 · +1541 ms 873,383 674×440 · +1550 ms 902,397 674×440 · +1658 ms 932,410 674×440 · +1759 ms 961,424 674×440

### Rule 4: the window you switch to comes to the front and into view

- ✘ **43 drag-calendar-by** (drags calendar, which floats, by its title bar 32 across and 53 down): calendar (w731) is not wholly in view: 87% of it, at 758,82 909×791 in 0,31 1600×791 [focus]
- ✘ **44 drag-safari-by** (drags safari, which floats, by its title bar -178 across and 35 down): safari (w710) is not wholly in view: 93% of it, at -106,54 1576×767 in 0,31 1600×791 [focus]
- ✘ **53 click-new-window** (clicks the title bar of the window that ⌘N opened): finder-new-51 (w840) is not in front: settings (w732) ahead of it, of which 1 cover part of it [behind]
- ✘ **53 click-new-window** (clicks the title bar of the window that ⌘N opened): finder-new-51 (w840) its app is not the one in front (process 74800 is) [focus]

### Rule -: what the script itself checked

- ✘ **38 drag-mail-to-right-edge** (drags mail by its title bar against the right edge of the screen and lets go): the act was not performed: drag_window could not be done [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (4, 121 ms) | quiet 952 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 414 ms; blind for 1503 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (4, 274 ms) | quiet 1219 ms; blind for 449 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal |  | quiet 919 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (5, 305 ms) | quiet 1209 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (5, 375 ms) | quiet 1299 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 541 ms; blind for 433 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (2, 57 ms) | quiet 1043 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w740 ×1 (6, 193 ms) | quiet 716 ms; blind for 1031 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (42, 3841 ms) | quiet 1392 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (29, 2323 ms) | quiet 1030 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 394 ms |  |  |  |  |  |  |  |  |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 13 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 409 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 14 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 417 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 15 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 501 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 16 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 413 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | drag-textedit-to-left-edge | drags textedit by its title bar against the left edge of the screen and lets go | textedit ×1 (12, 322 ms) | quiet 1403 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 18 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 542 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 418 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 397 ms; blind for 104 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | new-window-safari | presses ⌘N in safari |  | quiet 1000 ms; blind for 191 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 22 | close-window | presses ⌘W |  | quiet 859 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 23 | leave-alone | does nothing for half a minute |  | quiet 397 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 24 | leave-alone | does nothing for half a minute |  | quiet 402 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 25 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 394 ms; blind for 133 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 363 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | drag-calendar-to-right-edge | drags calendar by its title bar against the right edge of the screen and lets go | calendar ×1 (8, 283 ms) | quiet 1359 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 502 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 29 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 376 ms; blind for 102 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 386 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 369 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 423 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | drag-terminal-to-right-edge | drags terminal by its title bar against the right edge of the screen and lets go | terminal ×1 (12, 347 ms) | quiet 1422 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 420 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | minimize-settings | presses ⌘M | settings ×1 (25, 481 ms) | quiet 993 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 36 | restore-settings | clicks settings's icon in the Dock, which brings its minimized window back | settings ×1 (14, 459 ms) | quiet 1004 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 516 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | drag-mail-to-right-edge | drags mail by its title bar against the right edge of the screen and lets go |  | quiet 1058 ms |  |  |  |  |  |  |  | ✘ |
| 39 | click-textedit | clicks textedit's title bar |  | quiet 458 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 487 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 426 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 436 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | drag-calendar-by | drags calendar, which floats, by its title bar 32 across and 53 down |  | quiet 1035 ms | ✔ | ✔ | ~ | ✘ |  | ✔ | ✔ | ✔ |
| 44 | drag-safari-by | drags safari, which floats, by its title bar -178 across and 35 down |  | quiet 1087 ms | ✔ | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 45 | leave-alone | does nothing for half a minute |  | quiet 372 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 46 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 432 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 412 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | double-click-finder | double-clicks finder's title bar: macOS zooms the window | finder ×1 (13, 373 ms) | quiet 820 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | double-click-finder-again | double-clicks it again: macOS takes the window back | finder ×1 (15, 373 ms) | quiet 793 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 358 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | new-window-finder | presses ⌘N in finder |  | quiet 1179 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 52 | click-settings | clicks settings's title bar |  | quiet 355 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 53 | click-new-window | clicks the title bar of the window that ⌘N opened |  | quiet 428 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 54 | click-calendar | clicks calendar's title bar |  | quiet 435 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | drag-textedit-to-right-edge | drags textedit by its title bar against the right edge of the screen and lets go | textedit ×1 (9, 272 ms) | quiet 1361 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 56 | leave-alone | does nothing for half a minute |  | quiet 409 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 57 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 406 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 58 | quit-safari | presses ⌘Q in safari |  | quiet 972 ms; blind for 144 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 59 | window-menu-textedit | chooses textedit's first window in the Window menu |  | quiet 969 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | reopen-safari | opens safari's document again |  | quiet 393 ms; blind for 776 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 61 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 416 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
