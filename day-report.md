46 steps in 148 s, 11 of them judged, 1 with a rule broken. The sampler: samples 5621 seconds 159.5 hz 35.3 cost-ms 2.95 late 1626 longest-gap-ms 1238.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 2 | nothing moves that the person did not move | 0 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 11 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 11 | 1 | 37 textedit-109-arbor-out |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| L | no window is lost or stuck | 11 | 0 |  |
| - | what the script itself checked | 11 | 0 |  |

## Findings

### Rule 4: the window you switch to comes to the front and into view

- ~ **28 textedit-106-arbor-out** (presses ⌃⌘F again): the window in front changed 3 times: w220 of TextEdit → w236 of TextEdit → safari (w35) → textedit (w45)
- ✘ **37 textedit-109-arbor-out** (presses ⌃⌘F again): textedit (w45) is not in front: w305 of TextEdit ahead of it, none of which covers it
- ✘ **37 textedit-109-arbor-out** (presses ⌃⌘F again): textedit (w45) is not wholly in view: 88% of it, at 0,0 1600×900 in 0,31 1600×791

### Rule -: what the script itself checked

- ~ **6 dock-finder-left** (presses ⌃⌥⌘←): took more than a second longer to agree with the screen: w31 is at 340,120 920×436 but Arbor believes 12,43 782×767
- ~ **12 safari-101-in** (presses ⌃⌘F in safari): w31 is in view for Arbor but the window server does not show it
- ~ **12 safari-101-in** (presses ⌃⌘F in safari): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **12 safari-101-in** (presses ⌃⌘F in safari): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **12 safari-101-in** (presses ⌃⌘F in safari): w45 is in view for Arbor but the window server does not show it
- ~ **12 safari-101-in** (presses ⌃⌘F in safari): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **15 safari-102-in** (presses ⌃⌘F in safari): w31 is in view for Arbor but the window server does not show it
- ~ **15 safari-102-in** (presses ⌃⌘F in safari): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **15 safari-102-in** (presses ⌃⌘F in safari): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **15 safari-102-in** (presses ⌃⌘F in safari): w45 is in view for Arbor but the window server does not show it
- ~ **15 safari-102-in** (presses ⌃⌘F in safari): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **18 textedit-103-in** (presses ⌃⌘F in textedit): w31 is in view for Arbor but the window server does not show it
- ~ **18 textedit-103-in** (presses ⌃⌘F in textedit): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **18 textedit-103-in** (presses ⌃⌘F in textedit): w35 is in view for Arbor but the window server does not show it
- ~ **18 textedit-103-in** (presses ⌃⌘F in textedit): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **18 textedit-103-in** (presses ⌃⌘F in textedit): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **21 safari-104-in** (presses ⌃⌘F in safari): w31 is in view for Arbor but the window server does not show it
- ~ **21 safari-104-in** (presses ⌃⌘F in safari): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **21 safari-104-in** (presses ⌃⌘F in safari): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **21 safari-104-in** (presses ⌃⌘F in safari): w45 is in view for Arbor but the window server does not show it
- ~ **21 safari-104-in** (presses ⌃⌘F in safari): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **24 safari-105-in** (presses ⌃⌘F in safari): w31 is in view for Arbor but the window server does not show it
- ~ **24 safari-105-in** (presses ⌃⌘F in safari): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **24 safari-105-in** (presses ⌃⌘F in safari): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **24 safari-105-in** (presses ⌃⌘F in safari): w45 is in view for Arbor but the window server does not show it
- ~ **24 safari-105-in** (presses ⌃⌘F in safari): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **27 textedit-106-in** (presses ⌃⌘F in textedit): w31 is in view for Arbor but the window server does not show it
- ~ **27 textedit-106-in** (presses ⌃⌘F in textedit): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **27 textedit-106-in** (presses ⌃⌘F in textedit): w35 is in view for Arbor but the window server does not show it
- ~ **27 textedit-106-in** (presses ⌃⌘F in textedit): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **27 textedit-106-in** (presses ⌃⌘F in textedit): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **30 safari-107-in** (presses ⌃⌘F in safari): w31 is in view for Arbor but the window server does not show it
- ~ **30 safari-107-in** (presses ⌃⌘F in safari): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **30 safari-107-in** (presses ⌃⌘F in safari): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **30 safari-107-in** (presses ⌃⌘F in safari): w45 is in view for Arbor but the window server does not show it
- ~ **30 safari-107-in** (presses ⌃⌘F in safari): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **33 safari-108-in** (presses ⌃⌘F in safari): w31 is in view for Arbor but the window server does not show it
- ~ **33 safari-108-in** (presses ⌃⌘F in safari): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **33 safari-108-in** (presses ⌃⌘F in safari): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **33 safari-108-in** (presses ⌃⌘F in safari): w45 is in view for Arbor but the window server does not show it
- ~ **33 safari-108-in** (presses ⌃⌘F in safari): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **36 textedit-109-in** (presses ⌃⌘F in textedit): w31 is in view for Arbor but the window server does not show it
- ~ **36 textedit-109-in** (presses ⌃⌘F in textedit): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **36 textedit-109-in** (presses ⌃⌘F in textedit): w35 is in view for Arbor but the window server does not show it
- ~ **36 textedit-109-in** (presses ⌃⌘F in textedit): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **36 textedit-109-in** (presses ⌃⌘F in textedit): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **37 textedit-109-arbor-out** (presses ⌃⌘F again): w31 is in view for Arbor but the window server does not show it
- ~ **37 textedit-109-arbor-out** (presses ⌃⌘F again): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **37 textedit-109-arbor-out** (presses ⌃⌘F again): w35 is in view for Arbor but the window server does not show it
- ~ **37 textedit-109-arbor-out** (presses ⌃⌘F again): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **37 textedit-109-arbor-out** (presses ⌃⌘F again): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **38 reach-safari-110** (clicks safari's title bar, or its Dock icon if that is covered): w31 is in view for Arbor but the window server does not show it
- ~ **38 reach-safari-110** (clicks safari's title bar, or its Dock icon if that is covered): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **38 reach-safari-110** (clicks safari's title bar, or its Dock icon if that is covered): w35 is in view for Arbor but the window server does not show it
- ~ **38 reach-safari-110** (clicks safari's title bar, or its Dock icon if that is covered): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **38 reach-safari-110** (clicks safari's title bar, or its Dock icon if that is covered): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **41 safari-111-in** (presses ⌃⌘F in safari): w31 is in view for Arbor but the window server does not show it
- ~ **41 safari-111-in** (presses ⌃⌘F in safari): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **41 safari-111-in** (presses ⌃⌘F in safari): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **41 safari-111-in** (presses ⌃⌘F in safari): w45 is in view for Arbor but the window server does not show it
- ~ **41 safari-111-in** (presses ⌃⌘F in safari): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **44 textedit-112-in** (presses ⌃⌘F in textedit): w31 is in view for Arbor but the window server does not show it
- ~ **44 textedit-112-in** (presses ⌃⌘F in textedit): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **44 textedit-112-in** (presses ⌃⌘F in textedit): w35 is in view for Arbor but the window server does not show it
- ~ **44 textedit-112-in** (presses ⌃⌘F in textedit): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **44 textedit-112-in** (presses ⌃⌘F in textedit): w45 is docked and not parked, but has neither a slot nor a tile

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### The apps are open

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (1, 0 ms) | quiet 631 ms; blind for 269 ms |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 0 ms; blind for 785 ms |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (1, 0 ms) | quiet 1680 ms; blind for 1238 ms |  |  |  |  |  |  |

### With Arbor

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 4 | launch | starts Arbor | w52 ×1 (3, 81 ms) | quiet 1029 ms; blind for 136 ms |  |  |  |  |  |  |
| 5 | reach-finder-100 | clicks finder's title bar, or its Dock icon if that is covered |  | quiet 415 ms; blind for 107 ms |  |  |  |  |  |  |
| 6 | dock-finder-left | presses ⌃⌥⌘← | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 76 ms |  |  |  |  |  | ~ |
| 7 | reach-safari-100 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 441 ms; blind for 85 ms |  |  |  |  |  |  |
| 8 | dock-safari-right | presses ⌃⌥⌘→ | finder ×1 (1, 0 ms), safari ×1 (3, 37 ms), textedit ×1 (1, 0 ms) | quiet 1119 ms; blind for 73 ms |  |  |  |  |  |  |
| 9 | reach-textedit-100 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 345 ms; blind for 72 ms |  |  |  |  |  |  |
| 10 | dock-textedit-right | presses ⌃⌥⌘→ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 14 ms) | quiet 776 ms; blind for 65 ms |  |  |  |  |  |  |

### With Arbor: safari, round 101

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 11 | reach-safari-101 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 403 ms; blind for 79 ms |  |  |  |  |  |  |
| 12 | safari-101-in | presses ⌃⌘F in safari | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 47 ms) | quiet 0 ms; blind for 133 ms |  |  |  |  |  | ~ |
| 13 | safari-101-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 80 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: safari, round 102

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 14 | reach-safari-102 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 391 ms; blind for 78 ms |  |  |  |  |  |  |
| 15 | safari-102-in | presses ⌃⌘F in safari | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 66 ms) | quiet 0 ms; blind for 73 ms |  |  |  |  |  | ~ |
| 16 | safari-102-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 82 ms) | quiet 0 ms; blind for 78 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: textedit, round 103

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 17 | reach-textedit-103 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 354 ms; blind for 72 ms |  |  |  |  |  |  |
| 18 | textedit-103-in | presses ⌃⌘F in textedit | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 72 ms |  |  |  |  |  | ~ |
| 19 | textedit-103-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 80 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: safari, round 104

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 20 | reach-safari-104 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 329 ms; blind for 63 ms |  |  |  |  |  |  |
| 21 | safari-104-in | presses ⌃⌘F in safari | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 21 ms) | quiet 0 ms; blind for 83 ms |  |  |  |  |  | ~ |
| 22 | safari-104-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 74 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: safari, round 105

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 23 | reach-safari-105 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 335 ms; blind for 74 ms |  |  |  |  |  |  |
| 24 | safari-105-in | presses ⌃⌘F in safari | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 79 ms |  |  |  |  |  | ~ |
| 25 | safari-105-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 29 ms) | quiet 0 ms; blind for 99 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: textedit, round 106

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 26 | reach-textedit-106 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 305 ms; blind for 183 ms |  |  |  |  |  |  |
| 27 | textedit-106-in | presses ⌃⌘F in textedit | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 87 ms |  |  |  |  |  | ~ |
| 28 | textedit-106-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 139 ms |  | ✔ | ~ |  | ✔ | ✔ |

### With Arbor: safari, round 107

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 29 | reach-safari-107 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 359 ms; blind for 76 ms |  |  |  |  |  |  |
| 30 | safari-107-in | presses ⌃⌘F in safari | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 79 ms |  |  |  |  |  | ~ |
| 31 | safari-107-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 75 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: safari, round 108

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 32 | reach-safari-108 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 305 ms; blind for 72 ms |  |  |  |  |  |  |
| 33 | safari-108-in | presses ⌃⌘F in safari | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 17 ms) | quiet 0 ms; blind for 81 ms |  |  |  |  |  | ~ |
| 34 | safari-108-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 71 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: textedit, round 109

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 35 | reach-textedit-109 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 402 ms; blind for 118 ms |  |  |  |  |  |  |
| 36 | textedit-109-in | presses ⌃⌘F in textedit | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 79 ms |  |  |  |  |  | ~ |
| 37 | textedit-109-arbor-out | presses ⌃⌘F again |  | quiet 0 ms; blind for 78 ms |  | ✔ | ✘ |  | ✔ | ~ |

### With Arbor: safari, round 110

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 38 | reach-safari-110 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 389 ms; blind for 75 ms |  |  |  |  |  | ~ |
| 39 | safari-110-in | presses ⌃⌘F in safari | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 118 ms |  |  |  |  |  |  |

### With Arbor: safari, round 111

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 40 | reach-safari-111 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 350 ms; blind for 171 ms |  |  |  |  |  |  |
| 41 | safari-111-in | presses ⌃⌘F in safari | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 85 ms |  |  |  |  |  | ~ |
| 42 | safari-111-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 86 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: textedit, round 112

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 43 | reach-textedit-112 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 392 ms; blind for 86 ms |  |  |  |  |  |  |
| 44 | textedit-112-in | presses ⌃⌘F in textedit | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 80 ms |  |  |  |  |  | ~ |
| 45 | textedit-112-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 88 ms |  | ✔ | ✔ |  | ✔ | ✔ |
| 46 | quit | quits Arbor | finder ×1 (2, 29 ms), safari ×1 (2, 47 ms), textedit ×1 (1, 0 ms) | quiet 1081 ms; blind for 75 ms |  |  |  |  |  |  |
