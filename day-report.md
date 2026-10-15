63 steps in 254 s, 51 of them judged, 7 with a rule broken. The sampler: samples 5317 seconds 170.1 hz 31.3 cost-ms 4.15 late 19 longest-gap-ms 248 whole-samples 7974 whole-seconds 255.1 whole-late 160.
Input: 31 presses, releases, keys and scrolls reached the apps, half of them within 482 µs, 99 in 100 within 102159 µs, the latest after 102159 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 5, 688, 2712; forward 1, 81309, 81309; key 19, 344, 1032; up 6, 72884, 102159. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 101795; up 8, 6377.
The round of input `started` (events, half within µs): forward 8, 90396; up 8, 5021.
The round of input `last` (events, half within µs): forward 12, 31849; up 12, 946.
The round of input `after` (events, half within µs): forward 8, 38485; up 8, 1059.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 38 | 4 | 17 dock-left, 19 dock-right, 39 dock-left, 45 dock-right |
| 3 | no jolts: a window moves once, to where it ends up | 51 | 1 | 30 arrange |
| 4 | the window you switch to comes to the front and into view | 24 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 3 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 19 | 1 | 44 dock-icon-safari |
| L | no window is lost or stuck | 51 | 0 |  |
| - | what the script itself checked | 51 | 1 | 53 quit |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): safari (w35) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×791 · +743 ms 138,31 794×791 · +774 ms 806,31 794×791
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): textedit (w46) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +864 ms 806,65 673×439
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): terminal (w51) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,51 877×499 · +949 ms 806,51 793×499
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): notes (w54) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +1069 ms 300,105 794×660 · +1115 ms 806,105 794×660
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): calendar (w60) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 404,115 936×599 · +1214 ms 806,115 794×599
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): settings (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +1278 ms 806,85 723×625
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): preview (w67) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +1278 ms 806,35 708×424
- ✘ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): mail (w71) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +1473 ms 719,72 881×630
- ~ **17 dock-left** (presses ⌃⌥⌘ and the left arrow): w73 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +1473 ms 925,179 470×416
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): textedit (w46) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,65 673×439 · +555 ms 806,65 461×439 · +567 ms 541,65 461×439
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): terminal (w51) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,51 793×499 · +597 ms 541,51 464×499 · +629 ms 541,51 457×499
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): notes (w54) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,105 794×660 · +700 ms 417,105 709×660
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): calendar (w60) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,115 794×599 · +700 ms 806,115 680×599 · +756 ms 431,115 680×599
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): settings (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,85 723×625 · +756 ms 410,85 723×625
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): preview (w67) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,35 708×424 · +756 ms 417,35 708×424
- ✘ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): mail (w71) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 719,72 881×630 · +756 ms 331,72 881×630
- ~ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): w73 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 925,179 470×416 · +756 ms 537,179 470×416
- ✘ **39 dock-left** (presses ⌃⌥⌘ and the left arrow): safari (w35) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×790 · +349 ms 138,31 794×790 · +378 ms 806,31 794×790
- ✘ **39 dock-left** (presses ⌃⌥⌘ and the left arrow): textedit (w46) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +378 ms 806,65 673×439
- ✘ **39 dock-left** (presses ⌃⌥⌘ and the left arrow): terminal (w51) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,51 877×499 · +378 ms 806,51 793×499
- ✘ **39 dock-left** (presses ⌃⌥⌘ and the left arrow): notes (w54) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +475 ms 300,105 794×660 · +524 ms 806,105 794×660
- ✘ **39 dock-left** (presses ⌃⌥⌘ and the left arrow): calendar (w60) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 404,115 936×599 · +524 ms 806,115 794×599
- ✘ **39 dock-left** (presses ⌃⌥⌘ and the left arrow): settings (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +524 ms 806,85 723×625
- ✘ **39 dock-left** (presses ⌃⌥⌘ and the left arrow): preview (w67) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +524 ms 806,35 708×424
- ✘ **39 dock-left** (presses ⌃⌥⌘ and the left arrow): mail (w71) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +688 ms 719,72 881×630
- ~ **39 dock-left** (presses ⌃⌥⌘ and the left arrow): w73 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +688 ms 925,179 470×416
- ✘ **45 dock-right** (presses ⌃⌥⌘ and the right arrow): textedit (w46) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,65 673×439 · +1068 ms 541,65 461×439
- ✘ **45 dock-right** (presses ⌃⌥⌘ and the right arrow): terminal (w51) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,51 793×499 · +1068 ms 541,51 457×499
- ✘ **45 dock-right** (presses ⌃⌥⌘ and the right arrow): notes (w54) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,105 794×660 · +1068 ms 417,105 709×660
- ✘ **45 dock-right** (presses ⌃⌥⌘ and the right arrow): calendar (w60) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,115 794×599 · +1068 ms 431,115 680×599
- ✘ **45 dock-right** (presses ⌃⌥⌘ and the right arrow): settings (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,85 723×625 · +1068 ms 410,85 723×625
- ✘ **45 dock-right** (presses ⌃⌥⌘ and the right arrow): preview (w67) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,35 708×424 · +1068 ms 417,35 708×424
- ✘ **45 dock-right** (presses ⌃⌥⌘ and the right arrow): mail (w71) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 719,72 881×630 · +1068 ms 331,72 881×630
- ~ **45 dock-right** (presses ⌃⌥⌘ and the right arrow): w73 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 925,179 470×416 · +1068 ms 537,179 470×416

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **25 view-all** (presses ⌃⌥Space): w73 of Mail went 238 points out of its way before it ended up [jolt]
  - +0 ms 1805,877 470×416 · +578 ms 1924,877 470×416 · +637 ms 565,179 470×416
- ✘ **30 arrange** (chooses Arrange Windows): terminal (w51) moved 2 times [jolt]
  - +0 ms 40,51 877×499 · +73 ms 40,51 709×244 · +367 ms 12,565 709×244
- ✘ **30 arrange** (chooses Arrange Windows): preview (w67) moved 2 times [jolt]
  - +0 ms 4,35 708×424 · +73 ms 4,35 708×248 · +417 ms 12,43 708×246
- ~ **45 dock-right** (presses ⌃⌥⌘ and the right arrow): the last window came to rest 712 ms after the key or the button [slow]

### Rule 6: what a person presses reaches the apps, at once

- ✘ **44 dock-icon-safari** (clicks safari's icon in the Dock): the button came up, and the apps heard of it 102 ms later [input-held]

### Rule -: what the script itself checked

- ✘ **53 quit** (chooses Quit Arbor in Arbor's menu): Arbor's process ended, and nobody asked it to [crash]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder |  | quiet 517 ms; blind for 329 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 2407 ms; blind for 3048 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×2 (4, 1170 ms) | quiet 667 ms; blind for 639 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (5, 384 ms) | quiet 915 ms; blind for 806 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (4, 100 ms), w55 ×2 (16, 1531 ms), w57 ×1 (2, 36 ms) | quiet 384 ms; blind for 316 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (6, 364 ms) | quiet 1146 ms; blind for 163 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings |  | quiet 493 ms; blind for 999 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview |  | quiet 405 ms; blind for 1586 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w73 ×1 (1, 0 ms) | quiet 641 ms; blind for 360 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×5 (35, 4864 ms) | quiet 1156 ms; blind for 276 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (34, 2439 ms) | quiet 1019 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 425 ms; blind for 105 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 566 ms; blind for 217 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | launch | starts Arbor |  | quiet 1098 ms; blind for 189 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 15 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 552 ms; blind for 160 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### Docks and moves of the view, as Arbor ships

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 16 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 374 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (2, 87 ms), safari ×1 (2, 31 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (2, 46 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 932 ms; blind for 248 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 18 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 396 ms; blind for 160 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (2, 53 ms), textedit ×1 (2, 12 ms), terminal ×1 (2, 32 ms), notes ×1 (1, 0 ms), calendar ×1 (2, 56 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 914 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 20 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 352 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (3, 90 ms) | quiet 639 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 22 | click-safari | clicks safari's title bar |  | quiet 362 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (2, 40 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1046 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 24 | save-view-1 | presses ⌃⌥⇧1 |  | quiet 518 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 25 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (2, 9 ms), notes ×1 (2, 14 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (2, 59 ms), w73 ×1 (2, 59 ms) | quiet 1080 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 26 | view-1 | presses ⌃⌥1 | finder ×1 (1, 0 ms), safari ×1 (2, 85 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1126 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 27 | view-back | presses ⌃⌥[ | finder ×1 (1, 0 ms), safari ×1 (2, 10 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 736 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 28 | view-desktop | presses ⌃⌥D | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 913 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 29 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 669 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### Every window at once: most of them become tiles

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 30 | arrange | chooses Arrange Windows | finder ×1 (2, 191 ms), safari ×1 (2, 184 ms), textedit ×1 (3, 147 ms), terminal ×2 (2, 294 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×2 (2, 344 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1067 ms |  |  | ✘ | ✔ |  |  | ✔ | ✔ |

### What the one icon says

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 31 | hold | holds the view |  | quiet 406 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 32 | release | lets it go |  | quiet 411 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 33 | hold-still | asks Arbor to hold still |  | quiet 355 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 34 | release-again | lets it go |  | quiet 377 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 35 | pause | presses ⌃⌥⎋ | finder ×1 (1, 0 ms), safari ×1 (2, 101 ms), textedit ×1 (2, 13 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1126 ms |  |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 36 | resume | presses ⌃⌥⎋ | finder ×1 (2, 61 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 20 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 926 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 37 | float-all | presses ⌃⌥⇧F | finder ×1 (1, 0 ms), safari ×1 (2, 63 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1200 ms |  |  | ✔ |  | ✔ |  | ✔ | ✔ |

### Each is an option still

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 38 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 358 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (2, 55 ms), safari ×1 (2, 29 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (2, 49 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 913 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 40 | ring-on | switches the focus ring on |  | quiet 1083 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 41 | backdrop-on | darkens the wallpaper behind docked windows |  | quiet 385 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 42 | buttons-on | switches the buttons on |  | quiet 353 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 43 | motion-on | switches the motion on |  | quiet 369 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 44 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 397 ms; blind for 131 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 45 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1220 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 46 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 1016 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 47 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 806 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 48 | reset-focusRing | puts focusRing back |  | quiet 1023 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 49 | reset-dimBehindArranged | puts dimBehindArranged back |  | quiet 368 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 50 | reset-menuBarControls | puts menuBarControls back |  | quiet 381 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 51 | reset-animationDuration | puts animationDuration back |  | quiet 403 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 52 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 671 ms; blind for 105 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 53 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (2, 50 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (2, 43 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w73 ×1 (1, 0 ms) | quiet 808 ms |  |  | ✔ |  | ✔ |  | ✔ | ✘ |
| 54 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 676 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 55 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 473 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 56 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 477 ms; blind for 126 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 386 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 58 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 412 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 59 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 432 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 409 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 489 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 62 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 414 ms; blind for 146 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 63 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 485 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
