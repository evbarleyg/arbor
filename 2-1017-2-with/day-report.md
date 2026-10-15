141 steps in 479 s, 123 of them judged, 29 with a rule broken. The sampler: samples 17458 seconds 438.6 hz 39.8 cost-ms 2.83 late 35 longest-gap-ms 462 whole-samples 19109 whole-seconds 480.0 whole-late 47.
Input: 253 presses, releases, keys and scrolls reached the apps, half of them within 421 µs, 99 in 100 within 41194 µs, the latest after 80798 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 17, 636, 4115; dragged 164, 413, 2744; forward 13, 1335, 80798; key 29, 240, 629; up 30, 937, 39707. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 36958; up 8, 259.
The round of input `started` (events, half within µs): forward 8, 37098; up 8, 973.
The round of input `last` (events, half within µs): forward 14, 32289; up 14, 744.
The round of input `after` (events, half within µs): forward 12, 32186; up 12, 881.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 4 | 0 |  |
| 2 | nothing moves that the person did not move | 73 | 1 | 90 drag-safari-by |
| 3 | no jolts: a window moves once, to where it ends up | 128 | 16 | 18 display-plug, 27 display-unplug, 29 display-plug, 31 display-unplug, 33 display-plug, 57 display-left, 60 drag-gap-beside-terminal, 62 display-unplug, 76 launch, 83 drag-calendar-to-right-edge, 88 display-plug, 94 display-unplug … |
| 4 | the window you switch to comes to the front and into view | 65 | 3 | 23 undo, 98 dock-icon-safari, 124 dock-icon-safari |
| 5 | quitting, Float All and pause give windows their own sizes back | 6 | 5 | 21 float-all, 72 quit, 91 float-all, 121 float-all, 131 quit |
| 6 | what a person presses reaches the apps, at once | 46 | 0 |  |
| L | no window is lost or stuck | 128 | 5 | 28 view-home, 32 view-home, 34 view-home, 63 view-home, 76 launch |
| - | what the script itself checked | 128 | 0 |  |

## Findings

### Rule 2: nothing moves that the person did not move

- ~ **76 launch** (starts Arbor): w614 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 805,299 470×416 · +271 ms 681,244 470×416 · +506 ms 1800,822 470×416
- ✘ **90 drag-safari-by** (drags safari, which floats, by its title bar -100 across and 91 down): finder (w585) moved, and the step did not name it [moved-unasked]
  - +0 ms 400,43 709×380 · +4843 ms 690,43 709×380
- ✘ **90 drag-safari-by** (drags safari, which floats, by its title bar -100 across and 91 down): textedit (w596) moved, and the step did not name it [moved-unasked]
  - +0 ms 12,433 376×377 · +4843 ms 12,433 666×377
- ✘ **90 drag-safari-by** (drags safari, which floats, by its title bar -100 across and 91 down): notes (w603) moved, and the step did not name it [moved-unasked]
  - +0 ms 400,435 709×375 · +4843 ms 690,435 709×375

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **18 display-plug** (the second display: plug): finder (w585) moved 2 times [jolt]
  - +0 ms 400,43 709×252 · +558 ms 340,120 920×436 · +2528 ms 340,120 709×252 · +2599 ms 400,43 709×252
- ✘ **18 display-plug** (the second display: plug): safari (w588) moved 2 times [jolt]
  - +0 ms 1599,770 574×247 · +210 ms 67,31 1324×791 · +2599 ms -1323,770 1324×791
- ✘ **18 display-plug** (the second display: plug): textedit (w596) moved 2 times [jolt]
  - +0 ms 12,562 376×248 · +210 ms 165,65 656×422 · +2528 ms 12,562 376×248
- ✘ **18 display-plug** (the second display: plug): terminal (w602) moved 2 times [jolt]
  - +0 ms 1121,562 377×248 · +210 ms 799,31 860×503 · +2599 ms 1121,562 377×248
- ✘ **18 display-plug** (the second display: plug): notes (w603) moved 2 times [jolt]
  - +0 ms 400,490 709×320 · +558 ms 426,218 1000×600 · +2599 ms 426,218 709×320 · +2618 ms 400,490 709×320
- ✘ **18 display-plug** (the second display: plug): calendar (w606) moved 2 times [jolt]
  - +0 ms 1599,770 709×503 · +477 ms 403,112 937×600 · +2618 ms -936,770 937×600
- ✘ **18 display-plug** (the second display: plug): settings (w607) moved 2 times [jolt]
  - +0 ms 1599,770 723×470 · +789 ms 437,85 723×625 · +2618 ms -722,770 723×625
- ✘ **18 display-plug** (the second display: plug): preview (w611) moved 2 times [jolt]
  - +0 ms 1599,770 708×248 · +477 ms 4,35 708×424 · +2618 ms -707,770 708×424
- ✘ **18 display-plug** (the second display: plug): mail (w612) moved 2 times [jolt]
  - +0 ms 1599,770 871×247 · +757 ms 480,192 1120×630 · +2654 ms -1119,770 1120×630
- ✘ **18 display-plug** (the second display: plug): w614 of Mail moved 2 times [jolt]
  - +0 ms 1800,822 470×416 · +757 ms 805,299 470×416 · +2654 ms -794,877 470×416
- ✘ **27 display-unplug** (the second display: unplug): finder (w585) moved 2 times [jolt]
  - +0 ms 400,43 709×252 · +197 ms 340,120 920×436 · +1972 ms 340,120 709×252 · +2022 ms 400,43 709×252
- ✘ **27 display-unplug** (the second display: unplug): safari (w588) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -1323,770 1324×791 · +197 ms 67,31 1324×791 · +2073 ms 1599,770 1324×791
- ✘ **27 display-unplug** (the second display: unplug): textedit (w596) moved 2 times [jolt]
  - +0 ms 12,562 376×248 · +197 ms 165,65 656×422 · +1979 ms 165,65 376×248 · +2022 ms 12,562 376×248
- ✘ **27 display-unplug** (the second display: unplug): terminal (w602) moved 2 times [jolt]
  - +0 ms 1121,562 377×248 · +197 ms 799,31 860×503 · +2022 ms 1121,562 377×248
- ✘ **27 display-unplug** (the second display: unplug): notes (w603) moved 2 times [jolt]
  - +0 ms 400,490 709×320 · +197 ms 426,218 1000×600 · +2035 ms 426,218 709×320 · +2073 ms 400,490 709×320
- ✘ **27 display-unplug** (the second display: unplug): calendar (w606) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -936,770 937×600 · +197 ms 403,112 937×600 · +2073 ms 1599,770 937×600
- ✘ **27 display-unplug** (the second display: unplug): settings (w607) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -722,770 723×625 · +197 ms 437,85 723×625 · +2073 ms 1599,770 723×625
- ✘ **27 display-unplug** (the second display: unplug): preview (w611) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -707,770 708×424 · +197 ms 4,35 708×424 · +2073 ms 1599,770 708×424
- ✘ **27 display-unplug** (the second display: unplug): mail (w612) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -1119,770 1120×630 · +197 ms 480,192 1120×630 · +2073 ms 1599,770 1120×630
- ✘ **27 display-unplug** (the second display: unplug): w614 of Mail is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -794,877 470×416 · +197 ms 805,299 470×416 · +2073 ms 1924,877 470×416
- ✘ **29 display-plug** (the second display: plug): finder (w585) moved 2 times [jolt]
  - +0 ms 400,43 709×252 · +259 ms 340,120 920×436 · +2155 ms 340,120 709×252 · +2199 ms 400,43 709×252
- ✘ **29 display-plug** (the second display: plug): safari (w588) moved 2 times [jolt]
  - +0 ms 1599,770 1324×791 · +29 ms 67,31 1324×791 · +2270 ms -1323,770 1324×791
- ✘ **29 display-plug** (the second display: plug): textedit (w596) moved 2 times [jolt]
  - +0 ms 12,562 376×248 · +29 ms 165,65 656×422 · +2155 ms 165,65 376×248 · +2199 ms 12,562 376×248
- ✘ **29 display-plug** (the second display: plug): terminal (w602) moved 2 times [jolt]
  - +0 ms 1121,562 377×248 · +29 ms 799,31 860×503 · +2199 ms 1121,562 377×248
- ✘ **29 display-plug** (the second display: plug): notes (w603) moved 2 times [jolt]
  - +0 ms 400,490 709×320 · +259 ms 426,218 1000×600 · +2270 ms 400,490 709×320
- ✘ **29 display-plug** (the second display: plug): calendar (w606) moved 2 times [jolt]
  - +0 ms 1599,770 937×600 · +29 ms 403,112 937×600 · +2270 ms -936,770 937×600
- ✘ **29 display-plug** (the second display: plug): settings (w607) moved 2 times [jolt]
  - +0 ms 1599,770 723×625 · +259 ms 437,85 723×625 · +2270 ms -722,770 723×625
- ✘ **29 display-plug** (the second display: plug): preview (w611) moved 2 times [jolt]
  - +0 ms 1599,770 708×424 · +29 ms 4,35 708×424 · +2270 ms -707,770 708×424
- ✘ **29 display-plug** (the second display: plug): mail (w612) moved 2 times [jolt]
  - +0 ms 1599,770 1120×630 · +29 ms 480,192 1120×630 · +2270 ms -1119,770 1120×630
- ✘ **29 display-plug** (the second display: plug): w614 of Mail moved 2 times [jolt]
  - +0 ms 1924,877 470×416 · +29 ms 805,299 470×416 · +2270 ms -794,877 470×416
- ✘ **31 display-unplug** (the second display: unplug): finder (w585) moved 2 times [jolt]
  - +0 ms 400,43 709×252 · +149 ms 340,120 920×436 · +1874 ms 400,43 709×252
- ✘ **31 display-unplug** (the second display: unplug): safari (w588) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -1323,770 1324×791 · +149 ms 67,31 1324×791 · +1933 ms 1599,770 1324×791
- ✘ **31 display-unplug** (the second display: unplug): textedit (w596) moved 2 times [jolt]
  - +0 ms 12,562 376×248 · +149 ms 165,65 656×422 · +1874 ms 12,562 376×248
- ✘ **31 display-unplug** (the second display: unplug): terminal (w602) moved 2 times [jolt]
  - +0 ms 1121,562 377×248 · +149 ms 799,31 860×503 · +1874 ms 1121,562 377×248
- ✘ **31 display-unplug** (the second display: unplug): notes (w603) moved 2 times [jolt]
  - +0 ms 400,490 709×320 · +149 ms 426,218 1000×600 · +1886 ms 426,218 709×320 · +1933 ms 400,490 709×320
- ✘ **31 display-unplug** (the second display: unplug): calendar (w606) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -936,770 937×600 · +149 ms 403,112 937×600 · +1933 ms 1599,770 937×600
- ✘ **31 display-unplug** (the second display: unplug): settings (w607) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -722,770 723×625 · +179 ms 437,85 723×625 · +1933 ms 1599,770 723×625
- ✘ **31 display-unplug** (the second display: unplug): preview (w611) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -707,770 708×424 · +149 ms 4,35 708×424 · +1933 ms 1599,770 708×424
- ✘ **31 display-unplug** (the second display: unplug): mail (w612) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -1119,770 1120×630 · +149 ms 480,192 1120×630 · +1933 ms 1599,770 1120×630
- ✘ **31 display-unplug** (the second display: unplug): w614 of Mail is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -794,877 470×416 · +149 ms 805,299 470×416 · +1933 ms 1924,877 470×416
- ✘ **33 display-plug** (the second display: plug): finder (w585) moved 2 times [jolt]
  - +0 ms 400,43 709×252 · +16 ms 340,120 920×436 · +2506 ms 340,120 709×252 · +2536 ms 400,43 709×252
- ✘ **33 display-plug** (the second display: plug): safari (w588) moved 2 times [jolt]
  - +0 ms 1599,770 1324×791 · +16 ms 67,31 1324×791 · +2585 ms -1323,770 1324×791
- ✘ **33 display-plug** (the second display: plug): textedit (w596) moved 2 times [jolt]
  - +0 ms 12,562 376×248 · +16 ms 165,65 656×422 · +2506 ms 12,562 376×248
- ✘ **33 display-plug** (the second display: plug): terminal (w602) moved 3 times [jolt]
  - +0 ms 1121,562 377×248 · +16 ms 799,31 860×503 · +663 ms 740,31 860×503 · +2536 ms 1121,562 377×248
- ✘ **33 display-plug** (the second display: plug): notes (w603) moved 2 times [jolt]
  - +0 ms 400,490 709×320 · +226 ms 426,218 1000×600 · +2575 ms 400,490 709×320
- ✘ **33 display-plug** (the second display: plug): calendar (w606) moved 2 times [jolt]
  - +0 ms 1599,770 937×600 · +16 ms 403,112 937×600 · +2604 ms -936,770 937×600
- ✘ **33 display-plug** (the second display: plug): settings (w607) moved 2 times [jolt]
  - +0 ms 1599,770 723×625 · +234 ms 437,85 723×625 · +2604 ms -722,770 723×625
- ✘ **33 display-plug** (the second display: plug): preview (w611) moved 2 times [jolt]
  - +0 ms 1599,770 708×424 · +16 ms 4,35 708×424 · +2604 ms -707,770 708×424
- ✘ **33 display-plug** (the second display: plug): mail (w612) moved 2 times [jolt]
  - +0 ms 1599,770 1120×630 · +16 ms 480,192 1120×630 · +2604 ms -1119,770 1120×630
- ✘ **33 display-plug** (the second display: plug): w614 of Mail is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1924,877 470×416 · +16 ms 805,299 470×416 · +2604 ms -794,877 470×416
- ✘ **57 display-left** (the second display: left): finder (w585) moved 2 times [jolt]
  - +0 ms 12,43 1576×767 · +36 ms 340,120 920×436 · +1973 ms 12,43 920×436 · +1978 ms 12,43 1576×767
- ✘ **57 display-left** (the second display: left): safari (w588) moved 2 times [jolt]
  - +0 ms -1323,770 1324×791 · +36 ms 67,31 1324×791 · +1998 ms 1599,770 1324×791
- ✘ **57 display-left** (the second display: left): textedit (w596) moved 2 times [jolt]
  - +0 ms -375,790 376×248 · +36 ms 165,65 656×422 · +1998 ms 1599,790 656×422
- ✘ **57 display-left** (the second display: left): terminal (w602) moved 2 times [jolt]
  - +0 ms -376,790 377×248 · +245 ms 799,31 860×503 · +1998 ms 1599,790 860×503
- ✘ **57 display-left** (the second display: left): notes (w603) moved 2 times [jolt]
  - +0 ms -1575,770 1576×767 · +36 ms 426,218 1000×600 · +1998 ms 1599,770 1000×600
- ✘ **57 display-left** (the second display: left): calendar (w606) moved 2 times [jolt]
  - +0 ms -936,770 937×600 · +245 ms 403,112 937×600 · +1998 ms 1599,770 937×600
- ✘ **57 display-left** (the second display: left): settings (w607) moved 2 times [jolt]
  - +0 ms -722,770 723×767 · +245 ms 437,85 723×625 · +1998 ms 1599,770 723×625
- ✘ **57 display-left** (the second display: left): preview (w611) moved 2 times [jolt]
  - +0 ms -707,770 708×424 · +36 ms 4,35 708×424 · +1998 ms 1599,770 708×424
- ✘ **57 display-left** (the second display: left): mail (w612) moved 2 times [jolt]
  - +0 ms -1119,770 1120×630 · +245 ms 480,192 1120×630 · +1998 ms 1599,770 1120×630
- ✘ **57 display-left** (the second display: left): w614 of Mail is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -794,877 470×416 · +245 ms 805,299 470×416 · +1998 ms 1924,877 470×416
- ✘ **60 drag-gap-beside-terminal** (drags the gap to the right of terminal by -40 points): terminal (w602) moved 3 times [jolt]
  - +0 ms 1121,562 377×248 · +746 ms 1121,562 370×248 · +799 ms 1123,562 370×248 · +865 ms 1121,562 370×248 · +1084 ms 1123,562 363×248 · +1140 ms 1122,562 363×248 · … 6 more … · +2191 ms 1123,562 342×248 · +2247 ms 1121,562 342×248 · +2574 ms 1121,562 335×248 · +2650 ms 1122,562 335×248 · +2757 ms 1121,562 335×248
- ✘ **62 display-unplug** (the second display: unplug): finder (w585) moved 2 times [jolt]
  - +0 ms 400,43 709×252 · +11 ms 340,120 920×436 · +2048 ms 400,43 709×252
- ✘ **62 display-unplug** (the second display: unplug): safari (w588) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 1324×791 · +11 ms 67,31 1324×791 · +2162 ms 1599,770 1324×791
- ✘ **62 display-unplug** (the second display: unplug): textedit (w596) moved 2 times [jolt]
  - +0 ms 12,562 376×248 · +11 ms 165,65 656×422 · +2048 ms 12,562 376×248
- ✘ **62 display-unplug** (the second display: unplug): terminal (w602) moved 2 times [jolt]
  - +0 ms 1121,562 335×248 · +11 ms 799,31 860×503 · +2048 ms 1121,562 335×248
- ✘ **62 display-unplug** (the second display: unplug): notes (w603) moved 2 times [jolt]
  - +0 ms 400,490 709×320 · +11 ms 426,218 1000×600 · +2099 ms 426,218 709×320 · +2162 ms 400,490 709×320
- ✘ **62 display-unplug** (the second display: unplug): calendar (w606) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 937×600 · +11 ms 403,112 937×600 · +2162 ms 1599,770 937×600
- ✘ **62 display-unplug** (the second display: unplug): settings (w607) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 723×625 · +205 ms 437,85 723×625 · +2162 ms 1599,770 723×625
- ✘ **62 display-unplug** (the second display: unplug): preview (w611) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 708×424 · +11 ms 4,35 708×424 · +2162 ms 1599,770 708×424
- ✘ **62 display-unplug** (the second display: unplug): mail (w612) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 1120×630 · +11 ms 480,192 1120×630 · +2162 ms 1599,770 1120×630
- ✘ **62 display-unplug** (the second display: unplug): w614 of Mail is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1924,877 470×416 · +11 ms 805,299 470×416 · +2162 ms 1924,877 470×416
- ✘ **76 launch** (starts Arbor): safari (w588) moved 2 times [jolt]
  - +0 ms 67,31 1324×790 · +223 ms 67,31 574×247 · +480 ms 1599,770 574×247
- ✘ **76 launch** (starts Arbor): preview (w611) went 352 points out of its way before it ended up [jolt]
  - +0 ms 4,35 708×424 · +396 ms 4,35 708×248 · +595 ms 4,35 708×424
- ✘ **83 drag-calendar-to-right-edge** (drags calendar by its title bar against the right edge of the screen and lets go): calendar (w606) was 52 points ahead of the pointer's travel and 0 behind it at the most [pulled]
  - +0 ms 394,147 937×600 · +125 ms 425,158 937×600 · +131 ms 456,168 937×600 · +192 ms 487,178 937×600 · +211 ms 518,189 937×600 · +284 ms 549,199 937×600 · … 18 more … · +1642 ms 1221,294 937×600 · +1698 ms 1252,300 937×600 · +1833 ms 1284,300 937×600 · +2074 ms 1285,300 937×600 · +2241 ms 1284,300 937×600
- ✘ **88 display-plug** (the second display: plug): finder (w585) moved 2 times [jolt]
  - +0 ms 400,43 709×380 · +310 ms 340,120 920×436 · +2331 ms 400,43 709×380
- ✘ **88 display-plug** (the second display: plug): textedit (w596) moved 2 times [jolt]
  - +0 ms 12,433 376×377 · +29 ms 165,65 656×422 · +2331 ms 12,433 376×377
- ✘ **88 display-plug** (the second display: plug): notes (w603) moved 2 times [jolt]
  - +0 ms 400,435 709×375 · +310 ms 426,218 1000×600 · +2369 ms 400,435 709×375
- ✘ **88 display-plug** (the second display: plug): settings (w607) moved 2 times [jolt]
  - +0 ms 1599,770 723×470 · +633 ms 437,85 723×625 · +2369 ms -722,770 723×625
- ✘ **88 display-plug** (the second display: plug): preview (w611) moved 2 times [jolt]
  - +0 ms 1599,770 1576×378 · +310 ms 4,35 708×424 · +2369 ms -707,770 708×424
- ✘ **88 display-plug** (the second display: plug): mail (w612) moved 2 times [jolt]
  - +0 ms 1599,770 871×247 · +649 ms 480,192 1120×630 · +2369 ms -1119,770 1120×630
- ✘ **88 display-plug** (the second display: plug): w614 of Mail moved 2 times [jolt]
  - +0 ms 1800,822 470×416 · +649 ms 805,299 470×416 · +2369 ms -794,877 470×416
- ✘ **94 display-unplug** (the second display: unplug): calendar (w606) moved 2 times [jolt]
  - +0 ms 800,32 801×790 · +132 ms 1284,300 937×600 · +1848 ms 663,222 937×600
- ✘ **96 display-plug** (the second display: plug): calendar (w606) moved 2 times [jolt]
  - +0 ms 663,222 937×600 · +148 ms 1284,300 937×600 · +533 ms 663,300 937×600
- ✘ **115 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): preview (w611) was 52 points ahead of the pointer's travel and 0 behind it at the most [pulled]
  - +0 ms 0,433 1576×377 · +89 ms -26,433 1576×377 · +93 ms -77,433 1576×377 · +194 ms -103,433 1576×377 · +261 ms -128,433 1576×377 · +314 ms -154,434 1576×377 · … 17 more … · +1792 ms -717,437 1576×377 · +1893 ms -743,437 1576×377 · +1962 ms -768,438 1576×377 · +2228 ms -767,438 1576×377 · +2348 ms -768,438 1576×377
- ✘ **116 display-unplug** (the second display: unplug): calendar (w606) moved 2 times [jolt]
  - +0 ms 663,300 937×600 · +172 ms 1284,300 937×600 · +2067 ms 663,222 937×600
- ✘ **128 display-unplug** (the second display: unplug): calendar (w606) moved 2 times [jolt]
  - +0 ms 1284,300 801×780 · +404 ms 1284,300 937×600 · +2128 ms 663,222 937×600
- ✘ **128 display-unplug** (the second display: unplug): settings (w607) moved 2 times [jolt]
  - +0 ms 438,43 723×470 · +404 ms 437,85 723×625 · +2128 ms 438,43 723×470

### Rule 4: the window you switch to comes to the front and into view

- ✘ **23 undo** (presses ctrl+opt+z): the app in front changed (to process 23940), and nobody switched [focus]
- ✘ **98 dock-icon-safari** (clicks safari's icon in the Dock): safari (w588) is not wholly in view: 90% of it, at 0,109 1324×791 in 0,31 1600×791 and 1600,31 1280×769 [focus]
- ✘ **124 dock-icon-safari** (clicks safari's icon in the Dock): safari (w588) is not wholly in view: 90% of it, at 0,109 1324×791 in 0,31 1600×791 and 1600,31 1920×1049 [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **21 float-all** (chooses `float-all` from Arbor's menu): terminal (w602) is 800,34 797×788; its own size was 800,35 800×784 [size-lost]
- ✘ **72 quit** (chooses Quit Arbor in Arbor's menu): terminal (w602) is 800,34 797×788; its own size was 800,35 800×784 [size-lost]
- ✘ **91 float-all** (chooses `float-all` from Arbor's menu): safari (w588) is 67,31 1324×790; its own size was 104,43 574×378 [size-lost]
- ✘ **91 float-all** (chooses `float-all` from Arbor's menu): terminal (w602) is 803,31 797×791; its own size was 803,33 797×788 [size-lost]
- ✘ **121 float-all** (chooses `float-all` from Arbor's menu): safari (w588) is 0,109 1324×791; its own size was 104,43 574×378 [size-lost]
- ✘ **121 float-all** (chooses `float-all` from Arbor's menu): textedit (w596) is 165,65 656×422; its own size was 165,65 673×439 [size-lost]
- ✘ **121 float-all** (chooses `float-all` from Arbor's menu): terminal (w602) is 803,31 797×791; its own size was 803,33 797×788 [size-lost]
- ✘ **121 float-all** (chooses `float-all` from Arbor's menu): calendar (w606) is 1284,300 801×780; its own size was 800,32 801×791 [size-lost]
- ✘ **131 quit** (chooses Quit Arbor in Arbor's menu): textedit (w596) is 165,65 656×422; its own size was 165,65 673×439 [size-lost]
- ✘ **131 quit** (chooses Quit Arbor in Arbor's menu): terminal (w602) is 803,31 797×791; its own size was 803,33 797×788 [size-lost]
- ✘ **131 quit** (chooses Quit Arbor in Arbor's menu): preview (w611) is -768,438 1576×377; its own size was 2159,160 804×791 [size-lost]

### Rule L: no window is lost or stuck

- ✘ **28 view-home** (chooses `home` from Arbor's menu): safari (w588) is out of view: 0% of it is on a display, at 1599,770 1324×791 [lost]
- ✘ **28 view-home** (chooses `home` from Arbor's menu): calendar (w606) is out of view: 0% of it is on a display, at 1599,770 937×600 [lost]
- ✘ **28 view-home** (chooses `home` from Arbor's menu): mail (w612) is out of view: 0% of it is on a display, at 1599,770 1120×630 [lost]
- ✘ **32 view-home** (chooses `home` from Arbor's menu): safari (w588) is out of view: 0% of it is on a display, at 1599,770 1324×791 [lost]
- ✘ **32 view-home** (chooses `home` from Arbor's menu): calendar (w606) is out of view: 0% of it is on a display, at 1599,770 937×600 [lost]
- ✘ **32 view-home** (chooses `home` from Arbor's menu): mail (w612) is out of view: 0% of it is on a display, at 1599,770 1120×630 [lost]
- ✘ **34 view-home** (chooses `home` from Arbor's menu): safari (w588) is out of view: 0% of it is on a display, at -1323,770 1324×791 [lost]
- ✘ **34 view-home** (chooses `home` from Arbor's menu): calendar (w606) is out of view: 0% of it is on a display, at -936,770 937×600 [lost]
- ✘ **34 view-home** (chooses `home` from Arbor's menu): mail (w612) is out of view: 0% of it is on a display, at -1119,770 1120×630 [lost]
- ✘ **63 view-home** (chooses `home` from Arbor's menu): calendar (w606) is out of view: 0% of it is on a display, at 1599,770 937×600 [lost]
- ✘ **63 view-home** (chooses `home` from Arbor's menu): mail (w612) is out of view: 0% of it is on a display, at 1599,770 1120×630 [lost]
- ✘ **76 launch** (starts Arbor): safari (w588) is out of view: 0% of it is on a display, at 1599,770 574×247 [lost]
- ✘ **76 launch** (starts Arbor): calendar (w606) is out of view: 0% of it is on a display, at 1599,770 680×503 [lost]
- ✘ **76 launch** (starts Arbor): settings (w607) is out of view: 0% of it is on a display, at 1599,770 723×470 [lost]
- ✘ **76 launch** (starts Arbor): mail (w612) is out of view: 0% of it is on a display, at 1599,770 871×247 [lost]

### Rule -: what the script itself checked

- ~ **42 drag-notes-by** (drags notes, which floats, by its title bar 126 across and 53 down): the act was not performed: drag_window could not be done [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (2, 70 ms) | quiet 1119 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 645 ms; blind for 448 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit |  | quiet 855 ms; blind for 1016 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (2, 47 ms) | quiet 1035 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (2, 51 ms) | quiet 1044 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (6, 383 ms) | quiet 1404 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 969 ms; blind for 245 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (5, 57 ms) | quiet 1071 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w614 ×1 (6, 173 ms) | quiet 885 ms; blind for 363 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (31, 3328 ms) | quiet 1417 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×3 (36, 3195 ms) | quiet 1105 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 391 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 510 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | launch | starts Arbor |  | quiet 1200 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 15 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 563 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 16 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 481 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | arrange | chooses `arrange` from Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w614 ×1 (1, 0 ms) | quiet 1063 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 18 | display-plug | the second display: plug | finder ×2 (3, 2041 ms), safari ×2 (2, 2389 ms), textedit ×2 (2, 2318 ms), terminal ×2 (2, 2389 ms), notes ×2 (3, 2060 ms), calendar ×2 (2, 2141 ms), settings ×2 (2, 1829 ms), preview ×2 (2, 2141 ms), mail ×2 (2, 1897 ms), w614 ×2 (2, 1897 ms) | quiet 379 ms; blind for 266 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 19 | view-home | chooses `home` from Arbor's menu |  | quiet 360 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 20 | view-back | presses ctrl+opt+[ |  | quiet 695 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 21 | float-all | chooses `float-all` from Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w614 ×1 (1, 0 ms) | quiet 1114 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 22 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 491 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | undo | presses ctrl+opt+z | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w614 ×1 (1, 0 ms) | quiet 1174 ms |  |  | ✔ | ✘ |  |  | ✔ | ✔ |
| 24 | hold | holds the view, as for a shared screen |  | quiet 1056 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 25 | show-everything-while-held | presses ⌃⌥Space, which would show everything: the view is held |  | quiet 604 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 26 | release | lets the view go again |  | quiet 1114 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 27 | display-unplug | the second display: unplug | finder ×2 (3, 1825 ms), safari ×2 (2, 1876 ms), textedit ×2 (3, 1825 ms), terminal ×2 (2, 1825 ms), notes ×2 (3, 1876 ms), calendar ×2 (2, 1876 ms), settings ×2 (2, 1876 ms), preview ×2 (2, 1876 ms), mail ×2 (2, 1876 ms), w614 ×2 (2, 1876 ms) | quiet 828 ms; blind for 198 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 28 | view-home | chooses `home` from Arbor's menu |  | quiet 401 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 29 | display-plug | the second display: plug | finder ×2 (3, 1940 ms), safari ×2 (2, 2241 ms), textedit ×2 (3, 2170 ms), terminal ×2 (2, 2170 ms), notes ×2 (2, 2011 ms), calendar ×2 (2, 2241 ms), settings ×2 (2, 2011 ms), preview ×2 (2, 2241 ms), mail ×2 (2, 2241 ms), w614 ×2 (2, 2241 ms) | quiet 368 ms; blind for 230 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 30 | view-home | chooses `home` from Arbor's menu |  | quiet 365 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 31 | display-unplug | the second display: unplug | finder ×2 (2, 1725 ms), safari ×2 (2, 1784 ms), textedit ×2 (2, 1725 ms), terminal ×2 (2, 1725 ms), notes ×2 (3, 1784 ms), calendar ×2 (2, 1784 ms), settings ×2 (2, 1754 ms), preview ×2 (2, 1784 ms), mail ×2 (2, 1784 ms), w614 ×2 (2, 1784 ms) | quiet 700 ms; blind for 187 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 32 | view-home | chooses `home` from Arbor's menu |  | quiet 398 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 33 | display-plug | the second display: plug | finder ×2 (3, 2520 ms), safari ×2 (2, 2569 ms), textedit ×2 (2, 2490 ms), terminal ×3 (3, 2520 ms), notes ×2 (2, 2349 ms), calendar ×2 (2, 2588 ms), settings ×2 (2, 2370 ms), preview ×2 (2, 2588 ms), mail ×2 (2, 2588 ms), w614 ×2 (2, 2588 ms) | quiet 385 ms; blind for 209 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 34 | view-home | chooses `home` from Arbor's menu |  | quiet 413 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 35 | view-in | chooses `in` from Arbor's menu | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 1178 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 36 | view-all | presses ctrl+opt+space | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 843 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 37 | click-terminal | clicks terminal's title bar |  | quiet 373 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | undo | presses ctrl+opt+z | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w614 ×1 (1, 0 ms) | quiet 1256 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 39 | view-back | presses ctrl+opt+[ |  | quiet 607 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 40 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 405 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 41 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 449 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | drag-notes-by | drags notes, which floats, by its title bar 126 across and 53 down |  | quiet 1004 ms |  |  |  |  |  |  |  | ~ |
| 43 | click-settings | clicks settings's title bar |  | quiet 364 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | pin | chooses Keep This Window in View in Arbor's menu, or takes the tick off |  | quiet 363 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 45 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 381 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 46 | redo | chooses `redo` from Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w614 ×1 (1, 0 ms) | quiet 925 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 47 | display-right | the second display: right |  | quiet 410 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 48 | view-home | chooses `home` from Arbor's menu |  | quiet 377 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 49 | leave-alone | does nothing for half a minute |  | quiet 422 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 50 | view-frame | presses ctrl+opt+return | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 1067 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 51 | dock-icon-settings | clicks settings's icon in the Dock | finder ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 629 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 52 | dock-down | chooses `dock bottom` from Arbor's menu |  | quiet 352 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 53 | dock-icon-notes | clicks notes's icon in the Dock | notes ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 516 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 54 | dock-left | presses ctrl+opt+left |  | quiet 684 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 55 | dock-icon-finder | clicks finder's icon in the Dock | finder ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 618 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 56 | new-window-finder | presses ⌘N in finder |  | quiet 1077 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 57 | display-left | the second display: left | finder ×2 (3, 1942 ms), safari ×2 (2, 1962 ms), textedit ×2 (2, 1962 ms), terminal ×2 (2, 1753 ms), notes ×2 (2, 1962 ms), calendar ×2 (2, 1753 ms), settings ×2 (2, 1753 ms), preview ×2 (2, 1962 ms), mail ×2 (2, 1753 ms), w614 ×2 (2, 1753 ms) | quiet 372 ms; blind for 209 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 58 | view-home | chooses `home` from Arbor's menu | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 994 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 59 | close-window | presses ⌘W |  | quiet 1130 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 60 | drag-gap-beside-terminal | drags the gap to the right of terminal by -40 points | terminal ×3 (16, 2011 ms) | quiet 1124 ms |  | ✔ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | view-all | presses ctrl+opt+space |  | quiet 685 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 62 | display-unplug | the second display: unplug | finder ×2 (2, 2037 ms), safari ×2 (2, 2151 ms), textedit ×2 (2, 2037 ms), terminal ×2 (2, 2037 ms), notes ×2 (3, 2151 ms), calendar ×2 (2, 2151 ms), settings ×2 (2, 1957 ms), preview ×2 (2, 2151 ms), mail ×2 (2, 2151 ms), w614 ×2 (2, 2151 ms) | quiet 637 ms; blind for 163 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 63 | view-home | chooses `home` from Arbor's menu |  | quiet 367 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 64 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) |  | quiet 428 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 65 | dock-icon-safari | clicks safari's icon in the Dock | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 770 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 66 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 368 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 67 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 363 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 68 | leave-alone | does nothing for half a minute |  | quiet 381 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 69 | grow | chooses `grow` from Arbor's menu |  | quiet 378 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 70 | view-out | chooses `out` from Arbor's menu | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 1082 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 71 | save-view-2 | chooses `save-view 2` from Arbor's menu |  | quiet 370 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 72 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (2, 5 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w614 ×1 (1, 0 ms) | quiet 852 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 73 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 363 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 74 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 424 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 75 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 353 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 76 | launch | starts Arbor | finder ×1 (2, 41 ms), safari ×2 (2, 257 ms), textedit ×1 (2, 41 ms), terminal ×1 (3, 150 ms), notes ×1 (2, 170 ms), calendar ×1 (2, 176 ms), settings ×1 (2, 120 ms), preview ×1 (2, 199 ms), mail ×1 (2, 235 ms), w614 ×1 (2, 235 ms) | quiet 864 ms |  | ~ | ✘ |  |  |  | ✘ | ✔ |
| 77 | view-in | chooses `in` from Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 1241 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 78 | click-safari | clicks safari's title bar |  | quiet 400 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 79 | float | presses ⌃⌥F | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 688 ms |  | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 80 | view-frame | presses ctrl+opt+return | safari ×1 (1, 0 ms) | quiet 801 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 81 | dock-icon-calendar | clicks calendar's icon in the Dock | textedit ×1 (1, 0 ms), calendar ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 593 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 82 | pin | chooses Keep This Window in View in Arbor's menu, or takes the tick off | finder ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 1101 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 83 | drag-calendar-to-right-edge | drags calendar by its title bar against the right edge of the screen and lets go | calendar ×1 (10, 351 ms) | quiet 396 ms | ✔ | ✔ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 84 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 373 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 85 | view-all | presses ctrl+opt+space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 877 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 86 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 399 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 87 | drag-terminal-to-right-edge | drags terminal by its title bar against the right edge of the screen and lets go | terminal ×1 (1, 0 ms) | quiet 420 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 88 | display-plug | the second display: plug | finder ×2 (2, 2021 ms), safari ×1 (1, 0 ms), textedit ×2 (2, 2302 ms), terminal ×1 (1, 0 ms), notes ×2 (2, 2059 ms), calendar ×1 (1, 0 ms), settings ×2 (2, 1736 ms), preview ×2 (2, 2059 ms), mail ×2 (2, 1720 ms), w614 ×2 (2, 1720 ms) | quiet 368 ms; blind for 281 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 89 | view-home | chooses `home` from Arbor's menu |  | quiet 366 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 90 | drag-safari-by | drags safari, which floats, by its title bar -100 across and 91 down | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 1503 ms; blind for 254 ms | ✔ | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 91 | float-all | chooses `float-all` from Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (4, 133 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w614 ×1 (1, 0 ms) | quiet 1228 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 92 | view-out | chooses `out` from Arbor's menu |  | quiet 434 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 93 | view-frame | presses ctrl+opt+return | safari ×1 (2, 45 ms) | quiet 798 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 94 | display-unplug | the second display: unplug | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), calendar ×2 (2, 1716 ms) | quiet 587 ms; blind for 134 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 95 | view-home | chooses `home` from Arbor's menu |  | quiet 369 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 96 | display-plug | the second display: plug | calendar ×2 (2, 385 ms) | quiet 363 ms; blind for 133 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 97 | view-home | chooses `home` from Arbor's menu |  | quiet 374 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 98 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 415 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 99 | new-window-safari | presses ⌘N in safari |  | quiet 984 ms; blind for 158 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 100 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 416 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 101 | dock-down | chooses `dock bottom` from Arbor's menu | preview ×1 (1, 0 ms) | quiet 1053 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 102 | click-new-window | clicks the title bar of the window that ⌘N opened |  | quiet 351 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 103 | close-window | presses ⌘W |  | quiet 881 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 104 | view-all | presses ctrl+opt+space |  | quiet 689 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 105 | peek | holds ⌃⌥Space for a second and a half and lets go |  | quiet 363 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 106 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 399 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 107 | minimize-notes | presses ⌘M | notes ×1 (19, 478 ms) | quiet 1049 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 108 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 409 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 109 | click-textedit | clicks textedit's title bar |  | quiet 466 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 110 | restore-notes | clicks notes's icon in the Dock, which brings its minimized window back | notes ×1 (12, 470 ms) | quiet 1003 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 111 | hold | holds the view, as for a shared screen |  | quiet 379 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 112 | show-everything-while-held | presses ⌃⌥Space, which would show everything: the view is held |  | quiet 750 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 113 | release | lets the view go again |  | quiet 357 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 114 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 492 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 115 | drag-preview-to-left-edge | drags preview by its title bar against the left edge of the screen and lets go | preview ×1 (10, 274 ms) | quiet 404 ms | ✔ | ✔ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 116 | display-unplug | the second display: unplug | calendar ×2 (2, 1895 ms), preview ×1 (2, 192 ms) | quiet 625 ms; blind for 192 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 117 | view-home | chooses `home` from Arbor's menu |  | quiet 418 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 118 | display-plug | the second display: plug | calendar ×1 (2, 247 ms) | quiet 389 ms; blind for 200 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 119 | view-home | chooses `home` from Arbor's menu |  | quiet 393 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 120 | send-across | sends the window in front to the other display | preview ×1 (1, 0 ms) | quiet 1053 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 121 | float-all | chooses `float-all` from Arbor's menu |  | quiet 361 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 122 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 454 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 123 | dock-up | chooses `dock top` from Arbor's menu | settings ×1 (1, 0 ms) | quiet 1188 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 124 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 443 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 125 | quit-safari | presses ⌘Q in safari |  | quiet 799 ms; blind for 121 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 126 | view-home | chooses `home` from Arbor's menu |  | quiet 379 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 127 | reopen-safari | opens safari's document again |  | quiet 555 ms; blind for 462 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 128 | display-unplug | the second display: unplug | calendar ×2 (2, 1724 ms), settings ×2 (2, 1724 ms), preview ×1 (1, 0 ms) | quiet 567 ms; blind for 416 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 129 | view-home | chooses `home` from Arbor's menu |  | quiet 373 ms |  |  | ✔ |  |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 130 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 686 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 131 | quit | chooses Quit Arbor in Arbor's menu | calendar ×1 (2, 9 ms), settings ×1 (1, 0 ms) | quiet 944 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 132 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 713 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 133 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 409 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 134 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 519 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 135 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 351 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 136 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 355 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 137 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 402 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 138 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 494 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 139 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 518 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 140 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 418 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 141 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 448 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
