125 steps in 568 s, 101 of them judged, 23 with a rule broken. The sampler: samples 20113 seconds 500.4 hz 40.2 cost-ms 2.59 late 34 longest-gap-ms 1103 whole-samples 22874 whole-seconds 569.1 whole-late 53.
Input: 277 presses, releases, keys and scrolls reached the apps, half of them within 599 µs, 99 in 100 within 101785 µs, the latest after 205304 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 28, 731, 8722; dragged 165, 603, 3907; forward 6, 51963, 101785; key 44, 292, 1961; up 34, 830, 205304. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): down 14, 681; dragged 20, 271; forward 11, 7580; key 13, 712; scroll 28, 334; up 25, 338.
The round of input `started` (events, half within µs): down 13, 983; dragged 20, 454; forward 12, 12582; key 13, 617; scroll 28, 354; up 25, 412.
The round of input `last` (events, half within µs): down 13, 746; dragged 20, 417; forward 12, 6480; key 13, 482; scroll 28, 323; up 25, 382.
The round of input `after` (events, half within µs): down 13, 688; dragged 20, 384; forward 12, 5351; key 13, 471; scroll 28, 182; up 25, 303.
Judged: down, forward, up, key, dragged, scroll.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 5 | 0 |  |
| 2 | nothing moves that the person did not move | 71 | 8 | 16 input-before, 67 dock-down, 69 minimize-notes, 71 dock-right, 73 dock-right, 74 restore-notes, 83 launch, 90 quit-textedit |
| 3 | no jolts: a window moves once, to where it ends up | 109 | 10 | 21 display-plug, 25 display-unplug, 27 display-plug, 29 display-unplug, 31 display-plug, 35 display-unplug, 41 display-plug, 83 launch, 105 carry-calendar-across, 111 display-unplug |
| 4 | the window you switch to comes to the front and into view | 63 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 3 | 3 | 79 quit, 84 pause, 115 quit |
| 6 | what a person presses reaches the apps, at once | 49 | 2 | 33 click-wallpaper, 45 unhide-safari |
| L | no window is lost or stuck | 109 | 1 | 83 launch |
| - | what the script itself checked | 109 | 3 | 18 leave-alone-welcome-open, 79 quit, 115 quit |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **16 input-before** (a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text): calendar (w253) moved, and the step did not name it [moved-unasked]
  - +0 ms 403,115 937×600 · +1925 ms 113,69 937×600
- ✘ **67 dock-down** (presses ⌃⌥⌘ and the down arrow): finder (w234) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,120 920×436 · +1087 ms 340,31 920×297
- ✘ **67 dock-down** (presses ⌃⌥⌘ and the down arrow): safari (w237) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×791 · +1087 ms 138,31 1324×297
- ✘ **67 dock-down** (presses ⌃⌥⌘ and the down arrow): textedit (w248) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +1087 ms 165,31 673×297
- ✘ **67 dock-down** (presses ⌃⌥⌘ and the down arrow): terminal (w251) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 369,177 863×499 · +1087 ms 369,31 863×289
- ✘ **67 dock-down** (presses ⌃⌥⌘ and the down arrow): calendar (w253) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 1600×791 · +1087 ms 0,31 1600×503
- ✘ **67 dock-down** (presses ⌃⌥⌘ and the down arrow): preview (w260) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +1087 ms 4,31 708×297
- ✘ **67 dock-down** (presses ⌃⌥⌘ and the down arrow): mail (w262) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1087 ms 240,31 1120×297
- ~ **67 dock-down** (presses ⌃⌥⌘ and the down arrow): w264 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1087 ms 565,83 470×416
- ✘ **69 minimize-notes** (presses ⌘M): finder (w234) a floating window, moved and came back, and the step did not name it [moved-unasked]
  - +0 ms 340,31 920×297 · +1221 ms 340,31 920×299
- ✘ **69 minimize-notes** (presses ⌘M): safari (w237) a floating window, moved and came back, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×297 · +1269 ms 138,31 1324×299
- ✘ **69 minimize-notes** (presses ⌘M): textedit (w248) a floating window, moved and came back, and the step did not name it [moved-unasked]
  - +0 ms 165,31 673×297 · +1312 ms 165,31 673×299
- ✘ **69 minimize-notes** (presses ⌘M): calendar (w253) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 1600×503 · +762 ms 0,31 1600×793
- ✘ **69 minimize-notes** (presses ⌘M): preview (w260) a floating window, moved and came back, and the step did not name it [moved-unasked]
  - +0 ms 4,31 708×297 · +1378 ms 4,31 708×299
- ✘ **69 minimize-notes** (presses ⌘M): mail (w262) a floating window, moved and came back, and the step did not name it [moved-unasked]
  - +0 ms 240,31 1120×297 · +1378 ms 240,31 1120×299
- ✘ **71 dock-right** (presses ⌃⌥⌘ and the right arrow): safari (w237) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×299 · +934 ms 0,31 794×299
- ✘ **71 dock-right** (presses ⌃⌥⌘ and the right arrow): textedit (w248) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,31 673×299 · +934 ms 121,31 673×299
- ✘ **71 dock-right** (presses ⌃⌥⌘ and the right arrow): terminal (w251) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 369,31 863×289 · +934 ms 0,31 793×289
- ✘ **71 dock-right** (presses ⌃⌥⌘ and the right arrow): mail (w262) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,31 1120×299 · +934 ms 0,31 871×299
- ~ **71 dock-right** (presses ⌃⌥⌘ and the right arrow): w264 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,83 470×416 · +934 ms 201,83 470×416
- ✘ **73 dock-right** (presses ⌃⌥⌘ and the right arrow): safari (w237) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 794×299 · +965 ms 0,31 735×299
- ✘ **73 dock-right** (presses ⌃⌥⌘ and the right arrow): textedit (w248) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 121,31 673×299 · +965 ms 62,31 673×299
- ✘ **74 restore-notes** (clicks notes's icon in the Dock, which brings its minimized window back): calendar (w253) a floating window, moved and came back, and the step did not name it [moved-unasked]
  - +0 ms 0,31 1600×793 · +1584 ms 0,31 1600×791
- ✘ **83 launch** (starts Arbor): textedit (w248) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +1366 ms -672,790 673×439
- ✘ **83 launch** (starts Arbor): calendar (w253) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 1600×791 · +1366 ms -1599,770 1600×791
- ✘ **83 launch** (starts Arbor): preview (w260) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +1366 ms -707,770 708×424
- ✘ **83 launch** (starts Arbor): mail (w262) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1366 ms -1119,770 1120×630
- ~ **83 launch** (starts Arbor): w264 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1366 ms -794,877 470×416
- ✘ **83 launch** (starts Arbor): desk-a (w284) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,70 300×190 · +1366 ms -299,790 300×190
- ✘ **83 launch** (starts Arbor): desk-b (w286) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 360,70 300×190 · +1366 ms -299,790 300×190
- ✘ **90 quit-textedit** (presses ⌘Q in textedit): calendar (w253) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 1600×791 · +1019 ms -1599,770 1600×791
- ✘ **90 quit-textedit** (presses ⌘Q in textedit): preview (w260) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +1019 ms -707,770 708×424
- ✘ **90 quit-textedit** (presses ⌘Q in textedit): mail (w262) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1019 ms -1119,770 1120×630
- ~ **90 quit-textedit** (presses ⌘Q in textedit): w264 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1019 ms -794,877 470×416
- ✘ **90 quit-textedit** (presses ⌘Q in textedit): desk-a (w284) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,70 300×190 · +1019 ms -299,790 300×190
- ✘ **90 quit-textedit** (presses ⌘Q in textedit): desk-b (w286) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 360,70 300×190 · +1019 ms -299,790 300×190

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **21 display-plug** (the second display: plug): textedit (w248) moved 2 times [jolt]
  - +0 ms 165,65 673×439 · +1177 ms 165,65 656×422 · +3023 ms 165,65 673×439
- ✘ **25 display-unplug** (the second display: unplug): textedit (w248) moved 2 times [jolt]
  - +0 ms 165,65 673×439 · +13 ms 165,65 656×422 · +1904 ms 165,65 673×439
- ✘ **27 display-plug** (the second display: plug): textedit (w248) moved 2 times [jolt]
  - +0 ms 165,65 673×439 · +216 ms 165,65 656×422 · +2152 ms 165,65 673×439
- ✘ **27 display-plug** (the second display: plug): terminal (w251) moved 2 times [jolt]
  - +0 ms 737,300 863×499 · +216 ms 1000,300 863×499 · +2152 ms 737,300 863×499
- ✘ **29 display-unplug** (the second display: unplug): textedit (w248) moved 2 times [jolt]
  - +0 ms 165,65 673×439 · +28 ms 165,65 656×422 · +2137 ms 165,65 673×439
- ✘ **31 display-plug** (the second display: plug): textedit (w248) moved 2 times [jolt]
  - +0 ms 165,65 673×439 · +554 ms 165,65 656×422 · +2839 ms 165,65 673×439
- ✘ **31 display-plug** (the second display: plug): terminal (w251) moved 3 times [jolt]
  - +0 ms 1000,300 863×499 · +554 ms 737,300 863×499 · +1017 ms 1000,300 863×499 · +2850 ms 737,300 863×499
- ✘ **35 display-unplug** (the second display: unplug): textedit (w248) moved 2 times [jolt]
  - +0 ms 165,65 673×439 · +488 ms 165,65 656×422 · +2245 ms 165,65 673×439
- ✘ **35 display-unplug** (the second display: unplug): terminal (w251) moved 2 times [jolt]
  - +0 ms 737,300 863×499 · +488 ms 1000,300 863×499 · +2245 ms 737,300 863×499
- ✘ **41 display-plug** (the second display: plug): textedit (w248) moved 2 times [jolt]
  - +0 ms 165,65 673×439 · +416 ms 165,65 656×422 · +2425 ms 165,65 673×439
- ~ **67 dock-down** (presses ⌃⌥⌘ and the down arrow): the last window came to rest 849 ms after the key or the button [slow]
- ~ **71 dock-right** (presses ⌃⌥⌘ and the right arrow): the last window came to rest 707 ms after the key or the button [slow]
- ~ **78 dock-left** (presses ⌃⌥⌘ and the left arrow): the last window came to rest 983 ms after the key or the button [slow]
- ✘ **83 launch** (starts Arbor): finder (w234) moved 2 times [jolt]
  - +0 ms 340,120 920×436 · +283 ms 340,120 501×701 · +327 ms 798,43 501×767 · +1366 ms -500,770 501×767
- ✘ **83 launch** (starts Arbor): safari (w237) moved 2 times [jolt]
  - +0 ms 73,31 1324×790 · +327 ms 73,31 574×767 · +384 ms 12,43 574×767 · +1366 ms -573,770 574×767
- ✘ **83 launch** (starts Arbor): terminal (w251) moved 2 times [jolt]
  - +0 ms 369,177 863×499 · +406 ms 369,177 275×649 · +487 ms 1311,43 275×769 · +1366 ms -274,790 275×769
- ✘ **83 launch** (starts Arbor): settings (w256) moved 2 times [jolt]
  - +0 ms 437,85 723×625 · +532 ms -722,770 723×625 · +1366 ms 438,43 723×767
- ✘ **105 carry-calendar-across** (drags calendar, which floats, by its title bar onto the other display and lets go): calendar (w253) was 64 points ahead of the pointer's travel and 0 behind it at the most [pulled]
  - +0 ms 62,36 1600×791 · +108 ms 188,48 1600×791 · +116 ms 251,54 1600×791 · +171 ms 314,60 1600×791 · +242 ms 377,66 1600×791 · +305 ms 440,72 1600×791 · … 20 more … · +1763 ms 1825,139 1600×791 · +1838 ms 1888,145 1600×791 · +1866 ms 1951,151 1600×791 · +2048 ms 1952,151 1600×791 · +2799 ms 1951,151 1600×791
- ✘ **111 display-unplug** (the second display: unplug): safari (w237) moved 2 times [jolt]
  - +0 ms 73,31 1324×791 · +1 ms 73,42 735×299 · +2217 ms 73,42 1324×779 · +2221 ms 73,31 1324×790
- ✘ **111 display-unplug** (the second display: unplug): terminal (w251) moved 2 times [jolt]
  - +0 ms 369,177 862×497 · +1 ms 366,31 862×497 · +2249 ms 369,177 862×497

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **79 quit** (chooses Quit Arbor in Arbor's menu): safari (w237) is 73,31 1324×790; its own size was 73,42 735×299 [size-lost]
- ✘ **79 quit** (chooses Quit Arbor in Arbor's menu): terminal (w251) is 369,177 863×499; its own size was 369,177 877×499 [size-lost]
- ✘ **84 pause** (presses ⌃⌥⎋): safari (w237) is 73,31 1324×791; its own size was 73,42 735×299 [size-lost]
- ✘ **84 pause** (presses ⌃⌥⎋): terminal (w251) is 369,177 863×499; its own size was 369,177 877×499 [size-lost]
- ✘ **115 quit** (chooses Quit Arbor in Arbor's menu): safari (w237) is 73,31 1324×790; its own size was 73,42 735×299 [size-lost]
- ✘ **115 quit** (chooses Quit Arbor in Arbor's menu): terminal (w251) is 369,177 862×497; its own size was 1,35 1598×784 [size-lost]
- ✘ **115 quit** (chooses Quit Arbor in Arbor's menu): calendar (w253) has its size back but not its place: 0,31 1600×791, it was at 1951,151 1600×791 [size-lost]
- ✘ **115 quit** (chooses Quit Arbor in Arbor's menu): textedit (w816) is 165,65 656×422; its own size was 165,65 673×439 [size-lost]

### Rule 6: what a person presses reaches the apps, at once

- ✘ **33 click-wallpaper** (clicks on the wallpaper): the button came up, and the apps heard of it 155 ms later [input-held]
- ✘ **45 unhide-safari** (clicks its icon in the Dock): the button came up, and the apps heard of it 205 ms later [input-held]

### Rule L: no window is lost or stuck

- ✘ **83 launch** (starts Arbor): finder (w234) is out of view: 0% of it is on a display, at -500,770 501×767 [lost]
- ✘ **83 launch** (starts Arbor): safari (w237) is out of view: 0% of it is on a display, at -573,770 574×767 [lost]
- ✘ **83 launch** (starts Arbor): textedit (w248) is out of view: 0% of it is on a display, at -672,790 673×439 [lost]
- ✘ **83 launch** (starts Arbor): terminal (w251) is out of view: 0% of it is on a display, at -274,790 275×769 [lost]
- ✘ **83 launch** (starts Arbor): calendar (w253) is out of view: 0% of it is on a display, at -1599,770 1600×791 [lost]
- ✘ **83 launch** (starts Arbor): preview (w260) is out of view: 0% of it is on a display, at -707,770 708×424 [lost]
- ✘ **83 launch** (starts Arbor): mail (w262) is out of view: 0% of it is on a display, at -1119,770 1120×630 [lost]
- ✘ **83 launch** (starts Arbor): desk-a (w284) is out of view: 0% of it is on a display, at -299,790 300×190 [lost]
- ✘ **83 launch** (starts Arbor): desk-b (w286) is out of view: 0% of it is on a display, at -299,790 300×190 [lost]

### Rule -: what the script itself checked

- ✘ **18 leave-alone-welcome-open** (does nothing for half a minute, with Arbor's welcome window open): with nothing to do Arbor used 1.6 % of a core [busy]
- ~ **24 carry-notes-across** (drags notes, which floats, by its title bar onto the other display and lets go): the act was not performed: drag_window could not be done [script]
- ✘ **79 quit** (chooses Quit Arbor in Arbor's menu): Arbor's process ended, and nobody asked it to [crash]
- ✘ **115 quit** (chooses Quit Arbor in Arbor's menu): Arbor's process ended, and nobody asked it to [crash]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (3, 114 ms) | quiet 1025 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 608 ms; blind for 735 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (3, 270 ms) | quiet 1317 ms; blind for 252 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (5, 313 ms) | quiet 1199 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (2, 5 ms) | quiet 1050 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar |  | quiet 945 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 861 ms; blind for 750 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (3, 133 ms) | quiet 1077 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w264 ×1 (6, 206 ms) | quiet 750 ms; blind for 798 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (30, 2093 ms) | quiet 1032 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (30, 2765 ms) | quiet 1012 ms |  |  |  |  |  |  |  |  |
| 12 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (29, 4152 ms) | quiet 1397 ms |  |  |  |  |  |  |  |  |
| 13 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (35, 1754 ms) | quiet 386 ms |  |  |  |  |  |  |  |  |
| 14 | look-around | looks at the screen |  | quiet 397 ms |  |  |  |  |  |  |  |  |
| 15 | open-desks | opens the two windows that input is tried on | desk-a ×1 (1, 0 ms), desk-b ×1 (2, 47 ms) | quiet 365 ms; blind for 128 ms |  |  |  |  |  |  |  |  |
| 16 | input-before | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text | calendar ×1 (1, 0 ms) | quiet 945 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 17 | launch | starts Arbor |  | quiet 1002 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 18 | leave-alone-welcome-open | does nothing for half a minute, with Arbor's welcome window open |  | quiet 382 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 19 | close-welcome | closes Arbor's welcome window with its red button |  | quiet 1203 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 20 | input-started | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 867 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | display-plug | the second display: plug | textedit ×2 (2, 1846 ms), terminal ×1 (1, 0 ms) | quiet 377 ms; blind for 1103 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 22 | view-home | presses ⌃⌥0 |  | quiet 795 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 23 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 433 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | carry-notes-across | drags notes, which floats, by its title bar onto the other display and lets go |  | quiet 1078 ms |  |  |  |  |  |  |  | ~ |
| 25 | display-unplug | the second display: unplug | textedit ×2 (2, 1891 ms), terminal ×1 (1, 0 ms) | quiet 614 ms; blind for 211 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 26 | view-home | presses ⌃⌥0 |  | quiet 739 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 27 | display-plug | the second display: plug | textedit ×2 (2, 1936 ms), terminal ×2 (2, 1936 ms) | quiet 351 ms; blind for 194 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 28 | view-home | presses ⌃⌥0 |  | quiet 807 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 29 | display-unplug | the second display: unplug | textedit ×2 (2, 2109 ms), terminal ×1 (1, 0 ms) | quiet 458 ms; blind for 503 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 30 | view-home | presses ⌃⌥0 |  | quiet 768 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 31 | display-plug | the second display: plug | textedit ×2 (2, 2285 ms), terminal ×3 (3, 2296 ms) | quiet 380 ms; blind for 331 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 32 | view-home | presses ⌃⌥0 |  | quiet 613 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 33 | click-wallpaper | clicks on the wallpaper | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w264 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 640 ms; blind for 163 ms |  |  | ✔ |  |  | ✘ | ✔ | ✔ |
| 34 | click-wallpaper-again | clicks on the wallpaper again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w264 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 358 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 35 | display-unplug | the second display: unplug | textedit ×2 (2, 1757 ms), terminal ×2 (2, 1757 ms) | quiet 628 ms; blind for 465 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 36 | view-home | presses ⌃⌥0 |  | quiet 661 ms; blind for 121 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 37 | view-home | presses ⌃⌥0 |  | quiet 725 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 38 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 517 ms; blind for 236 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 366 ms; blind for 218 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | hide-safari | presses ⌘H |  | quiet 811 ms; blind for 122 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 41 | display-plug | the second display: plug | textedit ×2 (2, 2009 ms), terminal ×1 (1, 0 ms) | quiet 406 ms; blind for 365 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 42 | view-home | presses ⌃⌥0 |  | quiet 682 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 43 | click-notes | clicks notes's title bar |  | quiet 420 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | pin | chooses Keep This Window in View in Arbor's menu, or takes the tick off |  | quiet 359 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 45 | unhide-safari | clicks its icon in the Dock |  | quiet 381 ms; blind for 214 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 46 | view-all | presses ⌃⌥Space |  | quiet 722 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 47 | view-frame | presses ⌃⌥↩ |  | quiet 834 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 48 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 385 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 381 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 50 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 395 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 51 | view-all | presses ⌃⌥Space |  | quiet 657 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 52 | save-view-1 | presses ⌃⌥⇧1 |  | quiet 634 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 53 | view-in | presses ⌃⌥↓ |  | quiet 724 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 54 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 409 ms; blind for 100 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | click-terminal | clicks terminal's title bar |  | quiet 441 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 56 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 465 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | drag-calendar-to-top-edge | drags calendar by its title bar against the top edge of the screen and lets go | calendar ×1 (14, 314 ms) | quiet 354 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 58 | view-desktop | presses ⌃⌥D |  | quiet 764 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 59 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 438 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | send-across | sends the window in front to the other display | terminal ×1 (1, 0 ms) | quiet 1039 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 61 | view-home | presses ⌃⌥0 |  | quiet 801 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 62 | leave-alone | does nothing for half a minute |  | quiet 354 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 63 | view-all | presses ⌃⌥Space |  | quiet 705 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 64 | send-across | sends the window in front to the other display | terminal ×1 (1, 0 ms) | quiet 1021 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 65 | view-in | presses ⌃⌥↓ |  | quiet 771 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 66 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 561 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 67 | dock-down | presses ⌃⌥⌘ and the down arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w264 ×1 (1, 0 ms) | quiet 917 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 68 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 472 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 69 | minimize-notes | presses ⌘M | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), notes ×1 (21, 495 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms) | quiet 1651 ms; blind for 120 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 70 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 574 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 71 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w264 ×1 (1, 0 ms) | quiet 1170 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 72 | click-terminal | clicks terminal's title bar |  | quiet 489 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 73 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 969 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 74 | restore-notes | clicks notes's icon in the Dock, which brings its minimized window back | finder ×1 (1, 0 ms), notes ×1 (25, 463 ms), calendar ×1 (1, 0 ms) | quiet 1141 ms; blind for 166 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 75 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 371 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 76 | drag-safari-by | drags safari, which floats, by its title bar 144 across and 116 down, and clicks there 0.3 s after letting go |  | quiet 971 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 77 | click-safari | clicks safari's title bar |  | quiet 398 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 78 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 967 ms |  | ✔ | ~ | ✔ |  |  | ✔ | ✔ |
| 79 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (2, 31 ms), safari ×1 (2, 55 ms), textedit ×1 (1, 0 ms), terminal ×1 (2, 21 ms), settings ×1 (2, 61 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w264 ×1 (1, 0 ms) | quiet 780 ms |  |  | ✔ |  | ✘ |  | ✔ | ✘ |
| 80 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 409 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 81 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 419 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 82 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 510 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 83 | launch | starts Arbor | finder ×2 (3, 1083 ms), safari ×2 (3, 1039 ms), textedit ×1 (1, 0 ms), terminal ×2 (3, 960 ms), calendar ×1 (1, 0 ms), settings ×2 (2, 834 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w264 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 823 ms |  | ✘ | ✘ |  |  |  | ✘ | ✔ |
| 84 | pause | presses ⌃⌥⎋ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w264 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 907 ms |  |  | ✔ | ✔ | ✘ |  | ✔ | ✔ |
| 85 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 372 ms; blind for 133 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 86 | drag-terminal-to-top-edge | drags terminal by its title bar against the top edge of the screen and lets go | terminal ×1 (10, 330 ms) | quiet 380 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 87 | resume | presses ⌃⌥⎋ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w264 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 998 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 88 | view-in | presses ⌃⌥↓ |  | quiet 748 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 89 | dock-icon-textedit | clicks textedit's icon in the Dock | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w264 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 474 ms; blind for 136 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 90 | quit-textedit | presses ⌘Q in textedit | terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w264 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 926 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 91 | reopen-textedit | opens textedit's document again |  | quiet 1029 ms; blind for 607 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 92 | view-left | presses ⌃⌥← | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 994 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 93 | dock-icon-settings | clicks settings's icon in the Dock | finder ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 687 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 94 | click-settings | clicks settings's title bar |  | quiet 376 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 95 | undo | presses ⌃⌥Z |  | quiet 698 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 96 | view-back | presses ⌃⌥[ | finder ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 1025 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 97 | dock-icon-settings | clicks settings's icon in the Dock | finder ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 573 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 98 | dock-down | presses ⌃⌥⌘ and the down arrow |  | quiet 503 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 99 | save-view-2 | presses ⌃⌥⇧2 |  | quiet 604 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 100 | view-forward | presses ⌃⌥] |  | quiet 755 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 101 | view-forward | presses ⌃⌥] |  | quiet 578 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 102 | dock-icon-calendar | clicks calendar's icon in the Dock | calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w264 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 585 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 103 | float-all-here | floats every window of this display | finder ×1 (3, 32 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 1063 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 104 | view-left | presses ⌃⌥← |  | quiet 689 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 105 | carry-calendar-across | drags calendar, which floats, by its title bar onto the other display and lets go |  | quiet 1052 ms | ✔ | ✔ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 106 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 482 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 107 | mirror | presses ⌃⌥⇧R |  | quiet 666 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 108 | click-notes | clicks notes's title bar |  | quiet 430 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 109 | leave-alone | does nothing for half a minute |  | quiet 414 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 110 | drag-preview-to-top-edge | drags preview by its title bar against the top edge of the screen and lets go | preview ×1 (9, 332 ms) | quiet 382 ms; blind for 127 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 111 | display-unplug | the second display: unplug | safari ×2 (3, 2220 ms), terminal ×2 (2, 2248 ms), calendar ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 650 ms; blind for 537 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 112 | view-home | presses ⌃⌥0 |  | quiet 679 ms |  |  | ✔ |  |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 113 | view-home | presses ⌃⌥0 |  | quiet 595 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 114 | input-last | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 934 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 115 | quit | chooses Quit Arbor in Arbor's menu |  | quiet 385 ms |  |  | ✔ |  | ✘ |  | ✔ | ✘ |
| 116 | input-after | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 921 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 117 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 534 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 118 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 399 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 119 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 410 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 120 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 442 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 121 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 443 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 122 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 388 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 123 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 482 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 124 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 403 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 125 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 404 ms; blind for 263 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
