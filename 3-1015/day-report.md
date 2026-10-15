108 steps in 486 s, 93 of them judged, 24 with a rule broken. The sampler: samples 17317 seconds 438.2 hz 39.5 cost-ms 2.75 late 27 longest-gap-ms 1436 whole-samples 19275 whole-seconds 487.7 whole-late 42.
Input: 330 presses, releases, keys and scrolls reached the apps, half of them within 743 µs, 99 in 100 within 22364 µs, the latest after 111067 µs.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 5 | 1 | 36 drag-calendar-to-right-edge |
| 2 | nothing moves that the person did not move | 70 | 5 | 21 dock-left, 25 rotate, 35 dock-left, 52 dock-up, 88 resume |
| 3 | no jolts: a window moves once, to where it ends up | 95 | 2 | 67 drag-mail-to-right-edge, 77 drag-gap-beside-textedit |
| 4 | the window you switch to comes to the front and into view | 69 | 6 | 27 drag-preview-by, 45 dock-icon-preview, 61 dock-icon-preview, 67 drag-mail-to-right-edge, 89 view-frame, 107 dock-icon-preview |
| 5 | quitting, Float All and pause give windows their own sizes back | 3 | 3 | 58 quit, 87 pause, 99 quit |
| 6 | what a person presses reaches the apps, at once | 44 | 0 |  |
| L | no window is lost or stuck | 95 | 0 |  |
| - | what the script itself checked | 95 | 10 | 27 drag-preview-by, 32 leave-alone, 33 leave-alone, 38 drag-notes-by, 39 view-frame, 42 undo, 44 view-in, 48 view-all, 52 dock-up, 62 launch |

## Findings

### Rule 1: never fight macOS: where it answers a drag, Arbor stands aside

- ✘ **36 drag-calendar-to-right-edge** (drags calendar by its title bar against the right edge of the screen and lets go): calendar (w476) macOS's tiling preview and Arbor's drop preview were up at the same time [fought]

### Rule 2: nothing moves that the person did not move

- ✘ **21 dock-left** (presses ⌃⌥⌘ and the left arrow): finder (w452) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,120 920×436 · +1374 ms 806,120 794×436
- ✘ **21 dock-left** (presses ⌃⌥⌘ and the left arrow): textedit (w466) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +1374 ms 806,65 673×439
- ✘ **21 dock-left** (presses ⌃⌥⌘ and the left arrow): notes (w472) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 800×791 · +1374 ms 806,31 794×791
- ✘ **21 dock-left** (presses ⌃⌥⌘ and the left arrow): calendar (w476) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 415,115 909×602 · +1374 ms 806,115 794×602
- ✘ **21 dock-left** (presses ⌃⌥⌘ and the left arrow): settings (w477) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +1374 ms 806,85 723×625
- ✘ **21 dock-left** (presses ⌃⌥⌘ and the left arrow): preview (w479) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +1374 ms 806,35 708×424
- ✘ **21 dock-left** (presses ⌃⌥⌘ and the left arrow): mail (w481) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1374 ms 729,72 871×630
- ~ **21 dock-left** (presses ⌃⌥⌘ and the left arrow): w483 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1374 ms 930,179 470×416
- ✘ **25 rotate** (presses ⌃⌥R): finder (w452) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,120 794×436 · +1586 ms 340,433 920×389
- ✘ **25 rotate** (presses ⌃⌥R): notes (w472) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,31 794×791 · +1586 ms 0,433 800×389
- ✘ **25 rotate** (presses ⌃⌥R): calendar (w476) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,115 794×602 · +1586 ms 415,319 909×503
- ✘ **25 rotate** (presses ⌃⌥R): settings (w477) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,85 723×625 · +1586 ms 437,352 723×470
- ✘ **25 rotate** (presses ⌃⌥R): preview (w479) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,35 708×424 · +1586 ms 4,433 708×389
- ✘ **25 rotate** (presses ⌃⌥R): mail (w481) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 729,72 871×630 · +1586 ms 240,433 1120×389
- ~ **25 rotate** (presses ⌃⌥R): w483 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 930,179 470×416 · +1586 ms 565,485 470×416
- ✘ **35 dock-left** (presses ⌃⌥⌘ and the left arrow): finder (w452) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,433 920×389 · +1282 ms 806,433 794×389
- ✘ **35 dock-left** (presses ⌃⌥⌘ and the left arrow): notes (w472) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,433 800×389 · +1282 ms 806,433 794×389
- ✘ **35 dock-left** (presses ⌃⌥⌘ and the left arrow): calendar (w476) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 415,319 909×503 · +1282 ms 806,319 794×503
- ✘ **35 dock-left** (presses ⌃⌥⌘ and the left arrow): settings (w477) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,352 723×470 · +1282 ms 806,352 723×470
- ✘ **35 dock-left** (presses ⌃⌥⌘ and the left arrow): preview (w479) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms -84,432 708×389 · +1282 ms 806,433 708×389
- ✘ **35 dock-left** (presses ⌃⌥⌘ and the left arrow): mail (w481) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,433 1120×389 · +1282 ms 729,433 871×389
- ~ **35 dock-left** (presses ⌃⌥⌘ and the left arrow): w483 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,485 470×416 · +1282 ms 930,485 470×416
- ✘ **52 dock-up** (presses ⌃⌥⌘ and the up arrow): finder (w452) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,433 920×389 · +1243 ms 340,562 920×260
- ✘ **52 dock-up** (presses ⌃⌥⌘ and the up arrow): notes (w472) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,433 800×389 · +1243 ms 0,502 800×320
- ✘ **52 dock-up** (presses ⌃⌥⌘ and the up arrow): preview (w479) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms -84,433 708×389 · +1243 ms -84,562 708×260
- ✘ **52 dock-up** (presses ⌃⌥⌘ and the up arrow): mail (w481) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,433 1120×389 · +1243 ms 240,562 1120×260
- ~ **52 dock-up** (presses ⌃⌥⌘ and the up arrow): w483 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,485 470×416 · +1243 ms 565,614 470×416
- ~ **67 drag-mail-to-right-edge** (drags mail by its title bar against the right edge of the screen and lets go): w483 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +867 ms 591,191 470×416 · +928 ms 618,203 470×416 · +965 ms 644,215 470×416 · +1056 ms 671,227 470×416 · +1160 ms 698,240 470×416 · … 23 more … · +4318 ms 1297,394 470×416 · +4401 ms 1074,288 470×416 · +4489 ms 953,230 470×416 · +4600 ms 933,221 470×416 · +4610 ms 930,219 470×416
- ✘ **88 resume** (presses ⌃⌥⎋): finder (w452) is not back where it was after step 86: 1599,770 920×436, it was at 1599,770 1576×767 [moved-unasked]
- ✘ **88 resume** (presses ⌃⌥⎋): safari (w455) is not back where it was after step 86: 1599,770 1324×791, it was at 1599,770 1576×248 [moved-unasked]
- ✘ **88 resume** (presses ⌃⌥⎋): textedit (w466) is not back where it was after step 86: 1599,790 800×791, it was at 1599,790 375×248 [moved-unasked]
- ✘ **88 resume** (presses ⌃⌥⎋): notes (w472) is not back where it was after step 86: 1599,770 800×791, it was at 1599,770 709×320 [moved-unasked]
- ✘ **88 resume** (presses ⌃⌥⎋): calendar (w476) is not back where it was after step 86: 1599,770 800×791, it was at 1599,770 871×503 [moved-unasked]
- ✘ **88 resume** (presses ⌃⌥⎋): preview (w479) is not back where it was after step 86: 1599,770 708×424, it was at 1599,770 1576×767 [moved-unasked]
- ✘ **88 resume** (presses ⌃⌥⎋): mail (w481) is not back where it was after step 86: 1599,770 872×791, it was at 1599,770 871×252 [moved-unasked]
- ✘ **88 resume** (presses ⌃⌥⎋): w483 of Mail is not back where it was after step 86: 1800,957 470×416, it was at 1800,822 470×416 [moved-unasked]

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **21 dock-left** (presses ⌃⌥⌘ and the left arrow): the last window came to rest 1061 ms after the key or the button [slow]
- ~ **25 rotate** (presses ⌃⌥R): the last window came to rest 1350 ms after the key or the button [slow]
- ~ **35 dock-left** (presses ⌃⌥⌘ and the left arrow): the last window came to rest 1069 ms after the key or the button [slow]
- ~ **52 dock-up** (presses ⌃⌥⌘ and the up arrow): the last window came to rest 888 ms after the key or the button [slow]
- ~ **58 quit** (chooses Quit Arbor in Arbor's menu): w483 of Mail went 110 points out of its way before it ended up [jolt]
  - +0 ms 565,614 470×416 · +2418 ms 565,124 470×416 · +2542 ms 565,179 470×416
- ✘ **67 drag-mail-to-right-edge** (drags mail by its title bar against the right edge of the screen and lets go): w483 of Mail moved 3 times [jolt]
  - +0 ms 565,179 470×416 · +867 ms 591,191 470×416 · +928 ms 618,203 470×416 · +965 ms 644,215 470×416 · +1056 ms 671,227 470×416 · +1160 ms 698,240 470×416 · … 23 more … · +4318 ms 1297,394 470×416 · +4401 ms 1074,288 470×416 · +4489 ms 953,230 470×416 · +4600 ms 933,221 470×416 · +4610 ms 930,219 470×416
- ~ **70 arrange** (presses ⌃⌥A): the last window came to rest 1494 ms after the key or the button [slow]
- ~ **74 view-right** (presses ⌃⌥→): the last window came to rest 943 ms after the key or the button [slow]
- ~ **75 view-right** (presses ⌃⌥→): the last window came to rest 757 ms after the key or the button [slow]
- ~ **76 view-out** (presses ⌃⌥↑): the last window came to rest 754 ms after the key or the button [slow]
- ✘ **77 drag-gap-beside-textedit** (drags the gap to the right of textedit by 80 points): textedit (w466) moved 2 times [jolt]
  - +0 ms 12,562 295×248 · +744 ms 12,562 297×248 · +807 ms 12,562 303×248 · +958 ms 12,562 311×248 · +1095 ms 12,562 319×248 · +1167 ms 12,562 321×248 · … 4 more … · +1508 ms 12,562 340×248 · +1582 ms 12,562 343×248 · +1624 ms 12,562 348×248 · +1664 ms 12,562 351×248 · +2819 ms 12,562 375×248
- ~ **90 view-right** (presses ⌃⌥→): the last window came to rest 759 ms after the key or the button [slow]
- ~ **96 view-frame** (presses ⌃⌥↩): the last window came to rest 944 ms after the key or the button [slow]
- ~ **99 quit** (chooses Quit Arbor in Arbor's menu): w483 of Mail went 270 points out of its way before it ended up [jolt]
  - +0 ms 2152,822 470×416 · +2529 ms 1800,957 470×416 · +2573 ms 930,219 470×416

### Rule 4: the window you switch to comes to the front and into view

- ✘ **27 drag-preview-by** (drags preview, which floats, by its title bar -121 across and -22 down): preview (w479) is not wholly in view: 88% of it, at -84,432 708×389 in 0,31 1600×791 [focus]
- ✘ **45 dock-icon-preview** (clicks preview's icon in the Dock): preview (w479) is not wholly in view: 88% of it, at -84,398 708×423 in 0,31 1600×791 [focus]
- ✘ **61 dock-icon-preview** (clicks preview's icon in the Dock): preview (w479) is not wholly in view: 88% of it, at -84,398 708×423 in 0,31 1600×791 [focus]
- ✘ **67 drag-mail-to-right-edge** (drags mail by its title bar against the right edge of the screen and lets go): mail (w481) is not in front: w483 of Mail ahead of it, of which 1 cover part of it [behind]
- ✘ **89 view-frame** (presses ⌃⌥↩): settings (w477) is not in front: finder-new-82 (w644), terminal (w469) ahead of it, of which 1 cover part of it [behind]
- ✘ **89 view-frame** (presses ⌃⌥↩): settings (w477) its app is not the one in front (process 43355 is) [focus]
- ✘ **89 view-frame** (presses ⌃⌥↩): settings (w477) is not wholly in view: 0% of it, at 1599,770 723×767 in 0,31 1600×791 [focus]
- ✘ **107 dock-icon-preview** (clicks preview's icon in the Dock): preview (w479) is not wholly in view: 88% of it, at -84,398 708×424 in 0,31 1600×791 [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **58 quit** (chooses Quit Arbor in Arbor's menu): notes (w472) is 0,31 800×790; its own size was 806,433 794×389 [size-lost]
- ✘ **58 quit** (chooses Quit Arbor in Arbor's menu): preview (w479) is -84,398 708×423; its own size was -84,432 708×389 [size-lost]
- ✘ **87 pause** (presses ⌃⌥⎋): notes (w472) is 0,31 800×791; its own size was 806,433 794×389 [size-lost]
- ✘ **87 pause** (presses ⌃⌥⎋): preview (w479) is -84,398 708×424; its own size was -84,432 708×389 [size-lost]
- ✘ **87 pause** (presses ⌃⌥⎋): w483 of Mail has its size back but not its place: 930,219 470×416, it was at 565,179 470×416 [size-lost]
- ✘ **99 quit** (chooses Quit Arbor in Arbor's menu): notes (w472) is 0,31 800×791; its own size was 806,433 794×389 [size-lost]
- ✘ **99 quit** (chooses Quit Arbor in Arbor's menu): preview (w479) is -84,398 708×424; its own size was -84,432 708×389 [size-lost]
- ✘ **99 quit** (chooses Quit Arbor in Arbor's menu): w483 of Mail has its size back but not its place: 930,219 470×416, it was at 565,179 470×416 [size-lost]

### Rule -: what the script itself checked

- ✘ **27 drag-preview-by** (drags preview, which floats, by its title bar -121 across and -22 down): w479 is in view for Arbor but only 88% of it is on a display: -84,432 708×389 [script]
- ✘ **32 leave-alone** (does nothing for half a minute): with nothing to do Arbor used 1.5 % of a core [busy]
- ✘ **33 leave-alone** (does nothing for half a minute): with nothing to do Arbor used 1.3 % of a core [busy]
- ✘ **38 drag-notes-by** (drags notes, which floats, by its title bar 67 across and 34 down): the act was not performed: drag_window could not be done [script]
- ✘ **39 view-frame** (presses ⌃⌥↩): w479 is in view for Arbor but only 88% of it is on a display: -84,398 708×423 [script]
- ✘ **42 undo** (presses ⌃⌥Z): w479 is in view for Arbor but only 88% of it is on a display: -84,433 708×389 [script]
- ✘ **44 view-in** (presses ⌃⌥↓): w479 is in view for Arbor but only 88% of it is on a display: -84,398 708×423 [script]
- ✘ **48 view-all** (presses ⌃⌥Space): w479 is in view for Arbor but only 88% of it is on a display: -84,433 708×389 [script]
- ✘ **52 dock-up** (presses ⌃⌥⌘ and the up arrow): w479 is in view for Arbor but only 88% of it is on a display: -84,562 708×260 [script]
- ✘ **62 launch** (starts Arbor): w479 is in view for Arbor but only 88% of it is on a display: -84,398 708×423 [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (4, 128 ms) | quiet 962 ms; blind for 107 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 428 ms; blind for 1362 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (4, 255 ms) | quiet 1347 ms; blind for 356 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (3, 296 ms) | quiet 1256 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (4, 281 ms) | quiet 1230 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar |  | quiet 973 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (2, 50 ms) | quiet 398 ms; blind for 566 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (3, 90 ms) | quiet 1012 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w483 ×1 (5, 134 ms) | quiet 724 ms; blind for 1269 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (36, 4038 ms) | quiet 1383 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (33, 2406 ms) | quiet 1056 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 410 ms |  |  |  |  |  |  |  |  |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 13 | launch | starts Arbor |  | quiet 1085 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 14 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 382 ms; blind for 100 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 15 | pin | chooses Keep This Window in View in Arbor's menu, or takes the tick off |  | quiet 371 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 16 | click-notes | clicks notes's title bar |  | quiet 435 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | mirror | presses ⌃⌥⇧R |  | quiet 785 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 18 | view-all | presses ⌃⌥Space |  | quiet 780 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 19 | view-right | presses ⌃⌥→ |  | quiet 749 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 20 | click-safari | clicks safari's title bar |  | quiet 374 ms; blind for 105 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w483 ×1 (1, 0 ms) | quiet 1039 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 22 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 415 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | drag-textedit-to-left-edge | drags textedit by its title bar against the left edge of the screen and lets go | textedit ×1 (7, 292 ms) | quiet 399 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 550 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | rotate | presses ⌃⌥R | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w483 ×1 (1, 0 ms) | quiet 1485 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 26 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 593 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | drag-preview-by | drags preview, which floats, by its title bar -121 across and -22 down |  | quiet 1112 ms | ✔ | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✘ |
| 28 | view-forward | presses ⌃⌥] |  | quiet 578 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 29 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 470 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | new-window-safari | presses ⌘N in safari |  | quiet 1170 ms; blind for 198 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 31 | close-window | presses ⌘W |  | quiet 1006 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 32 | leave-alone | does nothing for half a minute |  | quiet 395 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 33 | leave-alone | does nothing for half a minute |  | quiet 412 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 34 | click-terminal | clicks terminal's title bar |  | quiet 364 ms; blind for 128 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w483 ×1 (1, 0 ms) | quiet 1175 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 36 | drag-calendar-to-right-edge | drags calendar by its title bar against the right edge of the screen and lets go | calendar ×1 (7, 263 ms) | quiet 358 ms; blind for 101 ms | ✘ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 463 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | drag-notes-by | drags notes, which floats, by its title bar 67 across and 34 down |  | quiet 1058 ms |  |  |  |  |  |  |  | ✘ |
| 39 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w483 ×1 (1, 0 ms) | quiet 1045 ms |  |  | ✔ | ✔ |  |  | ✔ | ✘ |
| 40 | view-in | presses ⌃⌥↓ |  | quiet 889 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 41 | dock-icon-safari | clicks safari's icon in the Dock | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w483 ×1 (1, 0 ms) | quiet 601 ms; blind for 137 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | undo | presses ⌃⌥Z | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w483 ×1 (1, 0 ms) | quiet 970 ms |  |  | ✔ | ✔ |  |  | ✔ | ✘ |
| 43 | view-all | presses ⌃⌥Space |  | quiet 752 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 44 | view-in | presses ⌃⌥↓ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w483 ×1 (1, 0 ms) | quiet 958 ms |  |  | ✔ |  |  |  | ✔ | ✘ |
| 45 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 549 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 46 | rotate | presses ⌃⌥R |  | quiet 711 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 47 | view-right | presses ⌃⌥→ |  | quiet 737 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 48 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w483 ×1 (1, 0 ms) | quiet 950 ms |  |  | ✔ |  |  |  | ✔ | ✘ |
| 49 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 419 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | view-all | presses ⌃⌥Space |  | quiet 656 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 51 | click-textedit | clicks textedit's title bar |  | quiet 374 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | dock-up | presses ⌃⌥⌘ and the up arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w483 ×1 (1, 0 ms) | quiet 1016 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✘ |
| 53 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 382 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 54 | drag-terminal-to-right-edge | drags terminal by its title bar against the right edge of the screen and lets go | terminal ×1 (11, 265 ms) | quiet 418 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 512 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 56 | minimize-settings | presses ⌘M | settings ×1 (16, 467 ms) | quiet 1404 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 57 | restore-settings | clicks settings's icon in the Dock, which brings its minimized window back | settings ×1 (20, 523 ms) | quiet 1122 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 58 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 53 ms), notes ×1 (2, 74 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (2, 124 ms), w483 ×1 (2, 124 ms) | quiet 795 ms |  |  | ~ |  | ✘ |  | ✔ | ✔ |
| 59 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 408 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 364 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 406 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 62 | launch | starts Arbor | safari ×1 (2, 52 ms), textedit ×1 (1, 0 ms) | quiet 1003 ms |  | ✔ | ✔ |  |  |  | ✔ | ✘ |
| 63 | hold | holds the view, as for a shared screen |  | quiet 361 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 64 | show-desktop-while-held | presses ⌃⌥D, which would show the Desktop: the view is held |  | quiet 814 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 65 | release | lets the view go again |  | quiet 394 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 66 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 596 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 67 | drag-mail-to-right-edge | drags mail by its title bar against the right edge of the screen and lets go | mail ×1 (5, 292 ms), w483 ×3 (33, 3743 ms) | quiet 350 ms | ✔ | ~ | ✘ | ✘ |  | ✔ | ✔ | ✔ |
| 68 | peek | holds ⌃⌥Space for a second and a half and lets go |  | quiet 371 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 69 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 477 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 70 | arrange | presses ⌃⌥A | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w483 ×1 (1, 0 ms) | quiet 2057 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 71 | dock-icon-preview | clicks preview's icon in the Dock | textedit ×1 (1, 0 ms), calendar ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w483 ×1 (1, 0 ms) | quiet 832 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 72 | dock-down | presses ⌃⌥⌘ and the down arrow |  | quiet 724 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 73 | balance | presses ⌃⌥⌘0 |  | quiet 611 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 74 | view-right | presses ⌃⌥→ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 1168 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 75 | view-right | presses ⌃⌥→ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), calendar ×1 (1, 0 ms), mail ×1 (1, 0 ms), w483 ×1 (1, 0 ms) | quiet 1363 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 76 | view-out | presses ⌃⌥↑ | textedit ×1 (1, 0 ms), calendar ×1 (1, 0 ms), mail ×1 (1, 0 ms), w483 ×1 (1, 0 ms) | quiet 873 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 77 | drag-gap-beside-textedit | drags the gap to the right of textedit by 80 points | textedit ×2 (14, 2075 ms) | quiet 1312 ms; blind for 106 ms |  | ✔ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 78 | leave-alone | does nothing for half a minute |  | quiet 433 ms; blind for 308 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 79 | dock-icon-settings | clicks settings's icon in the Dock | textedit ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w483 ×1 (1, 0 ms) | quiet 860 ms; blind for 211 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 80 | dock-down | presses ⌃⌥⌘ and the down arrow |  | quiet 606 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 81 | dock-icon-finder | clicks finder's icon in the Dock | finder ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 663 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 82 | new-window-finder | presses ⌘N in finder |  | quiet 1103 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 83 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 921 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 84 | dock-icon-settings | clicks settings's icon in the Dock | safari ×1 (1, 0 ms), settings ×1 (1, 0 ms), finder-new-82 ×1 (1, 0 ms) | quiet 719 ms; blind for 121 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 85 | redo | presses ⌃⌥⇧Z |  | quiet 588 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 86 | leave-alone | does nothing for half a minute |  | quiet 371 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 87 | pause | presses ⌃⌥⎋ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 11 ms), notes ×1 (2, 106 ms), calendar ×1 (2, 59 ms), settings ×1 (2, 29 ms), preview ×1 (2, 84 ms), mail ×1 (1, 0 ms), w483 ×1 (1, 0 ms), finder-new-82 ×1 (1, 0 ms) | quiet 1694 ms |  |  | ✔ | ✔ | ✘ |  | ✔ | ✔ |
| 88 | resume | presses ⌃⌥⎋ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w483 ×1 (1, 0 ms), finder-new-82 ×1 (1, 0 ms) | quiet 895 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 89 | view-frame | presses ⌃⌥↩ | safari ×1 (1, 0 ms), settings ×1 (1, 0 ms), finder-new-82 ×1 (1, 0 ms) | quiet 1216 ms; blind for 217 ms |  |  | ✔ | ✘ |  |  | ✔ | ✔ |
| 90 | view-right | presses ⌃⌥→ | safari ×1 (1, 0 ms), calendar ×1 (1, 0 ms), mail ×1 (1, 0 ms), w483 ×1 (1, 0 ms), finder-new-82 ×1 (1, 0 ms) | quiet 1413 ms; blind for 134 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 91 | dock-icon-safari | clicks safari's icon in the Dock | safari ×1 (1, 0 ms), calendar ×1 (1, 0 ms), mail ×1 (1, 0 ms), w483 ×1 (1, 0 ms) | quiet 466 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 92 | quit-safari | presses ⌘Q in safari | calendar ×1 (1, 0 ms) | quiet 942 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 93 | dock-icon-textedit | clicks textedit's icon in the Dock | textedit ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 479 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 94 | window-menu-textedit | chooses textedit's first window in the Window menu |  | quiet 1273 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 95 | reopen-safari | opens safari's document again |  | quiet 363 ms; blind for 1436 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 96 | view-frame | presses ⌃⌥↩ | textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 1005 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 97 | view-back | presses ⌃⌥[ | textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 676 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 98 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 431 ms; blind for 119 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 99 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), textedit ×1 (2, 48 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (2, 25 ms), mail ×1 (2, 44 ms), w483 ×1 (2, 44 ms), finder-new-82 ×1 (1, 0 ms) | quiet 720 ms |  |  | ~ |  | ✘ |  | ✔ | ✔ |
| 100 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 353 ms; blind for 101 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 101 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 363 ms; blind for 105 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 102 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 373 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 103 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 439 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 104 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 476 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 105 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 429 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 106 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 420 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 107 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 406 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 108 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 598 ms; blind for 106 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
