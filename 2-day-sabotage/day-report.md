59 steps in 277 s, 42 of them judged, 22 with a rule broken. The sampler: samples 8790 seconds 210.7 hz 41.7 cost-ms 1.92 late 3 longest-gap-ms 191 whole-samples 11613 whole-seconds 278.4 whole-late 14.
Input: 74 presses, releases, keys and scrolls reached the apps, half of them within 557 µs, 99 in 100 within 230148 µs, the latest after 230148 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 4, 3195, 3298; dragged 66, 542, 4767; up 4, 1372, 230148. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): down 13, 1137; dragged 20, 543; forward 12, 19281; key 13, 491; scroll 28, 289; up 25, 487.
The round of input `started` (events, half within µs): down 25, 990; dragged 20, 372; key 13, 278; scroll 28, 443; up 25, 485.
The round of input `last` (events, half within µs): down 25, 1558; dragged 20, 418; key 12, 910; scroll 28, 324; up 25, 367.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 5 | 1 | 53 both-previews |
| 2 | nothing moves that the person did not move | 38 | 1 | 25 somebody-else |
| 3 | no jolts: a window moves once, to where it ends up | 42 | 7 | 23 moved-twice, 24 elsewhere-first, 27 flashes, 37 out-of-the-hand, 38 dropped-elsewhere, 40 answers-late, 49 under-no-stage |
| 4 | the window you switch to comes to the front and into view | 28 | 5 | 29 covered, 32 keyboard-taken, 34 comes-forward, 51 input-started, 52 input-last |
| 5 | quitting, Float All and pause give windows their own sizes back | 2 | 1 | 42 wrong-size |
| 6 | what a person presses reaches the apps, at once | 17 | 2 | 50 held-back, 52 input-last |
| L | no window is lost or stuck | 42 | 2 | 44 left-out, 46 vanishes |
| - | what the script itself checked | 42 | 4 | 55 busy-doing-nothing, 57 stays-behind, 58 ends-unasked, 59 tells |

## Findings

### Rule 1: never fight macOS: where it answers a drag, Arbor stands aside

- ✘ **53 both-previews** (OFFENCE: a window is dragged against the menu bar, and a drop preview comes up beside macOS's own): textedit (w381) macOS's tiling preview and Arbor's drop preview were up at the same time [fought]

### Rule 2: nothing moves that the person did not move

- ✘ **25 somebody-else** (OFFENCE: a window that the step does not name is moved): finder (w367) moved, and the step did not name it [moved-unasked]
  - +0 ms 700,80 560×380 · +36 ms 720,120 560×380

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **23 moved-twice** (OFFENCE: a window is moved, and half a second later moved again): textedit (w381) moved 2 times [jolt]
  - +0 ms 60,60 600×420 · +57 ms 160,100 600×420 · +609 ms 220,100 600×420
- ✘ **24 elsewhere-first** (OFFENCE: a window goes somewhere else before it goes where it ends up): textedit (w381) went 960 points out of its way before it ended up [jolt]
  - +0 ms 220,100 600×420 · +40 ms 700,300 600×420 · +151 ms 100,100 600×420
- ✘ **27 flashes** (OFFENCE: a window that is out of view shows for a moment): preview (w393) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 708×320 · +73 ms 400,300 708×320 · +239 ms 1599,770 708×320
- ✘ **37 out-of-the-hand** (OFFENCE: while the button is down the dragged window is pulled away): textedit (w381) moved 401 points further than the pointer did, 3629 ms into the step [pulled]
  - +0 ms 167,120 600×420 · +49 ms 163,120 600×420 · +82 ms 159,120 600×420 · +959 ms 155,120 600×420 · +1063 ms 108,120 600×420 · +1183 ms 91,89 600×420 · … 8 more … · +1694 ms 55,62 600×420 · +1742 ms 51,60 600×420 · +2043 ms 52,60 600×420 · +2542 ms 452,260 600×420 · +2861 ms 51,60 600×420
- ✘ **38 dropped-elsewhere** (OFFENCE: a window is dragged and let go, and goes somewhere else altogether): textedit (w381) ended neither where it was let go nor where the preview was: let go at 119,79 600×420, no preview, now at 539,339 600×420 [stuck]
  - +0 ms 119,79 600×420 · +1471 ms 539,339 600×420
- ✘ **40 answers-late** (OFFENCE: a key is pressed, and the window moves two seconds later): the last window came to rest 2248 ms after the key or the button [slow]
- ✘ **49 under-no-stage** (OFFENCE: the same under a panel that is wholly transparent, as Arbor's is when it rehearses its stage: everybody sees the window go about): textedit (w381) moved 2 times [jolt]
  - +0 ms 159,79 520×380 · +611 ms 459,279 520×380 · +1032 ms 119,79 520×380
- ~ **54 honest-drag-back** (drags it away from the top again): textedit (w381) changed its size while it was being dragged [jolt]
  - +0 ms 0,33 1600×793 · +60 ms 1,39 1600×793 · +105 ms 1,39 1531×767 · +147 ms 1,39 1024×573 · +155 ms 287,36 1024×573 · +210 ms 444,36 710×453 · … 27 more … · +1667 ms 539,109 521×381 · +1711 ms 540,112 521×381 · +1769 ms 540,115 521×381 · +1949 ms 541,115 521×381 · +2009 ms 540,115 521×381

### Rule 4: the window you switch to comes to the front and into view

- ✘ **29 covered** (OFFENCE: the window switched to is covered by another one at once): textedit (w381) is not in front: elm (w447) ahead of it, of which 1 cover part of it [behind]
- ✘ **32 keyboard-taken** (OFFENCE: after the switch another app, with no window to show, takes the keyboard): textedit (w381) its app is not the one in front (process 40057 is) [focus]
- ✘ **34 comes-forward** (OFFENCE: nobody does anything, and an app comes forward by itself): the app in front changed (to process 40057), and nobody switched [focus]
- ✘ **51 input-started** (a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text): desk-a (w417) is not in front: textedit (w381) ahead of it, of which 1 cover part of it [behind]
- ✘ **51 input-started** (a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text): desk-a (w417) its app is not the one in front (process 39815 is) [focus]
- ✘ **52 input-last** (a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text): desk-a (w417) is not in front: textedit (w381) ahead of it, of which 1 cover part of it [behind]
- ✘ **52 input-last** (a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text): desk-a (w417) its app is not the one in front (process 39815 is) [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **42 wrong-size** (OFFENCE: everything is given back, but one window keeps a size that is not its own): textedit (w381) is 119,79 640×460; its own size was 119,79 520×380 [size-lost]

### Rule 6: what a person presses reaches the apps, at once

- ✘ **50 held-back** (OFFENCE: the button comes up, and an event tap keeps that from the apps for a fifth of a second): the button came up, and the apps heard of it 230 ms later [input-held]
- ✘ **52 input-last** (a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text): 1 of 13 events of the kind key never reached the apps [input-held]

### Rule L: no window is lost or stuck

- ✘ **44 left-out** (OFFENCE: everything should be in view, and one window is in the corner): finder (w367) is out of view: 0% of it is on a display, at 1599,772 560×380 [lost]
- ✘ **46 vanishes** (OFFENCE: a window is closed, and nobody asked for that): elm (w447) left the screen, and the step did not say it would [lost]
  - +0 ms 140,500 520×300 · +427 ms off the screen

### Rule -: what the script itself checked

- ✘ **55 busy-doing-nothing** (OFFENCE: nobody does anything, and the process keeps a core busy): with nothing to do Arbor used 100.2 % of a core [busy]
- ✘ **57 stays-behind** (OFFENCE: it is asked to quit and does, but a second process of its stays): after Quit a process of Arbor's is still there: 54029 [left-behind]
- ✘ **58 ends-unasked** (OFFENCE: nobody does anything, and the process ends): Arbor's process ended, and nobody asked it to [crash]
- ✘ **59 tells** (OFFENCE: a window's title is written into a log): a window's title is in what the run brings back: saboteur.log [told]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (4, 56 ms) | quiet 942 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 422 ms; blind for 1249 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (4, 338 ms) | quiet 1311 ms; blind for 248 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (4, 351 ms) | quiet 1298 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (2, 54 ms) | quiet 1063 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (5, 299 ms) | quiet 1333 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings |  | quiet 971 ms; blind for 684 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (3, 46 ms) | quiet 1053 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w396 ×1 (7, 222 ms) | quiet 845 ms; blind for 875 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×1 (28, 2097 ms) | quiet 1032 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (30, 3055 ms) | quiet 1010 ms |  |  |  |  |  |  |  |  |
| 12 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (32, 4474 ms) | quiet 1457 ms |  |  |  |  |  |  |  |  |
| 13 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (34, 2318 ms) | quiet 1029 ms |  |  |  |  |  |  |  |  |
| 14 | look-around | looks at the screen |  | quiet 416 ms |  |  |  |  |  |  |  |  |
| 15 | open-desks | opens the two windows that input is tried on | desk-a ×1 (2, 4 ms), desk-b ×1 (3, 80 ms) | quiet 413 ms |  |  |  |  |  |  |  |  |
| 16 | input-before | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 881 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The windows

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 17 | open-second | opens a second document in TextEdit | elm ×1 (4, 324 ms) | quiet 1408 ms |  |  |  |  |  |  |  |  |
| 18 | lay-out | hides the other apps and puts five windows side by side | finder ×1 (2, 6 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), preview ×1 (2, 33 ms), elm ×1 (2, 16 ms) | quiet 361 ms |  |  |  |  |  |  |  |  |

### Honest steps and offences

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 19 | honest-switch | clicks TextEdit's icon in the Dock |  | quiet 417 ms; blind for 104 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | honest-click | clicks the first document's title bar |  | quiet 469 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | honest-move | a window is moved once, straight to where it ends up | textedit ×1 (1, 0 ms) | quiet 1073 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 22 | honest-resize | a window is given another size and another place, which takes two stages | textedit ×1 (1, 0 ms) | quiet 1070 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 23 | moved-twice | OFFENCE: a window is moved, and half a second later moved again | textedit ×2 (2, 552 ms) | quiet 1037 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 24 | elsewhere-first | OFFENCE: a window goes somewhere else before it goes where it ends up | textedit ×1 (2, 111 ms) | quiet 1005 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 25 | somebody-else | OFFENCE: a window that the step does not name is moved | finder ×1 (1, 0 ms) | quiet 1030 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 26 | honest-park | a window is sent out of view, to the corner | preview ×1 (1, 0 ms) | quiet 1074 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 27 | flashes | OFFENCE: a window that is out of view shows for a moment | preview ×1 (2, 166 ms) | quiet 1052 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 28 | honest-return | it comes back into view | preview ×1 (1, 0 ms) | quiet 1008 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 29 | covered | OFFENCE: the window switched to is covered by another one at once |  | quiet 1064 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 30 | honest-click-2 | clicks the first document's title bar |  | quiet 355 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | honest-minimize | Terminal's window is minimized | terminal ×1 (15, 472 ms) | quiet 1738 ms; blind for 191 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 32 | keyboard-taken | OFFENCE: after the switch another app, with no window to show, takes the keyboard |  | quiet 365 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 33 | honest-click-3 | clicks the first document's title bar |  | quiet 363 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | comes-forward | OFFENCE: nobody does anything, and an app comes forward by itself |  | quiet 443 ms |  | ✔ | ✔ | ✘ |  |  | ✔ | ✔ |
| 35 | honest-click-4 | clicks the first document's title bar |  | quiet 426 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 36 | honest-drag | drags the first document a little way by its title bar |  | quiet 1033 ms | ✔ | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 37 | out-of-the-hand | OFFENCE: while the button is down the dragged window is pulled away |  | quiet 1039 ms | ✔ | ✔ | ✘ |  |  | ✔ | ✔ | ✔ |
| 38 | dropped-elsewhere | OFFENCE: a window is dragged and let go, and goes somewhere else altogether | textedit ×1 (1, 0 ms) | quiet 1096 ms | ✔ | ✔ | ✘ |  |  | ✔ | ✔ | ✔ |
| 39 | honest-move-2 | it is moved back to where the hand left it, which is its own place from now on | textedit ×1 (1, 0 ms) | quiet 1026 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 40 | answers-late | OFFENCE: a key is pressed, and the window moves two seconds later | textedit ×1 (1, 0 ms) | quiet 1026 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 41 | honest-idle | nobody does anything for three seconds |  | quiet 364 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 42 | wrong-size | OFFENCE: everything is given back, but one window keeps a size that is not its own | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1046 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 43 | honest-give-back | now it gets its own size and place back too | textedit ×1 (1, 0 ms) | quiet 1132 ms |  |  | ✔ |  | ✔ |  | ✔ | ✔ |
| 44 | left-out | OFFENCE: everything should be in view, and one window is in the corner | finder ×1 (1, 0 ms) | quiet 1063 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 45 | honest-return-2 | it comes back | finder ×1 (1, 0 ms) | quiet 1086 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 46 | vanishes | OFFENCE: a window is closed, and nobody asked for that |  | quiet 1316 ms |  | ✔ | ✔ | ✔ |  |  | ✘ | ✔ |

### What only Arbor's own process can do wrong

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 47 | honest-click-5 | clicks the first document's title bar, with something that passes for Arbor running |  | quiet 380 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | under-the-stage | a panel covers the whole display, as Arbor's stage does, and under it a window goes about before it ends up: nobody sees that | textedit ×1 (1, 0 ms) | quiet 748 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 49 | under-no-stage | OFFENCE: the same under a panel that is wholly transparent, as Arbor's is when it rehearses its stage: everybody sees the window go about | textedit ×2 (2, 421 ms) | quiet 833 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 50 | held-back | OFFENCE: the button comes up, and an event tap keeps that from the apps for a fifth of a second |  | quiet 562 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 51 | input-started | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 858 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 52 | input-last | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 803 ms |  | ✔ | ✔ | ✘ |  | ✘ | ✔ | ✔ |
| 53 | both-previews | OFFENCE: a window is dragged against the menu bar, and a drop preview comes up beside macOS's own | textedit ×1 (9, 285 ms) | quiet 1383 ms | ✘ | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 54 | honest-drag-back | drags it away from the top again | textedit ×1 (2, 37 ms) | quiet 1062 ms | ✔ | ✔ | ~ |  |  | ✔ | ✔ | ✔ |
| 55 | busy-doing-nothing | OFFENCE: nobody does anything, and the process keeps a core busy |  | quiet 354 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 56 | honest-idle-2 | nobody does anything, and neither does it |  | quiet 390 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 57 | stays-behind | OFFENCE: it is asked to quit and does, but a second process of its stays |  | quiet 398 ms |  | ✔ | ✔ |  |  |  | ✔ | ✘ |
| 58 | ends-unasked | OFFENCE: nobody does anything, and the process ends |  | quiet 377 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 59 | tells | OFFENCE: a window's title is written into a log |  | quiet 373 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
