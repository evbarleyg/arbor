49 steps in 232 s, 34 of them judged, 2 with a rule broken. The sampler: samples 6361 seconds 164.1 hz 38.8 cost-ms 2.34 late 13 longest-gap-ms 350 whole-samples 9045 whole-seconds 233.4 whole-late 35.
Input: 39 presses, releases, keys and scrolls reached the apps, half of them within 559 µs, 99 in 100 within 100866 µs, the latest after 100866 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 15, 740, 1918; key 9, 302, 1528; up 15, 559, 100866. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 56649; up 8, 974.
The round of input `started` (events, half within µs): forward 8, 40490; up 8, 2556.
The round of input `last` (events, half within µs): down 13, 2406; dragged 20, 441; forward 9, 42681; key 13, 315; scroll 28, 312; up 22, 529.
The round of input `after` (events, half within µs): down 13, 1910; dragged 20, 466; forward 9, 51013; key 13, 487; scroll 28, 315; up 22, 950.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 32 | 1 | 36 close-only-notes |
| 3 | no jolts: a window moves once, to where it ends up | 35 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 25 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 1 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 26 | 1 | 31 click-wallpaper |
| L | no window is lost or stuck | 35 | 0 |  |
| - | what the script itself checked | 35 | 0 |  |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **36 close-only-notes** (presses ⌘W on the only window of notes): finder (w142) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 920×436 · +795 ms 340,120 920×436
- ✘ **36 close-only-notes** (presses ⌘W on the only window of notes): textedit (w154) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,790 673×439 · +795 ms 165,65 673×439
- ✘ **36 close-only-notes** (presses ⌘W on the only window of notes): terminal (w159) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,790 877×499 · +795 ms 40,51 877×499
- ✘ **36 close-only-notes** (presses ⌘W on the only window of notes): calendar (w163) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 937×600 · +795 ms 403,115 937×600
- ✘ **36 close-only-notes** (presses ⌘W on the only window of notes): settings (w164) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 723×625 · +795 ms 437,85 723×625
- ✘ **36 close-only-notes** (presses ⌘W on the only window of notes): preview (w166) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 708×424 · +795 ms 4,35 708×424
- ✘ **36 close-only-notes** (presses ⌘W on the only window of notes): mail (w168) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 1120×630 · +795 ms 240,72 1120×630
- ~ **36 close-only-notes** (presses ⌘W on the only window of notes): w170 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 1924,877 470×416 · +795 ms 565,179 470×416

### Rule 6: what a person presses reaches the apps, at once

- ✘ **31 click-wallpaper** (clicks on the wallpaper): the button came up, and the apps heard of it 100 ms later [input-held]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (4, 104 ms) | quiet 1006 ms; blind for 109 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 478 ms; blind for 1016 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (3, 269 ms) | quiet 1306 ms; blind for 461 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×2 (8, 398 ms) | quiet 1208 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (3, 112 ms) | quiet 1065 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (6, 357 ms) | quiet 1292 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 704 ms; blind for 300 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (3, 85 ms) | quiet 978 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w170 ×1 (8, 180 ms) | quiet 598 ms; blind for 553 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×1 (27, 2180 ms) | quiet 1051 ms; blind for 136 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (29, 2294 ms) | quiet 998 ms |  |  |  |  |  |  |  |  |
| 12 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (32, 4100 ms) | quiet 1413 ms |  |  |  |  |  |  |  |  |
| 13 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (35, 2581 ms) | quiet 1048 ms; blind for 123 ms |  |  |  |  |  |  |  |  |
| 14 | look-around | looks at the screen |  | quiet 365 ms |  |  |  |  |  |  |  |  |
| 15 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 352 ms; blind for 350 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 16 | launch | starts Arbor |  | quiet 1015 ms; blind for 193 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 17 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 758 ms; blind for 107 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 18 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 362 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | dock-left | presses ⌃⌥⌘ and the left arrow | safari ×1 (1, 0 ms) | quiet 808 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 20 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 526 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | dock-right | presses ⌃⌥⌘ and the right arrow | safari ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 675 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 22 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 546 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 451 ms; blind for 101 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | minimize-notes | presses ⌘M | safari ×1 (1, 0 ms), notes ×1 (11, 305 ms) | quiet 1120 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 25 | restore-notes | clicks notes's icon in the Dock, which brings its minimized window back | safari ×1 (1, 0 ms), notes ×1 (9, 301 ms) | quiet 1021 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 544 ms; blind for 119 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 389 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | hide-safari | presses ⌘H | notes ×1 (2, 132 ms) | quiet 1027 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 29 | unhide-safari | clicks its icon in the Dock | notes ×1 (1, 0 ms) | quiet 363 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 434 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | click-wallpaper | clicks on the wallpaper | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w170 ×1 (1, 0 ms) | quiet 524 ms; blind for 153 ms |  |  | ✔ |  |  | ✘ | ✔ | ✔ |
| 32 | click-wallpaper-again | clicks on the wallpaper again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w170 ×1 (1, 0 ms) | quiet 376 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 33 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 359 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 498 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w170 ×1 (1, 0 ms) | quiet 1255 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 36 | close-only-notes | presses ⌘W on the only window of notes | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w170 ×1 (1, 0 ms) | quiet 1184 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 37 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 403 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 377 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | close-only-safari | presses ⌘W on the only window of safari |  | quiet 756 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 40 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 851 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | quit | chooses Quit Arbor in Arbor's menu |  | quiet 804 ms |  |  | ✔ |  | ✔ |  | ✔ | ✔ |
| 42 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 853 ms; blind for 104 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 378 ms; blind for 101 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 419 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 598 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 46 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 455 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 518 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 441 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 466 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
