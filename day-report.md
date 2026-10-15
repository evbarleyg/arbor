97 steps in 278 s, 85 of them judged, 6 with a rule broken. The sampler: samples 7880 seconds 216.5 hz 36.4 cost-ms 2.73 late 6 longest-gap-ms 163 whole-samples 10173 whole-seconds 279.5 whole-late 95.
Input: 78 presses, releases, keys and scrolls reached the apps, half of them within 262 µs, 99 in 100 within 87269 µs, the latest after 87269 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 2, 1086, 1086; forward 4, 85495, 87269; key 66, 240, 1506; up 6, 2646, 11135. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 29264; up 8, 811.
The round of input `started` (events, half within µs): forward 8, 37075; up 8, 1611.
The round of input `last` (events, half within µs): forward 11, 32648; up 11, 698.
The round of input `after` (events, half within µs): forward 8, 36546; up 8, 565.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 51 | 4 | 17 dock-left, 19 dock-right, 41 grow, 67 view-home |
| 3 | no jolts: a window moves once, to where it ends up | 85 | 1 | 64 larger-font |
| 4 | the window you switch to comes to the front and into view | 48 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 1 | 1 | 87 quit |
| 6 | what a person presses reaches the apps, at once | 19 | 0 |  |
| L | no window is lost or stuck | 85 | 0 |  |
| - | what the script itself checked | 85 | 1 | 87 quit |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): finder (w32) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,120 920×436 · +1466 ms 806,120 794×436
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): safari (w35) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×791 · +1466 ms 806,31 794×791
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): textedit (w46) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +1466 ms 806,65 673×439
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): notes (w54) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +1466 ms 806,105 794×660
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): calendar (w60) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 404,115 936×599 · +1466 ms 806,115 794×599
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): settings (w61) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +1466 ms 806,85 723×625
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): preview (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +1466 ms 806,35 708×424
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): mail (w67) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1466 ms 719,72 881×630
- ~ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): w69 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1466 ms 925,179 470×416
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): finder (w32) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,120 794×436 · +1092 ms 521,120 501×436
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): textedit (w46) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,65 673×439 · +1092 ms 541,65 461×439
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): notes (w54) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,105 794×660 · +1092 ms 417,105 709×660
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): calendar (w60) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,115 794×599 · +1092 ms 431,115 680×599
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): settings (w61) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,85 723×625 · +1092 ms 410,85 723×625
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): preview (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,35 708×424 · +1092 ms 417,35 708×424
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): mail (w67) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 719,72 881×630 · +1092 ms 331,72 881×630
- ~ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): w69 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 925,179 470×416 · +1092 ms 537,179 470×416
- ✘ **41 grow** (presses ⌃⌥⌘=): finder (w32) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 521,120 501×436 · +862 ms 541,120 501×436
- ✘ **41 grow** (presses ⌃⌥⌘=): textedit (w46) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 541,65 461×439 · +862 ms 581,65 421×439
- ✘ **41 grow** (presses ⌃⌥⌘=): notes (w54) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 417,105 709×660 · +862 ms 437,105 709×660
- ✘ **41 grow** (presses ⌃⌥⌘=): calendar (w60) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 431,115 680×599 · +862 ms 451,115 680×599
- ✘ **41 grow** (presses ⌃⌥⌘=): settings (w61) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 410,85 723×625 · +862 ms 430,85 723×625
- ✘ **41 grow** (presses ⌃⌥⌘=): preview (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 417,35 708×424 · +862 ms 437,35 708×424
- ✘ **41 grow** (presses ⌃⌥⌘=): mail (w67) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 331,72 881×630 · +862 ms 351,72 881×630
- ~ **41 grow** (presses ⌃⌥⌘=): w69 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 537,179 470×416 · +862 ms 557,179 470×416
- ✘ **67 view-home** (presses ⌃⌥0): terminal (w51) is not back where it was after step 62: 12,43 557×757, it was at 12,43 555×769 [moved-unasked]

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): the last window came to rest 752 ms after the key or the button [slow]
- ✘ **64 larger-font** (presses ⌘+ in Terminal): terminal (w51) went 144 points out of its way before it ended up [jolt]
  - +0 ms 12,43 555×769 · +180 ms 12,43 629×791 · +429 ms 12,43 557×774 · +438 ms 12,43 557×757
- ~ **87 quit** (chooses Quit Arbor in Arbor's menu): w69 of Mail went 222 points out of its way before it ended up [jolt]
  - +0 ms 557,179 470×416 · +2572 ms 676,179 470×416 · +2609 ms 565,179 470×416

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **87 quit** (chooses Quit Arbor in Arbor's menu): terminal (w51) is 40,51 877×502; its own size was 40,51 877×499 [size-lost]

### Rule -: what the script itself checked

- ~ **64 larger-font** (presses ⌘+ in Terminal): w51 fills 557×757 of its slot 12,43 557×767 [script]
- ~ **67 view-home** (presses ⌃⌥0): w51 fills 557×757 of its slot 12,43 557×767 [script]
- ~ **69 view-home** (presses ⌃⌥0): w51 fills 557×757 of its slot 12,43 557×767 [script]
- ~ **71 view-home** (presses ⌃⌥0): w51 fills 557×757 of its slot 12,43 557×767 [script]
- ~ **73 view-home** (presses ⌃⌥0): w51 fills 557×757 of its slot 12,43 557×767 [script]
- ~ **75 view-home** (presses ⌃⌥0): w51 fills 557×757 of its slot 12,43 557×767 [script]
- ~ **77 view-home** (presses ⌃⌥0): w51 fills 557×757 of its slot 12,43 557×767 [script]
- ~ **79 view-home** (presses ⌃⌥0): w51 fills 557×757 of its slot 12,43 557×767 [script]
- ~ **81 view-home** (presses ⌃⌥0): w51 fills 557×757 of its slot 12,43 557×767 [script]
- ~ **83 view-home** (presses ⌃⌥0): w51 fills 557×757 of its slot 12,43 557×767 [script]
- ~ **85 view-home** (presses ⌃⌥0): w51 fills 557×757 of its slot 12,43 557×767 [script]
- ✘ **87 quit** (chooses Quit Arbor in Arbor's menu): Arbor's process ended, and nobody asked it to [crash]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 545 ms; blind for 364 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 485 ms; blind for 2683 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (5, 302 ms) | quiet 1399 ms; blind for 706 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (5, 348 ms) | quiet 1214 ms; blind for 140 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (5, 82 ms), w55 ×2 (12, 1306 ms), w57 ×1 (8, 236 ms) | quiet 398 ms; blind for 129 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (3, 287 ms) | quiet 1315 ms; blind for 122 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 501 ms; blind for 304 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (2, 60 ms) | quiet 775 ms; blind for 161 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | mail ×1 (3, 63 ms), w69 ×1 (5, 271 ms) | quiet 631 ms; blind for 763 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (39, 4257 ms) | quiet 1369 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (39, 2979 ms) | quiet 1052 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 421 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 713 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | launch | starts Arbor |  | quiet 1197 ms; blind for 116 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 15 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 757 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 16 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 520 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 827 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 18 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 461 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 1151 ms; blind for 163 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |

### Ten times away and back

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 20 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 981 ms; blind for 107 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 21 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 995 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 22 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 864 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 23 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 858 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 24 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 815 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 25 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 880 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 26 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 985 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 27 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 825 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 28 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 1057 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 29 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 764 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 30 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 1098 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 31 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 901 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 32 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 1001 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 33 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 792 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 34 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 927 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 35 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 838 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 36 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 782 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 37 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 739 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 38 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 1114 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 39 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 779 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### Another width

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 40 | click-terminal | clicks terminal's title bar |  | quiet 440 ms; blind for 129 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | grow | presses ⌃⌥⌘= | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 717 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 42 | click-safari | clicks safari's title bar |  | quiet 429 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 1007 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 44 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 830 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 45 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 988 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 46 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 773 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 47 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 1090 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 48 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 762 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 49 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 1017 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 50 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 758 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 51 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 995 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 52 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 760 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 53 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 1012 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 54 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 813 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 55 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 954 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 56 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 827 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 57 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 840 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 58 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 815 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 59 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 1042 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 60 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 803 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 61 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 942 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 62 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 742 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### A larger font

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 63 | click-terminal | clicks terminal's title bar |  | quiet 391 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 64 | larger-font | presses ⌘+ in Terminal | terminal ×1 (3, 258 ms) | quiet 1126 ms |  |  | ✘ |  |  |  | ✔ | ~ |
| 65 | click-safari | clicks safari's title bar |  | quiet 361 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 66 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 1041 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 67 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 830 ms |  | ✘ | ✔ |  |  |  | ✔ | ~ |
| 68 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 955 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 69 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 811 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 70 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 972 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 71 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 847 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 72 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 1105 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 73 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 884 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 74 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 1066 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 75 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 858 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 76 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 1081 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 77 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 886 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 78 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 971 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 79 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 824 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 80 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 1041 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 81 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 809 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 82 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 944 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 83 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 764 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 84 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 950 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 85 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w69 ×1 (1, 0 ms) | quiet 760 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 86 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 742 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 87 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (2, 61 ms), textedit ×1 (1, 0 ms), terminal ×1 (2, 55 ms), notes ×1 (2, 30 ms), calendar ×1 (2, 23 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (2, 37 ms), w69 ×1 (2, 37 ms) | quiet 838 ms |  |  | ~ |  | ✘ |  | ✔ | ✘ |
| 88 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 749 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 89 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 457 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 90 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 403 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 91 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 374 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 92 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 480 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 93 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 484 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 94 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 353 ms; blind for 122 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 95 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 525 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 96 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 360 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 97 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 408 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
