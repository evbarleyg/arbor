71 steps in 301 s, 57 of them judged, 6 with a rule broken. The sampler: samples 10417 seconds 262.9 hz 39.6 cost-ms 2.30 late 31 longest-gap-ms 793 whole-samples 11982 whole-seconds 302.4 whole-late 45.
Input: 304 presses, releases, keys and scrolls reached the apps, half of them within 560 µs, 99 in 100 within 36577 µs, the latest after 57883 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 13, 555, 6195; dragged 231, 548, 3735; forward 19, 1533, 52935; key 9, 266, 339; up 32, 789, 57883. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 35115; up 8, 1052.
The round of input `after` (events, half within µs): forward 11, 33044; up 11, 283.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 7 | 0 |  |
| 2 | nothing moves that the person did not move | 44 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 59 | 4 | 20 display-plug, 33 drag-mail-to-right-edge, 53 display-plug, 64 display-unplug |
| 4 | the window you switch to comes to the front and into view | 38 | 2 | 38 cmd-tab-1, 46 dock-icon-terminal |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 33 | 0 |  |
| L | no window is lost or stuck | 59 | 0 |  |
| - | what the script itself checked | 59 | 0 |  |

## Findings

### Rule 2: nothing moves that the person did not move

- ~ **33 drag-mail-to-right-edge** (drags mail by its title bar against the right edge of the screen and lets go): w1286 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 805,299 470×416 · +989 ms 823,299 470×416 · +1022 ms 861,299 470×416 · +1044 ms 880,299 470×416 · +1128 ms 899,299 470×416 · +1180 ms 917,299 470×416 · … 25 more … · +4681 ms 1038,258 470×416 · +4706 ms 958,229 470×416 · +4738 ms 939,222 470×416 · +4780 ms 934,220 470×416 · +4830 ms 930,219 470×416

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **20 display-plug** (the second display: plug): terminal (w1272) went 132 points out of its way before it ended up [jolt]
  - +0 ms 803,31 863×499 · +123 ms 737,31 863×499 · +369 ms 803,31 863×499
- ✘ **33 drag-mail-to-right-edge** (drags mail by its title bar against the right edge of the screen and lets go): w1286 of Mail moved 3 times [jolt]
  - +0 ms 805,299 470×416 · +989 ms 823,299 470×416 · +1022 ms 861,299 470×416 · +1044 ms 880,299 470×416 · +1128 ms 899,299 470×416 · +1180 ms 917,299 470×416 · … 25 more … · +4681 ms 1038,258 470×416 · +4706 ms 958,229 470×416 · +4738 ms 939,222 470×416 · +4780 ms 934,220 470×416 · +4830 ms 930,219 470×416
- ✘ **53 display-plug** (the second display: plug): terminal (w1272) moved 2 times [jolt]
  - +0 ms 1165,398 863×499 · +140 ms 737,398 863×499 · +410 ms 1165,398 863×499
- ✘ **53 display-plug** (the second display: plug): calendar (w1276) moved 2 times [jolt]
  - +0 ms 691,109 909×791 · +140 ms -909,9 909×791 · +149 ms -909,31 909×769 · +410 ms 1971,31 909×769
- ✘ **53 display-plug** (the second display: plug): preview (w1281) moved 2 times [jolt]
  - +0 ms -63,81 708×424 · +140 ms 0,81 708×424 · +410 ms -63,81 708×424
- ✘ **53 display-plug** (the second display: plug): mail (w1284) moved 2 times [jolt]
  - +0 ms 1040,270 1120×630 · +140 ms 480,270 1120×630 · +410 ms 1040,270 1120×630
- ✘ **53 display-plug** (the second display: plug): w1286 of Mail moved 2 times [jolt]
  - +0 ms 1365,377 470×416 · +140 ms 805,377 470×416 · +410 ms 1365,377 470×416
- ~ **63 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): preview (w1281) changed its size while it was being dragged [jolt]
  - +0 ms -72,93 708×424 · +69 ms -80,105 708×424 · +125 ms -88,117 708×424 · +203 ms -96,129 708×424 · +224 ms -104,141 708×424 · +305 ms -112,153 708×424 · … 21 more … · +1941 ms -292,397 708×424 · +2066 ms -308,397 708×424 · +2331 ms -307,397 708×424 · +3890 ms -308,397 708×424 · +4001 ms -306,394 709×428
- ✘ **64 display-unplug** (the second display: unplug): calendar (w1276) went 1172 points out of its way before it ended up [jolt]
  - +0 ms 1971,31 909×769 · +1 ms 691,131 909×769 · +189 ms 1277,438 909×791

### Rule 4: the window you switch to comes to the front and into view

- ✘ **38 cmd-tab-1** (holds ⌘ and presses Tab 1 time(s)): w1286 of Mail is not wholly in view: 50% of it, at 1365,377 470×416 in 0,31 1600×791 [focus]
- ✘ **46 dock-icon-terminal** (clicks terminal's icon in the Dock): terminal (w1272) is not wholly in view: 92% of it, at 803,31 863×499 in 0,31 1600×791 [focus]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (3, 108 ms) | quiet 1130 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 362 ms; blind for 980 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (5, 329 ms) | quiet 1387 ms; blind for 129 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (2, 25 ms) | quiet 1054 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (3, 76 ms) | quiet 1067 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (5, 95 ms) | quiet 1159 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (2, 152 ms) | quiet 977 ms; blind for 163 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (4, 137 ms) | quiet 1137 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w1286 ×1 (5, 180 ms) | quiet 919 ms; blind for 485 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×4 (37, 3814 ms) | quiet 1347 ms; blind for 316 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (36, 2816 ms) | quiet 1047 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 427 ms; blind for 105 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 564 ms; blind for 121 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 435 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 15 | display-plug | the second display: plug | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 422 ms; blind for 284 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 16 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 437 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | display-unplug | the second display: unplug | terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 402 ms; blind for 108 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 18 | display-plug | the second display: plug | terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 361 ms; blind for 134 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 19 | display-unplug | the second display: unplug | terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 385 ms; blind for 103 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 20 | display-plug | the second display: plug | terminal ×1 (2, 246 ms), calendar ×1 (2, 246 ms) | quiet 353 ms; blind for 110 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 21 | click-terminal | clicks terminal's title bar |  | quiet 481 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 22 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 459 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | drag-notes-by | drags notes, which floats, by its title bar 126 across and 53 down |  | quiet 1060 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | click-settings | clicks settings's title bar |  | quiet 371 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 472 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | display-right | the second display: right |  | quiet 402 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 27 | leave-alone | does nothing for half a minute |  | quiet 390 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 28 | click-settings | clicks settings's title bar |  | quiet 416 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 29 | click-notes | clicks notes's title bar |  | quiet 417 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 379 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | new-window-finder | presses ⌘N in finder |  | quiet 1139 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 32 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 351 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | drag-mail-to-right-edge | drags mail by its title bar against the right edge of the screen and lets go | mail ×1 (7, 276 ms), w1286 ×3 (35, 3841 ms) | quiet 1398 ms | ✔ | ~ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | display-left | the second display: left | terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1286 ×1 (1, 0 ms) | quiet 353 ms; blind for 210 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 35 | click-new-window | clicks the title bar of the window that ⌘N opened |  | quiet 354 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 36 | close-window | presses ⌘W |  | quiet 1104 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 37 | display-unplug | the second display: unplug | terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1286 ×1 (1, 0 ms) | quiet 434 ms; blind for 145 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 38 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 458 ms |  | ✔ | ✔ | ✘ |  |  | ✔ | ✔ |
| 39 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 427 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 372 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 41 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 358 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 42 | leave-alone | does nothing for half a minute |  | quiet 364 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 43 | click-safari | clicks safari's title bar |  | quiet 366 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 359 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | drag-calendar-to-right-edge | drags calendar by its title bar against the right edge of the screen and lets go | calendar ×1 (7, 266 ms) | quiet 1408 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 46 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 406 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 47 | drag-terminal-to-right-edge | drags terminal by its title bar against the right edge of the screen and lets go | terminal ×1 (11, 290 ms) | quiet 1373 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 411 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | drag-preview-by | drags preview, which floats, by its title bar -112 across and 46 down, and clicks there 0.3 s after letting go |  | quiet 968 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | display-plug | the second display: plug | terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1286 ×1 (1, 0 ms) | quiet 378 ms; blind for 224 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 51 | drag-safari-by | drags safari, which floats, by its title bar -100 across and 91 down |  | quiet 1018 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | display-unplug | the second display: unplug | terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1286 ×1 (1, 0 ms) | quiet 362 ms; blind for 140 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 53 | display-plug | the second display: plug | terminal ×2 (2, 270 ms), calendar ×2 (3, 270 ms), preview ×2 (2, 270 ms), mail ×2 (2, 270 ms), w1286 ×2 (2, 270 ms) | quiet 396 ms; blind for 149 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 54 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 405 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | new-window-safari | presses ⌘N in safari |  | quiet 1045 ms; blind for 159 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 56 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 418 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | click-new-window | clicks the title bar of the window that ⌘N opened |  | quiet 407 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 58 | close-window | presses ⌘W |  | quiet 801 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 59 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 396 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | minimize-notes | presses ⌘M | notes ×1 (11, 282 ms) | quiet 1010 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 61 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 394 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 62 | restore-notes | clicks notes's icon in the Dock, which brings its minimized window back | notes ×1 (10, 227 ms) | quiet 596 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 63 | drag-preview-to-left-edge | drags preview by its title bar against the left edge of the screen and lets go | preview ×1 (11, 266 ms) | quiet 1358 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 64 | display-unplug | the second display: unplug | terminal ×1 (1, 0 ms), calendar ×1 (2, 188 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1286 ×1 (1, 0 ms) | quiet 375 ms; blind for 188 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 65 | display-plug | the second display: plug | terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1286 ×1 (1, 0 ms) | quiet 404 ms; blind for 200 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 66 | click-settings | clicks settings's title bar |  | quiet 419 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 67 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 430 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 68 | quit-safari | presses ⌘Q in safari |  | quiet 864 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 69 | reopen-safari | opens safari's document again |  | quiet 779 ms; blind for 793 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 70 | display-unplug | the second display: unplug | terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), mail ×1 (1, 0 ms), w1286 ×1 (1, 0 ms) | quiet 352 ms; blind for 148 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 71 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 577 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
