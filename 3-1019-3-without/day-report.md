56 steps in 262 s, 41 of them judged, 5 with a rule broken. The sampler: samples 8545 seconds 214.3 hz 39.9 cost-ms 2.85 late 25 longest-gap-ms 592 whole-samples 10499 whole-seconds 263.3 whole-late 42.
Input: 222 presses, releases, keys and scrolls reached the apps, half of them within 552 µs, 99 in 100 within 14038 µs, the latest after 145464 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 21, 754, 3066; dragged 165, 530, 3127; forward 5, 10985, 145464; key 5, 369, 513; up 26, 655, 6632. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 36582; up 8, 1242.
The round of input `after` (events, half within µs): .
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 5 | 0 |  |
| 2 | nothing moves that the person did not move | 34 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 44 | 5 | 18 display-plug, 20 display-plug, 23 display-unplug, 27 display-plug, 55 display-unplug |
| 4 | the window you switch to comes to the front and into view | 28 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 27 | 0 |  |
| L | no window is lost or stuck | 44 | 0 |  |
| - | what the script itself checked | 44 | 0 |  |

## Findings

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **18 display-plug** (the second display: plug): notes (w1022) went 486 points out of its way before it ended up [jolt]
  - +0 ms 456,208 1000×600 · +24 ms 2299,332 1000×600 · +239 ms 2056,208 1000×600
- ✘ **20 display-plug** (the second display: plug): notes (w1022) moved 2 times [jolt]
  - +0 ms 456,208 1000×600 · +23 ms -1067,142 1000×600 · +579 ms 1813,142 1000×600
- ✘ **23 display-unplug** (the second display: unplug): notes (w1022) went 10 points out of its way before it ended up [jolt]
  - +0 ms 1813,142 1000×600 · +7 ms 456,213 1000×600 · +231 ms 456,208 1000×600
- ✘ **27 display-plug** (the second display: plug): notes (w1022) went 486 points out of its way before it ended up [jolt]
  - +0 ms 456,208 1000×600 · +28 ms 2299,332 1000×600 · +206 ms 2056,208 1000×600
- ✘ **55 display-unplug** (the second display: unplug): calendar (w1025) went 88 points out of its way before it ended up [jolt]
  - +0 ms 2224,96 938×601 · +343 ms 420,59 938×601 · +462 ms 464,31 938×601

### Rule -: what the script itself checked

- ~ **10 tiling-acts** (without Arbor: drags a window by its title bar against the menu bar and lets go): the act was not performed: drag_window could not be done [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (2, 72 ms) | quiet 987 ms; blind for 108 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 461 ms; blind for 1385 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (2, 241 ms) | quiet 850 ms; blind for 485 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (4, 302 ms) | quiet 1145 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (4, 109 ms) | quiet 1019 ms; blind for 119 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (8, 364 ms) | quiet 1262 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (5, 255 ms) | quiet 711 ms; blind for 444 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (6, 90 ms) | quiet 1024 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w1034 ×1 (5, 209 ms) | quiet 805 ms; blind for 1448 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (11, 1021 ms) | quiet 1385 ms |  |  |  |  |  |  |  | ~ |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (33, 2229 ms) | quiet 993 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 386 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 756 ms; blind for 104 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | display-plug | the second display: plug | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms) | quiet 365 ms; blind for 372 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 15 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 420 ms; blind for 111 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 16 | carry-notes-across | drags notes, which floats, by its title bar onto the other display and lets go |  | quiet 989 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | display-unplug | the second display: unplug | notes ×1 (1, 0 ms) | quiet 442 ms; blind for 223 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 18 | display-plug | the second display: plug | notes ×1 (2, 215 ms) | quiet 376 ms; blind for 215 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 19 | display-unplug | the second display: unplug | notes ×1 (1, 0 ms) | quiet 377 ms; blind for 131 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 20 | display-plug | the second display: plug | notes ×2 (2, 556 ms) | quiet 369 ms; blind for 184 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 21 | click-wallpaper | clicks on the wallpaper | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1034 ×1 (1, 0 ms) | quiet 494 ms; blind for 140 ms |  |  | ✔ |  |  | ✔ | ✔ | ✔ |
| 22 | click-wallpaper-again | clicks on the wallpaper again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1034 ×1 (1, 0 ms) | quiet 352 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 23 | display-unplug | the second display: unplug | notes ×1 (2, 224 ms) | quiet 361 ms; blind for 223 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 24 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 486 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 491 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | hide-safari | presses ⌘H |  | quiet 796 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 27 | display-plug | the second display: plug | notes ×1 (2, 178 ms) | quiet 355 ms; blind for 177 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 28 | click-notes | clicks notes's title bar |  | quiet 442 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 29 | unhide-safari | clicks its icon in the Dock |  | quiet 403 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 361 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 372 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 32 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 379 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 33 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 436 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | drag-calendar-to-top-edge | drags calendar by its title bar against the top edge of the screen and lets go |  | quiet 1029 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | leave-alone | does nothing for half a minute |  | quiet 375 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 36 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 450 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 357 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | minimize-notes | presses ⌘M | notes ×1 (18, 468 ms) | quiet 1033 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 39 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 360 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 433 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | restore-notes | clicks notes's icon in the Dock, which brings its minimized window back | notes ×1 (17, 480 ms) | quiet 964 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | click-safari | clicks safari's title bar |  | quiet 372 ms; blind for 102 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | drag-terminal-to-top-edge | drags terminal by its title bar against the top edge of the screen and lets go | terminal ×1 (9, 287 ms) | quiet 1380 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 562 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | quit-textedit | presses ⌘Q in textedit |  | quiet 916 ms; blind for 102 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 46 | reopen-textedit | opens textedit's document again |  | quiet 679 ms; blind for 592 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 47 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 501 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | click-settings | clicks settings's title bar |  | quiet 407 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 389 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | carry-calendar-across | drags calendar, which floats, by its title bar onto the other display and lets go |  | quiet 1045 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 521 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | click-notes | clicks notes's title bar |  | quiet 542 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 53 | leave-alone | does nothing for half a minute |  | quiet 400 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 54 | drag-preview-to-top-edge | drags preview by its title bar against the top edge of the screen and lets go | preview ×1 (12, 291 ms) | quiet 1377 ms; blind for 154 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | display-unplug | the second display: unplug | terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (2, 119 ms), textedit ×1 (1, 0 ms) | quiet 361 ms; blind for 351 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 56 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 395 ms; blind for 100 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
