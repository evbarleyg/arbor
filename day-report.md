40 steps in 132 s, 9 of them judged, 0 with a rule broken. The sampler: samples 4801 seconds 138.8 hz 34.6 cost-ms 3.68 late 1343 longest-gap-ms 1100.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 2 | nothing moves that the person did not move | 0 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 9 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 8 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| L | no window is lost or stuck | 9 | 0 |  |
| - | what the script itself checked | 9 | 0 |  |

## Findings

### Rule -: what the script itself checked

- ~ **6 dock-finder-left** (presses ⌃⌥⌘←): took more than a second longer to agree with the screen: w31 is at 340,120 920×436 but Arbor believes 12,43 782×767
- ~ **12 safari-101-in** (presses ⌃⌘F in safari): w31 is in view for Arbor but the window server does not show it
- ~ **12 safari-101-in** (presses ⌃⌘F in safari): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **12 safari-101-in** (presses ⌃⌘F in safari): w34 is docked and not parked, but has neither a slot nor a tile
- ~ **12 safari-101-in** (presses ⌃⌘F in safari): w45 is in view for Arbor but the window server does not show it
- ~ **12 safari-101-in** (presses ⌃⌘F in safari): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **15 safari-102-in** (presses ⌃⌘F in safari): w31 is in view for Arbor but the window server does not show it
- ~ **15 safari-102-in** (presses ⌃⌘F in safari): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **15 safari-102-in** (presses ⌃⌘F in safari): w34 is docked and not parked, but has neither a slot nor a tile
- ~ **15 safari-102-in** (presses ⌃⌘F in safari): w45 is in view for Arbor but the window server does not show it
- ~ **15 safari-102-in** (presses ⌃⌘F in safari): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **18 textedit-103-in** (presses ⌃⌘F in textedit): w31 is in view for Arbor but the window server does not show it
- ~ **18 textedit-103-in** (presses ⌃⌘F in textedit): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **18 textedit-103-in** (presses ⌃⌘F in textedit): w34 is in view for Arbor but the window server does not show it
- ~ **18 textedit-103-in** (presses ⌃⌘F in textedit): w34 is docked and not parked, but has neither a slot nor a tile
- ~ **18 textedit-103-in** (presses ⌃⌘F in textedit): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **21 safari-104-in** (presses ⌃⌘F in safari): w31 is in view for Arbor but the window server does not show it
- ~ **21 safari-104-in** (presses ⌃⌘F in safari): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **21 safari-104-in** (presses ⌃⌘F in safari): w34 is docked and not parked, but has neither a slot nor a tile
- ~ **21 safari-104-in** (presses ⌃⌘F in safari): w45 is in view for Arbor but the window server does not show it
- ~ **21 safari-104-in** (presses ⌃⌘F in safari): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **24 safari-105-in** (presses ⌃⌘F in safari): w31 is in view for Arbor but the window server does not show it
- ~ **24 safari-105-in** (presses ⌃⌘F in safari): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **24 safari-105-in** (presses ⌃⌘F in safari): w34 is docked and not parked, but has neither a slot nor a tile
- ~ **24 safari-105-in** (presses ⌃⌘F in safari): w45 is in view for Arbor but the window server does not show it
- ~ **24 safari-105-in** (presses ⌃⌘F in safari): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **27 textedit-106-in** (presses ⌃⌘F in textedit): w31 is in view for Arbor but the window server does not show it
- ~ **27 textedit-106-in** (presses ⌃⌘F in textedit): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **27 textedit-106-in** (presses ⌃⌘F in textedit): w34 is in view for Arbor but the window server does not show it
- ~ **27 textedit-106-in** (presses ⌃⌘F in textedit): w34 is docked and not parked, but has neither a slot nor a tile
- ~ **27 textedit-106-in** (presses ⌃⌘F in textedit): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **30 safari-107-in** (presses ⌃⌘F in safari): w31 is in view for Arbor but the window server does not show it
- ~ **30 safari-107-in** (presses ⌃⌘F in safari): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **30 safari-107-in** (presses ⌃⌘F in safari): w34 is docked and not parked, but has neither a slot nor a tile
- ~ **30 safari-107-in** (presses ⌃⌘F in safari): w45 is in view for Arbor but the window server does not show it
- ~ **30 safari-107-in** (presses ⌃⌘F in safari): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **33 safari-108-in** (presses ⌃⌘F in safari): w31 is in view for Arbor but the window server does not show it
- ~ **33 safari-108-in** (presses ⌃⌘F in safari): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **33 safari-108-in** (presses ⌃⌘F in safari): w34 is docked and not parked, but has neither a slot nor a tile
- ~ **33 safari-108-in** (presses ⌃⌘F in safari): w45 is in view for Arbor but the window server does not show it
- ~ **33 safari-108-in** (presses ⌃⌘F in safari): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **36 safari-200-in** (presses ⌃⌘F in safari): w31 is in view for Arbor but the window server does not show it
- ~ **36 safari-200-in** (presses ⌃⌘F in safari): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **36 safari-200-in** (presses ⌃⌘F in safari): w34 is docked and not parked, but has neither a slot nor a tile
- ~ **36 safari-200-in** (presses ⌃⌘F in safari): w45 is in view for Arbor but the window server does not show it
- ~ **36 safari-200-in** (presses ⌃⌘F in safari): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **37 back-to-the-desktop** (presses ⌃←: the desktop comes back without Safari): w34 is in view for Arbor but the window server does not show it
- ~ **37 back-to-the-desktop** (presses ⌃←: the desktop comes back without Safari): w34 is docked and not parked, but has neither a slot nor a tile
- ~ **38 forth-to-safari** (presses ⌃→): w31 is in view for Arbor but the window server does not show it
- ~ **38 forth-to-safari** (presses ⌃→): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **38 forth-to-safari** (presses ⌃→): w34 is docked and not parked, but has neither a slot nor a tile
- ~ **38 forth-to-safari** (presses ⌃→): w45 is in view for Arbor but the window server does not show it
- ~ **38 forth-to-safari** (presses ⌃→): w45 is docked and not parked, but has neither a slot nor a tile

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### The apps are open

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder |  | quiet 546 ms; blind for 189 ms |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 0 ms; blind for 1025 ms |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | textedit ×1 (2, 212 ms) | quiet 885 ms; blind for 1100 ms |  |  |  |  |  |  |

### With Arbor

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 4 | launch | starts Arbor | w52 ×1 (1, 0 ms) | quiet 1074 ms; blind for 136 ms |  |  |  |  |  |  |
| 5 | reach-finder-100 | clicks finder's title bar, or its Dock icon if that is covered |  | quiet 346 ms; blind for 94 ms |  |  |  |  |  |  |
| 6 | dock-finder-left | presses ⌃⌥⌘← | finder ×1 (2, 6 ms), safari ×1 (2, 6 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 134 ms |  |  |  |  |  | ~ |
| 7 | reach-safari-100 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 424 ms; blind for 101 ms |  |  |  |  |  |  |
| 8 | dock-safari-right | presses ⌃⌥⌘→ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 11 ms) | quiet 1027 ms; blind for 95 ms |  |  |  |  |  |  |
| 9 | reach-textedit-100 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 239 ms; blind for 111 ms |  |  |  |  |  |  |
| 10 | dock-textedit-right | presses ⌃⌥⌘→ | finder ×1 (1, 0 ms), safari ×1 (2, 34 ms), textedit ×1 (2, 28 ms) | quiet 875 ms; blind for 67 ms |  |  |  |  |  |  |

### With Arbor: safari, round 101

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 11 | reach-safari-101 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 388 ms; blind for 89 ms |  |  |  |  |  |  |
| 12 | safari-101-in | presses ⌃⌘F in safari | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 209 ms |  |  |  |  |  | ~ |
| 13 | safari-101-arbor-out | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 98 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: safari, round 102

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 14 | reach-safari-102 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 381 ms; blind for 71 ms |  |  |  |  |  |  |
| 15 | safari-102-in | presses ⌃⌘F in safari | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 79 ms |  |  |  |  |  | ~ |
| 16 | safari-102-arbor-out | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 76 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: textedit, round 103

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 17 | reach-textedit-103 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 403 ms; blind for 96 ms |  |  |  |  |  |  |
| 18 | textedit-103-in | presses ⌃⌘F in textedit | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 77 ms |  |  |  |  |  | ~ |
| 19 | textedit-103-arbor-out | presses ⌃⌘F again | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 82 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: safari, round 104

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 20 | reach-safari-104 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 345 ms; blind for 92 ms |  |  |  |  |  |  |
| 21 | safari-104-in | presses ⌃⌘F in safari | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 69 ms |  |  |  |  |  | ~ |
| 22 | safari-104-arbor-out | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 76 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: safari, round 105

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 23 | reach-safari-105 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 427 ms; blind for 67 ms |  |  |  |  |  |  |
| 24 | safari-105-in | presses ⌃⌘F in safari | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 124 ms |  |  |  |  |  | ~ |
| 25 | safari-105-arbor-out | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 78 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: textedit, round 106

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 26 | reach-textedit-106 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 363 ms; blind for 102 ms |  |  |  |  |  |  |
| 27 | textedit-106-in | presses ⌃⌘F in textedit | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 94 ms |  |  |  |  |  | ~ |
| 28 | textedit-106-arbor-out | presses ⌃⌘F again | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 77 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: safari, round 107

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 29 | reach-safari-107 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 306 ms; blind for 119 ms |  |  |  |  |  |  |
| 30 | safari-107-in | presses ⌃⌘F in safari | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 69 ms |  |  |  |  |  | ~ |
| 31 | safari-107-arbor-out | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 76 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: safari, round 108

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 32 | reach-safari-108 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 436 ms; blind for 70 ms |  |  |  |  |  |  |
| 33 | safari-108-in | presses ⌃⌘F in safari | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 78 ms |  |  |  |  |  | ~ |
| 34 | safari-108-arbor-out | presses ⌃⌘F again | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 76 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: back to the desktop while Safari stays in full screen

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 35 | reach-safari-200 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 300 ms; blind for 60 ms |  |  |  |  |  |  |
| 36 | safari-200-in | presses ⌃⌘F in safari | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 78 ms |  |  |  |  |  | ~ |
| 37 | back-to-the-desktop | presses ⌃←: the desktop comes back without Safari | finder ×1 (1, 0 ms), textedit ×1 (2, 72 ms) | quiet 0 ms; blind for 89 ms |  |  |  |  |  | ~ |
| 38 | forth-to-safari | presses ⌃→ |  | quiet 0 ms; blind for 171 ms |  |  |  |  |  | ~ |
| 39 | safari-200-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 36 ms) | quiet 0 ms; blind for 78 ms |  | ✔ |  |  | ✔ | ✔ |
| 40 | quit | quits Arbor | finder ×1 (1, 0 ms), safari ×1 (2, 102 ms), textedit ×1 (1, 0 ms) | quiet 1004 ms; blind for 80 ms |  |  |  |  |  |  |
