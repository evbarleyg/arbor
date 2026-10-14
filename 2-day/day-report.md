115 steps in 387 s, 97 of them judged, 27 with a rule broken. The sampler: samples 14702 seconds 388.3 hz 37.9 cost-ms 2.76 late 3595 longest-gap-ms 4596.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 4 | 0 |  |
| 2 | nothing moves that the person did not move | 80 | 12 | 37 grow-finder, 38 shrink-finder, 55 show-everything, 62 show-everything-2, 74 minimize-safari, 75 restore-safari, 77 hide-finder, 78 unhide-finder, 80 quit-textedit, 84 leave-full-screen, 95 drag-calendar-while-paused, 113 launch-2 |
| 3 | no jolts: a window moves once, to where it ends up | 101 | 2 | 27 dock-finder-left, 95 drag-calendar-while-paused |
| 4 | the window you switch to comes to the front and into view | 75 | 6 | 18 dock-icon-terminal, 36 drag-gap-beside-finder, 37 grow-finder, 38 shrink-finder, 39 balance, 89 reach-calendar |
| 5 | quitting, Float All and pause give windows their own sizes back | 5 | 4 | 94 pause, 97 float-all, 103 quit, 115 quit-2 |
| L | no window is lost or stuck | 101 | 1 | 113 launch-2 |
| - | what the script itself checked | 101 | 6 | 14 leave-alone, 23 dock-icon-mail, 48 dock-icon-mail-2, 90 drag-calendar-to-top, 91 drag-calendar-back, 112 dock-icon-mail-3 |

## Findings

### Rule 2: nothing moves that the person did not move

- ~ **27 dock-finder-left** (presses ⌃⌥⌘←): w191 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +3247 ms 930,179 470×416
- ~ **29 dock-safari-right** (presses ⌃⌥⌘→): w191 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 930,179 470×416 · +1362 ms 537,179 470×416
- ~ **33 drag-terminal-onto-finder** (drags terminal by its title bar onto the right part of finder and lets go): w191 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 537,179 470×416 · +4619 ms 322,179 470×416
- ✘ **37 grow-finder** (presses ⌃⌥⌘=): terminal (w112) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 97,238 877×499 · +218 ms 76,216 919×544
- ✘ **38 shrink-finder** (presses ⌃⌥⌘-): terminal (w112) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 76,216 919×544 · +317 ms 97,239 877×499
- ✘ **55 show-everything** (presses ⌃⌥Space): notes (w115) is not back where it was after step 50: 300,105 1000×660, it was at 202,105 709×660 [moved-unasked]
- ✘ **55 show-everything** (presses ⌃⌥Space): calendar (w121) is not back where it was after step 50: 404,115 936×599, it was at 217,115 680×599 [moved-unasked]
- ✘ **55 show-everything** (presses ⌃⌥Space): settings (w124) is not back where it was after step 50: 437,85 723×625, it was at 195,85 723×625 [moved-unasked]
- ✘ **55 show-everything** (presses ⌃⌥Space): preview (w128) is not back where it was after step 50: 4,35 708×424, it was at 203,35 708×424 [moved-unasked]
- ✘ **55 show-everything** (presses ⌃⌥Space): w189 of Mail is not back where it was after step 50: 240,72 1120×630, it was at 121,72 871×630 [moved-unasked]
- ✘ **55 show-everything** (presses ⌃⌥Space): w191 of Mail is not back where it was after step 50: 565,179 470×416, it was at 322,179 470×416 [moved-unasked]
- ✘ **62 show-everything-2** (presses ⌃⌥Space): notes (w115) is not back where it was after step 50: 300,105 1000×660, it was at 202,105 709×660 [moved-unasked]
- ✘ **62 show-everything-2** (presses ⌃⌥Space): calendar (w121) is not back where it was after step 50: 404,115 936×599, it was at 217,115 680×599 [moved-unasked]
- ✘ **62 show-everything-2** (presses ⌃⌥Space): settings (w124) is not back where it was after step 50: 437,85 723×625, it was at 195,85 723×625 [moved-unasked]
- ✘ **62 show-everything-2** (presses ⌃⌥Space): preview (w128) is not back where it was after step 50: 4,35 708×424, it was at 203,35 708×424 [moved-unasked]
- ✘ **62 show-everything-2** (presses ⌃⌥Space): w189 of Mail is not back where it was after step 50: 240,72 1120×630, it was at 121,72 871×630 [moved-unasked]
- ✘ **62 show-everything-2** (presses ⌃⌥Space): w191 of Mail is not back where it was after step 50: 565,179 470×416, it was at 322,179 470×416 [moved-unasked]
- ✘ **74 minimize-safari** (presses ⌘M): terminal (w112) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 97,239 877×499 · +1724 ms 525,239 331×499
- ✘ **74 minimize-safari** (presses ⌘M): notes (w115) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +1724 ms 337,105 709×660
- ✘ **74 minimize-safari** (presses ⌘M): calendar (w121) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 404,115 936×599 · +1724 ms 352,115 680×599
- ✘ **74 minimize-safari** (presses ⌘M): settings (w124) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +1724 ms 330,85 723×625
- ✘ **74 minimize-safari** (presses ⌘M): preview (w128) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +1724 ms 338,35 708×424
- ✘ **74 minimize-safari** (presses ⌘M): w189 of Mail a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1724 ms 256,72 871×630
- ~ **74 minimize-safari** (presses ⌘M): w191 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1724 ms 457,179 470×416
- ✘ **75 restore-safari** (clicks its miniature in the Dock): terminal (w112) is not back where it was after step 73: 525,239 331×499, it was at 97,239 877×499 [moved-unasked]
- ✘ **75 restore-safari** (clicks its miniature in the Dock): notes (w115) is not back where it was after step 73: 337,105 709×660, it was at 300,105 1000×660 [moved-unasked]
- ✘ **75 restore-safari** (clicks its miniature in the Dock): calendar (w121) is not back where it was after step 73: 352,115 680×599, it was at 404,115 936×599 [moved-unasked]
- ✘ **75 restore-safari** (clicks its miniature in the Dock): settings (w124) is not back where it was after step 73: 330,85 723×625, it was at 437,85 723×625 [moved-unasked]
- ✘ **75 restore-safari** (clicks its miniature in the Dock): preview (w128) is not back where it was after step 73: 338,35 708×424, it was at 4,35 708×424 [moved-unasked]
- ✘ **75 restore-safari** (clicks its miniature in the Dock): w189 of Mail is not back where it was after step 73: 256,72 871×630, it was at 240,72 1120×630 [moved-unasked]
- ✘ **75 restore-safari** (clicks its miniature in the Dock): w191 of Mail is not back where it was after step 73: 457,179 470×416, it was at 565,179 470×416 [moved-unasked]
- ✘ **77 hide-finder** (presses ⌘H): terminal (w112) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 525,239 331×499 · +323 ms 525,239 415×499 · +352 ms 0,239 415×499
- ✘ **77 hide-finder** (presses ⌘H): notes (w115) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 337,105 709×660 · +352 ms 0,105 709×660
- ✘ **77 hide-finder** (presses ⌘H): calendar (w121) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 352,115 680×599 · +352 ms 0,115 680×599
- ✘ **77 hide-finder** (presses ⌘H): settings (w124) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 330,85 723×625 · +362 ms 0,85 723×625
- ✘ **77 hide-finder** (presses ⌘H): preview (w128) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 338,35 708×424 · +389 ms 0,35 708×424
- ✘ **77 hide-finder** (presses ⌘H): w189 of Mail a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 256,72 871×630 · +389 ms 0,72 871×630
- ~ **77 hide-finder** (presses ⌘H): w191 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 457,179 470×416 · +389 ms 201,179 470×416
- ✘ **78 unhide-finder** (clicks its icon in the Dock): terminal (w112) is not back where it was after step 76: 0,239 415×499, it was at 525,239 331×499 [moved-unasked]
- ✘ **78 unhide-finder** (clicks its icon in the Dock): notes (w115) is not back where it was after step 76: 0,105 709×660, it was at 337,105 709×660 [moved-unasked]
- ✘ **78 unhide-finder** (clicks its icon in the Dock): calendar (w121) is not back where it was after step 76: 0,115 680×599, it was at 352,115 680×599 [moved-unasked]
- ✘ **78 unhide-finder** (clicks its icon in the Dock): settings (w124) is not back where it was after step 76: 0,85 723×625, it was at 330,85 723×625 [moved-unasked]
- ✘ **78 unhide-finder** (clicks its icon in the Dock): preview (w128) is not back where it was after step 76: 0,35 708×424, it was at 338,35 708×424 [moved-unasked]
- ✘ **78 unhide-finder** (clicks its icon in the Dock): w189 of Mail is not back where it was after step 76: 0,72 871×630, it was at 256,72 871×630 [moved-unasked]
- ✘ **78 unhide-finder** (clicks its icon in the Dock): w191 of Mail is not back where it was after step 76: 201,179 470×416, it was at 457,179 470×416 [moved-unasked]
- ✘ **80 quit-textedit** (presses ⌘Q in TextEdit): terminal (w112) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,239 415×499 · +951 ms 525,239 478×499
- ✘ **80 quit-textedit** (presses ⌘Q in TextEdit): notes (w115) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,105 709×660 · +951 ms 409,105 709×660
- ✘ **80 quit-textedit** (presses ⌘Q in TextEdit): calendar (w121) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,115 680×599 · +951 ms 423,115 680×599
- ✘ **80 quit-textedit** (presses ⌘Q in TextEdit): settings (w124) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,85 723×625 · +951 ms 402,85 723×625
- ✘ **80 quit-textedit** (presses ⌘Q in TextEdit): preview (w128) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,35 708×424 · +951 ms 409,35 708×424
- ✘ **80 quit-textedit** (presses ⌘Q in TextEdit): w189 of Mail a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,72 871×630 · +951 ms 328,72 871×630
- ~ **80 quit-textedit** (presses ⌘Q in TextEdit): w191 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 201,179 470×416 · +951 ms 529,179 470×416
- ✘ **84 leave-full-screen** (presses ⌃⌘F again): textedit (w286) is not back where it was after step 82: 525,65 477×439, it was at 165,65 673×439 [moved-unasked]
- ✘ **95 drag-calendar-while-paused** (moves calendar a little while Arbor is paused): safari (w98) moved, and the step did not name it [moved-unasked]
  - +0 ms 1014,43 574×767 · +911 ms 1003,43 585×767 · +1277 ms 958,43 630×767 · +1323 ms 951,43 637×767 · +1437 ms 939,43 649×767 · +1509 ms 933,43 655×767 · … 12 more … · +2471 ms 845,43 743×767 · +2598 ms 832,43 756×767 · +2670 ms 826,43 762×767 · +2994 ms 827,43 761×767 · +3088 ms 826,43 762×767
- ~ **99 dock-finder-left-2** (presses ⌃⌥⌘←): w191 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +833 ms 930,179 470×416
- ~ **101 dock-safari-right-2** (presses ⌃⌥⌘→): w191 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 930,179 470×416 · +1135 ms 537,179 470×416
- ✘ **113 launch-2** (starts Arbor again): terminal (w112) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 97,239 877×499 · +551 ms 1599,790 877×499
- ✘ **113 launch-2** (starts Arbor again): notes (w115) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms -1,32 800×791 · +585 ms 1599,770 800×791
- ✘ **113 launch-2** (starts Arbor again): calendar (w121) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 404,115 936×599 · +614 ms 1599,770 936×599
- ✘ **113 launch-2** (starts Arbor again): settings (w124) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +614 ms 1599,770 723×625
- ✘ **113 launch-2** (starts Arbor again): preview (w128) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +614 ms 1599,770 708×424
- ✘ **113 launch-2** (starts Arbor again): w189 of Mail a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +614 ms 1599,770 1120×630
- ~ **113 launch-2** (starts Arbor again): w191 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +614 ms 1924,877 470×416
- ✘ **113 launch-2** (starts Arbor again): textedit (w286) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +614 ms 1599,790 673×439

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **27 dock-finder-left** (presses ⌃⌥⌘←): finder (w95) was still moving 407 ms after everything had been quiet for a second [jolt]
- ~ **27 dock-finder-left** (presses ⌃⌥⌘←): safari (w98) was still moving 407 ms after everything had been quiet for a second [jolt]
- ~ **27 dock-finder-left** (presses ⌃⌥⌘←): textedit (w109) was still moving 407 ms after everything had been quiet for a second [jolt]
- ~ **27 dock-finder-left** (presses ⌃⌥⌘←): terminal (w112) was still moving 407 ms after everything had been quiet for a second [jolt]
- ~ **27 dock-finder-left** (presses ⌃⌥⌘←): notes (w115) was still moving 407 ms after everything had been quiet for a second [jolt]
- ~ **27 dock-finder-left** (presses ⌃⌥⌘←): calendar (w121) was still moving 407 ms after everything had been quiet for a second [jolt]
- ~ **27 dock-finder-left** (presses ⌃⌥⌘←): settings (w124) was still moving 407 ms after everything had been quiet for a second [jolt]
- ~ **27 dock-finder-left** (presses ⌃⌥⌘←): preview (w128) was still moving 407 ms after everything had been quiet for a second [jolt]
- ~ **27 dock-finder-left** (presses ⌃⌥⌘←): w189 of Mail was still moving 407 ms after everything had been quiet for a second [jolt]
- ~ **27 dock-finder-left** (presses ⌃⌥⌘←): w191 of Mail was still moving 407 ms after everything had been quiet for a second [jolt]
- ✘ **27 dock-finder-left** (presses ⌃⌥⌘←): the last window came to rest 2928 ms after the key or the button [slow]
- ~ **29 dock-safari-right** (presses ⌃⌥⌘→): the last window came to rest 1063 ms after the key or the button [slow]
- ~ **33 drag-terminal-onto-finder** (drags terminal by its title bar onto the right part of finder and lets go): the last window came to rest 1037 ms after the key or the button [slow]
- ~ **34 drag-terminal-out** (drags terminal out of the arrangement onto the Desktop and lets go): the last window came to rest 726 ms after the key or the button [slow]
- ~ **51 frame-finder** (presses ⌃⌥↩): the last window came to rest 910 ms after the key or the button [slow]
- ~ **58 neighbour-left** (presses ⌃⌥←): the last window came to rest 702 ms after the key or the button [slow]
- ~ **62 show-everything-2** (presses ⌃⌥Space): the last window came to rest 735 ms after the key or the button [slow]
- ~ **72 show-everything-3** (presses ⌃⌥Space): the last window came to rest 711 ms after the key or the button [slow]
- ✘ **95 drag-calendar-while-paused** (moves calendar a little while Arbor is paused): safari (w98) moved 3 times [jolt]
  - +0 ms 1014,43 574×767 · +911 ms 1003,43 585×767 · +1277 ms 958,43 630×767 · +1323 ms 951,43 637×767 · +1437 ms 939,43 649×767 · +1509 ms 933,43 655×767 · … 12 more … · +2471 ms 845,43 743×767 · +2598 ms 832,43 756×767 · +2670 ms 826,43 762×767 · +2994 ms 827,43 761×767 · +3088 ms 826,43 762×767
- ~ **101 dock-safari-right-2** (presses ⌃⌥⌘→): the last window came to rest 915 ms after the key or the button [slow]
- ~ **103 quit** (chooses Quit Arbor in Arbor's menu): w191 of Mail went 248 points out of its way before it ended up [jolt]
  - +0 ms 1800,877 470×416 · +2563 ms 1924,877 470×416 · +2596 ms 565,179 470×416

### Rule 4: the window you switch to comes to the front and into view

- ✘ **18 dock-icon-terminal** (clicks terminal's icon in the Dock): terminal (w112) is not wholly in view: 98% of it, at 740,300 877×499 in 0,31 1600×791 [focus]
- ✘ **36 drag-gap-beside-finder** (drags the gap to the right of finder sixty points to the right): the app in front changed (to process 14828), and nobody switched [focus]
- ✘ **37 grow-finder** (presses ⌃⌥⌘=): finder (w95) is not in front: terminal (w112) ahead of it, of which 1 cover part of it [behind]
- ✘ **37 grow-finder** (presses ⌃⌥⌘=): finder (w95) its app is not the one in front (process 14828 is) [focus]
- ✘ **38 shrink-finder** (presses ⌃⌥⌘-): finder (w95) is not in front: terminal (w112) ahead of it, of which 1 cover part of it [behind]
- ✘ **38 shrink-finder** (presses ⌃⌥⌘-): finder (w95) its app is not the one in front (process 14828 is) [focus]
- ✘ **39 balance** (presses ⌃⌥⌘0): finder (w95) is not in front: terminal (w112) ahead of it, of which 1 cover part of it [behind]
- ✘ **39 balance** (presses ⌃⌥⌘0): finder (w95) its app is not the one in front (process 14828 is) [focus]
- ✘ **89 reach-calendar** (clicks calendar's title bar, or its Dock icon if that is covered): calendar (w121) is not in front: safari (w98), notes (w115), textedit (w286), finder (w95) ahead of it, of which 4 cover part of it [behind]
- ✘ **89 reach-calendar** (clicks calendar's title bar, or its Dock icon if that is covered): calendar (w121) its app is not the one in front (process 14544 is) [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **94 pause** (presses ⌃⌥⎋): finder (w95) is 12,43 501×767; its own size was 340,120 920×436 [size-lost]
- ✘ **94 pause** (presses ⌃⌥⎋): safari (w98) is 1014,43 574×767; its own size was 138,31 1324×791 [size-lost]
- ✘ **94 pause** (presses ⌃⌥⎋): terminal (w112) is 525,239 478×499; its own size was 97,238 877×499 [size-lost]
- ✘ **94 pause** (presses ⌃⌥⎋): calendar (w121) is 423,115 680×599; its own size was 423,115 936×599 [size-lost]
- ✘ **94 pause** (presses ⌃⌥⎋): w189 of Mail is 328,72 871×630; its own size was 240,72 1120×630 [size-lost]
- ✘ **94 pause** (presses ⌃⌥⎋): textedit (w286) is 525,65 477×439; its own size was 165,65 673×439 [size-lost]
- ✘ **97 float-all** (presses ⌃⌥⇧F): calendar (w121) has its size back but not its place: 404,115 936×599, it was at 423,115 936×599 [size-lost]
- ✘ **103 quit** (chooses Quit Arbor in Arbor's menu): calendar (w121) has its size back but not its place: 404,115 936×599, it was at 423,115 936×599 [size-lost]
- ✘ **115 quit-2** (quits Arbor): calendar (w121) has its size back but not its place: 404,115 936×599, it was at 423,115 936×599 [size-lost]

### Rule L: no window is lost or stuck

- ✘ **113 launch-2** (starts Arbor again): finder (w95) is out of view: 0% of it is on the display, at 1599,770 920×436 [lost]
- ✘ **113 launch-2** (starts Arbor again): terminal (w112) is out of view: 0% of it is on the display, at 1599,790 877×499 [lost]
- ✘ **113 launch-2** (starts Arbor again): notes (w115) is out of view: 0% of it is on the display, at 1599,770 800×791 [lost]
- ✘ **113 launch-2** (starts Arbor again): calendar (w121) is out of view: 0% of it is on the display, at 1599,770 936×599 [lost]
- ✘ **113 launch-2** (starts Arbor again): settings (w124) is out of view: 0% of it is on the display, at 1599,770 723×625 [lost]
- ✘ **113 launch-2** (starts Arbor again): preview (w128) is out of view: 0% of it is on the display, at 1599,770 708×424 [lost]
- ✘ **113 launch-2** (starts Arbor again): textedit (w286) is out of view: 0% of it is on the display, at 1599,790 673×439 [lost]

### Rule -: what the script itself checked

- ✘ **14 leave-alone** (does nothing for half a minute): with nothing to do Arbor used 1.6 % of a core [busy]
- ✘ **23 dock-icon-mail** (clicks mail's icon in the Dock): the script could not tell which window front is about [script]
- ~ **31 dock-textedit-right** (presses ⌃⌥⌘→): floating w115 and docked w98 overlap by 414×660 [script]
- ~ **31 dock-textedit-right** (presses ⌃⌥⌘→): floating w121 and docked w98 overlap by 399×599 [script]
- ~ **31 dock-textedit-right** (presses ⌃⌥⌘→): floating w124 and docked w98 overlap by 421×625 [script]
- ~ **31 dock-textedit-right** (presses ⌃⌥⌘→): floating w189 and docked w98 overlap by 495×630 [script]
- ~ **33 drag-terminal-onto-finder** (drags terminal by its title bar onto the right part of finder and lets go): floating w115 and docked w112 overlap by 188×660 [script]
- ~ **33 drag-terminal-onto-finder** (drags terminal by its title bar onto the right part of finder and lets go): floating w121 and docked w112 overlap by 173×599 [script]
- ~ **33 drag-terminal-onto-finder** (drags terminal by its title bar onto the right part of finder and lets go): floating w124 and docked w112 overlap by 195×625 [script]
- ~ **33 drag-terminal-onto-finder** (drags terminal by its title bar onto the right part of finder and lets go): floating w189 and docked w112 overlap by 240×630 [script]
- ~ **34 drag-terminal-out** (drags terminal out of the arrangement onto the Desktop and lets go): floating w112 and docked w95 overlap by 416×499 [script]
- ~ **34 drag-terminal-out** (drags terminal out of the arrangement onto the Desktop and lets go): floating w115 and docked w95 overlap by 311×660 [script]
- ~ **34 drag-terminal-out** (drags terminal out of the arrangement onto the Desktop and lets go): floating w124 and docked w95 overlap by 318×625 [script]
- ~ **34 drag-terminal-out** (drags terminal out of the arrangement onto the Desktop and lets go): floating w189 and docked w95 overlap by 392×630 [script]
- ~ **34 drag-terminal-out** (drags terminal out of the arrangement onto the Desktop and lets go): floating w189 and docked w98 overlap by 375×630 [script]
- ~ **37 grow-finder** (presses ⌃⌥⌘=): floating w112 and docked w95 overlap by 437×544 [script]
- ~ **38 shrink-finder** (presses ⌃⌥⌘-): floating w112 and docked w95 overlap by 416×499 [script]
- ✘ **48 dock-icon-mail-2** (clicks mail's icon in the Dock): the script could not tell which window front is about [script]
- ~ **55 show-everything** (presses ⌃⌥Space): floating w112 and docked w95 overlap by 416×499 [script]
- ~ **55 show-everything** (presses ⌃⌥Space): floating w115 and docked w98 overlap by 574×660 [script]
- ~ **55 show-everything** (presses ⌃⌥Space): floating w121 and docked w98 overlap by 574×599 [script]
- ~ **55 show-everything** (presses ⌃⌥Space): floating w124 and docked w98 overlap by 543×625 [script]
- ~ **55 show-everything** (presses ⌃⌥Space): floating w128 and docked w95 overlap by 501×416 [script]
- ~ **55 show-everything** (presses ⌃⌥Space): floating w189 and docked w98 overlap by 574×630 [script]
- ~ **60 step-out** (presses ⌃⌥↑): floating w112 and docked w95 overlap by 416×499 [script]
- ~ **60 step-out** (presses ⌃⌥↑): floating w115 and docked w98 overlap by 574×660 [script]
- ~ **60 step-out** (presses ⌃⌥↑): floating w121 and docked w98 overlap by 574×599 [script]
- ~ **60 step-out** (presses ⌃⌥↑): floating w124 and docked w98 overlap by 543×625 [script]
- ~ **60 step-out** (presses ⌃⌥↑): floating w128 and docked w95 overlap by 501×416 [script]
- ~ **60 step-out** (presses ⌃⌥↑): floating w189 and docked w98 overlap by 574×630 [script]
- ~ **62 show-everything-2** (presses ⌃⌥Space): floating w112 and docked w95 overlap by 416×499 [script]
- ~ **62 show-everything-2** (presses ⌃⌥Space): floating w115 and docked w98 overlap by 574×660 [script]
- ~ **62 show-everything-2** (presses ⌃⌥Space): floating w121 and docked w98 overlap by 574×599 [script]
- ~ **62 show-everything-2** (presses ⌃⌥Space): floating w124 and docked w98 overlap by 543×625 [script]
- ~ **62 show-everything-2** (presses ⌃⌥Space): floating w128 and docked w95 overlap by 501×416 [script]
- ~ **62 show-everything-2** (presses ⌃⌥Space): floating w189 and docked w98 overlap by 574×630 [script]
- ~ **64 new-window** (presses ⌘N in Safari): floating w254 and docked w98 overlap by 545×755 [script]
- ~ **70 new-window-while-framed** (presses ⌘N in Safari while its window is framed): floating w265 and docked w98 overlap by 1564×755 [script]
- ~ **72 show-everything-3** (presses ⌃⌥Space): floating w112 and docked w95 overlap by 416×499 [script]
- ~ **72 show-everything-3** (presses ⌃⌥Space): floating w115 and docked w98 overlap by 574×660 [script]
- ~ **72 show-everything-3** (presses ⌃⌥Space): floating w121 and docked w98 overlap by 574×599 [script]
- ~ **72 show-everything-3** (presses ⌃⌥Space): floating w124 and docked w98 overlap by 543×625 [script]
- ~ **72 show-everything-3** (presses ⌃⌥Space): floating w128 and docked w95 overlap by 501×416 [script]
- ~ **72 show-everything-3** (presses ⌃⌥Space): floating w189 and docked w98 overlap by 574×630 [script]
- ~ **75 restore-safari** (clicks its miniature in the Dock): floating w115 and docked w98 overlap by 429×660 [script]
- ~ **75 restore-safari** (clicks its miniature in the Dock): floating w121 and docked w98 overlap by 415×599 [script]
- ~ **75 restore-safari** (clicks its miniature in the Dock): floating w124 and docked w98 overlap by 436×625 [script]
- ~ **75 restore-safari** (clicks its miniature in the Dock): floating w189 and docked w98 overlap by 510×630 [script]
- ~ **77 hide-finder** (presses ⌘H): floating w189 and docked w98 overlap by 444×630 [script]
- ~ **78 unhide-finder** (clicks its icon in the Dock): floating w112 and docked w95 overlap by 403×499 [script]
- ~ **78 unhide-finder** (clicks its icon in the Dock): floating w115 and docked w95 overlap by 501×660 [script]
- ~ **78 unhide-finder** (clicks its icon in the Dock): floating w121 and docked w95 overlap by 501×599 [script]
- ~ **78 unhide-finder** (clicks its icon in the Dock): floating w124 and docked w95 overlap by 501×625 [script]
- ~ **78 unhide-finder** (clicks its icon in the Dock): floating w128 and docked w95 overlap by 501×416 [script]
- ~ **78 unhide-finder** (clicks its icon in the Dock): floating w189 and docked w95 overlap by 501×630 [script]
- ~ **88 drag-notes-to-left-edge** (drags notes by its title bar against the left edge of the screen and lets go): floating w115 and docked w95 overlap by 501×767 [script]
- ✘ **90 drag-calendar-to-top** (drags calendar by its title bar against the menu bar and lets go: macOS fills the screen with it): the act was not performed: drag_window could not be done [script]
- ✘ **91 drag-calendar-back** (drags calendar away from the top again, a hand's breadth down): the act was not performed: drag_window could not be done [script]
- ~ **96 resume** (presses ⌃⌥⎋): floating w115 and docked w95 overlap by 501×767 [script]
- ✘ **112 dock-icon-mail-3** (clicks mail's icon in the Dock): the script could not tell which window front is about [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (3, 87 ms) | quiet 1000 ms; blind for 70 ms |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 442 ms; blind for 4596 ms |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (5, 316 ms) | quiet 1230 ms; blind for 538 ms |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (4, 280 ms) | quiet 1209 ms; blind for 74 ms |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (5, 108 ms), w116 ×2 (17, 1275 ms), w118 ×2 (11, 1139 ms) | quiet 368 ms; blind for 257 ms |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (7, 363 ms) | quiet 1345 ms; blind for 72 ms |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×2 (2, 353 ms) | quiet 690 ms; blind for 352 ms |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview |  | quiet 932 ms; blind for 113 ms |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | mail ×1 (2, 35 ms), w132 ×1 (2, 239 ms) | quiet 394 ms; blind for 1971 ms |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags calendar by its title bar against the menu bar and lets go | calendar ×3 (46, 4013 ms) | quiet 1424 ms; blind for 82 ms |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (32, 2309 ms) | quiet 1026 ms; blind for 76 ms |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 350 ms; blind for 72 ms |  |  |  |  |  |  |  |

### Arbor starts

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 13 | launch | starts Arbor |  | quiet 858 ms; blind for 75 ms |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 14 | leave-alone | does nothing for half a minute |  | quiet 417 ms; blind for 82 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✘ |

### Switching between apps, nothing docked yet

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 15 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 422 ms; blind for 162 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 16 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 402 ms; blind for 251 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 17 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 404 ms; blind for 118 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 18 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 414 ms; blind for 72 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ |
| 19 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 390 ms; blind for 88 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 20 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 388 ms; blind for 116 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 21 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 652 ms; blind for 75 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 22 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 391 ms; blind for 125 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 23 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 1628 ms; blind for 194 ms |  | ✔ | ✔ |  |  | ✔ | ✘ |
| 24 | cmd-tab | presses ⌘Tab |  | quiet 362 ms; blind for 128 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 25 | cmd-tab-twice | holds ⌘ and presses Tab twice |  | quiet 354 ms; blind for 148 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |

### The first docks, by key

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 26 | reach-finder | clicks finder's title bar, or its Dock icon if that is covered |  | quiet 470 ms; blind for 90 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 27 | dock-finder-left | presses ⌃⌥⌘← | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms) | quiet 603 ms; blind for 270 ms |  | ~ | ✘ | ✔ |  | ✔ | ✔ |
| 28 | reach-safari | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 665 ms; blind for 114 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 29 | dock-safari-right | presses ⌃⌥⌘→ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms) | quiet 1236 ms; blind for 76 ms |  | ~ | ~ | ✔ |  | ✔ | ✔ |
| 30 | reach-textedit | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 365 ms; blind for 97 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 31 | dock-textedit-right | presses ⌃⌥⌘→ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 686 ms; blind for 76 ms |  | ✔ | ✔ | ✔ |  | ✔ | ~ |

### Docking by real drags

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 32 | reach-terminal | clicks terminal's title bar, or its Dock icon if that is covered |  | quiet 530 ms; blind for 77 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 33 | drag-terminal-onto-finder | drags terminal by its title bar onto the right part of finder and lets go | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms) | quiet 939 ms; blind for 80 ms | ✔ | ~ | ~ | ✔ |  | ✔ | ~ |
| 34 | drag-terminal-out | drags terminal out of the arrangement onto the Desktop and lets go | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms) | quiet 1053 ms; blind for 77 ms | ✔ | ✔ | ~ | ✔ | ✔ | ✔ | ~ |

### Sizes

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 35 | reach-finder | clicks finder's title bar, or its Dock icon if that is covered |  | quiet 369 ms; blind for 161 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 36 | drag-gap-beside-finder | drags the gap to the right of finder sixty points to the right |  | quiet 1040 ms; blind for 81 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ |
| 37 | grow-finder | presses ⌃⌥⌘= | terminal ×1 (1, 0 ms) | quiet 712 ms; blind for 72 ms |  | ✘ | ✔ | ✘ |  | ✔ | ~ |
| 38 | shrink-finder | presses ⌃⌥⌘- | terminal ×1 (1, 0 ms) | quiet 591 ms; blind for 76 ms |  | ✘ | ✔ | ✘ |  | ✔ | ~ |
| 39 | balance | presses ⌃⌥⌘0 |  | quiet 563 ms; blind for 61 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ |

### Switching between apps, with an arrangement

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 40 | dock-icon-finder-2 | clicks finder's icon in the Dock |  | quiet 430 ms; blind for 140 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 41 | dock-icon-safari-2 | clicks safari's icon in the Dock |  | quiet 414 ms; blind for 75 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 42 | dock-icon-textedit-2 | clicks textedit's icon in the Dock |  | quiet 586 ms; blind for 68 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 43 | dock-icon-terminal-2 | clicks terminal's icon in the Dock |  | quiet 514 ms; blind for 63 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 44 | dock-icon-notes-2 | clicks notes's icon in the Dock |  | quiet 415 ms; blind for 73 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 45 | dock-icon-calendar-2 | clicks calendar's icon in the Dock |  | quiet 431 ms; blind for 71 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 46 | dock-icon-settings-2 | clicks settings's icon in the Dock |  | quiet 703 ms; blind for 94 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 47 | dock-icon-preview-2 | clicks preview's icon in the Dock |  | quiet 410 ms; blind for 90 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 48 | dock-icon-mail-2 | clicks mail's icon in the Dock |  | quiet 512 ms; blind for 74 ms |  | ✔ | ✔ |  |  | ✔ | ✘ |
| 49 | cmd-tab-2 | presses ⌘Tab |  | quiet 468 ms; blind for 104 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |

### The view goes in and out

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 50 | reach-finder | clicks finder's title bar, or its Dock icon if that is covered |  | quiet 414 ms; blind for 85 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 51 | frame-finder | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms) | quiet 1347 ms; blind for 94 ms |  |  | ~ | ✔ |  | ✔ | ✔ |
| 52 | dock-icon-safari-while-framed | clicks safari's icon in the Dock, whose window is out of view | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 628 ms; blind for 166 ms |  |  | ✔ | ✔ |  | ✔ | ✔ |
| 53 | cmd-tab-while-framed | presses ⌘Tab, back to finder | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 1172 ms; blind for 77 ms |  |  | ✔ | ✔ |  | ✔ | ✔ |
| 54 | dock-icon-calendar-while-framed | clicks calendar's icon in the Dock, whose window floats and is out of view | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms) | quiet 832 ms; blind for 66 ms |  |  | ✔ | ✔ |  | ✔ | ✔ |
| 55 | show-everything | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 809 ms; blind for 71 ms |  | ✘ | ✔ |  |  | ✔ | ~ |
| 56 | reach-safari | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 385 ms; blind for 73 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 57 | frame-safari | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms) | quiet 1019 ms; blind for 73 ms |  |  | ✔ | ✔ |  | ✔ | ✔ |
| 58 | neighbour-left | presses ⌃⌥← | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms) | quiet 883 ms; blind for 89 ms |  |  | ~ |  |  | ✔ | ✔ |
| 59 | back | presses ⌃⌥[ | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms) | quiet 827 ms; blind for 77 ms |  |  | ✔ | ✔ |  | ✔ | ✔ |
| 60 | step-out | presses ⌃⌥↑ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms) | quiet 791 ms; blind for 65 ms |  |  | ✔ |  |  | ✔ | ~ |
| 61 | show-desktop | presses ⌃⌥D | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 961 ms; blind for 85 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 62 | show-everything-2 | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 712 ms; blind for 76 ms |  | ✘ | ~ |  |  | ✔ | ~ |

### Windows come and go

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 63 | reach-safari | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 620 ms; blind for 75 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 64 | new-window | presses ⌘N in Safari |  | quiet 351 ms; blind for 907 ms |  | ✔ | ✔ | ✔ |  | ✔ | ~ |
| 65 | window-menu | chooses Safari's first window in the Window menu |  | quiet 1383 ms; blind for 76 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 66 | cmd-backtick | presses ⌘` for Safari's other window |  | quiet 848 ms; blind for 66 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 67 | close-window | presses ⌘W |  | quiet 1063 ms; blind for 74 ms |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 68 | reach-safari | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 414 ms; blind for 75 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 69 | frame-safari | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms) | quiet 1144 ms; blind for 76 ms |  |  | ✔ | ✔ |  | ✔ | ✔ |
| 70 | new-window-while-framed | presses ⌘N in Safari while its window is framed |  | quiet 998 ms; blind for 122 ms |  |  | ✔ | ✔ |  | ✔ | ~ |
| 71 | close-window-while-framed | presses ⌘W |  | quiet 1030 ms; blind for 74 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 72 | show-everything-3 | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms) | quiet 994 ms; blind for 68 ms |  | ✔ | ~ |  |  | ✔ | ~ |
| 73 | reach-safari | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 401 ms; blind for 79 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 74 | minimize-safari | presses ⌘M | safari ×1 (15, 488 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms) | quiet 2102 ms; blind for 99 ms |  | ✘ | ✔ |  |  | ✔ | ✔ |
| 75 | restore-safari | clicks its miniature in the Dock | safari ×1 (20, 485 ms), textedit ×1 (1, 0 ms) | quiet 1160 ms; blind for 69 ms |  | ✘ | ✔ | ✔ |  | ✔ | ~ |
| 76 | reach-finder | clicks finder's title bar, or its Dock icon if that is covered |  | quiet 353 ms; blind for 74 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 77 | hide-finder | presses ⌘H | safari ×1 (1, 0 ms), textedit ×1 (2, 11 ms), terminal ×1 (2, 29 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms) | quiet 1129 ms; blind for 85 ms |  | ✘ | ✔ |  |  | ✔ | ~ |
| 78 | unhide-finder | clicks its icon in the Dock | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 528 ms; blind for 70 ms |  | ✘ | ✔ | ✔ |  | ✔ | ~ |
| 79 | reach-textedit | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 463 ms; blind for 67 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 80 | quit-textedit | presses ⌘Q in TextEdit | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms) | quiet 1099 ms; blind for 77 ms |  | ✘ | ✔ |  |  | ✔ | ✔ |
| 81 | reopen-textedit | opens the document again |  | quiet 1198 ms; blind for 322 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |

### Full screen

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 82 | reach-safari | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 519 ms; blind for 85 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 83 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (2, 31 ms), calendar ×1 (2, 92 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 357 ms; blind for 135 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 84 | leave-full-screen | presses ⌃⌘F again | safari ×1 (2, 72 ms), terminal ×1 (1, 0 ms), notes ×1 (2, 41 ms), calendar ×1 (2, 8 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 354 ms; blind for 144 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |

### A click lands on the wallpaper

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 85 | click-wallpaper | clicks on the wallpaper: macOS sweeps every window aside | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 442 ms; blind for 184 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 86 | click-wallpaper-again | clicks on the wallpaper again: macOS brings them back | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 365 ms; blind for 65 ms |  | ✔ | ✔ |  |  | ✔ | ✔ |

### Where macOS tiles too

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 87 | reach-notes | clicks notes's title bar, or its Dock icon if that is covered |  | quiet 503 ms; blind for 67 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 88 | drag-notes-to-left-edge | drags notes by its title bar against the left edge of the screen and lets go | notes ×1 (9, 339 ms) | quiet 402 ms; blind for 79 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ~ |
| 89 | reach-calendar | clicks calendar's title bar, or its Dock icon if that is covered |  | quiet 352 ms; blind for 128 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ |
| 90 | drag-calendar-to-top | drags calendar by its title bar against the menu bar and lets go: macOS fills the screen with it |  | quiet 407 ms; blind for 73 ms |  |  |  |  |  |  | ✘ |
| 91 | drag-calendar-back | drags calendar away from the top again, a hand's breadth down |  | quiet 357 ms; blind for 73 ms |  |  |  |  |  |  | ✘ |
| 92 | show-everything-4 | presses ⌃⌥Space |  | quiet 634 ms; blind for 78 ms |  |  | ✔ |  |  | ✔ | ✔ |

### The ways out

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 93 | reach-safari | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 353 ms; blind for 70 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 94 | pause | presses ⌃⌥⎋ |  | quiet 722 ms; blind for 78 ms |  |  | ✔ |  | ✘ | ✔ | ✔ |
| 95 | drag-calendar-while-paused | moves calendar a little while Arbor is paused | safari ×3 (22, 2177 ms) | quiet 1104 ms; blind for 77 ms | ✔ | ✘ | ✘ |  |  | ✔ | ✔ |
| 96 | resume | presses ⌃⌥⎋ | safari ×1 (1, 0 ms) | quiet 815 ms; blind for 74 ms |  |  | ✔ |  |  | ✔ | ~ |
| 97 | float-all | presses ⌃⌥⇧F | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1088 ms; blind for 75 ms |  |  | ✔ |  | ✘ | ✔ | ✔ |
| 98 | reach-finder | clicks finder's title bar, or its Dock icon if that is covered |  | quiet 474 ms; blind for 120 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 99 | dock-finder-left-2 | presses ⌃⌥⌘← | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1107 ms; blind for 71 ms |  | ~ | ✔ | ✔ |  | ✔ | ✔ |
| 100 | reach-safari | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 360 ms; blind for 101 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 101 | dock-safari-right-2 | presses ⌃⌥⌘→ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1021 ms; blind for 75 ms |  | ~ | ~ | ✔ |  | ✔ | ✔ |
| 102 | frame-safari-2 | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 898 ms; blind for 78 ms |  |  | ✔ | ✔ |  | ✔ | ✔ |
| 103 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (2, 5 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (2, 33 ms), w191 ×1 (2, 33 ms), textedit ×1 (1, 0 ms) | quiet 678 ms; blind for 74 ms |  |  | ~ |  | ✘ | ✔ | ✔ |

### After Arbor: can every window be reached?

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 104 | dock-icon-finder-3 | clicks finder's icon in the Dock |  | quiet 352 ms; blind for 72 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 105 | dock-icon-safari-3 | clicks safari's icon in the Dock |  | quiet 425 ms; blind for 76 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 106 | dock-icon-textedit-3 | clicks textedit's icon in the Dock |  | quiet 420 ms; blind for 103 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 107 | dock-icon-terminal-3 | clicks terminal's icon in the Dock |  | quiet 406 ms; blind for 75 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 108 | dock-icon-notes-3 | clicks notes's icon in the Dock |  | quiet 395 ms; blind for 82 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 109 | dock-icon-calendar-3 | clicks calendar's icon in the Dock |  | quiet 427 ms; blind for 94 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 110 | dock-icon-settings-3 | clicks settings's icon in the Dock |  | quiet 600 ms; blind for 79 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 111 | dock-icon-preview-3 | clicks preview's icon in the Dock |  | quiet 411 ms; blind for 71 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 112 | dock-icon-mail-3 | clicks mail's icon in the Dock |  | quiet 404 ms; blind for 75 ms |  | ✔ | ✔ |  |  | ✔ | ✘ |

### The next morning: Arbor starts again

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 113 | launch-2 | starts Arbor again | finder ×1 (1, 0 ms), safari ×1 (3, 61 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 848 ms; blind for 71 ms |  | ✘ | ✔ |  |  | ✘ | ✔ |
| 114 | leave-alone-2 | does nothing for half a minute |  | quiet 404 ms; blind for 79 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 115 | quit-2 | quits Arbor | finder ×1 (1, 0 ms), safari ×1 (2, 60 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w189 ×1 (1, 0 ms), w191 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 936 ms; blind for 75 ms |  |  | ✔ |  | ✘ | ✔ | ✔ |
