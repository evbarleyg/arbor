53 steps in 198 s, 14 of them judged, 0 with a rule broken. The sampler: samples 7646 seconds 211.7 hz 36.1 cost-ms 3.07 late 2051 longest-gap-ms 1439.

## Per rule

| Rule | | Steps that checked it | Steps that broke it | Which |
|---|---|---|---|---|
| 2 | nothing moves that the person did not move | 0 | 0 |  |
| 3 | no jolts: a window moves once, to where it ends up | 14 | 0 |  |
| 4 | the window you switch to comes to the front and into view | 8 | 0 |  |
| 5 | quitting, Float All and pause give windows their own sizes back | 0 | 0 |  |
| L | no window is lost or stuck | 14 | 0 |  |
| - | what the script itself checked | 14 | 0 |  |

## Findings

### Rule -: what the script itself checked

- ~ **24 dock-finder-left** (presses ⌃⌥⌘←): took more than a second longer to agree with the screen: w31 is at 340,120 920×436 but Arbor believes 12,43 782×767
- ~ **30 safari-101-in** (presses ⌃⌘F in safari): w31 is in view for Arbor but the window server does not show it
- ~ **30 safari-101-in** (presses ⌃⌘F in safari): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **30 safari-101-in** (presses ⌃⌘F in safari): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **30 safari-101-in** (presses ⌃⌘F in safari): w45 is in view for Arbor but the window server does not show it
- ~ **30 safari-101-in** (presses ⌃⌘F in safari): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **33 textedit-102-in** (presses ⌃⌘F in textedit): w31 is in view for Arbor but the window server does not show it
- ~ **33 textedit-102-in** (presses ⌃⌘F in textedit): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **33 textedit-102-in** (presses ⌃⌘F in textedit): w35 is in view for Arbor but the window server does not show it
- ~ **33 textedit-102-in** (presses ⌃⌘F in textedit): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **33 textedit-102-in** (presses ⌃⌘F in textedit): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **36 safari-103-in** (presses ⌃⌘F in safari): w31 is in view for Arbor but the window server does not show it
- ~ **36 safari-103-in** (presses ⌃⌘F in safari): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **36 safari-103-in** (presses ⌃⌘F in safari): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **36 safari-103-in** (presses ⌃⌘F in safari): w45 is in view for Arbor but the window server does not show it
- ~ **36 safari-103-in** (presses ⌃⌘F in safari): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **39 textedit-104-in** (presses ⌃⌘F in textedit): w31 is in view for Arbor but the window server does not show it
- ~ **39 textedit-104-in** (presses ⌃⌘F in textedit): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **39 textedit-104-in** (presses ⌃⌘F in textedit): w35 is in view for Arbor but the window server does not show it
- ~ **39 textedit-104-in** (presses ⌃⌘F in textedit): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **39 textedit-104-in** (presses ⌃⌘F in textedit): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **42 safari-105-in** (presses ⌃⌘F in safari): w31 is in view for Arbor but the window server does not show it
- ~ **42 safari-105-in** (presses ⌃⌘F in safari): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **42 safari-105-in** (presses ⌃⌘F in safari): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **42 safari-105-in** (presses ⌃⌘F in safari): w45 is in view for Arbor but the window server does not show it
- ~ **42 safari-105-in** (presses ⌃⌘F in safari): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **45 textedit-106-in** (presses ⌃⌘F in textedit): w31 is in view for Arbor but the window server does not show it
- ~ **45 textedit-106-in** (presses ⌃⌘F in textedit): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **45 textedit-106-in** (presses ⌃⌘F in textedit): w35 is in view for Arbor but the window server does not show it
- ~ **45 textedit-106-in** (presses ⌃⌘F in textedit): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **45 textedit-106-in** (presses ⌃⌘F in textedit): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **48 safari-107-in** (presses ⌃⌘F in safari): w31 is in view for Arbor but the window server does not show it
- ~ **48 safari-107-in** (presses ⌃⌘F in safari): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **48 safari-107-in** (presses ⌃⌘F in safari): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **48 safari-107-in** (presses ⌃⌘F in safari): w45 is in view for Arbor but the window server does not show it
- ~ **48 safari-107-in** (presses ⌃⌘F in safari): w45 is docked and not parked, but has neither a slot nor a tile
- ~ **51 textedit-108-in** (presses ⌃⌘F in textedit): w31 is in view for Arbor but the window server does not show it
- ~ **51 textedit-108-in** (presses ⌃⌘F in textedit): w31 is docked and not parked, but has neither a slot nor a tile
- ~ **51 textedit-108-in** (presses ⌃⌘F in textedit): w35 is in view for Arbor but the window server does not show it
- ~ **51 textedit-108-in** (presses ⌃⌘F in textedit): w35 is docked and not parked, but has neither a slot nor a tile
- ~ **51 textedit-108-in** (presses ⌃⌘F in textedit): w45 is docked and not parked, but has neither a slot nor a tile

## Every step

Moved: window × how many times (frames seen on the way, milliseconds from the first to the last).

### The apps are open

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | open-finder | opens finder | finder ×1 (2, 88 ms) | quiet 785 ms; blind for 189 ms |  |  |  |  |  |  |
| 2 | open-safari | opens safari |  | quiet 0 ms; blind for 1256 ms |  |  |  |  |  |  |
| 3 | open-textedit | opens textedit | safari ×1 (1, 0 ms), textedit ×1 (2, 181 ms) | quiet 1742 ms; blind for 1439 ms |  |  |  |  |  |  |

### Without Arbor: asked at one moment per round

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 4 | reach-safari-1 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 363 ms; blind for 108 ms |  |  |  |  |  |  |
| 5 | safari-1-in | presses ⌃⌘F in safari | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 172 ms |  |  |  |  |  |  |
| 6 | safari-1-insist-out | presses ⌃⌘F again; the window is asked for its slot: insist | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 121 ms |  | ✔ |  |  | ✔ | ✔ |
| 7 | reach-safari-2 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 329 ms; blind for 76 ms |  |  |  |  |  |  |
| 8 | safari-2-in | presses ⌃⌘F in safari | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 85 ms |  |  |  |  |  |  |
| 9 | safari-2-insist-out | presses ⌃⌘F again; the window is asked for its slot: insist | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 131 ms |  | ✔ |  |  | ✔ | ✔ |
| 10 | reach-safari-3 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 242 ms; blind for 75 ms |  |  |  |  |  |  |
| 11 | safari-3-in | presses ⌃⌘F in safari | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 73 ms |  |  |  |  |  |  |
| 12 | safari-3-insist-out | presses ⌃⌘F again; the window is asked for its slot: insist | safari ×1 (1, 0 ms) | quiet 0 ms; blind for 141 ms |  | ✔ |  |  | ✔ | ✔ |
| 13 | reach-textedit-4 | clicks textedit's title bar, or its Dock icon if that is covered | textedit ×1 (1, 0 ms) | quiet 397 ms; blind for 93 ms |  |  |  |  |  |  |
| 14 | textedit-4-in | presses ⌃⌘F in textedit | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 96 ms |  |  |  |  |  |  |
| 15 | textedit-4-insist-out | presses ⌃⌘F again; the window is asked for its slot: insist | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 114 ms |  | ✔ |  |  | ✔ | ✔ |
| 16 | reach-textedit-5 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 254 ms; blind for 77 ms |  |  |  |  |  |  |
| 17 | textedit-5-in | presses ⌃⌘F in textedit | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 124 ms |  |  |  |  |  |  |
| 18 | textedit-5-insist-out | presses ⌃⌘F again; the window is asked for its slot: insist | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 160 ms |  | ✔ |  |  | ✔ | ✔ |
| 19 | reach-textedit-6 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 358 ms; blind for 78 ms |  |  |  |  |  |  |
| 20 | textedit-6-in | presses ⌃⌘F in textedit | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 151 ms |  |  |  |  |  |  |
| 21 | textedit-6-insist-out | presses ⌃⌘F again; the window is asked for its slot: insist | textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 158 ms |  | ✔ |  |  | ✔ | ✔ |

### With Arbor

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 22 | launch | starts Arbor | w205 ×1 (3, 30 ms) | quiet 993 ms; blind for 74 ms |  |  |  |  |  |  |
| 23 | reach-finder-100 | clicks finder's title bar, or its Dock icon if that is covered |  | quiet 351 ms; blind for 214 ms |  |  |  |  |  |  |
| 24 | dock-finder-left | presses ⌃⌥⌘← | finder ×1 (3, 62 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 88 ms |  |  |  |  |  | ~ |
| 25 | reach-safari-100 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 502 ms; blind for 99 ms |  |  |  |  |  |  |
| 26 | dock-safari-right | presses ⌃⌥⌘→ | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 911 ms; blind for 77 ms |  |  |  |  |  |  |
| 27 | reach-textedit-100 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 283 ms; blind for 152 ms |  |  |  |  |  |  |
| 28 | dock-textedit-right | presses ⌃⌥⌘→ | finder ×1 (1, 0 ms), safari ×1 (2, 41 ms), textedit ×1 (3, 104 ms) | quiet 760 ms; blind for 67 ms |  |  |  |  |  |  |

### With Arbor: safari, round 101

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 29 | reach-safari-101 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 382 ms; blind for 128 ms |  |  |  |  |  |  |
| 30 | safari-101-in | presses ⌃⌘F in safari | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 47 ms) | quiet 0 ms; blind for 101 ms |  |  |  |  |  | ~ |
| 31 | safari-101-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (2, 50 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 76 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: textedit, round 102

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 32 | reach-textedit-102 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 287 ms; blind for 108 ms |  |  |  |  |  |  |
| 33 | textedit-102-in | presses ⌃⌘F in textedit | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 94 ms |  |  |  |  |  | ~ |
| 34 | textedit-102-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 116 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: safari, round 103

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 35 | reach-safari-103 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 397 ms; blind for 151 ms |  |  |  |  |  |  |
| 36 | safari-103-in | presses ⌃⌘F in safari | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 18 ms) | quiet 0 ms; blind for 81 ms |  |  |  |  |  | ~ |
| 37 | safari-103-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 80 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: textedit, round 104

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 38 | reach-textedit-104 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 263 ms; blind for 255 ms |  |  |  |  |  |  |
| 39 | textedit-104-in | presses ⌃⌘F in textedit | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 77 ms |  |  |  |  |  | ~ |
| 40 | textedit-104-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 126 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: safari, round 105

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 41 | reach-safari-105 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 282 ms; blind for 84 ms |  |  |  |  |  |  |
| 42 | safari-105-in | presses ⌃⌘F in safari | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 14 ms) | quiet 0 ms; blind for 94 ms |  |  |  |  |  | ~ |
| 43 | safari-105-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (2, 199 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 164 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: textedit, round 106

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 44 | reach-textedit-106 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 243 ms; blind for 183 ms |  |  |  |  |  |  |
| 45 | textedit-106-in | presses ⌃⌘F in textedit | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 280 ms |  |  |  |  |  | ~ |
| 46 | textedit-106-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 140 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: safari, round 107

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 47 | reach-safari-107 | clicks safari's title bar, or its Dock icon if that is covered |  | quiet 384 ms; blind for 167 ms |  |  |  |  |  |  |
| 48 | safari-107-in | presses ⌃⌘F in safari | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 119 ms |  |  |  |  |  | ~ |
| 49 | safari-107-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (2, 125 ms), textedit ×1 (2, 14 ms) | quiet 0 ms; blind for 167 ms |  | ✔ | ✔ |  | ✔ | ✔ |

### With Arbor: textedit, round 108

| # | Step | The person | Moved | Quiet after | 2 | 3 | 4 | 5 | L | – |
|---|---|---|---|---|---|---|---|---|---|---|
| 50 | reach-textedit-108 | clicks textedit's title bar, or its Dock icon if that is covered |  | quiet 319 ms; blind for 266 ms |  |  |  |  |  |  |
| 51 | textedit-108-in | presses ⌃⌘F in textedit | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 95 ms |  |  |  |  |  | ~ |
| 52 | textedit-108-arbor-out | presses ⌃⌘F again | finder ×1 (1, 0 ms), safari ×1 (1, 0 ms), textedit ×1 (1, 0 ms) | quiet 0 ms; blind for 89 ms |  | ✔ | ✔ |  | ✔ | ✔ |
| 53 | quit | quits Arbor | finder ×1 (2, 29 ms), safari ×1 (1, 0 ms), textedit ×1 (2, 55 ms) | quiet 1043 ms; blind for 80 ms |  |  |  |  |  |  |
