63 steps in 259 s, 48 of them judged, 22 with a rule broken. The sampler: samples 7001 seconds 187.0 hz 37.4 cost-ms 2.85 late 4 longest-gap-ms 177 whole-samples 9756 whole-seconds 260.6 whole-late 94.
Input: 78 presses, releases, keys and scrolls reached the apps, half of them within 759 µs, 99 in 100 within 234835 µs, the latest after 234835 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 6, 1753, 2430; dragged 66, 711, 4516; up 6, 1452, 234835. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): down 13, 649; dragged 20, 297; forward 12, 11123; key 13, 502; scroll 28, 252; up 25, 416.
The round of input `started` (events, half within µs): down 13, 637; dragged 20, 371; forward 12, 11762; key 13, 354; scroll 28, 319; up 25, 301.
The round of input `last` (events, half within µs): down 13, 659; dragged 20, 374; forward 12, 14248; key 12, 793; scroll 28, 325; up 25, 312.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 5 | 1 | 57 both-previews |
| 2 | nothing moves that the person did not move | 44 | 1 | 23 somebody-else |
| 3 | no jolts: a window moves once, to where it ends up | 48 | 8 | 21 moved-twice, 22 elsewhere-first, 25 flashes, 33 lands-elsewhere, 40 out-of-the-hand, 41 dropped-elsewhere, 43 answers-late, 52 under-no-stage |
| 4 | the window you switch to comes to the front and into view | 30 | 3 | 27 covered, 35 keyboard-taken, 37 comes-forward |
| 5 | quitting, Float All and pause give windows their own sizes back | 2 | 1 | 45 wrong-size |
| 6 | what a person presses reaches the apps, at once | 18 | 2 | 53 held-back, 55 input-last |
| L | no window is lost or stuck | 48 | 2 | 47 left-out, 49 vanishes |
| - | what the script itself checked | 48 | 4 | 59 busy-doing-nothing, 61 stays-behind, 62 ends-unasked, 63 tells |

## Findings

### Rule 1: never fight macOS: where it answers a drag, Arbor stands aside

- ✘ **57 both-previews** (OFFENCE: a window is dragged against the menu bar, and a drop preview comes up beside macOS's own): textedit (w46) macOS's tiling preview and Arbor's drop preview were up at the same time, for 766 ms [fought]

### Rule 2: nothing moves that the person did not move

- ✘ **23 somebody-else** (OFFENCE: a window that the step does not name is moved): finder (w32) moved, and the step did not name it [moved-unasked]
  - +0 ms 700,80 560×380 · +60 ms 720,120 560×380

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **21 moved-twice** (OFFENCE: a window is moved, and half a second later moved again): textedit (w46) moved 2 times [jolt]
  - +0 ms 60,60 600×420 · +70 ms 160,100 600×420 · +677 ms 220,100 600×420
- ✘ **22 elsewhere-first** (OFFENCE: a window goes somewhere else before it goes where it ends up): textedit (w46) went 960 points out of its way before it ended up [jolt]
  - +0 ms 220,100 600×420 · +43 ms 700,300 600×420 · +214 ms 100,100 600×420
- ✘ **25 flashes** (OFFENCE: a window that is out of view shows for a moment): preview (w67) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 708×320 · +72 ms 400,300 708×320 · +192 ms 1599,770 708×320
- ✘ **33 lands-elsewhere** (OFFENCE: it is shown again where it was, and a tenth of a second later it is somewhere else: one burst, a straight road): preview (w67) came into sight at 760,500 708×320 and was then moved to 460,500 708×320 [jolt]
  - +0 ms 760,500 708×320 · +141 ms 460,500 708×320
- ✘ **40 out-of-the-hand** (OFFENCE: while the button is down the dragged window is pulled away): textedit (w46) moved 401 points further than the pointer did, 3677 ms into the step [pulled]
  - +0 ms 167,120 600×420 · +31 ms 163,120 600×420 · +73 ms 159,120 600×420 · +896 ms 155,120 600×420 · +968 ms 107,120 600×420 · +1009 ms 96,111 600×420 · … 8 more … · +1608 ms 55,62 600×420 · +1682 ms 51,60 600×420 · +1889 ms 52,60 600×420 · +2449 ms 452,260 600×420 · +2877 ms 51,60 600×420
- ✘ **41 dropped-elsewhere** (OFFENCE: a window is dragged and let go, and goes somewhere else altogether): textedit (w46) ended neither where it was let go nor where the preview was: let go at 119,79 600×420, no preview, now at 539,339 600×420 [stuck]
  - +0 ms 119,79 600×420 · +1707 ms 539,339 600×420
- ✘ **43 answers-late** (OFFENCE: a key is pressed, and the window moves two seconds later): the last window came to rest 2306 ms after the key or the button [slow]
- ✘ **52 under-no-stage** (OFFENCE: the same under a panel that is wholly transparent, as Arbor's is when it rehearses its stage: everybody sees the window go about): textedit (w46) moved 2 times [jolt]
  - +0 ms 159,79 520×380 · +585 ms 459,279 520×380 · +1050 ms 119,79 520×380
- ~ **58 honest-drag-back** (drags it away from the top again): textedit (w46) changed its size while it was being dragged [jolt]
  - +0 ms 0,33 1600×793 · +7 ms 1,39 1600×793 · +63 ms 162,36 1275×669 · +98 ms 322,39 953×546 · +129 ms 426,39 746×467 · +149 ms 459,39 679×441 · … 27 more … · +1438 ms 539,109 521×381 · +1528 ms 540,112 521×381 · +1566 ms 540,115 521×381 · +1854 ms 541,115 521×381 · +1978 ms 540,115 521×381

### Rule 4: the window you switch to comes to the front and into view

- ✘ **27 covered** (OFFENCE: the window switched to is covered by another one at once): textedit (w46) is not in front: elm (w119) ahead of it, of which 1 cover part of it [behind]
- ✘ **35 keyboard-taken** (OFFENCE: after the switch another app, with no window to show, takes the keyboard): textedit (w46) its app is not the one in front (process 11481 is) [focus]
- ✘ **37 comes-forward** (OFFENCE: nobody does anything, and an app comes forward by itself): the app in front changed (to process 11481), and nobody switched [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **45 wrong-size** (OFFENCE: everything is given back, but one window keeps a size that is not its own): textedit (w46) is 119,79 640×460; its own size was 119,79 520×380 [size-lost]

### Rule 6: what a person presses reaches the apps, at once

- ✘ **53 held-back** (OFFENCE: the button comes up, and an event tap keeps that from the apps for a fifth of a second): the button came up, and the apps heard of it 234 ms later [input-held]
- ✘ **55 input-last** (a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text): 1 of 13 events of the kind key never reached the apps [input-held]

### Rule L: no window is lost or stuck

- ✘ **47 left-out** (OFFENCE: everything should be in view, and one window is in the corner): finder (w32) is out of view: 0% of it is on a display, at 1599,772 560×380 [lost]
- ✘ **49 vanishes** (OFFENCE: a window is closed, and nobody asked for that): elm (w119) left the screen, and the step did not say it would [lost]
  - +0 ms 140,500 520×300 · +393 ms off the screen

### Rule -: what the script itself checked

- ✘ **59 busy-doing-nothing** (OFFENCE: nobody does anything, and the process keeps a core busy): with nothing to do Arbor used 99.7 % of a core [busy]
- ✘ **61 stays-behind** (OFFENCE: it is asked to quit and does, but a second process of its stays): after Quit a process of Arbor's is still there: 24263 [left-behind]
- ✘ **61 stays-behind** (OFFENCE: it is asked to quit and does, but a second process of its stays): Arbor's process ended, and nobody asked it to [crash]
- ✘ **62 ends-unasked** (OFFENCE: nobody does anything, and the process ends): Arbor's process ended, and nobody asked it to [crash]
- ✘ **63 tells** (OFFENCE: a window's title is written into a log): a window's title is in what the run brings back: saboteur.log [told]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 621 ms; blind for 191 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 372 ms; blind for 5011 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (3, 278 ms) | quiet 1482 ms; blind for 1191 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal |  | quiet 478 ms; blind for 623 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (5, 106 ms), w55 ×2 (12, 1578 ms), w57 ×1 (11, 249 ms) | quiet 387 ms; blind for 357 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×2 (5, 417 ms) | quiet 1516 ms; blind for 145 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 1032 ms; blind for 693 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (2, 108 ms) | quiet 680 ms; blind for 187 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w73 ×1 (4, 321 ms) | quiet 687 ms; blind for 692 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (43, 4382 ms) | quiet 1377 ms; blind for 108 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (41, 2510 ms) | quiet 1028 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 369 ms |  |  |  |  |  |  |  |  |
| 13 | open-desks | opens the two windows that input is tried on | desk-a ×1 (3, 47 ms), desk-b ×1 (2, 64 ms) | quiet 382 ms; blind for 123 ms |  |  |  |  |  |  |  |  |
| 14 | input-before | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 940 ms; blind for 149 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The windows

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 15 | open-second | opens a second document in TextEdit | elm ×1 (4, 339 ms) | quiet 1358 ms |  |  |  |  |  |  |  |  |
| 16 | lay-out | hides the other apps and puts five windows side by side | finder ×1 (2, 37 ms), textedit ×1 (1, 0 ms), terminal ×1 (2, 64 ms), preview ×1 (1, 0 ms), elm ×1 (1, 0 ms) | quiet 359 ms |  |  |  |  |  |  |  |  |

### Honest steps and offences

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 17 | honest-switch | clicks TextEdit's icon in the Dock |  | quiet 408 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 18 | honest-click | clicks the first document's title bar |  | quiet 567 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | honest-move | a window is moved once, straight to where it ends up | textedit ×1 (1, 0 ms) | quiet 1050 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 20 | honest-resize | a window is given another size and another place, which takes two stages | textedit ×1 (1, 0 ms) | quiet 1044 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 21 | moved-twice | OFFENCE: a window is moved, and half a second later moved again | textedit ×2 (2, 607 ms) | quiet 1080 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 22 | elsewhere-first | OFFENCE: a window goes somewhere else before it goes where it ends up | textedit ×1 (2, 171 ms) | quiet 1010 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 23 | somebody-else | OFFENCE: a window that the step does not name is moved | finder ×1 (1, 0 ms) | quiet 1073 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 24 | honest-park | a window is sent out of view, to the corner | preview ×1 (1, 0 ms) | quiet 1041 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 25 | flashes | OFFENCE: a window that is out of view shows for a moment | preview ×1 (2, 120 ms) | quiet 1097 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 26 | honest-return | it comes back into view | preview ×1 (1, 0 ms) | quiet 1014 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 27 | covered | OFFENCE: the window switched to is covered by another one at once |  | quiet 1044 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 28 | honest-click-2 | clicks the first document's title bar |  | quiet 451 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 29 | honest-minimize | Terminal's window is minimized | terminal ×1 (12, 470 ms) | quiet 1598 ms; blind for 177 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 30 | honest-hide | Preview is hidden |  | quiet 1029 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 31 | honest-landing | it is shown again, and is where it was |  | quiet 999 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 32 | honest-hide-2 | Preview is hidden again |  | quiet 1092 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 33 | lands-elsewhere | OFFENCE: it is shown again where it was, and a tenth of a second later it is somewhere else: one burst, a straight road | preview ×1 (1, 0 ms) | quiet 1084 ms |  | ✔ | ✘ |  |  |  | ✔ | ✔ |
| 34 | honest-put-back | it is put back | preview ×1 (1, 0 ms) | quiet 1031 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 35 | keyboard-taken | OFFENCE: after the switch another app, with no window to show, takes the keyboard |  | quiet 362 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 36 | honest-click-3 | clicks the first document's title bar |  | quiet 400 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | comes-forward | OFFENCE: nobody does anything, and an app comes forward by itself |  | quiet 371 ms |  | ✔ | ✔ | ✘ |  |  | ✔ | ✔ |
| 38 | honest-click-4 | clicks the first document's title bar |  | quiet 354 ms; blind for 136 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | honest-drag | drags the first document a little way by its title bar |  | quiet 1052 ms | ✔ | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 40 | out-of-the-hand | OFFENCE: while the button is down the dragged window is pulled away |  | quiet 1052 ms | ✔ | ✔ | ✘ |  |  | ✔ | ✔ | ✔ |
| 41 | dropped-elsewhere | OFFENCE: a window is dragged and let go, and goes somewhere else altogether | textedit ×1 (1, 0 ms) | quiet 1011 ms | ✔ | ✔ | ✘ |  |  | ✔ | ✔ | ✔ |
| 42 | honest-move-2 | it is moved back to where the hand left it, which is its own place from now on | textedit ×1 (1, 0 ms) | quiet 1042 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 43 | answers-late | OFFENCE: a key is pressed, and the window moves two seconds later | textedit ×1 (1, 0 ms) | quiet 1086 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 44 | honest-idle | nobody does anything for three seconds |  | quiet 356 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 45 | wrong-size | OFFENCE: everything is given back, but one window keeps a size that is not its own | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1044 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 46 | honest-give-back | now it gets its own size and place back too | textedit ×1 (1, 0 ms) | quiet 1040 ms |  |  | ✔ |  | ✔ |  | ✔ | ✔ |
| 47 | left-out | OFFENCE: everything should be in view, and one window is in the corner | finder ×1 (1, 0 ms) | quiet 1017 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 48 | honest-return-2 | it comes back | finder ×1 (1, 0 ms) | quiet 1061 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 49 | vanishes | OFFENCE: a window is closed, and nobody asked for that |  | quiet 1287 ms |  | ✔ | ✔ | ✔ |  |  | ✘ | ✔ |

### What only Arbor's own process can do wrong

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 50 | honest-click-5 | clicks the first document's title bar, with something that passes for Arbor running |  | quiet 392 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | under-the-stage | a panel covers the whole display, as Arbor's stage does, and under it a window goes about before it ends up: nobody sees that | textedit ×1 (1, 0 ms) | quiet 851 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 52 | under-no-stage | OFFENCE: the same under a panel that is wholly transparent, as Arbor's is when it rehearses its stage: everybody sees the window go about | textedit ×2 (2, 465 ms) | quiet 752 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 53 | held-back | OFFENCE: the button comes up, and an event tap keeps that from the apps for a fifth of a second |  | quiet 551 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 54 | input-started | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 948 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | input-last | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 880 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 56 | honest-dock-icon | clicks TextEdit's icon in the Dock, and then the first document's title bar |  | quiet 431 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | both-previews | OFFENCE: a window is dragged against the menu bar, and a drop preview comes up beside macOS's own | textedit ×1 (14, 350 ms) | quiet 1371 ms | ✘ | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 58 | honest-drag-back | drags it away from the top again |  | quiet 1053 ms | ✔ | ✔ | ~ |  |  | ✔ | ✔ | ✔ |
| 59 | busy-doing-nothing | OFFENCE: nobody does anything, and the process keeps a core busy |  | quiet 360 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 60 | honest-idle-2 | nobody does anything, and neither does it |  | quiet 411 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 61 | stays-behind | OFFENCE: it is asked to quit and does, but a second process of its stays |  | quiet 394 ms |  | ✔ | ✔ |  |  |  | ✔ | ✘ |
| 62 | ends-unasked | OFFENCE: nobody does anything, and the process ends |  | quiet 382 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 63 | tells | OFFENCE: a window's title is written into a log |  | quiet 366 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
