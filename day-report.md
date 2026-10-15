59 steps in 221 s, 16 of them judged, 6 with a rule broken. The sampler: samples 8734 seconds 233.5 hz 37.4 cost-ms 2.26 late 2264 longest-gap-ms 1436.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 2 | nothing moves that the person did not move | 0 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 16 | 6 | 6 safari-1-never-out, 9 safari-2-now-out, 12 safari-3-scaffold-out, 15 safari-4-left-out, 24 textedit-7-never-out, 36 textedit-11-landed-out |
| 4 | the window you switch to comes to the front and into view | 4 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| L | no window is lost or stuck | 16 | 0 |  |
| - | what the script itself checked | 16 | 0 |  |

## Findings

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **6 safari-1-never-out** (presses ⌃⌘F again; the window is asked for its slot: never): safari (w36) moved 2 times
  - +0 ms 0,0 1600×900 · +459 ms off the screen · +1112 ms 138,31 1324×791 · +5511 ms 138,31 620×640 · +5539 ms 800,60 620×640
- ~ **6 safari-1-never-out** (presses ⌃⌘F again; the window is asked for its slot: never): safari (w36) was still moving 469 ms after everything had been quiet for a second
- ✘ **9 safari-2-now-out** (presses ⌃⌘F again; the window is asked for its slot: now): safari (w36) moved 2 times
  - +0 ms 0,0 1600×900 · +298 ms off the screen · +863 ms 138,31 1324×791 · +5443 ms 800,60 620×640
- ~ **9 safari-2-now-out** (presses ⌃⌘F again; the window is asked for its slot: now): safari (w36) was still moving 475 ms after everything had been quiet for a second
- ✘ **12 safari-3-scaffold-out** (presses ⌃⌘F again; the window is asked for its slot: scaffold): safari (w36) moved 2 times
  - +0 ms 0,0 1600×900 · +319 ms off the screen · +1047 ms 138,31 1324×791 · +5394 ms 800,60 620×640
- ~ **12 safari-3-scaffold-out** (presses ⌃⌘F again; the window is asked for its slot: scaffold): safari (w36) was still moving 367 ms after everything had been quiet for a second
- ✘ **15 safari-4-left-out** (presses ⌃⌘F again; the window is asked for its slot: left): safari (w36) moved 2 times
  - +0 ms 0,0 1600×900 · +372 ms off the screen · +1180 ms 138,31 1324×791 · +5445 ms 800,60 620×640
- ~ **15 safari-4-left-out** (presses ⌃⌘F again; the window is asked for its slot: left): safari (w36) was still moving 441 ms after everything had been quiet for a second
- ~ **21 safari-6-never-out** (presses ⌃⌘F again; the window is asked for its slot: never): textedit (w46) was still moving 509 ms after everything had been quiet for a second
- ✘ **24 textedit-7-never-out** (presses ⌃⌘F again; the window is asked for its slot: never): textedit (w46) moved 2 times
  - +0 ms 0,0 1600×900 · +165 ms off the screen · +713 ms 165,65 656×422 · +5245 ms 800,60 620×640
- ~ **24 textedit-7-never-out** (presses ⌃⌘F again; the window is asked for its slot: never): textedit (w46) was still moving 320 ms after everything had been quiet for a second
- ✘ **36 textedit-11-landed-out** (presses ⌃⌘F again; the window is asked for its slot: landed): textedit (w46) went 436 points out of its way before it ended up
  - +0 ms 0,0 1600×900 · +305 ms off the screen · +831 ms 165,65 656×422 · +875 ms 800,60 620×640

### Rule -: what the script itself checked

- ~ **42 dock-finder-left** (presses ⌃⌥⌘←): took more than a second longer to agree with the screen: w32 is at 340,120 920×436 but Arbor believes 12,43 782×767
- ~ **48 safari-101-in** (presses ⌃⌘F in safari): w32 is in view for Arbor but the window server does not show it
- ~ **48 safari-101-in** (presses ⌃⌘F in safari): w32 is docked and not parked, but has neither a slot nor a tile
- ~ **48 safari-101-in** (presses ⌃⌘F in safari): w36 is docked and not parked, but has neither a slot nor a tile
- ~ **48 safari-101-in** (presses ⌃⌘F in safari): w46 is in view for Arbor but the window server does not show it
- ~ **48 safari-101-in** (presses ⌃⌘F in safari): w46 is docked and not parked, but has neither a slot nor a tile
- ~ **51 textedit-102-in** (presses ⌃⌘F in textedit): w32 is in view for Arbor but the window server does not show it
- ~ **51 textedit-102-in** (presses ⌃⌘F in textedit): w32 is docked and not parked, but has neither a slot nor a tile
- ~ **51 textedit-102-in** (presses ⌃⌘F in textedit): w36 is in view for Arbor but the window server does not show it
- ~ **51 textedit-102-in** (presses ⌃⌘F in textedit): w36 is docked and not parked, but has neither a slot nor a tile
- ~ **51 textedit-102-in** (presses ⌃⌘F in textedit): w46 is docked and not parked, but has neither a slot nor a tile
- ~ **54 safari-103-in** (presses ⌃⌘F in safari): w32 is in view for Arbor but the window server does not show it
- ~ **54 safari-103-in** (presses ⌃⌘F in safari): w32 is docked and not parked, but has neither a slot nor a tile
- ~ **54 safari-103-in** (presses ⌃⌘F in safari): w36 is docked and not parked, but has neither a slot nor a tile
- ~ **54 safari-103-in** (presses ⌃⌘F in safari): w46 is in view for Arbor but the window server does not show it
- ~ **54 safari-103-in** (presses ⌃⌘F in safari): w46 is docked and not parked, but has neither a slot nor a tile
- ~ **57 textedit-104-in** (presses ⌃⌘F in textedit): w32 is in view for Arbor but the window server does not show it
- ~ **57 textedit-104-in** (presses ⌃⌘F in textedit): w32 is docked and not parked, but has neither a slot nor a tile
- ~ **57 textedit-104-in** (presses ⌃⌘F in textedit): w36 is in view for Arbor but the window server does not show it
- ~ **57 textedit-104-in** (presses ⌃⌘F in textedit): w36 is docked and not parked, but has neither a slot nor a tile
- ~ **57 textedit-104-in** (presses ⌃⌘F in textedit): w46 is docked and not parked, but has neither a slot nor a tile

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### The apps are open

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 551 ms; blind for 335 ms |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 778 ms; blind for 1436 ms |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | safari ×1 (1, 0 ms), textedit ×1 (3, 274 ms) | quiet 1234 ms; blind for 985 ms |  |  |  |  |  |  |

### Without Arbor: asked at one moment per round

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 4 | reach-safari-1 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 267 ms; blind for 109 ms |  |  |  |  |  |  |
| 5 | safari-1-in | presses ⌃⌘F in safari | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 208 ms |  |  |  |  |  |  |
| 6 | safari-1-never-out | presses ⌃⌘F again; the window is asked for its slot: never | safari ×2 (3, 4427 ms) | quiet 0 ms; blind for 202 ms |  | ✘ |  |  | ✔ | ✔ |
| 7 | reach-safari-2 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 323 ms; blind for 78 ms |  |  |  |  |  |  |
| 8 | safari-2-in | presses ⌃⌘F in safari | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 76 ms |  |  |  |  |  |  |
| 9 | safari-2-now-out | presses ⌃⌘F again; the window is asked for its slot: now | safari ×2 (2, 4580 ms) | quiet 0 ms; blind for 77 ms |  | ✘ |  |  | ✔ | ✔ |
| 10 | reach-safari-3 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 377 ms; blind for 71 ms |  |  |  |  |  |  |
| 11 | safari-3-in | presses ⌃⌘F in safari | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 78 ms |  |  |  |  |  |  |
| 12 | safari-3-scaffold-out | presses ⌃⌘F again; the window is asked for its slot: scaffold | safari ×2 (2, 4347 ms) | quiet 0 ms; blind for 157 ms |  | ✘ |  |  | ✔ | ✔ |
| 13 | reach-safari-4 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 387 ms; blind for 69 ms |  |  |  |  |  |  |
| 14 | safari-4-in | presses ⌃⌘F in safari | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 103 ms |  |  |  |  |  |  |
| 15 | safari-4-left-out | presses ⌃⌘F again; the window is asked for its slot: left | safari ×2 (2, 4265 ms) | quiet 0 ms; blind for 173 ms |  | ✘ |  |  | ✔ | ✔ |
| 16 | reach-safari-5 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 369 ms; blind for 70 ms |  |  |  |  |  |  |
| 17 | safari-5-in | presses ⌃⌘F in safari | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 133 ms |  |  |  |  |  |  |
| 18 | safari-5-landed-out | presses ⌃⌘F again; the window is asked for its slot: landed | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 78 ms |  | ✔ |  |  | ✔ | ✔ |
| 19 | reach-safari-6 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 208 ms; blind for 74 ms |  |  |  |  |  |  |
| 20 | safari-6-in | presses ⌃⌘F in safari | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 74 ms |  |  |  |  |  |  |
| 21 | safari-6-never-out | presses ⌃⌘F again; the window is asked for its slot: never | safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 80 ms |  | ~ |  |  | ✔ | ✔ |
| 22 | reach-textedit-7 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 482 ms; blind for 103 ms |  |  |  |  |  |  |
| 23 | textedit-7-in | presses ⌃⌘F in textedit | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 104 ms |  |  |  |  |  |  |
| 24 | textedit-7-never-out | presses ⌃⌘F again; the window is asked for its slot: never | textedit ×2 (2, 4532 ms) | quiet 0 ms; blind for 80 ms |  | ✘ |  |  | ✔ | ✔ |
| 25 | reach-textedit-8 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 403 ms; blind for 75 ms |  |  |  |  |  |  |
| 26 | textedit-8-in | presses ⌃⌘F in textedit | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 75 ms |  |  |  |  |  |  |
| 27 | textedit-8-now-out | presses ⌃⌘F again; the window is asked for its slot: now |  | quiet 0 ms; blind for 79 ms |  | ✔ |  |  | ✔ | ✔ |
| 28 | reach-textedit-9 | clicks textedit's title bar, or its Dock icon if that is covered | textedit ×1 (1, 0 ms) | quiet 1531 ms; blind for 406 ms |  |  |  |  |  |  |
| 29 | textedit-9-in | presses ⌃⌘F in textedit | textedit ×1 (1, 0 ms), w265 ×1 (1, 0 ms) | quiet 0 ms; blind for 101 ms |  |  |  |  |  |  |
| 30 | textedit-9-scaffold-out | presses ⌃⌘F again; the window is asked for its slot: scaffold | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 76 ms |  | ✔ |  |  | ✔ | ✔ |
| 31 | reach-textedit-10 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 390 ms; blind for 74 ms |  |  |  |  |  |  |
| 32 | textedit-10-in | presses ⌃⌘F in textedit | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 129 ms |  |  |  |  |  |  |
| 33 | textedit-10-left-out | presses ⌃⌘F again; the window is asked for its slot: left | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 92 ms |  | ✔ |  |  | ✔ | ✔ |
| 34 | reach-textedit-11 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 314 ms; blind for 66 ms |  |  |  |  |  |  |
| 35 | textedit-11-in | presses ⌃⌘F in textedit | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 90 ms |  |  |  |  |  |  |
| 36 | textedit-11-landed-out | presses ⌃⌘F again; the window is asked for its slot: landed | textedit ×1 (2, 44 ms) | quiet 0 ms; blind for 103 ms |  | ✘ |  |  | ✔ | ✔ |
| 37 | reach-textedit-12 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 464 ms; blind for 65 ms |  |  |  |  |  |  |
| 38 | textedit-12-in | presses ⌃⌘F in textedit | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 89 ms |  |  |  |  |  |  |
| 39 | textedit-12-never-out | presses ⌃⌘F again; the window is asked for its slot: never | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 71 ms |  | ✔ |  |  | ✔ | ✔ |

### With Arbor

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 40 | launch | starts Arbor |  | quiet 1034 ms; blind for 67 ms |  |  |  |  |  |  |
| 41 | reach-finder-100 | clicks finder's title bar, or its Dock icon if that is covered |  | quiet 329 ms; blind for 89 ms |  |  |  |  |  |  |
| 42 | dock-finder-left | presses ⌃⌥⌘← | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 75 ms |  |  |  |  |  | ~ |
| 43 | reach-safari-100 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 314 ms; blind for 78 ms |  |  |  |  |  |  |
| 44 | dock-safari-right | presses ⌃⌥⌘→ | finder ×1 (1, 0 ms), safari ×1 (2, 12 ms), textedit ×1 (1, 0 ms) | quiet 721 ms; blind for 74 ms |  |  |  |  |  |  |
| 45 | reach-textedit-100 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 398 ms; blind for 95 ms |  |  |  |  |  |  |
| 46 | dock-textedit-right | presses ⌃⌥⌘→ | finder ×1 (1, 0 ms), safari ×1 (2, 32 ms), textedit ×1 (2, 45 ms) | quiet 832 ms; blind for 68 ms |  |  |  |  |  |  |

### With Arbor: safari, round 101

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 47 | reach-safari-101 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 407 ms; blind for 75 ms |  |  |  |  |  |  |
| 48 | safari-101-in | presses ⌃⌘F in safari | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 49 ms) | quiet 0 ms; blind for 89 ms |  |  |  |  |  | ~ |
| 49 | safari-101-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 410 ms; blind for 78 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: textedit, round 102

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 50 | reach-textedit-102 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 340 ms; blind for 141 ms |  |  |  |  |  |  |
| 51 | textedit-102-in | presses ⌃⌘F in textedit | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 74 ms |  |  |  |  |  | ~ |
| 52 | textedit-102-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 84 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: safari, round 103

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 53 | reach-safari-103 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 333 ms; blind for 75 ms |  |  |  |  |  |  |
| 54 | safari-103-in | presses ⌃⌘F in safari | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 82 ms |  |  |  |  |  | ~ |
| 55 | safari-103-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 98 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: textedit, round 104

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 56 | reach-textedit-104 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 301 ms; blind for 76 ms |  |  |  |  |  |  |
| 57 | textedit-104-in | presses ⌃⌘F in textedit | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 89 ms |  |  |  |  |  | ~ |
| 58 | textedit-104-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 410 ms; blind for 79 ms |  | ✔ | ✔ |  | ✔ | ✔ |
| 59 | quit | quits Arbor | finder ×1 (2, 21 ms), safari ×1 (3, 73 ms), textedit ×1 (1, 0 ms) | quiet 1045 ms; blind for 82 ms |  |  |  |  |  |  |
