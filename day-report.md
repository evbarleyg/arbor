54 steps, 7 with a rule broken. The sampler: samples 5244 seconds 182.6 hz 28.7 cost-ms 5.34 late 1747 longest-gap-ms 1742.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 2 | nothing moves that the person did not move | 43 | 2 | 42 minimize-safari, 43 restore-safari |
| 3 | no jolts: a window moves once, to where it ends up | 45 | 2 | 21 cmd-tab, 49 reopen-textedit |
| 4 | the window you switch to comes to the front and into view | 36 | 3 | 25 drag-calendar-back, 31 dock-icon-calendar-2, 38 window-menu |
| 5 | quitting, Float All and pause give windows their own sizes back | 1 | 0 |  |
| L | no window is lost or stuck | 45 | 0 |  |
| - | what the script itself checked | 45 | 0 |  |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **42 minimize-safari** (presses ⌘M): safari (w34) moved, and the step did not name it
  - +0 ms 138,31 1324×791 · +406 ms 138,31 1324×792 · +428 ms 141,56 1321×792 · +462 ms 194,139 1268×731 · +529 ms 666,386 796×484 · +539 ms 767,427 695×443 · +614 ms 1352,717 113×153 · +623 ms 1379,744 86×126 · +658 ms 1415,818 51×52 · +669 ms 1416,827 50×43 · +695 ms 1416,834 50×36 · +704 ms off the screen
- ✘ **43 restore-safari** (clicks its miniature in the Dock): safari (w34) moved, and the step did not name it
  - +0 ms 1416,834 50×36 · +9 ms 1416,832 50×38 · +51 ms 1405,783 60×87 · +57 ms 1372,737 93×133 · +86 ms 1251,644 213×226 · +153 ms 629,371 833×499 · +167 ms 531,330 930×540 · +185 ms 368,254 1094×616 · +232 ms 163,102 1299×768 · +278 ms 138,33 1324×792 · +345 ms 138,31 1324×791

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **21 cmd-tab** (presses ⌘Tab): w122 of Mail opened in one place and was then moved to another
  - +0 ms 248,76 1104×622 · +28 ms 246,75 1108×624 · +35 ms 243,74 1114×626 · +64 ms 242,73 1116×628 · +121 ms 240,72 1120×630
- ✘ **21 cmd-tab** (presses ⌘Tab): w124 of Mail opened in one place and was then moved to another
  - +0 ms 565,164 470×416 · +18 ms 565,172 470×416 · +90 ms 565,178 470×416 · +169 ms 565,179 470×416
- ~ **25 drag-calendar-back** (drags calendar away from the top again, to the middle of the screen): calendar (w60) changed its size while it was being dragged
  - +0 ms 4,39 1600×791 · +36 ms 13,57 1600×791 · +88 ms 13,57 1550×777 · +93 ms 29,48 1550×777 · +146 ms 161,48 1237×686 · +222 ms 260,56 1015×622 · … 27 more … · +1846 ms 395,262 936×599 · +1949 ms 400,270 936×599 · +2010 ms 404,279 936×599 · +2327 ms 405,279 936×599 · +2444 ms 404,279 936×599
- ✘ **49 reopen-textedit** (opens the document again): textedit (w177) opened in one place and was then moved to another
  - +0 ms 171,68 644×416 · +6 ms 169,68 648×416 · +36 ms 168,67 667×435 · +42 ms 167,66 669×437 · +99 ms 165,65 673×439 · +104 ms 164,64 675×441 · +322 ms 165,65 673×439

### Rule 4: the window you switch to comes to the front and into view

- ~ **21 cmd-tab** (presses ⌘Tab): the window in front changed 3 times: preview (w67) → w122 of Mail → w124 of Mail → settings (w63)
- ✘ **25 drag-calendar-back** (drags calendar away from the top again, to the middle of the screen): calendar (w60) is not wholly in view: 91% of it, at 404,279 936×599 in 0,31 1600×791
- ✘ **31 dock-icon-calendar-2** (clicks calendar's icon in the Dock): calendar (w60) is not wholly in view: 91% of it, at 404,279 936×599 in 0,31 1600×791
- ✘ **38 window-menu** (chooses Safari's first window in the Window menu): safari (w34) is not in front: safari-new (w155) ahead of it, of which 1 cover part of it

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 525 ms; blind for 301 ms |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 0 ms; blind for 1706 ms |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (1, 0 ms) | quiet 914 ms; blind for 1395 ms |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×2 (6, 714 ms) | quiet 749 ms; blind for 333 ms |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (2, 9 ms), w55 ×2 (13, 1786 ms), w57 ×1 (5, 159 ms) | quiet 65 ms; blind for 172 ms |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (4, 318 ms) | quiet 1294 ms; blind for 324 ms |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 177 ms; blind for 513 ms |  |  |  |  |  |  |
| 8 | open-preview | opens preview |  | quiet 0 ms; blind for 1742 ms |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w73 ×1 (1, 0 ms) | quiet 126 ms; blind for 542 ms |  |  |  |  |  |  |
| 10 | look-around | looks at the screen |  | quiet 0 ms; blind for 126 ms | ✔ | ✔ |  |  | ✔ | ✔ |

### Arbor starts

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 11 | leave-alone | does nothing for five seconds |  | quiet 0 ms; blind for 141 ms | ✔ | ✔ |  |  | ✔ | ✔ |

### Switching between apps, nothing docked yet

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 12 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 333 ms; blind for 167 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 13 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 0 ms; blind for 111 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 14 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 364 ms; blind for 142 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 15 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 180 ms; blind for 86 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 16 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 445 ms; blind for 93 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 17 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 537 ms; blind for 158 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 18 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 500 ms; blind for 77 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 19 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 82 ms; blind for 97 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 20 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 0 ms; blind for 154 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 21 | cmd-tab | presses ⌘Tab | w122 ×1 (4, 93 ms), w124 ×1 (3, 151 ms) | quiet 423 ms; blind for 101 ms | ✔ | ✘ | ~ |  | ✔ | ✔ |
| 22 | cmd-tab-twice | holds ⌘ and presses Tab twice |  | quiet 485 ms; blind for 150 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |

### macOS's own tiling, which is on

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 23 | reach-calendar | clicks calendar's title bar, or its Dock icon if that is covered |  | quiet 424 ms; blind for 68 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 24 | drag-calendar-to-top | drags calendar by its title bar against the menu bar and lets go: macOS fills the screen with it | calendar ×1 (10, 346 ms) | quiet 1432 ms; blind for 98 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 25 | drag-calendar-back | drags calendar away from the top again, to the middle of the screen |  | quiet 1035 ms; blind for 72 ms | ✔ | ~ | ✘ | ✔ | ✔ | ✔ |

### Switching between apps, with an arrangement

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 26 | dock-icon-finder-2 | clicks finder's icon in the Dock |  | quiet 463 ms; blind for 127 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 27 | dock-icon-safari-2 | clicks safari's icon in the Dock |  | quiet 314 ms; blind for 75 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 28 | dock-icon-textedit-2 | clicks textedit's icon in the Dock |  | quiet 356 ms; blind for 76 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 29 | dock-icon-terminal-2 | clicks terminal's icon in the Dock |  | quiet 334 ms; blind for 81 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 30 | dock-icon-notes-2 | clicks notes's icon in the Dock |  | quiet 450 ms; blind for 177 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 31 | dock-icon-calendar-2 | clicks calendar's icon in the Dock |  | quiet 480 ms; blind for 116 ms | ✔ | ✔ | ✘ |  | ✔ | ✔ |
| 32 | dock-icon-settings-2 | clicks settings's icon in the Dock |  | quiet 504 ms; blind for 82 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 33 | dock-icon-preview-2 | clicks preview's icon in the Dock |  | quiet 327 ms; blind for 114 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 34 | dock-icon-mail-2 | clicks mail's icon in the Dock |  | quiet 527 ms; blind for 82 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 35 | cmd-tab-2 | presses ⌘Tab |  | quiet 440 ms; blind for 84 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |

### Windows come and go

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 36 | reach-safari | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 364 ms; blind for 135 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 37 | new-window | presses ⌘N in Safari |  | quiet 334 ms; blind for 735 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 38 | window-menu | chooses Safari's first window in the Window menu |  | quiet 0 ms; blind for 765 ms | ✔ | ✔ | ✘ |  | ✔ | ✔ |
| 39 | cmd-backtick | presses ⌘` for Safari's other window |  | quiet 703 ms; blind for 75 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 40 | close-window | presses ⌘W |  | quiet 799 ms; blind for 78 ms | ✔ | ✔ |  |  | ✔ | ✔ |
| 41 | reach-safari | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 335 ms; blind for 73 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 42 | minimize-safari | presses ⌘M | safari ×1 (10, 289 ms) | quiet 1276 ms; blind for 92 ms | ✘ | ✔ |  |  | ✔ | ✔ |
| 43 | restore-safari | clicks its miniature in the Dock | safari ×1 (10, 336 ms) | quiet 666 ms; blind for 72 ms | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 44 | reach-finder | clicks finder's title bar, or its Dock icon if that is covered |  | quiet 402 ms; blind for 138 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 45 | hide-finder | presses ⌘H |  | quiet 797 ms; blind for 77 ms | ✔ | ✔ |  |  | ✔ | ✔ |
| 46 | unhide-finder | clicks its icon in the Dock |  | quiet 425 ms; blind for 77 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 47 | reach-textedit | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 253 ms; blind for 184 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 48 | quit-textedit | presses ⌘Q in TextEdit |  | quiet 775 ms; blind for 147 ms | ✔ | ✔ |  |  | ✔ | ✔ |
| 49 | reopen-textedit | opens the document again | textedit ×1 (6, 316 ms) | quiet 563 ms; blind for 328 ms | ✔ | ✘ | ✔ |  | ✔ | ✔ |

### Full screen

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 50 | reach-safari | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 395 ms; blind for 164 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 51 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 258 ms |  | ✔ |  |  | ✔ | ✔ |
| 52 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 144 ms | ✔ | ✔ | ✔ |  | ✔ | ✔ |

### A click lands on the wallpaper

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 53 | click-wallpaper | clicks on the wallpaper: macOS sweeps every window aside | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w122 ×1 (1, 0 ms), w124 ×1 (1, 0 ms), textedit ×1 (1, 0 ms), w213 ×1 (1, 0 ms) | quiet 686 ms; blind for 114 ms |  | ✔ |  |  | ✔ | ✔ |
| 54 | click-wallpaper-again | clicks on the wallpaper again: macOS brings them back | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), w122 ×1 (1, 0 ms), w124 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 135 ms; blind for 61 ms | ✔ | ✔ |  |  | ✔ | ✔ |
