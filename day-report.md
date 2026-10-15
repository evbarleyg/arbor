95 steps in 297 s, 82 of them judged, 5 with a rule broken. The sampler: samples 7625 seconds 217.6 hz 35.0 cost-ms 3.29 late 15 longest-gap-ms 331 whole-samples 10455 whole-seconds 298.4 whole-late 136.
Input: 75 presses, releases, keys and scrolls reached the apps, half of them within 307 µs, 99 in 100 within 119244 µs, the latest after 119244 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 3, 1069, 3449; forward 2, 119244, 119244; key 65, 263, 29477; up 5, 1214, 9296. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 29640; up 8, 1229.
The round of input `started` (events, half within µs): forward 8, 60058; up 8, 2405.
The round of input `last` (events, half within µs): forward 11, 46090; up 11, 2098.
The round of input `after` (events, half within µs): forward 8, 55532; up 8, 3480.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 50 | 3 | 17 dock-left, 19 dock-right, 65 view-home |
| 3 | no jolts: a window moves once, to where it ends up | 83 | 1 | 62 larger-font |
| 4 | the window you switch to comes to the front and into view | 46 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 1 | 1 | 85 quit |
| 6 | what a person presses reaches the apps, at once | 18 | 0 |  |
| L | no window is lost or stuck | 83 | 0 |  |
| - | what the script itself checked | 83 | 1 | 85 quit |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): finder (w32) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,120 920×436 · +2234 ms 806,120 794×436
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): safari (w35) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×791 · +2234 ms 806,31 794×791
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): textedit (w46) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +2234 ms 806,65 673×439
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): notes (w54) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +2234 ms 806,105 794×660
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): calendar (w60) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 404,115 936×599 · +2234 ms 806,115 794×599
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): settings (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +2234 ms 806,85 723×625
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): preview (w67) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +2234 ms 806,35 708×424
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): mail (w71) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +2234 ms 719,72 881×630
- ~ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): w73 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +2234 ms 925,179 470×416
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): finder (w32) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,120 794×436 · +1412 ms 521,120 501×436
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): textedit (w46) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,65 673×439 · +1412 ms 541,65 461×439
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): notes (w54) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,105 794×660 · +1412 ms 417,105 709×660
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): calendar (w60) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,115 794×599 · +1412 ms 431,115 680×599
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): settings (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,85 723×625 · +1412 ms 410,85 723×625
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): preview (w67) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,35 708×424 · +1412 ms 417,35 708×424
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): mail (w71) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 719,72 881×630 · +1412 ms 331,72 881×630
- ~ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): w73 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 925,179 470×416 · +1412 ms 537,179 470×416
- ✘ **65 view-home** (presses ⌃⌥0): terminal (w51) is not back where it was after step 60: 12,43 517×757, it was at 12,43 513×769 [moved-unasked]

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): the last window came to rest 1917 ms after the key or the button, in Arbor's first act since it started [slow]
- ~ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): the last window came to rest 1055 ms after the key or the button [slow]
- ✘ **62 larger-font** (presses ⌘+ in Terminal): terminal (w51) moved 2 times [jolt]
  - +0 ms 12,43 513×769 · +191 ms 12,43 581×791 · +596 ms 12,43 517×757

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **85 quit** (chooses Quit Arbor in Arbor's menu): terminal (w51) is 40,51 877×502; its own size was 40,51 877×499 [size-lost]

### Rule -: what the script itself checked

- ~ **30 view-frame** (presses ⌃⌥↩): w35 fills 1569×767 of its slot 12,43 1576×767 [script]
- ~ **62 larger-font** (presses ⌘+ in Terminal): w51 fills 517×757 of its slot 12,43 517×767 [script]
- ~ **65 view-home** (presses ⌃⌥0): w51 fills 517×757 of its slot 12,43 517×767 [script]
- ~ **67 view-home** (presses ⌃⌥0): w51 fills 517×757 of its slot 12,43 517×767 [script]
- ~ **69 view-home** (presses ⌃⌥0): w51 fills 517×757 of its slot 12,43 517×767 [script]
- ~ **71 view-home** (presses ⌃⌥0): w51 fills 517×757 of its slot 12,43 517×767 [script]
- ~ **73 view-home** (presses ⌃⌥0): w51 fills 517×757 of its slot 12,43 517×767 [script]
- ~ **75 view-home** (presses ⌃⌥0): w51 fills 517×757 of its slot 12,43 517×767 [script]
- ~ **77 view-home** (presses ⌃⌥0): w51 fills 517×757 of its slot 12,43 517×767 [script]
- ~ **79 view-home** (presses ⌃⌥0): w51 fills 517×757 of its slot 12,43 517×767 [script]
- ~ **81 view-home** (presses ⌃⌥0): w51 fills 517×757 of its slot 12,43 517×767 [script]
- ~ **83 view-home** (presses ⌃⌥0): w51 fills 517×757 of its slot 12,43 517×767 [script]
- ✘ **85 quit** (chooses Quit Arbor in Arbor's menu): Arbor's process ended, and nobody asked it to [crash]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 480 ms; blind for 366 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 482 ms; blind for 898 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (2, 225 ms) | quiet 1751 ms; blind for 1345 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (7, 339 ms) | quiet 933 ms; blind for 193 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (2, 11 ms), w55 ×2 (10, 1603 ms), w57 ×1 (4, 199 ms) | quiet 478 ms; blind for 227 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×2 (4, 407 ms) | quiet 1318 ms; blind for 182 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings |  | quiet 395 ms; blind for 1378 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (1, 0 ms) | quiet 777 ms; blind for 850 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w73 ×1 (1, 0 ms) | quiet 575 ms; blind for 556 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (38, 4248 ms) | quiet 1421 ms; blind for 123 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (37, 2377 ms) | quiet 1058 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 350 ms; blind for 210 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 667 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | launch | starts Arbor |  | quiet 964 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 15 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 590 ms; blind for 114 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 16 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 375 ms; blind for 331 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 520 ms; blind for 176 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 18 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 398 ms; blind for 136 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 749 ms; blind for 110 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |

### Ten times away and back

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 20 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1006 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 21 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 811 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 22 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 906 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 23 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 834 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 24 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 880 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 25 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 951 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 26 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 841 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 27 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 778 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 28 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1116 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 29 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 858 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 30 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 945 ms |  |  | ✔ | ✔ |  |  | ✔ | ~ |
| 31 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 792 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 32 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1015 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 33 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 987 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 34 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1060 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 35 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 934 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 36 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 820 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 37 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 752 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 38 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 895 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 39 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 870 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### Another width

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 40 | click-safari | clicks safari's title bar |  | quiet 405 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1029 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 42 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 855 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 43 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1050 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 44 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 771 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 45 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1048 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 46 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 813 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 47 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 990 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 48 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 833 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 49 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 951 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 50 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 775 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 51 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 981 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 52 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 925 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 53 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 993 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 54 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 775 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 55 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 959 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 56 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 829 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 57 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 898 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 58 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 728 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 59 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1051 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 60 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 793 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### A larger font

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 61 | click-terminal | clicks terminal's title bar |  | quiet 362 ms; blind for 137 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 62 | larger-font | presses ⌘+ in Terminal | terminal ×2 (2, 405 ms) | quiet 1129 ms |  |  | ✘ |  |  |  | ✔ | ~ |
| 63 | click-safari | clicks safari's title bar |  | quiet 380 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 64 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 931 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 65 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 781 ms |  | ✘ | ✔ |  |  |  | ✔ | ~ |
| 66 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1047 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 67 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 709 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 68 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1007 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 69 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 834 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 70 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1081 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 71 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 782 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 72 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1015 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 73 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 808 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 74 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1027 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 75 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 746 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 76 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1047 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 77 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 735 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 78 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1039 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 79 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 854 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 80 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1022 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 81 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 676 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 82 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 933 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 83 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 834 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 84 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 718 ms; blind for 170 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 85 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (2, 94 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (2, 45 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 733 ms |  |  | ✔ |  | ✘ |  | ✔ | ✘ |
| 86 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 678 ms; blind for 108 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 87 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 417 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 88 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 430 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 89 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 415 ms; blind for 174 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 90 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 483 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 91 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 486 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 92 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 389 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 93 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 548 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 94 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 411 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 95 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 582 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
