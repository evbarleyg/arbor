22 steps in 84 s, 20 of them judged, 6 with a rule broken. The sampler: samples 2731 seconds 75.0 hz 36.4 cost-ms 2.48 late 7 longest-gap-ms 227 whole-samples 3102 whole-seconds 85.2 whole-late 15.
Input: 47 presses, releases, keys and scrolls reached the apps, half of them within 486 µs, 99 in 100 within 122846 µs, the latest after 122846 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 1, 3582, 3582; dragged 32, 348, 3524; forward 4, 117628, 122846; key 5, 486, 551; up 5, 7663, 81886. `forward`: a press on a window of an app that was not in front.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 19 | 2 | 12 frame, 13 frame-again |
| 3 | no jolts: a window moves once, to where it ends up | 20 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 15 | 1 | 20 drag-the-gap |
| 5 | quitting, Float All and pause give windows their own sizes back | 4 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 5 | 0 |  |
| L | no window is lost or stuck | 20 | 0 |  |
| - | what the script itself checked | 20 | 4 | 7 dock-right, 9 click-back, 18 overlap-again, 20 drag-the-gap |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **12 frame** (presses ⌃⌥↩): mail (w40) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 201,61 941×530 · +455 ms 1343,626 941×530
- ~ **12 frame** (presses ⌃⌥↩): w42 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 437,118 470×416 · +455 ms 1579,683 470×416
- ✘ **13 frame-again** (and again): mail (w40) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1343,626 941×530 · +291 ms 201,61 941×530
- ~ **13 frame-again** (and again): w42 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 1579,683 470×416 · +291 ms 437,118 470×416
- ~ **17 tile** (asks for tiles, and docks Mail at the right): w42 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 437,118 470×416 · +151 ms 1549,683 470×416
- ~ **18 overlap-again** (asks for the overlap again): w42 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 1549,683 470×416 · +123 ms 657,146 470×416
- ~ **19 float-mail-again** (floats Mail): w42 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 657,146 470×416 · +114 ms 609,147 470×416 · +161 ms 639,147 470×416

### Rule 4: the window you switch to comes to the front and into view

- ✘ **20 drag-the-gap** (drags the gap at the right of Notes 300 points to the left): the app in front changed (to process 6136), and nobody switched [focus]

### Rule -: what the script itself checked

- ✘ **7 dock-right** (presses ⌃⌥→): not so: Mail is docked [script]
- ✘ **7 dock-right** (presses ⌃⌥→): not so: Mail is in view [script]
- ✘ **7 dock-right** (presses ⌃⌥→): not so: state says that one of them hangs over its place [script]
- ✘ **7 dock-right** (presses ⌃⌥→): not so: the one the key named lies in front [script]
- ✘ **9 click-back** (clicks the part of Mail that shows): not so: Mail lies in front [script]
- ✘ **18 overlap-again** (asks for the overlap again): not so: the overlap is as it was [script]
- ✘ **20 drag-the-gap** (drags the gap at the right of Notes 300 points to the left): not so: the gap followed the pointer under the window: the place is some 300 points short [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: two apps are open

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-notes | opens notes |  | quiet 365 ms; blind for 164 ms |  |  |  |  |  |  |  |  |
| 2 | open-mail | opens mail |  | quiet 890 ms; blind for 688 ms |  |  |  |  |  |  |  |  |

### The coach's first two keys

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 3 | launch | starts Arbor |  | quiet 919 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 4 | click-notes | clicks Notes' title bar |  | quiet 431 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 5 | dock-left | presses ⌃⌥← | notes ×1 (2, 27 ms) | quiet 732 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 6 | click-mail | clicks Mail's title bar |  | quiet 494 ms; blind for 131 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 7 | dock-right | presses ⌃⌥→ |  | quiet 386 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |

### Which lies in front later is macOS's business

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 8 | click-the-one-behind | clicks the part of Notes that shows |  | quiet 378 ms; blind for 121 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 9 | click-back | clicks the part of Mail that shows |  | quiet 373 ms; blind for 227 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✘ |
| 10 | cmd-tab | presses ⌘Tab |  | quiet 408 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 11 | idle | does nothing for ten seconds |  | quiet 363 ms; blind for 127 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### Framed and back, and one step back

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 12 | frame | presses ⌃⌥↩ | notes ×1 (1, 0 ms), mail ×1 (1, 0 ms), w42 ×1 (1, 0 ms) | quiet 999 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 13 | frame-again | and again | notes ×1 (1, 0 ms), mail ×1 (1, 0 ms), w42 ×1 (1, 0 ms) | quiet 528 ms; blind for 169 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 14 | undo | takes the last dock back | notes ×1 (1, 0 ms) | quiet 880 ms |  | ✔ | ✔ |  | ✔ |  | ✔ | ✔ |
| 15 | redo | and docks it again | notes ×1 (2, 63 ms) | quiet 1010 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### It ends when the neighbour goes

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 16 | float-mail | floats Mail |  | quiet 374 ms |  | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ |

### The option: the tile, as it was

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 17 | tile | asks for tiles, and docks Mail at the right | mail ×1 (1, 0 ms), w42 ×1 (1, 0 ms) | quiet 1029 ms |  | ~ | ✔ | ✔ |  |  | ✔ | ✔ |
| 18 | overlap-again | asks for the overlap again | mail ×1 (1, 0 ms), w42 ×1 (1, 0 ms) | quiet 370 ms |  | ~ | ✔ | ✔ |  |  | ✔ | ✘ |

### A gap dragged until it lies under a window

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 19 | float-mail-again | floats Mail | notes ×1 (1, 0 ms), mail ×1 (2, 47 ms), w42 ×1 (2, 47 ms) | quiet 1269 ms |  | ~ | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 20 | drag-the-gap | drags the gap at the right of Notes 300 points to the left |  | quiet 428 ms; blind for 118 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✘ |
| 21 | idle-after-the-drag | does nothing for three seconds |  | quiet 403 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |

### The way out

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 22 | quit | quits Arbor | notes ×1 (2, 75 ms) | quiet 741 ms |  |  | ✔ |  | ✔ |  | ✔ | ✔ |
