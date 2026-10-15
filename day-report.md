134 steps in 359 s, 122 of them judged, 4 with a rule broken. The sampler: samples 10790 seconds 299.1 hz 36.1 cost-ms 2.53 late 46 longest-gap-ms 191 whole-samples 13011 whole-seconds 360.6 whole-late 76.
Input: 236 presses, releases, keys and scrolls reached the apps, half of them within 10088 µs, 99 in 100 within 123457 µs, the latest after 137396 µs.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 117 | 2 | 15 dock-left, 17 dock-right |
| 3 | no jolts: a window moves once, to where it ends up | 122 | 2 | 83 pause, 118 quit |
| 4 | the window you switch to comes to the front and into view | 117 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 2 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 114 | 0 |  |
| L | no window is lost or stuck | 122 | 0 |  |
| - | what the script itself checked | 122 | 0 |  |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **15 dock-left** (presses ⌃⌥⌘ and the left arrow): safari (w35) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 138,31 1324×791 · +2699 ms 806,31 794×791
- ✘ **15 dock-left** (presses ⌃⌥⌘ and the left arrow): textedit (w45) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +2699 ms 806,65 673×439
- ✘ **15 dock-left** (presses ⌃⌥⌘ and the left arrow): terminal (w48) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,51 877×499 · +2699 ms 806,51 793×499
- ✘ **15 dock-left** (presses ⌃⌥⌘ and the left arrow): notes (w51) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +2699 ms 806,105 794×660
- ✘ **15 dock-left** (presses ⌃⌥⌘ and the left arrow): calendar (w57) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 404,115 936×599 · +2699 ms 806,115 794×599
- ✘ **15 dock-left** (presses ⌃⌥⌘ and the left arrow): settings (w58) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +2699 ms 806,85 723×625
- ✘ **15 dock-left** (presses ⌃⌥⌘ and the left arrow): preview (w62) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +2699 ms 806,35 708×424
- ✘ **15 dock-left** (presses ⌃⌥⌘ and the left arrow): mail (w66) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 240,72 1120×630 · +2699 ms 719,72 881×630
- ~ **15 dock-left** (presses ⌃⌥⌘ and the left arrow): w68 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +2699 ms 925,179 470×416
- ✘ **17 dock-right** (presses ⌃⌥⌘ and the right arrow): textedit (w45) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,65 673×439 · +1217 ms 541,65 461×439
- ✘ **17 dock-right** (presses ⌃⌥⌘ and the right arrow): terminal (w48) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,51 793×499 · +1217 ms 541,51 457×499
- ✘ **17 dock-right** (presses ⌃⌥⌘ and the right arrow): notes (w51) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,105 794×660 · +1217 ms 417,105 709×660
- ✘ **17 dock-right** (presses ⌃⌥⌘ and the right arrow): calendar (w57) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,115 794×599 · +1217 ms 431,115 680×599
- ✘ **17 dock-right** (presses ⌃⌥⌘ and the right arrow): settings (w58) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,85 723×625 · +1217 ms 410,85 723×625
- ✘ **17 dock-right** (presses ⌃⌥⌘ and the right arrow): preview (w62) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 806,35 708×424 · +1217 ms 417,35 708×424
- ✘ **17 dock-right** (presses ⌃⌥⌘ and the right arrow): mail (w66) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 719,72 881×630 · +1217 ms 331,72 881×630
- ~ **17 dock-right** (presses ⌃⌥⌘ and the right arrow): w68 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 925,179 470×416 · +1217 ms 537,179 470×416

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **15 dock-left** (presses ⌃⌥⌘ and the left arrow): the last window came to rest 2420 ms after the key or the button, in Arbor's first act since it started [slow]
- ~ **17 dock-right** (presses ⌃⌥⌘ and the right arrow): the last window came to rest 1064 ms after the key or the button [slow]
- ✘ **83 pause** (presses ⌃⌥⎋): finder (w32) moved 2 times [jolt]
  - +0 ms 12,43 517×767 · +386 ms 340,120 920×436 · +2486 ms 340,120 517×701 · +2525 ms 12,43 517×767
- ✘ **83 pause** (presses ⌃⌥⎋): safari (w35) moved 2 times [jolt]
  - +0 ms 1014,43 574×767 · +453 ms 138,31 586×778 · +512 ms 138,31 1324×790 · +2585 ms 1014,43 574×767
- ✘ **83 pause** (presses ⌃⌥⎋): textedit (w45) moved 2 times [jolt]
  - +0 ms 541,65 461×439 · +601 ms 165,65 673×439 · +2733 ms 541,65 461×439
- ✘ **83 pause** (presses ⌃⌥⎋): terminal (w48) moved 2 times [jolt]
  - +0 ms 541,51 457×499 · +652 ms 40,51 877×499 · +2801 ms 541,51 457×499
- ✘ **83 pause** (presses ⌃⌥⎋): notes (w51) moved 2 times [jolt]
  - +0 ms 417,105 709×660 · +737 ms 300,105 1000×660 · +2918 ms 300,105 709×660 · +2995 ms 417,105 709×660
- ✘ **83 pause** (presses ⌃⌥⎋): calendar (w57) moved 2 times [jolt]
  - +0 ms 431,115 680×599 · +786 ms 431,115 936×599 · +804 ms 404,115 936×599 · +3054 ms 404,115 680×599 · +3071 ms 431,115 680×599
- ✘ **83 pause** (presses ⌃⌥⎋): settings (w58) moved 2 times [jolt]
  - +0 ms 410,85 723×625 · +804 ms 437,85 723×625 · +3185 ms 410,85 723×625
- ✘ **83 pause** (presses ⌃⌥⎋): preview (w62) moved 2 times [jolt]
  - +0 ms 417,35 708×424 · +851 ms 4,35 708×424 · +3253 ms 417,35 708×424
- ✘ **83 pause** (presses ⌃⌥⎋): mail (w66) moved 2 times [jolt]
  - +0 ms 331,72 881×630 · +912 ms 331,72 1120×630 · +950 ms 240,72 1120×630 · +3424 ms 331,72 881×630
- ✘ **83 pause** (presses ⌃⌥⎋): w68 of Mail moved 2 times [jolt]
  - +0 ms 537,179 470×416 · +912 ms 656,179 470×416 · +950 ms 565,179 470×416 · +3424 ms 537,179 470×416
- ~ **83 pause** (presses ⌃⌥⎋): finder (w32) was still moving 379 ms after everything had been quiet for a second [jolt]
- ~ **83 pause** (presses ⌃⌥⎋): safari (w35) was still moving 439 ms after everything had been quiet for a second [jolt]
- ~ **83 pause** (presses ⌃⌥⎋): textedit (w45) was still moving 587 ms after everything had been quiet for a second [jolt]
- ~ **83 pause** (presses ⌃⌥⎋): terminal (w48) was still moving 655 ms after everything had been quiet for a second [jolt]
- ~ **83 pause** (presses ⌃⌥⎋): notes (w51) was still moving 849 ms after everything had been quiet for a second [jolt]
- ~ **83 pause** (presses ⌃⌥⎋): calendar (w57) was still moving 925 ms after everything had been quiet for a second [jolt]
- ~ **83 pause** (presses ⌃⌥⎋): settings (w58) was still moving 1039 ms after everything had been quiet for a second [jolt]
- ~ **83 pause** (presses ⌃⌥⎋): preview (w62) was still moving 1107 ms after everything had been quiet for a second [jolt]
- ~ **83 pause** (presses ⌃⌥⎋): mail (w66) was still moving 1278 ms after everything had been quiet for a second [jolt]
- ~ **83 pause** (presses ⌃⌥⎋): w68 of Mail was still moving 1278 ms after everything had been quiet for a second [jolt]
- ✘ **83 pause** (presses ⌃⌥⎋): the last window came to rest 3173 ms after the key or the button [slow]
- ✘ **118 quit** (chooses Quit Arbor in Arbor's menu): finder (w32) moved 2 times [jolt]
  - +0 ms 12,43 517×767 · +2787 ms 340,120 920×436 · +4939 ms 340,120 517×701 · +4957 ms 12,43 517×767
- ✘ **118 quit** (chooses Quit Arbor in Arbor's menu): safari (w35) moved 2 times [jolt]
  - +0 ms 1014,43 574×767 · +2871 ms 1014,43 586×778 · +2905 ms 138,31 586×778 · +3003 ms 138,31 1324×790 · +5051 ms 138,31 574×767 · +5069 ms 1014,43 574×767
- ✘ **118 quit** (chooses Quit Arbor in Arbor's menu): textedit (w45) moved 2 times [jolt]
  - +0 ms 541,65 461×439 · +3003 ms 541,65 673×439 · +3011 ms 165,65 673×439 · +5287 ms 541,65 461×439
- ✘ **118 quit** (chooses Quit Arbor in Arbor's menu): terminal (w48) moved 2 times [jolt]
  - +0 ms 541,51 457×499 · +3072 ms 541,51 877×499 · +3088 ms 40,51 877×499 · +5346 ms 541,51 457×499
- ✘ **118 quit** (chooses Quit Arbor in Arbor's menu): notes (w51) moved 2 times [jolt]
  - +0 ms 417,105 709×660 · +3145 ms 300,105 1000×660 · +5496 ms 417,105 709×660
- ✘ **118 quit** (chooses Quit Arbor in Arbor's menu): calendar (w57) moved 2 times [jolt]
  - +0 ms 431,115 680×599 · +3236 ms 431,115 936×599 · +3254 ms 404,115 936×599 · +5613 ms 404,115 680×599 · +5662 ms 431,115 680×599
- ✘ **118 quit** (chooses Quit Arbor in Arbor's menu): settings (w58) moved 2 times [jolt]
  - +0 ms 410,85 723×625 · +3267 ms 437,85 723×625 · +5716 ms 410,85 723×625
- ✘ **118 quit** (chooses Quit Arbor in Arbor's menu): preview (w62) moved 2 times [jolt]
  - +0 ms 417,35 708×424 · +3307 ms 4,35 708×424 · +5784 ms 417,35 708×424
- ✘ **118 quit** (chooses Quit Arbor in Arbor's menu): mail (w66) moved 2 times [jolt]
  - +0 ms 331,72 881×630 · +3411 ms 240,72 1120×630 · +5969 ms 240,72 881×630 · +5974 ms 331,72 881×630
- ✘ **118 quit** (chooses Quit Arbor in Arbor's menu): w68 of Mail moved 2 times [jolt]
  - +0 ms 537,179 470×416 · +3411 ms 565,179 470×416 · +5969 ms 446,179 470×416 · +5974 ms 537,179 470×416
- ~ **118 quit** (chooses Quit Arbor in Arbor's menu): finder (w32) was still moving 484 ms after everything had been quiet for a second [jolt]
- ~ **118 quit** (chooses Quit Arbor in Arbor's menu): safari (w35) was still moving 596 ms after everything had been quiet for a second [jolt]
- ~ **118 quit** (chooses Quit Arbor in Arbor's menu): textedit (w45) was still moving 814 ms after everything had been quiet for a second [jolt]
- ~ **118 quit** (chooses Quit Arbor in Arbor's menu): terminal (w48) was still moving 873 ms after everything had been quiet for a second [jolt]
- ~ **118 quit** (chooses Quit Arbor in Arbor's menu): notes (w51) was still moving 1023 ms after everything had been quiet for a second [jolt]
- ~ **118 quit** (chooses Quit Arbor in Arbor's menu): calendar (w57) was still moving 1189 ms after everything had been quiet for a second [jolt]
- ~ **118 quit** (chooses Quit Arbor in Arbor's menu): settings (w58) was still moving 1243 ms after everything had been quiet for a second [jolt]
- ~ **118 quit** (chooses Quit Arbor in Arbor's menu): preview (w62) was still moving 1311 ms after everything had been quiet for a second [jolt]
- ~ **118 quit** (chooses Quit Arbor in Arbor's menu): mail (w66) was still moving 1501 ms after everything had been quiet for a second [jolt]
- ~ **118 quit** (chooses Quit Arbor in Arbor's menu): w68 of Mail was still moving 1501 ms after everything had been quiet for a second [jolt]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (2, 24 ms) | quiet 648 ms; blind for 220 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 375 ms; blind for 2503 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (4, 268 ms) | quiet 1719 ms; blind for 601 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal |  | quiet 970 ms; blind for 797 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (3, 103 ms), w52 ×2 (14, 999 ms), w54 ×1 (7, 231 ms) | quiet 381 ms; blind for 155 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (5, 420 ms) | quiet 1434 ms; blind for 112 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings |  | quiet 428 ms; blind for 353 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview |  | quiet 393 ms; blind for 390 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | mail ×1 (3, 69 ms), w68 ×1 (4, 211 ms) | quiet 840 ms; blind for 775 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (43, 3840 ms) | quiet 1400 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (36, 2444 ms) | quiet 1000 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 438 ms |  |  |  |  |  |  |  |  |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 13 | launch | starts Arbor |  | quiet 1083 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 14 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 409 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 15 | dock-left | presses ⌃⌥⌘ and the left arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w68 ×1 (1, 0 ms) | quiet 979 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 16 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 387 ms; blind for 121 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | dock-right | presses ⌃⌥⌘ and the right arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w68 ×1 (1, 0 ms) | quiet 939 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 18 | view-all | presses ⌃⌥Space |  | quiet 599 ms |  |  | ✔ |  |  |  | ✔ | ✔ |

### Arbor as it ships

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 19 | click-finder | clicks finder's title bar |  | quiet 360 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | click-safari | clicks safari's title bar |  | quiet 406 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | click-finder | clicks finder's title bar |  | quiet 367 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 22 | click-safari | clicks safari's title bar |  | quiet 350 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | click-finder | clicks finder's title bar |  | quiet 438 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | click-safari | clicks safari's title bar |  | quiet 438 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | click-finder | clicks finder's title bar |  | quiet 386 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | click-safari | clicks safari's title bar |  | quiet 357 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | click-finder | clicks finder's title bar |  | quiet 406 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | click-safari | clicks safari's title bar |  | quiet 397 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 29 | click-finder | clicks finder's title bar |  | quiet 387 ms; blind for 116 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | click-safari | clicks safari's title bar |  | quiet 409 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | click-finder | clicks finder's title bar |  | quiet 387 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | click-safari | clicks safari's title bar |  | quiet 394 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | click-finder | clicks finder's title bar |  | quiet 384 ms; blind for 186 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | click-safari | clicks safari's title bar |  | quiet 371 ms; blind for 115 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### Without a trace being recorded

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 35 | click-finder | clicks finder's title bar |  | quiet 425 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 36 | click-safari | clicks safari's title bar |  | quiet 386 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | click-finder | clicks finder's title bar |  | quiet 399 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | click-safari | clicks safari's title bar |  | quiet 408 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | click-finder | clicks finder's title bar |  | quiet 431 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | click-safari | clicks safari's title bar |  | quiet 435 ms; blind for 119 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | click-finder | clicks finder's title bar |  | quiet 412 ms; blind for 112 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | click-safari | clicks safari's title bar |  | quiet 440 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | click-finder | clicks finder's title bar |  | quiet 360 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | click-safari | clicks safari's title bar |  | quiet 488 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | click-finder | clicks finder's title bar |  | quiet 382 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 46 | click-safari | clicks safari's title bar |  | quiet 380 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | click-finder | clicks finder's title bar |  | quiet 360 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | click-safari | clicks safari's title bar |  | quiet 352 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | click-finder | clicks finder's title bar |  | quiet 362 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | click-safari | clicks safari's title bar |  | quiet 419 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### Without the line round the focused window

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 51 | click-finder | clicks finder's title bar |  | quiet 371 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | click-safari | clicks safari's title bar |  | quiet 365 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 53 | click-finder | clicks finder's title bar |  | quiet 392 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 54 | click-safari | clicks safari's title bar |  | quiet 350 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | click-finder | clicks finder's title bar |  | quiet 411 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 56 | click-safari | clicks safari's title bar |  | quiet 432 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | click-finder | clicks finder's title bar |  | quiet 423 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 58 | click-safari | clicks safari's title bar |  | quiet 408 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 59 | click-finder | clicks finder's title bar |  | quiet 378 ms; blind for 126 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | click-safari | clicks safari's title bar |  | quiet 418 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | click-finder | clicks finder's title bar |  | quiet 360 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 62 | click-safari | clicks safari's title bar |  | quiet 466 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 63 | click-finder | clicks finder's title bar |  | quiet 369 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 64 | click-safari | clicks safari's title bar |  | quiet 455 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 65 | click-finder | clicks finder's title bar |  | quiet 420 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 66 | click-safari | clicks safari's title bar |  | quiet 371 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### With no event tap at all

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 67 | click-finder | clicks finder's title bar |  | quiet 389 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 68 | click-safari | clicks safari's title bar |  | quiet 428 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 69 | click-finder | clicks finder's title bar |  | quiet 378 ms; blind for 160 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 70 | click-safari | clicks safari's title bar |  | quiet 403 ms; blind for 142 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 71 | click-finder | clicks finder's title bar |  | quiet 368 ms; blind for 178 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 72 | click-safari | clicks safari's title bar |  | quiet 415 ms; blind for 152 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 73 | click-finder | clicks finder's title bar |  | quiet 413 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 74 | click-safari | clicks safari's title bar |  | quiet 553 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 75 | click-finder | clicks finder's title bar |  | quiet 434 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 76 | click-safari | clicks safari's title bar |  | quiet 453 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 77 | click-finder | clicks finder's title bar |  | quiet 413 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 78 | click-safari | clicks safari's title bar |  | quiet 351 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 79 | click-finder | clicks finder's title bar |  | quiet 419 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 80 | click-safari | clicks safari's title bar |  | quiet 486 ms; blind for 118 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 81 | click-finder | clicks finder's title bar |  | quiet 370 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 82 | click-safari | clicks safari's title bar |  | quiet 401 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### Paused, the windows put back where they were

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 83 | pause | presses ⌃⌥⎋ | finder ×2 (3, 2139 ms), safari ×2 (3, 2132 ms), textedit ×2 (2, 2132 ms), terminal ×2 (2, 2149 ms), notes ×2 (3, 2258 ms), calendar ×2 (4, 2285 ms), settings ×2 (2, 2381 ms), preview ×2 (2, 2402 ms), mail ×2 (3, 2512 ms), w68 ×2 (3, 2512 ms) | quiet 1490 ms |  |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 84 | click-finder | clicks finder's title bar |  | quiet 376 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 85 | click-safari | clicks safari's title bar |  | quiet 409 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 86 | click-finder | clicks finder's title bar |  | quiet 368 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 87 | click-safari | clicks safari's title bar |  | quiet 419 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 88 | click-finder | clicks finder's title bar |  | quiet 390 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 89 | click-safari | clicks safari's title bar |  | quiet 426 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 90 | click-finder | clicks finder's title bar |  | quiet 357 ms; blind for 117 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 91 | click-safari | clicks safari's title bar |  | quiet 389 ms; blind for 118 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 92 | click-finder | clicks finder's title bar |  | quiet 422 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 93 | click-safari | clicks safari's title bar |  | quiet 401 ms; blind for 141 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 94 | click-finder | clicks finder's title bar |  | quiet 376 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 95 | click-safari | clicks safari's title bar |  | quiet 354 ms; blind for 114 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 96 | click-finder | clicks finder's title bar |  | quiet 350 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 97 | click-safari | clicks safari's title bar |  | quiet 358 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 98 | click-finder | clicks finder's title bar |  | quiet 385 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 99 | click-safari | clicks safari's title bar |  | quiet 358 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 100 | resume | presses ⌃⌥⎋ |  | quiet 836 ms |  |  | ✔ |  |  |  | ✔ | ✔ |

### As it ships, once more: is it the settings, or the time of day?

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 101 | view-all | presses ⌃⌥Space |  | quiet 721 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 102 | click-finder | clicks finder's title bar |  | quiet 360 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 103 | click-safari | clicks safari's title bar |  | quiet 401 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 104 | click-finder | clicks finder's title bar |  | quiet 448 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 105 | click-safari | clicks safari's title bar |  | quiet 417 ms; blind for 107 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 106 | click-finder | clicks finder's title bar |  | quiet 414 ms; blind for 102 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 107 | click-safari | clicks safari's title bar |  | quiet 371 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 108 | click-finder | clicks finder's title bar |  | quiet 409 ms; blind for 139 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 109 | click-safari | clicks safari's title bar |  | quiet 422 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 110 | click-finder | clicks finder's title bar |  | quiet 365 ms; blind for 100 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 111 | click-safari | clicks safari's title bar |  | quiet 410 ms; blind for 102 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 112 | click-finder | clicks finder's title bar |  | quiet 500 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 113 | click-safari | clicks safari's title bar |  | quiet 440 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 114 | click-finder | clicks finder's title bar |  | quiet 395 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 115 | click-safari | clicks safari's title bar |  | quiet 405 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 116 | click-finder | clicks finder's title bar |  | quiet 408 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 117 | click-safari | clicks safari's title bar |  | quiet 507 ms; blind for 113 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 118 | quit | chooses Quit Arbor in Arbor's menu | finder ×2 (3, 2170 ms), safari ×2 (5, 2198 ms), textedit ×2 (3, 2284 ms), terminal ×2 (3, 2274 ms), notes ×2 (2, 2351 ms), calendar ×2 (4, 2426 ms), settings ×2 (2, 2449 ms), preview ×2 (2, 2477 ms), mail ×2 (3, 2563 ms), w68 ×2 (3, 2563 ms) | quiet 655 ms; blind for 101 ms |  |  | ✘ |  | ✔ |  | ✔ | ✔ |

### After Quit, the windows put back where they were: the same Mac without Arbor

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 119 | click-finder | clicks finder's title bar |  | quiet 416 ms; blind for 146 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 120 | click-safari | clicks safari's title bar |  | quiet 374 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 121 | click-finder | clicks finder's title bar |  | quiet 430 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 122 | click-safari | clicks safari's title bar |  | quiet 438 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 123 | click-finder | clicks finder's title bar |  | quiet 451 ms; blind for 142 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 124 | click-safari | clicks safari's title bar |  | quiet 357 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 125 | click-finder | clicks finder's title bar |  | quiet 394 ms; blind for 191 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 126 | click-safari | clicks safari's title bar |  | quiet 436 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 127 | click-finder | clicks finder's title bar |  | quiet 419 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 128 | click-safari | clicks safari's title bar |  | quiet 367 ms; blind for 183 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 129 | click-finder | clicks finder's title bar |  | quiet 429 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 130 | click-safari | clicks safari's title bar |  | quiet 390 ms; blind for 121 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 131 | click-finder | clicks finder's title bar |  | quiet 355 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 132 | click-safari | clicks safari's title bar |  | quiet 427 ms; blind for 143 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 133 | click-finder | clicks finder's title bar |  | quiet 353 ms; blind for 119 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 134 | click-safari | clicks safari's title bar |  | quiet 370 ms; blind for 115 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
