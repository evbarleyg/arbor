66 steps in 252 s, 52 of them judged, 2 with a rule broken. The sampler: samples 5932 seconds 174.5 hz 34.0 cost-ms 5.39 late 22 longest-gap-ms 827 whole-samples 8610 whole-seconds 253.2 whole-late 131.
Input: 26 presses, releases, keys and scrolls reached the apps, half of them within 607 µs, 99 in 100 within 70198 µs, the latest after 70198 µs.
By kind, listed only (events, half within, 99 in 100 within, µs): down 5, 992, 2254; key 16, 581, 6370; up 5, 592, 70198. `forward`: a press on a window of an app that was not in front.
The round of input `before` (events, half within µs): forward 8, 37676; up 8, 1506.
The round of input `started` (events, half within µs): forward 8, 35404; up 8, 1883.
The round of input `last` (events, half within µs): down 13, 515; dragged 20, 434; forward 13, 13885; key 13, 436; scroll 28, 308; up 26, 1218.
The round of input `after` (events, half within µs): forward 1, 89053; up 1, 1916.
Judged: no kind. Not down: fewer than 10 such events in a round without Arbor. Not forward: fewer than 10 such events in a round without Arbor. Not up: fewer than 10 such events in a round without Arbor. Not key: fewer than 10 such events in a round without Arbor. Not dragged: fewer than 10 such events in a round without Arbor. Not scroll: fewer than 10 such events in a round without Arbor.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 1 | never fight macOS: where it answers a drag, Arbor stands aside | 0 | 0 |  |
| 2 | nothing moves that the person did not move | 35 | 1 | 45 float |
| 3 | no jolts: a window moves once, to where it ends up | 54 | 1 | 55 input-last |
| 4 | the window you switch to comes to the front and into view | 33 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 4 | 0 |  |
| 6 | what a person presses reaches the apps, at once | 18 | 0 |  |
| L | no window is lost or stuck | 54 | 0 |  |
| - | what the script itself checked | 54 | 0 |  |

## Findings

### Rule 2: nothing moves that the person did not move

- ✘ **45 float** (presses ⌃⌥F): finder (w31) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 920×436 · +926 ms 340,120 920×436
- ✘ **45 float** (presses ⌃⌥F): terminal (w51) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,790 877×499 · +926 ms 40,51 877×499
- ✘ **45 float** (presses ⌃⌥F): settings (w63) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 723×625 · +926 ms 437,85 723×625
- ✘ **45 float** (presses ⌃⌥F): preview (w65) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 708×424 · +926 ms 4,35 708×424
- ✘ **45 float** (presses ⌃⌥F): mail (w69) a floating window, moved, and the step did not name it [moved-unasked]
  - +0 ms 1599,770 1120×630 · +926 ms 240,72 1120×630
- ~ **45 float** (presses ⌃⌥F): w71 of Mail moved along with a window of its app [moved-unasked]
  - +0 ms 1924,877 470×416 · +926 ms 565,179 470×416

### Rule 3: no jolts: a window moves once, to where it ends up

- ~ **52 undo** (presses ctrl+opt+z): the last window came to rest 1032 ms after the key or the button [slow]
- ✘ **55 input-last** (a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window): w186 of TextEdit opened in one place and was then moved to another [jolt]
  - +0 ms 376,327 28×13 · +399 ms -5,326 671×154 · +552 ms -1,327 663×151 · +572 ms 0,327 661×150 · +790 ms 47,327 535×122 · +808 ms 106,327 375×86 · +855 ms 178,327 181×42 · +889 ms 195,327 135×32 · +930 ms 234,327 30×8 · +994 ms 243,327 4×2 · +1031 ms off the screen
- ✘ **55 input-last** (a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window): w191 of TextEdit opened in one place and was then moved to another [jolt]
  - +0 ms 330,327 76×34 · +18 ms 168,327 325×75 · +56 ms 127,327 407×93 · +75 ms 65,327 531×121 · +142 ms 14,327 633×144 · +147 ms 6,327 649×148 · … 7 more … · +908 ms 174,327 192×44 · +916 ms 192,327 143×34 · +936 ms 217,327 75×18 · +1014 ms 241,327 11×4 · +1075 ms off the screen
- ✘ **55 input-last** (a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window): w191 of TextEdit moved 2 times [jolt]
  - +0 ms 330,327 76×34 · +18 ms 168,327 325×75 · +56 ms 127,327 407×93 · +75 ms 65,327 531×121 · +142 ms 14,327 633×144 · +147 ms 6,327 649×148 · … 7 more … · +908 ms 174,327 192×44 · +916 ms 192,327 143×34 · +936 ms 217,327 75×18 · +1014 ms 241,327 11×4 · +1075 ms off the screen
- ✘ **55 input-last** (a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window): w195 of TextEdit opened in one place and was then moved to another [jolt]
  - +0 ms 361,327 44×20 · +15 ms 319,327 88×39 · +65 ms 119,327 423×97 · +146 ms 12,327 637×145 · +175 ms -1,327 663×151 · +211 ms -5,326 671×154 · … 8 more … · +1024 ms 210,327 93×22 · +1096 ms 234,327 29×8 · +1107 ms 239,327 16×5 · +1124 ms 242,327 8×3 · +1157 ms off the screen
- ✘ **55 input-last** (a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window): w195 of TextEdit moved 2 times [jolt]
  - +0 ms 361,327 44×20 · +15 ms 319,327 88×39 · +65 ms 119,327 423×97 · +146 ms 12,327 637×145 · +175 ms -1,327 663×151 · +211 ms -5,326 671×154 · … 8 more … · +1024 ms 210,327 93×22 · +1096 ms 234,327 29×8 · +1107 ms 239,327 16×5 · +1124 ms 242,327 8×3 · +1157 ms off the screen
- ✘ **55 input-last** (a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window): w199 of TextEdit opened in one place and was then moved to another [jolt]
  - +0 ms 399,327 4×3 · +22 ms 334,327 72×32 · +71 ms 131,327 399×91 · +138 ms 45,327 571×130 · +168 ms 6,327 649×147 · +250 ms -5,326 671×154 · … 9 more … · +1132 ms 214,327 83×20 · +1140 ms 224,327 57×14 · +1158 ms 236,327 24×7 · +1227 ms 244,328 2×1 · +1258 ms off the screen
- ✘ **55 input-last** (a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window): w199 of TextEdit moved 2 times [jolt]
  - +0 ms 399,327 4×3 · +22 ms 334,327 72×32 · +71 ms 131,327 399×91 · +138 ms 45,327 571×130 · +168 ms 6,327 649×147 · +250 ms -5,326 671×154 · … 9 more … · +1132 ms 214,327 83×20 · +1140 ms 224,327 57×14 · +1158 ms 236,327 24×7 · +1227 ms 244,328 2×1 · +1258 ms off the screen
- ✘ **55 input-last** (a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window): w203 of TextEdit opened in one place and was then moved to another [jolt]
  - +0 ms 360,327 45×20 · +17 ms 317,327 90×40 · +36 ms 199,327 263×60 · +53 ms 117,327 427×97 · +104 ms 58,327 545×124 · +115 ms 38,327 585×133 · … 19 more … · +1033 ms 234,327 30×8 · +1047 ms 238,327 18×5 · +1071 ms 241,327 10×3 · +1082 ms 243,327 4×2 · +1133 ms off the screen
- ✘ **55 input-last** (a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window): w203 of TextEdit moved 2 times [jolt]
  - +0 ms 360,327 45×20 · +17 ms 317,327 90×40 · +36 ms 199,327 263×60 · +53 ms 117,327 427×97 · +104 ms 58,327 545×124 · +115 ms 38,327 585×133 · … 19 more … · +1033 ms 234,327 30×8 · +1047 ms 238,327 18×5 · +1071 ms 241,327 10×3 · +1082 ms 243,327 4×2 · +1133 ms off the screen
- ✘ **55 input-last** (a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window): w207 of TextEdit opened in one place and was then moved to another [jolt]
  - +0 ms 392,327 11×6 · +31 ms 317,327 90×40 · +90 ms 156,327 349×80 · +100 ms 85,327 491×112 · +158 ms 38,327 585×133 · +165 ms 22,327 617×140 · … 10 more … · +952 ms 124,327 325×75 · +1022 ms 205,327 108×26 · +1096 ms 240,327 13×4 · +1158 ms 244,328 2×1 · +1164 ms off the screen
- ✘ **55 input-last** (a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window): w207 of TextEdit moved 2 times [jolt]
  - +0 ms 392,327 11×6 · +31 ms 317,327 90×40 · +90 ms 156,327 349×80 · +100 ms 85,327 491×112 · +158 ms 38,327 585×133 · +165 ms 22,327 617×140 · … 10 more … · +952 ms 124,327 325×75 · +1022 ms 205,327 108×26 · +1096 ms 240,327 13×4 · +1158 ms 244,328 2×1 · +1164 ms off the screen

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### Before Arbor: the apps are open already

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 750 ms; blind for 242 ms |  |  |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 423 ms; blind for 828 ms |  |  |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (2, 241 ms) | quiet 1150 ms; blind for 896 ms |  |  |  |  |  |  |  |  |
| 4 | open-terminal | opens terminal | terminal ×1 (5, 353 ms) | quiet 906 ms; blind for 220 ms |  |  |  |  |  |  |  |  |
| 5 | open-notes | opens notes | notes ×1 (2, 15 ms), w55 ×2 (14, 1731 ms), w57 ×1 (11, 239 ms) | quiet 394 ms; blind for 236 ms |  |  |  |  |  |  |  |  |
| 6 | open-calendar | opens calendar | calendar ×1 (4, 325 ms) | quiet 1197 ms; blind for 133 ms |  |  |  |  |  |  |  |  |
| 7 | open-settings | opens settings | settings ×1 (1, 0 ms) | quiet 364 ms; blind for 736 ms |  |  |  |  |  |  |  |  |
| 8 | open-preview | opens preview |  | quiet 384 ms; blind for 1711 ms |  |  |  |  |  |  |  |  |
| 9 | open-mail | opens mail |  | quiet 373 ms; blind for 979 ms |  |  |  |  |  |  |  |  |
| 10 | tiling-acts | without Arbor: drags a window by its title bar against the menu bar and lets go | calendar ×2 (39, 4101 ms) | quiet 1407 ms; blind for 146 ms |  |  |  |  |  |  |  |  |
| 11 | tiling-acts-back | drags it away again, a hand's breadth down | calendar ×2 (38, 2548 ms) | quiet 1019 ms |  |  |  |  |  |  |  |  |
| 12 | look-around | looks at the screen |  | quiet 352 ms |  |  |  |  |  |  |  |  |
| 13 | input-before | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 848 ms; blind for 170 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |

### The walk

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 14 | launch | starts Arbor |  | quiet 1123 ms; blind for 217 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 15 | input-started | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 667 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 16 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 415 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 17 | dock-left | presses ctrl+opt+left | safari ×1 (1, 0 ms) | quiet 781 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 18 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 364 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 19 | dock-right | presses ctrl+opt+right | safari ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 1110 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 20 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 377 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 21 | dock-up | chooses `dock top` from Arbor's menu | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms) | quiet 1074 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 22 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 422 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 23 | dock-down | chooses `dock bottom` from Arbor's menu | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms) | quiet 910 ms; blind for 109 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 24 | view-frame | presses ctrl+opt+return | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1025 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 25 | view-out | chooses `out` from Arbor's menu | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1021 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 26 | view-in | chooses `in` from Arbor's menu | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1251 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 27 | view-back | presses ctrl+opt+[ | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 803 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 28 | view-forward | chooses `forward` from Arbor's menu | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1210 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 29 | view-desktop | chooses `desktop` from Arbor's menu | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1045 ms; blind for 117 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 30 | view-all | presses ctrl+opt+space | calendar ×1 (1, 0 ms) | quiet 756 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 31 | view-home | chooses `home` from Arbor's menu |  | quiet 388 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 32 | save-view-2 | chooses `save-view 2` from Arbor's menu |  | quiet 388 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 33 | view-frame | presses ctrl+opt+return | calendar ×1 (1, 0 ms) | quiet 974 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 34 | view-2 | chooses `view 2` from Arbor's menu | calendar ×1 (1, 0 ms) | quiet 1088 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 35 | peek | holds ⌃⌥Space for a second and a half and lets go |  | quiet 378 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 36 | view-home | chooses `home` from Arbor's menu |  | quiet 381 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 37 | dock-icon-notes | clicks notes's icon in the Dock | finder ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1151 ms; blind for 133 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 38 | grow | chooses `grow` from Arbor's menu |  | quiet 422 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 39 | shrink | chooses `shrink` from Arbor's menu |  | quiet 389 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 40 | balance | chooses `balance` from Arbor's menu |  | quiet 399 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 41 | rotate | chooses `rotate` from Arbor's menu |  | quiet 406 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 42 | mirror | chooses `mirror` from Arbor's menu |  | quiet 360 ms |  | ✔ | ✔ | ✔ |  |  | ✔ | ✔ |
| 43 | undo | presses ctrl+opt+z | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1085 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 44 | redo | chooses `redo` from Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1048 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 45 | float | presses ⌃⌥F | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 905 ms |  | ✘ | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 46 | undo | presses ctrl+opt+z | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 874 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 47 | arrange | chooses `arrange` from Arbor's menu | finder ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1044 ms; blind for 207 ms |  |  | ✔ | ✔ |  |  | ✔ | ✔ |
| 48 | hold | holds the view, as for a shared screen |  | quiet 1011 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 49 | show-everything-while-held | presses ⌃⌥Space, which would show everything: the view is held |  | quiet 772 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |
| 50 | release | lets the view go again |  | quiet 1001 ms |  |  | ✔ |  |  |  | ✔ | ✔ |
| 51 | float-all | chooses `float-all` from Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1202 ms; blind for 794 ms |  |  | ✔ |  | ✔ |  | ✔ | ✔ |
| 52 | undo | presses ctrl+opt+z | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1422 ms; blind for 159 ms |  |  | ~ | ✔ |  |  | ✔ | ✔ |
| 53 | pause | presses ⌃⌥⎋ | finder ×1 (2, 108 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms), terminal ×1 (1, 0 ms), notes ×1 (2, 166 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1311 ms; blind for 101 ms |  |  | ✔ | ✔ | ✔ |  | ✔ | ✔ |
| 54 | resume | presses ⌃⌥⎋ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 55 ms), terminal ×1 (2, 55 ms), notes ×1 (1, 0 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 1663 ms |  | ✔ | ✔ |  |  |  | ✔ | ✔ |

### The end

| # | Step | The person | Moved | Quiet after | 1 | 2 | 3 | 4 | 5 | 6 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 55 | input-last | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window | w186 ×1 (9, 595 ms), w191 ×2 (16, 996 ms), w195 ×2 (17, 1109 ms), w199 ×2 (18, 1205 ms), w203 ×2 (28, 1065 ms), w207 ×2 (19, 1127 ms) | quiet 967 ms; blind for 827 ms |  | ✔ | ✘ | ✔ |  | ✔ | ✔ | ✔ |
| 56 | quit | chooses Quit Arbor in Arbor's menu | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 32 ms), terminal ×1 (1, 0 ms), notes ×1 (2, 145 ms), calendar ×1 (1, 0 ms), settings ×1 (1, 0 ms), preview ×1 (1, 0 ms), mail ×1 (1, 0 ms), w71 ×1 (1, 0 ms) | quiet 824 ms |  |  | ✔ |  | ✔ |  | ✔ | ✔ |
| 57 | input-after | a round of input: presses on windows behind and in front, keys, a scroll, a drag inside a window |  | quiet 424 ms; blind for 102 ms |  | ✔ | ✔ |  |  | ✔ | ✔ | ✔ |
| 58 | dock-icon-finder | clicks finder's icon in the Dock |  | quiet 363 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 59 | dock-icon-safari | clicks safari's icon in the Dock |  | quiet 367 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 60 | dock-icon-textedit | clicks textedit's icon in the Dock |  | quiet 391 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 61 | dock-icon-terminal | clicks terminal's icon in the Dock |  | quiet 504 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 62 | dock-icon-notes | clicks notes's icon in the Dock |  | quiet 405 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 63 | dock-icon-calendar | clicks calendar's icon in the Dock |  | quiet 413 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 64 | dock-icon-settings | clicks settings's icon in the Dock |  | quiet 519 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 65 | dock-icon-preview | clicks preview's icon in the Dock |  | quiet 418 ms; blind for 107 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
| 66 | dock-icon-mail | clicks mail's icon in the Dock |  | quiet 403 ms |  | ✔ | ✔ | ✔ |  | ✔ | ✔ | ✔ |
