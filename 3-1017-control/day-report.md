68 steps in 347 s, 38 of them judged, 15 with a rule broken. The sampler: samples 11297 seconds 291.7 hz 38.7 cost-ms 3.76 late 64 longest-gap-ms 1304 whole-samples 13471 whole-seconds 347.8 whole-late 92.
Input: 228 presses, releases, keys and scrolls reached the apps, half of them within 670 µs, 99 in 100 within 128785 µs, the latest after 149884 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 16, 1321, 8113; dragged 165, 553, 6284; forward 11, 95465, 134978; key 9, 880, 3971; up 27, 1370, 149884. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): down 13, 1085; dragged 20, 434; forward 12, 7105; key 13, 521; scroll 28, 356; up 25, 396.
The round of input `after` (events, half within µs): down 13, 690; dragged 20, 432; forward 12, 12775; key 13, 418; scroll 28, 321; up 25, 485.
Judged: no kind. Not down: fewer than 10 such events in a round with Arbor. Not forward: fewer than 10 such events in a round with Arbor. Not up: fewer than 10 such events in a round with Arbor. Not key: fewer than 10 such events in a round with Arbor. Not dragged: fewer than 10 such events in a round with Arbor. Not scroll: fewer than 10 such events in a round with Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 5 | 0 |  |
| 2 | nothing moves that the person did not move | 39 | 2 | 57 minimize-notes, 59 restore-notes |
| 3 | no jolts: a window moves once, to where it ends up | 54 | 9 | 18 display-unplug, 20 display-unplug, 21 display-plug, 32 drag-mail-to-right-edge, 36 display-unplug, 47 display-plug, 50 display-plug, 62 display-plug, 67 display-unplug |
| 4 | the window you switch to comes to the front and into view | 35 | 2 | 22 click-terminal, 45 dock-icon-terminal |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 28 | 2 | 43 dock-icon-calendar, 63 dock-icon-settings |
| L | no window is lost or stuck | 54 | 0 |  |
| - | what the script itself checked | 54 | 0 |  |

## Findings

### Rule 2: nothing moves that the person did not move

- ~ **32 drag-mail-to-right-edge** (drags mail by its title bar against the right edge of the screen and lets go): w1078 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 577,230 470×416 · +964 ms 577,242 470×416 · +1005 ms 577,268 470×416 · +1092 ms 577,281 470×416 · +1122 ms 593,294 470×416 · +1253 ms 650,306 470×416 · … 25 more … · +4611 ms 1060,551 470×416 · +4887 ms 1058,546 470×416 · +4953 ms 949,270 470×416 · +5082 ms 932,223 470×416 · +5143 ms 929,219 470×416
- ✘ **57 minimize-notes** (presses ⌘M): mail (w1076) moved and came back, and the step did not name it [moved-unasked]
  - +0 ms 728,31 872×791 · +1272 ms 728,31 872×793
- ~ **57 minimize-notes** (presses ⌘M): w1078 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 929,218 470×416 · +1272 ms 929,219 470×416
- ✘ **59 restore-notes** (clicks notes's icon in the Dock, which brings its minimized window back): mail (w1076) moved and came back, and the step did not name it [moved-unasked]
  - +0 ms 728,31 872×793 · +1553 ms 728,31 872×791
- ~ **59 restore-notes** (clicks notes's icon in the Dock, which brings its minimized window back): w1078 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 929,219 470×416 · +1553 ms 929,218 470×416

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **18 display-unplug** (the second display: unplug): terminal (w1065) moved 2 times [jolt]
  - +0 ms 1450,438 863×499 · +61 ms -150,302 863×499 · +672 ms 737,401 863×499
- ✘ **20 display-unplug** (the second display: unplug): terminal (w1065) went 1774 points out of its way before it ended up [jolt]
  - +0 ms 1450,438 863×499 · +4 ms -150,302 863×499 · +166 ms 737,401 863×499
- ✘ **21 display-plug** (the second display: plug): terminal (w1065) moved 2 times [jolt]
  - +0 ms 737,401 863×499 · +30 ms -863,401 863×499 · +875 ms 2017,401 863×499
- ✘ **32 drag-mail-to-right-edge** (drags mail by its title bar against the right edge of the screen and lets go): w1078 of Mail moved 4 times [jolt]
  - +0 ms 577,230 470×416 · +964 ms 577,242 470×416 · +1005 ms 577,268 470×416 · +1092 ms 577,281 470×416 · +1122 ms 593,294 470×416 · +1253 ms 650,306 470×416 · … 25 more … · +4611 ms 1060,551 470×416 · +4887 ms 1058,546 470×416 · +4953 ms 949,270 470×416 · +5082 ms 932,223 470×416 · +5143 ms 929,219 470×416
- ✘ **36 display-unplug** (the second display: unplug): terminal (w1065) moved 2 times [jolt]
  - +0 ms -863,401 863×499 · +-5 ms 737,501 863×499 · +412 ms 1450,438 863×499
- ✘ **47 display-plug** (the second display: plug): calendar (w1069) went 946 points out of its way before it ended up [jolt]
  - +0 ms 800,32 801×791 · +597 ms 1273,321 938×601 · +737 ms 799,31 801×791
- ✘ **50 display-plug** (the second display: plug): terminal (w1065) moved 2 times [jolt]
  - +0 ms 1450,438 863×499 · +212 ms -863,401 863×499 · +963 ms 2017,401 863×499
- ✘ **50 display-plug** (the second display: plug): calendar (w1069) moved 2 times [jolt]
  - +0 ms 1273,321 938×601 · +212 ms 662,299 938×601 · +963 ms 1273,321 938×601 · +1045 ms 2553,221 938×601
- ✘ **50 display-plug** (the second display: plug): preview (w1074) moved 2 times [jolt]
  - +0 ms -63,81 708×424 · +212 ms 0,81 708×424 · +963 ms -63,81 708×424
- ✘ **62 display-plug** (the second display: plug): terminal (w1065) moved 2 times [jolt]
  - +0 ms 1450,438 863×499 · +113 ms 3370,618 863×499 · +539 ms 1600,438 863×499
- ✘ **67 display-unplug** (the second display: unplug): terminal (w1065) moved 2 times [jolt]
  - +0 ms 1600,438 863×499 · +1 ms 0,302 863×499 · +823 ms 1450,438 863×499

### Rule 4: the window you switch to comes to the front and into view

- ✘ **22 click-terminal** (clicks terminal's title bar): terminal (w1065) is not wholly in view: 80% of it, at 2017,401 863×499 in 0,31 1600×791 and 1600,31 1280×769 [focus]
- ✘ **45 dock-icon-terminal** (clicks terminal's icon in the Dock): terminal (w1065) is not wholly in view: 13% of it, at 1450,438 863×499 in 0,31 1600×791 [focus]

### Rule 6: what a person presses reaches the apps, at once

- ✘ **43 dock-icon-calendar** (clicks calendar's icon in the Dock): the button came up, and the apps heard of it 128 ms later [input-held]
- ✘ **63 dock-icon-settings** (clicks settings's icon in the Dock): the button came up, and the apps heard of it 149 ms later [input-held]

### Rule -: what the script itself checked

- ~ **48 drag-safari-by** (drags safari, which floats, by its title bar -100 across and 91 down): the act was not performed: drag_window could not be done [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (4, 89 ms) | quiet 932 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 548 ms; blind for 922 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (4, 287 ms) | quiet 1189 ms; blind for 524 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (4, 305 ms) | quiet 1187 ms; blind for 145 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (2, 7 ms) | quiet 959 ms; blind for 208 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (5, 371 ms) | quiet 1322 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 421 ms; blind for 356 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (3, 37 ms) | quiet 978 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w1078 ×1 (4, 145 ms) | quiet 717 ms; blind for 1413 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (26, 3066 ms) | quiet 1404 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (34, 2193 ms) | quiet 1026 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 422 ms |  |  |  |  |  |  |  |  |
| 13 | open-desks | opens the two windows that input is tried on | desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 352 ms |  |  |  |  |  |  |  |  |
| 14 | input-before | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 918 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 15 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 407 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 16 | display-plug | the second display: plug | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms) | quiet 379 ms; blind for 527 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 17 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 445 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 18 | display-unplug | the second display: unplug | terminal ×2 (2, 611 ms) | quiet 369 ms; blind for 611 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 19 | display-plug | the second display: plug | terminal ×1 (1, 0 ms) | quiet 371 ms; blind for 398 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 20 | display-unplug | the second display: unplug | terminal ×1 (2, 162 ms) | quiet 402 ms; blind for 161 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 21 | display-plug | the second display: plug | terminal ×2 (2, 845 ms) | quiet 363 ms; blind for 249 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 22 | click-terminal | clicks terminal's title bar |  | quiet 384 ms; blind for 101 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 23 | drag-notes-by | drags notes, which floats, by its title bar 126 across and 53 down |  | quiet 1051 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | click-settings | clicks settings's title bar |  | quiet 362 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 397 ms; blind for 158 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | display-right | the second display: right |  | quiet 360 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 27 | leave-alone | does nothing for half a minute |  | quiet 359 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 28 | click-settings | clicks settings's title bar |  | quiet 356 ms; blind for 129 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 29 | click-notes | clicks notes's title bar |  | quiet 366 ms; blind for 107 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 382 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | new-window-finder | presses ⌘N in finder |  | quiet 971 ms; blind for 132 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 32 | drag-mail-to-right-edge | drags mail by its title bar against the right edge of the screen and lets go | mail ×1 (4, 256 ms), w1078 ×4 (35, 4179 ms) | quiet 1453 ms; blind for 161 ms | ✔ | ~ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | display-left | the second display: left | terminal ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1078 ×1 (1, 0 ms) | quiet 373 ms; blind for 269 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 34 | click-new-window | clicks the title bar of the window that ⌘N opened |  | quiet 360 ms; blind for 178 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | close-window | presses ⌘W |  | quiet 1197 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 36 | display-unplug | the second display: unplug | terminal ×2 (2, 417 ms) | quiet 361 ms; blind for 416 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 37 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 380 ms; blind for 131 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 38 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 460 ms; blind for 123 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 397 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 40 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 365 ms; blind for 107 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 41 | leave-alone | does nothing for half a minute |  | quiet 351 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 42 | click-safari | clicks safari's title bar |  | quiet 365 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 406 ms; blind for 154 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 44 | drag-calendar-to-right-edge | drags calendar by its title bar against the right edge of the screen and lets go | calendar ×1 (11, 313 ms) | quiet 1456 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 364 ms; blind for 126 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 46 | drag-preview-by | drags preview, which floats, by its title bar -112 across and 46 down, and clicks there 0.3 s after letting go | preview ×1 (1, 0 ms) | quiet 957 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | display-plug | the second display: plug | terminal ×1 (1, 0 ms), calendar ×1 (2, 140 ms), preview ×1 (1, 0 ms) | quiet 357 ms; blind for 530 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 48 | drag-safari-by | drags safari, which floats, by its title bar -100 across and 91 down |  | quiet 1104 ms; blind for 138 ms |  |  |  |  |  |  |  | ~ |
| 49 | display-unplug | the second display: unplug | terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 422 ms; blind for 550 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 50 | display-plug | the second display: plug | terminal ×2 (2, 751 ms), calendar ×2 (3, 833 ms), preview ×2 (2, 751 ms) | quiet 359 ms; blind for 343 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 51 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 443 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | new-window-safari | presses ⌘N in safari |  | quiet 474 ms; blind for 463 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 53 | click-preview | clicks preview's title bar |  | quiet 398 ms; blind for 136 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 54 | click-new-window | clicks the title bar of the window that ⌘N opened |  | quiet 407 ms; blind for 127 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | close-window | presses ⌘W |  | quiet 988 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 56 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 361 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | minimize-notes | presses ⌘M | notes ×1 (15, 258 ms), mail ×1 (1, 0 ms), w1078 ×1 (1, 0 ms) | quiet 987 ms; blind for 456 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 58 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 388 ms; blind for 141 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 59 | restore-notes | clicks notes's icon in the Dock, which brings its minimized window back | notes ×1 (12, 322 ms), mail ×1 (1, 0 ms), w1078 ×1 (1, 0 ms) | quiet 1038 ms; blind for 219 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | drag-preview-to-left-edge | drags preview by its title bar against the left edge of the screen and lets go | preview ×1 (9, 253 ms) | quiet 1346 ms; blind for 101 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | display-unplug | the second display: unplug | terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 358 ms; blind for 670 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 62 | display-plug | the second display: plug | terminal ×2 (2, 426 ms), calendar ×1 (1, 0 ms) | quiet 400 ms; blind for 647 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 63 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 617 ms; blind for 160 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 64 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 352 ms; blind for 269 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 65 | quit-safari | presses ⌘Q in safari |  | quiet 923 ms; blind for 297 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 66 | reopen-safari | opens safari's document again |  | quiet 414 ms; blind for 1304 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 67 | display-unplug | the second display: unplug | terminal ×2 (2, 822 ms), calendar ×1 (1, 0 ms) | quiet 365 ms; blind for 821 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 68 | input-after | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 940 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
