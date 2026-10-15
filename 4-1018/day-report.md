116 steps in 521 s, 95 of them judged, 16 with a rule broken. The sampler: samples 13648 seconds 391.7 hz 34.8 cost-ms 4.09 late 67 longest-gap-ms 1356 whole-samples 18209 whole-seconds 522.6 whole-late 182.
Input: 225 presses, releases, keys and scrolls reached the apps, half of them within 656 µs, 99 in 100 within 97965 µs, the latest after 164056 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 37, 1040, 5341; dragged 99, 632, 10371; forward 4, 97965, 164056; key 44, 424, 1976; up 41, 868, 99259. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): down 13, 978; dragged 20, 266; forward 12, 11438; key 13, 461; scroll 28, 301; up 25, 408.
The round of input `started` (events, half within µs): down 13, 1006; dragged 20, 494; forward 12, 13177; key 13, 600; scroll 28, 396; up 25, 597.
The round of input `last` (events, half within µs): .
The round of input `after` (events, half within µs): down 13, 738; dragged 20, 221; forward 12, 10222; key 13, 471; scroll 28, 273; up 25, 387.
Judged: no kind. Not down: fewer than 10 such events in a round with Arbor. Not forward: fewer than 10 such events in a round with Arbor. Not up: fewer than 10 such events in a round with Arbor. Not key: fewer than 10 such events in a round with Arbor. Not dragged: fewer than 10 such events in a round with Arbor. Not scroll: fewer than 10 such events in a round with Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 3 | 0 |  |
| 2 | nothing moves that the person did not move | 77 | 12 | 19 view-all, 31 dock-down, 34 minimize-textedit, 35 restore-textedit, 38 dock-up, 53 unhide-edge, 55 dock-up, 60 dock-right, 67 drag-firefox-by, 71 dock-right, 104 hide-terminal, 105 unhide-terminal |
| 3 | no jolts: a window moves once, to where it ends up | 101 | 3 | 53 unhide-edge, 58 leave-full-screen, 60 dock-right |
| 4 | the window you switch to comes to the front and into view | 67 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 3 | 2 | 61 quit, 108 quit |
| 6 | what a person presses reaches the apps, at once | 53 | 0 |  |
| L | no window is lost or stuck | 101 | 0 |  |
| - | what the script itself checked | 101 | 3 | 52 leave-alone, 61 quit, 108 quit |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **19 view-all** (presses ⌃⌥Space): terminal (w1731) is not back where it was after step 18: 723,321 877×499, it was at 737,321 877×499 [moved-unasked]
- ✘ **31 dock-down** (presses ⌃⌥⌘ and the down arrow): chrome (w1687) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 22,53 1200×747 · +1477 ms 22,31 1200×391
- ✘ **31 dock-down** (presses ⌃⌥⌘ and the down arrow): firefox (w1699) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,31 1280×711 · +1477 ms 4,31 1280×391
- ✘ **31 dock-down** (presses ⌃⌥⌘ and the down arrow): edge (w1702) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 22,53 1200×747 · +1477 ms 22,31 1200×391
- ✘ **31 dock-down** (presses ⌃⌥⌘ and the down arrow): textedit (w1723) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 463,114 674×440 · +1477 ms 463,31 674×391
- ✘ **31 dock-down** (presses ⌃⌥⌘ and the down arrow): terminal (w1731) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 723,321 877×499 · +1477 ms 723,31 877×379
- ✘ **31 dock-down** (presses ⌃⌥⌘ and the down arrow): safari-2 (w1736) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 96,60 1324×374 · +1477 ms 96,48 1324×374
- ✘ **31 dock-down** (presses ⌃⌥⌘ and the down arrow): chrome-2 (w1739) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 44,75 1200×747 · +1477 ms 44,31 1200×391
- ✘ **31 dock-down** (presses ⌃⌥⌘ and the down arrow): edge-2 (w1754) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 44,75 1200×747 · +1477 ms 44,31 1200×391
- ✘ **34 minimize-textedit** (presses ⌘M): terminal (w1731) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 723,31 877×379 · +1578 ms 723,31 877×394
- ✘ **35 restore-textedit** (clicks its miniature in the Dock): terminal (w1731) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 723,31 877×394 · +1538 ms 723,31 877×379
- ✘ **38 dock-up** (presses ⌃⌥⌘ and the up arrow): safari (w1681) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 67,31 1324×374 · +1428 ms 67,304 1324×245
- ✘ **38 dock-up** (presses ⌃⌥⌘ and the up arrow): chrome (w1687) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 22,31 1200×391 · +1428 ms 22,239 1200×375
- ✘ **38 dock-up** (presses ⌃⌥⌘ and the up arrow): firefox (w1699) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,31 1280×391 · +1428 ms 4,304 1280×245
- ✘ **38 dock-up** (presses ⌃⌥⌘ and the up arrow): edge (w1702) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 22,31 1200×391 · +1428 ms 22,239 1200×375
- ✘ **38 dock-up** (presses ⌃⌥⌘ and the up arrow): textedit (w1723) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 463,31 674×391 · +1428 ms 463,304 674×245
- ✘ **38 dock-up** (presses ⌃⌥⌘ and the up arrow): safari-2 (w1736) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 96,48 1324×374 · +1428 ms 96,304 1324×245
- ✘ **38 dock-up** (presses ⌃⌥⌘ and the up arrow): chrome-2 (w1739) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 44,31 1200×391 · +1428 ms 44,239 1200×375
- ✘ **38 dock-up** (presses ⌃⌥⌘ and the up arrow): edge-2 (w1754) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 44,31 1200×391 · +1428 ms 44,239 1200×375
- ✘ **38 dock-up** (presses ⌃⌥⌘ and the up arrow): desk-a (w1769) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,70 300×190 · +1428 ms 40,304 300×190
- ✘ **38 dock-up** (presses ⌃⌥⌘ and the up arrow): desk-b (w1771) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 360,70 300×190 · +1428 ms 360,304 300×190
- ✘ **53 unhide-edge** (clicks its icon in the Dock): edge-2 (w1754) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 44,239 1200×375 · +317 ms 44,75 1200×747
- ✘ **55 dock-up** (presses ⌃⌥⌘ and the up arrow): chrome (w1687) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 22,53 1200×747 · +1134 ms 22,434 1200×391
- ✘ **55 dock-up** (presses ⌃⌥⌘ and the up arrow): firefox (w1699) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,31 1280×711 · +1134 ms 4,434 1280×391
- ✘ **55 dock-up** (presses ⌃⌥⌘ and the up arrow): edge (w1702) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 22,53 1200×747 · +1134 ms 22,434 1200×391
- ✘ **55 dock-up** (presses ⌃⌥⌘ and the up arrow): safari-2 (w1736) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 96,60 1324×374 · +1134 ms 96,434 1324×374
- ✘ **55 dock-up** (presses ⌃⌥⌘ and the up arrow): chrome-2 (w1739) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 44,75 1200×747 · +1134 ms 44,434 1200×391
- ✘ **55 dock-up** (presses ⌃⌥⌘ and the up arrow): edge-2 (w1754) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 44,75 1200×747 · +1134 ms 44,434 1200×391
- ✘ **55 dock-up** (presses ⌃⌥⌘ and the up arrow): desk-a (w1769) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,70 300×190 · +1134 ms 40,434 300×190
- ✘ **55 dock-up** (presses ⌃⌥⌘ and the up arrow): desk-b (w1771) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 360,70 300×190 · +1134 ms 360,434 300×190
- ✘ **55 dock-up** (presses ⌃⌥⌘ and the up arrow): textedit (w1872) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +1134 ms 165,434 673×391
- ✘ **60 dock-right** (presses ⌃⌥⌘ and the right arrow): chrome (w1687) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 22,53 1200×747 · +1828 ms 0,212 794×375
- ✘ **60 dock-right** (presses ⌃⌥⌘ and the right arrow): firefox (w1699) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,31 1280×711 · +1828 ms 0,275 794×249
- ✘ **60 dock-right** (presses ⌃⌥⌘ and the right arrow): edge (w1702) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 22,53 1200×747 · +1828 ms 0,212 794×375
- ✘ **60 dock-right** (presses ⌃⌥⌘ and the right arrow): safari-2 (w1736) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 96,60 1324×374 · +1828 ms 0,275 794×249
- ✘ **60 dock-right** (presses ⌃⌥⌘ and the right arrow): chrome-2 (w1739) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 44,75 1200×747 · +1828 ms 0,212 794×375
- ✘ **60 dock-right** (presses ⌃⌥⌘ and the right arrow): edge-2 (w1754) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 44,75 1200×747 · +1828 ms 0,212 794×375
- ✘ **60 dock-right** (presses ⌃⌥⌘ and the right arrow): desk-a (w1769) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,70 300×190 · +1828 ms 40,275 300×190
- ✘ **60 dock-right** (presses ⌃⌥⌘ and the right arrow): desk-b (w1771) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 360,70 300×190 · +1828 ms 360,275 300×190
- ✘ **60 dock-right** (presses ⌃⌥⌘ and the right arrow): textedit (w1872) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +1828 ms 121,275 673×249
- ✘ **67 drag-firefox-by** (drags firefox, which floats, by its title bar 54 across and 57 down): safari (w1681) moved, and the step did not name it [moved-unasked]
  - +0 ms 12,43 782×220 · +5230 ms 12,43 574×220
- ✘ **67 drag-firefox-by** (drags firefox, which floats, by its title bar 54 across and 57 down): finder (w1721) moved, and the step did not name it [moved-unasked]
  - +0 ms 12,536 782×277 · +5230 ms 12,536 1086×277
- ✘ **67 drag-firefox-by** (drags firefox, which floats, by its title bar 54 across and 57 down): terminal (w1731) moved, and the step did not name it [moved-unasked]
  - +0 ms 807,44 779×769 · +5230 ms 1110,43 478×769
- ✘ **71 dock-right** (presses ⌃⌥⌘ and the right arrow): chrome (w1687) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 22,53 1200×747 · +928 ms 0,53 794×747
- ✘ **71 dock-right** (presses ⌃⌥⌘ and the right arrow): edge (w1702) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 22,53 1200×747 · +928 ms 0,53 794×747
- ✘ **71 dock-right** (presses ⌃⌥⌘ and the right arrow): safari-2 (w1736) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 96,60 1324×374 · +928 ms 0,60 794×374
- ✘ **71 dock-right** (presses ⌃⌥⌘ and the right arrow): chrome-2 (w1739) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 44,75 1200×747 · +928 ms 0,75 794×747
- ✘ **71 dock-right** (presses ⌃⌥⌘ and the right arrow): edge-2 (w1754) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 44,75 1200×747 · +928 ms 0,75 794×747
- ✘ **104 hide-terminal** (presses ⌘H): chrome (w1687) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,784 1200×747 · +521 ms 22,411 1200×414
- ✘ **104 hide-terminal** (presses ⌘H): edge (w1702) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,784 1200×747 · +539 ms 22,411 1200×414
- ✘ **104 hide-terminal** (presses ⌘H): chrome-2 (w1739) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,784 1200×747 · +649 ms 44,411 1200×414
- ✘ **104 hide-terminal** (presses ⌘H): edge-2 (w1754) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,784 1200×747 · +737 ms 44,411 1200×414
- ✘ **104 hide-terminal** (presses ⌘H): desk-a (w1769) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,793 300×190 · +761 ms 40,411 300×190
- ✘ **104 hide-terminal** (presses ⌘H): desk-b (w1771) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,793 300×190 · +786 ms 360,411 300×190
- ✘ **104 hide-terminal** (presses ⌘H): textedit (w1872) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,793 673×439 · +786 ms 1599,793 673×414 · +812 ms 165,411 673×414
- ✘ **104 hide-terminal** (presses ⌘H): safari (w2012) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,773 1324×374 · +786 ms 96,411 1324×374
- ✘ **105 unhide-terminal** (clicks its icon in the Dock): chrome (w1687) is not back where it was after step 103: 22,411 1200×414, it was at 1599,784 1200×747 [moved-unasked]
- ✘ **105 unhide-terminal** (clicks its icon in the Dock): edge (w1702) is not back where it was after step 103: 22,411 1200×414, it was at 1599,784 1200×747 [moved-unasked]
- ✘ **105 unhide-terminal** (clicks its icon in the Dock): chrome-2 (w1739) is not back where it was after step 103: 44,411 1200×414, it was at 1599,784 1200×747 [moved-unasked]
- ✘ **105 unhide-terminal** (clicks its icon in the Dock): edge-2 (w1754) is not back where it was after step 103: 44,411 1200×414, it was at 1599,784 1200×747 [moved-unasked]
- ✘ **105 unhide-terminal** (clicks its icon in the Dock): desk-a (w1769) is not back where it was after step 103: 40,411 300×190, it was at 1599,793 300×190 [moved-unasked]
- ✘ **105 unhide-terminal** (clicks its icon in the Dock): desk-b (w1771) is not back where it was after step 103: 360,411 300×190, it was at 1599,793 300×190 [moved-unasked]
- ✘ **105 unhide-terminal** (clicks its icon in the Dock): textedit (w1872) is not back where it was after step 103: 165,411 673×414, it was at 1599,793 673×439 [moved-unasked]
- ✘ **105 unhide-terminal** (clicks its icon in the Dock): safari (w2012) is not back where it was after step 103: 96,411 1324×374, it was at 1599,773 1324×374 [moved-unasked]

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **31 dock-down** (presses ⌃⌥⌘ and the down arrow): the last window came to rest 1128 ms after the key or the button [slow]
- ~ **38 dock-up** (presses ⌃⌥⌘ and the up arrow): the last window came to rest 1143 ms after the key or the button [slow]
- ~ **44 pause** (presses ⌃⌥⎋): the last window came to rest 924 ms after the key or the button [slow]
- ~ **46 resume** (presses ⌃⌥⎋): the last window came to rest 832 ms after the key or the button [slow]
- ~ **49 view-in** (presses ⌃⌥↓): the last window came to rest 824 ms after the key or the button [slow]
- ✘ **53 unhide-edge** (clicks its icon in the Dock): edge (w1702) came into sight at 22,239 1200×375 and was then moved to 22,53 1200×747 [jolt]
  - +0 ms 22,239 1200×375 · +230 ms 22,53 1200×747
- ~ **55 dock-up** (presses ⌃⌥⌘ and the up arrow): the last window came to rest 770 ms after the key or the button [slow]
- ✘ **58 leave-full-screen** (presses ⌃⌘F again): chrome (w1687) moved 3 times [jolt]
  - +0 ms -810,53 1200×747 · +15 ms -424,53 1200×747 · +280 ms -335,53 1200×747 · +335 ms -175,53 1200×747 · +352 ms -139,53 1200×747 · +375 ms -106,53 1200×747 · +385 ms -76,53 1200×747 · +399 ms -50,53 1200×747 · +452 ms 6,53 1200×747 · +518 ms 22,53 1200×747 · +811 ms 22,434 1200×391
- ✘ **58 leave-full-screen** (presses ⌃⌘F again): firefox (w1699) moved 3 times [jolt]
  - +0 ms -828,31 1280×711 · +15 ms -442,31 1280×711 · +280 ms -353,31 1280×711 · +335 ms -193,31 1280×711 · +352 ms -157,31 1280×711 · +375 ms -124,31 1280×711 · +385 ms -94,31 1280×711 · +399 ms -68,31 1280×711 · +452 ms -12,31 1280×711 · +518 ms 4,31 1280×711 · +871 ms 4,434 1280×391
- ✘ **58 leave-full-screen** (presses ⌃⌘F again): edge (w1702) moved 3 times [jolt]
  - +0 ms -810,53 1200×747 · +15 ms -424,53 1200×747 · +280 ms -335,53 1200×747 · +335 ms -175,53 1200×747 · +352 ms -139,53 1200×747 · +375 ms -106,53 1200×747 · +385 ms -76,53 1200×747 · +399 ms -50,53 1200×747 · +452 ms 6,53 1200×747 · +518 ms 22,53 1200×747 · +944 ms 22,434 1200×391
- ✘ **58 leave-full-screen** (presses ⌃⌘F again): finder (w1721) moved 2 times [jolt]
  - +0 ms 767,773 1576×252 · +15 ms 1153,773 1576×252 · +280 ms 1242,773 1576×252 · +335 ms 1402,773 1576×252 · +352 ms 1438,773 1576×252 · +375 ms 1471,773 1576×252 · +385 ms 1501,773 1576×252 · +399 ms 1527,773 1576×252 · +452 ms 1583,773 1576×252 · +518 ms 1599,773 1576×252
- ✘ **58 leave-full-screen** (presses ⌃⌘F again): terminal (w1731) moved 2 times [jolt]
  - +0 ms 767,793 1577×244 · +15 ms 1153,793 1577×244 · +280 ms 1242,793 1577×244 · +335 ms 1402,793 1577×244 · +352 ms 1438,793 1577×244 · +375 ms 1471,793 1577×244 · +385 ms 1501,793 1577×244 · +399 ms 1527,793 1577×244 · +452 ms 1583,793 1577×244 · +518 ms 1599,793 1577×244
- ✘ **58 leave-full-screen** (presses ⌃⌘F again): safari-2 (w1736) moved 3 times [jolt]
  - +0 ms -736,60 1324×374 · +15 ms -350,60 1324×374 · +280 ms -261,60 1324×374 · +335 ms -101,60 1324×374 · +352 ms -65,60 1324×374 · +375 ms -32,60 1324×374 · +385 ms -2,60 1324×374 · +399 ms 24,60 1324×374 · +452 ms 80,60 1324×374 · +518 ms 96,60 1324×374 · +944 ms 96,434 1324×374
- ✘ **58 leave-full-screen** (presses ⌃⌘F again): chrome-2 (w1739) moved 3 times [jolt]
  - +0 ms -788,75 1200×747 · +15 ms -402,75 1200×747 · +280 ms -313,75 1200×747 · +335 ms -153,75 1200×747 · +352 ms -117,75 1200×747 · +375 ms -84,75 1200×747 · +385 ms -54,75 1200×747 · +399 ms -28,75 1200×747 · +452 ms 28,75 1200×747 · +518 ms 44,75 1200×747 · +964 ms 44,434 1200×391
- ✘ **58 leave-full-screen** (presses ⌃⌘F again): edge-2 (w1754) moved 3 times [jolt]
  - +0 ms -788,75 1200×747 · +15 ms -402,75 1200×747 · +280 ms -313,75 1200×747 · +335 ms -153,75 1200×747 · +352 ms -117,75 1200×747 · +375 ms -84,75 1200×747 · +385 ms -54,75 1200×747 · +399 ms -28,75 1200×747 · +452 ms 28,75 1200×747 · +518 ms 44,75 1200×747 · +1048 ms 44,434 1200×391
- ✘ **58 leave-full-screen** (presses ⌃⌘F again): desk-a (w1769) moved 3 times [jolt]
  - +0 ms -792,70 300×190 · +15 ms -406,70 300×190 · +280 ms -317,70 300×190 · +335 ms -157,70 300×190 · +352 ms -121,70 300×190 · +375 ms -88,70 300×190 · +385 ms -58,70 300×190 · +399 ms -32,70 300×190 · +452 ms 24,70 300×190 · +518 ms 40,70 300×190 · +1125 ms 40,434 300×190
- ✘ **58 leave-full-screen** (presses ⌃⌘F again): desk-b (w1771) moved 3 times [jolt]
  - +0 ms -472,70 300×190 · +15 ms -86,70 300×190 · +280 ms 3,70 300×190 · +335 ms 163,70 300×190 · +352 ms 199,70 300×190 · +375 ms 232,70 300×190 · +385 ms 262,70 300×190 · +399 ms 288,70 300×190 · +452 ms 344,70 300×190 · +518 ms 360,70 300×190 · +1125 ms 360,434 300×190
- ✘ **58 leave-full-screen** (presses ⌃⌘F again): textedit (w1872) moved 3 times [jolt]
  - +0 ms -667,65 673×439 · +15 ms -281,65 673×439 · +280 ms -192,65 673×439 · +335 ms -32,65 673×439 · +352 ms 4,65 673×439 · +375 ms 37,65 673×439 · +385 ms 67,65 673×439 · +399 ms 93,65 673×439 · +452 ms 149,65 673×439 · +518 ms 165,65 673×439 · +1125 ms 165,434 673×391
- ✘ **60 dock-right** (presses ⌃⌥⌘ and the right arrow): the last window came to rest 1513 ms after the key or the button [slow]
- ~ **74 view-in** (presses ⌃⌥↓): the last window came to rest 852 ms after the key or the button [slow]
- ~ **78 undo** (presses ⌃⌥Z): the last window came to rest 765 ms after the key or the button [slow]
- ~ **79 view-out** (presses ⌃⌥↑): the last window came to rest 728 ms after the key or the button [slow]
- ~ **90 view-frame** (presses ⌃⌥↩): the last window came to rest 801 ms after the key or the button [slow]
- ~ **93 drag-safari-to-left-edge** (drags safari by its title bar against the left edge of the screen and lets go): safari (w1681) changed its size while it was being dragged [jolt]
  - +0 ms -10,411 795×414 · +65 ms -18,413 795×414 · +103 ms -18,413 783×411 · +116 ms -15,412 783×411 · +156 ms 25,412 652×377 · +167 ms 17,413 652×377 · … 26 more … · +1763 ms -160,435 575×357 · +1828 ms -169,436 575×357 · +1861 ms -177,437 575×357 · +2195 ms -176,437 575×357 · +2254 ms -177,437 575×357
- ~ **96 view-frame** (presses ⌃⌥↩): the last window came to rest 1163 ms after the key or the button [slow]
- ~ **106 view-home** (presses ⌃⌥0): the last window came to rest 712 ms after the key or the button [slow]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **61 quit** (chooses Quit Arbor in Arbor's menu): terminal (w1731) is 737,321 863×499; its own size was 737,321 877×499 [size-lost]
- ✘ **108 quit** (chooses Quit Arbor in Arbor's menu): firefox (w1699) is 4,31 1280×711; its own size was 598,43 500×220 [size-lost]
- ✘ **108 quit** (chooses Quit Arbor in Arbor's menu): finder (w1721) has its size back but not its place: 95,389 920×435, it was at 340,119 920×436 [size-lost]
- ✘ **108 quit** (chooses Quit Arbor in Arbor's menu): terminal (w1731) is 737,321 863×499; its own size was 737,321 877×499 [size-lost]

### Rule -: what the script itself checked

- ✘ **52 leave-alone** (does nothing for half a minute): with nothing to do Arbor used 1.4 % of a core [busy]
- ✘ **61 quit** (chooses Quit Arbor in Arbor's menu): Arbor's process ended, and nobody asked it to [crash]
- ✘ **108 quit** (chooses Quit Arbor in Arbor's menu): Arbor's process ended, and nobody asked it to [crash]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-safari | opens safari |  | quiet 441 ms; blind for 804 ms |  |  |  |  |  |  |  |  |
| 2 | open-chrome | opens chrome |  | quiet 396 ms; blind for 1953 ms |  |  |  |  |  |  |  |  |
| 3 | open-firefox | opens firefox |  | quiet 383 ms; blind for 436 ms |  |  |  |  |  |  |  |  |
| 4 | open-edge | opens edge |  | quiet 360 ms; blind for 3765 ms |  |  |  |  |  |  |  |  |
| 5 | open-finder | opens finder | finder ×1 (7, 111 ms) | quiet 903 ms; blind for 176 ms |  |  |  |  |  |  |  |  |
| 6 | open-textedit | opens textedit | textedit ×1 (3, 249 ms) | quiet 1817 ms; blind for 684 ms |  |  |  |  |  |  |  |  |
| 7 | open-terminal | opens terminal | terminal ×1 (1, 0 ms) | quiet 897 ms; blind for 1249 ms |  |  |  |  |  |  |  |  |
| 8 | second-window-safari | brings safari forward and presses ⌘N |  | quiet 414 ms; blind for 1050 ms |  |  |  |  |  |  |  |  |
| 9 | second-window-chrome | brings chrome forward and presses ⌘N |  | quiet 383 ms; blind for 2670 ms |  |  |  |  |  |  |  |  |
| 10 | second-window-firefox | brings firefox forward and presses ⌘N |  | quiet 401 ms; blind for 695 ms |  |  |  |  |  |  |  |  |
| 11 | second-window-edge | brings edge forward and presses ⌘N | edge-2 ×2 (2, 1341 ms) | quiet 949 ms; blind for 1340 ms |  |  |  |  |  |  |  |  |
| 12 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | textedit ×3 (36, 4202 ms) | quiet 1467 ms; blind for 245 ms |  |  |  |  |  |  |  |  |
| 13 | tiling-acts-back | drags it away again, a hand's breadth down | textedit ×2 (28, 2788 ms) | quiet 1081 ms; blind for 417 ms |  |  |  |  |  |  |  |  |
| 14 | look-around | looks at the screen |  | quiet 415 ms |  |  |  |  |  |  |  |  |
| 15 | open-desks | opens the two windows that input is tried on | desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 417 ms; blind for 226 ms |  |  |  |  |  |  |  |  |
| 16 | input-before | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 839 ms; blind for 114 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 17 | launch | starts Arbor |  | quiet 896 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 18 | input-started | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 834 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | view-all | presses ⌃⌥Space | terminal ×1 (1, 0 ms) | quiet 702 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 20 | dock-icon-chrome | clicks chrome's icon in the Dock |  | quiet 366 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | view-all | presses ⌃⌥Space |  | quiet 584 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 22 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 457 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | window-menu-safari | chooses safari's first window in the Window menu |  | quiet 1446 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 410 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 25 | minimize-safari | presses ⌘M | safari ×1 (16, 471 ms) | quiet 715 ms; blind for 203 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 26 | view-in | presses ⌃⌥↓ |  | quiet 604 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 27 | click-wallpaper | clicks on the wallpaper | chrome ×1 (1, 0 ms), firefox ×1 (1, 0 ms), edge ×1 (1, 0 ms), finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), edge-2 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1027 ms; blind for 214 ms |  |  | ✔ |  |  | ✔ | ✔ | ✔ |
| 28 | click-wallpaper-again | clicks on the wallpaper again | chrome ×1 (1, 0 ms), firefox ×1 (1, 0 ms), edge ×1 (1, 0 ms), finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), edge-2 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 416 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 29 | restore-safari | clicks its miniature in the Dock | safari ×1 (16, 490 ms) | quiet 499 ms; blind for 257 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 30 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 441 ms; blind for 147 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 31 | dock-down | presses ⌃⌥⌘ and the down arrow | chrome ×1 (1, 0 ms), firefox ×1 (1, 0 ms), edge ×1 (1, 0 ms), finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), edge-2 ×1 (1, 0 ms) | quiet 794 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 32 | view-all | presses ⌃⌥Space |  | quiet 737 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 33 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 549 ms; blind for 130 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 34 | minimize-textedit | presses ⌘M | textedit ×1 (16, 504 ms), terminal ×1 (1, 0 ms) | quiet 1532 ms; blind for 269 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 35 | restore-textedit | clicks its miniature in the Dock | textedit ×1 (23, 493 ms), terminal ×1 (1, 0 ms) | quiet 936 ms; blind for 285 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 36 | view-back | presses ⌃⌥[ |  | quiet 692 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 37 | click-terminal | clicks terminal's title bar |  | quiet 441 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | dock-up | presses ⌃⌥⌘ and the up arrow | safari ×1 (1, 0 ms), chrome ×1 (1, 0 ms), firefox ×1 (1, 0 ms), edge ×1 (1, 0 ms), finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), edge-2 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 928 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 39 | dock-icon-firefox | clicks firefox's icon in the Dock |  | quiet 365 ms; blind for 119 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 40 | view-home | presses ⌃⌥0 |  | quiet 788 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 41 | cmd-tab-3 | holds ⌘ and presses Tab 3 time(s) |  | quiet 577 ms; blind for 143 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 42 | quit-textedit | presses ⌘Q in textedit |  | quiet 918 ms; blind for 168 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 43 | save-view-1 | presses ⌃⌥⇧1 |  | quiet 574 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 44 | pause | presses ⌃⌥⎋ | safari ×1 (2, 53 ms), chrome ×1 (1, 0 ms), firefox ×1 (2, 98 ms), edge ×1 (1, 0 ms), finder ×1 (2, 63 ms), terminal ×1 (1, 0 ms), safari-2 ×1 (2, 82 ms), chrome-2 ×1 (2, 30 ms), edge-2 ×1 (2, 63 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1564 ms; blind for 104 ms |  |  | ~ | ✔ | ✔ |  | ✔ | ✔ |
| 45 | reopen-textedit | opens textedit's document again |  | quiet 1168 ms; blind for 682 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 46 | resume | presses ⌃⌥⎋ | safari ×1 (1, 0 ms), chrome ×1 (2, 40 ms), firefox ×1 (1, 0 ms), edge ×1 (1, 0 ms), finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), edge-2 ×1 (2, 76 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1646 ms; blind for 102 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 47 | dock-icon-edge | clicks edge's icon in the Dock |  | quiet 414 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 48 | hide-edge | presses ⌘H |  | quiet 833 ms; blind for 112 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 49 | view-in | presses ⌃⌥↓ | safari ×1 (1, 0 ms), chrome ×1 (1, 0 ms), firefox ×1 (1, 0 ms), finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1115 ms; blind for 132 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 50 | click-wallpaper | clicks on the wallpaper | safari ×1 (1, 0 ms), chrome ×1 (1, 0 ms), firefox ×1 (1, 0 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 478 ms |  |  | ✔ |  |  | ✔ | ✔ | ✔ |
| 51 | click-wallpaper-again | clicks on the wallpaper again | safari ×1 (1, 0 ms), chrome ×1 (1, 0 ms), firefox ×1 (1, 0 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 393 ms; blind for 125 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 52 | leave-alone | does nothing for half a minute |  | quiet 392 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 53 | unhide-edge | clicks its icon in the Dock | edge ×1 (1, 0 ms), edge-2 ×1 (1, 0 ms) | quiet 358 ms; blind for 168 ms |  | ✘ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 54 | click-safari | clicks safari's title bar |  | quiet 471 ms; blind for 125 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | dock-up | presses ⌃⌥⌘ and the up arrow | safari ×1 (1, 0 ms), chrome ×1 (1, 0 ms), firefox ×1 (1, 0 ms), edge ×1 (1, 0 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), edge-2 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 887 ms; blind for 115 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 56 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 428 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms), chrome ×1 (7, 259 ms), firefox ×1 (7, 259 ms), edge ×1 (7, 259 ms), finder ×1 (7, 259 ms), terminal ×1 (7, 259 ms), safari-2 ×1 (7, 259 ms), chrome-2 ×1 (7, 259 ms), edge-2 ×1 (7, 259 ms), desk-a ×1 (7, 259 ms), desk-b ×1 (7, 259 ms), textedit ×1 (7, 259 ms) | quiet 399 ms; blind for 216 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 58 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms), chrome ×3 (10, 796 ms), firefox ×3 (10, 856 ms), edge ×3 (10, 929 ms), finder ×2 (9, 503 ms), terminal ×2 (9, 503 ms), safari-2 ×3 (10, 929 ms), chrome-2 ×3 (10, 949 ms), edge-2 ×3 (10, 1033 ms), desk-a ×3 (10, 1110 ms), desk-b ×3 (10, 1110 ms), textedit ×3 (10, 1110 ms) | quiet 377 ms; blind for 265 ms |  | ✔ | ✘ | ✔ |  |  | ✔ | ✔ |
| 59 | dock-icon-terminal | clicks terminal's icon in the Dock | safari ×1 (1, 0 ms), chrome ×1 (1, 0 ms), firefox ×1 (1, 0 ms), edge ×1 (1, 0 ms), finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), edge-2 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 996 ms; blind for 164 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | dock-right | presses ⌃⌥⌘ and the right arrow | safari ×1 (1, 0 ms), chrome ×1 (1, 0 ms), firefox ×1 (1, 0 ms), edge ×1 (1, 0 ms), finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), edge-2 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 816 ms; blind for 134 ms |  | ✘ | ✘ | ✔ |  |  | ✔ | ✔ |
| 61 | quit | chooses Quit Arbor in Arbor's menu | safari ×1 (1, 0 ms), chrome ×1 (2, 70 ms), firefox ×1 (3, 175 ms), edge ×1 (3, 70 ms), finder ×1 (1, 0 ms), terminal ×1 (2, 10 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (2, 56 ms), edge-2 ×1 (2, 32 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 725 ms |  |  | ✔ |  | ✘ |  | ✔ | ✘ |
| 62 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 415 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 63 | dock-icon-edge | clicks edge's icon in the Dock |  | quiet 420 ms; blind for 150 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 64 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 383 ms; blind for 119 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 65 | launch | starts Arbor | safari ×1 (2, 24 ms), finder ×1 (2, 6 ms), terminal ×1 (4, 46 ms) | quiet 804 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 66 | dock-icon-firefox | clicks firefox's icon in the Dock |  | quiet 434 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 67 | drag-firefox-by | drags firefox, which floats, by its title bar 54 across and 57 down | safari ×1 (1, 0 ms), firefox ×1 (1, 0 ms), finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms) | quiet 1432 ms | ✔ | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 68 | view-frame | presses ⌃⌥↩ | safari ×1 (1, 0 ms), chrome ×1 (1, 0 ms), firefox ×1 (1, 0 ms), edge ×1 (1, 0 ms), finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), edge-2 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 917 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 69 | dock-icon-chrome | clicks chrome's icon in the Dock | chrome ×1 (1, 0 ms), firefox ×1 (1, 0 ms), edge ×1 (1, 0 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), edge-2 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 640 ms; blind for 102 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 70 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 491 ms; blind for 167 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 71 | dock-right | presses ⌃⌥⌘ and the right arrow | chrome ×1 (1, 0 ms), edge ×1 (1, 0 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), edge-2 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1065 ms; blind for 117 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 72 | dock-icon-edge | clicks edge's icon in the Dock |  | quiet 436 ms; blind for 211 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 73 | new-window-edge | presses ⌘N in edge |  | quiet 995 ms; blind for 149 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 74 | view-in | presses ⌃⌥↓ | chrome ×1 (1, 0 ms), edge ×1 (1, 0 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), edge-2 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1269 ms; blind for 116 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 75 | close-window | presses ⌘W |  | quiet 1004 ms; blind for 145 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 76 | view-out | presses ⌃⌥↑ | chrome ×1 (1, 0 ms), edge ×1 (1, 0 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), edge-2 ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1077 ms; blind for 106 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 77 | dock-icon-finder | clicks finder's icon in the Dock | safari ×1 (1, 0 ms), chrome ×1 (1, 0 ms), firefox ×1 (1, 0 ms), edge ×1 (1, 0 ms), finder ×1 (1, 0 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), edge-2 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 888 ms; blind for 139 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 78 | undo | presses ⌃⌥Z | safari ×1 (1, 0 ms), chrome ×1 (1, 0 ms), firefox ×1 (1, 0 ms), edge ×1 (1, 0 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), edge-2 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1310 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 79 | view-out | presses ⌃⌥↑ | safari ×1 (1, 0 ms), firefox ×1 (1, 0 ms), finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms) | quiet 833 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 80 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 529 ms; blind for 103 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 81 | leave-alone | does nothing for half a minute |  | quiet 400 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 82 | click-textedit | clicks textedit's title bar |  | quiet 432 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 83 | view-out | presses ⌃⌥↑ |  | quiet 764 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 84 | click-finder | clicks finder's title bar |  | quiet 402 ms; blind for 177 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 85 | pin | chooses Keep This Window in View in Arbor's menu, or takes the tick off | safari ×1 (1, 0 ms), firefox ×1 (1, 0 ms), finder ×1 (1, 0 ms) | quiet 1073 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 86 | view-out | presses ⌃⌥↑ |  | quiet 791 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 87 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 395 ms; blind for 246 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 88 | drag-safari-to-left-edge | drags safari by its title bar against the left edge of the screen and lets go | safari ×1 (1, 0 ms), firefox ×1 (1, 0 ms), terminal ×1 (1, 0 ms) | quiet 368 ms; blind for 108 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 89 | view-desktop | presses ⌃⌥D | firefox ×1 (1, 0 ms), terminal ×1 (1, 0 ms) | quiet 733 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 90 | view-frame | presses ⌃⌥↩ | safari ×1 (1, 0 ms), chrome ×1 (1, 0 ms), firefox ×1 (1, 0 ms), edge ×1 (1, 0 ms), terminal ×1 (1, 0 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), edge-2 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1205 ms; blind for 157 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 91 | dock-icon-chrome | clicks chrome's icon in the Dock |  | quiet 415 ms; blind for 228 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 92 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 421 ms; blind for 112 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 93 | drag-safari-to-left-edge | drags safari by its title bar against the left edge of the screen and lets go | safari ×1 (9, 327 ms) | quiet 395 ms | ✔ | ✔ | ~ | ✔ |  | ✔ | ✔ | ✔ |
| 94 | dock-icon-firefox | clicks firefox's icon in the Dock |  | quiet 547 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 95 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 427 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 96 | view-frame | presses ⌃⌥↩ | chrome ×1 (1, 0 ms), firefox ×1 (1, 0 ms), edge ×1 (1, 0 ms), terminal ×1 (1, 0 ms), safari-2 ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), edge-2 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1755 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 97 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 428 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 98 | quit-safari | presses ⌘Q in safari |  | quiet 1023 ms; blind for 167 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 99 | dock-icon-edge | clicks edge's icon in the Dock |  | quiet 460 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 100 | reopen-safari | opens safari's document again |  | quiet 1035 ms; blind for 1356 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 101 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 428 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 102 | view-3 | presses ⌃⌥3 |  | quiet 640 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 103 | dock-icon-terminal | clicks terminal's icon in the Dock | chrome ×1 (1, 0 ms), edge ×1 (1, 0 ms), terminal ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), edge-2 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 491 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 104 | hide-terminal | presses ⌘H | chrome ×1 (1, 0 ms), firefox ×1 (2, 12 ms), edge ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), edge-2 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (2, 26 ms), safari ×1 (1, 0 ms) | quiet 1369 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 105 | unhide-terminal | clicks its icon in the Dock | firefox ×1 (1, 0 ms) | quiet 358 ms |  | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 106 | view-home | presses ⌃⌥0 | chrome ×1 (1, 0 ms), firefox ×1 (1, 0 ms), edge ×1 (1, 0 ms), terminal ×1 (1, 0 ms), chrome-2 ×1 (1, 0 ms), edge-2 ×1 (1, 0 ms), textedit ×1 (1, 0 ms), safari ×1 (1, 0 ms) | quiet 908 ms; blind for 113 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 107 | input-last | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 443 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 108 | quit | chooses Quit Arbor in Arbor's menu | chrome ×1 (1, 0 ms), firefox ×1 (1, 0 ms), edge ×1 (2, 53 ms), terminal ×1 (3, 40 ms), chrome-2 ×1 (2, 69 ms), edge-2 ×1 (2, 53 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), textedit ×1 (2, 67 ms), safari ×1 (1, 0 ms) | quiet 860 ms |  |  | ✔ |  | ✘ |  | ✔ | ✘ |
| 109 | input-after | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 846 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 110 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 359 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 111 | dock-icon-chrome | clicks chrome's icon in the Dock |  | quiet 368 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 112 | dock-icon-firefox | clicks firefox's icon in the Dock |  | quiet 405 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 113 | dock-icon-edge | clicks edge's icon in the Dock |  | quiet 357 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 114 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 484 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 115 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 381 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 116 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 413 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
