62 steps in 249 s, 45 of them judged, 21 with a rule broken. The sampler: samples 6426 seconds 180.7 hz 35.6 cost-ms 2.18 late 2 longest-gap-ms 186 whole-samples 8900 whole-seconds 250.3 whole-late 97.
Input: 4 presses, releases, keys and scrolls reached the apps, half of them within 2944 µs, 99 in 100 within 210648 µs, the latest after 210648 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 2, 2944, 2944; up 2, 210648, 210648. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): down 13, 497; dragged 20, 363; forward 12, 11033; key 13, 461; scroll 28, 279; up 25, 345.
The round of input `started` (events, half within µs): down 13, 631; dragged 20, 590; forward 12, 11541; key 13, 420; scroll 28, 371; up 25, 312.
The round of input `last` (events, half within µs): down 13, 594; dragged 20, 277; forward 12, 5351; key 12, 625; scroll 28, 175; up 25, 237.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 3 | 0 |  |
| 2 | nothing moves that the person did not move | 41 | 1 | 23 somebody-else |
| 3 | no jolts: a window moves once, to where it ends up | 45 | 8 | 21 moved-twice, 22 elsewhere-first, 25 flashes, 33 lands-elsewhere, 40 out-of-the-hand, 41 dropped-elsewhere, 43 answers-late, 52 under-no-stage |
| 4 | the window you switch to comes to the front and into view | 29 | 3 | 27 covered, 35 keyboard-taken, 37 comes-forward |
| 5 | quitting, Float All and pause give windows their own sizes back | 2 | 1 | 45 wrong-size |
| 6 | what a person presses reaches the apps, at once | 15 | 2 | 53 held-back, 55 input-last |
| L | no window is lost or stuck | 45 | 2 | 47 left-out, 49 vanishes |
| - | what the script itself checked | 45 | 4 | 58 busy-doing-nothing, 60 stays-behind, 61 ends-unasked, 62 tells |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **23 somebody-else** (OFFENCE: a window that the step does not name is moved): finder (w32) moved, and the step did not name it [moved-unasked]
  - +0 ms 700,80 560×380 · +54 ms 720,120 560×380

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **21 moved-twice** (OFFENCE: a window is moved, and half a second later moved again): textedit (w46) moved 2 times [jolt]
  - +0 ms 60,60 600×420 · +41 ms 160,100 600×420 · +603 ms 220,100 600×420
- ✘ **22 elsewhere-first** (OFFENCE: a window goes somewhere else before it goes where it ends up): textedit (w46) went 960 points out of its way before it ended up [jolt]
  - +0 ms 220,100 600×420 · +54 ms 700,300 600×420 · +266 ms 100,100 600×420
- ✘ **25 flashes** (OFFENCE: a window that is out of view shows for a moment): preview (w61) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 708×320 · +66 ms 400,300 708×320 · +181 ms 1599,770 708×320
- ✘ **33 lands-elsewhere** (OFFENCE: it is shown again where it was, and a tenth of a second later it is somewhere else: one burst, a straight road): preview (w61) came into sight at 760,500 708×320 and was then moved to 460,500 708×320 [jolt]
  - +0 ms 760,500 708×320 · +214 ms 460,500 708×320
- ✘ **40 out-of-the-hand** (OFFENCE: while the button is down the dragged window is pulled away): textedit (w46) moved 400 points further than the pointer did, 3661 ms into the step [pulled]
  - +0 ms 167,120 600×420 · +25 ms 163,120 600×420 · +108 ms 159,120 600×420 · +843 ms 155,120 600×420 · +881 ms 129,120 600×420 · +883 ms 116,120 600×420 · … 9 more … · +1629 ms 51,60 600×420 · +1958 ms 52,60 600×420 · +2074 ms 51,60 600×420 · +2521 ms 451,260 600×420 · +2853 ms 51,60 600×420
- ✘ **41 dropped-elsewhere** (OFFENCE: a window is dragged and let go, and goes somewhere else altogether): textedit (w46) ended neither where it was let go nor where the preview was: let go at 119,79 600×420, no preview, now at 539,339 600×420 [stuck]
  - +0 ms 119,79 600×420 · +1745 ms 539,339 600×420
- ✘ **43 answers-late** (OFFENCE: a key is pressed, and the window moves two seconds later): the last window came to rest 2333 ms after the key or the button [slow]
- ✘ **52 under-no-stage** (OFFENCE: the same under a panel that is wholly transparent, as Arbor's is when it rehearses its stage: everybody sees the window go about): textedit (w46) moved 2 times [jolt]
  - +0 ms 159,79 520×380 · +620 ms 459,279 520×380 · +1071 ms 119,79 520×380

### Rule 4: the window you switch to comes to the front and into view

- ✘ **27 covered** (OFFENCE: the window switched to is covered by another one at once): textedit (w46) is not in front: elm (w113) ahead of it, of which 1 cover part of it [behind]
- ✘ **35 keyboard-taken** (OFFENCE: after the switch another app, with no window to show, takes the keyboard): textedit (w46) its app is not the one in front (process 44252 is) [focus]
- ✘ **37 comes-forward** (OFFENCE: nobody does anything, and an app comes forward by itself): the app in front changed (to process 44252), and nobody switched [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **45 wrong-size** (OFFENCE: everything is given back, but one window keeps a size that is not its own): textedit (w46) is 119,79 640×460; its own size was 119,79 520×380 [size-lost]

### Rule 6: what a person presses reaches the apps, at once

- ✘ **53 held-back** (OFFENCE: the button comes up, and an event tap keeps that from the apps for a fifth of a second): the button came up, and the apps heard of it 210 ms later [input-held]
- ✘ **55 input-last** (a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text): 1 of 13 events of the kind key never reached the apps [input-held]

### Rule L: no window is lost or stuck

- ✘ **47 left-out** (OFFENCE: everything should be in view, and one window is in the corner): finder (w32) is out of view: 0% of it is on a display, at 1599,772 560×380 [lost]
- ✘ **49 vanishes** (OFFENCE: a window is closed, and nobody asked for that): elm (w113) left the screen, and the step did not say it would [lost]
  - +0 ms 140,500 520×300 · +412 ms off the screen

### Rule -: what the script itself checked

- ~ **56 both-previews** (OFFENCE: a window is dragged against the menu bar, and a drop preview comes up beside macOS's own): the act was not performed: drag_window could not be done [script]
- ~ **57 honest-drag-back** (drags it away from the top again): the act was not performed: drag_window could not be done [script]
- ✘ **58 busy-doing-nothing** (OFFENCE: nobody does anything, and the process keeps a core busy): with nothing to do Arbor used 100.7 % of a core [busy]
- ✘ **60 stays-behind** (OFFENCE: it is asked to quit and does, but a second process of its stays): after Quit a process of Arbor's is still there: 57448 [left-behind]
- ✘ **60 stays-behind** (OFFENCE: it is asked to quit and does, but a second process of its stays): Arbor's process ended, and nobody asked it to [crash]
- ✘ **61 ends-unasked** (OFFENCE: nobody does anything, and the process ends): Arbor's process ended, and nobody asked it to [crash]
- ✘ **62 tells** (OFFENCE: a window's title is written into a log): a window's title is in what the run brings back: saboteur.log [told]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 879 ms; blind for 210 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 450 ms; blind for 3130 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (2, 234 ms) | quiet 1232 ms; blind for 582 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (8, 342 ms) | quiet 1073 ms; blind for 178 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (3, 134 ms), w53 ×2 (12, 1287 ms), w55 ×1 (8, 198 ms) | quiet 424 ms; blind for 321 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×2 (7, 445 ms) | quiet 1429 ms; blind for 127 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×2 (4, 395 ms) | quiet 592 ms; blind for 310 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview |  | quiet 390 ms; blind for 1542 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail |  | quiet 440 ms; blind for 955 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (38, 4117 ms) | quiet 1401 ms; blind for 100 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (33, 2034 ms) | quiet 1012 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 394 ms |  |  |  |  |  |  |  |  |
| 13 | open-desks | opens the two windows that input is tried on | desk-a ×1 (1, 0 ms), desk-b ×1 (2, 19 ms) | quiet 373 ms |  |  |  |  |  |  |  |  |
| 14 | input-before | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 907 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The windows

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 15 | open-second | opens a second document in TextEdit | elm ×1 (2, 250 ms) | quiet 1362 ms |  |  |  |  |  |  |  |  |
| 16 | lay-out | hides the other apps and puts five windows side by side | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (2, 18 ms), preview ×1 (1, 0 ms), elm ×1 (1, 0 ms) | quiet 387 ms |  |  |  |  |  |  |  |  |

### Honest steps and offences

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 17 | honest-switch | clicks TextEdit's icon in the Dock |  | quiet 457 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 18 | honest-click | clicks the first document's title bar |  | quiet 405 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | honest-move | a window is moved once, straight to where it ends up | textedit ×1 (1, 0 ms) | quiet 1051 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 20 | honest-resize | a window is given another size and another place, which takes two stages | textedit ×1 (2, 24 ms) | quiet 1094 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 21 | moved-twice | OFFENCE: a window is moved, and half a second later moved again | textedit ×2 (2, 562 ms) | quiet 1014 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 22 | elsewhere-first | OFFENCE: a window goes somewhere else before it goes where it ends up | textedit ×1 (2, 212 ms) | quiet 1073 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 23 | somebody-else | OFFENCE: a window that the step does not name is moved | finder ×1 (1, 0 ms) | quiet 1012 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 24 | honest-park | a window is sent out of view, to the corner | preview ×1 (1, 0 ms) | quiet 1030 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 25 | flashes | OFFENCE: a window that is out of view shows for a moment | preview ×1 (2, 115 ms) | quiet 1030 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 26 | honest-return | it comes back into view | preview ×1 (1, 0 ms) | quiet 1015 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 27 | covered | OFFENCE: the window switched to is covered by another one at once |  | quiet 1061 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 28 | honest-click-2 | clicks the first document's title bar |  | quiet 524 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 29 | honest-minimize | Terminal's window is minimized | terminal ×1 (17, 463 ms) | quiet 1572 ms; blind for 186 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 30 | honest-hide | Preview is hidden |  | quiet 1110 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 31 | honest-landing | it is shown again, and is where it was |  | quiet 1039 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 32 | honest-hide-2 | Preview is hidden again |  | quiet 1042 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 33 | lands-elsewhere | OFFENCE: it is shown again where it was, and a tenth of a second later it is somewhere else: one burst, a straight road | preview ×1 (1, 0 ms) | quiet 1095 ms |  | ✔ | ✘ |  |  |  | ✔ | ✔ |
| 34 | honest-put-back | it is put back | preview ×1 (1, 0 ms) | quiet 1009 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 35 | keyboard-taken | OFFENCE: after the switch another app, with no window to show, takes the keyboard |  | quiet 393 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 36 | honest-click-3 | clicks the first document's title bar |  | quiet 513 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 37 | comes-forward | OFFENCE: nobody does anything, and an app comes forward by itself |  | quiet 417 ms |  | ✔ | ✔ | ✘ |  |  | ✔ | ✔ |
| 38 | honest-click-4 | clicks the first document's title bar |  | quiet 404 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | honest-drag | drags the first document a little way by its title bar |  | quiet 1016 ms | ✔ | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 40 | out-of-the-hand | OFFENCE: while the button is down the dragged window is pulled away |  | quiet 1047 ms | ✔ | ✔ | ✘ |  |  | ✔ | ✔ | ✔ |
| 41 | dropped-elsewhere | OFFENCE: a window is dragged and let go, and goes somewhere else altogether | textedit ×1 (1, 0 ms) | quiet 1091 ms | ✔ | ✔ | ✘ |  |  | ✔ | ✔ | ✔ |
| 42 | honest-move-2 | it is moved back to where the hand left it, which is its own place from now on | textedit ×1 (1, 0 ms) | quiet 1072 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 43 | answers-late | OFFENCE: a key is pressed, and the window moves two seconds later | textedit ×1 (1, 0 ms) | quiet 1019 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 44 | honest-idle | nobody does anything for three seconds |  | quiet 370 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 45 | wrong-size | OFFENCE: everything is given back, but one window keeps a size that is not its own | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1054 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 46 | honest-give-back | now it gets its own size and place back too | textedit ×1 (1, 0 ms) | quiet 1104 ms |  |  | ✔ |  | ✔ |  | ✔ | ✔ |
| 47 | left-out | OFFENCE: everything should be in view, and one window is in the corner | finder ×1 (1, 0 ms) | quiet 1095 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 48 | honest-return-2 | it comes back | finder ×1 (1, 0 ms) | quiet 1086 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 49 | vanishes | OFFENCE: a window is closed, and nobody asked for that |  | quiet 1283 ms |  | ✔ | ✔ | ✔ |  |  | ✘ | ✔ |

### What only Arbor's own process can do wrong

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 50 | honest-click-5 | clicks the first document's title bar, with something that passes for Arbor running |  | quiet 363 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 51 | under-the-stage | a panel covers the whole display, as Arbor's stage does, and under it a window goes about before it ends up: nobody sees that | textedit ×1 (1, 0 ms) | quiet 816 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 52 | under-no-stage | OFFENCE: the same under a panel that is wholly transparent, as Arbor's is when it rehearses its stage: everybody sees the window go about | textedit ×2 (2, 451 ms) | quiet 756 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 53 | held-back | OFFENCE: the button comes up, and an event tap keeps that from the apps for a fifth of a second |  | quiet 603 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 54 | input-started | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 928 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | input-last | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 791 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 56 | both-previews | OFFENCE: a window is dragged against the menu bar, and a drop preview comes up beside macOS's own |  | quiet 375 ms |  |  |  |  |  |  |  | ~ |
| 57 | honest-drag-back | drags it away from the top again |  | quiet 351 ms |  |  |  |  |  |  |  | ~ |
| 58 | busy-doing-nothing | OFFENCE: nobody does anything, and the process keeps a core busy |  | quiet 388 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 59 | honest-idle-2 | nobody does anything, and neither does it |  | quiet 360 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 60 | stays-behind | OFFENCE: it is asked to quit and does, but a second process of its stays |  | quiet 429 ms |  | ✔ | ✔ |  |  |  | ✔ | ✘ |
| 61 | ends-unasked | OFFENCE: nobody does anything, and the process ends |  | quiet 423 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 62 | tells | OFFENCE: a window's title is written into a log |  | quiet 362 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
