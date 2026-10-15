52 steps in 166 s, 38 of them judged, 18 with a rule broken. The sampler: samples 6361 seconds 166.8 hz 38.1 cost-ms 1.99 late 72 longest-gap-ms 899.
Input: 194 presses, releases, keys and scrolls reached the apps, half of them within 638 µs, 99 in 100 within 21053 µs, the latest after 246783 µs.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 5 | 1 | 46 both-previews |
| 2 | nothing moves that the person did not move | 34 | 2 | 21 somebody-else, 42 vanishes |
| 3 | no jolts: a window moves once, to where it ends up | 38 | 5 | 19 moved-twice, 23 flashes, 33 out-of-the-hand, 34 dropped-elsewhere, 36 answers-late |
| 4 | the window you switch to comes to the front and into view | 24 | 3 | 25 covered, 28 keyboard-taken, 30 comes-forward |
| 5 | quitting, Float All and pause give windows their own sizes back | 2 | 1 | 38 wrong-size |
| 6 | what a person presses reaches the apps, at once | 14 | 1 | 45 held-back |
| L | no window is lost or stuck | 38 | 2 | 40 left-out, 42 vanishes |
| - | what the script itself checked | 38 | 4 | 48 busy-doing-nothing, 50 stays-behind, 51 ends-unasked, 52 tells |

## Findings

### Rule 1: never fight macOS: where it answers a drag, Arbor stands aside

- ✘ **46 both-previews** (OFFENCE: a window is dragged against the menu bar, and a drop preview comes up beside macOS's own): textedit (w46) macOS's tiling preview and Arbor's drop preview were up at the same time [fought]

### Rule 2: nothing moves that the person did not move

- ✘ **21 somebody-else** (OFFENCE: a window that the step does not name is moved): finder (w32) moved, and the step did not name it [moved-unasked]
  - +0 ms 700,80 560×380 · +42 ms 720,120 560×380
- ✘ **42 vanishes** (OFFENCE: a window is closed, and nobody asked for that): elm (w81) moved, and the step did not name it [moved-unasked]
  - +0 ms 140,500 520×300 · +189 ms 144,502 512×296 · +198 ms 145,503 510×294 · +405 ms off the screen

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **19 moved-twice** (OFFENCE: a window is moved, and half a second later moved again): textedit (w46) moved 2 times [jolt]
  - +0 ms 60,60 600×420 · +68 ms 160,100 600×420 · +661 ms 220,100 600×420
- ✘ **23 flashes** (OFFENCE: a window that is out of view shows for a moment): preview (w61) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 708×320 · +22 ms 400,300 708×320 · +51 ms 1599,770 708×320
- ✘ **33 out-of-the-hand** (OFFENCE: while the button is down the dragged window is pulled away): textedit (w46) moved 400 points further than the pointer did, 3751 ms into the step [pulled]
  - +0 ms 167,120 600×420 · +47 ms 163,120 600×420 · +148 ms 159,120 600×420 · +931 ms 155,120 600×420 · +1042 ms 108,120 600×420 · +1051 ms 95,105 600×420 · … 10 more … · +1684 ms 51,60 600×420 · +1931 ms 52,60 600×420 · +2038 ms 51,60 600×420 · +2531 ms 451,260 600×420 · +2894 ms 51,60 600×420
- ✘ **34 dropped-elsewhere** (OFFENCE: a window is dragged and let go, and goes somewhere else altogether): textedit (w46) ended neither where it was let go nor where the preview was: let go at 119,79 600×420, no preview, now at 539,339 600×420 [stuck]
  - +0 ms 119,79 600×420 · +1652 ms 539,339 600×420
- ✘ **36 answers-late** (OFFENCE: a key is pressed, and the window moves two seconds later): the last window came to rest 2224 ms after the key or the button [slow]
- ~ **47 honest-drag-back** (drags it away from the top again): textedit (w46) changed its size while it was being dragged [jolt]
  - +0 ms 0,33 1600×791 · +36 ms 1,39 1600×791 · +43 ms 1,39 1544×770 · +82 ms 1,39 1204×641 · +144 ms 400,39 797×486 · +150 ms 440,42 717×455 · … 23 more … · +1717 ms 539,109 521×381 · +1843 ms 540,112 521×381 · +1893 ms 540,115 521×381 · +2108 ms 541,115 521×381 · +2250 ms 540,115 521×381

### Rule 4: the window you switch to comes to the front and into view

- ✘ **25 covered** (OFFENCE: the window switched to is covered by another one at once): textedit (w46) is not in front: elm (w81) ahead of it, of which 1 cover part of it [behind]
- ✘ **28 keyboard-taken** (OFFENCE: after the switch another app, with no window to show, takes the keyboard): textedit (w46) its app is not the one in front (process 9502 is) [focus]
- ✘ **30 comes-forward** (OFFENCE: nobody does anything, and an app comes forward by itself): the app in front changed (to process 9502), and nobody switched [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **38 wrong-size** (OFFENCE: everything is given back, but one window keeps a size that is not its own): textedit (w46) is 119,79 640×460; its own size was 119,79 520×380 [size-lost]

### Rule 6: what a person presses reaches the apps, at once

- ✘ **45 held-back** (OFFENCE: the button comes up, and an event tap keeps that from the apps for a fifth of a second): the button came up, and the apps heard of it 246 ms later [input-held]

### Rule L: no window is lost or stuck

- ✘ **40 left-out** (OFFENCE: everything should be in view, and one window is in the corner): finder (w32) is out of view: 0% of it is on a display, at 1599,770 560×380 [lost]
- ✘ **42 vanishes** (OFFENCE: a window is closed, and nobody asked for that): elm (w81) left the screen, and the step did not say it would [lost]
  - +0 ms 140,500 520×300 · +189 ms 144,502 512×296 · +198 ms 145,503 510×294 · +405 ms off the screen

### Rule -: what the script itself checked

- ✘ **48 busy-doing-nothing** (OFFENCE: nobody does anything, and the process keeps a core busy): with nothing to do Arbor used 101.0 % of a core [busy]
- ✘ **50 stays-behind** (OFFENCE: it is asked to quit and does, but a second process of its stays): after Quit a process of Arbor's is still there: 17773 [left-behind]
- ✘ **51 ends-unasked** (OFFENCE: nobody does anything, and the process ends): Arbor's process ended, and nobody asked it to [crash]
- ✘ **52 tells** (OFFENCE: a window's title is written into a log): a window's title is in what the run brings back: saboteur.log [told]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (3, 193 ms) | quiet 958 ms; blind for 128 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 476 ms; blind for 816 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×2 (3, 365 ms) | quiet 2009 ms; blind for 899 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (4, 349 ms) | quiet 1182 ms; blind for 130 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (3, 125 ms), w53 ×2 (8, 917 ms), w55 ×1 (5, 134 ms) | quiet 351 ms; blind for 143 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (4, 422 ms) | quiet 1445 ms; blind for 140 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (4, 308 ms) | quiet 836 ms; blind for 246 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (1, 0 ms) | quiet 975 ms; blind for 184 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | mail ×1 (1, 0 ms), w67 ×1 (3, 125 ms) | quiet 796 ms; blind for 580 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (39, 3964 ms) | quiet 1443 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (38, 2958 ms) | quiet 1078 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 424 ms |  |  |  |  |  |  |  |  |

### The windows

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 13 | open-second | opens a second document in TextEdit | elm ×1 (4, 325 ms) | quiet 1398 ms |  |  |  |  |  |  |  |  |
| 14 | lay-out | hides the other apps and puts five windows side by side | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), preview ×1 (1, 0 ms), elm ×1 (1, 0 ms) | quiet 369 ms; blind for 113 ms |  |  |  |  |  |  |  |  |

### Honest steps and offences

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 15 | honest-switch | clicks TextEdit's icon in the Dock |  | quiet 457 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 16 | honest-click | clicks the first document's title bar |  | quiet 406 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | honest-move | a window is moved once, straight to where it ends up | textedit ×1 (1, 0 ms) | quiet 1079 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 18 | honest-resize | a window is given another size and another place, which takes two stages | textedit ×1 (1, 0 ms) | quiet 1067 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 19 | moved-twice | OFFENCE: a window is moved, and half a second later moved again | textedit ×2 (2, 593 ms) | quiet 1092 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 20 | elsewhere-first | OFFENCE: a window goes somewhere else before it goes where it ends up | textedit ×1 (1, 0 ms) | quiet 1054 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 21 | somebody-else | OFFENCE: a window that the step does not name is moved | finder ×1 (1, 0 ms) | quiet 1022 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 22 | honest-park | a window is sent out of view, to the corner | preview ×1 (1, 0 ms) | quiet 1022 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 23 | flashes | OFFENCE: a window that is out of view shows for a moment | preview ×1 (2, 29 ms) | quiet 1014 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 24 | honest-return | it comes back into view | preview ×1 (1, 0 ms) | quiet 1016 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 25 | covered | OFFENCE: the window switched to is covered by another one at once |  | quiet 1048 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 26 | honest-click-2 | clicks the first document's title bar |  | quiet 387 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 27 | honest-minimize | Terminal's window is minimized | terminal ×1 (16, 451 ms) | quiet 1635 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 28 | keyboard-taken | OFFENCE: after the switch another app, with no window to show, takes the keyboard |  | quiet 353 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 29 | honest-click-3 | clicks the first document's title bar |  | quiet 395 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | comes-forward | OFFENCE: nobody does anything, and an app comes forward by itself |  | quiet 394 ms |  | ✔ | ✔ | ✘ |  |  | ✔ | ✔ |
| 31 | honest-click-4 | clicks the first document's title bar |  | quiet 434 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 32 | honest-drag | drags the first document a little way by its title bar |  | quiet 1072 ms | ✔ | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 33 | out-of-the-hand | OFFENCE: while the button is down the dragged window is pulled away |  | quiet 1057 ms | ✔ | ✔ | ✘ |  |  | ✔ | ✔ | ✔ |
| 34 | dropped-elsewhere | OFFENCE: a window is dragged and let go, and goes somewhere else altogether | textedit ×1 (1, 0 ms) | quiet 1046 ms | ✔ | ✔ | ✘ |  |  | ✔ | ✔ | ✔ |
| 35 | honest-move-2 | it is moved back to where the hand left it, which is its own place from now on | textedit ×1 (1, 0 ms) | quiet 1021 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 36 | answers-late | OFFENCE: a key is pressed, and the window moves two seconds later | textedit ×1 (1, 0 ms) | quiet 1023 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 37 | honest-idle | nobody does anything for three seconds |  | quiet 376 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 38 | wrong-size | OFFENCE: everything is given back, but one window keeps a size that is not its own | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1015 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 39 | honest-give-back | now it gets its own size and place back too | textedit ×1 (1, 0 ms) | quiet 1042 ms |  |  | ✔ |  | ✔ |  | ✔ | ✔ |
| 40 | left-out | OFFENCE: everything should be in view, and one window is in the corner | finder ×1 (1, 0 ms) | quiet 1071 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 41 | honest-return-2 | it comes back | finder ×1 (1, 0 ms) | quiet 1059 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 42 | vanishes | OFFENCE: a window is closed, and nobody asked for that | elm ×1 (2, 9 ms) | quiet 1291 ms |  | ✘ | ✔ | ✔ |  |  | ✘ | ✔ |

### What only Arbor's own process can do wrong

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 43 | honest-click-5 | clicks the first document's title bar, with something that passes for Arbor running |  | quiet 376 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | under-the-stage | a panel covers the whole display, as Arbor's stage does, and under it a window goes about before it ends up: nobody sees that | textedit ×1 (1, 0 ms) | quiet 814 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 45 | held-back | OFFENCE: the button comes up, and an event tap keeps that from the apps for a fifth of a second |  | quiet 531 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ | ✔ |
| 46 | both-previews | OFFENCE: a window is dragged against the menu bar, and a drop preview comes up beside macOS's own | textedit ×1 (11, 332 ms) | quiet 1380 ms | ✘ | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 47 | honest-drag-back | drags it away from the top again |  | quiet 1009 ms | ✔ | ✔ | ~ |  |  | ✔ | ✔ | ✔ |
| 48 | busy-doing-nothing | OFFENCE: nobody does anything, and the process keeps a core busy |  | quiet 424 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 49 | honest-idle-2 | nobody does anything, and neither does it |  | quiet 411 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 50 | stays-behind | OFFENCE: it is asked to quit and does, but a second process of its stays |  | quiet 374 ms |  | ✔ | ✔ |  |  |  | ✔ | ✘ |
| 51 | ends-unasked | OFFENCE: nobody does anything, and the process ends |  | quiet 373 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 52 | tells | OFFENCE: a window's title is written into a log |  | quiet 411 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
