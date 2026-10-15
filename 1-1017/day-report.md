139 steps in 513 s, 118 of them judged, 27 with a rule broken. The sampler: samples 17563 seconds 456.6 hz 38.5 cost-ms 3.57 late 56 longest-gap-ms 1028 whole-samples 19767 whole-seconds 513.9 whole-late 137.
Input: 277 presses, releases, keys and scrolls reached the apps, half of them within 555 µs, 99 in 100 within 73061 µs, the latest after 132302 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 17, 576, 6091; dragged 164, 585, 4245; forward 10, 16678, 132302; key 60, 292, 1541; up 26, 633, 89661. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 25938; up 8, 467.
The round of input `started` (events, half within µs): forward 8, 35699; up 8, 363.
The round of input `last` (events, half within µs): forward 14, 42550; up 14, 1146.
The round of input `after` (events, half within µs): forward 8, 36713; up 8, 1613.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 4 | 0 |  |
| 2 | nothing moves that the person did not move | 70 | 2 | 87 drag-safari-by, 128 input-last |
| 3 | no jolts: a window moves once, to where it ends up | 127 | 15 | 18 display-plug, 27 display-unplug, 29 display-plug, 31 display-unplug, 33 display-plug, 57 display-left, 60 drag-gap-beside-terminal, 62 display-unplug, 76 launch, 85 display-plug, 87 drag-safari-by, 91 display-unplug … |
| 4 | the window you switch to comes to the front and into view | 63 | 2 | 23 undo, 138 dock-icon-preview |
| 5 | quitting, Float All and pause give windows their own sizes back | 6 | 3 | 88 float-all, 118 float-all, 129 quit |
| 6 | what a person presses reaches the apps, at once | 42 | 0 |  |
| L | no window is lost or stuck | 127 | 6 | 28 view-home, 32 view-home, 34 view-home, 63 view-home, 76 launch, 129 quit |
| - | what the script itself checked | 127 | 3 | 112 drag-preview-to-left-edge, 113 display-unplug, 117 send-across |

## Findings

### Rule 2: nothing moves that the person did not move

- ~ **76 launch** (starts Arbor): w67 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +444 ms 446,124 470×416 · +843 ms 1805,822 470×416
- ✘ **87 drag-safari-by** (drags safari, which floats, by its title bar -100 across and 91 down): textedit (w45) moved, and the step did not name it [moved-unasked]
  - +0 ms 234,43 749×222 · +4748 ms 234,43 369×222
- ✘ **128 input-last** (a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window): preview (w61) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 4,35 708×424 · +1108 ms 1396,31 708×424

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **17 arrange** (presses ⌃⌥A): the last window came to rest 1613 ms after the key or the button, in Arbor's first act since it started [slow]
- ✘ **18 display-plug** (the second display: plug): finder (w31) moved 2 times [jolt]
  - +0 ms 995,43 501×252 · +829 ms 340,120 920×436 · +2851 ms 340,120 501×252 · +2898 ms 995,43 501×252
- ✘ **18 display-plug** (the second display: plug): safari (w34) moved 2 times [jolt]
  - +0 ms 1599,770 574×248 · +480 ms 138,31 1324×791 · +3049 ms -1323,770 1324×791
- ✘ **18 display-plug** (the second display: plug): textedit (w45) moved 2 times [jolt]
  - +0 ms 274,43 709×222 · +480 ms 165,65 656×422 · +2898 ms 274,43 709×222
- ✘ **18 display-plug** (the second display: plug): terminal (w49) moved 2 times [jolt]
  - +0 ms 13,305 247×244 · +480 ms 40,51 863×499 · +2912 ms 40,51 247×244 · +2936 ms 12,303 247×244 · +2950 ms 13,305 247×244
- ✘ **18 display-plug** (the second display: plug): notes (w52) moved 2 times [jolt]
  - +0 ms 274,510 709×300 · +703 ms 300,165 1000×600 · +3049 ms 274,510 709×300
- ✘ **18 display-plug** (the second display: plug): calendar (w58) moved 2 times [jolt]
  - +0 ms 1599,770 680×503 · +480 ms 404,115 936×599 · +3049 ms -935,770 936×599
- ✘ **18 display-plug** (the second display: plug): settings (w59) moved 2 times [jolt]
  - +0 ms 1599,770 723×470 · +1082 ms 437,85 723×625 · +3049 ms -722,770 723×625
- ✘ **18 display-plug** (the second display: plug): preview (w61) moved 2 times [jolt]
  - +0 ms 1599,770 708×248 · +480 ms 4,35 708×424 · +3049 ms -707,770 708×424
- ✘ **18 display-plug** (the second display: plug): mail (w65) moved 2 times [jolt]
  - +0 ms 1599,770 881×236 · +899 ms 240,72 1120×630 · +3049 ms -1119,770 1120×630
- ✘ **18 display-plug** (the second display: plug): w67 of Mail moved 2 times [jolt]
  - +0 ms 1805,822 470×416 · +899 ms 565,179 470×416 · +3049 ms -794,877 470×416
- ~ **23 undo** (presses ⌃⌥Z): the last window came to rest 828 ms after the key or the button [slow]
- ✘ **27 display-unplug** (the second display: unplug): finder (w31) moved 2 times [jolt]
  - +0 ms 995,43 501×252 · +180 ms 340,120 920×436 · +2195 ms 340,120 501×252 · +2222 ms 995,43 501×252
- ✘ **27 display-unplug** (the second display: unplug): safari (w34) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -1323,770 1324×791 · +180 ms 138,31 1324×791 · +2294 ms 1599,770 1324×791
- ✘ **27 display-unplug** (the second display: unplug): textedit (w45) moved 2 times [jolt]
  - +0 ms 274,43 709×222 · +180 ms 165,65 656×422 · +2222 ms 274,43 709×222
- ✘ **27 display-unplug** (the second display: unplug): terminal (w49) moved 2 times [jolt]
  - +0 ms 13,305 247×244 · +180 ms 40,51 863×499 · +2222 ms 13,305 247×244
- ✘ **27 display-unplug** (the second display: unplug): notes (w52) moved 2 times [jolt]
  - +0 ms 274,510 709×300 · +180 ms 300,165 1000×600 · +2280 ms 274,510 709×300
- ✘ **27 display-unplug** (the second display: unplug): calendar (w58) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -935,770 936×599 · +180 ms 404,115 936×599 · +2294 ms 1599,770 936×599
- ✘ **27 display-unplug** (the second display: unplug): settings (w59) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -722,770 723×625 · +418 ms 437,85 723×625 · +2308 ms 1599,770 723×625
- ✘ **27 display-unplug** (the second display: unplug): preview (w61) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -707,770 708×424 · +180 ms 4,35 708×424 · +2308 ms 1599,770 708×424
- ✘ **27 display-unplug** (the second display: unplug): mail (w65) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -1119,770 1120×630 · +180 ms 240,72 1120×630 · +2308 ms 1599,770 1120×630
- ✘ **27 display-unplug** (the second display: unplug): w67 of Mail is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -794,877 470×416 · +180 ms 565,179 470×416 · +2308 ms 1924,877 470×416
- ✘ **29 display-plug** (the second display: plug): finder (w31) moved 2 times [jolt]
  - +0 ms 995,43 501×252 · +255 ms 340,120 920×436 · +2337 ms 995,43 501×252
- ✘ **29 display-plug** (the second display: plug): safari (w34) moved 2 times [jolt]
  - +0 ms 1599,770 1324×791 · +255 ms 138,31 1324×791 · +2390 ms -1323,770 1324×791
- ✘ **29 display-plug** (the second display: plug): textedit (w45) moved 2 times [jolt]
  - +0 ms 274,43 709×222 · +255 ms 165,65 656×422 · +2337 ms 274,43 709×222
- ✘ **29 display-plug** (the second display: plug): terminal (w49) moved 2 times [jolt]
  - +0 ms 13,305 247×244 · +255 ms 40,51 863×499 · +2337 ms 13,305 247×244
- ✘ **29 display-plug** (the second display: plug): notes (w52) moved 2 times [jolt]
  - +0 ms 274,510 709×300 · +255 ms 300,165 1000×600 · +2390 ms 274,510 709×300
- ✘ **29 display-plug** (the second display: plug): calendar (w58) moved 2 times [jolt]
  - +0 ms 1599,770 936×599 · +255 ms 404,115 936×599 · +2390 ms -935,770 936×599
- ✘ **29 display-plug** (the second display: plug): settings (w59) moved 2 times [jolt]
  - +0 ms 1599,770 723×625 · +259 ms 437,85 723×625 · +2390 ms -722,770 723×625
- ✘ **29 display-plug** (the second display: plug): preview (w61) moved 2 times [jolt]
  - +0 ms 1599,770 708×424 · +255 ms 4,35 708×424 · +2390 ms -707,770 708×424
- ✘ **29 display-plug** (the second display: plug): mail (w65) moved 2 times [jolt]
  - +0 ms 1599,770 1120×630 · +255 ms 240,72 1120×630 · +2390 ms -1119,770 1120×630
- ✘ **29 display-plug** (the second display: plug): w67 of Mail moved 2 times [jolt]
  - +0 ms 1924,877 470×416 · +255 ms 565,179 470×416 · +2390 ms -794,877 470×416
- ✘ **31 display-unplug** (the second display: unplug): finder (w31) moved 2 times [jolt]
  - +0 ms 995,43 501×252 · +4 ms 340,120 920×436 · +1874 ms 995,43 501×252
- ✘ **31 display-unplug** (the second display: unplug): safari (w34) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -1323,770 1324×791 · +4 ms 138,31 1324×791 · +2007 ms 1599,770 1324×791
- ✘ **31 display-unplug** (the second display: unplug): textedit (w45) moved 2 times [jolt]
  - +0 ms 274,43 709×222 · +4 ms 165,65 656×422 · +1889 ms 274,43 709×222
- ✘ **31 display-unplug** (the second display: unplug): terminal (w49) moved 2 times [jolt]
  - +0 ms 13,305 247×244 · +4 ms 40,51 863×499 · +1923 ms 13,305 247×244
- ✘ **31 display-unplug** (the second display: unplug): notes (w52) moved 2 times [jolt]
  - +0 ms 274,510 709×300 · +4 ms 300,165 1000×600 · +1972 ms 300,165 709×300 · +2007 ms 274,510 709×300
- ✘ **31 display-unplug** (the second display: unplug): calendar (w58) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -935,770 936×599 · +4 ms 404,115 936×599 · +2007 ms 1599,770 936×599
- ✘ **31 display-unplug** (the second display: unplug): settings (w59) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -722,770 723×625 · +227 ms 437,85 723×625 · +2007 ms 1599,770 723×625
- ✘ **31 display-unplug** (the second display: unplug): preview (w61) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -707,770 708×424 · +4 ms 4,35 708×424 · +2007 ms 1599,770 708×424
- ✘ **31 display-unplug** (the second display: unplug): mail (w65) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -1119,770 1120×630 · +4 ms 240,72 1120×630 · +2007 ms 1599,770 1120×630
- ✘ **31 display-unplug** (the second display: unplug): w67 of Mail is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -794,877 470×416 · +4 ms 565,179 470×416 · +2007 ms 1924,877 470×416
- ✘ **33 display-plug** (the second display: plug): finder (w31) moved 2 times [jolt]
  - +0 ms 995,43 501×252 · +317 ms 340,120 920×436 · +2781 ms 995,43 501×252
- ✘ **33 display-plug** (the second display: plug): safari (w34) moved 2 times [jolt]
  - +0 ms 1599,770 1324×791 · +211 ms 138,31 1324×791 · +2914 ms -1323,770 1324×791
- ✘ **33 display-plug** (the second display: plug): textedit (w45) moved 2 times [jolt]
  - +0 ms 274,43 709×222 · +211 ms 165,65 656×422 · +2781 ms 165,65 656×222 · +2823 ms 274,43 709×222
- ✘ **33 display-plug** (the second display: plug): terminal (w49) moved 2 times [jolt]
  - +0 ms 13,305 247×244 · +211 ms 40,51 863×499 · +2807 ms 40,51 247×244 · +2823 ms 12,303 247×244 · +2846 ms 13,305 247×244
- ✘ **33 display-plug** (the second display: plug): notes (w52) moved 2 times [jolt]
  - +0 ms 274,510 709×300 · +317 ms 300,165 1000×600 · +2914 ms 274,510 709×300
- ✘ **33 display-plug** (the second display: plug): calendar (w58) moved 2 times [jolt]
  - +0 ms 1599,770 936×599 · +211 ms 404,115 936×599 · +2914 ms -935,770 936×599
- ✘ **33 display-plug** (the second display: plug): settings (w59) moved 2 times [jolt]
  - +0 ms 1599,770 723×625 · +317 ms 437,85 723×625 · +2914 ms -722,770 723×625
- ✘ **33 display-plug** (the second display: plug): preview (w61) moved 2 times [jolt]
  - +0 ms 1599,770 708×424 · +211 ms 4,35 708×424 · +2914 ms -707,770 708×424
- ✘ **33 display-plug** (the second display: plug): mail (w65) moved 2 times [jolt]
  - +0 ms 1599,770 1120×630 · +317 ms 240,72 1120×630 · +2914 ms -1119,770 1120×630
- ✘ **33 display-plug** (the second display: plug): w67 of Mail is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1924,877 470×416 · +317 ms 565,179 470×416 · +2914 ms -794,877 470×416
- ~ **35 view-in** (presses ⌃⌥↓): the last window came to rest 896 ms after the key or the button [slow]
- ~ **46 redo** (presses ⌃⌥⇧Z): the last window came to rest 711 ms after the key or the button [slow]
- ✘ **57 display-left** (the second display: left): finder (w31) moved 2 times [jolt]
  - +0 ms 12,43 1576×767 · +200 ms 340,120 920×436 · +1975 ms 12,43 920×436 · +2001 ms 12,43 1576×767
- ✘ **57 display-left** (the second display: left): safari (w34) moved 2 times [jolt]
  - +0 ms -1323,770 1324×791 · +200 ms 138,31 1324×791 · +2001 ms 1599,770 1324×791
- ✘ **57 display-left** (the second display: left): textedit (w45) moved 2 times [jolt]
  - +0 ms -708,790 709×222 · +200 ms 165,65 656×422 · +2025 ms 1599,790 656×422
- ✘ **57 display-left** (the second display: left): terminal (w49) moved 2 times [jolt]
  - +0 ms -246,790 247×244 · +200 ms 40,51 863×499 · +2025 ms 1599,790 863×499
- ✘ **57 display-left** (the second display: left): notes (w52) moved 2 times [jolt]
  - +0 ms -1575,770 1576×767 · +200 ms 426,158 1000×660 · +2025 ms 1599,770 1000×660
- ✘ **57 display-left** (the second display: left): calendar (w58) moved 2 times [jolt]
  - +0 ms -935,770 936×599 · +200 ms 404,115 936×599 · +2025 ms 1599,770 936×599
- ✘ **57 display-left** (the second display: left): settings (w59) moved 2 times [jolt]
  - +0 ms -722,770 723×767 · +304 ms 437,85 723×625 · +2025 ms 1599,770 723×625
- ✘ **57 display-left** (the second display: left): preview (w61) moved 2 times [jolt]
  - +0 ms -707,770 708×424 · +200 ms 4,35 708×424 · +2025 ms 1599,770 708×424
- ✘ **57 display-left** (the second display: left): mail (w65) moved 2 times [jolt]
  - +0 ms -1119,770 1120×630 · +200 ms 240,72 1120×630 · +2025 ms 1599,770 1120×630
- ✘ **57 display-left** (the second display: left): w67 of Mail is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -794,877 470×416 · +200 ms 565,179 470×416 · +2025 ms 1924,877 470×416
- ✘ **60 drag-gap-beside-terminal** (drags the gap to the right of terminal by -40 points): textedit (w45) moved 2 times [jolt]
  - +0 ms 274,43 709×222 · +802 ms 271,43 712×222 · +926 ms 269,43 714×222 · +1008 ms 267,43 716×222 · +1128 ms 265,43 718×222 · +1216 ms 263,43 718×222 · … 12 more … · +2310 ms 239,43 742×222 · +2324 ms 239,43 744×222 · +2440 ms 237,43 744×222 · +2453 ms 237,43 746×222 · +2552 ms 235,43 748×222
- ✘ **60 drag-gap-beside-terminal** (drags the gap to the right of terminal by -40 points): notes (w52) moved 2 times [jolt]
  - +0 ms 274,510 709×300 · +802 ms 271,510 712×300 · +926 ms 269,510 712×300 · +964 ms 269,510 714×300 · +1054 ms 267,510 716×300 · +1181 ms 265,510 718×300 · … 9 more … · +2274 ms 241,510 742×300 · +2341 ms 239,510 744×300 · +2453 ms 237,510 744×300 · +2474 ms 237,510 746×300 · +2607 ms 235,510 748×300
- ✘ **62 display-unplug** (the second display: unplug): finder (w31) moved 2 times [jolt]
  - +0 ms 995,43 501×252 · +6 ms 340,120 920×436 · +1980 ms 995,43 501×252
- ✘ **62 display-unplug** (the second display: unplug): safari (w34) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 1324×791 · +6 ms 138,31 1324×791 · +2086 ms 1599,770 1324×791
- ✘ **62 display-unplug** (the second display: unplug): textedit (w45) moved 2 times [jolt]
  - +0 ms 235,43 748×222 · +6 ms 165,65 656×422 · +2011 ms 165,65 656×222 · +2017 ms 234,43 749×222
- ✘ **62 display-unplug** (the second display: unplug): terminal (w49) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,790 240×244 · +6 ms 40,51 863×499 · +2086 ms 1599,790 863×499
- ✘ **62 display-unplug** (the second display: unplug): notes (w52) moved 2 times [jolt]
  - +0 ms 235,510 748×300 · +6 ms 426,158 1000×660 · +2086 ms 234,510 749×300
- ✘ **62 display-unplug** (the second display: unplug): calendar (w58) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 936×599 · +6 ms 404,115 936×599 · +2086 ms 1599,770 936×599
- ✘ **62 display-unplug** (the second display: unplug): settings (w59) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 723×625 · +217 ms 437,85 723×625 · +2086 ms 1599,770 723×625
- ✘ **62 display-unplug** (the second display: unplug): preview (w61) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 708×424 · +6 ms 4,35 708×424 · +2086 ms 1599,770 708×424
- ✘ **62 display-unplug** (the second display: unplug): mail (w65) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 1120×630 · +6 ms 240,72 1120×630 · +2086 ms 1599,770 1120×630
- ✘ **62 display-unplug** (the second display: unplug): w67 of Mail is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1924,877 470×416 · +6 ms 565,179 470×416 · +2086 ms 1924,877 470×416
- ✘ **76 launch** (starts Arbor): textedit (w45) went 30 points out of its way before it ended up [jolt]
  - +0 ms 165,65 673×439 · +679 ms 165,65 673×207 · +770 ms 234,43 749×222
- ✘ **76 launch** (starts Arbor): calendar (w58) moved 2 times [jolt]
  - +0 ms 404,115 936×599 · +530 ms 404,115 680×503 · +818 ms 1599,770 680×503
- ✘ **76 launch** (starts Arbor): settings (w59) moved 2 times [jolt]
  - +0 ms 437,85 723×625 · +495 ms 437,85 723×470 · +818 ms 1599,770 723×470
- ✘ **76 launch** (starts Arbor): mail (w65) moved 2 times [jolt]
  - +0 ms 240,72 1120×630 · +444 ms 240,72 881×236 · +843 ms 1599,770 881×236
- ✘ **76 launch** (starts Arbor): w67 of Mail moved 2 times [jolt]
  - +0 ms 565,179 470×416 · +444 ms 446,124 470×416 · +843 ms 1805,822 470×416
- ~ **84 view-all** (presses ⌃⌥Space): the last window came to rest 1007 ms after the key or the button [slow]
- ✘ **85 display-plug** (the second display: plug): finder (w31) moved 2 times [jolt]
  - +0 ms 995,43 501×380 · +1089 ms 340,120 920×436 · +3479 ms 340,120 501×380 · +3488 ms 995,43 501×380
- ✘ **85 display-plug** (the second display: plug): textedit (w45) moved 2 times [jolt]
  - +0 ms 234,43 749×222 · +1089 ms 165,65 656×422 · +3513 ms 165,65 656×222 · +3553 ms 234,43 749×222
- ✘ **85 display-plug** (the second display: plug): terminal (w49) moved 2 times [jolt]
  - +0 ms 1599,790 1577×379 · +1089 ms 40,51 863×499 · +3685 ms -862,790 863×499
- ✘ **85 display-plug** (the second display: plug): notes (w52) moved 2 times [jolt]
  - +0 ms 234,510 749×300 · +1292 ms 426,158 1000×660 · +3651 ms 426,158 749×300 · +3685 ms 234,510 749×300
- ✘ **85 display-plug** (the second display: plug): calendar (w58) moved 2 times [jolt]
  - +0 ms 800,32 801×791 · +1089 ms 1263,301 936×599 · +1686 ms 2559,31 961×1049
- ✘ **85 display-plug** (the second display: plug): settings (w59) moved 2 times [jolt]
  - +0 ms 1599,770 723×470 · +1292 ms 437,85 723×625 · +3685 ms -722,770 723×625
- ✘ **85 display-plug** (the second display: plug): preview (w61) moved 2 times [jolt]
  - +0 ms 1599,770 1576×378 · +1089 ms 4,35 708×424 · +3685 ms -707,770 708×424
- ✘ **85 display-plug** (the second display: plug): mail (w65) moved 2 times [jolt]
  - +0 ms 1599,770 881×236 · +1292 ms 240,72 1120×630 · +3685 ms -1119,770 1120×630
- ✘ **85 display-plug** (the second display: plug): w67 of Mail moved 2 times [jolt]
  - +0 ms 1805,822 470×416 · +1292 ms 565,179 470×416 · +3685 ms -794,877 470×416
- ✘ **87 drag-safari-by** (drags safari, which floats, by its title bar -100 across and 91 down): safari (w34) ended neither where it was let go nor where the preview was: let go at 38,109 1324×791, the preview at 615,43 368×222, now at -573,770 574×240 [stuck]
  - +0 ms 38,109 1324×791 · +810 ms -573,770 574×240
- ~ **88 float-all** (presses ⌃⌥⇧F): the last window came to rest 1060 ms after the key or the button [slow]
- ✘ **91 display-unplug** (the second display: unplug): calendar (w58) moved 2 times [jolt]
  - +0 ms 800,32 801×791 · +502 ms 1263,301 936×599 · +2236 ms 664,223 936×599
- ✘ **93 display-plug** (the second display: plug): calendar (w58) moved 2 times [jolt]
  - +0 ms 664,223 936×599 · +17 ms 1263,301 936×599 · +650 ms 664,301 936×599
- ✘ **113 display-unplug** (the second display: unplug): calendar (w58) moved 2 times [jolt]
  - +0 ms 664,301 936×599 · +175 ms 1263,301 936×599 · +1936 ms 664,223 936×599
- ✘ **126 display-unplug** (the second display: unplug): calendar (w58) moved 2 times [jolt]
  - +0 ms 2559,31 801×791 · +14 ms 1263,301 936×599 · +2235 ms 664,223 936×599
- ✘ **126 display-unplug** (the second display: unplug): settings (w59) moved 2 times [jolt]
  - +0 ms 438,43 723×470 · +569 ms 437,85 723×625 · +2235 ms 438,43 723×470

### Rule 4: the window you switch to comes to the front and into view

- ✘ **23 undo** (presses ⌃⌥Z): the app in front changed (to process 16589), and nobody switched [focus]
- ✘ **138 dock-icon-preview** (clicks preview's icon in the Dock): preview (w61) is not wholly in view: 29% of it, at 1396,31 708×424 in 0,31 1600×791 [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **88 float-all** (presses ⌃⌥⇧F): safari (w34) is 138,31 1324×790; its own size was -573,770 574×240 [size-lost]
- ✘ **118 float-all** (presses ⌃⌥⇧F): safari (w34) is 38,109 1324×791; its own size was -573,770 574×240 [size-lost]
- ✘ **118 float-all** (presses ⌃⌥⇧F): textedit (w45) is 165,65 656×422; its own size was 165,65 673×439 [size-lost]
- ✘ **118 float-all** (presses ⌃⌥⇧F): terminal (w49) is 40,51 863×499; its own size was 40,51 877×499 [size-lost]
- ✘ **118 float-all** (presses ⌃⌥⇧F): calendar (w58) has its size back but not its place: 2559,31 801×791, it was at 800,32 801×791 [size-lost]
- ✘ **129 quit** (chooses Quit Arbor in Arbor's menu): safari (w34) is 38,109 1324×791; its own size was -573,770 574×240 [size-lost]
- ✘ **129 quit** (chooses Quit Arbor in Arbor's menu): textedit (w45) is 165,65 656×422; its own size was 165,65 673×439 [size-lost]
- ✘ **129 quit** (chooses Quit Arbor in Arbor's menu): terminal (w49) is 40,51 863×499; its own size was 40,51 877×499 [size-lost]
- ✘ **129 quit** (chooses Quit Arbor in Arbor's menu): preview (w61) has its size back but not its place: 1396,31 708×424, it was at 4,35 708×424 [size-lost]

### Rule L: no window is lost or stuck

- ✘ **28 view-home** (presses ⌃⌥0): settings (w59) is out of view: 0% of it is on a display, at 1599,770 723×625 [lost]
- ✘ **32 view-home** (presses ⌃⌥0): settings (w59) is out of view: 0% of it is on a display, at 1599,770 723×625 [lost]
- ✘ **34 view-home** (presses ⌃⌥0): settings (w59) is out of view: 0% of it is on a display, at -722,770 723×625 [lost]
- ✘ **63 view-home** (presses ⌃⌥0): mail (w65) is out of view: 0% of it is on a display, at 1599,770 1120×630 [lost]
- ✘ **76 launch** (starts Arbor): safari (w34) is out of view: 0% of it is on a display, at 1599,770 1324×790 [lost]
- ✘ **76 launch** (starts Arbor): terminal (w49) is out of view: 0% of it is on a display, at 1599,790 877×499 [lost]
- ✘ **76 launch** (starts Arbor): calendar (w58) is out of view: 0% of it is on a display, at 1599,770 680×503 [lost]
- ✘ **76 launch** (starts Arbor): settings (w59) is out of view: 0% of it is on a display, at 1599,770 723×470 [lost]
- ✘ **76 launch** (starts Arbor): mail (w65) is out of view: 0% of it is on a display, at 1599,770 881×236 [lost]
- ✘ **129 quit** (chooses Quit Arbor in Arbor's menu): preview (w61) is out of view: 29% of it is on a display, at 1396,31 708×424 [lost]

### Rule -: what the script itself checked

- ✘ **112 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): w61 is in view for Arbor but only 51% of it is on a display: -768,438 1576×377 [script]
- ✘ **112 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): w61 sticks 780 points out of its slot: window -768,438 1576×377, slot 12,433 1576×377 [script]
- ✘ **113 display-unplug** (the second display: unplug): w61 sticks 398 points out of its slot: window 4,35 708×424, slot 12,433 1576×377 [script]
- ✘ **117 send-across** (sends the window in front to the other display): w61 sticks 1608 points out of its slot: window 4,35 708×424, slot 1612,43 942×1025 [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (3, 258 ms) | quiet 1102 ms; blind for 149 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 476 ms; blind for 1576 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×2 (3, 464 ms) | quiet 1238 ms; blind for 496 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (4, 350 ms) | quiet 1044 ms; blind for 273 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (2, 10 ms), w53 ×2 (11, 795 ms), w55 ×1 (4, 165 ms) | quiet 457 ms; blind for 275 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (3, 335 ms) | quiet 1338 ms; blind for 139 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 469 ms; blind for 467 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (3, 46 ms) | quiet 1028 ms; blind for 119 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | mail ×1 (2, 16 ms), w67 ×1 (5, 106 ms) | quiet 656 ms; blind for 586 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (41, 4081 ms) | quiet 1388 ms; blind for 100 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (34, 3141 ms) | quiet 1046 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 366 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 726 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | launch | starts Arbor |  | quiet 1306 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 15 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 725 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 16 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 367 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | arrange | presses ⌃⌥A | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w67 ×1 (1, 0 ms) | quiet 2227 ms; blind for 104 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 18 | display-plug | the second display: plug | finder ×2 (3, 2069 ms), safari ×2 (2, 2569 ms), textedit ×2 (2, 2418 ms), terminal ×2 (4, 2470 ms), notes ×2 (2, 2346 ms), calendar ×2 (2, 2569 ms), settings ×2 (2, 1967 ms), preview ×2 (2, 2569 ms), mail ×2 (2, 2150 ms), w67 ×2 (2, 2150 ms) | quiet 388 ms; blind for 445 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 19 | view-home | presses ⌃⌥0 |  | quiet 732 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 20 | view-back | presses ⌃⌥[ |  | quiet 808 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 21 | float-all | presses ⌃⌥⇧F | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w67 ×1 (1, 0 ms) | quiet 1215 ms |  |  | ✔ |  | ✔ |  | ✔ | ✔ |
| 22 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 478 ms; blind for 187 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | undo | presses ⌃⌥Z | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w67 ×1 (1, 0 ms) | quiet 1170 ms; blind for 160 ms |  |  | ~ | ✘ |  |  | ✔ | ✔ |
| 24 | hold | holds the view, as for a shared screen |  | quiet 1057 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 25 | show-desktop-while-held | presses ⌃⌥D, which would show the Desktop: the view is held |  | quiet 718 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 26 | release | lets the view go again |  | quiet 1013 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 27 | display-unplug | the second display: unplug | finder ×2 (3, 2042 ms), safari ×2 (2, 2114 ms), textedit ×2 (2, 2042 ms), terminal ×2 (2, 2042 ms), notes ×2 (2, 2100 ms), calendar ×2 (2, 2114 ms), settings ×2 (2, 1890 ms), preview ×2 (2, 2128 ms), mail ×2 (2, 2128 ms), w67 ×2 (2, 2128 ms) | quiet 438 ms; blind for 237 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 28 | view-home | presses ⌃⌥0 |  | quiet 753 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 29 | display-plug | the second display: plug | finder ×2 (2, 2082 ms), safari ×2 (2, 2135 ms), textedit ×2 (2, 2082 ms), terminal ×2 (2, 2082 ms), notes ×2 (2, 2135 ms), calendar ×2 (2, 2135 ms), settings ×2 (2, 2131 ms), preview ×2 (2, 2135 ms), mail ×2 (2, 2135 ms), w67 ×2 (2, 2135 ms) | quiet 401 ms; blind for 212 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 30 | view-home | presses ⌃⌥0 |  | quiet 703 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 31 | display-unplug | the second display: unplug | finder ×2 (2, 1870 ms), safari ×2 (2, 2003 ms), textedit ×2 (2, 1885 ms), terminal ×2 (2, 1919 ms), notes ×2 (3, 2003 ms), calendar ×2 (2, 2003 ms), settings ×2 (2, 1780 ms), preview ×2 (2, 2003 ms), mail ×2 (2, 2003 ms), w67 ×2 (2, 2003 ms) | quiet 793 ms; blind for 170 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 32 | view-home | presses ⌃⌥0 |  | quiet 715 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 33 | display-plug | the second display: plug | finder ×2 (2, 2464 ms), safari ×2 (2, 2703 ms), textedit ×2 (3, 2612 ms), terminal ×2 (4, 2635 ms), notes ×2 (2, 2597 ms), calendar ×2 (2, 2703 ms), settings ×2 (2, 2597 ms), preview ×2 (2, 2703 ms), mail ×2 (2, 2597 ms), w67 ×2 (2, 2597 ms) | quiet 366 ms; blind for 208 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 34 | view-home | presses ⌃⌥0 |  | quiet 613 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 35 | view-in | presses ⌃⌥↓ | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 1507 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 36 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 824 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 37 | click-terminal | clicks terminal's title bar |  | quiet 497 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | undo | presses ⌃⌥Z | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w67 ×1 (1, 0 ms) | quiet 1227 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 39 | view-back | presses ⌃⌥[ |  | quiet 626 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 40 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 502 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 368 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | drag-notes-by | drags notes, which floats, by its title bar 126 across and 53 down |  | quiet 1081 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | click-settings | clicks settings's title bar |  | quiet 387 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | pin | chooses Keep This Window in View in Arbor's menu, or takes the tick off |  | quiet 426 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 45 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 357 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 46 | redo | presses ⌃⌥⇧Z | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w67 ×1 (1, 0 ms) | quiet 973 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 47 | display-right | the second display: right |  | quiet 396 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 48 | view-home | presses ⌃⌥0 |  | quiet 843 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 49 | leave-alone | does nothing for half a minute |  | quiet 363 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 50 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 1281 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 51 | dock-icon-settings | clicks settings's icon in the Dock | finder ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 626 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | dock-down | presses ⌃⌥⌘ and the down arrow |  | quiet 524 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 53 | dock-icon-notes | clicks notes's icon in the Dock | notes ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 520 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 54 | dock-left | presses ⌃⌥⌘ and the left arrow |  | quiet 575 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 55 | dock-icon-finder | clicks finder's icon in the Dock | finder ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 493 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 56 | new-window-finder | presses ⌘N in finder |  | quiet 1138 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 57 | display-left | the second display: left | finder ×2 (3, 1801 ms), safari ×2 (2, 1801 ms), textedit ×2 (2, 1825 ms), terminal ×2 (2, 1825 ms), notes ×2 (2, 1825 ms), calendar ×2 (2, 1825 ms), settings ×2 (2, 1721 ms), preview ×2 (2, 1825 ms), mail ×2 (2, 1825 ms), w67 ×2 (2, 1825 ms) | quiet 404 ms; blind for 169 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 58 | view-home | presses ⌃⌥0 | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 976 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 59 | close-window | presses ⌘W |  | quiet 1231 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 60 | drag-gap-beside-terminal | drags the gap to the right of terminal by -40 points | textedit ×2 (22, 1750 ms), terminal ×1 (5, 472 ms), notes ×2 (19, 1805 ms) | quiet 1062 ms; blind for 356 ms |  | ✔ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | view-all | presses ⌃⌥Space |  | quiet 783 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 62 | display-unplug | the second display: unplug | finder ×2 (2, 1974 ms), safari ×2 (2, 2080 ms), textedit ×2 (3, 2011 ms), terminal ×2 (2, 2080 ms), notes ×2 (2, 2080 ms), calendar ×2 (2, 2080 ms), settings ×2 (2, 1869 ms), preview ×2 (2, 2080 ms), mail ×2 (2, 2080 ms), w67 ×2 (2, 2080 ms) | quiet 846 ms; blind for 182 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 63 | view-home | presses ⌃⌥0 |  | quiet 623 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 64 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 520 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 65 | dock-icon-safari | clicks safari's icon in the Dock | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 607 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 66 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 397 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 67 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 405 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 68 | leave-alone | does nothing for half a minute |  | quiet 374 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 69 | grow | presses ⌃⌥⌘= |  | quiet 540 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 70 | view-out | presses ⌃⌥↑ | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 939 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 71 | save-view-2 | presses ⌃⌥⇧2 |  | quiet 600 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 72 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (2, 51 ms), safari ×1 (2, 46 ms), textedit ×1 (2, 48 ms), terminal ×1 (1, 0 ms), notes ×1 (2, 51 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w67 ×1 (1, 0 ms) | quiet 863 ms |  |  | ✔ |  | ✔ |  | ✔ | ✔ |
| 73 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 357 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 74 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 377 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 75 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 353 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 76 | launch | starts Arbor | finder ×1 (3, 149 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 91 ms), terminal ×1 (1, 0 ms), notes ×1 (3, 126 ms), calendar ×2 (2, 288 ms), settings ×2 (2, 323 ms), mail ×2 (2, 399 ms), w67 ×2 (2, 399 ms) | quiet 693 ms |  | ~ | ✘ |  |  |  | ✘ | ✔ |
| 77 | view-in | presses ⌃⌥↓ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 1319 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 78 | click-safari | clicks safari's title bar |  | quiet 367 ms; blind for 183 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 79 | float | presses ⌃⌥F | safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 881 ms |  | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 80 | view-frame | presses ⌃⌥↩ | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 1075 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 81 | dock-icon-calendar | clicks calendar's icon in the Dock | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 1135 ms; blind for 147 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 82 | pin | chooses Keep This Window in View in Arbor's menu, or takes the tick off | finder ×1 (1, 0 ms), calendar ×1 (2, 37 ms), settings ×1 (1, 0 ms) | quiet 1020 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 83 | drag-calendar-to-right-edge | drags calendar by its title bar against the right edge of the screen and lets go | calendar ×1 (7, 298 ms) | quiet 373 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 84 | view-all | presses ⌃⌥Space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 1473 ms; blind for 103 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 85 | display-plug | the second display: plug | finder ×2 (3, 2399 ms), safari ×1 (1, 0 ms), textedit ×2 (3, 2464 ms), terminal ×2 (2, 2596 ms), notes ×2 (3, 2393 ms), calendar ×2 (2, 597 ms), settings ×2 (2, 2393 ms), preview ×2 (2, 2596 ms), mail ×2 (2, 2393 ms), w67 ×2 (2, 2393 ms) | quiet 390 ms; blind for 1028 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 86 | view-home | presses ⌃⌥0 |  | quiet 589 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 87 | drag-safari-by | drags safari, which floats, by its title bar -100 across and 91 down | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 1208 ms; blind for 145 ms | ✔ | ✘ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 88 | float-all | presses ⌃⌥⇧F | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (2, 130 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w67 ×1 (1, 0 ms) | quiet 1670 ms; blind for 105 ms |  |  | ~ |  | ✘ |  | ✔ | ✔ |
| 89 | view-out | presses ⌃⌥↑ |  | quiet 682 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 90 | view-frame | presses ⌃⌥↩ |  | quiet 603 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 91 | display-unplug | the second display: unplug | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×2 (2, 1734 ms) | quiet 610 ms; blind for 392 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 92 | view-home | presses ⌃⌥0 |  | quiet 670 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 93 | display-plug | the second display: plug | calendar ×2 (2, 633 ms) | quiet 424 ms; blind for 253 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 94 | view-home | presses ⌃⌥0 |  | quiet 773 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 95 | focus-up | presses ⌃⌥⇧ and the up arrow |  | quiet 414 ms; blind for 231 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 96 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 409 ms; blind for 117 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 97 | new-window-safari | presses ⌘N in safari |  | quiet 1087 ms; blind for 938 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 98 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 386 ms; blind for 322 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 99 | dock-down | presses ⌃⌥⌘ and the down arrow | preview ×1 (1, 0 ms) | quiet 685 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 100 | click-new-window | clicks the title bar of the window that ⌘N opened |  | quiet 520 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 101 | close-window | presses ⌘W |  | quiet 1091 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 102 | view-all | presses ⌃⌥Space |  | quiet 673 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 103 | peek | holds ⌃⌥Space for a second and a half and lets go |  | quiet 422 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 104 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 478 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 105 | minimize-notes | presses ⌘M | notes ×1 (18, 443 ms) | quiet 1530 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 106 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 409 ms; blind for 124 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 107 | restore-notes | clicks notes's icon in the Dock, which brings its minimized window back | notes ×1 (21, 516 ms) | quiet 1007 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 108 | hold | holds the view, as for a shared screen |  | quiet 393 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 109 | show-desktop-while-held | presses ⌃⌥D, which would show the Desktop: the view is held |  | quiet 622 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 110 | release | lets the view go again |  | quiet 362 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 111 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 532 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 112 | drag-preview-to-left-edge | drags preview by its title bar against the left edge of the screen and lets go |  | quiet 882 ms | ✔ | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 113 | display-unplug | the second display: unplug | calendar ×2 (2, 1761 ms), preview ×1 (1, 0 ms) | quiet 485 ms; blind for 186 ms |  |  | ✘ |  |  |  | ✔ | ✘ |
| 114 | view-home | presses ⌃⌥0 |  | quiet 695 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 115 | display-plug | the second display: plug | calendar ×1 (1, 0 ms) | quiet 378 ms; blind for 374 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 116 | view-home | presses ⌃⌥0 |  | quiet 719 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 117 | send-across | sends the window in front to the other display |  | quiet 994 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 118 | float-all | presses ⌃⌥⇧F |  | quiet 628 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 119 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 435 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 120 | dock-up | presses ⌃⌥⌘ and the up arrow | settings ×1 (1, 0 ms) | quiet 751 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 121 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 418 ms; blind for 163 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 122 | quit-safari | presses ⌘Q in safari |  | quiet 362 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 123 | view-right | presses ⌃⌥→ |  | quiet 672 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 124 | view-home | presses ⌃⌥0 |  | quiet 653 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 125 | reopen-safari | opens safari's document again |  | quiet 384 ms; blind for 147 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 126 | display-unplug | the second display: unplug | calendar ×2 (2, 2221 ms), settings ×2 (2, 1666 ms) | quiet 754 ms; blind for 488 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 127 | view-home | presses ⌃⌥0 |  | quiet 678 ms |  |  | ✔ |  |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 128 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window | preview ×1 (1, 0 ms) | quiet 832 ms |  | ✘ | ✔ |  |  | ✔ | ✔ | ✔ |
| 129 | quit | chooses Quit Arbor in Arbor's menu | calendar ×1 (2, 76 ms), settings ×1 (2, 30 ms) | quiet 889 ms |  |  | ✔ |  | ✘ |  | ✘ | ✔ |
| 130 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 680 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 131 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 453 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 132 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 390 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 133 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 365 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 134 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 395 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 135 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 407 ms; blind for 101 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 136 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 399 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 137 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 613 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 138 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 479 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 139 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 480 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
