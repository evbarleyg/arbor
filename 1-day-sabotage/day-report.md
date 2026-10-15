53 steps in 209 s, 37 of them judged, 20 with a rule broken. The sampler: samples 4259 seconds 124.0 hz 34.4 cost-ms 3.27 late 6 longest-gap-ms 587 whole-samples 7228 whole-seconds 210.4 whole-late 80.
Input: 194 presses, releases, keys and scrolls reached the apps, half of them within 533 µs, 99 in 100 within 56919 µs, the latest after 247610 µs.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 5 | 1 | 47 both-previews |
| 2 | nothing moves that the person did not move | 35 | 1 | 21 somebody-else |
| 3 | no jolts: a window moves once, to where it ends up | 39 | 7 | 19 moved-twice, 20 elsewhere-first, 23 flashes, 33 out-of-the-hand, 34 dropped-elsewhere, 36 answers-late, 45 under-no-stage |
| 4 | the window you switch to comes to the front and into view | 25 | 3 | 25 covered, 28 keyboard-taken, 30 comes-forward |
| 5 | quitting, Float All and pause give windows their own sizes back | 2 | 1 | 38 wrong-size |
| 6 | what a person presses reaches the apps, at once | 14 | 1 | 46 held-back |
| L | no window is lost or stuck | 39 | 2 | 40 left-out, 42 vanishes |
| - | what the script itself checked | 39 | 4 | 49 busy-doing-nothing, 51 stays-behind, 52 ends-unasked, 53 tells |

## Findings

### Rule 1: never fight macOS: where it answers a drag, Arbor stands aside

- ✘ **47 both-previews** (OFFENCE: a window is dragged against the menu bar, and a drop preview comes up beside macOS's own): textedit (w45) macOS's tiling preview and Arbor's drop preview were up at the same time [fought]

### Rule 2: nothing moves that the person did not move

- ✘ **21 somebody-else** (OFFENCE: a window that the step does not name is moved): finder (w31) moved, and the step did not name it [moved-unasked]
  - +0 ms 700,80 560×380 · +61 ms 720,120 560×380

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **19 moved-twice** (OFFENCE: a window is moved, and half a second later moved again): textedit (w45) moved 2 times [jolt]
  - +0 ms 60,60 600×420 · +96 ms 160,100 600×420 · +650 ms 220,100 600×420
- ✘ **20 elsewhere-first** (OFFENCE: a window goes somewhere else before it goes where it ends up): textedit (w45) went 960 points out of its way before it ended up [jolt]
  - +0 ms 220,100 600×420 · +75 ms 700,300 600×420 · +225 ms 100,100 600×420
- ✘ **23 flashes** (OFFENCE: a window that is out of view shows for a moment): preview (w67) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 708×320 · +57 ms 400,300 708×320 · +267 ms 1599,770 708×320
- ✘ **33 out-of-the-hand** (OFFENCE: while the button is down the dragged window is pulled away): textedit (w45) moved 400 points further than the pointer did, 4109 ms into the step [pulled]
  - +0 ms 167,120 600×420 · +22 ms 163,120 600×420 · +67 ms 159,120 600×420 · +1120 ms 155,120 600×420 · +1190 ms 107,120 600×420 · +1305 ms 95,98 600×420 · … 10 more … · +2033 ms 51,60 600×420 · +2317 ms 52,60 600×420 · +2424 ms 51,60 600×420 · +2867 ms 451,260 600×420 · +3267 ms 51,60 600×420
- ✘ **34 dropped-elsewhere** (OFFENCE: a window is dragged and let go, and goes somewhere else altogether): textedit (w45) ended neither where it was let go nor where the preview was: let go at 119,79 600×420, no preview, now at 539,339 600×420 [stuck]
  - +0 ms 119,79 600×420 · +1696 ms 539,339 600×420
- ✘ **36 answers-late** (OFFENCE: a key is pressed, and the window moves two seconds later): the last window came to rest 2287 ms after the key or the button [slow]
- ✘ **45 under-no-stage** (OFFENCE: the same under a panel that is wholly transparent, as Arbor's is when it rehearses its stage: everybody sees the window go about): textedit (w45) moved 2 times [jolt]
  - +0 ms 159,79 520×380 · +627 ms 459,279 520×380 · +1072 ms 119,79 520×380
- ~ **48 honest-drag-back** (drags it away from the top again): textedit (w45) changed its size while it was being dragged [jolt]
  - +0 ms 0,33 1600×791 · +125 ms 1,39 1566×778 · +128 ms 1,39 1419×722 · +197 ms 335,36 927×535 · +202 ms 391,36 815×493 · +263 ms 502,36 592×408 · … 23 more … · +1783 ms 539,109 521×381 · +1874 ms 540,112 521×381 · +1996 ms 540,115 521×381 · +2227 ms 541,115 521×381 · +2278 ms 540,115 521×381

### Rule 4: the window you switch to comes to the front and into view

- ✘ **25 covered** (OFFENCE: the window switched to is covered by another one at once): textedit (w45) is not in front: elm (w87) ahead of it, of which 1 cover part of it [behind]
- ✘ **28 keyboard-taken** (OFFENCE: after the switch another app, with no window to show, takes the keyboard): textedit (w45) its app is not the one in front (process 5440 is) [focus]
- ✘ **30 comes-forward** (OFFENCE: nobody does anything, and an app comes forward by itself): the app in front changed (to process 5440), and nobody switched [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **38 wrong-size** (OFFENCE: everything is given back, but one window keeps a size that is not its own): textedit (w45) is 119,79 640×460; its own size was 119,79 520×380 [size-lost]

### Rule 6: what a person presses reaches the apps, at once

- ✘ **46 held-back** (OFFENCE: the button comes up, and an event tap keeps that from the apps for a fifth of a second): the button came up, and the apps heard of it 247 ms later [input-held]

### Rule L: no window is lost or stuck

- ✘ **40 left-out** (OFFENCE: everything should be in view, and one window is in the corner): finder (w31) is out of view: 0% of it is on a display, at 1599,770 560×380 [lost]
- ✘ **42 vanishes** (OFFENCE: a window is closed, and nobody asked for that): elm (w87) left the screen, and the step did not say it would [lost]
  - +0 ms 140,500 520×300 · +439 ms off the screen

### Rule -: what the script itself checked

- ✘ **49 busy-doing-nothing** (OFFENCE: nobody does anything, and the process keeps a core busy): with nothing to do Arbor used 91.5 % of a core [busy]
- ✘ **51 stays-behind** (OFFENCE: it is asked to quit and does, but a second process of its stays): after Quit a process of Arbor's is still there: 15077 [left-behind]
- ✘ **52 ends-unasked** (OFFENCE: nobody does anything, and the process ends): Arbor's process ended, and nobody asked it to [crash]
- ✘ **53 tells** (OFFENCE: a window's title is written into a log): a window's title is in what the run brings back: saboteur.log [told]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (2, 67 ms) | quiet 705 ms; blind for 249 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 373 ms; blind for 1025 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (2, 149 ms) | quiet 1201 ms; blind for 497 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (5, 294 ms) | quiet 1070 ms; blind for 261 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (2, 56 ms), w55 ×2 (10, 1340 ms), w57 ×1 (9, 229 ms) | quiet 363 ms; blind for 132 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×2 (6, 413 ms) | quiet 1323 ms; blind for 208 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings |  | quiet 409 ms; blind for 923 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview |  | quiet 386 ms; blind for 2178 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w73 ×1 (1, 0 ms) | quiet 394 ms; blind for 1097 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (39, 4426 ms) | quiet 1390 ms; blind for 157 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (30, 3251 ms) | quiet 1071 ms; blind for 168 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 418 ms; blind for 114 ms |  |  |  |  |  |  |  |  |

### The windows

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 13 | open-second | opens a second document in TextEdit | elm ×1 (5, 340 ms) | quiet 1366 ms |  |  |  |  |  |  |  |  |
| 14 | lay-out | hides the other apps and puts five windows side by side | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), preview ×1 (1, 0 ms), elm ×1 (1, 0 ms) | quiet 350 ms; blind for 178 ms |  |  |  |  |  |  |  |  |

### Honest steps and offences

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 15 | honest-switch | clicks TextEdit's icon in the Dock |  | quiet 431 ms; blind for 114 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 16 | honest-click | clicks the first document's title bar |  | quiet 393 ms; blind for 149 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | honest-move | a window is moved once, straight to where it ends up | textedit ×1 (1, 0 ms) | quiet 1088 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 18 | honest-resize | a window is given another size and another place, which takes two stages | textedit ×1 (1, 0 ms) | quiet 1092 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 19 | moved-twice | OFFENCE: a window is moved, and half a second later moved again | textedit ×2 (2, 554 ms) | quiet 1032 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 20 | elsewhere-first | OFFENCE: a window goes somewhere else before it goes where it ends up | textedit ×1 (2, 150 ms) | quiet 1062 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 21 | somebody-else | OFFENCE: a window that the step does not name is moved | finder ×1 (1, 0 ms) | quiet 1069 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 22 | honest-park | a window is sent out of view, to the corner | preview ×1 (1, 0 ms) | quiet 1079 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 23 | flashes | OFFENCE: a window that is out of view shows for a moment | preview ×1 (2, 210 ms) | quiet 1008 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 24 | honest-return | it comes back into view | preview ×1 (1, 0 ms) | quiet 1017 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 25 | covered | OFFENCE: the window switched to is covered by another one at once |  | quiet 994 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 26 | honest-click-2 | clicks the first document's title bar |  | quiet 376 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | honest-minimize | Terminal's window is minimized | terminal ×1 (14, 483 ms) | quiet 1614 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 28 | keyboard-taken | OFFENCE: after the switch another app, with no window to show, takes the keyboard |  | quiet 388 ms; blind for 587 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 29 | honest-click-3 | clicks the first document's title bar |  | quiet 389 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | comes-forward | OFFENCE: nobody does anything, and an app comes forward by itself |  | quiet 376 ms; blind for 112 ms |  | ✔ | ✔ | ✘ |  |  | ✔ | ✔ |
| 31 | honest-click-4 | clicks the first document's title bar |  | quiet 411 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | honest-drag | drags the first document a little way by its title bar |  | quiet 1084 ms | ✔ | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 33 | out-of-the-hand | OFFENCE: while the button is down the dragged window is pulled away |  | quiet 1081 ms | ✔ | ✔ | ✘ |  |  | ✔ | ✔ | ✔ |
| 34 | dropped-elsewhere | OFFENCE: a window is dragged and let go, and goes somewhere else altogether | textedit ×1 (1, 0 ms) | quiet 1020 ms | ✔ | ✔ | ✘ |  |  | ✔ | ✔ | ✔ |
| 35 | honest-move-2 | it is moved back to where the hand left it, which is its own place from now on | textedit ×1 (1, 0 ms) | quiet 1042 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 36 | answers-late | OFFENCE: a key is pressed, and the window moves two seconds later | textedit ×1 (1, 0 ms) | quiet 1070 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 37 | honest-idle | nobody does anything for three seconds |  | quiet 369 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 38 | wrong-size | OFFENCE: everything is given back, but one window keeps a size that is not its own | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1039 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 39 | honest-give-back | now it gets its own size and place back too | textedit ×1 (1, 0 ms) | quiet 1077 ms |  |  | ✔ |  | ✔ |  | ✔ | ✔ |
| 40 | left-out | OFFENCE: everything should be in view, and one window is in the corner | finder ×1 (1, 0 ms) | quiet 1036 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 41 | honest-return-2 | it comes back | finder ×1 (1, 0 ms) | quiet 1036 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 42 | vanishes | OFFENCE: a window is closed, and nobody asked for that |  | quiet 1305 ms |  | ✔ | ✔ | ✔ |  |  | ✘ | ✔ |

### What only Arbor's own process can do wrong

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 43 | honest-click-5 | clicks the first document's title bar, with something that passes for Arbor running |  | quiet 459 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | under-the-stage | a panel covers the whole display, as Arbor's stage does, and under it a window goes about before it ends up: nobody sees that | textedit ×1 (1, 0 ms) | quiet 820 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 45 | under-no-stage | OFFENCE: the same under a panel that is wholly transparent, as Arbor's is when it rehearses its stage: everybody sees the window go about | textedit ×2 (2, 445 ms) | quiet 743 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 46 | held-back | OFFENCE: the button comes up, and an event tap keeps that from the apps for a fifth of a second |  | quiet 592 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 47 | both-previews | OFFENCE: a window is dragged against the menu bar, and a drop preview comes up beside macOS's own | textedit ×1 (8, 315 ms) | quiet 1417 ms; blind for 377 ms | ✘ | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 48 | honest-drag-back | drags it away from the top again |  | quiet 1064 ms | ✔ | ✔ | ~ |  |  | ✔ | ✔ | ✔ |
| 49 | busy-doing-nothing | OFFENCE: nobody does anything, and the process keeps a core busy |  | quiet 384 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 50 | honest-idle-2 | nobody does anything, and neither does it |  | quiet 428 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 51 | stays-behind | OFFENCE: it is asked to quit and does, but a second process of its stays |  | quiet 351 ms |  | ✔ | ✔ |  |  |  | ✔ | ✘ |
| 52 | ends-unasked | OFFENCE: nobody does anything, and the process ends |  | quiet 361 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 53 | tells | OFFENCE: a window's title is written into a log |  | quiet 375 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
