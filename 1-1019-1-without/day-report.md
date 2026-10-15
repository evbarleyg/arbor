56 steps in 294 s, 37 of them judged, 2 with a rule broken. The sampler: samples 8118 seconds 226.8 hz 35.8 cost-ms 3.11 late 41 longest-gap-ms 771 whole-samples 10558 whole-seconds 294.9 whole-late 87.
Input: 187 presses, releases, keys and scrolls reached the apps, half of them within 527 µs, 99 in 100 within 86213 µs, the latest after 108648 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 23, 583, 2204; dragged 132, 527, 4775; forward 2, 86213, 86213; key 5, 377, 629; up 25, 509, 108648. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 36219; up 8, 371.
The round of input `after` (events, half within µs): .
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 4 | 0 |  |
| 2 | nothing moves that the person did not move | 33 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 43 | 1 | 55 display-unplug |
| 4 | the window you switch to comes to the front and into view | 27 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 26 | 1 | 21 click-wallpaper |
| L | no window is lost or stuck | 43 | 0 |  |
| - | what the script itself checked | 43 | 0 |  |

## Findings

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **55 display-unplug** (the second display: unplug): calendar (w60) moved 2 times [jolt]
  - +0 ms 2224,208 936×599 · +1 ms 421,130 936×599 · +772 ms 464,31 936×599

### Rule 6: what a person presses reaches the apps, at once

- ✘ **21 click-wallpaper** (clicks on the wallpaper): the button came up, and the apps heard of it 108 ms later [input-held]

### Rule -: what the script itself checked

- ~ **16 carry-notes-across** (drags notes, which floats, by its title bar onto the other display and lets go): the act was not performed: drag_window could not be done [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×2 (4, 358 ms) | quiet 949 ms; blind for 281 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 370 ms; blind for 826 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (1, 0 ms) | quiet 938 ms; blind for 502 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal |  | quiet 474 ms; blind for 479 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (3, 62 ms), w55 ×2 (14, 1193 ms), w57 ×1 (9, 233 ms) | quiet 439 ms; blind for 424 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (5, 334 ms) | quiet 1319 ms; blind for 118 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings |  | quiet 394 ms; blind for 824 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (2, 202 ms) | quiet 553 ms; blind for 1051 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w71 ×1 (3, 168 ms) | quiet 766 ms; blind for 1063 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (38, 4410 ms) | quiet 1463 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (38, 2312 ms) | quiet 1066 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 441 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 734 ms; blind for 123 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | display-plug | the second display: plug | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 369 ms; blind for 487 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 15 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 413 ms; blind for 163 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 16 | carry-notes-across | drags notes, which floats, by its title bar onto the other display and lets go |  | quiet 1012 ms |  |  |  |  |  |  |  | ~ |
| 17 | display-unplug | the second display: unplug |  | quiet 368 ms; blind for 372 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 18 | display-plug | the second display: plug |  | quiet 375 ms; blind for 222 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 19 | display-unplug | the second display: unplug |  | quiet 388 ms; blind for 250 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 20 | display-plug | the second display: plug |  | quiet 361 ms; blind for 158 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 21 | click-wallpaper | clicks on the wallpaper | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 383 ms; blind for 374 ms |  |  | ✔ |  |  | ✘ | ✔ | ✔ |
| 22 | click-wallpaper-again | clicks on the wallpaper again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 354 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 23 | display-unplug | the second display: unplug |  | quiet 411 ms; blind for 545 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 24 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 449 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 393 ms; blind for 164 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | hide-safari | presses ⌘H |  | quiet 819 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 27 | display-plug | the second display: plug |  | quiet 382 ms; blind for 249 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 28 | click-notes | clicks notes's title bar |  | quiet 424 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 29 | unhide-safari | clicks its icon in the Dock |  | quiet 417 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 370 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 427 ms; blind for 133 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 32 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 367 ms; blind for 108 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 33 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 428 ms; blind for 171 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | drag-calendar-to-top-edge | drags calendar by its title bar against the top edge of the screen and lets go |  | quiet 1071 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 35 | leave-alone | does nothing for half a minute |  | quiet 420 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 36 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 494 ms; blind for 157 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 350 ms; blind for 134 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | minimize-notes | presses ⌘M | notes ×1 (19, 423 ms) | quiet 970 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 39 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 403 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 373 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | restore-notes | clicks notes's icon in the Dock, which brings its minimized window back | notes ×1 (11, 407 ms) | quiet 691 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | click-safari | clicks safari's title bar |  | quiet 412 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 382 ms; blind for 104 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | drag-terminal-to-top-edge | drags terminal by its title bar against the top edge of the screen and lets go | terminal ×1 (7, 298 ms) | quiet 1378 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 366 ms; blind for 106 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 46 | quit-textedit | presses ⌘Q in textedit |  | quiet 687 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 47 | reopen-textedit | opens textedit's document again |  | quiet 1189 ms; blind for 326 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 48 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 369 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | click-settings | clicks settings's title bar |  | quiet 408 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 50 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 388 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | carry-calendar-across | drags calendar, which floats, by its title bar onto the other display and lets go |  | quiet 1087 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 383 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 53 | leave-alone | does nothing for half a minute |  | quiet 368 ms; blind for 212 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 54 | drag-preview-to-top-edge | drags preview by its title bar against the top edge of the screen and lets go | preview ×1 (9, 278 ms) | quiet 1402 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | display-unplug | the second display: unplug | terminal ×1 (1, 0 ms), calendar ×2 (2, 771 ms), textedit ×1 (1, 0 ms) | quiet 363 ms; blind for 771 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 56 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 371 ms; blind for 157 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
