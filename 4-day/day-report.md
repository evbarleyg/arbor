130 steps in 543 s, 115 of them judged, 22 with a rule broken. The sampler: samples 18855 seconds 493.4 hz 38.2 cost-ms 2.47 late 46 longest-gap-ms 908 whole-samples 20802 whole-seconds 544.3 whole-late 59.
Input: 361 presses, releases, keys and scrolls reached the apps, half of them within 649 µs, 99 in 100 within 87191 µs, the latest after 106869 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 39, 860, 5417; dragged 198, 649, 3585; forward 20, 6702, 99836; key 45, 359, 3034; up 59, 727, 106869. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): down 13, 714; dragged 20, 391; forward 12, 10927; key 13, 563; scroll 28, 357; up 25, 425.
The round of input `started` (events, half within µs): down 13, 798; dragged 20, 422; forward 12, 11863; key 13, 450; scroll 28, 454; up 25, 508.
The round of input `last` (events, half within µs): down 13, 1132; dragged 20, 531; forward 12, 14299; key 13, 605; scroll 28, 379; up 25, 504.
The round of input `after` (events, half within µs): down 13, 646; dragged 20, 394; forward 12, 13315; key 13, 523; scroll 28, 351; up 25, 360.
Judged: down, forward, up, key, dragged, scroll.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 10 | 3 | 90 double-click-finder, 91 double-click-finder-again, 95 drag-notes-to-left-edge |
| 2 | nothing moves that the person did not move | 101 | 12 | 32 dock-left, 34 dock-right, 38 drag-terminal-onto-finder-right, 60 view-all, 79 minimize-safari, 80 restore-safari, 82 hide-finder, 83 unhide-finder, 85 quit-textedit, 89 leave-full-screen, 108 dock-left, 110 dock-right |
| 3 | no jolts: a window moves once, to where it ends up | 117 | 1 | 79 minimize-safari |
| 4 | the window you switch to comes to the front and into view | 93 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 5 | 5 | 39 drag-terminal-out, 102 pause, 106 float-all, 112 quit, 120 quit |
| 6 | what a person presses reaches the apps, at once | 69 | 1 | 57 dock-icon-safari |
| L | no window is lost or stuck | 117 | 0 |  |
| - | what the script itself checked | 117 | 3 | 16 leave-alone-welcome-open, 112 quit, 120 quit |

## Findings

### Rule 1: never fight macOS: where it answers a drag, Arbor stands aside

- ✘ **90 double-click-finder** (double-clicks finder's title bar: macOS zooms the window): finder (w1395) macOS answered the double-click on its title bar, and it was moved again afterwards (2 moves) [fought]
  - +0 ms 12,43 501×767 · +1074 ms 12,43 503×747 · +1079 ms 12,43 507×710 · +1172 ms 12,43 518×592 · +1277 ms 12,43 543×335 · +1323 ms 12,43 546×306 · +1330 ms 12,43 549×276 · +1365 ms 12,43 551×261 · +1382 ms 12,43 551×253 · +1432 ms 12,43 551×252 · +1759 ms 12,43 501×767
- ✘ **91 double-click-finder-again** (double-clicks it again: macOS takes the window back): finder (w1395) macOS answered the double-click on its title bar, and it was moved again afterwards (2 moves) [fought]
  - +0 ms 12,43 501×767 · +954 ms 12,43 502×762 · +963 ms 12,43 503×749 · +992 ms 12,43 504×735 · +1058 ms 12,43 519×590 · +1123 ms 12,43 527×498 · +1176 ms 12,43 540×368 · +1242 ms 12,43 550×271 · +1301 ms 12,43 551×252 · +1654 ms 12,43 501×767
- ✘ **95 drag-notes-to-left-edge** (drags notes by its title bar against the left edge of the screen and lets go): notes (w1413) macOS's tiling preview and Arbor's drop preview were up at the same time, for 84 ms [fought]

### Rule 2: nothing moves that the person did not move

- ✘ **32 dock-left** (presses ⌃⌥⌘ and the left arrow): safari (w1398) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 217,31 1324×790 · +1267 ms 806,31 794×790
- ✘ **32 dock-left** (presses ⌃⌥⌘ and the left arrow): textedit (w1409) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +1267 ms 806,65 673×439
- ✘ **32 dock-left** (presses ⌃⌥⌘ and the left arrow): terminal (w1412) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 1600×791 · +1267 ms 806,31 794×791
- ✘ **32 dock-left** (presses ⌃⌥⌘ and the left arrow): notes (w1413) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +1267 ms 806,105 794×660
- ✘ **32 dock-left** (presses ⌃⌥⌘ and the left arrow): calendar (w1416) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 128,109 1600×791 · +1267 ms 806,31 794×791
- ✘ **32 dock-left** (presses ⌃⌥⌘ and the left arrow): settings (w1417) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +1267 ms 806,85 723×625
- ✘ **32 dock-left** (presses ⌃⌥⌘ and the left arrow): preview (w1421) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +1267 ms 806,35 708×424
- ✘ **32 dock-left** (presses ⌃⌥⌘ and the left arrow): mail (w1422) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1267 ms 729,72 871×630
- ~ **32 dock-left** (presses ⌃⌥⌘ and the left arrow): w1425 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1267 ms 930,179 470×416
- ✘ **32 dock-left** (presses ⌃⌥⌘ and the left arrow): desk-a (w1439) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,70 300×190 · +1267 ms 806,70 300×190
- ✘ **32 dock-left** (presses ⌃⌥⌘ and the left arrow): desk-b (w1441) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 360,70 300×190 · +1267 ms 806,70 300×190
- ✘ **34 dock-right** (presses ⌃⌥⌘ and the right arrow): textedit (w1409) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,65 673×439 · +1030 ms 541,65 461×439
- ✘ **34 dock-right** (presses ⌃⌥⌘ and the right arrow): terminal (w1412) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,31 794×791 · +1030 ms 541,31 461×791
- ✘ **34 dock-right** (presses ⌃⌥⌘ and the right arrow): notes (w1413) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,105 794×660 · +1030 ms 417,105 709×660
- ✘ **34 dock-right** (presses ⌃⌥⌘ and the right arrow): calendar (w1416) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,31 794×791 · +1030 ms 431,31 680×791
- ✘ **34 dock-right** (presses ⌃⌥⌘ and the right arrow): settings (w1417) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,85 723×625 · +1030 ms 410,85 723×625
- ✘ **34 dock-right** (presses ⌃⌥⌘ and the right arrow): preview (w1421) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,35 708×424 · +1030 ms 417,35 708×424
- ✘ **34 dock-right** (presses ⌃⌥⌘ and the right arrow): mail (w1422) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 729,72 871×630 · +1030 ms 336,72 871×630
- ~ **34 dock-right** (presses ⌃⌥⌘ and the right arrow): w1425 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 930,179 470×416 · +1030 ms 537,179 470×416
- ✘ **34 dock-right** (presses ⌃⌥⌘ and the right arrow): desk-a (w1439) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,70 300×190 · +1030 ms 541,70 300×190
- ✘ **34 dock-right** (presses ⌃⌥⌘ and the right arrow): desk-b (w1441) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,70 300×190 · +1030 ms 541,70 300×190
- ✘ **38 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): notes (w1413) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 417,105 709×660 · +5313 ms 202,105 709×660
- ✘ **38 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): calendar (w1416) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 431,31 680×791 · +5313 ms 217,31 680×791
- ✘ **38 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): settings (w1417) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 410,85 723×625 · +5313 ms 195,85 723×625
- ✘ **38 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): preview (w1421) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 417,35 708×424 · +5313 ms 203,35 708×424
- ✘ **38 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): mail (w1422) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 336,72 871×630 · +5313 ms 121,72 871×630
- ~ **38 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): w1425 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 537,179 470×416 · +5313 ms 322,179 470×416
- ✘ **38 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): desk-a (w1439) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 541,70 300×190 · +5313 ms 404,70 300×190
- ✘ **38 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): desk-b (w1441) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 541,70 300×190 · +5313 ms 404,70 300×190
- ✘ **60 view-all** (presses ⌃⌥Space): notes (w1413) is not back where it was after step 44: 300,105 1000×660, it was at 202,105 709×660 [moved-unasked]
- ✘ **60 view-all** (presses ⌃⌥Space): calendar (w1416) is not back where it was after step 44: 0,31 1600×791, it was at 217,31 680×791 [moved-unasked]
- ✘ **60 view-all** (presses ⌃⌥Space): settings (w1417) is not back where it was after step 44: 437,85 723×625, it was at 195,85 723×625 [moved-unasked]
- ✘ **60 view-all** (presses ⌃⌥Space): preview (w1421) is not back where it was after step 44: 4,35 708×424, it was at 203,35 708×424 [moved-unasked]
- ✘ **60 view-all** (presses ⌃⌥Space): mail (w1422) is not back where it was after step 44: 240,72 1120×630, it was at 121,72 871×630 [moved-unasked]
- ✘ **60 view-all** (presses ⌃⌥Space): w1425 of Mail is not back where it was after step 44: 565,179 470×416, it was at 322,179 470×416 [moved-unasked]
- ✘ **60 view-all** (presses ⌃⌥Space): desk-a (w1439) is not back where it was after step 44: 40,70 300×190, it was at 404,70 300×190 [moved-unasked]
- ✘ **60 view-all** (presses ⌃⌥Space): desk-b (w1441) is not back where it was after step 44: 360,70 300×190, it was at 404,70 300×190 [moved-unasked]
- ✘ **79 minimize-safari** (presses ⌘M): terminal (w1412) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 106,238 863×500 · +1277 ms 525,238 429×500
- ✘ **79 minimize-safari** (presses ⌘M): notes (w1413) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +1277 ms 386,105 709×660
- ✘ **79 minimize-safari** (presses ⌘M): calendar (w1416) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 1600×791 · +1277 ms 401,31 680×791 · +1664 ms 401,33 680×791
- ✘ **79 minimize-safari** (presses ⌘M): settings (w1417) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +1277 ms 379,85 723×625
- ✘ **79 minimize-safari** (presses ⌘M): preview (w1421) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +1277 ms 387,35 708×424
- ✘ **79 minimize-safari** (presses ⌘M): mail (w1422) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1277 ms 305,72 871×630
- ~ **79 minimize-safari** (presses ⌘M): w1425 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1277 ms 506,179 470×416
- ✘ **79 minimize-safari** (presses ⌘M): desk-a (w1439) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,70 300×190 · +1277 ms 525,70 300×190
- ✘ **79 minimize-safari** (presses ⌘M): desk-b (w1441) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 360,70 300×190 · +1277 ms 525,70 300×190
- ✘ **80 restore-safari** (clicks its miniature in the Dock): terminal (w1412) is not back where it was after step 78: 525,238 429×500, it was at 106,238 863×500 [moved-unasked]
- ✘ **80 restore-safari** (clicks its miniature in the Dock): notes (w1413) is not back where it was after step 78: 386,105 709×660, it was at 300,105 1000×660 [moved-unasked]
- ✘ **80 restore-safari** (clicks its miniature in the Dock): calendar (w1416) is not back where it was after step 78: 401,33 680×791, it was at 0,31 1600×791 [moved-unasked]
- ✘ **80 restore-safari** (clicks its miniature in the Dock): settings (w1417) is not back where it was after step 78: 379,85 723×625, it was at 437,85 723×625 [moved-unasked]
- ✘ **80 restore-safari** (clicks its miniature in the Dock): preview (w1421) is not back where it was after step 78: 387,35 708×424, it was at 4,35 708×424 [moved-unasked]
- ✘ **80 restore-safari** (clicks its miniature in the Dock): mail (w1422) is not back where it was after step 78: 305,72 871×630, it was at 240,72 1120×630 [moved-unasked]
- ✘ **80 restore-safari** (clicks its miniature in the Dock): w1425 of Mail is not back where it was after step 78: 506,179 470×416, it was at 565,179 470×416 [moved-unasked]
- ✘ **80 restore-safari** (clicks its miniature in the Dock): desk-a (w1439) is not back where it was after step 78: 525,70 300×190, it was at 40,70 300×190 [moved-unasked]
- ✘ **80 restore-safari** (clicks its miniature in the Dock): desk-b (w1441) is not back where it was after step 78: 525,70 300×190, it was at 360,70 300×190 [moved-unasked]
- ✘ **82 hide-finder** (presses ⌘H): terminal (w1412) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 525,238 429×500 · +426 ms 0,238 324×500
- ✘ **82 hide-finder** (presses ⌘H): notes (w1413) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 386,105 709×660 · +426 ms 0,105 709×660
- ✘ **82 hide-finder** (presses ⌘H): calendar (w1416) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 401,33 680×791 · +494 ms 0,31 680×791
- ✘ **82 hide-finder** (presses ⌘H): settings (w1417) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 379,85 723×625 · +494 ms 0,85 723×625
- ✘ **82 hide-finder** (presses ⌘H): preview (w1421) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 387,35 708×424 · +494 ms 0,35 708×424
- ✘ **82 hide-finder** (presses ⌘H): mail (w1422) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 305,72 871×630 · +494 ms 0,72 871×630
- ~ **82 hide-finder** (presses ⌘H): w1425 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 506,179 470×416 · +494 ms 201,179 470×416
- ✘ **82 hide-finder** (presses ⌘H): desk-a (w1439) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 525,70 300×190 · +494 ms 24,70 300×190
- ✘ **82 hide-finder** (presses ⌘H): desk-b (w1441) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 525,70 300×190 · +494 ms 24,70 300×190
- ✘ **83 unhide-finder** (clicks its icon in the Dock): terminal (w1412) is not back where it was after step 81: 0,238 324×500, it was at 525,238 429×500 [moved-unasked]
- ✘ **83 unhide-finder** (clicks its icon in the Dock): notes (w1413) is not back where it was after step 81: 0,105 709×660, it was at 386,105 709×660 [moved-unasked]
- ✘ **83 unhide-finder** (clicks its icon in the Dock): calendar (w1416) is not back where it was after step 81: 0,31 680×791, it was at 401,33 680×791 [moved-unasked]
- ✘ **83 unhide-finder** (clicks its icon in the Dock): settings (w1417) is not back where it was after step 81: 0,85 723×625, it was at 379,85 723×625 [moved-unasked]
- ✘ **83 unhide-finder** (clicks its icon in the Dock): preview (w1421) is not back where it was after step 81: 0,35 708×424, it was at 387,35 708×424 [moved-unasked]
- ✘ **83 unhide-finder** (clicks its icon in the Dock): mail (w1422) is not back where it was after step 81: 0,72 871×630, it was at 305,72 871×630 [moved-unasked]
- ✘ **83 unhide-finder** (clicks its icon in the Dock): w1425 of Mail is not back where it was after step 81: 201,179 470×416, it was at 506,179 470×416 [moved-unasked]
- ✘ **83 unhide-finder** (clicks its icon in the Dock): desk-a (w1439) is not back where it was after step 81: 24,70 300×190, it was at 525,70 300×190 [moved-unasked]
- ✘ **83 unhide-finder** (clicks its icon in the Dock): desk-b (w1441) is not back where it was after step 81: 24,70 300×190, it was at 525,70 300×190 [moved-unasked]
- ✘ **85 quit-textedit** (presses ⌘Q in textedit): terminal (w1412) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,238 324×500 · +1045 ms 525,238 478×500
- ✘ **85 quit-textedit** (presses ⌘Q in textedit): notes (w1413) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,105 709×660 · +1045 ms 409,105 709×660
- ✘ **85 quit-textedit** (presses ⌘Q in textedit): calendar (w1416) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 680×791 · +1045 ms 423,31 680×791
- ✘ **85 quit-textedit** (presses ⌘Q in textedit): settings (w1417) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,85 723×625 · +1045 ms 402,85 723×625
- ✘ **85 quit-textedit** (presses ⌘Q in textedit): preview (w1421) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,35 708×424 · +1045 ms 409,35 708×424
- ✘ **85 quit-textedit** (presses ⌘Q in textedit): mail (w1422) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,72 871×630 · +1045 ms 328,72 871×630
- ~ **85 quit-textedit** (presses ⌘Q in textedit): w1425 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 201,179 470×416 · +1045 ms 529,179 470×416
- ✘ **85 quit-textedit** (presses ⌘Q in textedit): desk-a (w1439) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 24,70 300×190 · +1045 ms 525,70 300×190
- ✘ **85 quit-textedit** (presses ⌘Q in textedit): desk-b (w1441) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 24,70 300×190 · +1045 ms 525,70 300×190
- ✘ **89 leave-full-screen** (presses ⌃⌘F again): textedit (w1624) is not back where it was after step 87: 525,65 477×439, it was at 165,65 673×439 [moved-unasked]
- ✘ **108 dock-left** (presses ⌃⌥⌘ and the left arrow): safari (w1398) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 217,31 1324×790 · +775 ms 806,31 794×790
- ✘ **108 dock-left** (presses ⌃⌥⌘ and the left arrow): terminal (w1412) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 106,238 863×500 · +775 ms 806,238 793×500
- ✘ **108 dock-left** (presses ⌃⌥⌘ and the left arrow): notes (w1413) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms -1,32 800×791 · +775 ms 806,32 794×791
- ✘ **108 dock-left** (presses ⌃⌥⌘ and the left arrow): calendar (w1416) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 385,145 682×791 · +775 ms 806,145 682×791
- ✘ **108 dock-left** (presses ⌃⌥⌘ and the left arrow): settings (w1417) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +775 ms 806,85 723×625
- ✘ **108 dock-left** (presses ⌃⌥⌘ and the left arrow): preview (w1421) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +775 ms 806,35 708×424
- ✘ **108 dock-left** (presses ⌃⌥⌘ and the left arrow): mail (w1422) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +775 ms 729,72 871×630
- ~ **108 dock-left** (presses ⌃⌥⌘ and the left arrow): w1425 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +775 ms 930,179 470×416
- ✘ **108 dock-left** (presses ⌃⌥⌘ and the left arrow): desk-a (w1439) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,70 300×190 · +775 ms 806,70 300×190
- ✘ **108 dock-left** (presses ⌃⌥⌘ and the left arrow): desk-b (w1441) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 360,70 300×190 · +775 ms 806,70 300×190
- ✘ **108 dock-left** (presses ⌃⌥⌘ and the left arrow): textedit (w1624) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +775 ms 806,65 673×439
- ✘ **110 dock-right** (presses ⌃⌥⌘ and the right arrow): terminal (w1412) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,238 793×500 · +1060 ms 541,238 457×500
- ✘ **110 dock-right** (presses ⌃⌥⌘ and the right arrow): notes (w1413) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,32 794×791 · +1060 ms 417,32 709×791
- ✘ **110 dock-right** (presses ⌃⌥⌘ and the right arrow): calendar (w1416) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,145 682×791 · +1060 ms 431,145 680×791
- ✘ **110 dock-right** (presses ⌃⌥⌘ and the right arrow): settings (w1417) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,85 723×625 · +1060 ms 410,85 723×625
- ✘ **110 dock-right** (presses ⌃⌥⌘ and the right arrow): preview (w1421) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,35 708×424 · +1060 ms 417,35 708×424
- ✘ **110 dock-right** (presses ⌃⌥⌘ and the right arrow): mail (w1422) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 729,72 871×630 · +1060 ms 336,72 871×630
- ~ **110 dock-right** (presses ⌃⌥⌘ and the right arrow): w1425 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 930,179 470×416 · +1060 ms 537,179 470×416
- ✘ **110 dock-right** (presses ⌃⌥⌘ and the right arrow): desk-a (w1439) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,70 300×190 · +1060 ms 541,70 300×190
- ✘ **110 dock-right** (presses ⌃⌥⌘ and the right arrow): desk-b (w1441) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,70 300×190 · +1060 ms 541,70 300×190
- ✘ **110 dock-right** (presses ⌃⌥⌘ and the right arrow): textedit (w1624) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,65 673×439 · +1060 ms 541,65 461×439

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **38 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): terminal (w1412) changed its size while it was being dragged [jolt]
  - +0 ms 529,43 461×791 · +69 ms 518,69 461×791 · +121 ms 518,69 539×735 · +196 ms 365,56 789×554 · +207 ms 354,69 789×554 · +264 ms 317,82 846×512 · … 23 more … · +1923 ms 51,375 863×500 · +1977 ms 40,388 863×500 · +2004 ms 29,401 863×500 · +2277 ms 30,401 863×500 · +2398 ms 29,401 863×500
- ~ **38 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): the last window came to rest 1275 ms after the key or the button [slow]
- ~ **39 drag-terminal-out** (drags terminal out of the arrangement onto the Desktop and lets go): the last window came to rest 717 ms after the key or the button [slow]
- ~ **62 view-frame** (presses ⌃⌥↩): the last window came to rest 730 ms after the key or the button [slow]
- ~ **65 view-out** (presses ⌃⌥↑): the last window came to rest 728 ms after the key or the button [slow]
- ~ **66 view-desktop** (presses ⌃⌥D): the last window came to rest 724 ms after the key or the button [slow]
- ~ **67 view-all** (presses ⌃⌥Space): the last window came to rest 723 ms after the key or the button [slow]
- ~ **77 view-all** (presses ⌃⌥Space): the last window came to rest 703 ms after the key or the button [slow]
- ✘ **79 minimize-safari** (presses ⌘M): textedit (w1409) moved 2 times [jolt]
  - +0 ms 1203,43 385×767 · +1277 ms 969,43 619×767 · +1657 ms 969,43 619×769
- ✘ **79 minimize-safari** (presses ⌘M): calendar (w1416) moved 2 times [jolt]
  - +0 ms 0,31 1600×791 · +1277 ms 401,31 680×791 · +1664 ms 401,33 680×791
- ~ **98 drag-calendar-by** (drags calendar, which floats, by its title bar 0 across and 118 down, and clicks there 0.3 s after letting go): calendar (w1416) changed its size while it was being dragged [jolt]
  - +0 ms 0,34 1600×791 · +100 ms 0,42 1600×791 · +119 ms 28,38 1531×791 · +192 ms 257,38 987×791 · +205 ms 257,42 987×791 · +252 ms 354,42 757×791 · … 25 more … · +1609 ms 385,137 681×791 · +1716 ms 385,141 681×791 · +1783 ms 385,145 681×791 · +2074 ms 386,145 681×791 · +2115 ms 385,145 681×791
- ~ **102 pause** (presses ⌃⌥⎋): w1425 of Mail went 176 points out of its way before it ended up [jolt]
  - +0 ms 529,179 470×416 · +875 ms 653,179 470×416 · +930 ms 565,179 470×416
- ~ **105 resume** (presses ⌃⌥⎋): w1425 of Mail went 176 points out of its way before it ended up [jolt]
  - +0 ms 565,179 470×416 · +760 ms 441,179 470×416 · +802 ms 529,179 470×416
- ~ **110 dock-right** (presses ⌃⌥⌘ and the right arrow): the last window came to rest 760 ms after the key or the button [slow]
- ~ **112 quit** (chooses Quit Arbor in Arbor's menu): w1425 of Mail went 248 points out of its way before it ended up [jolt]
  - +0 ms 1800,877 470×416 · +2901 ms 1924,877 470×416 · +2977 ms 565,179 470×416

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **39 drag-terminal-out** (drags terminal out of the arrangement onto the Desktop and lets go): terminal (w1412) is 106,238 863×500; its own size was 0,31 1600×791 [size-lost]
- ✘ **102 pause** (presses ⌃⌥⎋): terminal (w1412) is 106,238 863×500; its own size was 106,238 1600×791 [size-lost]
- ✘ **106 float-all** (presses ⌃⌥⇧F): terminal (w1412) is 106,238 863×500; its own size was 106,238 1600×791 [size-lost]
- ✘ **106 float-all** (presses ⌃⌥⇧F): calendar (w1416) has its size back but not its place: 385,145 682×791, it was at 445,205 681×791 [size-lost]
- ✘ **112 quit** (chooses Quit Arbor in Arbor's menu): terminal (w1412) is 106,238 863×500; its own size was 106,238 1600×791 [size-lost]
- ✘ **112 quit** (chooses Quit Arbor in Arbor's menu): calendar (w1416) has its size back but not its place: 385,145 682×791, it was at 445,205 681×791 [size-lost]
- ✘ **120 quit** (chooses Quit Arbor in Arbor's menu): terminal (w1412) is 106,238 863×500; its own size was 106,238 1600×791 [size-lost]
- ✘ **120 quit** (chooses Quit Arbor in Arbor's menu): calendar (w1416) has its size back but not its place: 385,145 682×791, it was at 445,205 681×791 [size-lost]

### Rule 6: what a person presses reaches the apps, at once

- ✘ **57 dock-icon-safari** (clicks safari's icon in the Dock): the button came up, and the apps heard of it 106 ms later [input-held]

### Rule -: what the script itself checked

- ✘ **16 leave-alone-welcome-open** (does nothing for half a minute, with Arbor's welcome window open): with nothing to do Arbor used 1.7 % of a core [busy]
- ✘ **112 quit** (chooses Quit Arbor in Arbor's menu): Arbor's process ended, and nobody asked it to [crash]
- ✘ **120 quit** (chooses Quit Arbor in Arbor's menu): Arbor's process ended, and nobody asked it to [crash]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (3, 86 ms) | quiet 937 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 359 ms; blind for 1664 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (4, 268 ms) | quiet 1242 ms; blind for 271 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (4, 268 ms) | quiet 1315 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (2, 61 ms) | quiet 1023 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (4, 274 ms) | quiet 1338 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings |  | quiet 895 ms; blind for 757 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (3, 95 ms) | quiet 1083 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w1425 ×1 (6, 165 ms) | quiet 687 ms; blind for 697 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (30, 2228 ms) | quiet 1079 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (26, 2944 ms) | quiet 1094 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 382 ms |  |  |  |  |  |  |  |  |
| 13 | open-desks | opens the two windows that input is tried on | desk-a ×1 (4, 67 ms), desk-b ×1 (1, 0 ms) | quiet 425 ms |  |  |  |  |  |  |  |  |
| 14 | input-before | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 876 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 15 | launch | starts Arbor |  | quiet 951 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 16 | leave-alone-welcome-open | does nothing for half a minute, with Arbor's welcome window open |  | quiet 369 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 17 | close-welcome | closes Arbor's welcome window with its red button |  | quiet 1241 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 18 | input-started | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 874 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | leave-alone | does nothing for half a minute |  | quiet 436 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### Switching between apps, nothing docked yet

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 20 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 450 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 386 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 22 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 416 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 372 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 405 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 392 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 440 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 440 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 466 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 29 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 395 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 30 | cmd-tab-2 | holds ⌘ and presses Tab 2 time(s) |  | quiet 450 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### The first docks, by key

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 31 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 375 ms; blind for 133 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1425 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 967 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 33 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 398 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1425 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 814 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 35 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 423 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 36 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 559 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### Docking by real drags

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 37 | click-terminal | clicks terminal's title bar |  | quiet 408 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | drag-terminal-onto-finder-right | drags terminal by its title bar onto the right part of finder and lets go | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1425 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 921 ms | ✔ | ✘ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | drag-terminal-out | drags terminal out of the arrangement onto the Desktop and lets go | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms) | quiet 955 ms | ✔ | ✔ | ~ | ✔ | ✘ | ✔ | ✔ | ✔ |

### Sizes

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 40 | click-finder | clicks finder's title bar |  | quiet 392 ms; blind for 103 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | grow | presses ⌃⌥⌘= |  | quiet 624 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 42 | shrink | presses ⌃⌥⌘- |  | quiet 797 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 43 | balance | presses ⌃⌥⌘0 |  | quiet 551 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### Switching between apps, with an arrangement

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 44 | view-all | presses ⌃⌥Space |  | quiet 683 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 45 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 426 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 46 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 376 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 417 ms; blind for 108 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 368 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 437 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 427 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 675 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 392 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 53 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 421 ms; blind for 100 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 54 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 501 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### The view goes in and out

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 55 | click-finder | clicks finder's title bar |  | quiet 461 ms; blind for 104 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 56 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1425 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1178 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 57 | dock-icon-safari | clicks safari's icon in the Dock | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 564 ms; blind for 120 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 58 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 458 ms; blind for 210 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 59 | dock-icon-calendar | clicks calendar's icon in the Dock | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1425 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 795 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 886 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 61 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 350 ms; blind for 132 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 62 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1425 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 960 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 63 | view-left | presses ⌃⌥← | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1425 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 914 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 64 | view-back | presses ⌃⌥[ | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1425 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 742 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 65 | view-out | presses ⌃⌥↑ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1425 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 740 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 66 | view-desktop | presses ⌃⌥D | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 899 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 67 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 713 ms |  | ✔ | ~ |  |  |  | ✔ | ✔ |

### Windows come and go

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 68 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 427 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 69 | new-window-safari | presses ⌘N in safari |  | quiet 1090 ms; blind for 908 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 70 | window-menu-safari | chooses safari's first window in the Window menu |  | quiet 1415 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 71 | cmd-backtick | presses ⌘` for the app's next window |  | quiet 510 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 72 | close-window | presses ⌘W |  | quiet 1056 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 73 | click-safari | clicks safari's title bar |  | quiet 444 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 74 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1425 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1339 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 75 | new-window-safari | presses ⌘N in safari |  | quiet 1036 ms; blind for 196 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 76 | close-window | presses ⌘W |  | quiet 941 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 77 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1425 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 890 ms |  | ✔ | ~ |  |  |  | ✔ | ✔ |
| 78 | click-safari | clicks safari's title bar |  | quiet 462 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 79 | minimize-safari | presses ⌘M | finder ×1 (1, 0 ms), safari ×1 (15, 496 ms), textedit ×2 (2, 380 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×2 (2, 387 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1425 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1683 ms; blind for 224 ms |  | ✘ | ✘ |  |  |  | ✔ | ✔ |
| 80 | restore-safari | clicks its miniature in the Dock | finder ×1 (1, 0 ms), safari ×1 (15, 649 ms), textedit ×1 (2, 36 ms) | quiet 907 ms; blind for 222 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 81 | click-finder | clicks finder's title bar |  | quiet 402 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 82 | hide-finder | presses ⌘H | safari ×1 (1, 0 ms), textedit ×1 (2, 10 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1425 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1211 ms; blind for 164 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 83 | unhide-finder | clicks its icon in the Dock | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 493 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 84 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 413 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 85 | quit-textedit | presses ⌘Q in textedit | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1425 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1138 ms; blind for 132 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 86 | reopen-textedit | opens textedit's document again |  | quiet 1134 ms; blind for 292 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### Full screen

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 87 | click-safari | clicks safari's title bar |  | quiet 452 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 88 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 407 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 89 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 387 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |

### A click lands on the wallpaper, a double-click on a title bar

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 90 | double-click-finder | double-clicks finder's title bar: macOS zooms the window | finder ×2 (10, 685 ms) | quiet 955 ms; blind for 103 ms | ✘ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 91 | double-click-finder-again | double-clicks it again: macOS takes the window back | finder ×2 (9, 700 ms) | quiet 1031 ms | ✘ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 92 | double-click-calendar | double-clicks calendar's title bar: macOS zooms the window | calendar ×1 (12, 342 ms) | quiet 739 ms; blind for 115 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 93 | double-click-calendar-again | double-clicks it again: macOS takes the window back | calendar ×1 (13, 352 ms) | quiet 814 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### Where macOS tiles too

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 94 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 418 ms; blind for 120 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 95 | drag-notes-to-left-edge | drags notes by its title bar against the left edge of the screen and lets go | notes ×1 (8, 271 ms) | quiet 426 ms; blind for 107 ms | ✘ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 96 | click-calendar | clicks calendar's title bar |  | quiet 509 ms; blind for 102 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 97 | drag-calendar-to-top-edge | drags calendar by its title bar against the top edge of the screen and lets go | calendar ×1 (9, 312 ms) | quiet 374 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 98 | drag-calendar-by | drags calendar, which floats, by its title bar 0 across and 118 down, and clicks there 0.3 s after letting go | calendar ×1 (2, 43 ms) | quiet 941 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 99 | view-all | presses ⌃⌥Space |  | quiet 745 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 100 | view-all | presses ⌃⌥Space |  | quiet 788 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### The ways out

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 101 | click-safari | clicks safari's title bar |  | quiet 432 ms; blind for 111 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 102 | pause | presses ⌃⌥⎋ | finder ×1 (2, 16 ms), safari ×1 (2, 120 ms), terminal ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (2, 55 ms), w1425 ×1 (2, 55 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (2, 24 ms) | quiet 1386 ms |  |  | ~ | ✔ | ✘ |  | ✔ | ✔ |
| 103 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 489 ms; blind for 115 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 104 | drag-calendar-by | drags calendar, which floats, by its title bar 60 across and 60 down |  | quiet 1037 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 105 | resume | presses ⌃⌥⎋ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (2, 42 ms), w1425 ×1 (2, 42 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1345 ms |  | ✔ | ~ |  |  |  | ✔ | ✔ |
| 106 | float-all | presses ⌃⌥⇧F | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1425 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1126 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 107 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 547 ms; blind for 155 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 108 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1425 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1021 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 109 | click-safari | clicks safari's title bar |  | quiet 468 ms; blind for 111 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 110 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1425 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1198 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 111 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1425 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1118 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |

### Quit, and the next morning

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 112 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (3, 49 ms), terminal ×1 (1, 0 ms), notes ×1 (2, 39 ms), calendar ×1 (2, 43 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (2, 76 ms), w1425 ×1 (2, 76 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 808 ms |  |  | ~ |  | ✘ |  | ✔ | ✘ |
| 113 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 396 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 114 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 393 ms; blind for 112 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 115 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 466 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 116 | launch | starts Arbor | finder ×1 (2, 40 ms), safari ×1 (1, 0 ms) | quiet 884 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 117 | leave-alone | does nothing for half a minute |  | quiet 400 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 118 | view-home | presses ⌃⌥0 |  | quiet 590 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 119 | input-last | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 917 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 120 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (2, 84 ms) | quiet 843 ms |  |  | ✔ |  | ✘ |  | ✔ | ✘ |
| 121 | input-after | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 898 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 122 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 385 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 123 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 356 ms; blind for 103 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 124 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 358 ms; blind for 120 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 125 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 362 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 126 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 400 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 127 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 535 ms; blind for 120 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 128 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 550 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 129 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 381 ms; blind for 102 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 130 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 368 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
