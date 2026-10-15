97 steps in 354 s, 85 of them judged, 3 with a rule broken. The sampler: samples 9360 seconds 276.1 hz 33.9 cost-ms 3.51 late 38 longest-gap-ms 220 whole-samples 12071 whole-seconds 356.0 whole-late 166.
Input: 78 presses, releases, keys and scrolls reached the apps, half of them within 437 µs, 99 in 100 within 161318 µs, the latest after 161318 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 1, 1085, 1085; forward 5, 104289, 161318; key 66, 395, 3420; up 6, 46828, 55433. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 71714; up 8, 5076.
The round of input `started` (events, half within µs): forward 8, 68600; up 8, 2353.
The round of input `last` (events, half within µs): down 13, 2328; dragged 20, 437; forward 13, 76401; key 13, 396; scroll 28, 481; up 26, 826.
The round of input `after` (events, half within µs): forward 8, 78610; up 8, 5276.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 51 | 1 | 67 view-home |
| 3 | no jolts: a window moves once, to where it ends up | 85 | 1 | 64 larger-font |
| 4 | the window you switch to comes to the front and into view | 49 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 1 | 1 | 87 quit |
| 6 | what a person presses reaches the apps, at once | 19 | 0 |  |
| L | no window is lost or stuck | 85 | 0 |  |
| - | what the script itself checked | 85 | 0 |  |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **67 view-home** (presses ⌃⌥0): terminal (w49) is not back where it was after step 62: 12,43 557×757, it was at 12,43 555×769 [moved-unasked]

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **19 dock-right** (presses ⌃⌥⌘ and the right arrow): the last window came to rest 724 ms after the key or the button [slow]
- ✘ **64 larger-font** (presses ⌘+ in Terminal): terminal (w49) moved 2 times [jolt]
  - +0 ms 12,43 555×769 · +232 ms 12,43 629×791 · +530 ms 12,43 557×774 · +571 ms 12,43 557×757
- ~ **71 view-home** (presses ⌃⌥0): the last window came to rest 713 ms after the key or the button [slow]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **87 quit** (chooses Quit Arbor in Arbor's menu): terminal (w49) is 40,51 877×502; its own size was 40,51 877×499 [size-lost]

### Rule -: what the script itself checked

- ~ **64 larger-font** (presses ⌘+ in Terminal): w49 fills 557×757 of its slot 12,43 557×767 [script]
- ~ **67 view-home** (presses ⌃⌥0): w49 fills 557×757 of its slot 12,43 557×767 [script]
- ~ **69 view-home** (presses ⌃⌥0): w49 fills 557×757 of its slot 12,43 557×767 [script]
- ~ **71 view-home** (presses ⌃⌥0): w49 fills 557×757 of its slot 12,43 557×767 [script]
- ~ **73 view-home** (presses ⌃⌥0): w49 fills 557×757 of its slot 12,43 557×767 [script]
- ~ **75 view-home** (presses ⌃⌥0): w49 fills 557×757 of its slot 12,43 557×767 [script]
- ~ **77 view-home** (presses ⌃⌥0): w49 fills 557×757 of its slot 12,43 557×767 [script]
- ~ **79 view-home** (presses ⌃⌥0): w49 fills 557×757 of its slot 12,43 557×767 [script]
- ~ **81 view-home** (presses ⌃⌥0): w49 fills 557×757 of its slot 12,43 557×767 [script]
- ~ **83 view-home** (presses ⌃⌥0): w49 fills 557×757 of its slot 12,43 557×767 [script]
- ~ **85 view-home** (presses ⌃⌥0): w49 fills 557×757 of its slot 12,43 557×767 [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 661 ms; blind for 232 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 462 ms; blind for 1073 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (1, 0 ms) | quiet 1878 ms; blind for 1767 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (3, 315 ms) | quiet 989 ms; blind for 345 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (4, 214 ms), w53 ×2 (8, 1504 ms), w55 ×1 (7, 249 ms) | quiet 424 ms; blind for 899 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×2 (3, 334 ms) | quiet 1082 ms; blind for 157 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×2 (2, 747 ms) | quiet 927 ms; blind for 747 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview |  | quiet 1676 ms; blind for 1410 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | mail ×1 (1, 0 ms), w71 ×1 (2, 155 ms) | quiet 401 ms; blind for 1107 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (40, 4552 ms) | quiet 1501 ms; blind for 106 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (32, 2488 ms) | quiet 998 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 401 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 708 ms; blind for 176 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | launch | starts Arbor |  | quiet 964 ms; blind for 173 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 15 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 641 ms; blind for 128 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 16 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 414 ms; blind for 191 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | dock-left | presses ⌃⌥⌘ and the left arrow | terminal ×1 (1, 0 ms) | quiet 720 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 18 | click-safari | clicks safari's title bar |  | quiet 434 ms; blind for 178 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | dock-right | presses ⌃⌥⌘ and the right arrow | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms) | quiet 696 ms; blind for 126 ms |  | ✔ | ~ | ✔ |  |  | ✔ | ✔ |

### Ten times away and back

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 20 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 897 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 21 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 777 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 22 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 889 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 23 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 874 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 24 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1123 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 25 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 756 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 26 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1123 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 27 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 851 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 28 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1120 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 29 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 809 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 30 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 922 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 31 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 856 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 32 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1227 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 33 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 889 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 34 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1069 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 35 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 721 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 36 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 763 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 37 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 865 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 38 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1072 ms; blind for 107 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 39 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 809 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### Another width

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 40 | click-terminal | clicks terminal's title bar |  | quiet 506 ms; blind for 144 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | grow | presses ⌃⌥⌘= | terminal ×1 (1, 0 ms) | quiet 632 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 42 | click-safari | clicks safari's title bar |  | quiet 451 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1251 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 44 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 938 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 45 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1080 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 46 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 992 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 47 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1445 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 48 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 833 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 49 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 884 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 50 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 795 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 51 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1106 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 52 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 903 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 53 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 841 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 54 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 753 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 55 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1032 ms; blind for 103 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 56 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 782 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 57 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1080 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 58 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 765 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 59 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 982 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 60 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 674 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 61 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1180 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 62 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 894 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### A larger font

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 63 | click-terminal | clicks terminal's title bar |  | quiet 499 ms; blind for 129 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 64 | larger-font | presses ⌘+ in Terminal | terminal ×2 (3, 339 ms) | quiet 1126 ms; blind for 107 ms |  |  | ✘ |  |  |  | ✔ | ~ |
| 65 | click-safari | clicks safari's title bar |  | quiet 394 ms; blind for 220 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 66 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1124 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 67 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 924 ms |  | ✘ | ✔ |  |  |  | ✔ | ~ |
| 68 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 936 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 69 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 802 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 70 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1204 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 71 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 818 ms |  | ✔ | ~ |  |  |  | ✔ | ~ |
| 72 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1143 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 73 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 874 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 74 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1091 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 75 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 777 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 76 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1002 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 77 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 727 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 78 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1093 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 79 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 913 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 80 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1057 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 81 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 848 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 82 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 973 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 83 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 991 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |
| 84 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1104 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 85 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1055 ms; blind for 119 ms |  | ✔ | ✔ |  |  |  | ✔ | ~ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 86 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 886 ms; blind for 172 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 87 | quit | chooses Quit Arbor in Arbor's menu | safari ×1 (2, 83 ms), terminal ×1 (2, 31 ms) | quiet 579 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 88 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 635 ms; blind for 142 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 89 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 537 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 90 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 372 ms; blind for 140 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 91 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 430 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 92 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 537 ms; blind for 124 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 93 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 526 ms; blind for 105 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 94 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 384 ms; blind for 147 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 95 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 737 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 96 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 403 ms; blind for 135 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 97 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 360 ms; blind for 220 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
