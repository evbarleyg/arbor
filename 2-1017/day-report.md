141 steps in 599 s, 111 of them judged, 28 with a rule broken. The sampler: samples 20558 seconds 547.1 hz 37.6 cost-ms 4.75 late 124 longest-gap-ms 1897 whole-samples 22543 whole-seconds 599.9 whole-late 133.
Input: 288 presses, releases, keys and scrolls reached the apps, half of them within 687 µs, 99 in 100 within 76227 µs, the latest after 99808 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 19, 1186, 6585; dragged 197, 684, 5366; forward 12, 6902, 86809; key 29, 450, 2610; up 31, 965, 99808. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 41837; up 8, 1062.
The round of input `started` (events, half within µs): forward 8, 71977; up 8, 3825.
The round of input `last` (events, half within µs): forward 11, 43124; up 11, 1074.
The round of input `after` (events, half within µs): forward 12, 42399; up 12, 640.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 5 | 0 |  |
| 2 | nothing moves that the person did not move | 74 | 1 | 90 drag-safari-by |
| 3 | no jolts: a window moves once, to where it ends up | 129 | 18 | 17 arrange, 18 display-plug, 28 display-unplug, 30 display-plug, 32 display-unplug, 34 display-plug, 51 view-frame, 58 display-left, 61 drag-gap-beside-terminal, 63 display-unplug, 77 launch, 78 view-in … |
| 4 | the window you switch to comes to the front and into view | 66 | 3 | 24 undo, 98 dock-icon-safari, 124 dock-icon-safari |
| 5 | quitting, Float All and pause give windows their own sizes back | 6 | 3 | 91 float-all, 121 float-all, 131 quit |
| 6 | what a person presses reaches the apps, at once | 47 | 0 |  |
| L | no window is lost or stuck | 129 | 4 | 29 view-home, 33 view-home, 64 view-home, 77 launch |
| - | what the script itself checked | 129 | 0 |  |

## Findings

### Rule 2: nothing moves that the person did not move

- ~ **77 launch** (starts Arbor): w357 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,179 470×416 · +635 ms 441,124 470×416 · +1113 ms 1800,822 470×416
- ✘ **90 drag-safari-by** (drags safari, which floats, by its title bar -100 across and 91 down): finder (w326) moved, and the step did not name it [moved-unasked]
  - +0 ms 865,43 723×285 · +4162 ms 865,43 501×285 · +4203 ms 1087,43 501×378
- ✘ **90 drag-safari-by** (drags safari, which floats, by its title bar -100 across and 91 down): textedit (w337) moved, and the step did not name it [moved-unasked]
  - +0 ms 471,43 382×378 · +4162 ms 471,43 343×378 · +4323 ms 732,43 343×378
- ✘ **90 drag-safari-by** (drags safari, which floats, by its title bar -100 across and 91 down): settings (w349) moved, and the step did not name it [moved-unasked]
  - +0 ms 865,340 723×470 · +4339 ms -722,770 723×470
- ✘ **90 drag-safari-by** (drags safari, which floats, by its title bar -100 across and 91 down): preview (w353) moved, and the step did not name it [moved-unasked]
  - +0 ms -707,770 708×424 · +4323 ms -707,770 708×377 · +4339 ms 12,433 708×377

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **17 arrange** (chooses `arrange` from Arbor's menu): finder (w326) moved 2 times [jolt]
  - +0 ms 340,120 920×436 · +564 ms 340,120 501×252 · +1081 ms 1087,43 501×252
- ✘ **17 arrange** (chooses `arrange` from Arbor's menu): safari (w329) moved 2 times [jolt]
  - +0 ms 138,31 1324×791 · +102 ms 138,31 574×248 · +1172 ms 1599,770 574×248
- ✘ **17 arrange** (chooses `arrange` from Arbor's menu): notes (w347) moved 2 times [jolt]
  - +0 ms 0,105 1000×660 · +284 ms 0,105 709×320 · +1146 ms 12,43 709×320
- ✘ **17 arrange** (chooses `arrange` from Arbor's menu): calendar (w348) moved 2 times [jolt]
  - +0 ms 403,115 937×600 · +467 ms 403,115 680×503 · +1210 ms 1599,770 680×503
- ✘ **17 arrange** (chooses `arrange` from Arbor's menu): preview (w353) went 16 points out of its way before it ended up [jolt]
  - +0 ms 4,35 708×424 · +1001 ms 4,35 708×224 · +1146 ms 12,375 709×232
- ✘ **17 arrange** (chooses `arrange` from Arbor's menu): mail (w355) moved 2 times [jolt]
  - +0 ms 240,72 1120×630 · +774 ms 240,72 871×248 · +1210 ms 1599,770 871×248
- ✘ **17 arrange** (chooses `arrange` from Arbor's menu): w357 of Mail moved 2 times [jolt]
  - +0 ms 565,179 470×416 · +774 ms 441,124 470×416 · +1210 ms 1800,822 470×416
- ✘ **18 display-plug** (the second display: plug): finder (w326) moved 2 times [jolt]
  - +0 ms 1087,43 501×252 · +1088 ms 340,120 920×436 · +3506 ms 1087,43 501×252
- ✘ **18 display-plug** (the second display: plug): safari (w329) moved 2 times [jolt]
  - +0 ms 1599,770 574×248 · +494 ms 138,31 1324×791 · +3911 ms -1323,770 1324×791
- ✘ **18 display-plug** (the second display: plug): textedit (w337) moved 2 times [jolt]
  - +0 ms 733,303 342×247 · +494 ms 165,65 656×422 · +3534 ms 733,303 342×247
- ✘ **18 display-plug** (the second display: plug): terminal (w344) moved 2 times [jolt]
  - +0 ms 12,619 709×184 · +494 ms 40,51 863×499 · +3582 ms 12,619 709×184
- ✘ **18 display-plug** (the second display: plug): notes (w347) moved 2 times [jolt]
  - +0 ms 12,43 709×320 · +494 ms 0,105 1000×660 · +3686 ms 0,105 709×320 · +3702 ms 12,43 709×320
- ✘ **18 display-plug** (the second display: plug): calendar (w348) moved 2 times [jolt]
  - +0 ms 1599,770 680×503 · +971 ms 403,115 937×600 · +3911 ms -936,770 937×600
- ✘ **18 display-plug** (the second display: plug): settings (w349) moved 2 times [jolt]
  - +0 ms 1599,770 723×470 · +1316 ms 437,85 723×625 · +3911 ms -722,770 723×625
- ✘ **18 display-plug** (the second display: plug): preview (w353) moved 2 times [jolt]
  - +0 ms 12,375 709×232 · +494 ms 4,35 708×424 · +3812 ms 12,375 708×232 · +3840 ms 12,375 709×232
- ✘ **18 display-plug** (the second display: plug): mail (w355) moved 2 times [jolt]
  - +0 ms 1599,770 871×248 · +1284 ms 240,72 1120×630 · +4052 ms -1119,770 1120×630
- ✘ **18 display-plug** (the second display: plug): w357 of Mail moved 2 times [jolt]
  - +0 ms 1800,822 470×416 · +1284 ms 565,179 470×416 · +4052 ms -794,877 470×416
- ✘ **28 display-unplug** (the second display: unplug): finder (w326) moved 2 times [jolt]
  - +0 ms 1087,43 501×252 · +1081 ms 340,120 920×436 · +2757 ms 1087,43 501×252
- ✘ **28 display-unplug** (the second display: unplug): safari (w329) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -1323,770 1324×791 · +871 ms 138,31 1324×791 · +3065 ms 1599,770 1324×791
- ✘ **28 display-unplug** (the second display: unplug): textedit (w337) moved 2 times [jolt]
  - +0 ms 733,303 342×247 · +585 ms 165,65 656×422 · +2822 ms 733,303 342×247
- ✘ **28 display-unplug** (the second display: unplug): terminal (w344) moved 2 times [jolt]
  - +0 ms 12,619 709×184 · +585 ms 40,51 863×499 · +2822 ms 40,51 709×184 · +2837 ms 12,619 709×184
- ✘ **28 display-unplug** (the second display: unplug): notes (w347) moved 2 times [jolt]
  - +0 ms 12,43 709×320 · +585 ms 0,105 1000×660 · +2926 ms 12,43 709×320
- ✘ **28 display-unplug** (the second display: unplug): calendar (w348) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -936,770 937×600 · +585 ms 403,115 937×600 · +3065 ms 1599,770 937×600
- ✘ **28 display-unplug** (the second display: unplug): settings (w349) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -722,770 723×625 · +1081 ms 437,85 723×625 · +3146 ms 1599,770 723×625
- ✘ **28 display-unplug** (the second display: unplug): preview (w353) moved 2 times [jolt]
  - +0 ms 12,375 709×232 · +585 ms 4,35 708×424 · +2926 ms 4,35 708×232 · +2976 ms 12,375 709×232
- ✘ **28 display-unplug** (the second display: unplug): mail (w355) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -1119,770 1120×630 · +585 ms 240,72 1120×630 · +3146 ms 1599,770 1120×630
- ✘ **28 display-unplug** (the second display: unplug): w357 of Mail is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -794,877 470×416 · +585 ms 565,179 470×416 · +3146 ms 1924,877 470×416
- ✘ **30 display-plug** (the second display: plug): finder (w326) moved 2 times [jolt]
  - +0 ms 1087,43 501×252 · +544 ms 340,120 920×436 · +2542 ms 340,120 501×252 · +2586 ms 1087,43 501×252
- ✘ **30 display-plug** (the second display: plug): safari (w329) moved 2 times [jolt]
  - +0 ms 1599,770 1324×791 · +360 ms 138,31 1324×791 · +2829 ms -1323,770 1324×791
- ✘ **30 display-plug** (the second display: plug): textedit (w337) moved 2 times [jolt]
  - +0 ms 733,303 342×247 · +360 ms 165,65 656×422 · +2586 ms 165,65 342×247 · +2637 ms 733,303 342×247
- ✘ **30 display-plug** (the second display: plug): terminal (w344) moved 2 times [jolt]
  - +0 ms 12,619 709×184 · +360 ms 40,51 863×499 · +2637 ms 12,619 709×184
- ✘ **30 display-plug** (the second display: plug): notes (w347) moved 2 times [jolt]
  - +0 ms 12,43 709×320 · +360 ms 0,105 1000×660 · +2720 ms 12,43 709×320
- ✘ **30 display-plug** (the second display: plug): calendar (w348) moved 2 times [jolt]
  - +0 ms 1599,770 937×600 · +360 ms 403,115 937×600 · +2829 ms -936,770 937×600
- ✘ **30 display-plug** (the second display: plug): settings (w349) moved 2 times [jolt]
  - +0 ms 1599,770 723×625 · +819 ms 437,85 723×625 · +2829 ms -722,770 723×625
- ✘ **30 display-plug** (the second display: plug): preview (w353) moved 2 times [jolt]
  - +0 ms 12,375 709×232 · +360 ms 4,35 708×424 · +2745 ms 4,35 708×232 · +2829 ms 12,375 709×232
- ✘ **30 display-plug** (the second display: plug): mail (w355) moved 2 times [jolt]
  - +0 ms 1599,770 1120×630 · +544 ms 240,72 1120×630 · +2935 ms -1119,770 1120×630
- ✘ **30 display-plug** (the second display: plug): w357 of Mail moved 2 times [jolt]
  - +0 ms 1924,877 470×416 · +544 ms 565,179 470×416 · +2935 ms -794,877 470×416
- ✘ **32 display-unplug** (the second display: unplug): finder (w326) moved 2 times [jolt]
  - +0 ms 1087,43 501×252 · +478 ms 340,120 920×436 · +2221 ms 340,120 501×252 · +2268 ms 1087,43 501×252
- ✘ **32 display-unplug** (the second display: unplug): safari (w329) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -1323,770 1324×791 · +176 ms 138,31 1324×791 · +2396 ms 1599,770 1324×791
- ✘ **32 display-unplug** (the second display: unplug): textedit (w337) moved 2 times [jolt]
  - +0 ms 733,303 342×247 · +176 ms 165,65 656×422 · +2268 ms 733,303 342×247
- ✘ **32 display-unplug** (the second display: unplug): terminal (w344) moved 2 times [jolt]
  - +0 ms 12,619 709×184 · +176 ms 40,51 863×499 · +2268 ms 12,619 709×184
- ✘ **32 display-unplug** (the second display: unplug): notes (w347) moved 2 times [jolt]
  - +0 ms 12,43 709×320 · +478 ms 0,105 1000×660 · +2316 ms 12,43 709×320
- ✘ **32 display-unplug** (the second display: unplug): calendar (w348) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -936,770 937×600 · +176 ms 403,115 937×600 · +2396 ms 1599,770 937×600
- ✘ **32 display-unplug** (the second display: unplug): settings (w349) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -722,770 723×625 · +478 ms 437,85 723×625 · +2396 ms 1599,770 723×625
- ✘ **32 display-unplug** (the second display: unplug): preview (w353) moved 2 times [jolt]
  - +0 ms 12,375 709×232 · +176 ms 4,35 708×424 · +2331 ms 4,35 708×232 · +2362 ms 12,375 709×232
- ✘ **32 display-unplug** (the second display: unplug): mail (w355) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -1119,770 1120×630 · +176 ms 240,72 1120×630 · +2417 ms 1599,770 1120×630
- ✘ **32 display-unplug** (the second display: unplug): w357 of Mail is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -794,877 470×416 · +176 ms 565,179 470×416 · +2417 ms 1924,877 470×416
- ✘ **34 display-plug** (the second display: plug): finder (w326) moved 2 times [jolt]
  - +0 ms 1087,43 501×252 · +574 ms 340,120 920×436 · +3153 ms 1087,43 501×252
- ✘ **34 display-plug** (the second display: plug): safari (w329) moved 2 times [jolt]
  - +0 ms 1599,770 1324×791 · +53 ms 138,31 1324×791 · +3309 ms -1323,770 1324×791
- ✘ **34 display-plug** (the second display: plug): textedit (w337) moved 2 times [jolt]
  - +0 ms 733,303 342×247 · +53 ms 165,65 656×422 · +3153 ms 733,303 342×247
- ✘ **34 display-plug** (the second display: plug): terminal (w344) moved 2 times [jolt]
  - +0 ms 12,619 709×184 · +369 ms 40,51 863×499 · +3164 ms 40,51 709×184 · +3200 ms 12,619 709×184
- ✘ **34 display-plug** (the second display: plug): notes (w347) moved 2 times [jolt]
  - +0 ms 12,43 709×320 · +574 ms 0,105 1000×660 · +3228 ms 12,43 709×320
- ✘ **34 display-plug** (the second display: plug): calendar (w348) moved 2 times [jolt]
  - +0 ms 1599,770 937×600 · +369 ms 403,115 937×600 · +3329 ms -936,770 937×600
- ✘ **34 display-plug** (the second display: plug): settings (w349) moved 2 times [jolt]
  - +0 ms 1599,770 723×625 · +780 ms 437,85 723×625 · +3383 ms -722,770 723×625
- ✘ **34 display-plug** (the second display: plug): preview (w353) moved 2 times [jolt]
  - +0 ms 12,375 709×232 · +369 ms 4,35 708×424 · +3228 ms 4,35 708×232 · +3278 ms 12,375 709×232
- ✘ **34 display-plug** (the second display: plug): mail (w355) moved 2 times [jolt]
  - +0 ms 1599,770 1120×630 · +574 ms 240,72 1120×630 · +3383 ms -1119,770 1120×630
- ✘ **34 display-plug** (the second display: plug): w357 of Mail is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1924,877 470×416 · +574 ms 565,179 470×416 · +3383 ms -794,877 470×416
- ~ **39 undo** (presses ctrl+opt+z): w357 of Mail went 456 points out of its way before it ended up [jolt]
  - +0 ms -1022,822 470×416 · +911 ms 793,124 470×416 · +1036 ms 565,179 470×416
- ~ **39 undo** (presses ctrl+opt+z): the last window came to rest 843 ms after the key or the button [slow]
- ✘ **51 view-frame** (presses ctrl+opt+return): finder (w326) moved 2 times [jolt]
  - +0 ms 1087,43 501×252 · +189 ms 12,43 501×252 · +453 ms 12,43 1576×767
- ✘ **58 display-left** (the second display: left): finder (w326) moved 2 times [jolt]
  - +0 ms 12,43 1576×767 · +226 ms 340,120 920×436 · +2364 ms 12,43 1576×767
- ✘ **58 display-left** (the second display: left): safari (w329) moved 2 times [jolt]
  - +0 ms -1323,770 1324×790 · +538 ms 138,31 1324×791 · +2391 ms 1599,770 1324×791
- ✘ **58 display-left** (the second display: left): textedit (w337) moved 2 times [jolt]
  - +0 ms -341,790 342×247 · +226 ms 165,65 656×422 · +2391 ms 1599,790 656×422
- ✘ **58 display-left** (the second display: left): terminal (w344) moved 2 times [jolt]
  - +0 ms -708,790 709×184 · +226 ms 40,51 863×499 · +2415 ms 1599,790 863×499
- ✘ **58 display-left** (the second display: left): notes (w347) moved 2 times [jolt]
  - +0 ms -1575,770 1576×767 · +226 ms 80,158 1000×660 · +2415 ms 1599,770 1000×660
- ✘ **58 display-left** (the second display: left): calendar (w348) moved 2 times [jolt]
  - +0 ms -936,770 937×600 · +538 ms 403,115 937×600 · +2470 ms 1599,770 937×600
- ✘ **58 display-left** (the second display: left): settings (w349) moved 2 times [jolt]
  - +0 ms -722,770 723×767 · +793 ms 437,85 723×625 · +2470 ms 1599,770 723×625
- ✘ **58 display-left** (the second display: left): preview (w353) moved 2 times [jolt]
  - +0 ms -708,770 709×232 · +538 ms 4,35 708×424 · +2470 ms 1599,770 708×424
- ✘ **58 display-left** (the second display: left): mail (w355) moved 2 times [jolt]
  - +0 ms -1119,770 1120×630 · +793 ms 240,72 1120×630 · +2470 ms 1599,770 1120×630
- ✘ **58 display-left** (the second display: left): w357 of Mail is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -794,877 470×416 · +793 ms 565,179 470×416 · +2470 ms 1924,877 470×416
- ✘ **61 drag-gap-beside-terminal** (drags the gap to the right of terminal by -40 points): textedit (w337) moved 3 times [jolt]
  - +0 ms 733,303 342×247 · +893 ms 730,303 342×247 · +932 ms 730,303 345×247 · +1101 ms 726,303 345×247 · +1140 ms 726,303 349×247 · +1877 ms 705,303 349×247 · +1908 ms 705,303 370×247 · +2149 ms 700,303 375×247 · +2435 ms 693,303 375×247 · +2481 ms 693,303 382×247
- ✘ **61 drag-gap-beside-terminal** (drags the gap to the right of terminal by -40 points): terminal (w344) moved 3 times [jolt]
  - +0 ms 12,619 709×184 · +852 ms 12,619 702×184 · +1854 ms 12,619 681×184 · +2090 ms 12,619 674×184 · +2404 ms 12,619 667×184
- ✘ **63 display-unplug** (the second display: unplug): finder (w326) moved 2 times [jolt]
  - +0 ms 1087,43 501×252 · +862 ms 340,120 920×436 · +2662 ms 1087,43 501×252
- ✘ **63 display-unplug** (the second display: unplug): safari (w329) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 1324×791 · +862 ms 138,31 1324×791 · +2828 ms 1599,770 1324×791
- ✘ **63 display-unplug** (the second display: unplug): textedit (w337) moved 2 times [jolt]
  - +0 ms 693,303 382×247 · +721 ms 165,65 656×422 · +2762 ms 693,303 382×247
- ✘ **63 display-unplug** (the second display: unplug): terminal (w344) moved 2 times [jolt]
  - +0 ms 12,619 667×184 · +721 ms 40,51 863×499 · +2790 ms 12,619 667×184
- ✘ **63 display-unplug** (the second display: unplug): notes (w347) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 709×320 · +862 ms 80,158 1000×660 · +2828 ms 1599,770 1000×660
- ✘ **63 display-unplug** (the second display: unplug): calendar (w348) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 937×600 · +721 ms 403,115 937×600 · +2828 ms 1599,770 937×600
- ✘ **63 display-unplug** (the second display: unplug): settings (w349) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 723×625 · +1094 ms 437,85 723×625 · +2828 ms 1599,770 723×625
- ✘ **63 display-unplug** (the second display: unplug): preview (w353) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 708×232 · +862 ms 4,35 708×424 · +2828 ms 1599,770 708×424
- ✘ **63 display-unplug** (the second display: unplug): mail (w355) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 1120×630 · +862 ms 240,72 1120×630 · +2828 ms 1599,770 1120×630
- ✘ **63 display-unplug** (the second display: unplug): w357 of Mail is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1924,877 470×416 · +862 ms 565,179 470×416 · +2828 ms 1924,877 470×416
- ~ **71 view-out** (chooses `out` from Arbor's menu): w357 of Mail went 456 points out of its way before it ended up [jolt]
  - +0 ms 1924,877 470×416 · +208 ms 337,614 470×416 · +301 ms 565,614 470×416
- ~ **73 quit** (chooses Quit Arbor in Arbor's menu): w357 of Mail went 456 points out of its way before it ended up [jolt]
  - +0 ms 565,614 470×416 · +2471 ms 337,614 470×416 · +2571 ms 565,179 470×416
- ✘ **77 launch** (starts Arbor): safari (w329) moved 2 times [jolt]
  - +0 ms 138,31 1324×790 · +406 ms 138,31 574×248 · +1026 ms 501,43 574×248
- ✘ **77 launch** (starts Arbor): terminal (w344) moved 2 times [jolt]
  - +0 ms 40,51 877×499 · +406 ms 40,51 548×184 · +1026 ms 40,51 478×184 · +1105 ms 12,562 478×244
- ✘ **77 launch** (starts Arbor): notes (w347) moved 2 times [jolt]
  - +0 ms 80,158 1000×660 · +776 ms 80,158 709×320 · +1105 ms 1599,770 709×320
- ✘ **77 launch** (starts Arbor): calendar (w348) moved 2 times [jolt]
  - +0 ms 403,115 937×600 · +683 ms 403,115 680×503 · +1105 ms 1599,770 680×503
- ✘ **77 launch** (starts Arbor): settings (w349) moved 2 times [jolt]
  - +0 ms 437,85 723×625 · +506 ms 437,85 723×470 · +1289 ms 437,85 723×625
- ✘ **77 launch** (starts Arbor): preview (w353) moved 2 times [jolt]
  - +0 ms 4,35 708×424 · +792 ms 4,35 708×247 · +1105 ms 1599,770 708×247
- ✘ **77 launch** (starts Arbor): mail (w355) moved 2 times [jolt]
  - +0 ms 240,72 1120×630 · +635 ms 240,72 871×248 · +1113 ms 1599,770 871×248
- ✘ **77 launch** (starts Arbor): w357 of Mail moved 2 times [jolt]
  - +0 ms 565,179 470×416 · +635 ms 441,124 470×416 · +1113 ms 1800,822 470×416
- ✘ **78 view-in** (chooses `in` from Arbor's menu): settings (w349) went 850 points out of its way before it ended up [jolt]
  - +0 ms 437,85 723×625 · +89 ms 12,340 723×470 · +161 ms 438,340 723×470
- ✘ **80 float** (presses ⌃⌥F): terminal (w344) went 14 points out of its way before it ended up [jolt]
  - +0 ms 12,562 254×244 · +500 ms 12,562 450×244 · +522 ms 12,562 443×244
- ✘ **88 display-plug** (the second display: plug): finder (w326) moved 2 times [jolt]
  - +0 ms 865,43 723×285 · +922 ms 340,120 920×436 · +2963 ms 865,43 723×285
- ✘ **88 display-plug** (the second display: plug): textedit (w337) moved 2 times [jolt]
  - +0 ms 471,43 382×378 · +637 ms 165,65 656×422 · +2963 ms 471,43 382×378
- ✘ **88 display-plug** (the second display: plug): notes (w347) moved 2 times [jolt]
  - +0 ms 1599,770 709×320 · +637 ms 80,158 1000×660 · +2978 ms -999,770 1000×660
- ✘ **88 display-plug** (the second display: plug): calendar (w348) moved 2 times [jolt]
  - +0 ms 800,32 801×791 · +412 ms 1263,300 937×600 · +637 ms 3183,480 937×600 · +3030 ms 663,222 937×600
- ✘ **88 display-plug** (the second display: plug): settings (w349) moved 2 times [jolt]
  - +0 ms 865,340 723×470 · +1104 ms 437,85 723×625 · +2978 ms 865,340 723×470
- ✘ **88 display-plug** (the second display: plug): preview (w353) moved 2 times [jolt]
  - +0 ms 1599,770 708×247 · +637 ms 4,35 708×424 · +2978 ms -707,770 708×424
- ✘ **88 display-plug** (the second display: plug): mail (w355) moved 2 times [jolt]
  - +0 ms 1599,770 871×248 · +1057 ms 240,72 1120×630 · +2996 ms -1119,770 1120×630
- ✘ **88 display-plug** (the second display: plug): w357 of Mail moved 2 times [jolt]
  - +0 ms 1800,822 470×416 · +1057 ms 565,179 470×416 · +2996 ms -794,877 470×416
- ✘ **94 display-unplug** (the second display: unplug): calendar (w348) moved 2 times [jolt]
  - +0 ms 800,32 801×790 · +347 ms 1263,300 937×600 · +2267 ms 663,222 937×600
- ✘ **96 display-plug** (the second display: plug): terminal (w344) moved 2 times [jolt]
  - +0 ms 1375,438 443×244 · +238 ms 1157,438 443×244 · +679 ms 1375,438 443×244
- ✘ **96 display-plug** (the second display: plug): calendar (w348) moved 2 times [jolt]
  - +0 ms 663,222 937×600 · +238 ms 1263,300 937×600 · +679 ms 663,300 937×600
- ✘ **116 display-unplug** (the second display: unplug): calendar (w348) moved 2 times [jolt]
  - +0 ms 663,300 937×600 · +572 ms 1263,300 937×600 · +2223 ms 663,222 937×600
- ✘ **128 display-unplug** (the second display: unplug): calendar (w348) moved 2 times [jolt]
  - +0 ms 1263,300 937×600 · +0 ms -337,187 937×600 · +535 ms 663,300 937×600
- ✘ **128 display-unplug** (the second display: unplug): settings (w349) moved 2 times [jolt]
  - +0 ms 438,43 723×470 · +591 ms 437,85 723×625 · +2303 ms 438,43 723×470
- ✘ **128 display-unplug** (the second display: unplug): preview (w353) moved 2 times [jolt]
  - +0 ms 2160,160 801×791 · +0 ms 399,60 801×791 · +535 ms -756,439 1576×377

### Rule 4: the window you switch to comes to the front and into view

- ✘ **24 undo** (presses ctrl+opt+z): the app in front changed (to process 22047), and nobody switched [focus]
- ✘ **98 dock-icon-safari** (clicks safari's icon in the Dock): safari (w329) is not wholly in view: 90% of it, at 38,109 1324×791 in 0,31 1600×791 and 1600,31 1280×769 [focus]
- ✘ **124 dock-icon-safari** (clicks safari's icon in the Dock): safari (w329) is not wholly in view: 90% of it, at 38,109 1324×791 in 0,31 1600×791 and 1600,31 1920×1049 [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **91 float-all** (chooses `float-all` from Arbor's menu): safari (w329) is 138,31 1324×790; its own size was 146,43 574×378 [size-lost]
- ✘ **91 float-all** (chooses `float-all` from Arbor's menu): terminal (w344) has its size back but not its place: 800,31 800×784, it was at 800,35 800×784 [size-lost]
- ✘ **121 float-all** (chooses `float-all` from Arbor's menu): safari (w329) is 38,109 1324×791; its own size was 146,43 574×378 [size-lost]
- ✘ **121 float-all** (chooses `float-all` from Arbor's menu): textedit (w337) is 165,65 656×422; its own size was 165,65 673×439 [size-lost]
- ✘ **121 float-all** (chooses `float-all` from Arbor's menu): terminal (w344) is 1375,438 443×244; its own size was 800,35 800×784 [size-lost]
- ✘ **121 float-all** (chooses `float-all` from Arbor's menu): calendar (w348) is 1263,300 937×600; its own size was 800,32 801×791 [size-lost]
- ✘ **131 quit** (chooses Quit Arbor in Arbor's menu): textedit (w337) is 165,65 656×422; its own size was 165,65 673×439 [size-lost]
- ✘ **131 quit** (chooses Quit Arbor in Arbor's menu): terminal (w344) is 1157,438 443×244; its own size was 800,35 800×784 [size-lost]
- ✘ **131 quit** (chooses Quit Arbor in Arbor's menu): preview (w353) is -756,439 1576×377; its own size was 2160,160 801×791 [size-lost]

### Rule L: no window is lost or stuck

- ✘ **29 view-home** (chooses `home` from Arbor's menu): safari (w329) is out of view: 0% of it is on a display, at 1599,770 1324×791 [lost]
- ✘ **29 view-home** (chooses `home` from Arbor's menu): settings (w349) is out of view: 0% of it is on a display, at 1599,770 723×625 [lost]
- ✘ **33 view-home** (chooses `home` from Arbor's menu): safari (w329) is out of view: 0% of it is on a display, at 1599,770 1324×791 [lost]
- ✘ **33 view-home** (chooses `home` from Arbor's menu): settings (w349) is out of view: 0% of it is on a display, at 1599,770 723×625 [lost]
- ✘ **64 view-home** (chooses `home` from Arbor's menu): safari (w329) is out of view: 0% of it is on a display, at 1599,770 1324×791 [lost]
- ✘ **64 view-home** (chooses `home` from Arbor's menu): settings (w349) is out of view: 0% of it is on a display, at 1599,770 723×625 [lost]
- ✘ **64 view-home** (chooses `home` from Arbor's menu): mail (w355) is out of view: 0% of it is on a display, at 1599,770 1120×630 [lost]
- ✘ **77 launch** (starts Arbor): notes (w347) is out of view: 0% of it is on a display, at 1599,770 709×320 [lost]
- ✘ **77 launch** (starts Arbor): calendar (w348) is out of view: 0% of it is on a display, at 1599,770 680×503 [lost]
- ✘ **77 launch** (starts Arbor): preview (w353) is out of view: 0% of it is on a display, at 1599,770 708×247 [lost]
- ✘ **77 launch** (starts Arbor): mail (w355) is out of view: 0% of it is on a display, at 1599,770 871×248 [lost]

### Rule -: what the script itself checked

- ~ **17 arrange** (chooses `arrange` from Arbor's menu): w344 fills 709×184 of its slot 12,619 709×191 [script]
- ~ **24 undo** (presses ctrl+opt+z): w344 fills 709×184 of its slot 12,619 709×191 [script]
- ~ **37 view-all** (presses ctrl+opt+space): w344 fills 709×184 of its slot 12,619 709×191 [script]
- ~ **47 redo** (chooses `redo` from Arbor's menu): w344 fills 709×184 of its slot 12,619 709×191 [script]
- ~ **59 view-home** (chooses `home` from Arbor's menu): w344 fills 709×184 of its slot 12,619 709×191 [script]
- ~ **61 drag-gap-beside-terminal** (drags the gap to the right of terminal by -40 points): w344 fills 667×184 of its slot 12,619 669×191 [script]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (2, 51 ms) | quiet 892 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 454 ms; blind for 545 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit |  | quiet 664 ms; blind for 3361 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×2 (5, 388 ms) | quiet 1211 ms; blind for 133 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (3, 96 ms) | quiet 938 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (5, 309 ms) | quiet 1304 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (2, 63 ms) | quiet 473 ms; blind for 453 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (5, 116 ms) | quiet 1050 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w357 ×1 (7, 159 ms) | quiet 607 ms; blind for 1032 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (40, 4069 ms) | quiet 1444 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (34, 2358 ms) | quiet 1027 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 356 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 779 ms; blind for 122 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | launch | starts Arbor |  | quiet 1234 ms; blind for 102 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 15 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 746 ms; blind for 483 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 16 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 384 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | arrange | chooses `arrange` from Arbor's menu | finder ×2 (2, 517 ms), safari ×2 (2, 1070 ms), textedit ×1 (2, 57 ms), terminal ×1 (3, 138 ms), notes ×2 (2, 862 ms), calendar ×2 (2, 743 ms), settings ×1 (2, 246 ms), preview ×1 (2, 145 ms), mail ×2 (2, 436 ms), w357 ×2 (2, 436 ms) | quiet 1085 ms; blind for 400 ms |  |  | ✘ | ✔ |  |  | ✔ | ~ |
| 18 | display-plug | the second display: plug | finder ×2 (2, 2418 ms), safari ×2 (2, 3417 ms), textedit ×2 (2, 3040 ms), terminal ×2 (2, 3088 ms), notes ×2 (3, 3208 ms), calendar ×2 (2, 2940 ms), settings ×2 (2, 2595 ms), preview ×2 (3, 3346 ms), mail ×2 (2, 2768 ms), w357 ×2 (2, 2768 ms) | quiet 417 ms; blind for 477 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 19 | view-home | chooses `home` from Arbor's menu |  | quiet 389 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 20 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 385 ms; blind for 114 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | view-back | presses ctrl+opt+[ |  | quiet 657 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 22 | float-all | chooses `float-all` from Arbor's menu | finder ×1 (2, 196 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 40 ms), terminal ×1 (2, 19 ms), notes ×1 (2, 51 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (2, 70 ms), mail ×1 (1, 0 ms), w357 ×1 (1, 0 ms) | quiet 1286 ms |  |  | ✔ |  | ✔ |  | ✔ | ✔ |
| 23 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 536 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 24 | undo | presses ctrl+opt+z | finder ×1 (2, 58 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 8 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (2, 77 ms), mail ×1 (1, 0 ms), w357 ×1 (1, 0 ms) | quiet 1489 ms; blind for 105 ms |  |  | ✔ | ✘ |  |  | ✔ | ~ |
| 25 | hold | holds the view, as for a shared screen |  | quiet 362 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 26 | show-everything-while-held | presses ⌃⌥Space, which would show everything: the view is held |  | quiet 614 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 27 | release | lets the view go again |  | quiet 371 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 28 | display-unplug | the second display: unplug | finder ×2 (2, 1676 ms), safari ×2 (2, 2194 ms), textedit ×2 (2, 2237 ms), terminal ×2 (3, 2252 ms), notes ×2 (2, 2341 ms), calendar ×2 (2, 2480 ms), settings ×2 (2, 2065 ms), preview ×2 (3, 2391 ms), mail ×2 (2, 2561 ms), w357 ×2 (2, 2561 ms) | quiet 901 ms; blind for 503 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 29 | view-home | chooses `home` from Arbor's menu |  | quiet 354 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 30 | display-plug | the second display: plug | finder ×2 (3, 2042 ms), safari ×2 (2, 2469 ms), textedit ×2 (3, 2277 ms), terminal ×2 (2, 2277 ms), notes ×2 (2, 2360 ms), calendar ×2 (2, 2469 ms), settings ×2 (2, 2010 ms), preview ×2 (3, 2469 ms), mail ×2 (2, 2391 ms), w357 ×2 (2, 2391 ms) | quiet 350 ms; blind for 386 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 31 | view-home | chooses `home` from Arbor's menu |  | quiet 404 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 32 | display-unplug | the second display: unplug | finder ×2 (3, 1790 ms), safari ×2 (2, 2220 ms), textedit ×2 (2, 2092 ms), terminal ×2 (2, 2092 ms), notes ×2 (2, 1838 ms), calendar ×2 (2, 2220 ms), settings ×2 (2, 1918 ms), preview ×2 (3, 2186 ms), mail ×2 (2, 2241 ms), w357 ×2 (2, 2241 ms) | quiet 759 ms; blind for 301 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 33 | view-home | chooses `home` from Arbor's menu |  | quiet 393 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 34 | display-plug | the second display: plug | finder ×2 (2, 2579 ms), safari ×2 (2, 3256 ms), textedit ×2 (2, 3100 ms), terminal ×2 (3, 2831 ms), notes ×2 (2, 2654 ms), calendar ×2 (2, 2960 ms), settings ×2 (2, 2603 ms), preview ×2 (3, 2909 ms), mail ×2 (2, 2809 ms), w357 ×2 (2, 2809 ms) | quiet 356 ms; blind for 316 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 35 | view-home | chooses `home` from Arbor's menu |  | quiet 357 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 36 | view-in | chooses `in` from Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (3, 169 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (2, 202 ms), w357 ×1 (2, 202 ms) | quiet 1202 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 37 | view-all | presses ctrl+opt+space | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w357 ×1 (1, 0 ms) | quiet 865 ms |  |  | ✔ |  |  |  | ✔ | ~ |
| 38 | click-terminal | clicks terminal's title bar |  | quiet 355 ms; blind for 189 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | undo | presses ctrl+opt+z | finder ×1 (2, 99 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 43 ms), terminal ×1 (2, 56 ms), notes ×1 (2, 50 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (2, 64 ms), mail ×1 (2, 125 ms), w357 ×1 (2, 125 ms) | quiet 1677 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 40 | view-back | presses ctrl+opt+[ |  | quiet 648 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 41 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 365 ms; blind for 139 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 372 ms; blind for 110 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 43 | drag-notes-by | drags notes, which floats, by its title bar 126 across and 53 down |  | quiet 1033 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 44 | click-settings | clicks settings's title bar |  | quiet 385 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | pin | chooses Keep This Window in View in Arbor's menu, or takes the tick off |  | quiet 362 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 46 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 395 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | redo | chooses `redo` from Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 29 ms), terminal ×1 (2, 24 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (2, 46 ms), mail ×1 (1, 0 ms), w357 ×1 (1, 0 ms) | quiet 1024 ms |  |  | ✔ | ✔ |  |  | ✔ | ~ |
| 48 | display-right | the second display: right |  | quiet 363 ms; blind for 115 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 49 | view-home | chooses `home` from Arbor's menu |  | quiet 352 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 50 | leave-alone | does nothing for half a minute |  | quiet 380 ms; blind for 111 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 51 | view-frame | presses ctrl+opt+return | finder ×2 (2, 264 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 1555 ms; blind for 117 ms |  |  | ✘ | ✔ |  |  | ✔ | ✔ |
| 52 | dock-icon-settings | clicks settings's icon in the Dock | finder ×1 (1, 0 ms), settings ×1 (2, 4 ms) | quiet 531 ms; blind for 131 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 53 | dock-down | chooses `dock bottom` from Arbor's menu |  | quiet 401 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 54 | dock-icon-notes | clicks notes's icon in the Dock | notes ×1 (2, 159 ms), settings ×1 (1, 0 ms) | quiet 523 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | dock-left | presses ctrl+opt+left |  | quiet 566 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 56 | dock-icon-finder | clicks finder's icon in the Dock | finder ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 454 ms; blind for 185 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | new-window-finder | presses ⌘N in finder |  | quiet 986 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 58 | display-left | the second display: left | finder ×2 (2, 2138 ms), safari ×2 (2, 1853 ms), textedit ×2 (2, 2165 ms), terminal ×2 (2, 2189 ms), notes ×2 (2, 2189 ms), calendar ×2 (2, 1932 ms), settings ×2 (2, 1677 ms), preview ×2 (2, 1932 ms), mail ×2 (2, 1677 ms), w357 ×2 (2, 1677 ms) | quiet 360 ms; blind for 312 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 59 | view-home | chooses `home` from Arbor's menu | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (2, 31 ms), notes ×1 (2, 31 ms), preview ×1 (2, 47 ms) | quiet 1039 ms |  |  | ✔ |  |  |  | ✔ | ~ |
| 60 | close-window | presses ⌘W |  | quiet 1261 ms; blind for 111 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 61 | drag-gap-beside-terminal | drags the gap to the right of terminal by -40 points | textedit ×3 (9, 1588 ms), terminal ×3 (4, 1552 ms), notes ×1 (1, 0 ms), preview ×1 (2, 134 ms) | quiet 1063 ms; blind for 298 ms |  | ✔ | ✘ | ✔ |  | ✔ | ✔ | ~ |
| 62 | view-all | presses ctrl+opt+space |  | quiet 768 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 63 | display-unplug | the second display: unplug | finder ×2 (2, 1800 ms), safari ×2 (2, 1966 ms), textedit ×2 (2, 2041 ms), terminal ×2 (2, 2069 ms), notes ×2 (2, 1966 ms), calendar ×2 (2, 2107 ms), settings ×2 (2, 1734 ms), preview ×2 (2, 1966 ms), mail ×2 (2, 1966 ms), w357 ×2 (2, 1966 ms) | quiet 592 ms; blind for 431 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 64 | view-home | chooses `home` from Arbor's menu |  | quiet 405 ms; blind for 132 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 65 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (2, 64 ms) | quiet 1173 ms; blind for 198 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 66 | dock-icon-safari | clicks safari's icon in the Dock | safari ×1 (3, 79 ms), calendar ×1 (1, 0 ms) | quiet 587 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 67 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms) | quiet 356 ms; blind for 112 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 68 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 395 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 69 | leave-alone | does nothing for half a minute |  | quiet 372 ms; blind for 110 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 70 | grow | chooses `grow` from Arbor's menu |  | quiet 379 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 71 | view-out | chooses `out` from Arbor's menu | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), mail ×1 (2, 93 ms), w357 ×1 (2, 93 ms) | quiet 1032 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 72 | save-view-2 | chooses `save-view 2` from Arbor's menu |  | quiet 375 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 73 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (2, 135 ms), safari ×1 (2, 30 ms), textedit ×1 (2, 22 ms), terminal ×1 (2, 61 ms), notes ×1 (1, 0 ms), calendar ×1 (2, 43 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (2, 100 ms), w357 ×1 (2, 100 ms) | quiet 716 ms |  |  | ~ |  | ✔ |  | ✔ | ✔ |
| 74 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 421 ms; blind for 104 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 75 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 424 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 76 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 489 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 77 | launch | starts Arbor | finder ×1 (2, 123 ms), safari ×2 (2, 620 ms), textedit ×1 (2, 48 ms), terminal ×2 (3, 699 ms), notes ×2 (2, 329 ms), calendar ×2 (2, 422 ms), settings ×2 (2, 783 ms), preview ×2 (2, 313 ms), mail ×2 (2, 478 ms), w357 ×2 (2, 478 ms) | quiet 911 ms; blind for 150 ms |  | ~ | ✘ |  |  |  | ✘ | ✔ |
| 78 | view-in | chooses `in` from Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), settings ×1 (2, 72 ms) | quiet 1201 ms; blind for 386 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 79 | dock-icon-safari | clicks safari's icon in the Dock | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (2, 93 ms), settings ×1 (1, 0 ms) | quiet 629 ms; blind for 108 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 80 | float | presses ⌃⌥F | safari ×1 (2, 118 ms), textedit ×1 (2, 18 ms), terminal ×1 (2, 22 ms) | quiet 903 ms |  | ✔ | ✘ | ✔ | ✔ |  | ✔ | ✔ |
| 81 | view-frame | presses ctrl+opt+return | safari ×1 (3, 86 ms) | quiet 690 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 82 | dock-icon-calendar | clicks calendar's icon in the Dock | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (2, 128 ms), settings ×1 (1, 0 ms) | quiet 897 ms; blind for 102 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 83 | pin | chooses Keep This Window in View in Arbor's menu, or takes the tick off | finder ×1 (1, 0 ms), calendar ×1 (2, 31 ms), settings ×1 (1, 0 ms) | quiet 1103 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 84 | drag-calendar-to-right-edge | drags calendar by its title bar against the right edge of the screen and lets go | calendar ×1 (5, 278 ms) | quiet 364 ms; blind for 113 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 85 | view-all | presses ctrl+opt+space | finder ×1 (1, 0 ms), safari ×1 (3, 323 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 1060 ms; blind for 176 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 86 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 462 ms; blind for 109 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 87 | drag-terminal-to-right-edge | drags terminal by its title bar against the right edge of the screen and lets go | terminal ×1 (9, 330 ms) | quiet 363 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 88 | display-plug | the second display: plug | finder ×2 (2, 2041 ms), safari ×1 (1, 0 ms), textedit ×2 (2, 2326 ms), terminal ×1 (1, 0 ms), notes ×2 (2, 2341 ms), calendar ×2 (3, 2618 ms), settings ×2 (2, 1874 ms), preview ×2 (2, 2341 ms), mail ×2 (2, 1939 ms), w357 ×2 (2, 1939 ms) | quiet 395 ms; blind for 791 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 89 | view-home | chooses `home` from Arbor's menu |  | quiet 367 ms; blind for 122 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 90 | drag-safari-by | drags safari, which floats, by its title bar -100 across and 91 down | finder ×1 (2, 41 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 161 ms), settings ×1 (1, 0 ms), preview ×1 (2, 16 ms) | quiet 1418 ms; blind for 116 ms | ✔ | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 91 | float-all | chooses `float-all` from Arbor's menu | finder ×1 (2, 189 ms), safari ×1 (2, 96 ms), textedit ×1 (2, 90 ms), notes ×1 (1, 0 ms), calendar ×1 (3, 93 ms), settings ×1 (2, 42 ms), preview ×1 (2, 98 ms), mail ×1 (1, 0 ms), w357 ×1 (1, 0 ms) | quiet 1226 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 92 | view-out | chooses `out` from Arbor's menu |  | quiet 355 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 93 | view-frame | presses ctrl+opt+return | safari ×1 (2, 70 ms) | quiet 750 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 94 | display-unplug | the second display: unplug | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×2 (2, 1920 ms) | quiet 585 ms; blind for 347 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 95 | view-home | chooses `home` from Arbor's menu |  | quiet 398 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 96 | display-plug | the second display: plug | terminal ×2 (2, 441 ms), calendar ×2 (2, 441 ms) | quiet 423 ms; blind for 213 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 97 | view-home | chooses `home` from Arbor's menu |  | quiet 415 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 98 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 374 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 99 | new-window-safari | presses ⌘N in safari |  | quiet 1161 ms; blind for 1897 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 100 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 396 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 101 | dock-down | chooses `dock bottom` from Arbor's menu | preview ×1 (2, 68 ms) | quiet 938 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 102 | click-new-window | clicks the title bar of the window that ⌘N opened |  | quiet 369 ms; blind for 129 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 103 | close-window | presses ⌘W |  | quiet 1088 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 104 | view-all | presses ctrl+opt+space |  | quiet 684 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 105 | peek | holds ⌃⌥Space for a second and a half and lets go |  | quiet 425 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 106 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 399 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 107 | minimize-notes | presses ⌘M | notes ×1 (22, 470 ms) | quiet 1001 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 108 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 417 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 109 | click-textedit | clicks textedit's title bar |  | quiet 540 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 110 | restore-notes | clicks notes's icon in the Dock, which brings its minimized window back | notes ×1 (22, 522 ms) | quiet 949 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 111 | hold | holds the view, as for a shared screen |  | quiet 364 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 112 | show-everything-while-held | presses ⌃⌥Space, which would show everything: the view is held |  | quiet 808 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 113 | release | lets the view go again |  | quiet 422 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 114 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 429 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 115 | drag-preview-to-left-edge | drags preview by its title bar against the left edge of the screen and lets go | preview ×1 (15, 327 ms) | quiet 350 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 116 | display-unplug | the second display: unplug | terminal ×1 (1, 0 ms), calendar ×2 (2, 1651 ms), preview ×1 (1, 0 ms) | quiet 533 ms; blind for 554 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 117 | view-home | chooses `home` from Arbor's menu |  | quiet 353 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 118 | display-plug | the second display: plug | terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 413 ms; blind for 312 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 119 | view-home | chooses `home` from Arbor's menu |  | quiet 431 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 120 | send-across | sends the window in front to the other display | preview ×1 (1, 0 ms) | quiet 1028 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 121 | float-all | chooses `float-all` from Arbor's menu |  | quiet 357 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 122 | click-settings | clicks settings's title bar |  | quiet 384 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 123 | dock-up | chooses `dock top` from Arbor's menu | settings ×1 (2, 19 ms) | quiet 1002 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 124 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 382 ms; blind for 153 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 125 | quit-safari | presses ⌘Q in safari |  | quiet 958 ms; blind for 182 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 126 | view-home | chooses `home` from Arbor's menu |  | quiet 388 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 127 | reopen-safari | opens safari's document again |  | quiet 370 ms; blind for 1831 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 128 | display-unplug | the second display: unplug | terminal ×1 (1, 0 ms), calendar ×2 (2, 535 ms), settings ×2 (2, 1712 ms), preview ×2 (2, 535 ms) | quiet 721 ms; blind for 534 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 129 | view-home | chooses `home` from Arbor's menu |  | quiet 393 ms |  |  | ✔ |  |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 130 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 659 ms; blind for 162 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 131 | quit | chooses Quit Arbor in Arbor's menu | calendar ×1 (2, 59 ms), settings ×1 (1, 0 ms) | quiet 767 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 132 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 751 ms; blind for 111 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 133 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 497 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 134 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 415 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 135 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 419 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 136 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 415 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 137 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 430 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 138 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 424 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 139 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 632 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 140 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 363 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 141 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 405 ms; blind for 117 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
