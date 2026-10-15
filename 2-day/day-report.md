128 steps in 381 s, 113 of them judged, 25 with a rule broken. The sampler: samples 15299 seconds 382.3 hz 40.0 cost-ms 2.00 late 29 longest-gap-ms 743.
Input: 394 presses, releases, keys and scrolls reached the apps, half of them within 594 µs, 99 in 100 within 57749 µs, the latest after 68941 µs.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 9 | 3 | 85 double-click-finder, 86 double-click-finder-again, 93 drag-calendar-to-top-edge |
| 2 | nothing moves that the person did not move | 98 | 14 | 27 dock-left, 29 dock-right, 33 drag-terminal-onto-finder-right, 53 view-all, 72 minimize-safari, 73 restore-safari, 75 hide-finder, 76 unhide-finder, 78 quit-textedit, 82 leave-full-screen, 93 drag-calendar-to-top-edge, 103 dock-left … |
| 3 | no jolts: a window moves once, to where it ends up | 116 | 2 | 93 drag-calendar-to-top-edge, 100 resume |
| 4 | the window you switch to comes to the front and into view | 91 | 3 | 36 drag-gap-beside-finder, 93 drag-calendar-to-top-edge, 95 click-tile |
| 5 | quitting, Float All and pause give windows their own sizes back | 5 | 4 | 98 pause, 101 float-all, 107 quit, 119 quit |
| 6 | what a person presses reaches the apps, at once | 73 | 1 | 122 dock-icon-textedit |
| L | no window is lost or stuck | 116 | 1 | 117 launch |
| - | what the script itself checked | 116 | 1 | 14 leave-alone |

## Findings

### Rule 1: never fight macOS: where it answers a drag, Arbor stands aside

- ✘ **85 double-click-finder** (double-clicks finder's title bar: macOS zooms the window): finder (w148) macOS answered the double-click on its title bar, and it was moved again afterwards (2 moves) [fought]
  - +0 ms 12,43 501×767 · +1044 ms 12,43 502×760 · +1118 ms 12,43 512×655 · +1146 ms 12,43 519×586 · +1169 ms 12,43 523×547 · +1194 ms 12,43 530×471 · … 5 more … · +1296 ms 12,43 548×286 · +1319 ms 12,43 550×270 · +1360 ms 12,43 551×253 · +1379 ms 12,43 551×252 · +1721 ms 12,43 501×767
- ✘ **86 double-click-finder-again** (double-clicks it again: macOS takes the window back): finder (w148) macOS answered the double-click on its title bar, and it was moved again afterwards (2 moves) [fought]
  - +0 ms 12,43 501×767 · +888 ms 12,43 501×766 · +912 ms 12,43 504×745 · +960 ms 12,43 510×683 · +981 ms 12,43 513×649 · +1000 ms 12,43 516×613 · … 3 more … · +1129 ms 12,43 544×333 · +1171 ms 12,43 550×269 · +1224 ms 12,43 551×253 · +1231 ms 12,43 551×252 · +1551 ms 12,43 501×767
- ✘ **93 drag-calendar-to-top-edge** (drags calendar by its title bar against the top edge of the screen and lets go): calendar (w167) macOS's tiling preview and Arbor's drop preview were up at the same time [fought]
- ✘ **93 drag-calendar-to-top-edge** (drags calendar by its title bar against the top edge of the screen and lets go): calendar (w167) macOS answered the drag, and Arbor docked the window [fought]

### Rule 2: nothing moves that the person did not move

- ✘ **27 dock-left** (presses ⌃⌥⌘ and the left arrow): safari (w151) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×791 · +2101 ms 806,31 794×791
- ✘ **27 dock-left** (presses ⌃⌥⌘ and the left arrow): textedit (w160) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +2101 ms 806,65 673×439
- ✘ **27 dock-left** (presses ⌃⌥⌘ and the left arrow): terminal (w165) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 740,300 877×499 · +2101 ms 806,300 793×499
- ✘ **27 dock-left** (presses ⌃⌥⌘ and the left arrow): notes (w166) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +2101 ms 806,105 794×660
- ✘ **27 dock-left** (presses ⌃⌥⌘ and the left arrow): calendar (w167) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 464,118 936×599 · +2101 ms 806,118 794×599
- ✘ **27 dock-left** (presses ⌃⌥⌘ and the left arrow): settings (w170) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +2101 ms 806,85 723×625
- ✘ **27 dock-left** (presses ⌃⌥⌘ and the left arrow): preview (w172) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +2101 ms 806,35 708×424
- ✘ **27 dock-left** (presses ⌃⌥⌘ and the left arrow): mail (w175) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +2101 ms 729,72 871×630
- ~ **27 dock-left** (presses ⌃⌥⌘ and the left arrow): w177 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +2101 ms 930,179 470×416
- ✘ **29 dock-right** (presses ⌃⌥⌘ and the right arrow): textedit (w160) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,65 673×439 · +1111 ms 541,65 461×439
- ✘ **29 dock-right** (presses ⌃⌥⌘ and the right arrow): terminal (w165) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,300 793×499 · +1111 ms 541,300 457×499
- ✘ **29 dock-right** (presses ⌃⌥⌘ and the right arrow): notes (w166) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,105 794×660 · +1111 ms 417,105 709×660
- ✘ **29 dock-right** (presses ⌃⌥⌘ and the right arrow): calendar (w167) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,118 794×599 · +1111 ms 431,118 680×599
- ✘ **29 dock-right** (presses ⌃⌥⌘ and the right arrow): settings (w170) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,85 723×625 · +1111 ms 410,85 723×625
- ✘ **29 dock-right** (presses ⌃⌥⌘ and the right arrow): preview (w172) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,35 708×424 · +1111 ms 417,35 708×424
- ✘ **29 dock-right** (presses ⌃⌥⌘ and the right arrow): mail (w175) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 729,72 871×630 · +1111 ms 336,72 871×630
- ~ **29 dock-right** (presses ⌃⌥⌘ and the right arrow): w177 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 930,179 470×416 · +1111 ms 537,179 470×416
- ✘ **33 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): notes (w166) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 417,105 709×660 · +4554 ms 202,105 709×660
- ✘ **33 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): calendar (w167) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 431,118 680×599 · +4554 ms 217,118 680×599
- ✘ **33 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): settings (w170) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 410,85 723×625 · +4554 ms 195,85 723×625
- ✘ **33 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): preview (w172) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 417,35 708×424 · +4554 ms 203,35 708×424
- ✘ **33 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): mail (w175) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 336,72 871×630 · +4554 ms 121,72 871×630
- ~ **33 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): w177 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 537,179 470×416 · +4554 ms 322,179 470×416
- ✘ **53 view-all** (presses ⌃⌥Space): notes (w166) is not back where it was after step 37: 300,105 1000×660, it was at 202,105 709×660 [moved-unasked]
- ✘ **53 view-all** (presses ⌃⌥Space): calendar (w167) is not back where it was after step 37: 464,118 936×599, it was at 217,118 680×599 [moved-unasked]
- ✘ **53 view-all** (presses ⌃⌥Space): settings (w170) is not back where it was after step 37: 437,85 723×625, it was at 195,85 723×625 [moved-unasked]
- ✘ **53 view-all** (presses ⌃⌥Space): preview (w172) is not back where it was after step 37: 4,35 708×424, it was at 203,35 708×424 [moved-unasked]
- ✘ **53 view-all** (presses ⌃⌥Space): mail (w175) is not back where it was after step 37: 240,72 1120×630, it was at 121,72 871×630 [moved-unasked]
- ✘ **53 view-all** (presses ⌃⌥Space): w177 of Mail is not back where it was after step 37: 565,179 470×416, it was at 322,179 470×416 [moved-unasked]
- ✘ **72 minimize-safari** (presses ⌘M): terminal (w165) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 97,238 877×499 · +1440 ms 525,238 331×499
- ✘ **72 minimize-safari** (presses ⌘M): notes (w166) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +1440 ms 335,105 709×660
- ✘ **72 minimize-safari** (presses ⌘M): calendar (w167) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 464,118 936×599 · +1440 ms 350,118 680×599
- ✘ **72 minimize-safari** (presses ⌘M): settings (w170) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +1440 ms 328,85 723×625
- ✘ **72 minimize-safari** (presses ⌘M): preview (w172) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +1440 ms 336,35 708×424
- ✘ **72 minimize-safari** (presses ⌘M): mail (w175) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1440 ms 254,72 871×630
- ~ **72 minimize-safari** (presses ⌘M): w177 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1440 ms 455,179 470×416
- ✘ **73 restore-safari** (clicks its miniature in the Dock): terminal (w165) is not back where it was after step 71: 525,238 331×499, it was at 97,238 877×499 [moved-unasked]
- ✘ **73 restore-safari** (clicks its miniature in the Dock): notes (w166) is not back where it was after step 71: 335,105 709×660, it was at 300,105 1000×660 [moved-unasked]
- ✘ **73 restore-safari** (clicks its miniature in the Dock): calendar (w167) is not back where it was after step 71: 350,118 680×599, it was at 464,118 936×599 [moved-unasked]
- ✘ **73 restore-safari** (clicks its miniature in the Dock): settings (w170) is not back where it was after step 71: 328,85 723×625, it was at 437,85 723×625 [moved-unasked]
- ✘ **73 restore-safari** (clicks its miniature in the Dock): preview (w172) is not back where it was after step 71: 336,35 708×424, it was at 4,35 708×424 [moved-unasked]
- ✘ **73 restore-safari** (clicks its miniature in the Dock): mail (w175) is not back where it was after step 71: 254,72 871×630, it was at 240,72 1120×630 [moved-unasked]
- ✘ **73 restore-safari** (clicks its miniature in the Dock): w177 of Mail is not back where it was after step 71: 455,179 470×416, it was at 565,179 470×416 [moved-unasked]
- ✘ **75 hide-finder** (presses ⌘H): terminal (w165) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 525,238 331×499 · +349 ms 0,238 268×499
- ✘ **75 hide-finder** (presses ⌘H): notes (w166) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 335,105 709×660 · +349 ms 0,105 709×660
- ✘ **75 hide-finder** (presses ⌘H): calendar (w167) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 350,118 680×599 · +349 ms 0,118 680×599
- ✘ **75 hide-finder** (presses ⌘H): settings (w170) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 328,85 723×625 · +349 ms 0,85 723×625
- ✘ **75 hide-finder** (presses ⌘H): preview (w172) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 336,35 708×424 · +349 ms 0,35 708×424
- ✘ **75 hide-finder** (presses ⌘H): mail (w175) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 254,72 871×630 · +349 ms 0,72 871×630
- ~ **75 hide-finder** (presses ⌘H): w177 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 455,179 470×416 · +349 ms 201,179 470×416
- ✘ **76 unhide-finder** (clicks its icon in the Dock): terminal (w165) is not back where it was after step 74: 0,238 268×499, it was at 525,238 331×499 [moved-unasked]
- ✘ **76 unhide-finder** (clicks its icon in the Dock): notes (w166) is not back where it was after step 74: 0,105 709×660, it was at 335,105 709×660 [moved-unasked]
- ✘ **76 unhide-finder** (clicks its icon in the Dock): calendar (w167) is not back where it was after step 74: 0,118 680×599, it was at 350,118 680×599 [moved-unasked]
- ✘ **76 unhide-finder** (clicks its icon in the Dock): settings (w170) is not back where it was after step 74: 0,85 723×625, it was at 328,85 723×625 [moved-unasked]
- ✘ **76 unhide-finder** (clicks its icon in the Dock): preview (w172) is not back where it was after step 74: 0,35 708×424, it was at 336,35 708×424 [moved-unasked]
- ✘ **76 unhide-finder** (clicks its icon in the Dock): mail (w175) is not back where it was after step 74: 0,72 871×630, it was at 254,72 871×630 [moved-unasked]
- ✘ **76 unhide-finder** (clicks its icon in the Dock): w177 of Mail is not back where it was after step 74: 201,179 470×416, it was at 455,179 470×416 [moved-unasked]
- ✘ **78 quit-textedit** (presses ⌘Q in textedit): terminal (w165) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,238 268×499 · +906 ms 525,238 401×499
- ✘ **78 quit-textedit** (presses ⌘Q in textedit): notes (w166) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,105 709×660 · +906 ms 372,105 709×660
- ✘ **78 quit-textedit** (presses ⌘Q in textedit): calendar (w167) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,118 680×599 · +906 ms 386,118 680×599
- ✘ **78 quit-textedit** (presses ⌘Q in textedit): settings (w170) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,85 723×625 · +906 ms 365,85 723×625
- ✘ **78 quit-textedit** (presses ⌘Q in textedit): preview (w172) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,35 708×424 · +906 ms 372,35 708×424
- ✘ **78 quit-textedit** (presses ⌘Q in textedit): mail (w175) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,72 871×630 · +906 ms 291,72 871×630
- ~ **78 quit-textedit** (presses ⌘Q in textedit): w177 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 201,179 470×416 · +906 ms 492,179 470×416
- ✘ **82 leave-full-screen** (presses ⌃⌘F again): textedit (w321) is not back where it was after step 80: 525,65 403×439, it was at 165,65 673×439 [moved-unasked]
- ✘ **93 drag-calendar-to-top-edge** (drags calendar by its title bar against the top edge of the screen and lets go): terminal (w165) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 525,238 401×499 · +5248 ms 525,433 401×379
- ✘ **93 drag-calendar-to-top-edge** (drags calendar by its title bar against the top edge of the screen and lets go): settings (w170) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 365,85 723×625 · +5248 ms 365,352 723×470
- ✘ **93 drag-calendar-to-top-edge** (drags calendar by its title bar against the top edge of the screen and lets go): preview (w172) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 372,35 708×424 · +5248 ms 372,433 708×389
- ✘ **93 drag-calendar-to-top-edge** (drags calendar by its title bar against the top edge of the screen and lets go): mail (w175) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 291,72 871×630 · +5248 ms 291,433 871×389
- ~ **93 drag-calendar-to-top-edge** (drags calendar by its title bar against the top edge of the screen and lets go): w177 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 492,179 470×416 · +5248 ms 492,485 470×416
- ✘ **93 drag-calendar-to-top-edge** (drags calendar by its title bar against the top edge of the screen and lets go): textedit (w321) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 525,65 403×439 · +5248 ms 525,433 403×389
- ✘ **103 dock-left** (presses ⌃⌥⌘ and the left arrow): safari (w151) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×791 · +827 ms 806,31 794×791
- ✘ **103 dock-left** (presses ⌃⌥⌘ and the left arrow): terminal (w165) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 97,238 877×499 · +827 ms 806,238 793×499
- ✘ **103 dock-left** (presses ⌃⌥⌘ and the left arrow): notes (w166) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms -1,32 800×791 · +827 ms 806,32 794×791
- ✘ **103 dock-left** (presses ⌃⌥⌘ and the left arrow): calendar (w167) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 386,118 680×599 · +827 ms 806,118 680×599
- ✘ **103 dock-left** (presses ⌃⌥⌘ and the left arrow): settings (w170) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +827 ms 806,85 723×625
- ✘ **103 dock-left** (presses ⌃⌥⌘ and the left arrow): preview (w172) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +827 ms 806,35 708×424
- ✘ **103 dock-left** (presses ⌃⌥⌘ and the left arrow): mail (w175) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +827 ms 729,72 871×630
- ~ **103 dock-left** (presses ⌃⌥⌘ and the left arrow): w177 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +827 ms 930,179 470×416
- ✘ **103 dock-left** (presses ⌃⌥⌘ and the left arrow): textedit (w321) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +827 ms 806,65 673×439
- ✘ **105 dock-right** (presses ⌃⌥⌘ and the right arrow): terminal (w165) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,238 793×499 · +1023 ms 541,238 457×499
- ✘ **105 dock-right** (presses ⌃⌥⌘ and the right arrow): notes (w166) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,32 794×791 · +1023 ms 417,32 709×791
- ✘ **105 dock-right** (presses ⌃⌥⌘ and the right arrow): calendar (w167) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,118 680×599 · +1023 ms 431,118 680×599
- ✘ **105 dock-right** (presses ⌃⌥⌘ and the right arrow): settings (w170) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,85 723×625 · +1023 ms 410,85 723×625
- ✘ **105 dock-right** (presses ⌃⌥⌘ and the right arrow): preview (w172) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,35 708×424 · +1023 ms 417,35 708×424
- ✘ **105 dock-right** (presses ⌃⌥⌘ and the right arrow): mail (w175) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 729,72 871×630 · +1023 ms 336,72 871×630
- ~ **105 dock-right** (presses ⌃⌥⌘ and the right arrow): w177 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 930,179 470×416 · +1023 ms 537,179 470×416
- ✘ **105 dock-right** (presses ⌃⌥⌘ and the right arrow): textedit (w321) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,65 673×439 · +1023 ms 541,65 461×439
- ✘ **117 launch** (starts Arbor): terminal (w165) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 97,238 877×499 · +242 ms 1599,790 877×499
- ✘ **117 launch** (starts Arbor): notes (w166) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms -1,32 800×791 · +242 ms 1599,770 800×791
- ✘ **117 launch** (starts Arbor): calendar (w167) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 386,118 680×599 · +242 ms 1599,770 680×599
- ✘ **117 launch** (starts Arbor): settings (w170) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +242 ms 1599,770 723×625
- ✘ **117 launch** (starts Arbor): preview (w172) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +288 ms 1599,770 708×424
- ✘ **117 launch** (starts Arbor): mail (w175) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +288 ms 1599,770 1120×630
- ~ **117 launch** (starts Arbor): w177 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +288 ms 1924,877 470×416
- ✘ **117 launch** (starts Arbor): textedit (w321) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +288 ms 1599,790 673×439

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **27 dock-left** (presses ⌃⌥⌘ and the left arrow): the last window came to rest 1816 ms after the key or the button, in Arbor's first act since it started [slow]
- ~ **29 dock-right** (presses ⌃⌥⌘ and the right arrow): the last window came to rest 877 ms after the key or the button [slow]
- ~ **33 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): the last window came to rest 739 ms after the key or the button [slow]
- ~ **34 drag-terminal-out** (drags terminal out of the arrangement onto the Desktop and lets go): the last window came to rest 761 ms after the key or the button [slow]
- ~ **58 view-out** (presses ⌃⌥↑): the last window came to rest 702 ms after the key or the button [slow]
- ~ **59 view-desktop** (presses ⌃⌥D): the last window came to rest 702 ms after the key or the button [slow]
- ~ **67 view-frame** (presses ⌃⌥↩): the last window came to rest 711 ms after the key or the button [slow]
- ✘ **93 drag-calendar-to-top-edge** (drags calendar by its title bar against the top edge of the screen and lets go): calendar (w167) went 620 points out of its way before it ended up [jolt]
  - +0 ms 310,31 680×599 · +1066 ms 0,31 1600×791 · +1179 ms 1599,770 1600×791
- ✘ **100 resume** (presses ⌃⌥⎋): calendar (w167) moved 2 times [jolt]
  - +0 ms 446,178 680×599 · +200 ms 1599,770 680×599 · +895 ms 12,43 1576×767
- ~ **100 resume** (presses ⌃⌥⎋): the last window came to rest 746 ms after the key or the button [slow]
- ~ **105 dock-right** (presses ⌃⌥⌘ and the right arrow): the last window came to rest 719 ms after the key or the button [slow]

### Rule 4: the window you switch to comes to the front and into view

- ✘ **36 drag-gap-beside-finder** (drags the gap to the right of finder by 60 points): the app in front changed (to process 20332), and nobody switched [focus]
- ✘ **93 drag-calendar-to-top-edge** (drags calendar by its title bar against the top edge of the screen and lets go): calendar (w167) is not wholly in view: 0% of it, at 1599,770 1600×791 in 0,31 1600×791 [focus]
- ✘ **95 click-tile** (clicks the tile that stands in for a window): calendar (w167) is not in front: notes (w166) ahead of it, none of which covers it [behind]
- ✘ **95 click-tile** (clicks the tile that stands in for a window): calendar (w167) its app is not the one in front (process 20515 is) [focus]
- ✘ **95 click-tile** (clicks the tile that stands in for a window): calendar (w167) is not wholly in view: 0% of it, at 1599,770 1600×791 in 0,31 1600×791 [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **98 pause** (presses ⌃⌥⎋): finder (w148) is 12,433 501×377; its own size was 340,120 920×436 [size-lost]
- ✘ **98 pause** (presses ⌃⌥⎋): safari (w151) is 940,433 648×377; its own size was 138,31 1324×791 [size-lost]
- ✘ **98 pause** (presses ⌃⌥⎋): terminal (w165) is 525,433 401×379; its own size was 97,238 877×499 [size-lost]
- ✘ **98 pause** (presses ⌃⌥⎋): calendar (w167) is 386,118 680×599; its own size was 464,118 936×599 [size-lost]
- ✘ **98 pause** (presses ⌃⌥⎋): settings (w170) is 365,352 723×470; its own size was 437,85 723×625 [size-lost]
- ✘ **98 pause** (presses ⌃⌥⎋): preview (w172) is 372,433 708×389; its own size was 4,35 708×424 [size-lost]
- ✘ **98 pause** (presses ⌃⌥⎋): mail (w175) is 291,433 871×389; its own size was 240,72 1120×630 [size-lost]
- ✘ **98 pause** (presses ⌃⌥⎋): textedit (w321) is 525,433 403×389; its own size was 165,65 673×439 [size-lost]
- ✘ **101 float-all** (presses ⌃⌥⇧F): calendar (w167) has its size back but not its place: 386,118 680×599, it was at 446,178 680×599 [size-lost]
- ✘ **107 quit** (chooses Quit Arbor in Arbor's menu): calendar (w167) has its size back but not its place: 386,118 680×599, it was at 446,178 680×599 [size-lost]
- ✘ **119 quit** (chooses Quit Arbor in Arbor's menu): calendar (w167) has its size back but not its place: 386,118 680×599, it was at 446,178 680×599 [size-lost]

### Rule 6: what a person presses reaches the apps, at once

- ✘ **122 dock-icon-textedit** (clicks textedit's icon in the Dock): the button came up, and the apps heard of it 57 ms later [input-held]

### Rule L: no window is lost or stuck

- ✘ **117 launch** (starts Arbor): finder (w148) is out of view: 0% of it is on a display, at 1599,770 920×436 [lost]
- ✘ **117 launch** (starts Arbor): terminal (w165) is out of view: 0% of it is on a display, at 1599,790 877×499 [lost]
- ✘ **117 launch** (starts Arbor): notes (w166) is out of view: 0% of it is on a display, at 1599,770 800×791 [lost]
- ✘ **117 launch** (starts Arbor): calendar (w167) is out of view: 0% of it is on a display, at 1599,770 680×599 [lost]
- ✘ **117 launch** (starts Arbor): settings (w170) is out of view: 0% of it is on a display, at 1599,770 723×625 [lost]
- ✘ **117 launch** (starts Arbor): preview (w172) is out of view: 0% of it is on a display, at 1599,770 708×424 [lost]
- ✘ **117 launch** (starts Arbor): mail (w175) is out of view: 0% of it is on a display, at 1599,770 1120×630 [lost]
- ✘ **117 launch** (starts Arbor): textedit (w321) is out of view: 0% of it is on a display, at 1599,790 673×439 [lost]

### Rule -: what the script itself checked

- ✘ **14 leave-alone** (does nothing for half a minute): with nothing to do Arbor used 1.6 % of a core [busy]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (3, 89 ms) | quiet 1076 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 810 ms; blind for 713 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (4, 292 ms) | quiet 1359 ms; blind for 124 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (7, 375 ms) | quiet 1319 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (4, 103 ms) | quiet 1064 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×2 (4, 376 ms) | quiet 1383 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (3, 319 ms) | quiet 990 ms; blind for 167 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (3, 108 ms) | quiet 1091 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w177 ×1 (4, 133 ms) | quiet 928 ms; blind for 743 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (28, 3331 ms) | quiet 1006 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (30, 2964 ms) | quiet 1049 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 400 ms |  |  |  |  |  |  |  |  |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 13 | launch | starts Arbor |  | quiet 1088 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 14 | leave-alone | does nothing for half a minute |  | quiet 353 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |

### Switching between apps, nothing docked yet

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 15 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 432 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 16 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 356 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 388 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 18 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 420 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 370 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 357 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 533 ms; blind for 142 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 22 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 428 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 388 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 460 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 25 | cmd-tab-2 | holds ⌘ and presses Tab 2 time(s) |  | quiet 376 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### The first docks, by key

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 26 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 483 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms) | quiet 1052 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 28 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 415 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 29 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms) | quiet 975 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 30 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 569 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 802 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### Docking by real drags

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 32 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 424 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | drag-terminal-onto-finder-right | drags terminal by its title bar onto the right part of finder and lets go | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms) | quiet 1023 ms | ✔ | ✘ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | drag-terminal-out | drags terminal out of the arrangement onto the Desktop and lets go | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms) | quiet 1115 ms | ✔ | ✔ | ~ | ✔ | ✔ | ✔ | ✔ | ✔ |

### Sizes

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 35 | click-finder | clicks finder's title bar |  | quiet 358 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 36 | drag-gap-beside-finder | drags the gap to the right of finder by 60 points |  | quiet 1039 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |

### Switching between apps, with an arrangement

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 37 | view-all | presses ⌃⌥Space |  | quiet 876 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 38 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 422 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 558 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 384 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 365 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 473 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 386 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 525 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 434 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 46 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 461 ms; blind for 101 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 538 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### The view goes in and out

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 48 | click-finder | clicks finder's title bar |  | quiet 384 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms) | quiet 1202 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 50 | dock-icon-safari | clicks safari's icon in the Dock | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 492 ms; blind for 110 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 456 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 52 | dock-icon-calendar | clicks calendar's icon in the Dock | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms) | quiet 662 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 53 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 709 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 54 | click-safari | clicks safari's title bar |  | quiet 416 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms) | quiet 907 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 56 | view-left | presses ⌃⌥← | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms) | quiet 724 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 57 | view-back | presses ⌃⌥[ | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms) | quiet 680 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 58 | view-out | presses ⌃⌥↑ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms) | quiet 765 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 59 | view-desktop | presses ⌃⌥D | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 942 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 60 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 762 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### Windows come and go

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 61 | click-safari | clicks safari's title bar |  | quiet 385 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 62 | new-window-safari | presses ⌘N in safari |  | quiet 1005 ms; blind for 735 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 63 | window-menu-safari | chooses safari's first window in the Window menu |  | quiet 1380 ms; blind for 296 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 64 | cmd-backtick | presses ⌘` for the app's next window |  | quiet 382 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 65 | close-window | presses ⌘W |  | quiet 857 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 66 | click-safari | clicks safari's title bar |  | quiet 367 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 67 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms) | quiet 949 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 68 | new-window-safari | presses ⌘N in safari |  | quiet 981 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 69 | close-window | presses ⌘W |  | quiet 826 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 70 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms) | quiet 667 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 71 | click-safari | clicks safari's title bar |  | quiet 418 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 72 | minimize-safari | presses ⌘M | safari ×1 (17, 452 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms) | quiet 2004 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 73 | restore-safari | clicks its miniature in the Dock | safari ×1 (18, 495 ms), textedit ×1 (1, 0 ms) | quiet 1029 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 74 | click-finder | clicks finder's title bar |  | quiet 415 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 75 | hide-finder | presses ⌘H | safari ×1 (1, 0 ms), textedit ×1 (2, 74 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms) | quiet 1170 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 76 | unhide-finder | clicks its icon in the Dock | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 484 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 77 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 523 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 78 | quit-textedit | presses ⌘Q in textedit | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms) | quiet 1234 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 79 | reopen-textedit | opens textedit's document again |  | quiet 1000 ms; blind for 297 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### Full screen

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 80 | click-safari | clicks safari's title bar |  | quiet 400 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 81 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (2, 129 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 417 ms; blind for 128 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 82 | leave-full-screen | presses ⌃⌘F again | safari ×1 (2, 66 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 362 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |

### A click lands on the wallpaper, a double-click on a title bar

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 83 | click-wallpaper | clicks on the wallpaper | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 350 ms; blind for 100 ms |  |  | ✔ |  |  | ✔ | ✔ | ✔ |
| 84 | click-wallpaper-again | clicks on the wallpaper again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 366 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 85 | double-click-finder | double-clicks finder's title bar: macOS zooms the window | finder ×2 (15, 677 ms) | quiet 1151 ms | ✘ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 86 | double-click-finder-again | double-clicks it again: macOS takes the window back | finder ×2 (13, 663 ms) | quiet 1078 ms | ✘ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 87 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 595 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 88 | double-click-calendar | double-clicks calendar's title bar: macOS zooms the window | calendar ×1 (8, 320 ms) | quiet 830 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 89 | double-click-calendar-again | double-clicks it again: macOS takes the window back | calendar ×1 (15, 383 ms) | quiet 768 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### Where macOS tiles too

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 90 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 381 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 91 | drag-notes-to-left-edge | drags notes by its title bar against the left edge of the screen and lets go | notes ×1 (7, 268 ms) | quiet 386 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 92 | click-calendar | clicks calendar's title bar |  | quiet 417 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 93 | drag-calendar-to-top-edge | drags calendar by its title bar against the top edge of the screen and lets go | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (2, 113 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1350 ms | ✘ | ✘ | ✘ | ✘ |  | ✔ | ✔ | ✔ |
| 94 | view-all | presses ⌃⌥Space |  | quiet 785 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 95 | click-tile | clicks the tile that stands in for a window |  | quiet 911 ms |  |  | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 96 | view-all | presses ⌃⌥Space |  | quiet 703 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### The ways out

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 97 | click-safari | clicks safari's title bar |  | quiet 393 ms; blind for 107 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 98 | pause | presses ⌃⌥⎋ | calendar ×1 (1, 0 ms) | quiet 705 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 99 | drag-calendar-by | drags calendar, which floats, by its title bar 60 across and 60 down |  | quiet 1051 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 100 | resume | presses ⌃⌥⎋ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×2 (2, 695 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 960 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 101 | float-all | presses ⌃⌥⇧F | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 843 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 102 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 410 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 103 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 723 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 104 | click-safari | clicks safari's title bar |  | quiet 475 ms; blind for 101 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 105 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 968 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 106 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 981 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |

### Quit, and the next morning

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 107 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (2, 65 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 814 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 108 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 370 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 109 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 419 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 110 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 415 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 111 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 385 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 112 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 408 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 113 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 362 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 114 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 462 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 115 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 517 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 116 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 431 ms; blind for 100 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 117 | launch | starts Arbor | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 865 ms |  | ✘ | ✔ |  |  |  | ✘ | ✔ |
| 118 | leave-alone | does nothing for half a minute |  | quiet 416 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 119 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w177 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 823 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 120 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 399 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 121 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 507 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 122 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 365 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 123 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 367 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 124 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 413 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 125 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 400 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 126 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 365 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 127 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 417 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 128 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 409 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
