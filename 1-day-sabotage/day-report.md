35 steps in 83 s, 29 of them judged, 15 with a rule broken. The sampler: samples 3190 seconds 83.7 hz 38.1 cost-ms 2.54 late 727 longest-gap-ms 485.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 3 | 0 |  |
| 2 | nothing moves that the person did not move | 25 | 1 | 13 somebody-else |
| 3 | no jolts: a window moves once, to where it ends up | 29 | 6 | 11 moved-twice, 12 elsewhere-first, 15 flashes, 25 out-of-the-hand, 26 dropped-elsewhere, 28 answers-late |
| 4 | the window you switch to comes to the front and into view | 18 | 3 | 17 covered, 20 keyboard-taken, 22 comes-forward |
| 5 | quitting, Float All and pause give windows their own sizes back | 2 | 2 | 30 wrong-size, 31 honest-give-back |
| L | no window is lost or stuck | 29 | 2 | 32 left-out, 34 vanishes |
| - | what the script itself checked | 29 | 1 | 35 tells |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **13 somebody-else** (OFFENCE: a window that the step does not name is moved): grove (w44) moved, and the step did not name it [moved-unasked]
  - +0 ms 700,80 560×380 · +42 ms 720,120 560×380

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **11 moved-twice** (OFFENCE: a window is moved, and half a second later moved again): oak (w36) moved 2 times [jolt]
  - +0 ms 60,60 600×420 · +64 ms 160,100 600×420 · +691 ms 220,100 600×420
- ✘ **12 elsewhere-first** (OFFENCE: a window goes somewhere else before it goes where it ends up): oak (w36) went 960 points out of its way before it ended up [jolt]
  - +0 ms 220,100 600×420 · +61 ms 700,300 600×420 · +89 ms 100,100 600×420
- ✘ **15 flashes** (OFFENCE: a window that is out of view shows for a moment): leaf (w47) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 708×320 · +64 ms 400,300 708×320 · +134 ms 1599,770 708×320
- ✘ **25 out-of-the-hand** (OFFENCE: while the button is down the dragged window is pulled away): oak (w36) moved 400 points further than the pointer did, 3637 ms into the step [pulled]
  - +0 ms 167,120 600×420 · +89 ms 163,120 600×420 · +129 ms 159,120 600×420 · +995 ms 155,120 600×420 · +1039 ms 133,120 600×420 · +1084 ms 108,120 600×420 · … 9 more … · +1824 ms 51,60 600×420 · +2064 ms 52,60 600×420 · +2204 ms 51,60 600×420 · +2590 ms 451,260 600×420 · +2950 ms 51,60 600×420
- ✘ **26 dropped-elsewhere** (OFFENCE: a window is dragged and let go, and goes somewhere else altogether): oak (w36) ended neither where it was let go nor where the preview was: let go at 119,79 600×420, no preview, now at 539,339 600×420 [stuck]
  - +0 ms 119,79 600×420 · +1292 ms 539,339 600×420
- ✘ **28 answers-late** (OFFENCE: a key is pressed, and the window moves two seconds later): the last window came to rest 2226 ms after the key or the button [slow]

### Rule 4: the window you switch to comes to the front and into view

- ✘ **17 covered** (OFFENCE: the window switched to is covered by another one at once): oak (w36) is not in front: elm (w42) ahead of it, of which 1 cover part of it [behind]
- ✘ **20 keyboard-taken** (OFFENCE: after the switch another app, with no window to show, takes the keyboard): oak (w36) its app is not the one in front (process 9922 is) [focus]
- ✘ **22 comes-forward** (OFFENCE: nobody does anything, and an app comes forward by itself): the app in front changed (to process 9922), and nobody switched [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **30 wrong-size** (OFFENCE: everything is given back, but one window keeps a size that is not its own): oak (w36) is 119,79 640×460; its own size was 51,60 520×380 [size-lost]
- ✘ **31 honest-give-back** (now it gets its own size and place back too): oak (w36) has its size back but not its place: 119,79 520×380, it was at 51,60 520×380 [size-lost]

### Rule L: no window is lost or stuck

- ✘ **32 left-out** (OFFENCE: everything should be in view, and one window is in the corner): grove (w44) is out of view: 0% of it is on the display, at 1599,770 560×380 [lost]
- ✘ **34 vanishes** (OFFENCE: a window is closed, and nobody asked for that): elm (w42) left the screen, and the step did not say it would [lost]
  - +0 ms 140,500 520×300 · +156 ms off the screen

### Rule -: what the script itself checked

- ✘ **35 tells** (OFFENCE: a window's title is written into a log): a window's title is in what the run brings back: saboteur.log [told]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### The windows

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-textedit | opens a document in TextEdit |  | quiet 920 ms; blind for 386 ms |  |  |  |  |  |  |  |
| 2 | open-second | opens a second one |  | quiet 1041 ms; blind for 105 ms |  |  |  |  |  |  |  |
| 3 | open-finder | opens a folder in Finder |  | quiet 875 ms; blind for 140 ms |  |  |  |  |  |  |  |
| 4 | open-preview | opens a picture in Preview |  | quiet 904 ms; blind for 261 ms |  |  |  |  |  |  |  |
| 5 | open-terminal | opens Terminal | shell ×1 (1, 0 ms) | quiet 949 ms; blind for 485 ms |  |  |  |  |  |  |  |
| 6 | lay-out | puts them side by side | oak ×1 (1, 0 ms), elm ×1 (1, 0 ms), grove ×1 (1, 0 ms), leaf ×1 (1, 0 ms), shell ×1 (1, 0 ms) | quiet 488 ms; blind for 134 ms |  |  |  |  |  |  |  |

### Honest steps and offences

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 7 | honest-switch | clicks TextEdit's icon in the Dock |  | quiet 506 ms; blind for 78 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 8 | honest-click | clicks the first document's title bar |  | quiet 377 ms; blind for 67 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 9 | honest-move | a window is moved once, straight to where it ends up | oak ×1 (1, 0 ms) | quiet 1023 ms; blind for 65 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 10 | honest-resize | a window is given another size and another place, which takes two stages | oak ×1 (1, 0 ms) | quiet 1026 ms; blind for 72 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 11 | moved-twice | OFFENCE: a window is moved, and half a second later moved again | oak ×2 (2, 627 ms) | quiet 1085 ms; blind for 78 ms |  | ✔ | ✘ | ✔ |  | ✔ | ✔ |
| 12 | elsewhere-first | OFFENCE: a window goes somewhere else before it goes where it ends up | oak ×1 (2, 28 ms) | quiet 1048 ms; blind for 63 ms |  | ✔ | ✘ | ✔ |  | ✔ | ✔ |
| 13 | somebody-else | OFFENCE: a window that the step does not name is moved | grove ×1 (1, 0 ms) | quiet 999 ms; blind for 69 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 14 | honest-park | a window is sent out of view, to the corner | leaf ×1 (1, 0 ms) | quiet 1084 ms; blind for 77 ms |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 15 | flashes | OFFENCE: a window that is out of view shows for a moment | leaf ×1 (2, 70 ms) | quiet 1089 ms; blind for 73 ms |  |  | ✘ |  |  | ✔ | ✔ |
| 16 | honest-return | it comes back into view | leaf ×1 (1, 0 ms) | quiet 1019 ms; blind for 74 ms |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 17 | covered | OFFENCE: the window switched to is covered by another one at once |  | quiet 1045 ms; blind for 75 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ |
| 18 | honest-click-2 | clicks the first document's title bar |  | quiet 436 ms; blind for 64 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 19 | honest-minimize | Terminal's window is minimized | shell ×1 (20, 483 ms) | quiet 1588 ms; blind for 65 ms |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 20 | keyboard-taken | OFFENCE: after the switch another app, with no window to show, takes the keyboard |  | quiet 425 ms; blind for 76 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ |
| 21 | honest-click-3 | clicks the first document's title bar |  | quiet 415 ms; blind for 68 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 22 | comes-forward | OFFENCE: nobody does anything, and an app comes forward by itself |  | quiet 411 ms; blind for 72 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ |
| 23 | honest-click-4 | clicks the first document's title bar |  | quiet 422 ms; blind for 69 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 24 | honest-drag | drags the first document a little way by its title bar |  | quiet 1025 ms; blind for 75 ms | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 25 | out-of-the-hand | OFFENCE: while the button is down the dragged window is pulled away |  | quiet 1057 ms; blind for 78 ms | ✔ | ✔ | ✘ |  |  | ✔ | ✔ |
| 26 | dropped-elsewhere | OFFENCE: a window is dragged and let go, and goes somewhere else altogether | oak ×1 (1, 0 ms) | quiet 1040 ms; blind for 79 ms | ✔ | ✔ | ✘ |  |  | ✔ | ✔ |
| 27 | honest-move-2 | it is moved back | oak ×1 (1, 0 ms) | quiet 1007 ms; blind for 76 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 28 | answers-late | OFFENCE: a key is pressed, and the window moves two seconds later | oak ×1 (1, 0 ms) | quiet 1086 ms; blind for 72 ms |  | ✔ | ✘ | ✔ |  | ✔ | ✔ |
| 29 | honest-idle | nobody does anything for three seconds |  | quiet 381 ms; blind for 77 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 30 | wrong-size | OFFENCE: everything is given back, but one window keeps a size that is not its own | oak ×1 (1, 0 ms), grove ×1 (1, 0 ms) | quiet 1067 ms; blind for 69 ms |  |  | ✔ |  | ✘ | ✔ | ✔ |
| 31 | honest-give-back | now it gets its own size and place back too | oak ×1 (1, 0 ms) | quiet 1046 ms; blind for 67 ms |  |  | ✔ |  | ✘ | ✔ | ✔ |
| 32 | left-out | OFFENCE: everything should be in view, and one window is in the corner | grove ×1 (1, 0 ms) | quiet 1079 ms; blind for 74 ms |  |  | ✔ |  |  | ✘ | ✔ |
| 33 | honest-return-2 | it comes back | grove ×1 (1, 0 ms) | quiet 1031 ms; blind for 79 ms |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 34 | vanishes | OFFENCE: a window is closed, and nobody asked for that |  | quiet 1088 ms; blind for 77 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ |
| 35 | tells | OFFENCE: a window's title is written into a log |  | quiet 422 ms; blind for 58 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✘ |
