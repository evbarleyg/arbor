113 steps in 316 s, 97 of them judged, 18 with a rule broken. The sampler: samples 12372 seconds 316.9 hz 39.0 cost-ms 2.00 late 26 longest-gap-ms 706.
Input: 189 presses, releases, keys and scrolls reached the apps, half of them within 522 µs, 99 in 100 within 37158 µs, the latest after 68634 µs.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 5 | 1 | 91 drag-preview-to-left-edge |
| 2 | nothing moves that the person did not move | 78 | 9 | 25 dock-left, 28 quit-preview, 35 leave-full-screen, 72 dock-left, 79 dock-down, 89 minimize-notes, 91 drag-preview-to-left-edge, 99 minimize-textedit, 109 dock-icon-notes |
| 3 | no jolts: a window moves once, to where it ends up | 99 | 1 | 103 resume |
| 4 | the window you switch to comes to the front and into view | 69 | 1 | 91 drag-preview-to-left-edge |
| 5 | quitting, Float All and pause give windows their own sizes back | 5 | 3 | 77 float-all-here, 101 pause, 104 quit |
| 6 | what a person presses reaches the apps, at once | 49 | 0 |  |
| L | no window is lost or stuck | 99 | 1 | 69 launch |
| - | what the script itself checked | 99 | 4 | 18 restore-calendar, 43 leave-alone, 51 leave-alone, 92 restore-notes |

## Findings

### Rule 1: never fight macOS: where it answers a drag, Arbor stands aside

- ✘ **91 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): preview (w565) macOS's tiling preview and Arbor's drop preview were up at the same time [fought]
- ✘ **91 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): preview (w565) macOS answered the drag, and Arbor docked the window [fought]

### Rule 2: nothing moves that the person did not move

- ✘ **25 dock-left** (presses ⌃⌥⌘ and the left arrow): safari (w436) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×790 · +1264 ms 806,31 794×790
- ✘ **25 dock-left** (presses ⌃⌥⌘ and the left arrow): textedit (w445) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +1264 ms 806,65 673×439
- ✘ **25 dock-left** (presses ⌃⌥⌘ and the left arrow): terminal (w450) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 97,238 877×499 · +1264 ms 806,238 793×499
- ✘ **25 dock-left** (presses ⌃⌥⌘ and the left arrow): notes (w451) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 800×791 · +1264 ms 806,31 794×791
- ✘ **25 dock-left** (presses ⌃⌥⌘ and the left arrow): calendar (w454) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 415,115 909×600 · +1264 ms 806,115 794×600
- ✘ **25 dock-left** (presses ⌃⌥⌘ and the left arrow): settings (w455) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +1264 ms 806,85 723×625
- ✘ **25 dock-left** (presses ⌃⌥⌘ and the left arrow): preview (w459) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +1264 ms 806,35 708×424
- ✘ **25 dock-left** (presses ⌃⌥⌘ and the left arrow): mail (w460) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1264 ms 729,72 871×630
- ~ **25 dock-left** (presses ⌃⌥⌘ and the left arrow): w462 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1264 ms 930,179 470×416
- ✘ **28 quit-preview** (presses ⌘Q in preview): safari (w436) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×790 · +990 ms 1599,770 1324×790
- ✘ **28 quit-preview** (presses ⌘Q in preview): textedit (w445) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +990 ms 1599,790 673×439
- ✘ **28 quit-preview** (presses ⌘Q in preview): terminal (w450) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 97,238 877×499 · +990 ms 1599,790 877×499
- ✘ **28 quit-preview** (presses ⌘Q in preview): notes (w451) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 800×791 · +990 ms 1599,770 800×791
- ✘ **28 quit-preview** (presses ⌘Q in preview): calendar (w454) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 415,115 909×600 · +990 ms 1599,770 909×600
- ✘ **28 quit-preview** (presses ⌘Q in preview): settings (w455) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +990 ms 1599,770 723×625
- ✘ **28 quit-preview** (presses ⌘Q in preview): mail (w460) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +990 ms 1599,770 1120×630
- ~ **28 quit-preview** (presses ⌘Q in preview): w462 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +990 ms 1924,877 470×416
- ✘ **35 leave-full-screen** (presses ⌃⌘F again): preview (w507) is not back where it was after step 33: 806,35 708×424, it was at 4,35 708×424 [moved-unasked]
- ✘ **72 dock-left** (presses ⌃⌥⌘ and the left arrow): finder (w433) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,120 920×436 · +1092 ms 806,120 794×436
- ✘ **72 dock-left** (presses ⌃⌥⌘ and the left arrow): textedit (w445) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +1092 ms 806,65 673×439
- ✘ **72 dock-left** (presses ⌃⌥⌘ and the left arrow): terminal (w450) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 97,238 877×499 · +1092 ms 806,238 793×499
- ✘ **72 dock-left** (presses ⌃⌥⌘ and the left arrow): notes (w451) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 800×791 · +1092 ms 806,31 794×791
- ✘ **72 dock-left** (presses ⌃⌥⌘ and the left arrow): calendar (w454) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 415,115 909×600 · +1092 ms 806,115 794×600
- ✘ **72 dock-left** (presses ⌃⌥⌘ and the left arrow): settings (w455) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +1092 ms 806,85 723×625
- ✘ **72 dock-left** (presses ⌃⌥⌘ and the left arrow): mail (w460) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1092 ms 729,72 871×630
- ~ **72 dock-left** (presses ⌃⌥⌘ and the left arrow): w462 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1092 ms 930,179 470×416
- ✘ **72 dock-left** (presses ⌃⌥⌘ and the left arrow): preview (w565) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +1092 ms 806,35 708×424
- ✘ **79 dock-down** (presses ⌃⌥⌘ and the down arrow): finder (w433) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,120 920×436 · +1183 ms 340,31 920×297
- ✘ **79 dock-down** (presses ⌃⌥⌘ and the down arrow): textedit (w445) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +1183 ms 165,31 673×297
- ✘ **79 dock-down** (presses ⌃⌥⌘ and the down arrow): terminal (w450) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,238 795×499 · +1183 ms 806,31 795×289
- ✘ **79 dock-down** (presses ⌃⌥⌘ and the down arrow): notes (w451) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 800×791 · +1183 ms 0,31 800×320
- ✘ **79 dock-down** (presses ⌃⌥⌘ and the down arrow): calendar (w454) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 415,115 909×600 · +1183 ms 415,31 909×503
- ✘ **79 dock-down** (presses ⌃⌥⌘ and the down arrow): mail (w460) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1183 ms 240,31 1120×297
- ~ **79 dock-down** (presses ⌃⌥⌘ and the down arrow): w462 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1183 ms 565,83 470×416
- ✘ **79 dock-down** (presses ⌃⌥⌘ and the down arrow): safari (w554) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×790 · +1183 ms 138,31 1324×297
- ✘ **79 dock-down** (presses ⌃⌥⌘ and the down arrow): preview (w565) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +1183 ms 4,31 708×297
- ✘ **89 minimize-notes** (presses ⌘M): textedit (w657) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +1332 ms 165,31 673×297
- ✘ **91 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): finder (w433) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,31 920×297 · +5690 ms 806,31 794×297
- ✘ **91 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): calendar (w454) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 415,31 909×503 · +5690 ms 806,31 794×503
- ✘ **91 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): mail (w460) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,31 1120×297 · +5690 ms 729,31 871×297
- ~ **91 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): w462 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,83 470×416 · +5690 ms 930,83 470×416
- ✘ **91 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): safari (w554) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×297 · +5690 ms 806,31 794×297
- ✘ **91 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): textedit (w657) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,31 673×297 · +5690 ms 806,31 673×297
- ✘ **99 minimize-textedit** (presses ⌘M): safari-new-97 (w675) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,60 794×297 · +1425 ms 806,31 794×297
- ✘ **109 dock-icon-notes** (clicks notes's icon in the Dock): notes (w451) moved, and the step did not name it [moved-unasked]
  - +0 ms 1413,812 53×53 · +21 ms 1398,779 67×86 · +83 ms 1088,579 374×286 · +150 ms 485,351 973×514 · +156 ms 392,315 1066×550 · +217 ms 53,131 1400×734 · … 3 more … · +327 ms 0,31 1244×790 · +367 ms 0,31 1071×790 · +431 ms 0,31 856×790 · +437 ms 0,31 833×790 · +469 ms 0,31 800×790

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **25 dock-left** (presses ⌃⌥⌘ and the left arrow): the last window came to rest 1013 ms after the key or the button [slow]
- ~ **56 view-in** (presses ⌃⌥↓): the last window came to rest 717 ms after the key or the button [slow]
- ~ **72 dock-left** (presses ⌃⌥⌘ and the left arrow): the last window came to rest 808 ms after the key or the button [slow]
- ~ **79 dock-down** (presses ⌃⌥⌘ and the down arrow): the last window came to rest 895 ms after the key or the button [slow]
- ✘ **103 resume** (presses ⌃⌥⎋): preview (w565) moved 2 times [jolt]
  - +0 ms 4,35 708×424 · +296 ms 1599,770 708×424 · +1046 ms 12,43 782×767
- ~ **103 resume** (presses ⌃⌥⎋): the last window came to rest 819 ms after the key or the button [slow]

### Rule 4: the window you switch to comes to the front and into view

- ✘ **91 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): preview (w565) is not wholly in view: 0% of it, at 1599,770 800×791 in 0,31 1600×791 [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **77 float-all-here** (floats every window of this display): terminal (w450) is 806,238 795×499; its own size was 97,238 877×499 [size-lost]
- ✘ **101 pause** (presses ⌃⌥⎋): finder (w433) is 806,31 794×297; its own size was 340,120 920×436 [size-lost]
- ✘ **101 pause** (presses ⌃⌥⎋): terminal (w450) is 806,31 795×289; its own size was 97,238 877×499 [size-lost]
- ✘ **101 pause** (presses ⌃⌥⎋): calendar (w454) is 806,31 794×503; its own size was 415,115 909×600 [size-lost]
- ✘ **101 pause** (presses ⌃⌥⎋): settings (w455) is 835,340 723×470; its own size was 437,85 723×625 [size-lost]
- ✘ **101 pause** (presses ⌃⌥⎋): mail (w460) is 729,31 871×297; its own size was 240,72 1120×630 [size-lost]
- ✘ **101 pause** (presses ⌃⌥⎋): safari (w554) is 806,31 794×297; its own size was 138,31 1324×790 [size-lost]
- ✘ **104 quit** (chooses Quit Arbor in Arbor's menu): finder (w433) is 806,31 794×297; its own size was 340,120 920×436 [size-lost]
- ✘ **104 quit** (chooses Quit Arbor in Arbor's menu): terminal (w450) is 806,238 795×499; its own size was 97,238 877×499 [size-lost]

### Rule L: no window is lost or stuck

- ✘ **69 launch** (starts Arbor): finder (w433) is out of view: 0% of it is on a display, at 1599,770 920×436 [lost]

### Rule -: what the script itself checked

- ✘ **18 restore-calendar** (clicks its miniature in the Dock): the act was not performed: false could not be done [script]
- ✘ **43 leave-alone** (does nothing for half a minute): with nothing to do Arbor used 1.6 % of a core [busy]
- ✘ **51 leave-alone** (does nothing for half a minute): with nothing to do Arbor used 1.5 % of a core [busy]
- ✘ **92 restore-notes** (clicks its miniature in the Dock): the act was not performed: false could not be done [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (3, 103 ms) | quiet 1084 ms; blind for 108 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 468 ms; blind for 686 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×2 (2, 251 ms) | quiet 1365 ms; blind for 333 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (4, 299 ms) | quiet 1297 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (5, 300 ms) | quiet 1327 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (4, 342 ms) | quiet 1361 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (2, 102 ms) | quiet 725 ms; blind for 221 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (2, 25 ms) | quiet 1042 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w462 ×1 (7, 207 ms) | quiet 873 ms; blind for 434 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (39, 4247 ms) | quiet 1432 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (34, 2282 ms) | quiet 1032 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 424 ms |  |  |  |  |  |  |  |  |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 13 | launch | starts Arbor |  | quiet 1108 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 14 | view-all | presses ⌃⌥Space |  | quiet 847 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 15 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 444 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 16 | minimize-calendar | presses ⌘M |  | quiet 763 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 17 | view-frame | presses ⌃⌥↩ |  | quiet 715 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 18 | restore-calendar | clicks its miniature in the Dock |  | quiet 350 ms |  |  |  |  |  |  |  | ✘ |
| 19 | view-all | presses ⌃⌥Space |  | quiet 702 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 20 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 508 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | hide-notes | presses ⌘H |  | quiet 869 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 22 | unhide-notes | clicks its icon in the Dock |  | quiet 462 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | focus-up | presses ⌃⌥⇧ and the up arrow |  | quiet 384 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 24 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 512 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w462 ×1 (1, 0 ms) | quiet 1105 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 26 | view-desktop | presses ⌃⌥D | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w462 ×1 (1, 0 ms) | quiet 862 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 27 | view-in | presses ⌃⌥↓ |  | quiet 713 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 28 | quit-preview | presses ⌘Q in preview | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w462 ×1 (1, 0 ms) | quiet 877 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 29 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w462 ×1 (1, 0 ms) | quiet 919 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 30 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 549 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | minimize-calendar | presses ⌘M | calendar ×1 (18, 347 ms) | quiet 1663 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 32 | reopen-preview | opens preview's document again |  | quiet 1004 ms; blind for 183 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 33 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 428 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 407 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 35 | leave-full-screen | presses ⌃⌘F again | safari ×1 (2, 64 ms) | quiet 394 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 36 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 522 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 37 | restore-calendar | clicks its miniature in the Dock | calendar ×1 (11, 352 ms) | quiet 1010 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 475 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w462 ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 1234 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 40 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 531 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | quit-safari | presses ⌘Q in safari |  | quiet 750 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 42 | reopen-safari | opens safari's document again |  | quiet 794 ms; blind for 706 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 43 | leave-alone | does nothing for half a minute |  | quiet 411 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 44 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 364 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | quit-preview | presses ⌘Q in preview |  | quiet 921 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 46 | cmd-tab-3 | holds ⌘ and presses Tab 3 time(s) |  | quiet 455 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 47 | reopen-preview | opens preview's document again |  | quiet 1024 ms; blind for 281 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 48 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 385 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | window-menu-safari | chooses safari's first window in the Window menu |  | quiet 1303 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | view-desktop | presses ⌃⌥D |  | quiet 684 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 51 | leave-alone | does nothing for half a minute |  | quiet 372 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 52 | view-out | presses ⌃⌥↑ | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w462 ×1 (1, 0 ms), safari ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 929 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 53 | cmd-tab-2 | holds ⌘ and presses Tab 2 time(s) |  | quiet 459 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 54 | cmd-tab-3 | holds ⌘ and presses Tab 3 time(s) |  | quiet 514 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 55 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 658 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 56 | view-in | presses ⌃⌥↓ | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w462 ×1 (1, 0 ms), safari ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 1036 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 57 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 490 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 58 | redo | presses ⌃⌥⇧Z |  | quiet 807 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 59 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms) | quiet 969 ms |  |  | ✔ |  | ✔ |  | ✔ | ✔ |
| 60 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 387 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 439 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 62 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 372 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 63 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 380 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 64 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 486 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 65 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 460 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 66 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 397 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 67 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 426 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 68 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 367 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 69 | launch | starts Arbor | finder ×1 (1, 0 ms) | quiet 943 ms |  | ✔ | ✔ |  |  |  | ✘ | ✔ |
| 70 | float-all | presses ⌃⌥⇧F | finder ×1 (1, 0 ms) | quiet 822 ms |  |  | ✔ |  | ✔ |  | ✔ | ✔ |
| 71 | click-safari | clicks safari's title bar |  | quiet 405 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 72 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w462 ×1 (1, 0 ms), safari ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 782 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 73 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 410 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 74 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 411 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 75 | double-click-terminal | double-clicks terminal's title bar: macOS zooms the window | terminal ×1 (15, 381 ms) | quiet 930 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 76 | double-click-terminal-again | double-clicks it again: macOS takes the window back | terminal ×1 (10, 354 ms) | quiet 711 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 77 | float-all-here | floats every window of this display | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w462 ×1 (1, 0 ms), safari ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 1039 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 78 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 399 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 79 | dock-down | presses ⌃⌥⌘ and the down arrow | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w462 ×1 (1, 0 ms), safari ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 661 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 80 | view-all | presses ⌃⌥Space |  | quiet 664 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 81 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 484 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 82 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 393 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 83 | leave-full-screen | presses ⌃⌘F again | safari ×1 (2, 44 ms) | quiet 382 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 84 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 475 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 85 | quit-textedit | presses ⌘Q in textedit |  | quiet 760 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 86 | reopen-textedit | opens textedit's document again |  | quiet 1024 ms; blind for 177 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 87 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 577 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 88 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 362 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 89 | minimize-notes | presses ⌘M | notes ×1 (13, 424 ms), textedit ×1 (1, 0 ms) | quiet 1728 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 90 | view-left | presses ⌃⌥← |  | quiet 680 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 91 | drag-preview-to-left-edge | drags preview by its title bar against the left edge of the screen and lets go | finder ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w462 ×1 (1, 0 ms), safari ×1 (1, 0 ms), preview ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1341 ms | ✘ | ✘ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 92 | restore-notes | clicks its miniature in the Dock |  | quiet 357 ms |  |  |  |  |  |  |  | ✘ |
| 93 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 447 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 94 | double-click-finder | double-clicks finder's title bar: macOS zooms the window | finder ×1 (7, 252 ms) | quiet 769 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 95 | double-click-finder-again | double-clicks it again: macOS takes the window back | finder ×1 (9, 248 ms) | quiet 730 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 96 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 396 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 97 | new-window-safari | presses ⌘N in safari |  | quiet 1023 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 98 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 386 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 99 | minimize-textedit | presses ⌘M | textedit ×1 (16, 438 ms), safari-new-97 ×1 (1, 0 ms) | quiet 1745 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 100 | close-window | presses ⌘W |  | quiet 725 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 101 | pause | presses ⌃⌥⎋ | preview ×1 (1, 0 ms) | quiet 915 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 102 | restore-textedit | clicks its miniature in the Dock | textedit ×1 (15, 468 ms) | quiet 775 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 103 | resume | presses ⌃⌥⎋ | preview ×2 (2, 750 ms) | quiet 1126 ms |  |  | ✘ |  |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 104 | quit | chooses Quit Arbor in Arbor's menu | terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (2, 32 ms), mail ×1 (2, 75 ms), w462 ×1 (2, 75 ms), safari ×1 (2, 83 ms), preview ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 926 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 105 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 475 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 106 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 374 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 107 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 383 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 108 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 366 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 109 | dock-icon-notes | clicks notes's icon in the Dock | notes ×1 (13, 448 ms) | quiet 868 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 110 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 361 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 111 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 408 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 112 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 431 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 113 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 471 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
