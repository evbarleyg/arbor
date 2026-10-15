56 steps in 254 s, 41 of them judged, 21 with a rule broken. The sampler: samples 7136 seconds 190.3 hz 37.5 cost-ms 2.45 late 6 longest-gap-ms 362 whole-samples 9561 whole-seconds 255.0 whole-late 70.
Input: 74 presses, releases, keys and scrolls reached the apps, half of them within 523 µs, 99 in 100 within 253508 µs, the latest after 253508 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 4, 2688, 6125; dragged 66, 502, 6286; up 4, 1428, 253508. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 26161; up 8, 371.
The round of input `started` (events, half within µs): down 13, 1072; dragged 20, 380; forward 9, 5316; key 13, 333; scroll 28, 314; up 22, 349.
The round of input `last` (events, half within µs): down 13, 647; dragged 20, 370; forward 9, 3715; key 12, 490; scroll 28, 244; up 22, 353.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 5 | 1 | 50 both-previews |
| 2 | nothing moves that the person did not move | 38 | 1 | 22 somebody-else |
| 3 | no jolts: a window moves once, to where it ends up | 42 | 7 | 20 moved-twice, 21 elsewhere-first, 24 flashes, 34 out-of-the-hand, 35 dropped-elsewhere, 37 answers-late, 46 under-no-stage |
| 4 | the window you switch to comes to the front and into view | 27 | 3 | 26 covered, 29 keyboard-taken, 31 comes-forward |
| 5 | quitting, Float All and pause give windows their own sizes back | 2 | 1 | 39 wrong-size |
| 6 | what a person presses reaches the apps, at once | 17 | 2 | 47 held-back, 49 input-last |
| L | no window is lost or stuck | 42 | 2 | 41 left-out, 43 vanishes |
| - | what the script itself checked | 42 | 4 | 52 busy-doing-nothing, 54 stays-behind, 55 ends-unasked, 56 tells |

## Findings

### Rule 1: never fight macOS: where it answers a drag, Arbor stands aside

- ✘ **50 both-previews** (OFFENCE: a window is dragged against the menu bar, and a drop preview comes up beside macOS's own): textedit (w45) macOS's tiling preview and Arbor's drop preview were up at the same time [fought]

### Rule 2: nothing moves that the person did not move

- ✘ **22 somebody-else** (OFFENCE: a window that the step does not name is moved): finder (w31) moved, and the step did not name it [moved-unasked]
  - +0 ms 700,80 560×380 · +38 ms 720,120 560×380

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **20 moved-twice** (OFFENCE: a window is moved, and half a second later moved again): textedit (w45) moved 2 times [jolt]
  - +0 ms 60,60 600×420 · +62 ms 160,100 600×420 · +651 ms 220,100 600×420
- ✘ **21 elsewhere-first** (OFFENCE: a window goes somewhere else before it goes where it ends up): textedit (w45) went 960 points out of its way before it ended up [jolt]
  - +0 ms 220,100 600×420 · +51 ms 700,300 600×420 · +264 ms 100,100 600×420
- ✘ **24 flashes** (OFFENCE: a window that is out of view shows for a moment): preview (w64) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 708×320 · +95 ms 400,300 708×320 · +258 ms 1599,770 708×320
- ✘ **34 out-of-the-hand** (OFFENCE: while the button is down the dragged window is pulled away): textedit (w45) moved 401 points further than the pointer did, 3547 ms into the step [pulled]
  - +0 ms 163,120 600×420 · +92 ms 159,120 600×420 · +851 ms 137,120 600×420 · +883 ms 128,120 600×420 · +965 ms 92,120 600×420 · +1034 ms 87,97 600×420 · … 7 more … · +1617 ms 55,62 600×420 · +1708 ms 51,60 600×420 · +1917 ms 52,60 600×420 · +2409 ms 452,260 600×420 · +2807 ms 51,60 600×420
- ✘ **35 dropped-elsewhere** (OFFENCE: a window is dragged and let go, and goes somewhere else altogether): textedit (w45) ended neither where it was let go nor where the preview was: let go at 119,79 600×420, no preview, now at 539,339 600×420 [stuck]
  - +0 ms 119,79 600×420 · +1849 ms 539,339 600×420
- ✘ **37 answers-late** (OFFENCE: a key is pressed, and the window moves two seconds later): the last window came to rest 2355 ms after the key or the button [slow]
- ✘ **46 under-no-stage** (OFFENCE: the same under a panel that is wholly transparent, as Arbor's is when it rehearses its stage: everybody sees the window go about): textedit (w45) moved 2 times [jolt]
  - +0 ms 159,79 520×380 · +676 ms 459,279 520×380 · +1175 ms 119,79 520×380
- ~ **51 honest-drag-back** (drags it away from the top again): textedit (w45) changed its size while it was being dragged [jolt]
  - +0 ms 0,33 1600×791 · +31 ms 1,39 1600×791 · +52 ms 1,39 1554×774 · +70 ms 1,39 1399×715 · +127 ms 397,39 804×488 · +189 ms 489,39 619×418 · … 26 more … · +1499 ms 539,106 521×381 · +1616 ms 540,112 521×381 · +1733 ms 540,115 521×381 · +1941 ms 541,115 521×381 · +2024 ms 540,115 521×381

### Rule 4: the window you switch to comes to the front and into view

- ✘ **26 covered** (OFFENCE: the window switched to is covered by another one at once): textedit (w45) is not in front: elm (w94) ahead of it, of which 1 cover part of it [behind]
- ✘ **29 keyboard-taken** (OFFENCE: after the switch another app, with no window to show, takes the keyboard): textedit (w45) its app is not the one in front (process 6802 is) [focus]
- ✘ **31 comes-forward** (OFFENCE: nobody does anything, and an app comes forward by itself): the app in front changed (to process 6802), and nobody switched [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **39 wrong-size** (OFFENCE: everything is given back, but one window keeps a size that is not its own): textedit (w45) is 119,79 640×460; its own size was 119,79 520×380 [size-lost]

### Rule 6: what a person presses reaches the apps, at once

- ✘ **47 held-back** (OFFENCE: the button comes up, and an event tap keeps that from the apps for a fifth of a second): the button came up, and the apps heard of it 253 ms later [input-held]
- ✘ **49 input-last** (a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window): 1 of 13 events of the kind key never reached the apps [input-held]

### Rule L: no window is lost or stuck

- ✘ **41 left-out** (OFFENCE: everything should be in view, and one window is in the corner): finder (w31) is out of view: 0% of it is on a display, at 1599,770 560×380 [lost]
- ✘ **43 vanishes** (OFFENCE: a window is closed, and nobody asked for that): elm (w94) left the screen, and the step did not say it would [lost]
  - +0 ms 140,500 520×300 · +391 ms off the screen

### Rule -: what the script itself checked

- ✘ **52 busy-doing-nothing** (OFFENCE: nobody does anything, and the process keeps a core busy): with nothing to do Arbor used 100.5 % of a core [busy]
- ✘ **54 stays-behind** (OFFENCE: it is asked to quit and does, but a second process of its stays): after Quit a process of Arbor's is still there: 20174 [left-behind]
- ✘ **55 ends-unasked** (OFFENCE: nobody does anything, and the process ends): Arbor's process ended, and nobody asked it to [crash]
- ✘ **56 tells** (OFFENCE: a window's title is written into a log): a window's title is in what the run brings back: saboteur.log [told]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 685 ms; blind for 282 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 641 ms; blind for 2418 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (5, 295 ms) | quiet 2006 ms; blind for 868 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (3, 285 ms) | quiet 1061 ms; blind for 245 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (2, 72 ms), w54 ×2 (10, 1016 ms), w56 ×1 (7, 238 ms) | quiet 415 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (3, 341 ms) | quiet 1352 ms; blind for 134 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 532 ms; blind for 379 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview |  | quiet 741 ms; blind for 642 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w70 ×1 (2, 96 ms) | quiet 473 ms; blind for 967 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (43, 4387 ms) | quiet 1404 ms; blind for 149 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (37, 2491 ms) | quiet 1026 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 373 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 795 ms; blind for 133 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The windows

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | open-second | opens a second document in TextEdit | elm ×1 (4, 335 ms) | quiet 1428 ms |  |  |  |  |  |  |  |  |
| 15 | lay-out | hides the other apps and puts five windows side by side | finder ×1 (2, 34 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), preview ×1 (2, 31 ms), elm ×1 (1, 0 ms) | quiet 370 ms |  |  |  |  |  |  |  |  |

### Honest steps and offences

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 16 | honest-switch | clicks TextEdit's icon in the Dock |  | quiet 350 ms; blind for 116 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | honest-click | clicks the first document's title bar |  | quiet 390 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 18 | honest-move | a window is moved once, straight to where it ends up | textedit ×1 (1, 0 ms) | quiet 1074 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 19 | honest-resize | a window is given another size and another place, which takes two stages | textedit ×1 (1, 0 ms) | quiet 1097 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 20 | moved-twice | OFFENCE: a window is moved, and half a second later moved again | textedit ×2 (2, 589 ms) | quiet 1069 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 21 | elsewhere-first | OFFENCE: a window goes somewhere else before it goes where it ends up | textedit ×1 (2, 213 ms) | quiet 1036 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 22 | somebody-else | OFFENCE: a window that the step does not name is moved | finder ×1 (1, 0 ms) | quiet 1056 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 23 | honest-park | a window is sent out of view, to the corner | preview ×1 (1, 0 ms) | quiet 1029 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 24 | flashes | OFFENCE: a window that is out of view shows for a moment | preview ×1 (2, 163 ms) | quiet 1019 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 25 | honest-return | it comes back into view | preview ×1 (1, 0 ms) | quiet 1081 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 26 | covered | OFFENCE: the window switched to is covered by another one at once |  | quiet 1069 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 27 | honest-click-2 | clicks the first document's title bar |  | quiet 457 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 28 | honest-minimize | Terminal's window is minimized | terminal ×1 (20, 485 ms) | quiet 1648 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 29 | keyboard-taken | OFFENCE: after the switch another app, with no window to show, takes the keyboard |  | quiet 438 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 30 | honest-click-3 | clicks the first document's title bar |  | quiet 481 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | comes-forward | OFFENCE: nobody does anything, and an app comes forward by itself |  | quiet 367 ms |  | ✔ | ✔ | ✘ |  |  | ✔ | ✔ |
| 32 | honest-click-4 | clicks the first document's title bar |  | quiet 396 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 33 | honest-drag | drags the first document a little way by its title bar |  | quiet 1082 ms | ✔ | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 34 | out-of-the-hand | OFFENCE: while the button is down the dragged window is pulled away |  | quiet 1010 ms | ✔ | ✔ | ✘ |  |  | ✔ | ✔ | ✔ |
| 35 | dropped-elsewhere | OFFENCE: a window is dragged and let go, and goes somewhere else altogether | textedit ×1 (1, 0 ms) | quiet 1103 ms | ✔ | ✔ | ✘ |  |  | ✔ | ✔ | ✔ |
| 36 | honest-move-2 | it is moved back to where the hand left it, which is its own place from now on | textedit ×1 (1, 0 ms) | quiet 1081 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 37 | answers-late | OFFENCE: a key is pressed, and the window moves two seconds later | textedit ×1 (1, 0 ms) | quiet 1031 ms; blind for 362 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 38 | honest-idle | nobody does anything for three seconds |  | quiet 352 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 39 | wrong-size | OFFENCE: everything is given back, but one window keeps a size that is not its own | finder ×1 (1, 0 ms), textedit ×1 (2, 6 ms) | quiet 1024 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 40 | honest-give-back | now it gets its own size and place back too | textedit ×1 (1, 0 ms) | quiet 1063 ms |  |  | ✔ |  | ✔ |  | ✔ | ✔ |
| 41 | left-out | OFFENCE: everything should be in view, and one window is in the corner | finder ×1 (1, 0 ms) | quiet 1013 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 42 | honest-return-2 | it comes back | finder ×1 (1, 0 ms) | quiet 1026 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 43 | vanishes | OFFENCE: a window is closed, and nobody asked for that |  | quiet 1266 ms |  | ✔ | ✔ | ✔ |  |  | ✘ | ✔ |

### What only Arbor's own process can do wrong

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 44 | honest-click-5 | clicks the first document's title bar, with something that passes for Arbor running |  | quiet 433 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | under-the-stage | a panel covers the whole display, as Arbor's stage does, and under it a window goes about before it ends up: nobody sees that | textedit ×1 (1, 0 ms) | quiet 759 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 46 | under-no-stage | OFFENCE: the same under a panel that is wholly transparent, as Arbor's is when it rehearses its stage: everybody sees the window go about | textedit ×2 (2, 499 ms) | quiet 756 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 47 | held-back | OFFENCE: the button comes up, and an event tap keeps that from the apps for a fifth of a second |  | quiet 702 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 48 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 742 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 819 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 50 | both-previews | OFFENCE: a window is dragged against the menu bar, and a drop preview comes up beside macOS's own | textedit ×1 (10, 322 ms) | quiet 1460 ms | ✘ | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 51 | honest-drag-back | drags it away from the top again |  | quiet 1015 ms | ✔ | ✔ | ~ |  |  | ✔ | ✔ | ✔ |
| 52 | busy-doing-nothing | OFFENCE: nobody does anything, and the process keeps a core busy |  | quiet 365 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 53 | honest-idle-2 | nobody does anything, and neither does it |  | quiet 369 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 54 | stays-behind | OFFENCE: it is asked to quit and does, but a second process of its stays |  | quiet 427 ms |  | ✔ | ✔ |  |  |  | ✔ | ✘ |
| 55 | ends-unasked | OFFENCE: nobody does anything, and the process ends |  | quiet 406 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 56 | tells | OFFENCE: a window's title is written into a log |  | quiet 411 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
