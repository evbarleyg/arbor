22 steps in 87 s, 18 of them judged, 1 with a rule broken. The sampler: samples 2806 seconds 77.4 hz 36.2 cost-ms 3.35 late 16 longest-gap-ms 708 whole-samples 3186 whole-seconds 87.9 whole-late 20.
Input: 47 presses, releases, keys and scrolls reached the apps, half of them within 862 µs, 99 in 100 within 147308 µs, the latest after 147308 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 1, 14131, 14131; dragged 32, 714, 3461; forward 4, 137986, 147308; key 5, 542, 1057; up 5, 6455, 94645. `forward`: a press on a window of an app that was not in front.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 19 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 20 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 15 | 1 | 20 drag-the-gap |
| 5 | quitting, Float All and pause give windows their own sizes back | 4 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 5 | 0 |  |
| L | no window is lost or stuck | 20 | 0 |  |
| - | what the script itself checked | 20 | 1 | 20 drag-the-gap |

## Findings

### Rule 4: the window you switch to comes to the front and into view

- ✘ **20 drag-the-gap** (drags the gap at the right of Notes 300 points to the left): the app in front changed (to process 4701), and nobody switched [focus]

### Rule -: what the script itself checked

- ✘ **20 drag-the-gap** (drags the gap at the right of Notes 300 points to the left): not so: the gap followed the pointer under the window: the place is some 300 points short [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: two apps are open

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-notes | opens notes |  | quiet 371 ms; blind for 134 ms |  |  |  |  |  |  |  |  |
| 2 | open-settings | opens settings |  | quiet 458 ms; blind for 683 ms |  |  |  |  |  |  |  |  |

### The coach's first two keys

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 3 | launch | starts Arbor |  | quiet 850 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 4 | click-notes | clicks Notes' title bar |  | quiet 462 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 5 | dock-left | presses ⌃⌥← | notes ×1 (1, 0 ms) | quiet 858 ms; blind for 200 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 6 | click-settings | clicks System Settings' title bar |  | quiet 474 ms; blind for 306 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 7 | dock-right | presses ⌃⌥→ | settings ×1 (1, 0 ms) | quiet 434 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### Which lies in front later is macOS's business

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 8 | click-the-one-behind | clicks the part of Notes that shows |  | quiet 382 ms; blind for 155 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 9 | click-back | clicks the part of System Settings that shows |  | quiet 405 ms; blind for 159 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 10 | cmd-tab | presses ⌘Tab |  | quiet 440 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 11 | idle | does nothing for ten seconds |  | quiet 379 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### Framed and back, and one step back

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 12 | frame | presses ⌃⌥↩ | notes ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 990 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 13 | frame-again | and again | notes ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 742 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 14 | undo | takes the last dock back | settings ×1 (1, 0 ms) | quiet 983 ms |  | ✔ | ✔ |  | ✔ |  | ✔ | ✔ |
| 15 | redo | and docks it again | settings ×1 (1, 0 ms) | quiet 966 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### It ends when the neighbour goes

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 16 | float-settings | floats System Settings | settings ×1 (2, 41 ms) | quiet 948 ms |  | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ |

### The option: the tile, as it was

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 17 | tile | asks for tiles, and docks System Settings at the right | settings ×1 (1, 0 ms) | quiet 1045 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 18 | overlap-again | asks for the overlap again | settings ×1 (1, 0 ms) | quiet 1179 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### A gap dragged until it lies under a window

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 19 | float-settings-again | floats System Settings | settings ×1 (2, 56 ms) | quiet 1048 ms; blind for 146 ms |  | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 20 | drag-the-gap | drags the gap at the right of Notes 300 points to the left |  | quiet 426 ms; blind for 708 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✘ |
| 21 | idle-after-the-drag | does nothing for three seconds |  | quiet 387 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### The way out

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 22 | quit | quits Arbor | notes ×1 (2, 102 ms) | quiet 521 ms |  |  | ✔ |  | ✔ |  | ✔ | ✔ |
