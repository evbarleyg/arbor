127 steps in 435 s, 109 of them judged, 22 with a rule broken. The sampler: samples 14435 seconds 371.6 hz 38.8 cost-ms 2.52 late 48 longest-gap-ms 1751 whole-samples 16939 whole-seconds 436.1 whole-late 64.
Input: 388 presses, releases, keys and scrolls reached the apps, half of them within 651 µs, 99 in 100 within 94322 µs, the latest after 165198 µs.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 10 | 3 | 89 double-click-finder, 90 double-click-finder-again, 97 drag-calendar-to-top-edge |
| 2 | nothing moves that the person did not move | 96 | 13 | 29 dock-left, 31 dock-right, 35 drag-terminal-onto-finder-right, 57 view-all, 76 minimize-safari, 77 restore-safari, 79 hide-finder, 80 unhide-finder, 82 quit-textedit, 86 leave-full-screen, 108 dock-left, 110 dock-right … |
| 3 | no jolts: a window moves once, to where it ends up | 113 | 3 | 86 leave-full-screen, 95 drag-notes-to-left-edge, 116 launch |
| 4 | the window you switch to comes to the front and into view | 89 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 5 | 3 | 106 float-all, 112 quit, 118 quit |
| 6 | what a person presses reaches the apps, at once | 67 | 1 | 87 click-wallpaper |
| L | no window is lost or stuck | 113 | 1 | 116 launch |
| - | what the script itself checked | 113 | 1 | 16 leave-alone |

## Findings

### Rule 1: never fight macOS: where it answers a drag, Arbor stands aside

- ✘ **89 double-click-finder** (double-clicks finder's title bar: macOS zooms the window): finder (w153) macOS answered the double-click on its title bar, and it was moved again afterwards (2 moves) [fought]
  - +0 ms 12,43 501×767 · +901 ms 12,43 502×759 · +937 ms 12,43 505×728 · +999 ms 12,43 516×614 · +1040 ms 12,43 520×579 · +1071 ms 12,43 526×519 · … 2 more … · +1165 ms 12,43 548×283 · +1188 ms 12,43 550×267 · +1221 ms 12,43 551×253 · +1258 ms 12,43 551×252 · +1604 ms 12,43 501×767
- ✘ **90 double-click-finder-again** (double-clicks it again: macOS takes the window back): finder (w153) macOS answered the double-click on its title bar, and it was moved again afterwards (2 moves) [fought]
  - +0 ms 12,43 501×767 · +995 ms 12,43 502×760 · +1027 ms 12,43 506×719 · +1048 ms 12,43 509×693 · +1083 ms 12,43 516×621 · +1134 ms 12,43 527×499 · +1213 ms 12,43 541×362 · +1218 ms 12,43 543×334 · +1253 ms 12,43 548×287 · +1313 ms 12,43 551×252 · +1658 ms 12,43 501×767
- ✘ **97 drag-calendar-to-top-edge** (drags calendar by its title bar against the top edge of the screen and lets go): calendar (w172) Arbor's drop preview was up with the pointer within 12 points of an edge of the screen that is macOS's [fought]

### Rule 2: nothing moves that the person did not move

- ✘ **29 dock-left** (presses ⌃⌥⌘ and the left arrow): safari (w156) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×791 · +2412 ms 806,31 794×791
- ✘ **29 dock-left** (presses ⌃⌥⌘ and the left arrow): textedit (w167) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +2412 ms 806,65 673×439
- ✘ **29 dock-left** (presses ⌃⌥⌘ and the left arrow): terminal (w170) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 740,300 877×499 · +2412 ms 806,300 793×499
- ✘ **29 dock-left** (presses ⌃⌥⌘ and the left arrow): notes (w171) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +2412 ms 806,105 794×660
- ✘ **29 dock-left** (presses ⌃⌥⌘ and the left arrow): calendar (w172) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 403,115 937×600 · +2412 ms 806,115 794×600
- ✘ **29 dock-left** (presses ⌃⌥⌘ and the left arrow): settings (w175) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +2412 ms 806,85 723×625
- ✘ **29 dock-left** (presses ⌃⌥⌘ and the left arrow): preview (w177) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +2412 ms 806,35 708×424
- ✘ **29 dock-left** (presses ⌃⌥⌘ and the left arrow): mail (w180) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +2412 ms 729,72 871×630
- ~ **29 dock-left** (presses ⌃⌥⌘ and the left arrow): w182 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +2412 ms 930,179 470×416
- ✘ **31 dock-right** (presses ⌃⌥⌘ and the right arrow): textedit (w167) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,65 673×439 · +1341 ms 541,65 461×439
- ✘ **31 dock-right** (presses ⌃⌥⌘ and the right arrow): terminal (w170) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,300 793×499 · +1341 ms 541,300 457×499
- ✘ **31 dock-right** (presses ⌃⌥⌘ and the right arrow): notes (w171) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,105 794×660 · +1341 ms 417,105 709×660
- ✘ **31 dock-right** (presses ⌃⌥⌘ and the right arrow): calendar (w172) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,115 794×600 · +1341 ms 431,115 680×600
- ✘ **31 dock-right** (presses ⌃⌥⌘ and the right arrow): settings (w175) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,85 723×625 · +1341 ms 410,85 723×625
- ✘ **31 dock-right** (presses ⌃⌥⌘ and the right arrow): preview (w177) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,35 708×424 · +1341 ms 417,35 708×424
- ✘ **31 dock-right** (presses ⌃⌥⌘ and the right arrow): mail (w180) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 729,72 871×630 · +1341 ms 336,72 871×630
- ~ **31 dock-right** (presses ⌃⌥⌘ and the right arrow): w182 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 930,179 470×416 · +1341 ms 537,179 470×416
- ✘ **35 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): notes (w171) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 417,105 709×660 · +4727 ms 202,105 709×660
- ✘ **35 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): calendar (w172) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 431,115 680×600 · +4727 ms 217,115 680×600
- ✘ **35 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): settings (w175) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 410,85 723×625 · +4727 ms 195,85 723×625
- ✘ **35 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): preview (w177) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 417,35 708×424 · +4727 ms 203,35 708×424
- ✘ **35 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): mail (w180) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 336,72 871×630 · +4727 ms 121,72 871×630
- ~ **35 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): w182 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 537,179 470×416 · +4727 ms 322,179 470×416
- ✘ **57 view-all** (presses ⌃⌥Space): notes (w171) is not back where it was after step 41: 300,105 1000×660, it was at 202,105 709×660 [moved-unasked]
- ✘ **57 view-all** (presses ⌃⌥Space): calendar (w172) is not back where it was after step 41: 403,115 937×600, it was at 217,115 680×600 [moved-unasked]
- ✘ **57 view-all** (presses ⌃⌥Space): settings (w175) is not back where it was after step 41: 437,85 723×625, it was at 195,85 723×625 [moved-unasked]
- ✘ **57 view-all** (presses ⌃⌥Space): preview (w177) is not back where it was after step 41: 4,35 708×424, it was at 203,35 708×424 [moved-unasked]
- ✘ **57 view-all** (presses ⌃⌥Space): mail (w180) is not back where it was after step 41: 240,72 1120×630, it was at 121,72 871×630 [moved-unasked]
- ✘ **57 view-all** (presses ⌃⌥Space): w182 of Mail is not back where it was after step 41: 565,179 470×416, it was at 322,179 470×416 [moved-unasked]
- ✘ **76 minimize-safari** (presses ⌘M): terminal (w170) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 97,238 877×499 · +1768 ms 525,238 429×499
- ✘ **76 minimize-safari** (presses ⌘M): notes (w171) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +1768 ms 386,105 709×660
- ✘ **76 minimize-safari** (presses ⌘M): calendar (w172) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 403,115 937×600 · +1768 ms 401,115 680×600
- ✘ **76 minimize-safari** (presses ⌘M): settings (w175) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +1768 ms 379,85 723×625
- ✘ **76 minimize-safari** (presses ⌘M): preview (w177) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +1768 ms 387,35 708×424
- ✘ **76 minimize-safari** (presses ⌘M): mail (w180) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1768 ms 305,72 871×630
- ~ **76 minimize-safari** (presses ⌘M): w182 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1768 ms 506,179 470×416
- ✘ **77 restore-safari** (clicks its miniature in the Dock): terminal (w170) is not back where it was after step 75: 525,238 429×499, it was at 97,238 877×499 [moved-unasked]
- ✘ **77 restore-safari** (clicks its miniature in the Dock): notes (w171) is not back where it was after step 75: 386,105 709×660, it was at 300,105 1000×660 [moved-unasked]
- ✘ **77 restore-safari** (clicks its miniature in the Dock): calendar (w172) is not back where it was after step 75: 401,115 680×600, it was at 403,115 937×600 [moved-unasked]
- ✘ **77 restore-safari** (clicks its miniature in the Dock): settings (w175) is not back where it was after step 75: 379,85 723×625, it was at 437,85 723×625 [moved-unasked]
- ✘ **77 restore-safari** (clicks its miniature in the Dock): preview (w177) is not back where it was after step 75: 387,35 708×424, it was at 4,35 708×424 [moved-unasked]
- ✘ **77 restore-safari** (clicks its miniature in the Dock): mail (w180) is not back where it was after step 75: 305,72 871×630, it was at 240,72 1120×630 [moved-unasked]
- ✘ **77 restore-safari** (clicks its miniature in the Dock): w182 of Mail is not back where it was after step 75: 506,179 470×416, it was at 565,179 470×416 [moved-unasked]
- ✘ **79 hide-finder** (presses ⌘H): terminal (w170) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 525,238 429×499 · +285 ms 0,238 324×499
- ✘ **79 hide-finder** (presses ⌘H): notes (w171) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 386,105 709×660 · +285 ms 0,105 709×660
- ✘ **79 hide-finder** (presses ⌘H): calendar (w172) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 401,115 680×600 · +285 ms 0,115 680×600
- ✘ **79 hide-finder** (presses ⌘H): settings (w175) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 379,85 723×625 · +295 ms 0,85 723×625
- ✘ **79 hide-finder** (presses ⌘H): preview (w177) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 387,35 708×424 · +295 ms 0,35 708×424
- ✘ **79 hide-finder** (presses ⌘H): mail (w180) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 305,72 871×630 · +295 ms 0,72 871×630
- ~ **79 hide-finder** (presses ⌘H): w182 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 506,179 470×416 · +295 ms 201,179 470×416
- ✘ **80 unhide-finder** (clicks its icon in the Dock): terminal (w170) is not back where it was after step 78: 0,238 324×499, it was at 525,238 429×499 [moved-unasked]
- ✘ **80 unhide-finder** (clicks its icon in the Dock): notes (w171) is not back where it was after step 78: 0,105 709×660, it was at 386,105 709×660 [moved-unasked]
- ✘ **80 unhide-finder** (clicks its icon in the Dock): calendar (w172) is not back where it was after step 78: 0,115 680×600, it was at 401,115 680×600 [moved-unasked]
- ✘ **80 unhide-finder** (clicks its icon in the Dock): settings (w175) is not back where it was after step 78: 0,85 723×625, it was at 379,85 723×625 [moved-unasked]
- ✘ **80 unhide-finder** (clicks its icon in the Dock): preview (w177) is not back where it was after step 78: 0,35 708×424, it was at 387,35 708×424 [moved-unasked]
- ✘ **80 unhide-finder** (clicks its icon in the Dock): mail (w180) is not back where it was after step 78: 0,72 871×630, it was at 305,72 871×630 [moved-unasked]
- ✘ **80 unhide-finder** (clicks its icon in the Dock): w182 of Mail is not back where it was after step 78: 201,179 470×416, it was at 506,179 470×416 [moved-unasked]
- ✘ **82 quit-textedit** (presses ⌘Q in textedit): terminal (w170) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,238 324×499 · +1020 ms 525,238 478×499
- ✘ **82 quit-textedit** (presses ⌘Q in textedit): notes (w171) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,105 709×660 · +1020 ms 409,105 709×660
- ✘ **82 quit-textedit** (presses ⌘Q in textedit): calendar (w172) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,115 680×600 · +1020 ms 423,115 680×600
- ✘ **82 quit-textedit** (presses ⌘Q in textedit): settings (w175) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,85 723×625 · +1020 ms 402,85 723×625
- ✘ **82 quit-textedit** (presses ⌘Q in textedit): preview (w177) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,35 708×424 · +1020 ms 409,35 708×424
- ✘ **82 quit-textedit** (presses ⌘Q in textedit): mail (w180) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,72 871×630 · +1020 ms 328,72 871×630
- ~ **82 quit-textedit** (presses ⌘Q in textedit): w182 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 201,179 470×416 · +1020 ms 529,179 470×416
- ✘ **86 leave-full-screen** (presses ⌃⌘F again): textedit (w335) is not back where it was after step 84: 525,65 477×439, it was at 165,65 673×439 [moved-unasked]
- ✘ **108 dock-left** (presses ⌃⌥⌘ and the left arrow): safari (w156) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×790 · +902 ms 806,31 794×790
- ✘ **108 dock-left** (presses ⌃⌥⌘ and the left arrow): terminal (w170) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 97,238 877×499 · +902 ms 806,238 793×499
- ✘ **108 dock-left** (presses ⌃⌥⌘ and the left arrow): notes (w171) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms -1,32 800×791 · +902 ms 806,32 794×791
- ✘ **108 dock-left** (presses ⌃⌥⌘ and the left arrow): calendar (w172) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 385,145 683×601 · +902 ms 806,145 683×601
- ✘ **108 dock-left** (presses ⌃⌥⌘ and the left arrow): settings (w175) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +902 ms 806,85 723×625
- ✘ **108 dock-left** (presses ⌃⌥⌘ and the left arrow): preview (w177) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +902 ms 806,35 708×424
- ✘ **108 dock-left** (presses ⌃⌥⌘ and the left arrow): mail (w180) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +902 ms 729,72 871×630
- ~ **108 dock-left** (presses ⌃⌥⌘ and the left arrow): w182 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +902 ms 930,179 470×416
- ✘ **108 dock-left** (presses ⌃⌥⌘ and the left arrow): textedit (w335) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +902 ms 806,65 673×439
- ✘ **110 dock-right** (presses ⌃⌥⌘ and the right arrow): terminal (w170) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,238 793×499 · +1191 ms 541,238 457×499
- ✘ **110 dock-right** (presses ⌃⌥⌘ and the right arrow): notes (w171) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,32 794×791 · +1191 ms 417,32 709×791
- ✘ **110 dock-right** (presses ⌃⌥⌘ and the right arrow): calendar (w172) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,145 683×601 · +1191 ms 431,145 680×601
- ✘ **110 dock-right** (presses ⌃⌥⌘ and the right arrow): settings (w175) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,85 723×625 · +1191 ms 410,85 723×625
- ✘ **110 dock-right** (presses ⌃⌥⌘ and the right arrow): preview (w177) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,35 708×424 · +1191 ms 417,35 708×424
- ✘ **110 dock-right** (presses ⌃⌥⌘ and the right arrow): mail (w180) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 729,72 871×630 · +1191 ms 336,72 871×630
- ~ **110 dock-right** (presses ⌃⌥⌘ and the right arrow): w182 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 930,179 470×416 · +1191 ms 537,179 470×416
- ✘ **110 dock-right** (presses ⌃⌥⌘ and the right arrow): textedit (w335) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,65 673×439 · +1191 ms 541,65 461×439
- ✘ **116 launch** (starts Arbor): terminal (w170) a floating window, moved and came back, and the step did not name it [moved-unasked]
  - +0 ms 97,238 877×499 · +450 ms 1599,790 877×499 · +1298 ms 97,238 877×499
- ✘ **116 launch** (starts Arbor): notes (w171) a floating window, moved and came back, and the step did not name it [moved-unasked]
  - +0 ms -1,32 800×791 · +450 ms 1599,770 800×791 · +1298 ms 0,31 800×791
- ✘ **116 launch** (starts Arbor): calendar (w172) a floating window, moved and came back, and the step did not name it [moved-unasked]
  - +0 ms 385,145 683×601 · +450 ms 1599,770 683×601 · +1298 ms 385,145 683×601
- ✘ **116 launch** (starts Arbor): settings (w175) a floating window, moved and came back, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +450 ms 1599,770 723×625 · +1298 ms 437,85 723×625
- ✘ **116 launch** (starts Arbor): preview (w177) a floating window, moved and came back, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +450 ms 1599,770 708×424 · +1298 ms 4,35 708×424
- ✘ **116 launch** (starts Arbor): mail (w180) a floating window, moved and came back, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +450 ms 1599,770 1120×630 · +1298 ms 240,72 1120×630
- ~ **116 launch** (starts Arbor): w182 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +450 ms 1924,877 470×416 · +1298 ms 565,179 470×416
- ✘ **116 launch** (starts Arbor): textedit (w335) a floating window, moved and came back, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +497 ms 1599,790 673×439 · +1298 ms 165,65 673×439

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **29 dock-left** (presses ⌃⌥⌘ and the left arrow): the last window came to rest 2144 ms after the key or the button, in Arbor's first act since it started [slow]
- ~ **31 dock-right** (presses ⌃⌥⌘ and the right arrow): the last window came to rest 1062 ms after the key or the button [slow]
- ~ **33 dock-right** (presses ⌃⌥⌘ and the right arrow): the last window came to rest 743 ms after the key or the button [slow]
- ~ **35 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): the last window came to rest 924 ms after the key or the button [slow]
- ~ **53 view-frame** (presses ⌃⌥↩): the last window came to rest 1292 ms after the key or the button [slow]
- ~ **57 view-all** (presses ⌃⌥Space): the last window came to rest 729 ms after the key or the button [slow]
- ✘ **86 leave-full-screen** (presses ⌃⌘F again): safari (w156) moved 2 times [jolt]
  - +0 ms 0,0 1600×900 · +276 ms off the screen · +883 ms 138,31 1324×791 · +1929 ms 138,31 574×767 · +1964 ms 1014,43 574×767
- ✘ **95 drag-notes-to-left-edge** (drags notes by its title bar against the left edge of the screen and lets go): notes (w171) was 0 points ahead of the pointer's travel and 198 behind it at the most [pulled]
  - +0 ms 383,116 709×660 · +60 ms 358,127 709×660 · +116 ms 333,138 709×660 · +173 ms 282,160 709×660 · +259 ms 257,161 709×660 · +368 ms 231,161 709×660 · … 19 more … · +1953 ms -278,240 709×660 · +2065 ms -303,240 709×660 · +2140 ms -328,240 709×660 · +2357 ms -327,240 709×660 · +3867 ms -328,240 709×660
- ~ **98 drag-calendar-by** (drags calendar, which floats, by its title bar 0 across and 118 down, and clicks there 0.3 s after letting go): calendar (w172) changed its size while it was being dragged [jolt]
  - +0 ms 0,34 1600×791 · +83 ms 0,42 1600×791 · +125 ms 7,38 1582×788 · +133 ms 121,38 1311×731 · +149 ms 182,38 1165×701 · +216 ms 330,46 812×628 · … 23 more … · +1609 ms 385,137 681×601 · +1668 ms 385,141 681×601 · +1675 ms 385,145 681×601 · +1983 ms 386,145 681×601 · +2049 ms 385,145 681×601
- ~ **105 resume** (presses ⌃⌥⎋): w182 of Mail went 176 points out of its way before it ended up [jolt]
  - +0 ms 565,179 470×416 · +651 ms 441,179 470×416 · +684 ms 529,179 470×416
- ~ **110 dock-right** (presses ⌃⌥⌘ and the right arrow): the last window came to rest 956 ms after the key or the button [slow]
- ✘ **116 launch** (starts Arbor): safari (w156) moved 2 times [jolt]
  - +0 ms 138,31 1324×790 · +332 ms 12,43 1576×767 · +1298 ms 1599,770 1576×767
- ✘ **116 launch** (starts Arbor): terminal (w170) moved 2 times [jolt]
  - +0 ms 97,238 877×499 · +450 ms 1599,790 877×499 · +1298 ms 97,238 877×499
- ✘ **116 launch** (starts Arbor): notes (w171) moved 2 times [jolt]
  - +0 ms -1,32 800×791 · +450 ms 1599,770 800×791 · +1298 ms 0,31 800×791
- ✘ **116 launch** (starts Arbor): calendar (w172) moved 2 times [jolt]
  - +0 ms 385,145 683×601 · +450 ms 1599,770 683×601 · +1298 ms 385,145 683×601
- ✘ **116 launch** (starts Arbor): settings (w175) moved 2 times [jolt]
  - +0 ms 437,85 723×625 · +450 ms 1599,770 723×625 · +1298 ms 437,85 723×625
- ✘ **116 launch** (starts Arbor): preview (w177) moved 2 times [jolt]
  - +0 ms 4,35 708×424 · +450 ms 1599,770 708×424 · +1298 ms 4,35 708×424
- ✘ **116 launch** (starts Arbor): mail (w180) moved 2 times [jolt]
  - +0 ms 240,72 1120×630 · +450 ms 1599,770 1120×630 · +1298 ms 240,72 1120×630
- ✘ **116 launch** (starts Arbor): w182 of Mail moved 2 times [jolt]
  - +0 ms 565,179 470×416 · +450 ms 1924,877 470×416 · +1298 ms 565,179 470×416
- ✘ **116 launch** (starts Arbor): textedit (w335) moved 2 times [jolt]
  - +0 ms 165,65 673×439 · +497 ms 1599,790 673×439 · +1298 ms 165,65 673×439

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **106 float-all** (presses ⌃⌥⇧F): calendar (w172) has its size back but not its place: 385,145 683×601, it was at 445,205 683×601 [size-lost]
- ✘ **112 quit** (chooses Quit Arbor in Arbor's menu): calendar (w172) has its size back but not its place: 385,145 683×601, it was at 445,205 683×601 [size-lost]
- ✘ **118 quit** (chooses Quit Arbor in Arbor's menu): calendar (w172) has its size back but not its place: 385,145 683×601, it was at 445,205 683×601 [size-lost]

### Rule 6: what a person presses reaches the apps, at once

- ✘ **87 click-wallpaper** (clicks on the wallpaper): the button came up, and the apps heard of it 165 ms later [input-held]

### Rule L: no window is lost or stuck

- ✘ **116 launch** (starts Arbor): finder (w153) is out of view: 0% of it is on a display, at 1599,770 920×436 [lost]
- ✘ **116 launch** (starts Arbor): safari (w156) is out of view: 0% of it is on a display, at 1599,770 1576×767 [lost]

### Rule -: what the script itself checked

- ✘ **16 leave-alone** (does nothing for half a minute): with nothing to do Arbor used 1.6 % of a core [busy]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (2, 34 ms) | quiet 1105 ms; blind for 103 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 435 ms; blind for 1114 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (4, 323 ms) | quiet 1382 ms; blind for 163 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (5, 342 ms) | quiet 1262 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (3, 70 ms) | quiet 1058 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (4, 314 ms) | quiet 1380 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (2, 61 ms) | quiet 918 ms; blind for 269 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (3, 104 ms) | quiet 1030 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w182 ×1 (7, 159 ms) | quiet 711 ms; blind for 627 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (31, 3565 ms) | quiet 1093 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (29, 2904 ms) | quiet 1059 ms |  |  |  |  |  |  |  |  |
| 12 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (30, 3957 ms) | quiet 1397 ms |  |  |  |  |  |  |  |  |
| 13 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (37, 2945 ms) | quiet 1085 ms |  |  |  |  |  |  |  |  |
| 14 | look-around | looks at the screen |  | quiet 395 ms |  |  |  |  |  |  |  |  |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 15 | launch | starts Arbor |  | quiet 1085 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 16 | leave-alone | does nothing for half a minute |  | quiet 408 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |

### Switching between apps, nothing docked yet

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 17 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 356 ms; blind for 122 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 18 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 387 ms; blind for 194 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 351 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 384 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 412 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 22 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 359 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 488 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 372 ms; blind for 168 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 380 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 385 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 27 | cmd-tab-2 | holds ⌘ and presses Tab 2 time(s) |  | quiet 455 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### The first docks, by key

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 28 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 355 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 29 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms) | quiet 983 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 30 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 453 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms) | quiet 1137 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 32 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 412 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 607 ms |  | ✔ | ~ | ✔ |  |  | ✔ | ✔ |

### Docking by real drags

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 34 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 419 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | drag-terminal-onto-finder-right | drags terminal by its title bar onto the right part of finder and lets go | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms) | quiet 1089 ms | ✔ | ✘ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 36 | drag-terminal-out | drags terminal out of the arrangement onto the Desktop and lets go | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms) | quiet 1055 ms | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |

### Sizes

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 37 | click-finder | clicks finder's title bar |  | quiet 392 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | grow | presses ⌃⌥⌘= |  | quiet 708 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 39 | shrink | presses ⌃⌥⌘- |  | quiet 692 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 40 | balance | presses ⌃⌥⌘0 |  | quiet 668 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### Switching between apps, with an arrangement

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 41 | view-all | presses ⌃⌥Space |  | quiet 737 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 42 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 552 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 490 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 411 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 428 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 46 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 450 ms; blind for 101 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 438 ms; blind for 158 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 678 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 514 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 354 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 415 ms; blind for 151 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### The view goes in and out

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 52 | click-finder | clicks finder's title bar |  | quiet 387 ms; blind for 381 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 53 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms) | quiet 1555 ms; blind for 253 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 54 | dock-icon-safari | clicks safari's icon in the Dock | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 485 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 452 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 56 | dock-icon-calendar | clicks calendar's icon in the Dock | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms) | quiet 674 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 959 ms |  | ✘ | ~ |  |  |  | ✔ | ✔ |
| 58 | click-safari | clicks safari's title bar |  | quiet 453 ms; blind for 146 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 59 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms) | quiet 1197 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 60 | view-left | presses ⌃⌥← | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms) | quiet 997 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 61 | view-back | presses ⌃⌥[ | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms) | quiet 845 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 62 | view-out | presses ⌃⌥↑ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms) | quiet 1019 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 63 | view-desktop | presses ⌃⌥D | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1044 ms; blind for 110 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 64 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 938 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### Windows come and go

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 65 | click-safari | clicks safari's title bar |  | quiet 380 ms; blind for 156 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 66 | new-window-safari | presses ⌘N in safari |  | quiet 1766 ms; blind for 1751 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 67 | window-menu-safari | chooses safari's first window in the Window menu |  | quiet 1442 ms; blind for 181 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 68 | cmd-backtick | presses ⌘` for the app's next window |  | quiet 428 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 69 | close-window | presses ⌘W |  | quiet 1124 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 70 | click-safari | clicks safari's title bar |  | quiet 356 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 71 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms) | quiet 1173 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 72 | new-window-safari | presses ⌘N in safari |  | quiet 992 ms; blind for 222 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 73 | close-window | presses ⌘W |  | quiet 970 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 74 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms) | quiet 1143 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 75 | click-safari | clicks safari's title bar |  | quiet 363 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 76 | minimize-safari | presses ⌘M | safari ×1 (22, 473 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms) | quiet 1784 ms; blind for 129 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 77 | restore-safari | clicks its miniature in the Dock | safari ×1 (18, 474 ms), textedit ×1 (1, 0 ms) | quiet 1179 ms; blind for 101 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 78 | click-finder | clicks finder's title bar |  | quiet 418 ms; blind for 124 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 79 | hide-finder | presses ⌘H | safari ×1 (1, 0 ms), textedit ×1 (2, 18 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms) | quiet 1077 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 80 | unhide-finder | clicks its icon in the Dock | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 491 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 81 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 396 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 82 | quit-textedit | presses ⌘Q in textedit | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms) | quiet 1296 ms; blind for 111 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 83 | reopen-textedit | opens textedit's document again |  | quiet 1078 ms; blind for 523 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### Full screen

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 84 | click-safari | clicks safari's title bar |  | quiet 420 ms; blind for 160 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 85 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 355 ms; blind for 155 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 86 | leave-full-screen | presses ⌃⌘F again | safari ×2 (3, 1081 ms), terminal ×1 (1, 0 ms), notes ×1 (2, 16 ms), calendar ×1 (2, 14 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 482 ms |  | ✘ | ✘ | ✔ |  |  | ✔ | ✔ |

### A click lands on the wallpaper, a double-click on a title bar

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 87 | click-wallpaper | clicks on the wallpaper | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 449 ms; blind for 170 ms |  |  | ✔ |  |  | ✘ | ✔ | ✔ |
| 88 | click-wallpaper-again | clicks on the wallpaper again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 373 ms; blind for 113 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 89 | double-click-finder | double-clicks finder's title bar: macOS zooms the window | finder ×2 (12, 703 ms) | quiet 1078 ms | ✘ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 90 | double-click-finder-again | double-clicks it again: macOS takes the window back | finder ×2 (10, 663 ms) | quiet 1102 ms | ✘ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 91 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 504 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 92 | double-click-calendar | double-clicks calendar's title bar: macOS zooms the window | calendar ×1 (10, 330 ms) | quiet 885 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 93 | double-click-calendar-again | double-clicks it again: macOS takes the window back | calendar ×1 (10, 293 ms) | quiet 972 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### Where macOS tiles too

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 94 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 577 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 95 | drag-notes-to-left-edge | drags notes by its title bar against the left edge of the screen and lets go | notes ×1 (8, 275 ms) | quiet 373 ms | ✔ | ✔ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 96 | click-calendar | clicks calendar's title bar |  | quiet 390 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 97 | drag-calendar-to-top-edge | drags calendar by its title bar against the top edge of the screen and lets go | calendar ×1 (11, 314 ms) | quiet 376 ms | ✘ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 98 | drag-calendar-by | drags calendar, which floats, by its title bar 0 across and 118 down, and clicks there 0.3 s after letting go | calendar ×1 (2, 45 ms) | quiet 939 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 99 | view-all | presses ⌃⌥Space |  | quiet 693 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 100 | view-all | presses ⌃⌥Space |  | quiet 777 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### The ways out

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 101 | click-safari | clicks safari's title bar |  | quiet 499 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 102 | pause | presses ⌃⌥⎋ | finder ×1 (1, 0 ms), safari ×1 (2, 79 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1004 ms |  |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 103 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 479 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 104 | drag-calendar-by | drags calendar, which floats, by its title bar 60 across and 60 down |  | quiet 1071 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 105 | resume | presses ⌃⌥⎋ | finder ×1 (2, 41 ms), safari ×1 (1, 0 ms), terminal ×1 (2, 26 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (2, 33 ms), w182 ×1 (2, 33 ms), textedit ×1 (1, 0 ms) | quiet 1162 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 106 | float-all | presses ⌃⌥⇧F | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 933 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 107 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 413 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 108 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1170 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 109 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 455 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 110 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 864 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 111 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 852 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |

### Quit, and the next morning

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 112 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (2, 17 ms), safari ×1 (2, 69 ms), terminal ×1 (1, 0 ms), notes ×1 (2, 46 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w182 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 871 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 113 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 408 ms; blind for 127 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 114 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 424 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 115 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 494 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 116 | launch | starts Arbor | finder ×1 (1, 0 ms), safari ×2 (2, 966 ms), terminal ×2 (2, 848 ms), notes ×2 (2, 848 ms), calendar ×2 (2, 848 ms), settings ×2 (2, 848 ms), preview ×2 (2, 848 ms), mail ×2 (2, 848 ms), w182 ×2 (2, 848 ms), textedit ×2 (2, 801 ms) | quiet 934 ms |  | ✘ | ✘ |  |  |  | ✘ | ✔ |
| 117 | leave-alone | does nothing for half a minute |  | quiet 405 ms; blind for 132 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 118 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (2, 9 ms) | quiet 836 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 119 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 421 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 120 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 451 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 121 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 385 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 122 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 487 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 123 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 502 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 124 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 556 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 125 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 585 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 126 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 362 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 127 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 387 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
