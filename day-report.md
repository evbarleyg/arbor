32 steps in 61 s, 26 of them judged, 13 with a rule broken. The sampler: samples 2361 seconds 62.3 hz 37.9 cost-ms 1.63 late 652 longest-gap-ms 331.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 2 | 0 |  |
| 2 | nothing moves that the person did not move | 22 | 2 | 13 somebody-else, 20 keyboard-taken |
| 3 | no jolts: a window moves once, to where it ends up | 26 | 6 | 11 moved-twice, 12 elsewhere-first, 15 flashes, 24 honest-drag, 25 out-of-the-hand, 26 answers-late |
| 4 | the window you switch to comes to the front and into view | 16 | 1 | 22 comes-forward |
| 5 | quitting, Float All and pause give windows their own sizes back | 2 | 2 | 28 wrong-size, 29 honest-give-back |
| L | no window is lost or stuck | 26 | 3 | 20 keyboard-taken, 30 left-out, 32 vanishes |
| - | what the script itself checked | 26 | 0 |  |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **13 somebody-else** (OFFENCE: a window that the step does not name is moved): grove (w44) moved, and the step did not name it [moved-unasked]
  - +0 ms 700,80 560×380 · +36 ms 720,120 560×380
- ✘ **20 keyboard-taken** (OFFENCE: after the switch another app, with no window to show, takes the keyboard): shell (w47) moved, and the step did not name it [moved-unasked]
  - +0 ms 1067,450 375×260 · +13 ms 1168,532 284×260 · +32 ms 1211,565 243×260 · +99 ms 1345,683 115×188 · +148 ms 1397,753 66×118 · +155 ms 1402,765 61×106 · +171 ms 1407,776 57×95 · +237 ms 1417,827 49×44 · +244 ms 1417,830 49×41 · +273 ms 1416,833 50×38 · +275 ms off the screen

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **9 honest-move** (a window is moved once, straight to where it ends up): oak (w37) was still moving 19 ms after everything had been quiet for a second [jolt]
- ✘ **11 moved-twice** (OFFENCE: a window is moved, and half a second later moved again): oak (w37) moved 2 times [jolt]
  - +0 ms 60,60 600×420 · +63 ms 160,100 600×420 · +563 ms 220,100 600×420
- ✘ **12 elsewhere-first** (OFFENCE: a window goes somewhere else before it goes where it ends up): oak (w37) went 960 points out of its way before it ended up [jolt]
  - +0 ms 220,100 600×420 · +45 ms 700,300 600×420 · +112 ms 100,100 600×420
- ~ **13 somebody-else** (OFFENCE: a window that the step does not name is moved): grove (w44) was still moving 10 ms after everything had been quiet for a second [jolt]
- ✘ **15 flashes** (OFFENCE: a window that is out of view shows for a moment): leaf (w45) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 708×320 · +25 ms 400,300 708×320 · +88 ms 1599,770 708×320
- ~ **16 honest-return** (it comes back into view): leaf (w45) was still moving 40 ms after everything had been quiet for a second [jolt]
- ~ **19 honest-minimize** (Terminal's window is minimized): shell (w47) was still moving 233 ms after everything had been quiet for a second [jolt]
- ✘ **24 honest-drag** (drags the first document a little way by its title bar): oak (w37) was 49 points from where the pointer carried it, 1762 ms into the step [pulled]
  - +0 ms 104,102 600×420 · +23 ms 108,104 600×420 · +130 ms 112,106 600×420 · +188 ms 116,108 600×420 · +237 ms 119,110 600×420 · +320 ms 119,112 600×420 · … 13 more … · +1654 ms 163,120 600×420 · +1756 ms 167,120 600×420 · +1762 ms 171,120 600×420 · +2017 ms 172,120 600×420 · +2167 ms 171,120 600×420
- ✘ **25 out-of-the-hand** (OFFENCE: while the button is down the dragged window is pulled away): oak (w37) was 401 points from where the pointer carried it, 3060 ms into the step [pulled]
  - +0 ms 167,120 600×420 · +59 ms 163,120 600×420 · +95 ms 159,120 600×420 · +809 ms 155,120 600×420 · +862 ms 122,120 600×420 · +867 ms 107,120 600×420 · … 8 more … · +1435 ms 55,62 600×420 · +1534 ms 51,60 600×420 · +1703 ms 52,60 600×420 · +2311 ms 452,260 600×420 · +2763 ms 51,60 600×420
- ~ **26 answers-late** (OFFENCE: a key is pressed, and the window moves two seconds later): oak (w37) was still moving 21 ms after everything had been quiet for a second [jolt]
- ✘ **26 answers-late** (OFFENCE: a key is pressed, and the window moves two seconds later): the last window came to rest 2309 ms after the key or the button [slow]
- ~ **31 honest-return-2** (it comes back): grove (w44) was still moving 37 ms after everything had been quiet for a second [jolt]

### Rule 4: the window you switch to comes to the front and into view

- ✘ **22 comes-forward** (OFFENCE: nobody does anything, and an app comes forward by itself): the app in front changed (to process 3371), and nobody switched [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **28 wrong-size** (OFFENCE: everything is given back, but one window keeps a size that is not its own): oak (w37) is 80,80 640×460; its own size was 51,60 520×380 [size-lost]
- ✘ **29 honest-give-back** (now it gets its own size and place back too): oak (w37) is 80,80 640×460; its own size was 51,60 520×380 [size-lost]

### Rule L: no window is lost or stuck

- ✘ **20 keyboard-taken** (OFFENCE: after the switch another app, with no window to show, takes the keyboard): shell (w47) left the screen, and the step did not say it would [lost]
  - +0 ms 1067,450 375×260 · +13 ms 1168,532 284×260 · +32 ms 1211,565 243×260 · +99 ms 1345,683 115×188 · +148 ms 1397,753 66×118 · +155 ms 1402,765 61×106 · +171 ms 1407,776 57×95 · +237 ms 1417,827 49×44 · +244 ms 1417,830 49×41 · +273 ms 1416,833 50×38 · +275 ms off the screen
- ✘ **30 left-out** (OFFENCE: everything should be in view, and one window is in the corner): grove (w44) is out of view: 0% of it is on the display, at 1599,770 560×380 [lost]
- ✘ **32 vanishes** (OFFENCE: a window is closed, and nobody asked for that): elm (w42) left the screen, and the step did not say it would [lost]
  - +0 ms 140,500 520×300 · +263 ms off the screen

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### The windows

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-textedit | opens a document in TextEdit | oak ×1 (1, 0 ms) | quiet 1027 ms; blind for 331 ms |  |  |  |  |  |  |  |
| 2 | open-second | opens a second one |  | quiet 1039 ms; blind for 65 ms |  |  |  |  |  |  |  |
| 3 | open-finder | opens a folder in Finder |  | quiet 949 ms; blind for 65 ms |  |  |  |  |  |  |  |
| 4 | open-preview | opens a picture in Preview |  | quiet 970 ms; blind for 205 ms |  |  |  |  |  |  |  |
| 5 | open-terminal | opens Terminal | shell ×1 (1, 0 ms) | quiet 969 ms; blind for 328 ms |  |  |  |  |  |  |  |
| 6 | lay-out | puts them side by side | oak ×1 (1, 0 ms), elm ×1 (1, 0 ms), grove ×1 (2, 32 ms), leaf ×1 (1, 0 ms), shell ×1 (1, 0 ms) | quiet 0 ms; blind for 71 ms |  |  |  |  |  |  |  |

### Honest steps and offences

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 7 | honest-switch | clicks TextEdit's icon in the Dock |  | quiet 388 ms; blind for 70 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 8 | honest-click | clicks the first document's title bar |  | quiet 380 ms; blind for 76 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 9 | honest-move | a window is moved once, straight to where it ends up | oak ×1 (1, 0 ms) | quiet 0 ms; blind for 60 ms |  | ✔ | ~ | ✔ |  | ✔ | ✔ |
| 10 | honest-resize | a window is given another size and another place, which takes two stages | oak ×1 (1, 0 ms) | quiet 1044 ms; blind for 73 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 11 | moved-twice | OFFENCE: a window is moved, and half a second later moved again | oak ×2 (2, 500 ms) | quiet 1086 ms; blind for 63 ms |  | ✔ | ✘ | ✔ |  | ✔ | ✔ |
| 12 | elsewhere-first | OFFENCE: a window goes somewhere else before it goes where it ends up | oak ×1 (2, 67 ms) | quiet 1092 ms; blind for 73 ms |  | ✔ | ✘ | ✔ |  | ✔ | ✔ |
| 13 | somebody-else | OFFENCE: a window that the step does not name is moved | grove ×1 (1, 0 ms) | quiet 0 ms; blind for 77 ms |  | ✘ | ~ | ✔ |  | ✔ | ✔ |
| 14 | honest-park | a window is sent out of view, to the corner | leaf ×1 (1, 0 ms) | quiet 1016 ms; blind for 80 ms |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 15 | flashes | OFFENCE: a window that is out of view shows for a moment | leaf ×1 (2, 63 ms) | quiet 1059 ms; blind for 77 ms |  |  | ✘ |  |  | ✔ | ✔ |
| 16 | honest-return | it comes back into view | leaf ×1 (1, 0 ms) | quiet 0 ms; blind for 67 ms |  | ✔ | ~ |  |  | ✔ | ✔ |
| 17 | covered | OFFENCE: the window switched to is covered by another one at once |  | quiet 0 ms; blind for 76 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 18 | honest-click-2 | clicks the first document's title bar |  | quiet 337 ms; blind for 74 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 19 | honest-minimize | Terminal's window is minimized | shell ×1 (8, 171 ms) | quiet 0 ms; blind for 45 ms |  | ✔ | ~ |  |  | ✔ | ✔ |
| 20 | keyboard-taken | OFFENCE: after the switch another app, with no window to show, takes the keyboard | shell ×1 (9, 260 ms) | quiet 0 ms; blind for 74 ms |  | ✘ | ✔ | ✔ |  | ✘ | ✔ |
| 21 | honest-click-3 | clicks the first document's title bar |  | quiet 419 ms; blind for 79 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 22 | comes-forward | OFFENCE: nobody does anything, and an app comes forward by itself |  | quiet 0 ms; blind for 77 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ |
| 23 | honest-click-4 | clicks the first document's title bar |  | quiet 373 ms; blind for 66 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 24 | honest-drag | drags the first document a little way by its title bar |  | quiet 1040 ms; blind for 78 ms | ✔ | ✔ | ✘ |  |  | ✔ | ✔ |
| 25 | out-of-the-hand | OFFENCE: while the button is down the dragged window is pulled away |  | quiet 1069 ms; blind for 82 ms | ✔ | ✔ | ✘ |  |  | ✔ | ✔ |
| 26 | answers-late | OFFENCE: a key is pressed, and the window moves two seconds later | oak ×1 (1, 0 ms) | quiet 0 ms; blind for 73 ms |  | ✔ | ✘ | ✔ |  | ✔ | ✔ |
| 27 | honest-idle | nobody does anything for three seconds |  | quiet 0 ms; blind for 79 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 28 | wrong-size | OFFENCE: everything is given back, but one window keeps a size that is not its own | oak ×1 (1, 0 ms), grove ×1 (1, 0 ms) | quiet 1040 ms; blind for 70 ms |  |  | ✔ |  | ✘ | ✔ | ✔ |
| 29 | honest-give-back | now it gets its own size and place back too | oak ×1 (1, 0 ms) | quiet 0 ms; blind for 64 ms |  |  | ✔ |  | ✘ | ✔ | ✔ |
| 30 | left-out | OFFENCE: everything should be in view, and one window is in the corner | grove ×1 (1, 0 ms) | quiet 1063 ms; blind for 250 ms |  |  | ✔ |  |  | ✘ | ✔ |
| 31 | honest-return-2 | it comes back | grove ×1 (1, 0 ms) | quiet 0 ms; blind for 134 ms |  | ✔ | ~ |  |  | ✔ | ✔ |
| 32 | vanishes | OFFENCE: a window is closed, and nobody asked for that |  | quiet 0 ms; blind for 82 ms |  | ✔ | ✔ | ✔ |  | ✘ | ✔ |
