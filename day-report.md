33 steps in 108 s, 6 of them judged, 3 with a rule broken. The sampler: samples 3785 seconds 115.2 hz 32.9 cost-ms 3.51 late 1210 longest-gap-ms 1243.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 2 | nothing moves that the person did not move | 0 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 6 | 2 | 13 safari-101-arbor-out, 24 safari-105-arbor-out |
| 4 | the window you switch to comes to the front and into view | 5 | 1 | 16 textedit-102-arbor-out |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| L | no window is lost or stuck | 6 | 0 |  |
| - | what the script itself checked | 6 | 0 |  |

## Findings

### Rule 3: no jolts: a window moves once, to where it ends up

- ✘ **13 safari-101-arbor-out** (presses ⌃⌘F again): finder (w32) went 608 points out of its way before it ended up
  - +0 ms 12,43 501×767 · +642 ms 12,43 805×767 · +847 ms 12,43 501×767
- ✘ **13 safari-101-arbor-out** (presses ⌃⌘F again): textedit (w46) went 468 points out of its way before it ended up
  - +0 ms 1203,43 385×767 · +676 ms 969,43 397×767 · +682 ms 969,43 619×767 · +847 ms 1203,43 385×767
- ✘ **24 safari-105-arbor-out** (presses ⌃⌘F again): finder (w32) went 236 points out of its way before it ended up
  - +0 ms 12,43 501×767 · +736 ms 12,43 619×767 · +899 ms 12,43 501×767
- ✘ **24 safari-105-arbor-out** (presses ⌃⌘F again): textedit (w46) went 468 points out of its way before it ended up
  - +0 ms 1203,43 385×767 · +780 ms 969,43 397×767 · +832 ms 969,43 619×767 · +899 ms 1203,43 385×767

### Rule 4: the window you switch to comes to the front and into view

- ✘ **16 textedit-102-arbor-out** (presses ⌃⌘F again): textedit (w46) is not in front: w105 of TextEdit ahead of it, none of which covers it
- ✘ **16 textedit-102-arbor-out** (presses ⌃⌘F again): textedit (w46) is not wholly in view: 88% of it, at 0,0 1600×900 in 0,31 1600×791

### Rule -: what the script itself checked

- ~ **12 safari-101-in** (presses ⌃⌘F in safari): w32 is in view for Arbor but the window server does not show it
- ~ **12 safari-101-in** (presses ⌃⌘F in safari): w32 is docked and not parked, but has neither a slot nor a tile
- ~ **12 safari-101-in** (presses ⌃⌘F in safari): w36 is docked and not parked, but has neither a slot nor a tile
- ~ **12 safari-101-in** (presses ⌃⌘F in safari): w46 is in view for Arbor but the window server does not show it
- ~ **12 safari-101-in** (presses ⌃⌘F in safari): w46 is docked and not parked, but has neither a slot nor a tile
- ~ **15 textedit-102-in** (presses ⌃⌘F in textedit): w32 is in view for Arbor but the window server does not show it
- ~ **15 textedit-102-in** (presses ⌃⌘F in textedit): w32 is docked and not parked, but has neither a slot nor a tile
- ~ **15 textedit-102-in** (presses ⌃⌘F in textedit): w36 is in view for Arbor but the window server does not show it
- ~ **15 textedit-102-in** (presses ⌃⌘F in textedit): w36 is docked and not parked, but has neither a slot nor a tile
- ~ **15 textedit-102-in** (presses ⌃⌘F in textedit): w46 is docked and not parked, but has neither a slot nor a tile
- ~ **16 textedit-102-arbor-out** (presses ⌃⌘F again): w32 is in view for Arbor but the window server does not show it
- ~ **16 textedit-102-arbor-out** (presses ⌃⌘F again): w32 is docked and not parked, but has neither a slot nor a tile
- ~ **16 textedit-102-arbor-out** (presses ⌃⌘F again): w36 is in view for Arbor but the window server does not show it
- ~ **16 textedit-102-arbor-out** (presses ⌃⌘F again): w36 is docked and not parked, but has neither a slot nor a tile
- ~ **16 textedit-102-arbor-out** (presses ⌃⌘F again): w46 is docked and not parked, but has neither a slot nor a tile
- ~ **17 reach-safari-103** (clicks safari's title bar, or its Dock icon if that is covered): w32 is in view for Arbor but the window server does not show it
- ~ **17 reach-safari-103** (clicks safari's title bar, or its Dock icon if that is covered): w32 is docked and not parked, but has neither a slot nor a tile
- ~ **17 reach-safari-103** (clicks safari's title bar, or its Dock icon if that is covered): w36 is in view for Arbor but the window server does not show it
- ~ **17 reach-safari-103** (clicks safari's title bar, or its Dock icon if that is covered): w36 is docked and not parked, but has neither a slot nor a tile
- ~ **17 reach-safari-103** (clicks safari's title bar, or its Dock icon if that is covered): w46 is docked and not parked, but has neither a slot nor a tile
- ~ **20 textedit-104-in** (presses ⌃⌘F in textedit): w32 is in view for Arbor but the window server does not show it
- ~ **20 textedit-104-in** (presses ⌃⌘F in textedit): w32 is docked and not parked, but has neither a slot nor a tile
- ~ **20 textedit-104-in** (presses ⌃⌘F in textedit): w36 is in view for Arbor but the window server does not show it
- ~ **20 textedit-104-in** (presses ⌃⌘F in textedit): w36 is docked and not parked, but has neither a slot nor a tile
- ~ **20 textedit-104-in** (presses ⌃⌘F in textedit): w46 is docked and not parked, but has neither a slot nor a tile
- ~ **23 safari-105-in** (presses ⌃⌘F in safari): w32 is in view for Arbor but the window server does not show it
- ~ **23 safari-105-in** (presses ⌃⌘F in safari): w32 is docked and not parked, but has neither a slot nor a tile
- ~ **23 safari-105-in** (presses ⌃⌘F in safari): w36 is docked and not parked, but has neither a slot nor a tile
- ~ **23 safari-105-in** (presses ⌃⌘F in safari): w46 is in view for Arbor but the window server does not show it
- ~ **23 safari-105-in** (presses ⌃⌘F in safari): w46 is docked and not parked, but has neither a slot nor a tile
- ~ **26 textedit-106-in** (presses ⌃⌘F in textedit): w32 is in view for Arbor but the window server does not show it
- ~ **26 textedit-106-in** (presses ⌃⌘F in textedit): w32 is docked and not parked, but has neither a slot nor a tile
- ~ **26 textedit-106-in** (presses ⌃⌘F in textedit): w36 is in view for Arbor but the window server does not show it
- ~ **26 textedit-106-in** (presses ⌃⌘F in textedit): w36 is docked and not parked, but has neither a slot nor a tile
- ~ **26 textedit-106-in** (presses ⌃⌘F in textedit): w46 is docked and not parked, but has neither a slot nor a tile
- ~ **29 safari-200-in** (presses ⌃⌘F in safari): w32 is in view for Arbor but the window server does not show it
- ~ **29 safari-200-in** (presses ⌃⌘F in safari): w32 is docked and not parked, but has neither a slot nor a tile
- ~ **29 safari-200-in** (presses ⌃⌘F in safari): w36 is docked and not parked, but has neither a slot nor a tile
- ~ **29 safari-200-in** (presses ⌃⌘F in safari): w46 is in view for Arbor but the window server does not show it
- ~ **29 safari-200-in** (presses ⌃⌘F in safari): w46 is docked and not parked, but has neither a slot nor a tile
- ~ **30 back-to-the-desktop** (presses ⌃←: the desktop comes back without Safari): w36 is in view for Arbor but the window server does not show it
- ~ **30 back-to-the-desktop** (presses ⌃←: the desktop comes back without Safari): w36 is docked and not parked, but has neither a slot nor a tile
- ~ **31 forth-to-safari** (presses ⌃→): w32 is in view for Arbor but the window server does not show it
- ~ **31 forth-to-safari** (presses ⌃→): w32 is docked and not parked, but has neither a slot nor a tile
- ~ **31 forth-to-safari** (presses ⌃→): w36 is docked and not parked, but has neither a slot nor a tile
- ~ **31 forth-to-safari** (presses ⌃→): w46 is in view for Arbor but the window server does not show it
- ~ **31 forth-to-safari** (presses ⌃→): w46 is docked and not parked, but has neither a slot nor a tile

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### The apps are open

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 653 ms; blind for 250 ms |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 0 ms; blind for 1243 ms |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (3, 238 ms) | quiet 2063 ms; blind for 889 ms |  |  |  |  |  |  |

### With Arbor

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 4 | launch | starts Arbor | w52 ×1 (3, 64 ms) | quiet 957 ms; blind for 116 ms |  |  |  |  |  |  |
| 5 | reach-finder-100 | clicks finder's title bar, or its Dock icon if that is covered |  | quiet 321 ms; blind for 73 ms |  |  |  |  |  |  |
| 6 | dock-finder-left | presses ⌃⌥⌘← | finder ×1 (2, 75 ms), safari ×1 (2, 9 ms), textedit ×1 (1, 0 ms) | quiet 1122 ms; blind for 119 ms |  |  |  |  |  |  |
| 7 | reach-safari-100 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 308 ms; blind for 98 ms |  |  |  |  |  |  |
| 8 | dock-safari-right | presses ⌃⌥⌘→ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 11 ms) | quiet 1208 ms; blind for 98 ms |  |  |  |  |  |  |
| 9 | reach-textedit-100 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 286 ms; blind for 74 ms |  |  |  |  |  |  |
| 10 | dock-textedit-right | presses ⌃⌥⌘→ | finder ×1 (1, 0 ms), safari ×1 (2, 64 ms), textedit ×1 (2, 64 ms) | quiet 721 ms; blind for 72 ms |  |  |  |  |  |  |

### With Arbor: safari, round 101

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 11 | reach-safari-101 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 460 ms; blind for 83 ms |  |  |  |  |  |  |
| 12 | safari-101-in | presses ⌃⌘F in safari | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 87 ms |  |  |  |  |  | ~ |
| 13 | safari-101-arbor-out | presses ⌃⌘F again | finder ×1 (2, 205 ms), safari ×1 (1, 0 ms), textedit ×1 (3, 171 ms) | quiet 0 ms; blind for 70 ms |  | ✘ | ✔ |  | ✔ | ✔ |

### With Arbor: textedit, round 102

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 14 | reach-textedit-102 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 261 ms; blind for 129 ms |  |  |  |  |  |  |
| 15 | textedit-102-in | presses ⌃⌘F in textedit | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 101 ms |  |  |  |  |  | ~ |
| 16 | textedit-102-arbor-out | presses ⌃⌘F again |  | quiet 0 ms; blind for 79 ms |  | ✔ | ✘ |  | ✔ | ~ |

### With Arbor: safari, round 103

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 17 | reach-safari-103 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 312 ms; blind for 78 ms |  |  |  |  |  | ~ |
| 18 | safari-103-in | presses ⌃⌘F in safari | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 209 ms |  |  |  |  |  |  |

### With Arbor: textedit, round 104

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 19 | reach-textedit-104 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 402 ms; blind for 75 ms |  |  |  |  |  |  |
| 20 | textedit-104-in | presses ⌃⌘F in textedit | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 79 ms |  |  |  |  |  | ~ |
| 21 | textedit-104-arbor-out | presses ⌃⌘F again | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 86 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: safari, round 105

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 22 | reach-safari-105 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 324 ms; blind for 87 ms |  |  |  |  |  |  |
| 23 | safari-105-in | presses ⌃⌘F in safari | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 78 ms |  |  |  |  |  | ~ |
| 24 | safari-105-arbor-out | presses ⌃⌘F again | finder ×1 (2, 163 ms), safari ×1 (1, 0 ms), textedit ×1 (3, 119 ms) | quiet 0 ms; blind for 77 ms |  | ✘ | ✔ |  | ✔ | ✔ |

### With Arbor: textedit, round 106

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 25 | reach-textedit-106 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 382 ms; blind for 114 ms |  |  |  |  |  |  |
| 26 | textedit-106-in | presses ⌃⌘F in textedit | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 144 ms |  |  |  |  |  | ~ |
| 27 | textedit-106-arbor-out | presses ⌃⌘F again | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 83 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: back to the desktop while Safari stays in full screen

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 28 | reach-safari-200 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 328 ms; blind for 119 ms |  |  |  |  |  |  |
| 29 | safari-200-in | presses ⌃⌘F in safari | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 105 ms |  |  |  |  |  | ~ |
| 30 | back-to-the-desktop | presses ⌃←: the desktop comes back without Safari | finder ×1 (1, 0 ms), textedit ×1 (2, 46 ms) | quiet 0 ms; blind for 92 ms |  |  |  |  |  | ~ |
| 31 | forth-to-safari | presses ⌃→ |  | quiet 0 ms; blind for 95 ms |  |  |  |  |  | ~ |
| 32 | safari-200-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 81 ms |  | ✔ |  |  | ✔ | ✔ |
| 33 | quit | quits Arbor | finder ×1 (1, 0 ms), safari ×1 (2, 73 ms), textedit ×1 (2, 75 ms) | quiet 1086 ms; blind for 75 ms |  |  |  |  |  |  |
