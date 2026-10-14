112 steps in 391 s, 92 of them judged, 42 with a rule broken. The sampler: samples 13426 seconds 392.6 hz 34.2 cost-ms 5.21 late 3738 longest-gap-ms 1470.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 5 | 1 | 35 drag-notes-to-left-edge |
| 2 | nothing moves that the person did not move | 74 | 28 | 27 dock-finder-left, 29 dock-safari-right, 33 drag-terminal-onto-finder, 35 drag-notes-to-left-edge, 37 reach-finder, 42 reach-calendar, 43 drag-calendar-to-top, 45 dock-icon-finder-2, 46 dock-icon-safari-2, 47 dock-icon-textedit-2, 48 dock-icon-terminal-2, 49 dock-icon-notes-2 … |
| 3 | no jolts: a window moves once, to where it ends up | 92 | 8 | 27 dock-finder-left, 29 dock-safari-right, 33 drag-terminal-onto-finder, 35 drag-notes-to-left-edge, 44 drag-calendar-back, 66 show-desktop, 94 float-all, 100 quit |
| 4 | the window you switch to comes to the front and into view | 71 | 5 | 35 drag-notes-to-left-edge, 36 drag-terminal-out, 56 frame-finder, 58 cmd-tab-while-framed, 81 reach-finder |
| 5 | quitting, Float All and pause give windows their own sizes back | 5 | 6 | 36 drag-terminal-out, 44 drag-calendar-back, 91 pause, 94 float-all, 100 quit, 112 quit-2 |
| L | no window is lost or stuck | 92 | 5 | 60 show-everything, 67 show-everything-2, 77 show-everything-3, 82 hide-finder, 110 launch-2 |
| - | what the script itself checked | 92 | 4 | 23 dock-icon-mail, 36 drag-terminal-out, 53 dock-icon-mail-2, 109 dock-icon-mail-3 |

## Findings

### Rule 1: never fight macOS: where it answers a drag, Arbor stands aside

- ✘ **35 drag-notes-to-left-edge** (drags notes by its title bar against the left edge of the screen and lets go): notes (w54) macOS's tiling preview and Arbor's drop preview were up at the same time [fought]

### Rule 2: nothing moves that the person did not move

- ✘ **27 dock-finder-left** (presses ⌃⌥⌘←): w130 of Mail moved, and the step did not name it [moved-unasked]
  - +0 ms 565,179 470×416 · +2726 ms 930,179 470×416
- ✘ **29 dock-safari-right** (presses ⌃⌥⌘→): w130 of Mail moved, and the step did not name it [moved-unasked]
  - +0 ms 930,179 470×416 · +953 ms 537,179 470×416
- ✘ **33 drag-terminal-onto-finder** (drags terminal by its title bar onto the right part of finder and lets go): w130 of Mail moved, and the step did not name it [moved-unasked]
  - +0 ms 537,179 470×416 · +3928 ms 322,179 470×416
- ✘ **35 drag-notes-to-left-edge** (drags notes by its title bar against the left edge of the screen and lets go): w130 of Mail moved, and the step did not name it [moved-unasked]
  - +0 ms 322,179 470×416 · +4158 ms 358,179 470×416
- ✘ **37 reach-finder** (clicks finder's title bar, or its Dock icon if that is covered): finder (w32) moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 501×767 · +1446 ms 12,43 1576×767
- ✘ **37 reach-finder** (clicks finder's title bar, or its Dock icon if that is covered): safari (w35) moved, and the step did not name it [moved-unasked]
  - +0 ms 731,43 574×767 · +1461 ms 1599,770 574×767
- ✘ **37 reach-finder** (clicks finder's title bar, or its Dock icon if that is covered): textedit (w46) moved, and the step did not name it [moved-unasked]
  - +0 ms 1317,43 271×767 · +1557 ms 1599,790 271×767
- ✘ **37 reach-finder** (clicks finder's title bar, or its Dock icon if that is covered): calendar (w60) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 253,115 680×599 · +1557 ms 1599,770 680×599
- ✘ **37 reach-finder** (clicks finder's title bar, or its Dock icon if that is covered): settings (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 231,85 723×625 · +1557 ms 1599,770 723×625
- ✘ **37 reach-finder** (clicks finder's title bar, or its Dock icon if that is covered): preview (w65) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 239,35 708×424 · +1557 ms 1599,770 708×424
- ✘ **37 reach-finder** (clicks finder's title bar, or its Dock icon if that is covered): w128 of Mail a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 157,72 871×630 · +1557 ms 1599,770 871×630
- ✘ **37 reach-finder** (clicks finder's title bar, or its Dock icon if that is covered): w130 of Mail moved, and the step did not name it [moved-unasked]
  - +0 ms 358,179 470×416 · +1557 ms 1800,877 470×416
- ✘ **42 reach-calendar** (clicks calendar's title bar, or its Dock icon if that is covered): finder (w32) moved, and the step did not name it [moved-unasked]
  - +0 ms 12,43 1576×767 · +1047 ms 1599,770 1576×767
- ✘ **42 reach-calendar** (clicks calendar's title bar, or its Dock icon if that is covered): calendar (w60) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 680×599 · +1217 ms 404,115 936×599
- ✘ **42 reach-calendar** (clicks calendar's title bar, or its Dock icon if that is covered): settings (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 723×625 · +1228 ms 437,85 723×625
- ✘ **42 reach-calendar** (clicks calendar's title bar, or its Dock icon if that is covered): preview (w65) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 708×424 · +1248 ms 4,35 708×424
- ✘ **42 reach-calendar** (clicks calendar's title bar, or its Dock icon if that is covered): w128 of Mail a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 871×630 · +1445 ms 1599,770 1120×630 · +1484 ms 240,72 1120×630
- ✘ **42 reach-calendar** (clicks calendar's title bar, or its Dock icon if that is covered): w130 of Mail moved, and the step did not name it [moved-unasked]
  - +0 ms 1800,877 470×416 · +1445 ms 1924,877 470×416 · +1484 ms 565,179 470×416
- ✘ **43 drag-calendar-to-top** (drags calendar by its title bar against the menu bar and lets go: macOS fills the screen with it): settings (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +4363 ms 437,558 723×470 · +4417 ms 437,352 723×470
- ✘ **43 drag-calendar-to-top** (drags calendar by its title bar against the menu bar and lets go: macOS fills the screen with it): preview (w65) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +4417 ms 4,35 708×264 · +4432 ms 4,558 708×264
- ✘ **43 drag-calendar-to-top** (drags calendar by its title bar against the menu bar and lets go: macOS fills the screen with it): w128 of Mail a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +4520 ms 240,558 1120×264
- ✘ **43 drag-calendar-to-top** (drags calendar by its title bar against the menu bar and lets go: macOS fills the screen with it): w130 of Mail moved, and the step did not name it [moved-unasked]
  - +0 ms 565,179 470×416 · +4520 ms 565,610 470×416
- ✘ **45 dock-icon-finder-2** (clicks finder's icon in the Dock): finder (w32) moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 1576×767 · +903 ms 12,43 1576×767
- ✘ **45 dock-icon-finder-2** (clicks finder's icon in the Dock): calendar (w60) moved, and the step did not name it [moved-unasked]
  - +0 ms 12,43 1576×503 · +903 ms 1599,770 1576×503
- ✘ **45 dock-icon-finder-2** (clicks finder's icon in the Dock): settings (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,352 723×470 · +943 ms 1599,770 723×470
- ✘ **45 dock-icon-finder-2** (clicks finder's icon in the Dock): preview (w65) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,558 708×264 · +943 ms 1599,770 708×264
- ✘ **45 dock-icon-finder-2** (clicks finder's icon in the Dock): w128 of Mail a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,558 1120×264 · +960 ms 1599,770 1120×264
- ✘ **45 dock-icon-finder-2** (clicks finder's icon in the Dock): w130 of Mail moved, and the step did not name it [moved-unasked]
  - +0 ms 565,610 470×416 · +960 ms 1924,822 470×416
- ✘ **46 dock-icon-safari-2** (clicks safari's icon in the Dock): finder (w32) moved, and the step did not name it [moved-unasked]
  - +0 ms 12,43 1576×767 · +890 ms 1599,770 1576×767
- ✘ **46 dock-icon-safari-2** (clicks safari's icon in the Dock): safari (w35) moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 574×767 · +877 ms 12,43 1576×767
- ✘ **47 dock-icon-textedit-2** (clicks textedit's icon in the Dock): safari (w35) moved, and the step did not name it [moved-unasked]
  - +0 ms 12,43 1576×767 · +911 ms 1599,770 1576×767
- ✘ **47 dock-icon-textedit-2** (clicks textedit's icon in the Dock): textedit (w46) moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,790 271×767 · +892 ms 1599,790 1576×767 · +911 ms 12,43 1576×767
- ✘ **48 dock-icon-terminal-2** (clicks terminal's icon in the Dock): textedit (w46) moved, and the step did not name it [moved-unasked]
  - +0 ms 12,43 1576×767 · +971 ms 1599,790 1576×767
- ✘ **48 dock-icon-terminal-2** (clicks terminal's icon in the Dock): terminal (w51) moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,790 240×769 · +1009 ms 12,43 1577×769
- ✘ **49 dock-icon-notes-2** (clicks notes's icon in the Dock): terminal (w51) moved, and the step did not name it [moved-unasked]
  - +0 ms 12,43 1577×769 · +973 ms 1599,790 1577×769
- ✘ **49 dock-icon-notes-2** (clicks notes's icon in the Dock): notes (w54) moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 800×791 · +973 ms 12,43 1576×767
- ✘ **50 dock-icon-calendar-2** (clicks calendar's icon in the Dock): notes (w54) moved, and the step did not name it [moved-unasked]
  - +0 ms 12,43 1576×767 · +936 ms 1599,770 1576×767
- ✘ **50 dock-icon-calendar-2** (clicks calendar's icon in the Dock): calendar (w60) moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 1576×503 · +868 ms 12,43 1576×767
- ✘ **51 dock-icon-settings-2** (clicks settings's icon in the Dock): calendar (w60) moved, and the step did not name it [moved-unasked]
  - +0 ms 12,43 1576×767 · +841 ms 1599,770 1576×767
- ✘ **51 dock-icon-settings-2** (clicks settings's icon in the Dock): settings (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 723×470 · +912 ms 437,85 723×625
- ✘ **51 dock-icon-settings-2** (clicks settings's icon in the Dock): preview (w65) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 708×264 · +919 ms 4,35 708×424
- ✘ **51 dock-icon-settings-2** (clicks settings's icon in the Dock): w128 of Mail a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 1120×264 · +1040 ms 1599,770 1120×630 · +1103 ms 240,72 1120×630
- ✘ **51 dock-icon-settings-2** (clicks settings's icon in the Dock): w130 of Mail moved, and the step did not name it [moved-unasked]
  - +0 ms 1924,822 470×416 · +1040 ms 1924,877 470×416 · +1103 ms 565,179 470×416
- ✘ **54 cmd-tab-2** (presses ⌘Tab): safari (w35) is not back where it was after step 44: 1599,770 1576×767, it was at 1599,770 574×767 [moved-unasked]
- ✘ **54 cmd-tab-2** (presses ⌘Tab): textedit (w46) is not back where it was after step 44: 1599,790 1576×767, it was at 1599,790 271×767 [moved-unasked]
- ✘ **54 cmd-tab-2** (presses ⌘Tab): terminal (w51) is not back where it was after step 44: 1599,790 1577×769, it was at 1599,790 240×769 [moved-unasked]
- ✘ **54 cmd-tab-2** (presses ⌘Tab): notes (w54) is not back where it was after step 44: 1599,770 1576×767, it was at 1599,770 800×791 [moved-unasked]
- ✘ **54 cmd-tab-2** (presses ⌘Tab): calendar (w60) is not back where it was after step 44: 1599,770 1576×767, it was at 12,43 1576×503 [moved-unasked]
- ✘ **54 cmd-tab-2** (presses ⌘Tab): settings (w63) is not back where it was after step 44: 437,85 723×625, it was at 437,352 723×470 [moved-unasked]
- ✘ **54 cmd-tab-2** (presses ⌘Tab): preview (w65) is not back where it was after step 44: 4,35 708×424, it was at 4,558 708×264 [moved-unasked]
- ✘ **54 cmd-tab-2** (presses ⌘Tab): w128 of Mail is not back where it was after step 44: 240,72 1120×630, it was at 240,558 1120×264 [moved-unasked]
- ✘ **54 cmd-tab-2** (presses ⌘Tab): w130 of Mail is not back where it was after step 44: 565,179 470×416, it was at 565,610 470×416 [moved-unasked]
- ✘ **55 reach-finder** (clicks finder's title bar, or its Dock icon if that is covered): finder (w32) moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 1576×767 · +1094 ms 12,43 1576×767
- ✘ **55 reach-finder** (clicks finder's title bar, or its Dock icon if that is covered): settings (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +1094 ms 1599,770 723×625
- ✘ **55 reach-finder** (clicks finder's title bar, or its Dock icon if that is covered): preview (w65) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +1120 ms 1599,770 708×424
- ✘ **55 reach-finder** (clicks finder's title bar, or its Dock icon if that is covered): w128 of Mail a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1120 ms 1599,770 1120×630
- ✘ **55 reach-finder** (clicks finder's title bar, or its Dock icon if that is covered): w130 of Mail moved, and the step did not name it [moved-unasked]
  - +0 ms 565,179 470×416 · +1120 ms 1924,877 470×416
- ✘ **60 show-everything** (presses ⌃⌥Space): finder (w32) is not back where it was after step 55: 1599,770 1576×767, it was at 12,43 1576×767 [moved-unasked]
- ✘ **60 show-everything** (presses ⌃⌥Space): safari (w35) is not back where it was after step 55: 731,43 574×767, it was at 1599,770 1576×767 [moved-unasked]
- ✘ **60 show-everything** (presses ⌃⌥Space): textedit (w46) is not back where it was after step 55: 1317,43 271×767, it was at 1599,790 1576×767 [moved-unasked]
- ✘ **60 show-everything** (presses ⌃⌥Space): settings (w63) is not back where it was after step 55: 231,352 723×470, it was at 1599,770 723×625 [moved-unasked]
- ✘ **60 show-everything** (presses ⌃⌥Space): preview (w65) is not back where it was after step 55: 239,433 708×389, it was at 1599,770 708×424 [moved-unasked]
- ✘ **60 show-everything** (presses ⌃⌥Space): w128 of Mail is not back where it was after step 55: 157,433 871×389, it was at 1599,770 1120×630 [moved-unasked]
- ✘ **60 show-everything** (presses ⌃⌥Space): w130 of Mail is not back where it was after step 55: 358,485 470×416, it was at 1924,877 470×416 [moved-unasked]
- ✘ **67 show-everything-2** (presses ⌃⌥Space): finder (w32) is not back where it was after step 55: 1599,770 1576×767, it was at 12,43 1576×767 [moved-unasked]
- ✘ **67 show-everything-2** (presses ⌃⌥Space): safari (w35) is not back where it was after step 55: 731,43 574×767, it was at 1599,770 1576×767 [moved-unasked]
- ✘ **67 show-everything-2** (presses ⌃⌥Space): textedit (w46) is not back where it was after step 55: 1317,43 271×767, it was at 1599,790 1576×767 [moved-unasked]
- ✘ **67 show-everything-2** (presses ⌃⌥Space): calendar (w60) is not back where it was after step 55: 1599,770 1576×503, it was at 1599,770 1576×767 [moved-unasked]
- ✘ **67 show-everything-2** (presses ⌃⌥Space): settings (w63) is not back where it was after step 55: 231,352 723×470, it was at 1599,770 723×625 [moved-unasked]
- ✘ **67 show-everything-2** (presses ⌃⌥Space): preview (w65) is not back where it was after step 55: 239,433 708×389, it was at 1599,770 708×424 [moved-unasked]
- ✘ **67 show-everything-2** (presses ⌃⌥Space): w128 of Mail is not back where it was after step 55: 157,433 871×389, it was at 1599,770 1120×630 [moved-unasked]
- ✘ **67 show-everything-2** (presses ⌃⌥Space): w130 of Mail is not back where it was after step 55: 358,485 470×416, it was at 1924,877 470×416 [moved-unasked]
- ✘ **79 minimize-safari** (presses ⌘M): settings (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 231,352 723×470 · +1296 ms 547,352 723×470
- ✘ **79 minimize-safari** (presses ⌘M): preview (w65) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 239,433 708×389 · +1333 ms 239,433 708×264 · +1344 ms 555,558 708×264
- ✘ **79 minimize-safari** (presses ⌘M): w128 of Mail a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 157,433 871×389 · +1444 ms 157,433 871×264 · +1479 ms 473,558 871×264
- ✘ **79 minimize-safari** (presses ⌘M): w130 of Mail moved, and the step did not name it [moved-unasked]
  - +0 ms 358,485 470×416 · +1479 ms 674,610 470×416
- ✘ **80 restore-safari** (clicks its miniature in the Dock): settings (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 547,352 723×470 · +1637 ms 231,352 723×470
- ✘ **80 restore-safari** (clicks its miniature in the Dock): preview (w65) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 555,558 708×264 · +1637 ms 239,433 708×264 · +1668 ms 239,433 708×388
- ✘ **80 restore-safari** (clicks its miniature in the Dock): w128 of Mail a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 473,558 871×264 · +1668 ms 157,433 871×264 · +1760 ms 157,433 871×388
- ✘ **80 restore-safari** (clicks its miniature in the Dock): w130 of Mail moved, and the step did not name it [moved-unasked]
  - +0 ms 674,610 470×416 · +1668 ms 358,485 470×416
- ✘ **80 restore-safari** (clicks its miniature in the Dock): terminal (w51) is not back where it was after step 78: 1599,790 240×769, it was at 1599,790 1577×769 [moved-unasked]
- ✘ **80 restore-safari** (clicks its miniature in the Dock): calendar (w60) is not back where it was after step 78: 1599,770 680×503, it was at 1599,770 1576×503 [moved-unasked]
- ✘ **82 hide-finder** (presses ⌘H): settings (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 231,352 723×470 · +542 ms 547,352 723×470
- ✘ **82 hide-finder** (presses ⌘H): preview (w65) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 239,433 708×388 · +576 ms 239,433 708×264 · +595 ms 555,558 708×264
- ✘ **82 hide-finder** (presses ⌘H): w128 of Mail a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 157,433 871×388 · +704 ms 157,433 871×264 · +803 ms 473,558 871×264
- ✘ **82 hide-finder** (presses ⌘H): w130 of Mail moved, and the step did not name it [moved-unasked]
  - +0 ms 358,485 470×416 · +803 ms 674,610 470×416
- ✘ **83 unhide-finder** (clicks its icon in the Dock): settings (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 547,352 723×470 · +900 ms 1599,770 723×470
- ✘ **83 unhide-finder** (clicks its icon in the Dock): preview (w65) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 555,558 708×264 · +900 ms 1599,770 708×264
- ✘ **83 unhide-finder** (clicks its icon in the Dock): w128 of Mail a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 473,558 871×264 · +924 ms 1599,770 871×264
- ✘ **83 unhide-finder** (clicks its icon in the Dock): w130 of Mail moved, and the step did not name it [moved-unasked]
  - +0 ms 674,610 470×416 · +924 ms 1800,822 470×416
- ✘ **83 unhide-finder** (clicks its icon in the Dock): finder (w32) is not back where it was after step 81: 12,43 1576×767, it was at 1599,770 1576×767 [moved-unasked]
- ✘ **83 unhide-finder** (clicks its icon in the Dock): textedit (w46) is not back where it was after step 81: 1599,790 327×767, it was at 1317,43 271×767 [moved-unasked]
- ✘ **83 unhide-finder** (clicks its icon in the Dock): settings (w63) is not back where it was after step 81: 1599,770 723×470, it was at 231,352 723×470 [moved-unasked]
- ✘ **83 unhide-finder** (clicks its icon in the Dock): preview (w65) is not back where it was after step 81: 1599,770 708×264, it was at 239,433 708×388 [moved-unasked]
- ✘ **83 unhide-finder** (clicks its icon in the Dock): w128 of Mail is not back where it was after step 81: 1599,770 871×264, it was at 157,433 871×388 [moved-unasked]
- ✘ **83 unhide-finder** (clicks its icon in the Dock): w130 of Mail is not back where it was after step 81: 1800,822 470×416, it was at 358,485 470×416 [moved-unasked]
- ✘ **84 reach-textedit** (clicks textedit's title bar, or its Dock icon if that is covered): finder (w32) moved, and the step did not name it [moved-unasked]
  - +0 ms 12,43 1576×767 · +999 ms 1599,770 1576×767
- ✘ **84 reach-textedit** (clicks textedit's title bar, or its Dock icon if that is covered): textedit (w46) moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,790 327×767 · +999 ms 1599,790 1576×767 · +1030 ms 12,43 1576×767
- ✘ **87 reach-safari** (clicks safari's title bar, or its Dock icon if that is covered): finder (w32) moved, and the step did not name it [moved-unasked]
  - +0 ms 12,43 1576×767 · +1123 ms 1599,770 1576×767
- ✘ **87 reach-safari** (clicks safari's title bar, or its Dock icon if that is covered): safari (w35) moved, and the step did not name it [moved-unasked]
  - +0 ms 731,43 574×767 · +79 ms 1599,770 574×767 · +206 ms 12,43 1576×767
- ✘ **87 reach-safari** (clicks safari's title bar, or its Dock icon if that is covered): textedit (w251) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +1131 ms 1599,790 673×439
- ✘ **89 leave-full-screen** (presses ⌃⌘F again): finder (w32) is not back where it was after step 87: 1599,770 501×767, it was at 1599,770 1576×767 [moved-unasked]
- ✘ **89 leave-full-screen** (presses ⌃⌘F again): terminal (w51) is not back where it was after step 87: 1599,790 247×769, it was at 1599,790 240×769 [moved-unasked]
- ✘ **89 leave-full-screen** (presses ⌃⌘F again): settings (w63) is not back where it was after step 87: 877,352 723×470, it was at 1599,770 723×470 [moved-unasked]
- ✘ **89 leave-full-screen** (presses ⌃⌘F again): preview (w65) is not back where it was after step 87: 892,558 708×264, it was at 1599,770 708×264 [moved-unasked]
- ✘ **89 leave-full-screen** (presses ⌃⌘F again): w128 of Mail is not back where it was after step 87: 729,558 871×264, it was at 1599,770 871×264 [moved-unasked]
- ✘ **89 leave-full-screen** (presses ⌃⌘F again): w130 of Mail is not back where it was after step 87: 930,610 470×416, it was at 1800,822 470×416 [moved-unasked]
- ✘ **89 leave-full-screen** (presses ⌃⌘F again): textedit (w251) is not back where it was after step 87: 908,558 673×264, it was at 1599,790 673×439 [moved-unasked]
- ✘ **96 dock-finder-left-2** (presses ⌃⌥⌘←): w130 of Mail moved, and the step did not name it [moved-unasked]
  - +0 ms 565,179 470×416 · +912 ms 930,179 470×416
- ✘ **98 dock-safari-right-2** (presses ⌃⌥⌘→): w130 of Mail moved, and the step did not name it [moved-unasked]
  - +0 ms 930,179 470×416 · +780 ms 537,179 470×416
- ✘ **110 launch-2** (starts Arbor again): terminal (w51) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,51 877×499 · +617 ms 1599,790 877×499
- ✘ **110 launch-2** (starts Arbor again): notes (w54) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +669 ms 1599,770 1000×660
- ✘ **110 launch-2** (starts Arbor again): calendar (w60) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 404,115 936×599 · +669 ms 1599,770 936×599
- ✘ **110 launch-2** (starts Arbor again): settings (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +711 ms 1599,770 723×625
- ✘ **110 launch-2** (starts Arbor again): preview (w65) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +711 ms 1599,770 708×424
- ✘ **110 launch-2** (starts Arbor again): w128 of Mail a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +740 ms 1599,770 1120×630
- ✘ **110 launch-2** (starts Arbor again): w130 of Mail moved, and the step did not name it [moved-unasked]
  - +0 ms 565,179 470×416 · +740 ms 1924,877 470×416
- ✘ **110 launch-2** (starts Arbor again): textedit (w251) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +754 ms 1599,790 673×439

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **27 dock-finder-left** (presses ⌃⌥⌘←): the last window came to rest 2535 ms after the key or the button [slow]
- ✘ **29 dock-safari-right** (presses ⌃⌥⌘→): safari (w35) went 114 points out of its way before it ended up [jolt]
  - +0 ms 806,31 794×791 · +392 ms 806,31 574×767 · +410 ms 1071,43 574×767 · +451 ms 1014,43 574×767
- ✘ **33 drag-terminal-onto-finder** (drags terminal by its title bar onto the right part of finder and lets go): terminal (w51) was 86 points from where the pointer carried it, 3247 ms into the step [pulled]
  - +0 ms 529,63 457×499 · +45 ms 518,75 457×499 · +103 ms 514,87 457×499 · +220 ms 514,99 457×499 · +288 ms 514,111 457×499 · +354 ms 514,123 457×499 · … 21 more … · +2054 ms 312,322 457×499 · +2088 ms 301,322 457×499 · +2181 ms 290,334 457×499 · +2430 ms 291,347 457×499 · +2536 ms 290,347 457×499
- ✘ **35 drag-notes-to-left-edge** (drags notes by its title bar against the left edge of the screen and lets go): textedit (w46) went 38 points out of its way before it ended up [jolt]
  - +0 ms 1308,43 280×767 · +3723 ms 1308,43 252×767 · +3752 ms 1336,43 252×767 · +3933 ms 1336,43 264×767 · +3986 ms 1317,43 271×767
- ✘ **35 drag-notes-to-left-edge** (drags notes by its title bar against the left edge of the screen and lets go): notes (w54) was 75 points from where the pointer carried it, 2679 ms into the step [pulled]
  - +0 ms 183,115 709×660 · +27 ms 165,125 709×660 · +139 ms 151,135 709×660 · +208 ms 151,146 709×660 · +304 ms 151,150 709×660 · +341 ms 132,150 709×660 · … 21 more … · +1927 ms -258,333 709×660 · +1968 ms -276,343 709×660 · +2043 ms -294,354 709×660 · +2324 ms -293,354 709×660 · +2713 ms -294,354 709×660
- ✘ **35 drag-notes-to-left-edge** (drags notes by its title bar against the left edge of the screen and lets go): notes (w54) moved 2 times [jolt]
  - +0 ms -294,354 709×660 · +89 ms -275,333 716×669 · +146 ms -58,94 783×766 · +209 ms -36,70 789×776 · +323 ms -1,32 800×791 · +383 ms -1,32 789×776 · +431 ms -1,32 800×791 · +1987 ms 1599,770 800×791
- ✘ **44 drag-calendar-back** (drags calendar away from the top again, a hand's breadth down): calendar (w60) was 61 points from where the pointer carried it, 2989 ms into the step [pulled]
  - +0 ms 16,45 1576×503 · +8 ms 20,48 1576×503 · +77 ms 24,50 1576×503 · +125 ms 24,53 1576×503 · +216 ms 24,54 1576×503 · +1222 ms 28,54 1576×503 · … 6 more … · +1698 ms 72,54 1576×503 · +1759 ms 80,54 1576×503 · +1809 ms 85,54 1576×503 · +2097 ms 86,54 1576×503 · +2568 ms 85,54 1576×503
- ✘ **66 show-desktop** (presses ⌃⌥D): w130 of Mail went 110 points out of its way before it ended up [jolt]
  - +0 ms 358,485 470×416 · +422 ms 482,485 470×416 · +505 ms 565,124 470×416 · +591 ms 565,179 470×416
- ✘ **94 float-all** (presses ⌃⌥⇧F): w130 of Mail went 248 points out of its way before it ended up [jolt]
  - +0 ms 1800,822 470×416 · +797 ms 1924,877 470×416 · +824 ms 565,179 470×416
- ✘ **100 quit** (chooses Quit Arbor in Arbor's menu): w130 of Mail went 248 points out of its way before it ended up [jolt]
  - +0 ms 1800,877 470×416 · +2583 ms 1924,877 470×416 · +2637 ms 565,179 470×416

### Rule 4: the window you switch to comes to the front and into view

- ✘ **35 drag-notes-to-left-edge** (drags notes by its title bar against the left edge of the screen and lets go): notes (w54) is not wholly in view: 0% of it, at 1599,770 800×791 in 0,31 1600×791 [focus]
- ✘ **36 drag-terminal-out** (drags terminal out of the arrangement onto the Desktop and lets go): terminal (w51) is not in front: notes (w54), w130 of Mail, w128 of Mail, preview (w65) ahead of it, of which 1 cover part of it [behind]
- ✘ **36 drag-terminal-out** (drags terminal out of the arrangement onto the Desktop and lets go): terminal (w51) its app is not the one in front (process 6789 is) [focus]
- ✘ **36 drag-terminal-out** (drags terminal out of the arrangement onto the Desktop and lets go): terminal (w51) is not wholly in view: 0% of it, at 1599,790 240×769 in 0,31 1600×791 [focus]
- ✘ **56 frame-finder** (presses ⌃⌥↩): finder (w32) is not in front: preview (w65) ahead of it, none of which covers it [behind]
- ✘ **56 frame-finder** (presses ⌃⌥↩): finder (w32) its app is not the one in front (process 7479 is) [focus]
- ✘ **56 frame-finder** (presses ⌃⌥↩): finder (w32) is not wholly in view: 0% of it, at 1599,770 1576×767 in 0,31 1600×791 [focus]
- ✘ **58 cmd-tab-while-framed** (presses ⌘Tab, back to finder): finder (w32) is not in front: preview (w65), safari (w35) ahead of it, none of which covers it [behind]
- ✘ **58 cmd-tab-while-framed** (presses ⌘Tab, back to finder): finder (w32) its app is not the one in front (process 7479 is) [focus]
- ✘ **58 cmd-tab-while-framed** (presses ⌘Tab, back to finder): finder (w32) is not wholly in view: 0% of it, at 1599,770 1576×767 in 0,31 1600×791 [focus]
- ✘ **81 reach-finder** (clicks finder's title bar, or its Dock icon if that is covered): finder (w32) is not in front: safari (w35), preview (w65), w130 of Mail, w128 of Mail ahead of it, of which 1 cover part of it [behind]
- ✘ **81 reach-finder** (clicks finder's title bar, or its Dock icon if that is covered): finder (w32) its app is not the one in front (process 6198 is) [focus]
- ✘ **81 reach-finder** (clicks finder's title bar, or its Dock icon if that is covered): finder (w32) is not wholly in view: 0% of it, at 1599,770 1576×767 in 0,31 1600×791 [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **36 drag-terminal-out** (drags terminal out of the arrangement onto the Desktop and lets go): terminal (w51) is 1599,790 240×769; its own size was 40,51 877×499 [size-lost]
- ✘ **44 drag-calendar-back** (drags calendar away from the top again, a hand's breadth down): calendar (w60) is 12,43 1576×503; its own size was 404,115 936×599 [size-lost]
- ✘ **91 pause** (presses ⌃⌥⎋): safari (w35) is 12,43 1576×767; its own size was 138,31 1324×791 [size-lost]
- ✘ **91 pause** (presses ⌃⌥⎋): settings (w63) is 877,352 723×470; its own size was 437,85 723×625 [size-lost]
- ✘ **91 pause** (presses ⌃⌥⎋): preview (w65) is 892,558 708×264; its own size was 4,35 708×424 [size-lost]
- ✘ **91 pause** (presses ⌃⌥⎋): w128 of Mail is 729,558 871×264; its own size was 240,72 1120×630 [size-lost]
- ✘ **91 pause** (presses ⌃⌥⎋): textedit (w251) is 908,558 673×264; its own size was 165,65 673×439 [size-lost]
- ✘ **94 float-all** (presses ⌃⌥⇧F): terminal (w51) has its size back but not its place: 40,51 877×499, it was at 1599,790 877×499 [size-lost]
- ✘ **100 quit** (chooses Quit Arbor in Arbor's menu): terminal (w51) has its size back but not its place: 40,51 877×499, it was at 1599,790 877×499 [size-lost]
- ✘ **112 quit-2** (quits Arbor): terminal (w51) has its size back but not its place: 40,51 877×499, it was at 1599,790 877×499 [size-lost]

### Rule L: no window is lost or stuck

- ✘ **60 show-everything** (presses ⌃⌥Space): finder (w32) is out of view: 0% of it is on the display, at 1599,770 1576×767 [lost]
- ✘ **60 show-everything** (presses ⌃⌥Space): notes (w54) is out of view: 0% of it is on the display, at 1599,770 1576×767 [lost]
- ✘ **60 show-everything** (presses ⌃⌥Space): calendar (w60) is out of view: 0% of it is on the display, at 1599,770 1576×767 [lost]
- ✘ **67 show-everything-2** (presses ⌃⌥Space): finder (w32) is out of view: 0% of it is on the display, at 1599,770 1576×767 [lost]
- ✘ **67 show-everything-2** (presses ⌃⌥Space): notes (w54) is out of view: 0% of it is on the display, at 1599,770 1576×767 [lost]
- ✘ **67 show-everything-2** (presses ⌃⌥Space): calendar (w60) is out of view: 0% of it is on the display, at 1599,770 1576×503 [lost]
- ✘ **77 show-everything-3** (presses ⌃⌥Space): finder (w32) is out of view: 0% of it is on the display, at 1599,770 1576×767 [lost]
- ✘ **77 show-everything-3** (presses ⌃⌥Space): notes (w54) is out of view: 0% of it is on the display, at 1599,770 1576×767 [lost]
- ✘ **77 show-everything-3** (presses ⌃⌥Space): calendar (w60) is out of view: 0% of it is on the display, at 1599,770 1576×503 [lost]
- ✘ **82 hide-finder** (presses ⌘H): safari (w35) left the screen, and the step did not say it would [lost]
  - +0 ms 731,43 574×767 · +345 ms off the screen
- ✘ **110 launch-2** (starts Arbor again): finder (w32) is out of view: 0% of it is on the display, at 1599,770 920×436 [lost]
- ✘ **110 launch-2** (starts Arbor again): notes (w54) is out of view: 0% of it is on the display, at 1599,770 1000×660 [lost]
- ✘ **110 launch-2** (starts Arbor again): calendar (w60) is out of view: 0% of it is on the display, at 1599,770 936×599 [lost]
- ✘ **110 launch-2** (starts Arbor again): settings (w63) is out of view: 0% of it is on the display, at 1599,770 723×625 [lost]
- ✘ **110 launch-2** (starts Arbor again): preview (w65) is out of view: 0% of it is on the display, at 1599,770 708×424 [lost]
- ✘ **110 launch-2** (starts Arbor again): textedit (w251) is out of view: 0% of it is on the display, at 1599,790 673×439 [lost]

### Rule -: what the script itself checked

- ✘ **23 dock-icon-mail** (clicks mail's icon in the Dock): the script could not tell which window front is about [script]
- ~ **23 dock-icon-mail** (clicks mail's icon in the Dock): took more than a second longer to agree with the screen: w128 is gone from the window server but Arbor still lists it [script]
- ~ **31 dock-textedit-right** (presses ⌃⌥⌘→): floating w54 and docked w35 overlap by 414×660 [script]
- ~ **31 dock-textedit-right** (presses ⌃⌥⌘→): floating w60 and docked w35 overlap by 399×599 [script]
- ~ **31 dock-textedit-right** (presses ⌃⌥⌘→): floating w63 and docked w35 overlap by 421×625 [script]
- ~ **31 dock-textedit-right** (presses ⌃⌥⌘→): floating w128 and docked w35 overlap by 495×630 [script]
- ~ **33 drag-terminal-onto-finder** (drags terminal by its title bar onto the right part of finder and lets go): floating w54 and docked w51 overlap by 188×660 [script]
- ~ **33 drag-terminal-onto-finder** (drags terminal by its title bar onto the right part of finder and lets go): floating w60 and docked w51 overlap by 173×599 [script]
- ~ **33 drag-terminal-onto-finder** (drags terminal by its title bar onto the right part of finder and lets go): floating w63 and docked w51 overlap by 195×625 [script]
- ~ **33 drag-terminal-onto-finder** (drags terminal by its title bar onto the right part of finder and lets go): floating w128 and docked w51 overlap by 240×630 [script]
- ~ **35 drag-notes-to-left-edge** (drags notes by its title bar against the left edge of the screen and lets go): took more than a second longer to agree with the screen: w54 is parked but 100% of it shows, at -1,32 800×791 [script]
- ✘ **36 drag-terminal-out** (drags terminal out of the arrangement onto the Desktop and lets go): not so: terminal floats [script]
- ~ **43 drag-calendar-to-top** (drags calendar by its title bar against the menu bar and lets go: macOS fills the screen with it): took more than a second longer to agree with the screen: w60 is at 464,31 936×599 but Arbor believes 12,43 1576×503 [script]
- ✘ **53 dock-icon-mail-2** (clicks mail's icon in the Dock): the script could not tell which window front is about [script]
- ~ **69 new-window** (presses ⌘N in Safari): floating w218 and docked w35 overlap by 545×755 [script]
- ~ **75 new-window-while-framed** (presses ⌘N in Safari while its window is framed): floating w231 and docked w35 overlap by 1564×755 [script]
- ✘ **109 dock-icon-mail-3** (clicks mail's icon in the Dock): the script could not tell which window front is about [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 659 ms; blind for 561 ms |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 0 ms; blind for 1470 ms |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (2, 153 ms) | quiet 903 ms; blind for 1119 ms |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal |  | quiet 458 ms; blind for 489 ms |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (3, 49 ms), w55 ×2 (11, 1442 ms), w57 ×1 (6, 222 ms) | quiet 165 ms; blind for 251 ms |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×2 (2, 264 ms) | quiet 1333 ms; blind for 142 ms |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings |  | quiet 121 ms; blind for 633 ms |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (1, 0 ms) | quiet 406 ms; blind for 930 ms |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w71 ×1 (5, 156 ms) | quiet 199 ms; blind for 457 ms |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags calendar by its title bar against the menu bar and lets go | calendar ×3 (41, 4122 ms) | quiet 0 ms; blind for 85 ms |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (36, 2294 ms) | quiet 1058 ms; blind for 79 ms |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 0 ms; blind for 68 ms |  |  |  |  |  |  |  |

### Arbor starts

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 13 | launch | starts Arbor |  | quiet 967 ms; blind for 81 ms |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 14 | leave-alone | does nothing for five seconds |  | quiet 0 ms; blind for 77 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |

### Switching between apps, nothing docked yet

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 15 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 311 ms; blind for 89 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 16 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 271 ms; blind for 123 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 17 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 429 ms; blind for 80 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 18 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 303 ms; blind for 76 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 19 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 447 ms; blind for 91 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 20 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 306 ms; blind for 132 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 21 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 524 ms; blind for 75 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 22 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 82 ms; blind for 112 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 23 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 162 ms; blind for 78 ms |  | ✔ | ✔ |  |  | ✔ | ✘ |
| 24 | cmd-tab | presses ⌘Tab |  | quiet 436 ms; blind for 129 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 25 | cmd-tab-twice | holds ⌘ and presses Tab twice |  | quiet 441 ms; blind for 103 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |

### The first docks, by key

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 26 | reach-finder | clicks finder's title bar, or its Dock icon if that is covered |  | quiet 356 ms; blind for 94 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 27 | dock-finder-left | presses ⌃⌥⌘← | finder ×1 (2, 6 ms), safari ×1 (2, 7 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms) | quiet 589 ms; blind for 86 ms |  | ✘ | ✘ | ✔ |  | ✔ | ✔ |
| 28 | reach-safari | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 502 ms; blind for 103 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 29 | dock-safari-right | presses ⌃⌥⌘→ | finder ×1 (1, 0 ms), safari ×1 (3, 59 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (2, 54 ms), settings ×1 (2, 39 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms) | quiet 1451 ms; blind for 78 ms |  | ✘ | ✘ | ✔ |  | ✔ | ✔ |
| 30 | reach-textedit | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 469 ms; blind for 103 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 31 | dock-textedit-right | presses ⌃⌥⌘→ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 63 ms) | quiet 703 ms; blind for 66 ms |  | ✔ | ✔ | ✔ |  | ✔ | ~ |

### Docking by real drags

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 32 | reach-terminal | clicks terminal's title bar, or its Dock icon if that is covered |  | quiet 559 ms; blind for 72 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 33 | drag-terminal-onto-finder | drags terminal by its title bar onto the right part of finder and lets go | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms) | quiet 908 ms; blind for 175 ms | ✔ | ✘ | ✘ | ✔ |  | ✔ | ~ |
| 34 | reach-notes | clicks notes's title bar, or its Dock icon if that is covered |  | quiet 500 ms; blind for 161 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 35 | drag-notes-to-left-edge | drags notes by its title bar against the left edge of the screen and lets go | safari ×1 (1, 0 ms), textedit ×1 (4, 263 ms), terminal ×1 (1, 0 ms), notes ×2 (7, 1898 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms) | quiet 1533 ms; blind for 143 ms | ✘ | ✘ | ✘ | ✘ |  | ✔ | ~ |
| 36 | drag-terminal-out | drags terminal out of the arrangement onto the Desktop and lets go |  | quiet 0 ms; blind for 253 ms |  |  |  | ✘ | ✘ |  | ✘ |

### Sizes

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 37 | reach-finder | clicks finder's title bar, or its Dock icon if that is covered | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms) | quiet 803 ms; blind for 126 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 38 | drag-gap-beside-finder | drags the gap to the right of finder sixty points to the right |  | quiet 0 ms; blind for 76 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 39 | grow-finder | presses ⌃⌥⌘= |  | quiet 604 ms; blind for 86 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 40 | shrink-finder | presses ⌃⌥⌘- |  | quiet 652 ms; blind for 70 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 41 | balance | presses ⌃⌥⌘0 |  | quiet 607 ms; blind for 73 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |

### macOS's own tiling

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 42 | reach-calendar | clicks calendar's title bar, or its Dock icon if that is covered | finder ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (2, 39 ms), w130 ×1 (2, 39 ms) | quiet 858 ms; blind for 170 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 43 | drag-calendar-to-top | drags calendar by its title bar against the menu bar and lets go: macOS fills the screen with it | calendar ×1 (4, 175 ms), settings ×1 (2, 54 ms), preview ×1 (2, 15 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms) | quiet 0 ms; blind for 80 ms | ✔ | ✘ | ✔ | ✔ |  | ✔ | ~ |
| 44 | drag-calendar-back | drags calendar away from the top again, a hand's breadth down | calendar ×1 (1, 0 ms) | quiet 1109 ms; blind for 76 ms | ✔ | ✔ | ✘ | ✔ | ✘ | ✔ | ✔ |

### Switching between apps, with an arrangement

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 45 | dock-icon-finder-2 | clicks finder's icon in the Dock | finder ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms) | quiet 422 ms; blind for 120 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 46 | dock-icon-safari-2 | clicks safari's icon in the Dock | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 594 ms; blind for 96 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 47 | dock-icon-textedit-2 | clicks textedit's icon in the Dock | safari ×1 (1, 0 ms), textedit ×1 (2, 19 ms) | quiet 423 ms; blind for 75 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 48 | dock-icon-terminal-2 | clicks terminal's icon in the Dock | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms) | quiet 493 ms; blind for 124 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 49 | dock-icon-notes-2 | clicks notes's icon in the Dock | terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 385 ms; blind for 77 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 50 | dock-icon-calendar-2 | clicks calendar's icon in the Dock | notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 548 ms; blind for 82 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 51 | dock-icon-settings-2 | clicks settings's icon in the Dock | calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (2, 63 ms), w130 ×1 (2, 63 ms) | quiet 697 ms; blind for 77 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 52 | dock-icon-preview-2 | clicks preview's icon in the Dock |  | quiet 393 ms; blind for 90 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 53 | dock-icon-mail-2 | clicks mail's icon in the Dock |  | quiet 387 ms; blind for 115 ms |  | ✔ | ✔ |  |  | ✔ | ✘ |
| 54 | cmd-tab-2 | presses ⌘Tab |  | quiet 599 ms; blind for 333 ms |  | ✘ |  |  |  |  |  |

### The view goes in and out

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 55 | reach-finder | clicks finder's title bar, or its Dock icon if that is covered | finder ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms) | quiet 622 ms; blind for 84 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 56 | frame-finder | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms) | quiet 1554 ms; blind for 105 ms |  |  | ✔ | ✘ |  | ✔ | ✔ |
| 57 | dock-icon-safari-while-framed | clicks safari's icon in the Dock, whose window is out of view |  | quiet 514 ms; blind for 270 ms |  |  |  |  |  |  |  |
| 58 | cmd-tab-while-framed | presses ⌘Tab, back to finder |  | quiet 1042 ms; blind for 196 ms |  |  | ✔ | ✘ |  | ✔ | ✔ |
| 59 | dock-icon-calendar-while-framed | clicks calendar's icon in the Dock, whose window floats and is out of view | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms) | quiet 675 ms; blind for 175 ms |  |  | ✔ | ✔ |  | ✔ | ✔ |
| 60 | show-everything | presses ⌃⌥Space | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms) | quiet 909 ms; blind for 284 ms |  | ✘ |  |  |  | ✘ |  |
| 61 | reach-safari | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 453 ms; blind for 112 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 62 | frame-safari | presses ⌃⌥↩ | safari ×1 (2, 67 ms), textedit ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms) | quiet 1047 ms; blind for 72 ms |  |  | ✔ | ✔ |  | ✔ | ✔ |
| 63 | neighbour-left | presses ⌃⌥← | safari ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms) | quiet 1206 ms; blind for 109 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 64 | back | presses ⌃⌥[ | safari ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms) | quiet 835 ms; blind for 132 ms |  |  | ✔ | ✔ |  | ✔ | ✔ |
| 65 | step-out | presses ⌃⌥↑ | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (2, 43 ms), w130 ×1 (2, 43 ms) | quiet 913 ms; blind for 73 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 66 | show-desktop | presses ⌃⌥D | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (2, 25 ms), w128 ×1 (3, 169 ms), w130 ×1 (3, 169 ms) | quiet 1492 ms; blind for 82 ms |  |  | ✘ |  |  | ✔ | ✔ |
| 67 | show-everything-2 | presses ⌃⌥Space | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms) | quiet 905 ms; blind for 68 ms |  | ✘ | ✔ |  |  | ✘ | ✔ |

### Windows come and go

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 68 | reach-safari | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 480 ms; blind for 105 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 69 | new-window | presses ⌘N in Safari |  | quiet 1055 ms; blind for 841 ms |  |  |  |  |  |  | ~ |
| 70 | window-menu | chooses Safari's first window in the Window menu |  | quiet 1541 ms; blind for 571 ms |  |  |  |  |  |  |  |
| 71 | cmd-backtick | presses ⌘` for Safari's other window |  | quiet 924 ms; blind for 96 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 72 | close-window | presses ⌘W |  | quiet 1240 ms; blind for 186 ms |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 73 | reach-safari | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 323 ms; blind for 115 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 74 | frame-safari | presses ⌃⌥↩ | safari ×1 (2, 79 ms), textedit ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms) | quiet 1602 ms; blind for 108 ms |  |  | ✔ | ✔ |  | ✔ | ✔ |
| 75 | new-window-while-framed | presses ⌘N in Safari while its window is framed |  | quiet 1106 ms; blind for 125 ms |  |  | ✔ | ✔ |  | ✔ | ~ |
| 76 | close-window-while-framed | presses ⌘W |  | quiet 977 ms; blind for 72 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 77 | show-everything-3 | presses ⌃⌥Space | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms) | quiet 736 ms; blind for 76 ms |  | ✔ | ✔ |  |  | ✘ | ✔ |
| 78 | reach-safari | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 393 ms; blind for 71 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 79 | minimize-safari | presses ⌘M | safari ×1 (16, 459 ms), textedit ×1 (2, 85 ms), terminal ×1 (1, 0 ms), calendar ×1 (2, 20 ms), settings ×1 (1, 0 ms), preview ×1 (2, 11 ms), w128 ×1 (2, 35 ms), w130 ×1 (1, 0 ms) | quiet 2522 ms; blind for 99 ms |  | ✘ | ✔ |  |  | ✔ | ✔ |
| 80 | restore-safari | clicks its miniature in the Dock | safari ×1 (17, 403 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (2, 31 ms), w128 ×1 (2, 92 ms), w130 ×1 (1, 0 ms) | quiet 1469 ms; blind for 164 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 81 | reach-finder | clicks finder's title bar, or its Dock icon if that is covered |  | quiet 262 ms; blind for 150 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ |
| 82 | hide-finder | presses ⌘H | textedit ×1 (3, 109 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (2, 19 ms), w128 ×1 (2, 99 ms), w130 ×1 (1, 0 ms) | quiet 1523 ms; blind for 109 ms |  | ✘ | ✔ |  |  | ✘ | ✔ |
| 83 | unhide-finder | clicks its icon in the Dock | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms) | quiet 758 ms; blind for 67 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 84 | reach-textedit | clicks textedit's title bar, or its Dock icon if that is covered | finder ×1 (1, 0 ms), textedit ×1 (2, 31 ms) | quiet 544 ms; blind for 72 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 85 | quit-textedit | presses ⌘Q in TextEdit | finder ×1 (1, 0 ms) | quiet 933 ms; blind for 286 ms |  |  |  |  |  |  |  |
| 86 | reopen-textedit | opens the document again |  | quiet 924 ms; blind for 469 ms |  |  |  |  |  |  |  |

### Full screen

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 87 | reach-safari | clicks safari's title bar, or its Dock icon if that is covered | finder ×1 (1, 0 ms), safari ×1 (2, 127 ms), textedit ×1 (1, 0 ms) | quiet 507 ms; blind for 72 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 88 | full-screen | presses ⌃⌘F in Safari | finder ×1 (2, 60 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 140 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 89 | leave-full-screen | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (4, 195 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 0 ms; blind for 180 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |

### The ways out

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 90 | reach-safari | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 471 ms; blind for 74 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 91 | pause | presses ⌃⌥⎋ | finder ×1 (2, 27 ms), terminal ×1 (2, 19 ms), notes ×1 (2, 50 ms), calendar ×1 (1, 0 ms) | quiet 982 ms; blind for 75 ms |  |  | ✔ |  | ✘ | ✔ | ✔ |
| 92 | drag-calendar-while-paused | moves calendar a little while Arbor is paused |  | quiet 0 ms; blind for 67 ms | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 93 | resume | presses ⌃⌥⎋ | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 899 ms; blind for 78 ms |  |  | ✔ |  |  | ✔ | ✔ |
| 94 | float-all | presses ⌃⌥⇧F | finder ×1 (1, 0 ms), safari ×1 (2, 37 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (2, 12 ms), w128 ×1 (2, 27 ms), w130 ×1 (2, 27 ms), textedit ×1 (1, 0 ms) | quiet 1273 ms; blind for 76 ms |  |  | ✘ |  | ✘ | ✔ | ✔ |
| 95 | reach-finder | clicks finder's title bar, or its Dock icon if that is covered |  | quiet 453 ms; blind for 187 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 96 | dock-finder-left-2 | presses ⌃⌥⌘← | finder ×1 (2, 20 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (2, 24 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1236 ms; blind for 96 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 97 | reach-safari | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 501 ms; blind for 139 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 98 | dock-safari-right-2 | presses ⌃⌥⌘→ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (2, 51 ms), notes ×1 (2, 36 ms), calendar ×1 (2, 30 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1149 ms; blind for 76 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 99 | frame-safari-2 | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (3, 100 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1323 ms; blind for 75 ms |  |  | ✔ | ✔ |  | ✔ | ✔ |
| 100 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (2, 31 ms), safari ×1 (2, 38 ms), terminal ×1 (2, 51 ms), notes ×1 (2, 7 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (2, 54 ms), w130 ×1 (2, 54 ms), textedit ×1 (1, 0 ms) | quiet 992 ms; blind for 79 ms |  |  | ✘ |  | ✘ | ✔ | ✔ |

### After Arbor: can every window be reached?

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 101 | dock-icon-finder-3 | clicks finder's icon in the Dock |  | quiet 435 ms; blind for 92 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 102 | dock-icon-safari-3 | clicks safari's icon in the Dock |  | quiet 351 ms; blind for 80 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 103 | dock-icon-textedit-3 | clicks textedit's icon in the Dock |  | quiet 268 ms; blind for 79 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 104 | dock-icon-terminal-3 | clicks terminal's icon in the Dock |  | quiet 387 ms; blind for 104 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 105 | dock-icon-notes-3 | clicks notes's icon in the Dock |  | quiet 369 ms; blind for 77 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 106 | dock-icon-calendar-3 | clicks calendar's icon in the Dock |  | quiet 517 ms; blind for 71 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 107 | dock-icon-settings-3 | clicks settings's icon in the Dock |  | quiet 577 ms; blind for 68 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 108 | dock-icon-preview-3 | clicks preview's icon in the Dock |  | quiet 456 ms; blind for 79 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 109 | dock-icon-mail-3 | clicks mail's icon in the Dock |  | quiet 459 ms; blind for 102 ms |  | ✔ | ✔ |  |  | ✔ | ✘ |

### The next morning: Arbor starts again

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 110 | launch-2 | starts Arbor again | finder ×1 (1, 0 ms), safari ×1 (3, 128 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 820 ms; blind for 69 ms |  | ✘ | ✔ |  |  | ✘ | ✔ |
| 111 | leave-alone-2 | does nothing for five seconds |  | quiet 0 ms; blind for 80 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 112 | quit-2 | quits Arbor | finder ×1 (1, 0 ms), safari ×1 (2, 77 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w128 ×1 (1, 0 ms), w130 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1037 ms; blind for 63 ms |  |  | ✔ |  | ✘ | ✔ | ✔ |
