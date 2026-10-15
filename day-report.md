22 steps in 72 s, 14 of them judged, 6 with a rule broken. The sampler: samples 1314 seconds 55.9 hz 23.5 cost-ms 9.01 late 112 longest-gap-ms 1357 whole-samples 1731 whole-seconds 73.6 whole-late 155.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 12 | 1 | 4 dock-left |
| 3 | no jolts: a window moves once, to where it ends up | 20 | 2 | 12 arrange-3, 18 arrange-6 |
| 4 | the window you switch to comes to the front and into view | 10 | 2 | 4 dock-left, 5 dock-right |
| 5 | quitting, Float All and pause give windows their own sizes back | 5 | 1 | 9 float-all |
| 6 | what a person presses reaches the apps, at once | 0 | 0 |  |
| L | no window is lost or stuck | 20 | 0 |  |
| - | what the script itself checked | 20 | 1 | 22 quit |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **4 dock-left** (docks Safari at the left): notes (w37) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 300,105 1000×660 · +194 ms 300,105 794×660 · +203 ms 806,105 794×660

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **12 arrange-3** (chooses Arrange Windows with 3 windows open): notes (w37) went 146 points out of its way before it ended up [jolt]
  - +0 ms 806,43 782×767 · +258 ms 806,43 709×767 · +378 ms 806,43 782×767
- ~ **12 arrange-3** (chooses Arrange Windows with 3 windows open): w62 of Mail went 238 points out of its way before it ended up [jolt]
  - +0 ms 565,179 470×416 · +159 ms 446,124 470×416 · +399 ms 1805,822 470×416
- ✘ **18 arrange-6** (chooses Arrange Windows with 6 windows open): calendar (w88) moved 2 times [jolt]
  - +0 ms 200,86 935×598 · +159 ms 200,86 680×503 · +451 ms 187,43 680×503

### Rule 4: the window you switch to comes to the front and into view

- ✘ **4 dock-left** (docks Safari at the left): the app in front changed (to process 9860), and nobody switched [focus]
- ✘ **5 dock-right** (docks Notes at the right): the app in front changed (to process 10080), and nobody switched [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **9 float-all** (floats everything): safari (w32) has its size back but not its place: 0,31 1324×790, it was at 138,31 1324×791 [size-lost]
- ✘ **9 float-all** (floats everything): notes (w37) has its size back but not its place: 600,97 1000×660, it was at 300,105 1000×660 [size-lost]

### Rule -: what the script itself checked

- ✘ **22 quit** (quits Arbor): Arbor's process ended, and nobody asked it to [crash]
- ✘ **22 quit** (quits Arbor): the witness at the end of the event taps saw nothing all day [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: two apps are open

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-safari | opens safari |  | quiet 574 ms; blind for 972 ms |  |  |  |  |  |  |  |  |
| 2 | open-notes | opens notes |  | quiet 486 ms; blind for 199 ms |  |  |  |  |  |  |  |  |

### Two docks are two halves

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 3 | launch | starts Arbor |  | quiet 928 ms; blind for 113 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 4 | dock-left | docks Safari at the left | safari ×1 (1, 0 ms), notes ×1 (2, 9 ms) | quiet 948 ms; blind for 131 ms |  | ✘ | ✔ | ✘ |  |  | ✔ | ✔ |
| 5 | dock-right | docks Notes at the right | notes ×1 (2, 127 ms) | quiet 804 ms; blind for 129 ms |  | ✔ | ✔ | ✘ |  |  | ✔ | ✔ |

### Whoever is left alone stays as it is

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 6 | float-notes | floats Notes | notes ×1 (2, 117 ms) | quiet 1050 ms; blind for 120 ms |  | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 7 | dock-right-again | docks Notes at the right again | notes ×1 (2, 68 ms) | quiet 1298 ms; blind for 116 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 8 | float-safari | floats Safari, the one that was docked first | safari ×1 (2, 32 ms) | quiet 1047 ms; blind for 134 ms |  | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 9 | float-all | floats everything | notes ×1 (2, 21 ms) | quiet 1006 ms; blind for 121 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |

### Arrange Windows leaves nothing over

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 10 | arrange-2 | chooses Arrange Windows with 2 windows open | safari ×1 (2, 42 ms), notes ×1 (1, 0 ms) | quiet 910 ms; blind for 109 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 11 | open-mail | opens mail |  | quiet 621 ms; blind for 333 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 12 | arrange-3 | chooses Arrange Windows with 3 windows open | safari ×1 (1, 0 ms), notes ×1 (2, 120 ms), mail ×1 (2, 240 ms), w62 ×1 (2, 240 ms) | quiet 814 ms; blind for 112 ms |  |  | ✘ | ✔ |  |  | ✔ | ✔ |
| 13 | open-textedit | opens textedit |  | quiet 911 ms; blind for 480 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 14 | arrange-4 | chooses Arrange Windows with 4 windows open | notes ×1 (2, 111 ms), textedit ×1 (3, 162 ms) | quiet 810 ms; blind for 878 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 15 | open-terminal | opens terminal |  | quiet 719 ms; blind for 339 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 16 | arrange-5 | chooses Arrange Windows with 5 windows open | safari ×1 (1, 0 ms), notes ×1 (1, 0 ms), textedit ×1 (2, 82 ms), terminal ×1 (3, 205 ms) | quiet 614 ms; blind for 1357 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 17 | open-calendar | opens calendar |  | quiet 943 ms; blind for 328 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 18 | arrange-6 | chooses Arrange Windows with 6 windows open | safari ×1 (1, 0 ms), notes ×1 (1, 0 ms), textedit ×1 (2, 18 ms), terminal ×1 (3, 216 ms), calendar ×2 (2, 292 ms) | quiet 655 ms; blind for 221 ms |  |  | ✘ | ✔ |  |  | ✔ | ✔ |

### The Desktop is still a place to go

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 19 | desktop | goes to the Desktop | notes ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 1233 ms; blind for 118 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 20 | back | and back | notes ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 1022 ms; blind for 120 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### The way out

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 21 | float-all-at-the-end | floats everything | safari ×1 (2, 27 ms), notes ×1 (2, 114 ms), mail ×1 (1, 0 ms), w62 ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (3, 44 ms), calendar ×1 (1, 0 ms) | quiet 1210 ms; blind for 123 ms |  |  | ✔ |  | ✔ |  | ✔ | ✔ |
| 22 | quit | quits Arbor |  | quiet 898 ms; blind for 123 ms |  |  | ✔ |  | ✔ |  | ✔ | ✘ |
