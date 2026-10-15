152 steps in 608 s, 127 of them judged, 40 with a rule broken. The sampler: samples 21409 seconds 547.7 hz 39.1 cost-ms 3.82 late 90 longest-gap-ms 1004 whole-samples 23827 whole-seconds 609.5 whole-late 107.
Input: 331 presses, releases, keys and scrolls reached the apps, half of them within 569 µs, 99 in 100 within 11615 µs, the latest after 50233 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 24, 771, 4806; dragged 198, 609, 5630; forward 12, 4552, 47995; key 61, 308, 1930; up 36, 554, 50233. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): down 13, 443; dragged 20, 403; forward 12, 7453; key 13, 423; scroll 28, 231; up 25, 224.
The round of input `started` (events, half within µs): down 13, 689; dragged 20, 425; forward 12, 6884; key 13, 466; scroll 28, 425; up 25, 416.
The round of input `last` (events, half within µs): down 13, 861; dragged 20, 461; forward 12, 13717; key 13, 559; scroll 28, 342; up 25, 479.
The round of input `after` (events, half within µs): down 13, 744; dragged 20, 415; forward 12, 13326; key 13, 525; scroll 28, 347; up 25, 361.
Judged: down, forward, up, key, dragged, scroll.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 6 | 0 |  |
| 2 | nothing moves that the person did not move | 80 | 7 | 47 pin, 87 float, 100 drag-safari-by, 112 dock-down, 118 minimize-notes, 124 drag-preview-to-left-edge, 132 dock-up |
| 3 | no jolts: a window moves once, to where it ends up | 137 | 15 | 21 display-plug, 30 display-unplug, 32 display-plug, 34 display-unplug, 36 display-plug, 62 drag-mail-to-right-edge, 63 display-left, 69 display-unplug, 84 launch, 97 display-plug, 104 display-unplug, 106 display-plug … |
| 4 | the window you switch to comes to the front and into view | 76 | 5 | 26 undo, 49 redo, 109 dock-icon-safari, 133 dock-icon-safari, 147 dock-icon-terminal |
| 5 | quitting, Float All and pause give windows their own sizes back | 6 | 5 | 24 float-all, 80 quit, 101 float-all, 130 float-all, 142 quit |
| 6 | what a person presses reaches the apps, at once | 52 | 0 |  |
| L | no window is lost or stuck | 137 | 7 | 31 view-home, 35 view-home, 37 view-home, 70 view-home, 84 launch, 139 view-home, 140 view-home |
| - | what the script itself checked | 137 | 4 | 52 leave-alone, 75 leave-alone, 80 quit, 142 quit |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **47 pin** (chooses Keep This Window in View in Arbor's menu, or takes the tick off): terminal (w235) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 740,300 863×499 · +657 ms 723,300 877×499
- ~ **62 drag-mail-to-right-edge** (drags mail by its title bar against the right edge of the screen and lets go): w248 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 565,218 470×416 · +958 ms 577,229 470×416 · +1004 ms 604,229 470×416 · +1046 ms 660,229 470×416 · +1087 ms 687,229 470×416 · +1191 ms 715,229 470×416 · … 26 more … · +4812 ms 1407,453 470×416 · +4890 ms 1090,297 470×416 · +5009 ms 966,237 470×416 · +5083 ms 935,221 470×416 · +5110 ms 930,219 470×416
- ✘ **87 float** (presses ⌃⌥F): mail (w245) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 872×791 · +981 ms 728,31 872×791
- ~ **87 float** (presses ⌃⌥F): w248 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 1800,957 470×416 · +981 ms 929,218 470×416
- ✘ **100 drag-safari-by** (drags safari, which floats, by its title bar -100 across and 91 down): textedit (w230) moved, and the step did not name it [moved-unasked]
  - +0 ms 732,43 253×352 · +4558 ms -252,790 253×352
- ✘ **100 drag-safari-by** (drags safari, which floats, by its title bar -100 across and 91 down): notes (w236) moved, and the step did not name it [moved-unasked]
  - +0 ms -999,770 1000×660 · +4558 ms 303,407 709×403
- ✘ **100 drag-safari-by** (drags safari, which floats, by its title bar -100 across and 91 down): preview (w242) moved, and the step did not name it [moved-unasked]
  - +0 ms 12,43 708×378 · +4558 ms -707,770 708×378
- ✘ **100 drag-safari-by** (drags safari, which floats, by its title bar -100 across and 91 down): desk-a (w266) moved, and the step did not name it [moved-unasked]
  - +0 ms 12,433 708×377 · +4558 ms 12,433 279×377
- ✘ **100 drag-safari-by** (drags safari, which floats, by its title bar -100 across and 91 down): desk-b (w268) moved, and the step did not name it [moved-unasked]
  - +0 ms 997,433 247×377 · +4558 ms 1024,433 279×377
- ✘ **112 dock-down** (presses ⌃⌥⌘ and the down arrow): finder (w218) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,120 920×436 · +1283 ms 340,31 920×390
- ✘ **112 dock-down** (presses ⌃⌥⌘ and the down arrow): safari (w221) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 38,109 1324×791 · +1283 ms 38,31 1324×390
- ✘ **112 dock-down** (presses ⌃⌥⌘ and the down arrow): textedit (w230) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +1283 ms 165,31 673×390
- ✘ **112 dock-down** (presses ⌃⌥⌘ and the down arrow): terminal (w235) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 800,35 800×784 · +1283 ms 800,31 800×379
- ✘ **112 dock-down** (presses ⌃⌥⌘ and the down arrow): notes (w236) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 426,158 1000×660 · +1283 ms 426,31 1000×390
- ✘ **112 dock-down** (presses ⌃⌥⌘ and the down arrow): settings (w240) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,85 723×625 · +1283 ms 437,31 723×470
- ✘ **112 dock-down** (presses ⌃⌥⌘ and the down arrow): mail (w245) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 728,31 872×790 · +1283 ms 728,31 872×390
- ~ **112 dock-down** (presses ⌃⌥⌘ and the down arrow): w248 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 929,218 470×416 · +1283 ms 929,83 470×416
- ✘ **112 dock-down** (presses ⌃⌥⌘ and the down arrow): safari-new-110 (w858) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 67,31 1324×791 · +1283 ms 67,31 1324×390
- ✘ **118 minimize-notes** (presses ⌘M): terminal (w235) a floating window, moved and came back, and the step did not name it [moved-unasked]
  - +0 ms 800,31 800×379 · +1289 ms 800,31 800×394 · +1301 ms 800,31 800×379
- ✘ **124 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): finder (w218) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,31 920×390 · +5091 ms 340,120 920×436
- ✘ **124 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): safari (w221) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 38,31 1324×390 · +5091 ms 38,109 1324×790
- ✘ **124 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): textedit (w230) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,31 673×390 · +5091 ms 165,65 673×439
- ✘ **124 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): terminal (w235) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 800,31 800×379 · +5091 ms 800,35 800×784
- ✘ **124 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): notes (w236) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 426,31 1000×390 · +5091 ms 426,158 1000×660
- ✘ **124 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): settings (w240) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 437,31 723×470 · +5091 ms 437,85 723×625
- ✘ **124 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): mail (w245) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 728,31 872×390 · +5091 ms 728,31 872×790
- ~ **124 drag-preview-to-left-edge** (drags preview by its title bar against the left edge of the screen and lets go): w248 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 929,83 470×416 · +5091 ms 929,218 470×416
- ✘ **132 dock-up** (presses ⌃⌥⌘ and the up arrow): finder (w218) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 340,120 920×436 · +1117 ms 340,525 920×297
- ✘ **132 dock-up** (presses ⌃⌥⌘ and the up arrow): safari (w221) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 38,109 1324×791 · +1117 ms 38,525 1324×375
- ✘ **132 dock-up** (presses ⌃⌥⌘ and the up arrow): textedit (w230) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 165,65 673×439 · +1117 ms 165,525 673×297
- ✘ **132 dock-up** (presses ⌃⌥⌘ and the up arrow): terminal (w235) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 800,35 800×784 · +1117 ms 800,525 800×289
- ✘ **132 dock-up** (presses ⌃⌥⌘ and the up arrow): notes (w236) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 426,158 1000×660 · +1117 ms 426,502 1000×320
- ✘ **132 dock-up** (presses ⌃⌥⌘ and the up arrow): mail (w245) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 855,278 1576×767 · +746 ms 855,278 1576×520 · +793 ms 855,525 1576×520
- ~ **132 dock-up** (presses ⌃⌥⌘ and the up arrow): w248 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 1408,453 470×416 · +746 ms 1408,330 470×416 · +793 ms 1408,577 470×416
- ✘ **132 dock-up** (presses ⌃⌥⌘ and the up arrow): desk-a (w266) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 40,70 300×190 · +1117 ms 40,525 300×190
- ✘ **132 dock-up** (presses ⌃⌥⌘ and the up arrow): desk-b (w268) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 360,70 300×190 · +1117 ms 360,525 300×190

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **20 arrange** (presses ⌃⌥A): the last window came to rest 1616 ms after the key or the button, in Arbor's first act since it started [slow]
- ✘ **21 display-plug** (the second display: plug): finder (w218) moved 2 times [jolt]
  - +0 ms 1599,770 501×252 · +816 ms 340,120 920×436 · +3033 ms -919,770 920×436
- ✘ **21 display-plug** (the second display: plug): safari (w221) moved 2 times [jolt]
  - +0 ms 1599,770 574×248 · +451 ms 138,31 1324×791 · +3067 ms -1323,770 1324×791
- ✘ **21 display-plug** (the second display: plug): textedit (w230) moved 2 times [jolt]
  - +0 ms 270,43 709×212 · +451 ms 165,65 656×422 · +2841 ms 270,43 709×212
- ✘ **21 display-plug** (the second display: plug): terminal (w235) moved 2 times [jolt]
  - +0 ms 1250,433 247×379 · +451 ms 1000,300 863×499 · +2841 ms 1250,433 247×379
- ✘ **21 display-plug** (the second display: plug): notes (w236) moved 2 times [jolt]
  - +0 ms 270,490 709×320 · +451 ms 300,105 1000×660 · +2901 ms 300,105 709×320 · +2948 ms 270,490 709×320
- ✘ **21 display-plug** (the second display: plug): calendar (w237) moved 2 times [jolt]
  - +0 ms 1599,770 680×503 · +734 ms 403,115 937×600 · +3067 ms -936,770 937×600
- ✘ **21 display-plug** (the second display: plug): settings (w240) moved 2 times [jolt]
  - +0 ms 1599,770 723×470 · +988 ms 437,85 723×625 · +3091 ms -722,770 723×625
- ✘ **21 display-plug** (the second display: plug): preview (w242) moved 2 times [jolt]
  - +0 ms 1599,770 708×248 · +451 ms 4,35 708×424 · +3091 ms -707,770 708×424
- ✘ **21 display-plug** (the second display: plug): mail (w245) moved 2 times [jolt]
  - +0 ms 1599,770 871×247 · +961 ms 240,72 1120×630 · +3091 ms -1119,770 1120×630
- ✘ **21 display-plug** (the second display: plug): w248 of Mail moved 2 times [jolt]
  - +0 ms 1800,822 470×416 · +961 ms 565,179 470×416 · +3091 ms -794,877 470×416
- ✘ **21 display-plug** (the second display: plug): desk-a (w266) moved 2 times [jolt]
  - +0 ms 12,303 246×247 · +1102 ms 40,70 300×190 · +2948 ms 12,303 246×247
- ✘ **21 display-plug** (the second display: plug): desk-b (w268) moved 2 times [jolt]
  - +0 ms 991,303 247×247 · +1102 ms 360,70 300×190 · +3033 ms 991,303 247×247
- ~ **24 float-all** (presses ⌃⌥⇧F): the last window came to rest 801 ms after the key or the button [slow]
- ~ **26 undo** (presses ⌃⌥Z): the last window came to rest 931 ms after the key or the button [slow]
- ✘ **30 display-unplug** (the second display: unplug): finder (w218) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -919,770 920×436 · +181 ms 340,120 920×436 · +2325 ms 1599,770 920×436
- ✘ **30 display-unplug** (the second display: unplug): safari (w221) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -1323,770 1324×791 · +181 ms 138,31 1324×791 · +2325 ms 1599,770 1324×791
- ✘ **30 display-unplug** (the second display: unplug): textedit (w230) moved 2 times [jolt]
  - +0 ms 270,43 709×212 · +181 ms 165,65 656×422 · +2158 ms 165,65 709×212 · +2190 ms 270,43 709×212
- ✘ **30 display-unplug** (the second display: unplug): terminal (w235) moved 2 times [jolt]
  - +0 ms 1250,433 247×379 · +181 ms 1000,300 863×499 · +2190 ms 1250,433 247×379
- ✘ **30 display-unplug** (the second display: unplug): notes (w236) moved 2 times [jolt]
  - +0 ms 270,490 709×320 · +181 ms 300,105 1000×660 · +2244 ms 270,490 709×320
- ✘ **30 display-unplug** (the second display: unplug): calendar (w237) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -936,770 937×600 · +181 ms 403,115 937×600 · +2325 ms 1599,770 937×600
- ✘ **30 display-unplug** (the second display: unplug): settings (w240) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -722,770 723×625 · +181 ms 437,85 723×625 · +2325 ms 1599,770 723×625
- ✘ **30 display-unplug** (the second display: unplug): preview (w242) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -707,770 708×424 · +181 ms 4,35 708×424 · +2325 ms 1599,770 708×424
- ✘ **30 display-unplug** (the second display: unplug): mail (w245) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -1119,770 1120×630 · +181 ms 240,72 1120×630 · +2325 ms 1599,770 1120×630
- ✘ **30 display-unplug** (the second display: unplug): w248 of Mail is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -794,877 470×416 · +181 ms 565,179 470×416 · +2325 ms 1924,877 470×416
- ✘ **30 display-unplug** (the second display: unplug): desk-a (w266) moved 2 times [jolt]
  - +0 ms 12,303 246×247 · +527 ms 40,70 300×190 · +2260 ms 12,303 246×247
- ✘ **30 display-unplug** (the second display: unplug): desk-b (w268) moved 2 times [jolt]
  - +0 ms 991,303 247×247 · +527 ms 360,70 300×190 · +2325 ms 991,303 247×247
- ✘ **32 display-plug** (the second display: plug): finder (w218) moved 2 times [jolt]
  - +0 ms 1599,770 920×436 · +32 ms 340,120 920×436 · +2399 ms -919,770 920×436
- ✘ **32 display-plug** (the second display: plug): safari (w221) moved 2 times [jolt]
  - +0 ms 1599,770 1324×791 · +32 ms 138,31 1324×791 · +2399 ms -1323,770 1324×791
- ✘ **32 display-plug** (the second display: plug): textedit (w230) moved 2 times [jolt]
  - +0 ms 270,43 709×212 · +32 ms 165,65 656×422 · +2204 ms 270,43 709×212
- ✘ **32 display-plug** (the second display: plug): terminal (w235) moved 2 times [jolt]
  - +0 ms 1250,433 247×379 · +32 ms 1000,300 863×499 · +2211 ms 1000,300 247×379 · +2237 ms 1250,433 247×379
- ✘ **32 display-plug** (the second display: plug): notes (w236) moved 2 times [jolt]
  - +0 ms 270,490 709×320 · +32 ms 300,105 1000×660 · +2308 ms 270,490 709×320
- ✘ **32 display-plug** (the second display: plug): calendar (w237) moved 2 times [jolt]
  - +0 ms 1599,770 937×600 · +32 ms 403,115 937×600 · +2399 ms -936,770 937×600
- ✘ **32 display-plug** (the second display: plug): settings (w240) moved 2 times [jolt]
  - +0 ms 1599,770 723×625 · +282 ms 437,85 723×625 · +2399 ms -722,770 723×625
- ✘ **32 display-plug** (the second display: plug): preview (w242) moved 2 times [jolt]
  - +0 ms 1599,770 708×424 · +32 ms 4,35 708×424 · +2399 ms -707,770 708×424
- ✘ **32 display-plug** (the second display: plug): mail (w245) moved 2 times [jolt]
  - +0 ms 1599,770 1120×630 · +32 ms 240,72 1120×630 · +2434 ms -1119,770 1120×630
- ✘ **32 display-plug** (the second display: plug): w248 of Mail moved 2 times [jolt]
  - +0 ms 1924,877 470×416 · +32 ms 565,179 470×416 · +2434 ms -794,877 470×416
- ✘ **32 display-plug** (the second display: plug): desk-a (w266) moved 2 times [jolt]
  - +0 ms 12,303 246×247 · +282 ms 40,70 300×190 · +2308 ms 40,70 246×247 · +2335 ms 12,303 246×247
- ✘ **32 display-plug** (the second display: plug): desk-b (w268) moved 2 times [jolt]
  - +0 ms 991,303 247×247 · +282 ms 360,70 300×190 · +2399 ms 991,303 247×247
- ✘ **34 display-unplug** (the second display: unplug): finder (w218) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -919,770 920×436 · +12 ms 340,120 920×436 · +2238 ms 1599,770 920×436
- ✘ **34 display-unplug** (the second display: unplug): safari (w221) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -1323,770 1324×791 · +12 ms 138,31 1324×791 · +2238 ms 1599,770 1324×791
- ✘ **34 display-unplug** (the second display: unplug): textedit (w230) moved 2 times [jolt]
  - +0 ms 270,43 709×212 · +12 ms 165,65 656×422 · +2124 ms 270,43 709×212
- ✘ **34 display-unplug** (the second display: unplug): terminal (w235) moved 2 times [jolt]
  - +0 ms 1250,433 247×379 · +12 ms 1000,300 863×499 · +2124 ms 1250,433 247×379
- ✘ **34 display-unplug** (the second display: unplug): notes (w236) moved 2 times [jolt]
  - +0 ms 270,490 709×320 · +12 ms 300,105 1000×660 · +2150 ms 270,490 709×320
- ✘ **34 display-unplug** (the second display: unplug): calendar (w237) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -936,770 937×600 · +12 ms 403,115 937×600 · +2238 ms 1599,770 937×600
- ✘ **34 display-unplug** (the second display: unplug): settings (w240) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -722,770 723×625 · +251 ms 437,85 723×625 · +2238 ms 1599,770 723×625
- ✘ **34 display-unplug** (the second display: unplug): preview (w242) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -707,770 708×424 · +12 ms 4,35 708×424 · +2238 ms 1599,770 708×424
- ✘ **34 display-unplug** (the second display: unplug): mail (w245) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -1119,770 1120×630 · +12 ms 240,72 1120×630 · +2238 ms 1599,770 1120×630
- ✘ **34 display-unplug** (the second display: unplug): w248 of Mail is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms -794,877 470×416 · +12 ms 565,179 470×416 · +2238 ms 1924,877 470×416
- ✘ **34 display-unplug** (the second display: unplug): desk-a (w266) moved 2 times [jolt]
  - +0 ms 12,303 246×247 · +302 ms 40,70 300×190 · +2184 ms 12,303 246×247
- ✘ **34 display-unplug** (the second display: unplug): desk-b (w268) moved 2 times [jolt]
  - +0 ms 991,303 247×247 · +302 ms 360,70 300×190 · +2238 ms 991,303 247×247
- ✘ **36 display-plug** (the second display: plug): finder (w218) moved 2 times [jolt]
  - +0 ms 1599,770 920×436 · +285 ms 340,120 920×436 · +3085 ms -919,770 920×436
- ✘ **36 display-plug** (the second display: plug): safari (w221) moved 2 times [jolt]
  - +0 ms 1599,770 1324×791 · +285 ms 138,31 1324×791 · +3109 ms -1323,770 1324×791
- ✘ **36 display-plug** (the second display: plug): textedit (w230) moved 2 times [jolt]
  - +0 ms 270,43 709×212 · +285 ms 165,65 656×422 · +2947 ms 270,43 709×212
- ✘ **36 display-plug** (the second display: plug): terminal (w235) moved 3 times [jolt]
  - +0 ms 1250,433 247×379 · +285 ms 1000,300 863×499 · +976 ms 737,300 863×499 · +2947 ms 1250,433 247×379
- ✘ **36 display-plug** (the second display: plug): notes (w236) moved 2 times [jolt]
  - +0 ms 270,490 709×320 · +285 ms 300,105 1000×660 · +3008 ms 300,105 709×320 · +3018 ms 270,490 709×320
- ✘ **36 display-plug** (the second display: plug): calendar (w237) moved 2 times [jolt]
  - +0 ms 1599,770 937×600 · +285 ms 403,115 937×600 · +3109 ms -936,770 937×600
- ✘ **36 display-plug** (the second display: plug): settings (w240) moved 2 times [jolt]
  - +0 ms 1599,770 723×625 · +285 ms 437,85 723×625 · +3109 ms -722,770 723×625
- ✘ **36 display-plug** (the second display: plug): preview (w242) moved 2 times [jolt]
  - +0 ms 1599,770 708×424 · +285 ms 4,35 708×424 · +3109 ms -707,770 708×424
- ✘ **36 display-plug** (the second display: plug): mail (w245) moved 2 times [jolt]
  - +0 ms 1599,770 1120×630 · +285 ms 240,72 1120×630 · +3137 ms -1119,770 1120×630
- ✘ **36 display-plug** (the second display: plug): w248 of Mail is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1924,877 470×416 · +285 ms 565,179 470×416 · +3137 ms -794,877 470×416
- ✘ **36 display-plug** (the second display: plug): desk-a (w266) moved 2 times [jolt]
  - +0 ms 12,303 246×247 · +383 ms 40,70 300×190 · +3050 ms 12,303 246×247
- ✘ **36 display-plug** (the second display: plug): desk-b (w268) moved 2 times [jolt]
  - +0 ms 991,303 247×247 · +383 ms 360,70 300×190 · +3085 ms 991,303 247×247
- ~ **42 undo** (presses ⌃⌥Z): the last window came to rest 704 ms after the key or the button [slow]
- ✘ **62 drag-mail-to-right-edge** (drags mail by its title bar against the right edge of the screen and lets go): w248 of Mail moved 2 times [jolt]
  - +0 ms 565,218 470×416 · +958 ms 577,229 470×416 · +1004 ms 604,229 470×416 · +1046 ms 660,229 470×416 · +1087 ms 687,229 470×416 · +1191 ms 715,229 470×416 · … 26 more … · +4812 ms 1407,453 470×416 · +4890 ms 1090,297 470×416 · +5009 ms 966,237 470×416 · +5083 ms 935,221 470×416 · +5110 ms 930,219 470×416
- ✘ **63 display-left** (the second display: left): finder (w218) moved 2 times [jolt]
  - +0 ms -1575,770 1576×767 · +200 ms 340,120 920×436 · +2204 ms 1599,770 920×436
- ✘ **63 display-left** (the second display: left): safari (w221) moved 2 times [jolt]
  - +0 ms -1323,770 1324×791 · +200 ms 138,31 1324×791 · +2204 ms 1599,770 1324×791
- ✘ **63 display-left** (the second display: left): textedit (w230) moved 2 times [jolt]
  - +0 ms 12,43 1576×352 · +200 ms 165,65 656×422 · +2176 ms 12,43 1576×352
- ✘ **63 display-left** (the second display: left): terminal (w235) is out of view before and after, and 70% of it showed in between [flash]
  - +0 ms -1576,790 1577×769 · +200 ms 1000,300 863×499 · +2204 ms 1599,790 863×499
- ✘ **63 display-left** (the second display: left): notes (w236) moved 2 times [jolt]
  - +0 ms 12,407 1576×403 · +200 ms 426,158 1000×660 · +2176 ms 426,158 1174×403 · +2204 ms 12,407 1576×403
- ✘ **63 display-left** (the second display: left): calendar (w237) moved 2 times [jolt]
  - +0 ms -936,770 937×600 · +200 ms 403,115 937×600 · +2265 ms 1599,770 937×600
- ✘ **63 display-left** (the second display: left): settings (w240) moved 2 times [jolt]
  - +0 ms -722,770 723×767 · +518 ms 437,85 723×625 · +2265 ms 1599,770 723×625
- ✘ **63 display-left** (the second display: left): preview (w242) moved 2 times [jolt]
  - +0 ms -707,770 708×424 · +200 ms 4,35 708×424 · +2265 ms 1599,770 708×424
- ✘ **63 display-left** (the second display: left): desk-a (w266) moved 2 times [jolt]
  - +0 ms -245,790 246×247 · +582 ms 40,70 300×190 · +2265 ms 1599,790 300×190
- ✘ **63 display-left** (the second display: left): desk-b (w268) moved 2 times [jolt]
  - +0 ms -246,790 247×247 · +582 ms 360,70 300×190 · +2265 ms 1599,790 300×190
- ✘ **63 display-left** (the second display: left): finder-new-60 (w607) moved 2 times [jolt]
  - +0 ms -919,770 920×436 · +200 ms 41,72 920×436 · +2265 ms 1599,770 920×436
- ~ **68 view-all** (presses ⌃⌥Space): the last window came to rest 715 ms after the key or the button [slow]
- ✘ **69 display-unplug** (the second display: unplug): finder (w218) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 920×436 · +381 ms 340,120 920×436 · +2724 ms 1599,770 920×436
- ✘ **69 display-unplug** (the second display: unplug): safari (w221) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 1324×791 · +381 ms 138,31 1324×791 · +2724 ms 1599,770 1324×791
- ✘ **69 display-unplug** (the second display: unplug): textedit (w230) moved 2 times [jolt]
  - +0 ms 270,43 709×352 · +381 ms 165,65 656×422 · +2625 ms 270,43 709×352
- ✘ **69 display-unplug** (the second display: unplug): terminal (w235) moved 2 times [jolt]
  - +0 ms 1250,433 247×379 · +381 ms 1000,300 863×499 · +2702 ms 1250,433 247×379
- ✘ **69 display-unplug** (the second display: unplug): notes (w236) moved 2 times [jolt]
  - +0 ms 270,407 709×403 · +381 ms 426,158 1000×660 · +2702 ms 270,407 709×403
- ✘ **69 display-unplug** (the second display: unplug): calendar (w237) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 937×600 · +381 ms 403,115 937×600 · +2801 ms 1599,770 937×600
- ✘ **69 display-unplug** (the second display: unplug): settings (w240) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 723×625 · +809 ms 437,85 723×625 · +2801 ms 1599,770 723×625
- ✘ **69 display-unplug** (the second display: unplug): preview (w242) is out of view before and after, and 100% of it showed in between [flash]
  - +0 ms 1599,770 1576×767 · +381 ms 4,35 708×424 · +2801 ms 1599,770 708×424
- ✘ **69 display-unplug** (the second display: unplug): desk-a (w266) moved 2 times [jolt]
  - +0 ms 12,303 246×247 · +912 ms 40,70 300×190 · +2702 ms 12,303 246×247
- ✘ **69 display-unplug** (the second display: unplug): desk-b (w268) moved 2 times [jolt]
  - +0 ms 991,303 247×247 · +912 ms 360,70 300×190 · +2724 ms 991,303 247×247
- ~ **80 quit** (chooses Quit Arbor in Arbor's menu): w248 of Mail went 24 points out of its way before it ended up [jolt]
  - +0 ms 2152,945 470×416 · +2663 ms 1800,957 470×416 · +2670 ms 929,218 470×416
- ✘ **84 launch** (starts Arbor): finder (w218) moved 2 times [jolt]
  - +0 ms 340,120 920×436 · +396 ms 991,43 501×252 · +1069 ms 1599,770 501×252
- ✘ **84 launch** (starts Arbor): safari (w221) moved 2 times [jolt]
  - +0 ms 138,31 1324×791 · +467 ms 12,562 574×248 · +1069 ms 1599,770 574×248
- ✘ **84 launch** (starts Arbor): textedit (w230) moved 2 times [jolt]
  - +0 ms 165,65 673×439 · +467 ms 165,65 709×352 · +478 ms 270,43 709×352 · +879 ms 264,43 245×352 · +1104 ms 264,43 709×352 · +1122 ms 270,43 709×352
- ✘ **84 launch** (starts Arbor): terminal (w235) moved 2 times [jolt]
  - +0 ms 740,300 877×499 · +478 ms 740,300 247×379 · +542 ms 1250,433 247×379 · +931 ms 773,525 352×289 · +983 ms 773,525 723×274 · +1001 ms 773,531 723×274 · +1144 ms 773,531 247×289 · +1169 ms 1250,433 247×379
- ✘ **84 launch** (starts Arbor): notes (w236) moved 2 times [jolt]
  - +0 ms 426,158 1000×660 · +603 ms 270,407 709×403 · +1001 ms 264,407 709×403 · +1185 ms 270,407 709×403
- ✘ **84 launch** (starts Arbor): calendar (w237) moved 2 times [jolt]
  - +0 ms 403,115 937×600 · +612 ms 403,115 680×503 · +730 ms 991,562 680×503 · +1080 ms 1599,770 680×503
- ✘ **84 launch** (starts Arbor): settings (w240) moved 2 times [jolt]
  - +0 ms 437,85 723×625 · +730 ms 1250,43 723×470 · +1001 ms 773,43 723×470 · +1210 ms 1599,770 723×470
- ✘ **84 launch** (starts Arbor): preview (w242) moved 2 times [jolt]
  - +0 ms 4,35 708×424 · +785 ms 12,43 708×248 · +1080 ms 1599,770 708×248
- ✘ **84 launch** (starts Arbor): desk-a (w266) went 12 points out of its way before it ended up [jolt]
  - +0 ms 40,70 300×190 · +828 ms 12,303 246×247 · +1050 ms 12,303 240×247 · +1199 ms 12,303 246×247
- ✘ **84 launch** (starts Arbor): desk-b (w268) went 940 points out of its way before it ended up [jolt]
  - +0 ms 360,70 300×190 · +879 ms 991,303 247×247 · +1050 ms 991,303 240×247 · +1069 ms 521,303 240×247 · +1210 ms 991,303 247×247
- ✘ **97 display-plug** (the second display: plug): finder (w218) moved 2 times [jolt]
  - +0 ms 1599,770 1576×378 · +960 ms 340,120 920×436 · +3240 ms -919,770 920×436
- ✘ **97 display-plug** (the second display: plug): safari (w221) moved 2 times [jolt]
  - +0 ms 1599,770 1324×791 · +78 ms 138,31 1324×791 · +3265 ms -1323,770 1324×791
- ✘ **97 display-plug** (the second display: plug): textedit (w230) moved 2 times [jolt]
  - +0 ms 1599,790 709×352 · +78 ms 165,65 656×422 · +3240 ms -655,790 656×422
- ✘ **97 display-plug** (the second display: plug): terminal (w235) moved 2 times [jolt]
  - +0 ms 1599,790 800×784 · +78 ms 1450,438 247×379 · +3314 ms -246,790 247×379
- ✘ **97 display-plug** (the second display: plug): notes (w236) moved 2 times [jolt]
  - +0 ms 1599,770 709×403 · +960 ms 426,158 1000×660 · +3240 ms -999,770 1000×660
- ✘ **97 display-plug** (the second display: plug): calendar (w237) moved 2 times [jolt]
  - +0 ms 800,32 801×791 · +78 ms 1273,300 937×600 · +3441 ms 1273,300 937×780 · +3518 ms 663,31 937×780 · +3532 ms 663,31 937×790
- ✘ **97 display-plug** (the second display: plug): settings (w240) moved 2 times [jolt]
  - +0 ms 1599,770 723×470 · +1179 ms 437,85 723×625 · +3240 ms -722,770 723×625
- ✘ **97 display-plug** (the second display: plug): preview (w242) moved 2 times [jolt]
  - +0 ms 12,43 1576×767 · +78 ms 4,35 708×424 · +3240 ms 12,43 1576×767
- ✘ **97 display-plug** (the second display: plug): mail (w245) moved 2 times [jolt]
  - +0 ms 1599,770 872×791 · +960 ms 855,278 1576×767 · +3554 ms -1575,770 1576×767
- ✘ **97 display-plug** (the second display: plug): w248 of Mail moved 2 times [jolt]
  - +0 ms 1800,957 470×416 · +960 ms 1408,453 470×416 · +3554 ms -1022,945 470×416
- ✘ **97 display-plug** (the second display: plug): desk-a (w266) moved 2 times [jolt]
  - +0 ms 1599,790 246×377 · +1403 ms 40,70 300×190 · +3265 ms -299,790 300×190
- ✘ **97 display-plug** (the second display: plug): desk-b (w268) moved 2 times [jolt]
  - +0 ms 1599,790 247×377 · +1403 ms 360,70 300×190 · +3265 ms -299,790 300×190
- ~ **98 view-home** (presses ⌃⌥0): w248 of Mail went 704 points out of its way before it ended up [jolt]
  - +0 ms -1022,945 470×416 · +773 ms 1281,218 470×416 · +871 ms 929,218 470×416
- ~ **98 view-home** (presses ⌃⌥0): the last window came to rest 893 ms after the key or the button [slow]
- ~ **101 float-all** (presses ⌃⌥⇧F): the last window came to rest 732 ms after the key or the button [slow]
- ✘ **104 display-unplug** (the second display: unplug): textedit (w230) moved 2 times [jolt]
  - +0 ms 165,65 673×439 · +414 ms 165,65 656×422 · +2160 ms 165,65 673×439
- ✘ **104 display-unplug** (the second display: unplug): terminal (w235) moved 2 times [jolt]
  - +0 ms 800,35 800×784 · +414 ms 1450,438 247×379 · +2160 ms 1450,438 800×379 · +2190 ms 800,35 800×784
- ✘ **104 display-unplug** (the second display: unplug): calendar (w237) moved 2 times [jolt]
  - +0 ms 800,32 801×790 · +414 ms 1273,300 937×600 · +2190 ms 663,222 937×600
- ✘ **104 display-unplug** (the second display: unplug): mail (w245) moved 2 times [jolt]
  - +0 ms 728,31 872×791 · +414 ms 855,278 1576×767 · +2265 ms 728,31 872×791
- ✘ **104 display-unplug** (the second display: unplug): w248 of Mail moved 2 times [jolt]
  - +0 ms 929,218 470×416 · +414 ms 1408,453 470×416 · +2265 ms 929,218 470×416
- ✘ **106 display-plug** (the second display: plug): textedit (w230) moved 2 times [jolt]
  - +0 ms 165,65 673×439 · +299 ms 165,65 656×422 · +2631 ms 165,65 673×439
- ✘ **106 display-plug** (the second display: plug): terminal (w235) moved 3 times [jolt]
  - +0 ms 800,35 800×784 · +299 ms 1450,438 247×379 · +771 ms 1353,438 247×379 · +2631 ms 800,35 800×784
- ✘ **106 display-plug** (the second display: plug): calendar (w237) moved 2 times [jolt]
  - +0 ms 663,31 937×790 · +299 ms 1273,300 937×600 · +771 ms 663,300 937×600
- ✘ **106 display-plug** (the second display: plug): mail (w245) moved 3 times [jolt]
  - +0 ms 728,31 872×791 · +455 ms 855,278 1576×767 · +771 ms 24,133 1576×767 · +2786 ms 24,133 872×767 · +2850 ms 728,31 872×790
- ✘ **106 display-plug** (the second display: plug): w248 of Mail moved 3 times [jolt]
  - +0 ms 929,218 470×416 · +455 ms 1408,453 470×416 · +771 ms 577,308 470×416 · +2786 ms 225,308 470×416 · +2850 ms 929,218 470×416
- ~ **112 dock-down** (presses ⌃⌥⌘ and the down arrow): the last window came to rest 998 ms after the key or the button [slow]
- ✘ **125 display-unplug** (the second display: unplug): textedit (w230) moved 2 times [jolt]
  - +0 ms 165,65 673×439 · +6 ms 165,65 656×422 · +2108 ms 165,65 673×439
- ✘ **125 display-unplug** (the second display: unplug): terminal (w235) moved 2 times [jolt]
  - +0 ms 800,35 800×784 · +6 ms 1450,438 247×379 · +2117 ms 1450,438 800×379 · +2167 ms 800,35 800×784
- ✘ **125 display-unplug** (the second display: unplug): calendar (w237) moved 2 times [jolt]
  - +0 ms 663,300 937×600 · +6 ms 1273,300 937×600 · +2167 ms 663,222 937×600
- ✘ **125 display-unplug** (the second display: unplug): mail (w245) moved 2 times [jolt]
  - +0 ms 728,31 872×790 · +390 ms 855,278 1576×767 · +2230 ms 728,31 872×791
- ✘ **125 display-unplug** (the second display: unplug): w248 of Mail moved 2 times [jolt]
  - +0 ms 929,218 470×416 · +390 ms 1408,453 470×416 · +2230 ms 929,218 470×416
- ✘ **127 display-plug** (the second display: plug): textedit (w230) moved 2 times [jolt]
  - +0 ms 165,65 673×439 · +194 ms 165,65 656×422 · +2162 ms 165,65 673×439
- ✘ **127 display-plug** (the second display: plug): terminal (w235) moved 2 times [jolt]
  - +0 ms 800,35 800×784 · +194 ms 1450,438 247×379 · +2162 ms 1450,438 800×379 · +2185 ms 800,35 800×784
- ~ **132 dock-up** (presses ⌃⌥⌘ and the up arrow): the last window came to rest 883 ms after the key or the button [slow]
- ✘ **138 display-unplug** (the second display: unplug): settings (w240) moved 2 times [jolt]
  - +0 ms 438,43 723×470 · +736 ms 437,85 723×625 · +2510 ms 438,43 723×470
- ✘ **138 display-unplug** (the second display: unplug): preview (w242) moved 2 times [jolt]
  - +0 ms 2160,160 801×791 · +26 ms -629,439 1576×377 · +2510 ms -629,439 801×297 · +2517 ms 560,525 801×297
- ✘ **138 display-unplug** (the second display: unplug): mail (w245) moved 2 times [jolt]
  - +0 ms 855,525 1576×520 · +26 ms -745,356 1576×520 · +774 ms 855,278 1576×767
- ✘ **138 display-unplug** (the second display: unplug): w248 of Mail moved 2 times [jolt]
  - +0 ms 1408,577 470×416 · +26 ms -192,408 470×416 · +774 ms 1408,453 470×416

### Rule 4: the window you switch to comes to the front and into view

- ✘ **26 undo** (presses ⌃⌥Z): the app in front changed (to process 60611), and nobody switched [focus]
- ✘ **49 redo** (presses ⌃⌥⇧Z): the app in front changed (to process 60611), and nobody switched [focus]
- ✘ **109 dock-icon-safari** (clicks safari's icon in the Dock): safari (w221) is not wholly in view: 90% of it, at 38,109 1324×791 in 0,31 1600×791 and 1600,31 1280×769 [focus]
- ✘ **133 dock-icon-safari** (clicks safari's icon in the Dock): safari (w221) is not wholly in view: 79% of it, at 38,525 1324×375 in 0,31 1600×791 and 1600,31 1920×1049 [focus]
- ✘ **147 dock-icon-terminal** (clicks terminal's icon in the Dock): terminal (w235) is not wholly in view: 61% of it, at 1450,438 247×379 in 0,31 1600×791 [focus]

### Rule 5: quitting, Float All and pause give windows their own sizes back

- ✘ **24 float-all** (presses ⌃⌥⇧F): terminal (w235) is 740,300 863×499; its own size was 740,300 877×499 [size-lost]
- ✘ **80 quit** (chooses Quit Arbor in Arbor's menu): w248 of Mail has its size back but not its place: 929,218 470×416, it was at 565,179 470×416 [size-lost]
- ✘ **101 float-all** (presses ⌃⌥⇧F): safari (w221) is 138,31 1324×790; its own size was 438,43 574×352 [size-lost]
- ✘ **101 float-all** (presses ⌃⌥⇧F): w248 of Mail has its size back but not its place: 929,218 470×416, it was at 565,179 470×416 [size-lost]
- ✘ **130 float-all** (presses ⌃⌥⇧F): safari (w221) is 38,109 1324×791; its own size was 438,43 574×352 [size-lost]
- ✘ **130 float-all** (presses ⌃⌥⇧F): calendar (w237) is 1273,300 937×600; its own size was 800,32 801×791 [size-lost]
- ✘ **130 float-all** (presses ⌃⌥⇧F): mail (w245) is 855,278 1576×767; its own size was 729,32 872×791 [size-lost]
- ✘ **130 float-all** (presses ⌃⌥⇧F): w248 of Mail has its size back but not its place: 1408,453 470×416, it was at 565,179 470×416 [size-lost]
- ✘ **142 quit** (chooses Quit Arbor in Arbor's menu): terminal (w235) is 1450,438 247×379; its own size was 800,35 800×784 [size-lost]
- ✘ **142 quit** (chooses Quit Arbor in Arbor's menu): calendar (w237) is 663,222 937×600; its own size was 800,32 801×791 [size-lost]
- ✘ **142 quit** (chooses Quit Arbor in Arbor's menu): preview (w242) has its size back but not its place: 560,31 801×790, it was at 2160,160 801×791 [size-lost]
- ✘ **142 quit** (chooses Quit Arbor in Arbor's menu): mail (w245) is 24,55 1576×767; its own size was 729,32 872×791 [size-lost]
- ✘ **142 quit** (chooses Quit Arbor in Arbor's menu): w248 of Mail has its size back but not its place: 577,230 470×416, it was at 565,179 470×416 [size-lost]

### Rule L: no window is lost or stuck

- ✘ **31 view-home** (presses ⌃⌥0): finder (w218) is out of view: 0% of it is on a display, at 1599,770 920×436 [lost]
- ✘ **31 view-home** (presses ⌃⌥0): safari (w221) is out of view: 0% of it is on a display, at 1599,770 1324×791 [lost]
- ✘ **31 view-home** (presses ⌃⌥0): settings (w240) is out of view: 0% of it is on a display, at 1599,770 723×625 [lost]
- ✘ **35 view-home** (presses ⌃⌥0): finder (w218) is out of view: 0% of it is on a display, at 1599,770 920×436 [lost]
- ✘ **35 view-home** (presses ⌃⌥0): safari (w221) is out of view: 0% of it is on a display, at 1599,770 1324×791 [lost]
- ✘ **35 view-home** (presses ⌃⌥0): settings (w240) is out of view: 0% of it is on a display, at 1599,770 723×625 [lost]
- ✘ **37 view-home** (presses ⌃⌥0): finder (w218) is out of view: 0% of it is on a display, at -919,770 920×436 [lost]
- ✘ **37 view-home** (presses ⌃⌥0): safari (w221) is out of view: 0% of it is on a display, at -1323,770 1324×791 [lost]
- ✘ **37 view-home** (presses ⌃⌥0): settings (w240) is out of view: 0% of it is on a display, at -722,770 723×625 [lost]
- ✘ **70 view-home** (presses ⌃⌥0): safari (w221) is out of view: 0% of it is on a display, at 1599,770 1324×791 [lost]
- ✘ **70 view-home** (presses ⌃⌥0): settings (w240) is out of view: 0% of it is on a display, at 1599,770 723×625 [lost]
- ✘ **70 view-home** (presses ⌃⌥0): mail (w245) is out of view: 38% of it is on a display, at 855,278 1576×767 [lost]
- ✘ **84 launch** (starts Arbor): finder (w218) is out of view: 0% of it is on a display, at 1599,770 501×252 [lost]
- ✘ **84 launch** (starts Arbor): safari (w221) is out of view: 0% of it is on a display, at 1599,770 574×248 [lost]
- ✘ **84 launch** (starts Arbor): calendar (w237) is out of view: 0% of it is on a display, at 1599,770 680×503 [lost]
- ✘ **84 launch** (starts Arbor): settings (w240) is out of view: 0% of it is on a display, at 1599,770 723×470 [lost]
- ✘ **84 launch** (starts Arbor): preview (w242) is out of view: 0% of it is on a display, at 1599,770 708×248 [lost]
- ✘ **139 view-home** (presses ⌃⌥0): mail (w245) is out of view: 38% of it is on a display, at 855,278 1576×767 [lost]
- ✘ **140 view-home** (presses ⌃⌥0): mail (w245) is out of view: 38% of it is on a display, at 855,278 1576×767 [lost]

### Rule -: what the script itself checked

- ✘ **52 leave-alone** (does nothing for half a minute): with nothing to do Arbor used 1.3 % of a core [busy]
- ✘ **75 leave-alone** (does nothing for half a minute): with nothing to do Arbor used 1.4 % of a core [busy]
- ✘ **80 quit** (chooses Quit Arbor in Arbor's menu): Arbor's process ended, and nobody asked it to [crash]
- ✘ **142 quit** (chooses Quit Arbor in Arbor's menu): Arbor's process ended, and nobody asked it to [crash]

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (6, 86 ms) | quiet 1040 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 681 ms; blind for 377 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (4, 276 ms) | quiet 1359 ms; blind for 134 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (3, 297 ms) | quiet 1308 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (4, 106 ms) | quiet 1101 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×2 (5, 390 ms) | quiet 1376 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 959 ms; blind for 345 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview | preview ×1 (3, 115 ms) | quiet 1094 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail | w248 ×1 (5, 174 ms) | quiet 823 ms; blind for 1237 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (27, 3584 ms) | quiet 1045 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (25, 2103 ms) | quiet 1002 ms |  |  |  |  |  |  |  |  |
| 12 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×3 (30, 4135 ms) | quiet 1360 ms |  |  |  |  |  |  |  |  |
| 13 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×1 (35, 2402 ms) | quiet 1058 ms |  |  |  |  |  |  |  |  |
| 14 | look-around | looks at the screen |  | quiet 407 ms |  |  |  |  |  |  |  |  |
| 15 | open-desks | opens the two windows that input is tried on | desk-a ×1 (2, 51 ms), desk-b ×1 (1, 0 ms) | quiet 364 ms |  |  |  |  |  |  |  |  |
| 16 | input-before | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 896 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 17 | launch | starts Arbor |  | quiet 1033 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 18 | input-started | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 914 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 455 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 20 | arrange | presses ⌃⌥A | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w248 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 2098 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 21 | display-plug | the second display: plug | finder ×2 (2, 2217 ms), safari ×2 (2, 2616 ms), textedit ×2 (2, 2390 ms), terminal ×2 (2, 2390 ms), notes ×2 (3, 2497 ms), calendar ×2 (2, 2333 ms), settings ×2 (2, 2103 ms), preview ×2 (2, 2640 ms), mail ×2 (2, 2130 ms), w248 ×2 (2, 2130 ms), desk-a ×2 (2, 1846 ms), desk-b ×2 (2, 1931 ms) | quiet 398 ms; blind for 429 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 22 | view-home | presses ⌃⌥0 |  | quiet 815 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 23 | view-back | presses ⌃⌥[ |  | quiet 746 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 24 | float-all | presses ⌃⌥⇧F | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w248 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1473 ms |  |  | ~ |  | ✘ |  | ✔ | ✔ |
| 25 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 408 ms; blind for 282 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 26 | undo | presses ⌃⌥Z | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w248 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1514 ms |  |  | ~ | ✘ |  |  | ✔ | ✔ |
| 27 | hold | holds the view, as for a shared screen |  | quiet 378 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 28 | show-desktop-while-held | presses ⌃⌥D, which would show the Desktop: the view is held |  | quiet 797 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 29 | release | lets the view go again |  | quiet 371 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 30 | display-unplug | the second display: unplug | finder ×2 (2, 2144 ms), safari ×2 (2, 2144 ms), textedit ×2 (3, 2009 ms), terminal ×2 (2, 2009 ms), notes ×2 (2, 2063 ms), calendar ×2 (2, 2144 ms), settings ×2 (2, 2144 ms), preview ×2 (2, 2144 ms), mail ×2 (2, 2144 ms), w248 ×2 (2, 2144 ms), desk-a ×2 (2, 1733 ms), desk-b ×2 (2, 1798 ms) | quiet 756 ms; blind for 234 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 31 | view-home | presses ⌃⌥0 |  | quiet 701 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 32 | display-plug | the second display: plug | finder ×2 (2, 2367 ms), safari ×2 (2, 2367 ms), textedit ×2 (2, 2172 ms), terminal ×2 (3, 2205 ms), notes ×2 (2, 2276 ms), calendar ×2 (2, 2367 ms), settings ×2 (2, 2117 ms), preview ×2 (2, 2367 ms), mail ×2 (2, 2402 ms), w248 ×2 (2, 2402 ms), desk-a ×2 (3, 2053 ms), desk-b ×2 (2, 2117 ms) | quiet 408 ms; blind for 186 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 33 | view-home | presses ⌃⌥0 |  | quiet 814 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 34 | display-unplug | the second display: unplug | finder ×2 (2, 2226 ms), safari ×2 (2, 2226 ms), textedit ×2 (2, 2112 ms), terminal ×2 (2, 2112 ms), notes ×2 (2, 2138 ms), calendar ×2 (2, 2226 ms), settings ×2 (2, 1987 ms), preview ×2 (2, 2226 ms), mail ×2 (2, 2226 ms), w248 ×2 (2, 2226 ms), desk-a ×2 (2, 1882 ms), desk-b ×2 (2, 1936 ms) | quiet 897 ms; blind for 216 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 35 | view-home | presses ⌃⌥0 |  | quiet 693 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 36 | display-plug | the second display: plug | finder ×2 (2, 2800 ms), safari ×2 (2, 2824 ms), textedit ×2 (2, 2662 ms), terminal ×3 (3, 2662 ms), notes ×2 (3, 2733 ms), calendar ×2 (2, 2824 ms), settings ×2 (2, 2824 ms), preview ×2 (2, 2824 ms), mail ×2 (2, 2852 ms), w248 ×2 (2, 2852 ms), desk-a ×2 (2, 2667 ms), desk-b ×2 (2, 2702 ms) | quiet 366 ms; blind for 248 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 37 | view-home | presses ⌃⌥0 |  | quiet 713 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 38 | dock-icon-calendar | clicks calendar's icon in the Dock | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 919 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 39 | view-in | presses ⌃⌥↓ |  | quiet 833 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 40 | view-all | presses ⌃⌥Space | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 780 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 41 | click-terminal | clicks terminal's title bar |  | quiet 450 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 42 | undo | presses ⌃⌥Z | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w248 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1289 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 43 | view-back | presses ⌃⌥[ |  | quiet 715 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 44 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 385 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 45 | drag-notes-by | drags notes, which floats, by its title bar 126 across and 53 down |  | quiet 1070 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 46 | click-settings | clicks settings's title bar |  | quiet 382 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 47 | pin | chooses Keep This Window in View in Arbor's menu, or takes the tick off | terminal ×1 (1, 0 ms) | quiet 1061 ms |  | ✘ | ✔ | ✔ |  |  | ✔ | ✔ |
| 48 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 370 ms; blind for 138 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 49 | redo | presses ⌃⌥⇧Z | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w248 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1170 ms |  |  | ✔ | ✘ |  |  | ✔ | ✔ |
| 50 | display-right | the second display: right |  | quiet 367 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 51 | view-home | presses ⌃⌥0 |  | quiet 615 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 52 | leave-alone | does nothing for half a minute |  | quiet 372 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 53 | view-frame | presses ⌃⌥↩ | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1240 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 54 | dock-icon-settings | clicks settings's icon in the Dock | notes ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 629 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 55 | dock-down | presses ⌃⌥⌘ and the down arrow |  | quiet 577 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 56 | dock-icon-terminal | clicks terminal's icon in the Dock | terminal ×1 (1, 0 ms), settings ×1 (1, 0 ms) | quiet 561 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 57 | dock-icon-notes | clicks notes's icon in the Dock | terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 450 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 58 | dock-left | presses ⌃⌥⌘ and the left arrow |  | quiet 654 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 59 | dock-icon-finder | clicks finder's icon in the Dock | finder ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 504 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | new-window-finder | presses ⌘N in finder |  | quiet 1050 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 61 | dock-icon-mail | clicks mail's icon in the Dock | finder ×1 (1, 0 ms), mail ×1 (1, 0 ms), w248 ×1 (1, 0 ms), finder-new-60 ×1 (1, 0 ms) | quiet 705 ms; blind for 130 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 62 | drag-mail-to-right-edge | drags mail by its title bar against the right edge of the screen and lets go | textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms), mail ×1 (5, 298 ms), w248 ×2 (36, 4152 ms) | quiet 362 ms | ✔ | ~ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 63 | display-left | the second display: left | finder ×2 (2, 2004 ms), safari ×2 (2, 2004 ms), textedit ×2 (2, 1976 ms), terminal ×2 (2, 2004 ms), notes ×2 (3, 2004 ms), calendar ×2 (2, 2065 ms), settings ×2 (2, 1747 ms), preview ×2 (2, 2065 ms), mail ×1 (1, 0 ms), w248 ×1 (1, 0 ms), desk-a ×2 (2, 1683 ms), desk-b ×2 (2, 1683 ms), finder-new-60 ×2 (2, 2065 ms) | quiet 404 ms; blind for 317 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 64 | view-home | presses ⌃⌥0 | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), finder-new-60 ×1 (1, 0 ms) | quiet 922 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 65 | click-new-window | clicks the title bar of the window that ⌘N opened |  | quiet 411 ms; blind for 114 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 66 | close-window | presses ⌘W |  | quiet 1057 ms; blind for 119 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 67 | dock-icon-preview | clicks preview's icon in the Dock | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w248 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1089 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 68 | view-all | presses ⌃⌥Space | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w248 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1050 ms; blind for 121 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 69 | display-unplug | the second display: unplug | finder ×2 (2, 2343 ms), safari ×2 (2, 2343 ms), textedit ×2 (2, 2244 ms), terminal ×2 (2, 2321 ms), notes ×2 (2, 2321 ms), calendar ×2 (2, 2420 ms), settings ×2 (2, 1992 ms), preview ×2 (2, 2420 ms), mail ×1 (1, 0 ms), w248 ×1 (1, 0 ms), desk-a ×2 (2, 1790 ms), desk-b ×2 (2, 1812 ms) | quiet 719 ms; blind for 366 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 70 | view-home | presses ⌃⌥0 |  | quiet 721 ms |  |  | ✔ |  |  |  | ✘ | ✔ |
| 71 | cmd-tab-1 | holds ⌘ and presses Tab 1 time(s) | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w248 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 934 ms; blind for 101 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 72 | dock-icon-safari | clicks safari's icon in the Dock | safari ×1 (1, 0 ms), preview ×1 (1, 0 ms) | quiet 419 ms; blind for 114 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 73 | full-screen | presses ⌃⌘F in Safari | safari ×1 (1, 0 ms), preview ×1 (1, 0 ms), desk-a ×1 (2, 39 ms) | quiet 362 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 74 | leave-full-screen | presses ⌃⌘F again | safari ×1 (1, 0 ms), preview ×1 (1, 0 ms), desk-a ×1 (1, 0 ms) | quiet 416 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 75 | leave-alone | does nothing for half a minute |  | quiet 442 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✘ |
| 76 | grow | presses ⌃⌥⌘= |  | quiet 694 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 77 | view-out | presses ⌃⌥↑ | safari ×1 (1, 0 ms), preview ×1 (1, 0 ms), desk-a ×1 (1, 0 ms) | quiet 779 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 78 | dock-icon-calendar | clicks calendar's icon in the Dock | safari ×1 (1, 0 ms), calendar ×1 (1, 0 ms), preview ×1 (1, 0 ms), desk-a ×1 (1, 0 ms) | quiet 584 ms; blind for 119 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 79 | save-view-2 | presses ⌃⌥⇧2 |  | quiet 735 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 80 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (2, 15 ms), mail ×1 (2, 7 ms), w248 ×1 (2, 7 ms), desk-a ×1 (2, 21 ms), desk-b ×1 (1, 0 ms) | quiet 783 ms |  |  | ~ |  | ✘ |  | ✔ | ✘ |
| 81 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 363 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 82 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 437 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 83 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 418 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 84 | launch | starts Arbor | finder ×2 (2, 673 ms), safari ×2 (2, 602 ms), textedit ×2 (5, 655 ms), terminal ×2 (7, 691 ms), notes ×2 (3, 582 ms), calendar ×2 (3, 468 ms), settings ×2 (3, 480 ms), preview ×2 (2, 295 ms), desk-a ×1 (3, 371 ms), desk-b ×1 (4, 331 ms) | quiet 562 ms; blind for 141 ms |  | ✔ | ✘ |  |  |  | ✘ | ✔ |
| 85 | view-in | presses ⌃⌥↓ | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1508 ms; blind for 106 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 86 | dock-icon-safari | clicks safari's icon in the Dock | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms), mail ×1 (1, 0 ms), w248 ×1 (1, 0 ms) | quiet 792 ms; blind for 225 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 87 | float | presses ⌃⌥F | safari ×1 (1, 0 ms), mail ×1 (1, 0 ms), w248 ×1 (1, 0 ms) | quiet 842 ms |  | ✘ | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 88 | view-frame | presses ⌃⌥↩ | textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1062 ms; blind for 190 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 89 | dock-icon-calendar | clicks calendar's icon in the Dock | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), mail ×1 (1, 0 ms), w248 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1578 ms; blind for 225 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 90 | pin | chooses Keep This Window in View in Arbor's menu, or takes the tick off | finder ×1 (1, 0 ms), calendar ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1083 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 91 | drag-calendar-to-right-edge | drags calendar by its title bar against the right edge of the screen and lets go | calendar ×1 (8, 258 ms) | quiet 396 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 92 | dock-icon-notes | clicks notes's icon in the Dock | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), mail ×1 (1, 0 ms), w248 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 907 ms; blind for 129 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 93 | view-all | presses ⌃⌥Space |  | quiet 699 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 94 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 400 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 95 | drag-terminal-to-right-edge | drags terminal by its title bar against the right edge of the screen and lets go | terminal ×1 (1, 0 ms) | quiet 365 ms | ✔ | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 96 | dock-icon-preview | clicks preview's icon in the Dock | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w248 ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 999 ms; blind for 137 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 97 | display-plug | the second display: plug | finder ×2 (2, 2280 ms), safari ×2 (2, 3187 ms), textedit ×2 (2, 3162 ms), terminal ×2 (2, 3236 ms), notes ×2 (2, 2280 ms), calendar ×2 (4, 3454 ms), settings ×2 (2, 2061 ms), preview ×2 (2, 3162 ms), mail ×2 (2, 2594 ms), w248 ×2 (2, 2594 ms), desk-a ×2 (2, 1862 ms), desk-b ×2 (2, 1862 ms) | quiet 361 ms; blind for 882 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 98 | view-home | presses ⌃⌥0 | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (2, 98 ms), w248 ×1 (2, 98 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1446 ms |  |  | ~ |  |  |  | ✔ | ✔ |
| 99 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 410 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 100 | drag-safari-by | drags safari, which floats, by its title bar -100 across and 91 down | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms), preview ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1506 ms; blind for 126 ms | ✔ | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 101 | float-all | presses ⌃⌥⇧F | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 1296 ms |  |  | ~ |  | ✘ |  | ✔ | ✔ |
| 102 | view-out | presses ⌃⌥↑ |  | quiet 657 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 103 | view-frame | presses ⌃⌥↩ |  | quiet 770 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 104 | display-unplug | the second display: unplug | safari ×1 (1, 0 ms), textedit ×2 (2, 1746 ms), terminal ×2 (3, 1776 ms), calendar ×2 (2, 1776 ms), mail ×2 (2, 1851 ms), w248 ×2 (2, 1851 ms) | quiet 727 ms; blind for 431 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 105 | view-home | presses ⌃⌥0 | calendar ×1 (1, 0 ms) | quiet 730 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 106 | display-plug | the second display: plug | textedit ×2 (2, 2332 ms), terminal ×3 (3, 2332 ms), calendar ×2 (2, 472 ms), mail ×3 (4, 2395 ms), w248 ×3 (4, 2395 ms) | quiet 398 ms; blind for 279 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 107 | view-home | presses ⌃⌥0 |  | quiet 852 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 108 | focus-up | presses ⌃⌥⇧ and the up arrow |  | quiet 382 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 109 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 435 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 110 | new-window-safari | presses ⌘N in safari |  | quiet 355 ms; blind for 1004 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 111 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 373 ms; blind for 246 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 112 | dock-down | presses ⌃⌥⌘ and the down arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w248 ×1 (1, 0 ms), safari-new-110 ×1 (1, 0 ms) | quiet 824 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 113 | click-new-window | clicks the title bar of the window that ⌘N opened |  | quiet 553 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 114 | close-window | presses ⌘W |  | quiet 1028 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 115 | view-all | presses ⌃⌥Space |  | quiet 633 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 116 | peek | holds ⌃⌥Space for a second and a half and lets go |  | quiet 369 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 117 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 451 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 118 | minimize-notes | presses ⌘M | terminal ×1 (2, 12 ms), notes ×1 (23, 491 ms) | quiet 1501 ms; blind for 167 ms |  | ✘ | ✔ |  |  |  | ✔ | ✔ |
| 119 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 443 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 120 | restore-notes | clicks notes's icon in the Dock, which brings its minimized window back | notes ×1 (20, 443 ms) | quiet 1011 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 121 | hold | holds the view, as for a shared screen |  | quiet 366 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 122 | show-desktop-while-held | presses ⌃⌥D, which would show the Desktop: the view is held |  | quiet 850 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 123 | release | lets the view go again |  | quiet 357 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 124 | drag-preview-to-left-edge | drags preview by its title bar against the left edge of the screen and lets go | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w248 ×1 (1, 0 ms) | quiet 378 ms; blind for 105 ms | ✔ | ✘ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 125 | display-unplug | the second display: unplug | safari ×1 (1, 0 ms), textedit ×2 (2, 2102 ms), terminal ×2 (3, 2161 ms), calendar ×2 (2, 2161 ms), preview ×1 (1, 0 ms), mail ×2 (2, 1840 ms), w248 ×2 (2, 1840 ms) | quiet 754 ms; blind for 245 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 126 | view-home | presses ⌃⌥0 |  | quiet 760 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 127 | display-plug | the second display: plug | textedit ×2 (2, 1968 ms), terminal ×2 (3, 1991 ms), calendar ×1 (1, 0 ms), mail ×1 (1, 0 ms), w248 ×1 (1, 0 ms) | quiet 428 ms; blind for 212 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 128 | view-home | presses ⌃⌥0 |  | quiet 660 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 129 | send-across | sends the window in front to the other display | preview ×1 (1, 0 ms) | quiet 942 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 130 | float-all | presses ⌃⌥⇧F |  | quiet 797 ms |  |  | ✔ |  | ✘ |  | ✔ | ✔ |
| 131 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 424 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 132 | dock-up | presses ⌃⌥⌘ and the up arrow | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), settings ×1 (1, 0 ms), mail ×1 (2, 47 ms), w248 ×1 (2, 47 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms) | quiet 906 ms |  | ✘ | ~ | ✔ |  |  | ✔ | ✔ |
| 133 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 490 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 134 | quit-safari | presses ⌘Q in safari |  | quiet 1000 ms; blind for 162 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 135 | view-right | presses ⌃⌥→ |  | quiet 787 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 136 | view-home | presses ⌃⌥0 |  | quiet 817 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 137 | reopen-safari | opens safari's document again |  | quiet 778 ms; blind for 971 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 138 | display-unplug | the second display: unplug | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×2 (2, 1774 ms), preview ×2 (3, 2491 ms), mail ×2 (2, 748 ms), w248 ×2 (2, 748 ms), desk-a ×1 (1, 0 ms), desk-b ×1 (1, 0 ms), safari ×1 (2, 13 ms) | quiet 680 ms; blind for 651 ms |  |  | ✘ |  |  |  | ✔ | ✔ |
| 139 | view-home | presses ⌃⌥0 |  | quiet 666 ms |  |  | ✔ |  |  |  | ✘ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 140 | view-home | presses ⌃⌥0 |  | quiet 745 ms |  | ✔ | ✔ |  |  |  | ✘ | ✔ |
| 141 | input-last | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 939 ms; blind for 125 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 142 | quit | chooses Quit Arbor in Arbor's menu | textedit ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w248 ×1 (1, 0 ms), safari ×1 (2, 61 ms) | quiet 805 ms |  |  | ✔ |  | ✘ |  | ✔ | ✘ |
| 143 | input-after | a round of input on two windows of its own: presses behind and in front, keys, a scroll, a drag inside the text |  | quiet 932 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 144 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 440 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 145 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 433 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 146 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 426 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 147 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 380 ms |  | ✔ | ✔ | ✘ |  | ✔ | ✔ | ✔ |
| 148 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 476 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 149 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 433 ms; blind for 113 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 150 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 419 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 151 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 491 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 152 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 420 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
