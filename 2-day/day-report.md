131 steps in 457 s, 115 of them judged, 20 with a rule broken. The sampler: samples 15374 seconds 394.3 hz 39.0 cost-ms 1.93 late 19 longest-gap-ms 795 whole-samples 17873 whole-seconds 458.4 whole-late 37.
Input: 364 presses, releases, keys and scrolls reached the apps, half of them within 515 µs, 99 in 100 within 41387 µs, the latest after 52917 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 52, 644, 6874; dragged 198, 517, 6373; forward 9, 37849, 52917; key 44, 225, 766; up 61, 541, 52516. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 12, 33698; up 12, 378.
The round of input `started` (events, half within µs): forward 12, 33120; up 12, 407.
The round of input `last` (events, half within µs): forward 13, 43149; up 13, 1976.
The round of input `after` (events, half within µs): forward 8, 32171; up 8, 614.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 10 | 3 | 91 double-click-finder, 92 double-click-finder-again, 97 drag-notes-to-left-edge |
| 2 | nothing moves that the person did not move | 101 | 12 | 31 dock-left, 33 dock-right, 37 drag-terminal-onto-finder-right, 59 view-all, 78 minimize-safari, 79 restore-safari, 81 hide-finder, 82 unhide-finder, 84 quit-textedit, 88 leave-full-screen, 110 dock-left, 112 dock-right |
| 3 | no jolts: a window moves once, to where it ends up | 117 | 1 | 38 drag-terminal-out |
| 4 | the window you switch to comes to the front and into view | 89 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 5 | 3 | 108 float-all, 114 quit, 121 quit |
| 6 | what a person presses reaches the apps, at once | 71 | 0 |  |
| L | no window is lost or stuck | 117 | 0 |  |
| - | what the script itself checked | 117 | 1 | 18 leave-alone |

## Findings

### Rule 1: never fight macOS: where it answers a drag, Arbor stands aside

- ✘ **91 double-click-finder** (double-clicks finder's title bar: macOS zooms the window): finder (w170) macOS answered the double-click on its title bar, and it was moved again afterwards (2 moves) [fought]
  - +0 ms 12,43 501×767 · +954 ms 12,43 501×766 · +993 ms 12,43 505×732 · +1039 ms 12,43 509×684 · +1045 ms 12,43 512×653 · +1063 ms 12,43 516×620 · … 5 more … · +1184 ms 12,43 542×353 · +1210 ms 12,43 546×308 · +1267 ms 12,43 551×258 · +1298 ms 12,43 551×252 · +1653 ms 12,43 501×767
- ✘ **92 double-click-finder-again** (double-clicks it again: macOS takes the window back): finder (w170) macOS answered the double-click on its title bar, and it was moved again afterwards (2 moves) [fought]
  - +0 ms 12,43 501×767 · +834 ms 12,43 502×765 · +843 ms 12,43 503×749 · +857 ms 12,43 504×737 · +892 ms 12,43 509×686 · +917 ms 12,43 513×651 · … 3 more … · +1059 ms 12,43 544×325 · +1101 ms 12,43 550×265 · +1126 ms 12,43 551×256 · +1175 ms 12,43 551×252 · +1557 ms 12,43 501×767
- ✘ **97 drag-notes-to-left-edge** (drags notes by its title bar against the left edge of the screen and lets go): notes (w188) macOS's tiling preview and Arbor's drop preview were up at the same time [fought]

### Rule 2: nothing moves that the person did not move

- ✘ **31 dock-left** (presses ⌃⌥⌘ and the left arrow): safari (w173) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×791 · +2502 ms 806,31 794×791
- ✘ **31 dock-left** (presses ⌃⌥⌘ and the left arrow): textedit (w182) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +2502 ms 806,65 673×439
- ✘ **31 dock-left** (presses ⌃⌥⌘ and the left arrow): terminal (w187) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 740,300 877×499 · +2502 ms 806,300 793×499
- ✘ **31 dock-left** (presses ⌃⌥⌘ and the left arrow): notes (w188) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +2502 ms 806,105 794×660
- ✘ **31 dock-left** (presses ⌃⌥⌘ and the left arrow): calendar (w189) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 403,115 937×600 · +2502 ms 806,115 794×600
- ✘ **31 dock-left** (presses ⌃⌥⌘ and the left arrow): settings (w192) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +2502 ms 806,85 723×625
- ✘ **31 dock-left** (presses ⌃⌥⌘ and the left arrow): preview (w194) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +2502 ms 806,35 708×424
- ✘ **31 dock-left** (presses ⌃⌥⌘ and the left arrow): mail (w197) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +2502 ms 729,72 871×630
- ~ **31 dock-left** (presses ⌃⌥⌘ and the left arrow): w200 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +2502 ms 930,179 470×416
- ✘ **33 dock-right** (presses ⌃⌥⌘ and the right arrow): textedit (w182) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,65 673×439 · +1056 ms 541,65 461×439
- ✘ **33 dock-right** (presses ⌃⌥⌘ and the right arrow): terminal (w187) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,300 793×499 · +1056 ms 541,300 457×499
- ✘ **33 dock-right** (presses ⌃⌥⌘ and the right arrow): notes (w188) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,105 794×660 · +1056 ms 417,105 709×660
- ✘ **33 dock-right** (presses ⌃⌥⌘ and the right arrow): calendar (w189) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,115 794×600 · +1056 ms 431,115 680×600
- ✘ **33 dock-right** (presses ⌃⌥⌘ and the right arrow): settings (w192) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,85 723×625 · +1056 ms 410,85 723×625
- ✘ **33 dock-right** (presses ⌃⌥⌘ and the right arrow): preview (w194) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,35 708×424 · +1056 ms 417,35 708×424
- ✘ **33 dock-right** (presses ⌃⌥⌘ and the right arrow): mail (w197) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 729,72 871×630 · +1056 ms 336,72 871×630
- ~ **33 dock-right** (presses ⌃⌥⌘ and the right arrow): w200 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 930,179 470×416 · +1056 ms 537,179 470×416
- ✘ **37 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): notes (w188) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 417,105 709×660 · +4561 ms 202,105 709×660
- ✘ **37 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): calendar (w189) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 431,115 680×600 · +4561 ms 217,115 680×600
- ✘ **37 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): settings (w192) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 410,85 723×625 · +4561 ms 195,85 723×625
- ✘ **37 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): preview (w194) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 417,35 708×424 · +4561 ms 203,35 708×424
- ✘ **37 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): mail (w197) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 336,72 871×630 · +4561 ms 121,72 871×630
- ~ **37 drag-terminal-onto-finder-right** (drags terminal by its title bar onto the right part of finder and lets go): w200 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 537,179 470×416 · +4561 ms 322,179 470×416
- ✘ **59 view-all** (presses ⌃⌥Space): notes (w188) is not back where it was after step 43: 300,105 1000×660, it was at 202,105 709×660 [moved-unasked]
- ✘ **59 view-all** (presses ⌃⌥Space): calendar (w189) is not back where it was after step 43: 403,115 937×600, it was at 217,115 680×600 [moved-unasked]
- ✘ **59 view-all** (presses ⌃⌥Space): settings (w192) is not back where it was after step 43: 437,85 723×625, it was at 195,85 723×625 [moved-unasked]
- ✘ **59 view-all** (presses ⌃⌥Space): preview (w194) is not back where it was after step 43: 4,35 708×424, it was at 203,35 708×424 [moved-unasked]
- ✘ **59 view-all** (presses ⌃⌥Space): mail (w197) is not back where it was after step 43: 240,72 1120×630, it was at 121,72 871×630 [moved-unasked]
- ✘ **59 view-all** (presses ⌃⌥Space): w200 of Mail is not back where it was after step 43: 565,179 470×416, it was at 322,179 470×416 [moved-unasked]
- ✘ **78 minimize-safari** (presses ⌘M): terminal (w187) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 97,238 877×499 · +1665 ms 525,238 429×499
- ✘ **78 minimize-safari** (presses ⌘M): notes (w188) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +1665 ms 386,105 709×660
- ✘ **78 minimize-safari** (presses ⌘M): calendar (w189) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 403,115 937×600 · +1665 ms 401,115 680×600
- ✘ **78 minimize-safari** (presses ⌘M): settings (w192) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +1665 ms 379,85 723×625
- ✘ **78 minimize-safari** (presses ⌘M): preview (w194) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +1665 ms 387,35 708×424
- ✘ **78 minimize-safari** (presses ⌘M): mail (w197) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1665 ms 305,72 871×630
- ~ **78 minimize-safari** (presses ⌘M): w200 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1665 ms 506,179 470×416
- ✘ **79 restore-safari** (clicks its miniature in the Dock): terminal (w187) is not back where it was after step 77: 525,238 429×499, it was at 97,238 877×499 [moved-unasked]
- ✘ **79 restore-safari** (clicks its miniature in the Dock): notes (w188) is not back where it was after step 77: 386,105 709×660, it was at 300,105 1000×660 [moved-unasked]
- ✘ **79 restore-safari** (clicks its miniature in the Dock): calendar (w189) is not back where it was after step 77: 401,115 680×600, it was at 403,115 937×600 [moved-unasked]
- ✘ **79 restore-safari** (clicks its miniature in the Dock): settings (w192) is not back where it was after step 77: 379,85 723×625, it was at 437,85 723×625 [moved-unasked]
- ✘ **79 restore-safari** (clicks its miniature in the Dock): preview (w194) is not back where it was after step 77: 387,35 708×424, it was at 4,35 708×424 [moved-unasked]
- ✘ **79 restore-safari** (clicks its miniature in the Dock): mail (w197) is not back where it was after step 77: 305,72 871×630, it was at 240,72 1120×630 [moved-unasked]
- ✘ **79 restore-safari** (clicks its miniature in the Dock): w200 of Mail is not back where it was after step 77: 506,179 470×416, it was at 565,179 470×416 [moved-unasked]
- ✘ **81 hide-finder** (presses ⌘H): terminal (w187) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 525,238 429×499 · +273 ms 0,238 324×499
- ✘ **81 hide-finder** (presses ⌘H): notes (w188) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 386,105 709×660 · +273 ms 0,105 709×660
- ✘ **81 hide-finder** (presses ⌘H): calendar (w189) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 401,115 680×600 · +282 ms 0,115 680×600
- ✘ **81 hide-finder** (presses ⌘H): settings (w192) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 379,85 723×625 · +282 ms 0,85 723×625
- ✘ **81 hide-finder** (presses ⌘H): preview (w194) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 387,35 708×424 · +282 ms 0,35 708×424
- ✘ **81 hide-finder** (presses ⌘H): mail (w197) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 305,72 871×630 · +282 ms 0,72 871×630
- ~ **81 hide-finder** (presses ⌘H): w200 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 506,179 470×416 · +282 ms 201,179 470×416
- ✘ **82 unhide-finder** (clicks its icon in the Dock): terminal (w187) is not back where it was after step 80: 0,238 324×499, it was at 525,238 429×499 [moved-unasked]
- ✘ **82 unhide-finder** (clicks its icon in the Dock): notes (w188) is not back where it was after step 80: 0,105 709×660, it was at 386,105 709×660 [moved-unasked]
- ✘ **82 unhide-finder** (clicks its icon in the Dock): calendar (w189) is not back where it was after step 80: 0,115 680×600, it was at 401,115 680×600 [moved-unasked]
- ✘ **82 unhide-finder** (clicks its icon in the Dock): settings (w192) is not back where it was after step 80: 0,85 723×625, it was at 379,85 723×625 [moved-unasked]
- ✘ **82 unhide-finder** (clicks its icon in the Dock): preview (w194) is not back where it was after step 80: 0,35 708×424, it was at 387,35 708×424 [moved-unasked]
- ✘ **82 unhide-finder** (clicks its icon in the Dock): mail (w197) is not back where it was after step 80: 0,72 871×630, it was at 305,72 871×630 [moved-unasked]
- ✘ **82 unhide-finder** (clicks its icon in the Dock): w200 of Mail is not back where it was after step 80: 201,179 470×416, it was at 506,179 470×416 [moved-unasked]
- ✘ **84 quit-textedit** (presses ⌘Q in textedit): terminal (w187) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,238 324×499 · +835 ms 525,238 478×499
- ✘ **84 quit-textedit** (presses ⌘Q in textedit): notes (w188) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,105 709×660 · +835 ms 409,105 709×660
- ✘ **84 quit-textedit** (presses ⌘Q in textedit): calendar (w189) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,115 680×600 · +835 ms 423,115 680×600
- ✘ **84 quit-textedit** (presses ⌘Q in textedit): settings (w192) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,85 723×625 · +835 ms 402,85 723×625
- ✘ **84 quit-textedit** (presses ⌘Q in textedit): preview (w194) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,35 708×424 · +835 ms 409,35 708×424
- ✘ **84 quit-textedit** (presses ⌘Q in textedit): mail (w197) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,72 871×630 · +835 ms 328,72 871×630
- ~ **84 quit-textedit** (presses ⌘Q in textedit): w200 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 201,179 470×416 · +835 ms 529,179 470×416
- ✘ **88 leave-full-screen** (presses ⌃⌘F again): textedit (w353) is not back where it was after step 86: 525,65 477×439, it was at 165,65 673×439 [moved-unasked]
- ✘ **110 dock-left** (presses ⌃⌥⌘ and the left arrow): safari (w173) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×790 · +903 ms 806,31 794×790
- ✘ **110 dock-left** (presses ⌃⌥⌘ and the left arrow): terminal (w187) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 97,238 877×499 · +903 ms 806,238 793×499
- ✘ **110 dock-left** (presses ⌃⌥⌘ and the left arrow): notes (w188) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms -1,32 800×791 · +903 ms 806,32 794×791
- ✘ **110 dock-left** (presses ⌃⌥⌘ and the left arrow): calendar (w189) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 385,145 683×601 · +903 ms 806,145 683×601
- ✘ **110 dock-left** (presses ⌃⌥⌘ and the left arrow): settings (w192) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +903 ms 806,85 723×625
- ✘ **110 dock-left** (presses ⌃⌥⌘ and the left arrow): preview (w194) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +903 ms 806,35 708×424
- ✘ **110 dock-left** (presses ⌃⌥⌘ and the left arrow): mail (w197) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +903 ms 729,72 871×630
- ~ **110 dock-left** (presses ⌃⌥⌘ and the left arrow): w200 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +903 ms 930,179 470×416
- ✘ **110 dock-left** (presses ⌃⌥⌘ and the left arrow): textedit (w353) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +903 ms 806,65 673×439
- ✘ **112 dock-right** (presses ⌃⌥⌘ and the right arrow): terminal (w187) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,238 793×499 · +1178 ms 541,238 457×499
- ✘ **112 dock-right** (presses ⌃⌥⌘ and the right arrow): notes (w188) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,32 794×791 · +1178 ms 417,32 709×791
- ✘ **112 dock-right** (presses ⌃⌥⌘ and the right arrow): calendar (w189) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,145 683×601 · +1178 ms 431,145 680×601
- ✘ **112 dock-right** (presses ⌃⌥⌘ and the right arrow): settings (w192) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,85 723×625 · +1178 ms 410,85 723×625
- ✘ **112 dock-right** (presses ⌃⌥⌘ and the right arrow): preview (w194) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,35 708×424 · +1178 ms 417,35 708×424
- ✘ **112 dock-right** (presses ⌃⌥⌘ and the right arrow): mail (w197) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 729,72 871×630 · +1178 ms 336,72 871×630
- ~ **112 dock-right** (presses ⌃⌥⌘ and the right arrow): w200 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 930,179 470×416 · +1178 ms 537,179 470×416
- ✘ **112 dock-right** (presses ⌃⌥⌘ and the right arrow): textedit (w353) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,65 673×439 · +1178 ms 541,65 461×439

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **31 dock-left** (presses ⌃⌥⌘ and the left arrow): the last window came to rest 2217 ms after the key or the button, in Arbor's first act since it started [slow]
- ~ **33 dock-right** (presses ⌃⌥⌘ and the right arrow): the last window came to rest 774 ms after the key or the button [slow]
- ~ **35 dock-right** (presses ⌃⌥⌘ and the right arrow): the last window came to rest 745 ms after the key or the button [slow]
- ✘ **38 drag-terminal-out** (drags terminal out of the arrangement onto the Desktop and lets go): terminal (w187) moved 2 times [jolt]
  - +0 ms 431,131 240×769 · +122 ms 431,131 877×499 · +879 ms 97,238 877×499
- ~ **38 drag-terminal-out** (drags terminal out of the arrangement onto the Desktop and lets go): the last window came to rest 789 ms after the key or the button [slow]
- ~ **55 view-frame** (presses ⌃⌥↩): the last window came to rest 725 ms after the key or the button [slow]
- ~ **61 view-frame** (presses ⌃⌥↩): the last window came to rest 735 ms after the key or the button [slow]
- ~ **100 drag-calendar-by** (drags calendar, which floats, by its title bar 0 across and 118 down, and clicks there 0.3 s after letting go): calendar (w189) changed its size while it was being dragged [jolt]
  - +0 ms 0,34 1600×791 · +77 ms 0,42 1600×791 · +116 ms 0,42 1584×788 · +121 ms 6,38 1584×788 · +155 ms 181,38 1169×702 · +165 ms 181,42 1169×702 · … 29 more … · +1727 ms 385,137 681×601 · +1801 ms 385,141 681×601 · +1869 ms 385,145 681×601 · +2053 ms 386,145 681×601 · +2120 ms 385,145 681×601
- ~ **112 dock-right** (presses ⌃⌥⌘ and the right arrow): the last window came to rest 893 ms after the key or the button [slow]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **108 float-all** (presses ⌃⌥⇧F): calendar (w189) has its size back but not its place: 385,145 683×601, it was at 445,205 683×601 [size-lost]
- ✘ **114 quit** (chooses Quit Arbor in Arbor's menu): calendar (w189) has its size back but not its place: 385,145 683×601, it was at 445,205 683×601 [size-lost]
- ✘ **121 quit** (chooses Quit Arbor in Arbor's menu): calendar (w189) has its size back but not its place: 385,145 683×601, it was at 445,205 683×601 [size-lost]

### Rule -: what the script itself checked

- ✘ **18 leave-alone** (does nothing for half a minute): with nothing to do Arbor used 1.2 % of a core [busy]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (3, 84 ms) | quiet 1015 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 373 ms; blind for 783 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (4, 289 ms) | quiet 1393 ms; blind for 149 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (4, 329 ms) | quiet 1347 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (5, 122 ms) | quiet 1103 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×2 (7, 376 ms) | quiet 1404 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×2 (2, 288 ms) | quiet 824 ms; blind for 287 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (4, 51 ms) | quiet 959 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w200 ×1 (6, 168 ms) | quiet 795 ms; blind for 1191 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (30, 2647 ms) | quiet 1063 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (30, 2901 ms) | quiet 1042 ms |  |  |  |  |  |  |  |  |
| 12 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (27, 3999 ms) | quiet 1473 ms |  |  |  |  |  |  |  |  |
| 13 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (35, 2224 ms) | quiet 1012 ms |  |  |  |  |  |  |  |  |
| 14 | look-around | looks at the screen |  | quiet 382 ms |  |  |  |  |  |  |  |  |
| 15 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 675 ms; blind for 111 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 16 | launch | starts Arbor |  | quiet 1071 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 17 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 787 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 18 | leave-alone | does nothing for half a minute |  | quiet 371 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |

### Switching between apps, nothing docked yet

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 19 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 444 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 443 ms; blind for 114 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 382 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 22 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 380 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 423 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 527 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 455 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 380 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 379 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 406 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 29 | cmd-tab-2 | holds ⌘ and presses Tab 2 time(s) |  | quiet 476 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### The first docks, by key

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 30 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 418 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms) | quiet 1002 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 32 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 455 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms) | quiet 936 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 34 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 438 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 659 ms |  | ✔ | ~ | ✔ |  |  | ✔ | ✔ |

### Docking by real drags

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 36 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 371 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | drag-terminal-onto-finder-right | drags terminal by its title bar onto the right part of finder and lets go | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms) | quiet 1042 ms | ✔ | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | drag-terminal-out | drags terminal out of the arrangement onto the Desktop and lets go | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×2 (2, 757 ms) | quiet 1092 ms | ✔ | ✔ | ✘ | ✔ | ✔ | ✔ | ✔ | ✔ |

### Sizes

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 39 | click-finder | clicks finder's title bar |  | quiet 404 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | grow | presses ⌃⌥⌘= |  | quiet 682 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 41 | shrink | presses ⌃⌥⌘- |  | quiet 598 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 42 | balance | presses ⌃⌥⌘0 |  | quiet 519 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### Switching between apps, with an arrangement

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 43 | view-all | presses ⌃⌥Space |  | quiet 786 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 44 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 438 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 351 ms; blind for 104 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 46 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 414 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 381 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 416 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 482 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 676 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 503 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 517 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 53 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 491 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### The view goes in and out

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 54 | click-finder | clicks finder's title bar |  | quiet 474 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms) | quiet 1106 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 56 | dock-icon-safari | clicks safari's icon in the Dock | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 445 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 446 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 58 | dock-icon-calendar | clicks calendar's icon in the Dock | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms) | quiet 545 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 59 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 807 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 60 | click-safari | clicks safari's title bar |  | quiet 376 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms) | quiet 928 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 62 | view-left | presses ⌃⌥← | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms) | quiet 823 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 63 | view-back | presses ⌃⌥[ | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms) | quiet 921 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 64 | view-out | presses ⌃⌥↑ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms) | quiet 793 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 65 | view-desktop | presses ⌃⌥D | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 929 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 66 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 697 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### Windows come and go

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 67 | click-safari | clicks safari's title bar |  | quiet 425 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 68 | new-window-safari | presses ⌘N in safari |  | quiet 972 ms; blind for 795 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 69 | window-menu-safari | chooses safari's first window in the Window menu |  | quiet 1419 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 70 | cmd-backtick | presses ⌘` for the app's next window |  | quiet 403 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 71 | close-window | presses ⌘W |  | quiet 956 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 72 | click-safari | clicks safari's title bar |  | quiet 409 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 73 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms) | quiet 1010 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 74 | new-window-safari | presses ⌘N in safari |  | quiet 1015 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 75 | close-window | presses ⌘W |  | quiet 836 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 76 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms) | quiet 727 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 77 | click-safari | clicks safari's title bar |  | quiet 397 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 78 | minimize-safari | presses ⌘M | safari ×1 (18, 452 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms) | quiet 1724 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 79 | restore-safari | clicks its miniature in the Dock | safari ×1 (20, 483 ms), textedit ×1 (1, 0 ms) | quiet 954 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 80 | click-finder | clicks finder's title bar |  | quiet 452 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 81 | hide-finder | presses ⌘H | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms) | quiet 1128 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 82 | unhide-finder | clicks its icon in the Dock | safari ×1 (1, 0 ms), textedit ×1 (2, 52 ms) | quiet 520 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 83 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 471 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 84 | quit-textedit | presses ⌘Q in textedit | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms) | quiet 1185 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 85 | reopen-textedit | opens textedit's document again |  | quiet 1032 ms; blind for 364 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### Full screen

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 86 | click-safari | clicks safari's title bar |  | quiet 351 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 87 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (2, 85 ms), calendar ×1 (2, 72 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 356 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 88 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 380 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |

### A click lands on the wallpaper, a double-click on a title bar

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 89 | click-wallpaper | clicks on the wallpaper | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 499 ms |  |  | ✔ |  |  | ✔ | ✔ | ✔ |
| 90 | click-wallpaper-again | clicks on the wallpaper again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 410 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 91 | double-click-finder | double-clicks finder's title bar: macOS zooms the window | finder ×2 (15, 699 ms) | quiet 1180 ms | ✘ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 92 | double-click-finder-again | double-clicks it again: macOS takes the window back | finder ×2 (13, 723 ms) | quiet 1224 ms | ✘ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 93 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 416 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 94 | double-click-calendar | double-clicks calendar's title bar: macOS zooms the window | calendar ×1 (9, 310 ms) | quiet 907 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 95 | double-click-calendar-again | double-clicks it again: macOS takes the window back | calendar ×1 (12, 321 ms) | quiet 818 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### Where macOS tiles too

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 96 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 460 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 97 | drag-notes-to-left-edge | drags notes by its title bar against the left edge of the screen and lets go | notes ×1 (8, 257 ms) | quiet 362 ms | ✘ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 98 | click-calendar | clicks calendar's title bar |  | quiet 420 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 99 | drag-calendar-to-top-edge | drags calendar by its title bar against the top edge of the screen and lets go | calendar ×1 (11, 323 ms) | quiet 362 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 100 | drag-calendar-by | drags calendar, which floats, by its title bar 0 across and 118 down, and clicks there 0.3 s after letting go |  | quiet 1021 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 101 | view-all | presses ⌃⌥Space |  | quiet 810 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 102 | view-all | presses ⌃⌥Space |  | quiet 752 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### The ways out

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 103 | click-safari | clicks safari's title bar |  | quiet 356 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 104 | pause | presses ⌃⌥⎋ | finder ×1 (1, 0 ms), safari ×1 (2, 64 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms), textedit ×1 (2, 59 ms) | quiet 1077 ms |  |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 105 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 442 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 106 | drag-calendar-by | drags calendar, which floats, by its title bar 60 across and 60 down |  | quiet 1074 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 107 | resume | presses ⌃⌥⎋ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (2, 5 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1093 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 108 | float-all | presses ⌃⌥⇧F | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 876 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 109 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 387 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 110 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1091 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 111 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 424 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 112 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1034 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 113 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1092 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |

### Quit, and the next morning

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 114 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (2, 75 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w200 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 882 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 115 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 485 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 116 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 399 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 117 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 523 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 118 | launch | starts Arbor | finder ×1 (2, 26 ms), safari ×1 (2, 25 ms) | quiet 954 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 119 | leave-alone | does nothing for half a minute |  | quiet 432 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 120 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 659 ms; blind for 100 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 121 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (2, 29 ms), safari ×1 (2, 33 ms) | quiet 845 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 122 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 514 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 123 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 393 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 124 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 371 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 125 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 407 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 126 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 508 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 127 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 396 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 128 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 422 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 129 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 613 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 130 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 465 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 131 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 400 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
