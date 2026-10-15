103 steps in 490 s, 86 of them judged, 8 with a rule broken. The sampler: samples 14743 seconds 405.0 hz 36.4 cost-ms 4.54 late 61 longest-gap-ms 2433 whole-samples 17891 whole-seconds 491.4 whole-late 186.
Input: 130 presses, releases, keys and scrolls reached the apps, half of them within 600 µs, 99 in 100 within 31967 µs, the latest after 79832 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 24, 959, 12076; dragged 32, 502, 2787; forward 1, 79832, 79832; key 48, 528, 2336; up 25, 969, 31967. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): down 13, 925; dragged 20, 400; forward 12, 21583; key 13, 458; scroll 28, 341; up 25, 808.
The round of input `started` (events, half within µs): down 13, 1000; dragged 20, 570; forward 12, 19731; key 13, 460; scroll 28, 358; up 25, 482.
The round of input `last` (events, half within µs): down 13, 1427; dragged 20, 453; forward 12, 3708; key 13, 294; scroll 28, 244; up 25, 838.
The round of input `after` (events, half within µs): down 24, 451; dragged 20, 387; forward 1, 747; key 13, 327; scroll 28, 260; up 25, 551.
Judged: down, up, key, dragged, scroll. Not forward: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 62 | 3 | 55 launch, 57 hide-notes, 58 unhide-notes |
| 3 | no jolts: a window moves once, to where it ends up | 90 | 5 | 19 arrange, 55 launch, 60 peek, 83 drag-right-edge-of-terminal, 94 input-after |
| 4 | the window you switch to comes to the front and into view | 56 | 1 | 94 input-after |
| 5 | quitting, Float All and pause give windows their own sizes back | 4 | 1 | 93 quit |
| 6 | what a person presses reaches the apps, at once | 40 | 0 |  |
| L | no window is lost or stuck | 90 | 1 | 55 launch |
| - | what the script itself checked | 90 | 0 |  |

## Findings

### Rule 2: nothing moves that the person did not move

- ~ **38 hide-safari** (presses ⌘H): w73 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 1924,877 470×416 · +395 ms 565,485 470×416
- ~ **39 unhide-safari** (clicks its icon in the Dock): w73 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,485 470×416 · +1007 ms 2152,822 470×416
- ~ **55 launch** (starts Arbor): w73 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +728 ms 476,485 470×416 · +921 ms 1805,822 470×416 · +1938 ms 565,218 470×416
- ✘ **55 launch** (starts Arbor): safari (w223) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 12,43 1576×767 · +1938 ms 1599,770 1576×767
- ✘ **57 hide-notes** (presses ⌘H): safari (w223) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 1576×767 · +391 ms 12,43 1576×767
- ✘ **58 unhide-notes** (clicks its icon in the Dock): safari (w223) is not back where it was after step 56: 12,43 1576×767, it was at 1599,770 1576×767 [moved-unasked]
- ~ **78 minimize-terminal** (presses ⌘M): w73 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 2152,945 470×416 · +1711 ms 2152,947 470×416
- ~ **79 restore-terminal** (clicks its miniature in the Dock): w73 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 2152,947 470×416 · +1714 ms 2152,945 470×416

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **19 arrange** (presses ⌃⌥A): the last window came to rest 3390 ms after the key or the button, in Arbor's first act since it started [slow]
- ~ **27 arrange** (presses ⌃⌥A): the last window came to rest 1393 ms after the key or the button [slow]
- ~ **30 view-all** (presses ⌃⌥Space): the last window came to rest 770 ms after the key or the button [slow]
- ~ **33 pause** (presses ⌃⌥⎋): the last window came to rest 979 ms after the key or the button [slow]
- ~ **36 view-right** (presses ⌃⌥→): the last window came to rest 725 ms after the key or the button [slow]
- ~ **47 view-out** (presses ⌃⌥↑): the last window came to rest 1188 ms after the key or the button [slow]
- ~ **51 quit** (chooses Quit Arbor in Arbor's menu): w73 of Mail went 110 points out of its way before it ended up [jolt]
  - +0 ms 2152,822 470×416 · +2808 ms 1924,877 470×416 · +2861 ms 565,179 470×416
- ✘ **55 launch** (starts Arbor): finder (w32) moved 2 times [jolt]
  - +0 ms 340,120 920×436 · +395 ms 529,375 709×252 · +783 ms 529,375 501×252 · +824 ms 516,375 501×252 · +973 ms 516,375 709×252 · +983 ms 529,303 709×252 · +1012 ms 1599,770 709×252
- ✘ **55 launch** (starts Arbor): textedit (w46) moved 3 times [jolt]
  - +0 ms 165,65 673×439 · +395 ms 165,65 247×378 · +405 ms 270,43 247×378 · +799 ms 270,43 240×378 · +824 ms 264,43 240×378 · +983 ms 270,43 247×378 · +1938 ms 1599,790 247×378
- ✘ **55 launch** (starts Arbor): terminal (w51) moved 3 times [jolt]
  - +0 ms 40,51 877×499 · +405 ms 12,303 247×244 · +426 ms 12,305 247×244 · +824 ms 12,305 240×244 · +983 ms 12,305 247×244 · +1938 ms 1599,790 247×244
- ✘ **55 launch** (starts Arbor): notes (w54) moved 2 times [jolt]
  - +0 ms 300,105 1000×660 · +505 ms 529,43 709×320 · +852 ms 516,43 709×320 · +1012 ms 529,43 709×320 · +1048 ms 1599,770 709×320
- ✘ **55 launch** (starts Arbor): calendar (w60) moved 2 times [jolt]
  - +0 ms 404,115 936×599 · +545 ms 1250,43 680×503 · +886 ms 1599,770 680×503
- ✘ **55 launch** (starts Arbor): settings (w63) moved 2 times [jolt]
  - +0 ms 437,85 723×625 · +586 ms 1250,433 723×470 · +852 ms 773,340 723×470 · +1012 ms 1599,770 723×470
- ✘ **55 launch** (starts Arbor): mail (w71) moved 2 times [jolt]
  - +0 ms 240,72 1120×630 · +728 ms 270,433 881×377 · +921 ms 1599,770 881×377 · +1938 ms 12,43 1576×767
- ✘ **55 launch** (starts Arbor): w73 of Mail moved 2 times [jolt]
  - +0 ms 565,179 470×416 · +728 ms 476,485 470×416 · +921 ms 1805,822 470×416 · +1938 ms 565,218 470×416
- ✘ **55 launch** (starts Arbor): desk-a (w87) moved 2 times [jolt]
  - +0 ms 40,70 300×190 · +728 ms 40,70 246×248 · +766 ms 12,562 246×248 · +886 ms 12,562 240×248 · +1012 ms 12,562 246×248 · +1938 ms 1599,790 246×248
- ✘ **55 launch** (starts Arbor): desk-b (w89) moved 2 times [jolt]
  - +0 ms 360,70 300×190 · +766 ms 529,639 709×171 · +886 ms 529,639 245×171 · +921 ms 516,639 245×171 · +1012 ms 529,562 709×248 · +1938 ms 1599,790 709×248
- ✘ **60 peek** (holds ⌃⌥Space for a second and a half and lets go): finder (w32) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 1576×378 · +815 ms 529,375 709×252 · +2571 ms 1599,770 709×252
- ✘ **60 peek** (holds ⌃⌥Space for a second and a half and lets go): textedit (w46) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,790 247×378 · +815 ms 270,43 247×378 · +2571 ms 1599,790 247×378
- ✘ **60 peek** (holds ⌃⌥Space for a second and a half and lets go): terminal (w51) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,790 247×244 · +815 ms 12,305 247×244 · +2571 ms 1599,790 247×244
- ✘ **60 peek** (holds ⌃⌥Space for a second and a half and lets go): notes (w54) moved 2 times [jolt]
  - +0 ms 12,43 1576×767 · +815 ms 529,43 709×320 · +2571 ms 12,43 1576×767
- ✘ **60 peek** (holds ⌃⌥Space for a second and a half and lets go): desk-a (w87) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,790 246×248 · +815 ms 12,562 246×248 · +2571 ms 1599,790 246×248
- ✘ **60 peek** (holds ⌃⌥Space for a second and a half and lets go): desk-b (w89) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,790 1576×377 · +815 ms 529,639 709×171 · +2571 ms 1599,790 709×171
- ✘ **60 peek** (holds ⌃⌥Space for a second and a half and lets go): the last window came to rest 2306 ms after the key or the button [slow]
- ~ **61 view-all** (presses ⌃⌥Space): the last window came to rest 734 ms after the key or the button [slow]
- ~ **67 dock-up** (presses ⌃⌥⌘ and the up arrow): the last window came to rest 715 ms after the key or the button [slow]
- ~ **69 view-in** (presses ⌃⌥↓): the last window came to rest 825 ms after the key or the button [slow]
- ~ **71 float** (presses ⌃⌥F): the last window came to rest 713 ms after the key or the button [slow]
- ~ **72 view-back** (presses ⌃⌥[): the last window came to rest 937 ms after the key or the button [slow]
- ✘ **83 drag-right-edge-of-terminal** (drags the right edge of terminal's window by -30 points): terminal (w51) moved 5 times [jolt]
  - +0 ms 13,305 289×244 · +1147 ms 13,305 282×244 · +1470 ms 13,305 275×244 · +1904 ms 13,305 268×244 · +2387 ms 13,305 261×244 · +4374 ms 12,305 261×244
- ~ **83 drag-right-edge-of-terminal** (drags the right edge of terminal's window by -30 points): the last window came to rest 829 ms after the key or the button [slow]
- ~ **87 view-back** (presses ⌃⌥[): the last window came to rest 771 ms after the key or the button [slow]
- ~ **91 view-home** (presses ⌃⌥0): the last window came to rest 715 ms after the key or the button [slow]
- ✘ **94 input-after** (a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text): w344 of Safari opened in one place and was then moved to another [jolt]
  - +0 ms 487,83 19×7 · +117 ms 330,83 332×144 · +134 ms 320,83 352×153 · +165 ms 306,83 380×165 · +199 ms 299,83 394×171 · +248 ms 297,82 398×174 · … 116 more … · +10302 ms 488,83 17×9 · +10311 ms 491,83 11×6 · +10344 ms 494,83 5×4 · +10354 ms 495,83 3×2 · +10366 ms off the screen
- ✘ **94 input-after** (a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text): w344 of Safari moved 11 times [jolt]
  - +0 ms 487,83 19×7 · +117 ms 330,83 332×144 · +134 ms 320,83 352×153 · +165 ms 306,83 380×165 · +199 ms 299,83 394×171 · +248 ms 297,82 398×174 · … 116 more … · +10302 ms 488,83 17×9 · +10311 ms 491,83 11×6 · +10344 ms 494,83 5×4 · +10354 ms 495,83 3×2 · +10366 ms off the screen

### Rule 4: the window you switch to comes to the front and into view

- ✘ **94 input-after** (a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text): desk-a (w87) is not in front: safari (w223) ahead of it, of which 1 cover part of it [behind]
- ✘ **94 input-after** (a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text): desk-a (w87) its app is not the one in front (process 23854 is) [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **93 quit** (chooses Quit Arbor in Arbor's menu): finder (w32) has its size back but not its place: 446,216 920×436, it was at 340,120 920×436 [size-lost]
- ✘ **93 quit** (chooses Quit Arbor in Arbor's menu): notes (w54) has its size back but not its place: 300,97 1000×660, it was at 300,105 1000×660 [size-lost]

### Rule L: no window is lost or stuck

- ✘ **55 launch** (starts Arbor): finder (w32) is out of view: 0% of it is on a display, at 1599,770 709×252 [lost]
- ✘ **55 launch** (starts Arbor): textedit (w46) is out of view: 0% of it is on a display, at 1599,790 247×378 [lost]
- ✘ **55 launch** (starts Arbor): terminal (w51) is out of view: 0% of it is on a display, at 1599,790 247×244 [lost]
- ✘ **55 launch** (starts Arbor): notes (w54) is out of view: 0% of it is on a display, at 1599,770 709×320 [lost]
- ✘ **55 launch** (starts Arbor): calendar (w60) is out of view: 0% of it is on a display, at 1599,770 680×503 [lost]
- ✘ **55 launch** (starts Arbor): settings (w63) is out of view: 0% of it is on a display, at 1599,770 723×470 [lost]
- ✘ **55 launch** (starts Arbor): preview (w67) is out of view: 0% of it is on a display, at 1599,770 708×248 [lost]
- ✘ **55 launch** (starts Arbor): desk-a (w87) is out of view: 0% of it is on a display, at 1599,790 246×248 [lost]
- ✘ **55 launch** (starts Arbor): desk-b (w89) is out of view: 0% of it is on a display, at 1599,790 709×248 [lost]
- ✘ **55 launch** (starts Arbor): safari (w223) is out of view: 0% of it is on a display, at 1599,770 1576×767 [lost]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (2, 23 ms) | quiet 645 ms; blind for 273 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 400 ms; blind for 1816 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (1, 0 ms) | quiet 2409 ms; blind for 1515 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×2 (4, 529 ms) | quiet 836 ms; blind for 340 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (3, 76 ms), w55 ×2 (10, 1565 ms), w57 ×1 (6, 222 ms) | quiet 430 ms; blind for 212 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (4, 277 ms) | quiet 1326 ms; blind for 124 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 681 ms; blind for 997 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview |  | quiet 371 ms; blind for 1249 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w73 ×1 (1, 0 ms) | quiet 443 ms; blind for 735 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (40, 4242 ms) | quiet 1484 ms; blind for 229 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (33, 2346 ms) | quiet 1048 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 361 ms |  |  |  |  |  |  |  |  |
| 13 | open-desks | opens the two windows that input is tried on | desk-a ×1 (2, 59 ms), desk-b ×1 (4, 65 ms) | quiet 423 ms; blind for 118 ms |  |  |  |  |  |  |  |  |
| 14 | input-before | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 792 ms; blind for 152 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 15 | launch | starts Arbor |  | quiet 1049 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 16 | input-started | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 749 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | click-mail | clicks mail's title bar |  | quiet 393 ms; blind for 170 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 18 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 428 ms; blind for 1090 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | arrange | presses ⌃⌥A | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 883 ms; blind for 204 ms |  |  | ✘ | ✔ |  |  | ✔ | ✔ |
| 20 | dock-icon-finder | clicks finder's icon in the Dock | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), settings ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1366 ms; blind for 156 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | new-window-finder | presses ⌘N in finder |  | quiet 1029 ms; blind for 111 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 22 | close-window | presses ⌘W |  | quiet 1140 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 23 | dock-icon-notes | clicks notes's icon in the Dock | finder ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 522 ms; blind for 145 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | hide-notes | presses ⌘H | finder ×1 (1, 0 ms), desk-b ×1 (2, 25 ms) | quiet 1016 ms; blind for 123 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 25 | unhide-notes | clicks its icon in the Dock | finder ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 437 ms; blind for 101 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | dock-icon-finder | clicks finder's icon in the Dock | finder ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 548 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | arrange | presses ⌃⌥A | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1980 ms; blind for 300 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 28 | cmd-tab-2 | holds ⌘ and presses Tab 2 time(s) | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1371 ms; blind for 106 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 29 | click-mail | clicks mail's title bar |  | quiet 462 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1223 ms; blind for 143 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 31 | view-back | presses ⌃⌥[ | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 949 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 32 | view-right | presses ⌃⌥→ | finder ×1 (1, 0 ms), notes ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 980 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 33 | pause | presses ⌃⌥⎋ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (2, 78 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (2, 25 ms), w73 ×1 (2, 25 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1698 ms |  |  | ~ | ✔ | ✔ |  | ✔ | ✔ |
| 34 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 355 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | resume | presses ⌃⌥⎋ | finder ×1 (2, 50 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (3, 49 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1356 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 36 | view-right | presses ⌃⌥→ | finder ×1 (1, 0 ms), notes ×1 (1, 0 ms), settings ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 917 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 37 | dock-icon-safari | clicks safari's icon in the Dock | safari ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 1310 ms; blind for 143 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | hide-safari | presses ⌘H | textedit ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 991 ms; blind for 140 ms |  | ~ | ✔ |  |  |  | ✔ | ✔ |
| 39 | unhide-safari | clicks its icon in the Dock | textedit ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 493 ms |  | ~ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | shrink | presses ⌃⌥⌘- |  | quiet 514 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 41 | shrink | presses ⌃⌥⌘- |  | quiet 478 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 42 | view-right | presses ⌃⌥→ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), notes ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 973 ms; blind for 167 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 43 | dock-icon-safari | clicks safari's icon in the Dock | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), notes ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 502 ms; blind for 115 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | quit-safari | presses ⌘Q in safari | finder ×1 (1, 0 ms) | quiet 1104 ms; blind for 337 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 45 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), notes ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 770 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 46 | reopen-safari | opens safari's document again |  | quiet 962 ms; blind for 2433 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 47 | view-out | presses ⌃⌥↑ | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1422 ms; blind for 110 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 48 | view-all | presses ⌃⌥Space |  | quiet 717 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 49 | dock-icon-calendar | clicks calendar's icon in the Dock | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 828 ms; blind for 132 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | redo | presses ⌃⌥⇧Z |  | quiet 652 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 51 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), textedit ×1 (2, 25 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (2, 34 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (2, 53 ms), w73 ×1 (2, 53 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 812 ms |  |  | ~ |  | ✔ |  | ✔ | ✔ |
| 52 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 416 ms; blind for 116 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 53 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 489 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 54 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 385 ms; blind for 121 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | launch | starts Arbor | finder ×2 (6, 617 ms), textedit ×3 (6, 1543 ms), terminal ×3 (5, 1533 ms), notes ×2 (4, 543 ms), calendar ×2 (2, 341 ms), settings ×2 (3, 426 ms), preview ×1 (3, 300 ms), mail ×2 (3, 1210 ms), w73 ×2 (3, 1210 ms), desk-a ×2 (5, 1210 ms), desk-b ×2 (5, 1172 ms), safari ×1 (1, 0 ms) | quiet 871 ms |  | ✘ | ✘ |  |  |  | ✘ | ✔ |
| 56 | dock-icon-notes | clicks notes's icon in the Dock | notes ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 637 ms; blind for 112 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | hide-notes | presses ⌘H | finder ×1 (2, 25 ms), desk-b ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 1117 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 58 | unhide-notes | clicks its icon in the Dock | finder ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 382 ms; blind for 144 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 59 | view-3 | presses ⌃⌥3 |  | quiet 857 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 60 | peek | holds ⌃⌥Space for a second and a half and lets go | finder ×2 (2, 1756 ms), textedit ×2 (2, 1756 ms), terminal ×2 (2, 1756 ms), notes ×2 (2, 1756 ms), desk-a ×2 (2, 1756 ms), desk-b ×2 (2, 1756 ms), safari ×1 (1, 0 ms) | quiet 1312 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 61 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 905 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 62 | view-all | presses ⌃⌥Space |  | quiet 779 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 63 | view-all | presses ⌃⌥Space |  | quiet 714 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 64 | dock-icon-calendar | clicks calendar's icon in the Dock | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 892 ms; blind for 121 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 65 | dock-up | presses ⌃⌥⌘ and the up arrow |  | quiet 572 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 66 | dock-icon-safari | clicks safari's icon in the Dock | finder ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 899 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 67 | dock-up | presses ⌃⌥⌘ and the up arrow | finder ×1 (1, 0 ms), notes ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 738 ms |  | ✔ | ~ | ✔ |  |  | ✔ | ✔ |
| 68 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 1231 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 69 | view-in | presses ⌃⌥↓ | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 1541 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 70 | dock-icon-notes | clicks notes's icon in the Dock | finder ×1 (1, 0 ms), notes ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 821 ms; blind for 137 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 71 | float | presses ⌃⌥F | notes ×1 (1, 0 ms) | quiet 857 ms |  | ✔ | ~ | ✔ | ✔ |  | ✔ | ✔ |
| 72 | view-back | presses ⌃⌥[ | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 1115 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 73 | focus-up | presses ⌃⌥⇧ and the up arrow |  | quiet 400 ms; blind for 116 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 74 | leave-alone | does nothing for half a minute |  | quiet 372 ms; blind for 100 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 75 | view-all | presses ⌃⌥Space |  | quiet 612 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 76 | view-all | presses ⌃⌥Space |  | quiet 773 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 77 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 459 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 78 | minimize-terminal | presses ⌘M | terminal ×1 (23, 457 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms) | quiet 1791 ms; blind for 174 ms |  | ~ | ✔ |  |  |  | ✔ | ✔ |
| 79 | restore-terminal | clicks its miniature in the Dock | terminal ×1 (14, 412 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms) | quiet 1450 ms |  | ~ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 80 | click-terminal | clicks terminal's title bar |  | quiet 543 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 81 | view-all | presses ⌃⌥Space |  | quiet 719 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 82 | view-left | presses ⌃⌥← |  | quiet 719 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 83 | drag-right-edge-of-terminal | drags the right edge of terminal's window by -30 points | textedit ×1 (1, 0 ms), terminal ×5 (5, 3227 ms), desk-a ×1 (1, 0 ms) | quiet 1257 ms; blind for 101 ms |  | ✔ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 84 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 562 ms; blind for 131 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 85 | pin | chooses Keep This Window in View in Arbor's menu, or takes the tick off | finder ×1 (2, 21 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 1053 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 86 | view-out | presses ⌃⌥↑ |  | quiet 705 ms; blind for 116 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 87 | view-back | presses ⌃⌥[ | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 1292 ms; blind for 102 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 88 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 459 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 89 | window-menu-finder | chooses finder's first window in the Window menu |  | quiet 1258 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 90 | view-in | presses ⌃⌥↓ | desk-b ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 902 ms |  |  | ✔ |  |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 91 | view-home | presses ⌃⌥0 | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 864 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 92 | input-last | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 864 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 93 | quit | chooses Quit Arbor in Arbor's menu | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (2, 20 ms), mail ×1 (2, 30 ms), w73 ×1 (2, 30 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (2, 35 ms), safari ×1 (2, 81 ms) | quiet 754 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 94 | input-after | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text | w344 ×11 (120, 10237 ms) | quiet 892 ms; blind for 117 ms |  | ✔ | ✘ | ✘ |  | ✔ | ✔ | ✔ |
| 95 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 454 ms; blind for 146 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 96 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 404 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 97 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 402 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 98 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 553 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 99 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 404 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 100 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 467 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 101 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 522 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 102 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 404 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 103 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 380 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
