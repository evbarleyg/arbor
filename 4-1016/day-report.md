129 steps in 515 s, 115 of them judged, 19 with a rule broken. The sampler: samples 18554 seconds 473.0 hz 39.2 cost-ms 1.94 late 6 longest-gap-ms 681 whole-samples 20251 whole-seconds 516.2 whole-late 20.
Input: 334 presses, releases, keys and scrolls reached the apps, half of them within 507 µs, 99 in 100 within 46349 µs, the latest after 66481 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 34, 659, 3914; dragged 197, 512, 4481; forward 8, 46349, 66481; key 53, 244, 767; up 42, 617, 41300. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 32099; up 8, 853.
The round of input `started` (events, half within µs): forward 8, 32983; up 8, 659.
The round of input `last` (events, half within µs): down 13, 1418; dragged 20, 455; forward 8, 43453; key 13, 417; scroll 28, 200; up 21, 418.
The round of input `after` (events, half within µs): down 14, 1502; dragged 20, 389; key 13, 324; scroll 28, 296; up 14, 444.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 5 | 2 | 56 drag-textedit-to-right-edge, 60 drag-safari-to-right-edge |
| 2 | nothing moves that the person did not move | 92 | 9 | 32 dock-right, 34 dock-down, 40 dock-up, 44 dock-up, 56 drag-textedit-to-right-edge, 77 pin, 80 mirror, 88 restore-textedit, 90 dock-down |
| 3 | no jolts: a window moves once, to where it ends up | 117 | 3 | 25 drag-notes-to-left-edge, 49 drag-bottom-edge-of-textedit, 56 drag-textedit-to-right-edge |
| 4 | the window you switch to comes to the front and into view | 83 | 2 | 49 drag-bottom-edge-of-textedit, 79 dock-icon-mail |
| 5 | quitting, Float All and pause give windows their own sizes back | 6 | 2 | 101 float-all, 119 quit |
| 6 | what a person presses reaches the apps, at once | 58 | 0 |  |
| L | no window is lost or stuck | 117 | 1 | 71 launch |
| - | what the script itself checked | 117 | 3 | 28 leave-alone, 47 leave-alone, 48 leave-alone |

## Findings

### Rule 1: never fight macOS: where it answers a drag, Arbor stands aside

- ✘ **56 drag-textedit-to-right-edge** (drags textedit by its title bar against the right edge of the screen and lets go): textedit (w697) macOS's tiling preview and Arbor's drop preview were up at the same time [fought]
- ✘ **60 drag-safari-to-right-edge** (drags safari by its title bar against the right edge of the screen and lets go): safari (w688) macOS's tiling preview and Arbor's drop preview were up at the same time [fought]

### Rule 2: nothing moves that the person did not move

- ✘ **32 dock-right** (presses ⌃⌥⌘ and the right arrow): finder (w685) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,120 920×436 · +1349 ms 0,120 794×436
- ✘ **32 dock-right** (presses ⌃⌥⌘ and the right arrow): safari (w688) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 167,31 1324×790 · +1349 ms 0,31 794×790
- ✘ **32 dock-right** (presses ⌃⌥⌘ and the right arrow): terminal (w702) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 97,238 877×499 · +1349 ms 0,238 793×499
- ✘ **32 dock-right** (presses ⌃⌥⌘ and the right arrow): notes (w703) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 800×791 · +1349 ms 0,31 794×791
- ✘ **32 dock-right** (presses ⌃⌥⌘ and the right arrow): calendar (w709) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 414,115 911×604 · +1349 ms 0,115 794×604
- ✘ **32 dock-right** (presses ⌃⌥⌘ and the right arrow): settings (w710) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +1349 ms 71,85 723×625
- ✘ **32 dock-right** (presses ⌃⌥⌘ and the right arrow): preview (w714) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 800,31 800×791 · +1349 ms 0,31 794×791
- ✘ **32 dock-right** (presses ⌃⌥⌘ and the right arrow): mail (w715) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1349 ms 0,72 871×630
- ~ **32 dock-right** (presses ⌃⌥⌘ and the right arrow): w718 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1349 ms 201,179 470×416
- ✘ **34 dock-down** (presses ⌃⌥⌘ and the down arrow): finder (w685) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,120 794×436 · +1139 ms 340,31 920×390
- ✘ **34 dock-down** (presses ⌃⌥⌘ and the down arrow): safari (w688) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 794×790 · +1139 ms 167,31 1324×390
- ✘ **34 dock-down** (presses ⌃⌥⌘ and the down arrow): terminal (w702) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,238 793×499 · +1139 ms 97,31 877×379
- ✘ **34 dock-down** (presses ⌃⌥⌘ and the down arrow): notes (w703) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 794×791 · +1139 ms 0,31 800×390
- ✘ **34 dock-down** (presses ⌃⌥⌘ and the down arrow): calendar (w709) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,115 794×604 · +1139 ms 414,31 911×503
- ✘ **34 dock-down** (presses ⌃⌥⌘ and the down arrow): settings (w710) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 71,85 723×625 · +1139 ms 437,31 723×470
- ✘ **34 dock-down** (presses ⌃⌥⌘ and the down arrow): preview (w714) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 794×791 · +1139 ms 800,31 800×390
- ✘ **34 dock-down** (presses ⌃⌥⌘ and the down arrow): mail (w715) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,72 871×630 · +1139 ms 240,31 1120×390
- ~ **34 dock-down** (presses ⌃⌥⌘ and the down arrow): w718 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 201,179 470×416 · +1139 ms 565,83 470×416
- ✘ **40 dock-up** (presses ⌃⌥⌘ and the up arrow): finder (w685) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,120 794×436 · +1099 ms 0,558 794×264
- ✘ **40 dock-up** (presses ⌃⌥⌘ and the up arrow): safari (w688) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 794×790 · +1099 ms 0,558 794×264
- ✘ **40 dock-up** (presses ⌃⌥⌘ and the up arrow): terminal (w702) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,238 793×499 · +1099 ms 0,558 793×259
- ✘ **40 dock-up** (presses ⌃⌥⌘ and the up arrow): notes (w703) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 794×790 · +1099 ms 0,502 794×320
- ✘ **40 dock-up** (presses ⌃⌥⌘ and the up arrow): settings (w710) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 71,85 723×625 · +1099 ms 71,352 723×470
- ✘ **40 dock-up** (presses ⌃⌥⌘ and the up arrow): preview (w714) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 794×790 · +1099 ms 0,558 794×264
- ✘ **40 dock-up** (presses ⌃⌥⌘ and the up arrow): mail (w715) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,72 871×630 · +1099 ms 0,558 871×264
- ~ **40 dock-up** (presses ⌃⌥⌘ and the up arrow): w718 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 201,179 470×416 · +1099 ms 201,610 470×416
- ✘ **44 dock-up** (presses ⌃⌥⌘ and the up arrow): finder (w685) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,558 794×264 · +1086 ms 0,570 794×252
- ✘ **44 dock-up** (presses ⌃⌥⌘ and the up arrow): safari (w688) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,558 794×264 · +1086 ms 0,598 794×224
- ✘ **44 dock-up** (presses ⌃⌥⌘ and the up arrow): terminal (w702) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,558 793×259 · +1086 ms 0,598 793×214
- ✘ **44 dock-up** (presses ⌃⌥⌘ and the up arrow): preview (w714) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,558 794×264 · +1086 ms 0,598 794×224
- ✘ **44 dock-up** (presses ⌃⌥⌘ and the up arrow): mail (w715) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,558 871×264 · +1086 ms 0,586 871×236
- ~ **44 dock-up** (presses ⌃⌥⌘ and the up arrow): w718 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 201,610 470×416 · +1086 ms 201,638 470×416
- ✘ **56 drag-textedit-to-right-edge** (drags textedit by its title bar against the right edge of the screen and lets go): finder (w685) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,570 794×252 · +5211 ms 340,570 920×252
- ✘ **56 drag-textedit-to-right-edge** (drags textedit by its title bar against the right edge of the screen and lets go): safari (w688) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,598 794×224 · +5211 ms 167,598 1324×224
- ✘ **56 drag-textedit-to-right-edge** (drags textedit by its title bar against the right edge of the screen and lets go): terminal (w702) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,598 793×214 · +5211 ms 97,598 877×214
- ✘ **56 drag-textedit-to-right-edge** (drags textedit by its title bar against the right edge of the screen and lets go): settings (w710) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 71,352 723×470 · +5211 ms 437,352 723×470
- ✘ **56 drag-textedit-to-right-edge** (drags textedit by its title bar against the right edge of the screen and lets go): preview (w714) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,598 794×224 · +5211 ms 800,598 800×224
- ✘ **56 drag-textedit-to-right-edge** (drags textedit by its title bar against the right edge of the screen and lets go): mail (w715) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,586 871×236 · +5211 ms 240,586 1120×236
- ~ **56 drag-textedit-to-right-edge** (drags textedit by its title bar against the right edge of the screen and lets go): w718 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 201,638 470×416 · +5211 ms 565,638 470×416
- ✘ **77 pin** (chooses Keep This Window in View in Arbor's menu, or takes the tick off): finder (w685) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 920×436 · +884 ms 340,558 920×264
- ✘ **77 pin** (chooses Keep This Window in View in Arbor's menu, or takes the tick off): safari (w688) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 801×791 · +884 ms 799,558 801×264
- ✘ **77 pin** (chooses Keep This Window in View in Arbor's menu, or takes the tick off): textedit (w697) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,790 800×791 · +884 ms 800,558 800×264
- ✘ **77 pin** (chooses Keep This Window in View in Arbor's menu, or takes the tick off): terminal (w702) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,790 877×499 · +884 ms 97,558 877×259
- ✘ **77 pin** (chooses Keep This Window in View in Arbor's menu, or takes the tick off): settings (w710) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 723×625 · +884 ms 437,352 723×470
- ✘ **77 pin** (chooses Keep This Window in View in Arbor's menu, or takes the tick off): preview (w714) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 800×790 · +884 ms 800,558 800×264
- ✘ **77 pin** (chooses Keep This Window in View in Arbor's menu, or takes the tick off): mail (w715) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 1120×630 · +884 ms 240,558 1120×264
- ~ **77 pin** (chooses Keep This Window in View in Arbor's menu, or takes the tick off): w718 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 1924,877 470×416 · +884 ms 565,610 470×416
- ✘ **80 mirror** (presses ⌃⌥⇧R): finder (w685) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,558 920×264 · +861 ms 340,31 920×264
- ✘ **80 mirror** (presses ⌃⌥⇧R): safari (w688) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 799,558 801×264 · +861 ms 799,31 801×264
- ✘ **80 mirror** (presses ⌃⌥⇧R): textedit (w697) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 800,558 800×264 · +861 ms 800,31 800×264
- ✘ **80 mirror** (presses ⌃⌥⇧R): terminal (w702) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 97,558 877×259 · +861 ms 97,31 877×259
- ✘ **80 mirror** (presses ⌃⌥⇧R): settings (w710) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,352 723×470 · +861 ms 437,31 723×470
- ✘ **80 mirror** (presses ⌃⌥⇧R): preview (w714) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 800,558 800×264 · +861 ms 800,31 800×264
- ✘ **80 mirror** (presses ⌃⌥⇧R): mail (w715) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,558 1120×264 · +861 ms 240,31 1120×264
- ~ **80 mirror** (presses ⌃⌥⇧R): w718 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,610 470×416 · +861 ms 565,83 470×416
- ✘ **88 restore-textedit** (clicks its miniature in the Dock): safari-new-87 (w898) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,60 801×264 · +2041 ms 0,31 801×264
- ✘ **90 dock-down** (presses ⌃⌥⌘ and the down arrow): finder (w685) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,31 920×264 · +952 ms 340,31 920×260
- ✘ **90 dock-down** (presses ⌃⌥⌘ and the down arrow): safari (w688) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 799,31 801×264 · +952 ms 799,31 801×260
- ✘ **90 dock-down** (presses ⌃⌥⌘ and the down arrow): textedit (w697) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 800,31 800×264 · +952 ms 800,31 800×260
- ✘ **90 dock-down** (presses ⌃⌥⌘ and the down arrow): preview (w714) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 800,31 800×264 · +952 ms 800,31 800×260
- ✘ **90 dock-down** (presses ⌃⌥⌘ and the down arrow): mail (w715) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,31 1120×264 · +952 ms 240,31 1120×260
- ✘ **90 dock-down** (presses ⌃⌥⌘ and the down arrow): safari-new-87 (w898) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 0,31 801×264 · +952 ms 0,31 801×260

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **25 drag-notes-to-left-edge** (drags notes by its title bar against the left edge of the screen and lets go): notes (w703) moved 70 points further than the pointer did, 4770 ms into the step [pulled]
  - +0 ms -4,44 800×791 · +138 ms -11,72 800×791 · +172 ms -15,85 800×791 · +248 ms -18,99 800×791 · +332 ms -22,109 800×791 · +399 ms -26,109 800×791 · … 22 more … · +1960 ms -112,421 800×791 · +2082 ms -115,435 800×791 · +2335 ms -114,435 800×791 · +3855 ms -115,435 800×791 · +3904 ms -95,365 800×791
- ~ **32 dock-right** (presses ⌃⌥⌘ and the right arrow): the last window came to rest 1120 ms after the key or the button [slow]
- ~ **34 dock-down** (presses ⌃⌥⌘ and the down arrow): the last window came to rest 965 ms after the key or the button [slow]
- ~ **40 dock-up** (presses ⌃⌥⌘ and the up arrow): the last window came to rest 813 ms after the key or the button [slow]
- ~ **44 dock-up** (presses ⌃⌥⌘ and the up arrow): the last window came to rest 815 ms after the key or the button [slow]
- ~ **46 view-frame** (presses ⌃⌥↩): the last window came to rest 1079 ms after the key or the button [slow]
- ✘ **49 drag-bottom-edge-of-textedit** (drags the bottom edge of textedit's window by -60 points): textedit (w697) moved 2 times [jolt]
  - +0 ms 806,598 782×212 · +930 ms 806,598 782×204 · +1029 ms 806,598 782×202 · +1157 ms 806,598 782×200 · +1225 ms 806,598 782×198 · +1288 ms 806,598 782×196 · … 16 more … · +2467 ms 806,598 782×160 · +2522 ms 806,598 782×158 · +2591 ms 806,598 782×156 · +2647 ms 806,598 782×152 · +3379 ms 806,598 782×212
- ~ **53 resume** (presses ⌃⌥⎋): w718 of Mail went 110 points out of its way before it ended up [jolt]
  - +0 ms 565,179 470×416 · +412 ms 441,124 470×416 · +417 ms 201,638 470×416
- ✘ **56 drag-textedit-to-right-edge** (drags textedit by its title bar against the right edge of the screen and lets go): textedit (w697) moved 77 points further than the pointer did, 2456 ms into the step [pulled]
  - +0 ms 818,592 782×212 · +81 ms 818,587 782×212 · +385 ms 867,587 782×212 · +457 ms 896,587 782×212 · +579 ms 912,587 782×212 · +588 ms 926,587 782×212 · … 17 more … · +1456 ms 1180,587 782×212 · +1517 ms 1193,581 782×212 · +1579 ms 1207,488 782×212 · +1797 ms 1208,438 782×212 · +1847 ms 1207,438 782×212
- ~ **67 quit** (chooses Quit Arbor in Arbor's menu): w718 of Mail went 110 points out of its way before it ended up [jolt]
  - +0 ms 565,638 470×416 · +2396 ms 565,124 470×416 · +2474 ms 565,179 470×416
- ~ **75 view-desktop** (presses ⌃⌥D): the last window came to rest 807 ms after the key or the button [slow]
- ~ **80 mirror** (presses ⌃⌥⇧R): the last window came to rest 721 ms after the key or the button [slow]

### Rule 4: the window you switch to comes to the front and into view

- ✘ **49 drag-bottom-edge-of-textedit** (drags the bottom edge of textedit's window by -60 points): the app in front changed (to process 71766), and nobody switched [focus]
- ✘ **79 dock-icon-mail** (clicks mail's icon in the Dock): w718 of Mail is not in front: terminal (w702), notes (w703), settings (w710), finder (w685) ahead of it, of which 6 cover part of it [behind]
- ✘ **79 dock-icon-mail** (clicks mail's icon in the Dock): w718 of Mail its app is not the one in front (process 72146 is) [focus]
- ✘ **79 dock-icon-mail** (clicks mail's icon in the Dock): w718 of Mail is not wholly in view: 51% of it, at 565,610 470×416 in 0,31 1600×791 [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **101 float-all** (presses ⌃⌥⇧F): notes (w703) has its size back but not its place: 400,31 800×790, it was at 0,31 800×791 [size-lost]
- ✘ **119 quit** (chooses Quit Arbor in Arbor's menu): notes (w703) has its size back but not its place: 400,31 800×790, it was at 0,31 800×791 [size-lost]

### Rule L: no window is lost or stuck

- ✘ **71 launch** (starts Arbor): calendar (w709) is out of view: 0% of it is on a display, at 1599,770 1576×503 [lost]

### Rule -: what the script itself checked

- ✘ **28 leave-alone** (does nothing for half a minute): with nothing to do Arbor used 1.3 % of a core [busy]
- ✘ **47 leave-alone** (does nothing for half a minute): with nothing to do Arbor used 1.3 % of a core [busy]
- ✘ **48 leave-alone** (does nothing for half a minute): with nothing to do Arbor used 1.3 % of a core [busy]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (3, 103 ms) | quiet 987 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 565 ms; blind for 800 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (4, 295 ms) | quiet 1371 ms; blind for 165 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (4, 341 ms) | quiet 1377 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (6, 376 ms) | quiet 1261 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (5, 361 ms) | quiet 1355 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (2, 105 ms) | quiet 910 ms; blind for 230 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (3, 94 ms) | quiet 1078 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w718 ×1 (5, 173 ms) | quiet 814 ms; blind for 1127 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (35, 3784 ms) | quiet 1457 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (34, 2073 ms) | quiet 1047 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 370 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 743 ms; blind for 101 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | launch | starts Arbor |  | quiet 1133 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 15 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 764 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 16 | drag-preview-to-right-edge | drags preview by its title bar against the right edge of the screen and lets go | preview ×1 (12, 279 ms) | quiet 362 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 443 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 18 | undo | presses ⌃⌥Z |  | quiet 812 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 19 | view-all | presses ⌃⌥Space |  | quiet 668 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 20 | view-frame | presses ⌃⌥↩ |  | quiet 719 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 21 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 369 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 22 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 426 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 23 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 439 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 24 | click-safari | clicks safari's title bar |  | quiet 421 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | drag-notes-to-left-edge | drags notes by its title bar against the left edge of the screen and lets go | notes ×1 (11, 348 ms) | quiet 366 ms | ✔ | ✔ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | view-all | presses ⌃⌥Space |  | quiet 696 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 27 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 371 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | leave-alone | does nothing for half a minute |  | quiet 426 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 29 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 404 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | rotate | presses ⌃⌥R |  | quiet 679 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 31 | click-textedit | clicks textedit's title bar |  | quiet 474 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w718 ×1 (1, 0 ms) | quiet 1032 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 33 | click-textedit | clicks textedit's title bar |  | quiet 451 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | dock-down | presses ⌃⌥⌘ and the down arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w718 ×1 (1, 0 ms) | quiet 1002 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 35 | pause | presses ⌃⌥⎋ | finder ×1 (2, 45 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (2, 7 ms), w718 ×1 (2, 7 ms) | quiet 898 ms |  |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 36 | resume | presses ⌃⌥⎋ | finder ×1 (2, 56 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (2, 16 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (2, 45 ms), w718 ×1 (2, 45 ms) | quiet 993 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 37 | click-safari | clicks safari's title bar |  | quiet 389 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | undo | presses ⌃⌥Z | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w718 ×1 (1, 0 ms) | quiet 984 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 39 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 353 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | dock-up | presses ⌃⌥⌘ and the up arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w718 ×1 (1, 0 ms) | quiet 1024 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 41 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 392 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 474 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | click-notes | clicks notes's title bar |  | quiet 394 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | dock-up | presses ⌃⌥⌘ and the up arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w718 ×1 (1, 0 ms) | quiet 1124 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 45 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w718 ×1 (1, 0 ms) | quiet 976 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 46 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w718 ×1 (1, 0 ms) | quiet 955 ms; blind for 681 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 47 | leave-alone | does nothing for half a minute |  | quiet 397 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 48 | leave-alone | does nothing for half a minute |  | quiet 367 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 49 | drag-bottom-edge-of-textedit | drags the bottom edge of textedit's window by -60 points | textedit ×2 (26, 2449 ms) | quiet 1118 ms |  | ✔ | ✘ | ✘ |  | ✔ | ✔ | ✔ |
| 50 | pause | presses ⌃⌥⎋ | finder ×1 (2, 22 ms), safari ×1 (3, 49 ms), textedit ×1 (2, 17 ms), terminal ×1 (2, 22 ms), notes ×1 (2, 34 ms), calendar ×1 (2, 10 ms), settings ×1 (1, 0 ms), preview ×1 (2, 24 ms), mail ×1 (2, 54 ms), w718 ×1 (2, 54 ms) | quiet 1231 ms |  |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 51 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 551 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | new-window-textedit | presses ⌘N in textedit |  | quiet 1309 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 53 | resume | presses ⌃⌥⎋ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (2, 75 ms), mail ×1 (2, 5 ms), w718 ×1 (2, 5 ms) | quiet 1067 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 54 | close-window | presses ⌘W |  | quiet 1145 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 55 | view-all | presses ⌃⌥Space |  | quiet 709 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 56 | drag-textedit-to-right-edge | drags textedit by its title bar against the right edge of the screen and lets go | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w718 ×1 (1, 0 ms) | quiet 370 ms | ✘ | ✘ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | click-wallpaper | clicks on the wallpaper | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w718 ×1 (1, 0 ms) | quiet 394 ms |  |  | ✔ |  |  | ✔ | ✔ | ✔ |
| 58 | click-wallpaper-again | clicks on the wallpaper again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w718 ×1 (1, 0 ms) | quiet 398 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 59 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 382 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | drag-safari-to-right-edge | drags safari by its title bar against the right edge of the screen and lets go | safari ×1 (8, 311 ms) | quiet 404 ms; blind for 138 ms | ✘ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 412 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 62 | hide-finder | presses ⌘H |  | quiet 966 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 63 | unhide-finder | clicks its icon in the Dock |  | quiet 506 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 64 | hold | holds the view, as for a shared screen |  | quiet 360 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 65 | show-desktop-while-held | presses ⌃⌥D, which would show the Desktop: the view is held |  | quiet 755 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 66 | release | lets the view go again |  | quiet 363 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 67 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (2, 31 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (2, 32 ms), mail ×1 (2, 78 ms), w718 ×1 (2, 78 ms) | quiet 854 ms |  |  | ~ |  | ✔ |  | ✔ | ✔ |
| 68 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 423 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 69 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 466 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 70 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 380 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 71 | launch | starts Arbor | notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 981 ms |  | ✔ | ✔ |  |  |  | ✘ | ✔ |
| 72 | view-all | presses ⌃⌥Space |  | quiet 781 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 73 | pause | presses ⌃⌥⎋ | notes ×1 (2, 28 ms), calendar ×1 (2, 18 ms) | quiet 896 ms |  |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 74 | resume | presses ⌃⌥⎋ | notes ×1 (2, 13 ms), calendar ×1 (1, 0 ms) | quiet 806 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 75 | view-desktop | presses ⌃⌥D | notes ×1 (1, 0 ms) | quiet 1069 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 76 | dock-icon-notes | clicks notes's icon in the Dock | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w718 ×1 (1, 0 ms) | quiet 476 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 77 | pin | chooses Keep This Window in View in Arbor's menu, or takes the tick off | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w718 ×1 (1, 0 ms) | quiet 1059 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 78 | click-notes | clicks notes's title bar |  | quiet 400 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 79 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 547 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 80 | mirror | presses ⌃⌥⇧R | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w718 ×1 (1, 0 ms) | quiet 797 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 81 | view-all | presses ⌃⌥Space |  | quiet 739 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 82 | leave-alone | does nothing for half a minute |  | quiet 385 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 83 | save-view-1 | presses ⌃⌥⇧1 |  | quiet 574 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 84 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 515 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 85 | minimize-textedit | presses ⌘M | textedit ×1 (15, 469 ms) | quiet 1441 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 86 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 424 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 87 | new-window-safari | presses ⌘N in safari |  | quiet 1004 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 88 | restore-textedit | clicks its miniature in the Dock | textedit ×1 (19, 501 ms), safari-new-87 ×1 (1, 0 ms) | quiet 1009 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 89 | click-notes | clicks notes's title bar |  | quiet 483 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 90 | dock-down | presses ⌃⌥⌘ and the down arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), safari-new-87 ×1 (1, 0 ms) | quiet 832 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 91 | click-new-window | clicks the title bar of the window that ⌘N opened |  | quiet 388 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 92 | close-window | presses ⌘W |  | quiet 850 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 93 | view-all | presses ⌃⌥Space |  | quiet 693 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 94 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 480 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 95 | quit-preview | presses ⌘Q in preview |  | quiet 707 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 96 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w718 ×1 (1, 0 ms) | quiet 1036 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 97 | reopen-preview | opens preview's document again |  | quiet 1045 ms; blind for 392 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 98 | view-out | presses ⌃⌥↑ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w718 ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 942 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 99 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 484 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 100 | minimize-safari | presses ⌘M | safari ×1 (17, 471 ms) | quiet 1465 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 101 | float-all | presses ⌃⌥⇧F | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w718 ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 1085 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 102 | click-textedit | clicks textedit's title bar |  | quiet 404 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 103 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 378 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 104 | new-window-terminal | presses ⌘N in terminal |  | quiet 1187 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 105 | restore-safari | clicks its miniature in the Dock | safari ×1 (10, 308 ms) | quiet 762 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 106 | click-new-window | clicks the title bar of the window that ⌘N opened |  | quiet 444 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 107 | close-window | presses ⌘W |  | quiet 1077 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 108 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 370 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 109 | new-window-textedit | presses ⌘N in textedit |  | quiet 1271 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 110 | close-window | presses ⌘W |  | quiet 1050 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 111 | cmd-tab-3 | holds ⌘ and presses Tab 3 time(s) |  | quiet 457 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 112 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 437 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 113 | drag-textedit-to-top-edge | drags textedit by its title bar against the top edge of the screen and lets go | textedit ×1 (10, 314 ms) | quiet 360 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 114 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 357 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 115 | hide-safari | presses ⌘H |  | quiet 823 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 116 | undo | presses ⌃⌥Z | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w718 ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 1028 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 117 | unhide-safari | clicks its icon in the Dock |  | quiet 421 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 118 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 913 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 119 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (2, 34 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (2, 39 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (1, 0 ms), w718 ×1 (1, 0 ms), preview ×1 (2, 42 ms) | quiet 915 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 120 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 1020 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 121 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 376 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 122 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 483 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 123 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 407 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 124 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 360 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 125 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 493 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 126 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 468 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 127 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 603 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 128 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 546 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 129 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 549 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
