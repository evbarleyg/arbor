68 steps in 317 s, 49 of them judged, 4 with a rule broken. The sampler: samples 9406 seconds 261.3 hz 36.0 cost-ms 2.66 late 49 longest-gap-ms 1252 whole-samples 11442 whole-seconds 317.8 whole-late 73.
Input: 263 presses, releases, keys and scrolls reached the apps, half of them within 484 µs, 99 in 100 within 69370 µs, the latest after 109450 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 16, 607, 7355; dragged 198, 458, 8965; forward 12, 45846, 109450; key 9, 294, 565; up 28, 687, 87961. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 26119; up 8, 305.
The round of input `after` (events, half within µs): forward 7, 35862; up 7, 627.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 6 | 0 |  |
| 2 | nothing moves that the person did not move | 41 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 56 | 4 | 32 drag-mail-to-right-edge, 47 display-plug, 49 display-unplug, 50 display-plug |
| 4 | the window you switch to comes to the front and into view | 35 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 30 | 0 |  |
| L | no window is lost or stuck | 56 | 0 |  |
| - | what the script itself checked | 56 | 0 |  |

## Findings

### Rule 2: nothing moves that the person did not move

- ~ **32 drag-mail-to-right-edge** (drags mail by its title bar against the right edge of the screen and lets go): w66 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +800 ms 593,191 470×416 · +859 ms 621,203 470×416 · +954 ms 649,215 470×416 · +961 ms 677,227 470×416 · +1079 ms 705,240 470×416 · … 25 more … · +5028 ms 1360,366 470×416 · +5151 ms 1098,277 470×416 · +5201 ms 956,230 470×416 · +5298 ms 929,220 470×416 · +5322 ms 925,219 470×416

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **32 drag-mail-to-right-edge** (drags mail by its title bar against the right edge of the screen and lets go): w66 of Mail moved 3 times [jolt]
  - +0 ms 565,179 470×416 · +800 ms 593,191 470×416 · +859 ms 621,203 470×416 · +954 ms 649,215 470×416 · +961 ms 677,227 470×416 · +1079 ms 705,240 470×416 · … 25 more … · +5028 ms 1360,366 470×416 · +5151 ms 1098,277 470×416 · +5201 ms 956,230 470×416 · +5298 ms 929,220 470×416 · +5322 ms 925,219 470×416
- ✘ **47 display-plug** (the second display: plug): mail (w64) moved 2 times [jolt]
  - +0 ms 718,31 882×791 · +202 ms 1069,270 1120×630 · +1142 ms 2462,31 1058×1049
- ✘ **47 display-plug** (the second display: plug): w66 of Mail moved 2 times [jolt]
  - +0 ms 924,218 470×416 · +202 ms 1394,377 470×416 · +1142 ms 2756,347 470×416
- ✘ **49 display-unplug** (the second display: unplug): mail (w64) went 1054 points out of its way before it ended up [jolt]
  - +0 ms 2462,31 1058×1049 · +147 ms 542,-149 1058×1049 · +311 ms 1069,270 1120×630
- ~ **49 display-unplug** (the second display: unplug): w66 of Mail went 1116 points out of its way before it ended up [jolt]
  - +0 ms 2756,347 470×416 · +147 ms 836,167 470×416 · +311 ms 1394,377 470×416
- ✘ **50 display-plug** (the second display: plug): mail (w64) moved 2 times [jolt]
  - +0 ms 1069,270 1120×630 · +167 ms -531,170 1120×630 · +199 ms 1069,270 1120×630 · +606 ms 480,270 1120×630
- ✘ **50 display-plug** (the second display: plug): w66 of Mail moved 2 times [jolt]
  - +0 ms 1394,377 470×416 · +167 ms -206,277 470×416 · +199 ms 1394,377 470×416 · +606 ms 805,377 470×416

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 816 ms; blind for 192 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 399 ms; blind for 1347 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×2 (3, 328 ms) | quiet 1324 ms; blind for 374 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (5, 393 ms) | quiet 1212 ms; blind for 178 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (2, 58 ms), w54 ×2 (8, 857 ms), w56 ×1 (7, 252 ms) | quiet 369 ms; blind for 163 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (3, 283 ms) | quiet 1325 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×2 (2, 476 ms) | quiet 835 ms; blind for 464 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (2, 61 ms) | quiet 885 ms; blind for 124 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | mail ×1 (2, 70 ms), w66 ×1 (5, 221 ms) | quiet 847 ms; blind for 2146 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (44, 4361 ms) | quiet 1390 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (31, 2122 ms) | quiet 1028 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 354 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 771 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 379 ms; blind for 132 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 15 | display-plug | the second display: plug | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 385 ms; blind for 989 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 16 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 526 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | display-unplug | the second display: unplug |  | quiet 356 ms; blind for 185 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 18 | display-plug | the second display: plug |  | quiet 352 ms; blind for 148 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 19 | display-unplug | the second display: unplug |  | quiet 353 ms; blind for 133 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 20 | display-plug | the second display: plug |  | quiet 355 ms; blind for 126 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 21 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 381 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 22 | drag-notes-by | drags notes, which floats, by its title bar 126 across and 53 down |  | quiet 1070 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | click-settings | clicks settings's title bar |  | quiet 375 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 405 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | display-right | the second display: right |  | quiet 351 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 26 | leave-alone | does nothing for half a minute |  | quiet 369 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 27 | click-settings | clicks settings's title bar |  | quiet 465 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | click-notes | clicks notes's title bar |  | quiet 351 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 29 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 378 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | new-window-finder | presses ⌘N in finder |  | quiet 1124 ms; blind for 146 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 31 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 377 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | drag-mail-to-right-edge | drags mail by its title bar against the right edge of the screen and lets go | mail ×1 (5, 294 ms), w66 ×3 (35, 4522 ms) | quiet 1384 ms; blind for 106 ms | ✔ | ~ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | display-left | the second display: left | mail ×1 (1, 0 ms), w66 ×1 (1, 0 ms) | quiet 437 ms; blind for 196 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 34 | click-new-window | clicks the title bar of the window that ⌘N opened |  | quiet 363 ms; blind for 170 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | close-window | presses ⌘W |  | quiet 1132 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 36 | display-unplug | the second display: unplug |  | quiet 351 ms; blind for 244 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 37 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 487 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 38 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 430 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 436 ms; blind for 127 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 40 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 389 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 41 | leave-alone | does nothing for half a minute |  | quiet 362 ms; blind for 298 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 42 | click-safari | clicks safari's title bar |  | quiet 365 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 394 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | drag-calendar-to-right-edge | drags calendar by its title bar against the right edge of the screen and lets go | calendar ×1 (9, 287 ms) | quiet 1407 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 385 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 46 | drag-terminal-to-right-edge | drags terminal by its title bar against the right edge of the screen and lets go | terminal ×1 (11, 294 ms) | quiet 1346 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | display-plug | the second display: plug | terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), mail ×2 (2, 940 ms), w66 ×2 (2, 940 ms) | quiet 358 ms; blind for 323 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 48 | drag-safari-by | drags safari, which floats, by its title bar -100 across and 91 down |  | quiet 1025 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | display-unplug | the second display: unplug | calendar ×1 (1, 0 ms), mail ×1 (2, 164 ms), w66 ×1 (2, 164 ms) | quiet 364 ms; blind for 184 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 50 | display-plug | the second display: plug | calendar ×1 (1, 0 ms), mail ×2 (3, 439 ms), w66 ×2 (3, 439 ms) | quiet 367 ms; blind for 156 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 51 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 394 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | new-window-safari | presses ⌘N in safari |  | quiet 412 ms; blind for 870 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 53 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 387 ms; blind for 120 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 54 | click-new-window | clicks the title bar of the window that ⌘N opened |  | quiet 406 ms; blind for 168 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | close-window | presses ⌘W |  | quiet 793 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 56 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 434 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | minimize-notes | presses ⌘M | notes ×1 (19, 448 ms) | quiet 963 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 58 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 527 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 59 | restore-notes | clicks notes's icon in the Dock, which brings its minimized window back | notes ×1 (16, 500 ms) | quiet 1048 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | drag-preview-to-left-edge | drags preview by its title bar against the left edge of the screen and lets go | preview ×1 (7, 296 ms) | quiet 1410 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | display-unplug | the second display: unplug | calendar ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w66 ×1 (1, 0 ms) | quiet 416 ms; blind for 219 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 62 | display-plug | the second display: plug | calendar ×1 (1, 0 ms), mail ×1 (1, 0 ms), w66 ×1 (1, 0 ms) | quiet 395 ms; blind for 134 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 63 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 464 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 64 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 392 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 65 | quit-safari | presses ⌘Q in safari |  | quiet 942 ms; blind for 262 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 66 | reopen-safari | opens safari's document again |  | quiet 397 ms; blind for 515 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 67 | display-unplug | the second display: unplug | calendar ×1 (1, 0 ms), mail ×1 (1, 0 ms), w66 ×1 (1, 0 ms) | quiet 397 ms; blind for 1252 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 68 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 562 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
