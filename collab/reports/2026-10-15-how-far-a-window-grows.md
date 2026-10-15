# Report: how far macOS lets a window grow or go

- Date: 2026-10-15
- What: the rule behind the short window, read off traces (part 1), asked of macOS call by call (part 2), asked while a hand holds the window (part 3), and what has been seen since with Arbor running (part 4)
- Scripts: `scripts/mac-shell/probe-how-far-a-window-grows.sh`, `scripts/mac-shell/probe-a-size-call-in-the-hand.sh`, `scripts/mac-shell/probe-when-the-display-turns.sh` (written, not played yet), all three with `scripts/mac-shell/grow.swift`
- Lines: `collab/evidence/how-far-a-window-grows/` (its README says what is what)
- Readers: `scripts/reality-clip.py`, `scripts/reality-clip-any-display.py`, `scripts/reality-slots.py`, `scripts/mac-shell/grow-table.py`, `scripts/mac-shell/grow-hand.py`
- The ledger's cases: docs/REALITY.md, from `a-window-asked-to-grow-stops-at-the-dock` on; each names this page

Everything here is from hosted Macs, macOS 26.6.2, scale 1, with posted events for a hand. The three parts were written one after the other in one night, each by whoever had read the lines, and are kept as they were written but for
the names of files: **where a later part corrects an earlier one it says so, and the later part holds.** Part 1's "an edge already past its line is free" is narrowed by part 2's rule 4; part 1's and part 2's "x is free" and "pulled back until 40 points show" are
narrowed by part 4 (which edge the 40 points are counted from).

**In short.** A size call that makes a window grow is cut at the edge of the display the window is on: at the display's right edge and bottom, and where the Dock is, a point short of the visible frame's edge on that side. It is judged where the window
stands when the call arrives, each edge by itself, and growth only. A position call is held back elsewhere: between the menu bar and the visible bottom less the title bar, and so that 40 points stay in the visible frame; and it cuts the height of a window that is taller than the display it is sent to. For some
milliseconds after a position call has changed the display, a size call is still judged by the display the window came from. Real apps are cut like test windows. In a hand all of it holds as at rest.

## Part 1. The rule, read off the traces of Arbor at work

Read off 182 `setFrame` calls of run 38685233668 (hosted Mac, macOS 26.6.2, one display 1024×768, visible 0,31 1024×674, so the Dock's top is at 705;
Arbor at trunk 848da3f7) and 313 of two older runs (Arbor at a391fe4). "commands 26" is line 26 of `commands.jsonl` of the new run
(`collab/evidence/how-far-a-window-grows/first-catch/traces/`); "old" is a run of 2026-10-14, the recording that was committed before and has since been replaced.
All windows are the AppKit test windows. `scripts/reality-clip.py` prints every case from any folder of traces.

One `setFrame` of Arbor's is up to three calls on the Mac (`FramePlan`): size, position, size; only position when the size is believed right.

1. **A size call that makes a window GROW stops where its bottom edge comes to the visible frame's bottom less 1, and its right edge to the display's
   right edge.** The origin stays. Bottom 704 with the visible bottom at 705, 23 answers out of 23 (all of them in that script's output): commands 26 (170,220 494×650 → 494×484), 81, 82, 498
   (12,374 1000×650 → 1000×330); apps 28, 84, 85, 320, 426; keys 28, 71, 72, 148, 459; pointer 198, 355, 553. Right edge 1024, no "less 1": apps 136
   (687,106 494×650 → 337×600), apps 161 (596,69 → 428 wide).
2. **What decides is where the window IS when the size call arrives, not whether `setFrame` names a new origin.** With a new origin the last size
   call comes at the new place and decides. New origin, would pass, clipped: pointer 688 (297,194 274×650 → ×510), 700 (296,113 → ×591), 719
   (295,73 → ×631); apps 427 and keys 189 (12,56 325×650 → ×648). New origin, fits, whole: pointer 731 (294,53 277×650, bottom 703) and every move
   into a slot of the old way, e.g. old commands 24 (stood 170,220 480×348; asked and took 12,43 494×650, bottom 693). That is why nothing showed
   before windows were asked where they stand: the first size call was clipped then too, and the third made it good.
3. **It only holds growth back: it never shrinks a window, it holds no edge that is past the line already, and it does not apply to position calls.**
   Already at the line, height stays: pointer 552 (stood 249,356 446×348, bottom 704; asked 273×650, took 273×348). Parked (1023,677, both edges
   past): asked 1000×650 where it stands and took all of it, apps 536, pointer 1206. So a window that comes back from where it is parked gets the whole size
   there and keeps it wherever it is put: commands 221 and keys 191 (stood 1023,677 325×524; asked and took 687,106 325×650: bottom 756, 51 points
   behind the Dock, until Arbor's second move, commands 222). Moved after it was clipped, not clipped again: apps 161 (638 high from y 68, then put at 69: bottom 707).
4. **704, 705, 706: it is the Dock as it is at that moment, less 1, whatever Arbor has been told.** Visible bottom 705: always 704. A window went into
   the Dock, which became 2 points lower: apps 136 is clipped at 706 at t 6.24, while Arbor's last reading (apps 134) still said 705 and the news of 707 came at t 6.57
   (apps 157). Why "less 1" at the bottom and not at the right: not known. The visible frame is in whole points in every reading.
5. **What beats it, and the neighbouring rules.** The app's own minimum size beats it: old pointer 311 (asked 578,220 446×348, took 700×500: bottom 720, right
   1278). Position has a rule of its own: y is at most the visible bottom less the title bar's 28 points, x is free: 1023,767 → 1023,677, 20 times out of 20
   (commands 173, 174, 432…). Half points in a position are rounded down in AppKit's coordinates, so x goes down and y goes up: apps 137 (596.5,68 → 596,68),
   apps 321 (12,55.5 → 12,56), pointer 356, 701, 720.

**Not seen, so not known:** a window with one edge past the line and the other not; the Dock at a side; a second display; the menu bar's edge (nothing can grow upwards:
the origin stays); any app that is not AppKit's plain window, so whether AppKit or the window server does the clipping.

**What it does to Arbor at 848da3f7** (`Controller+AskFirst.swift`): the question "can you be as large as the slot?" is put where the window stands, the answer is
the room below the window and not the app's limit, and Arbor lays the window out at that size in the middle of its slot. It is asked again at every later layout, from higher up, so
it grows by steps: W1 of `keys` 484, 578, 625, 648, 650. Seen: the calls, the answers, and the frames the window server lists at rest. By reading and not by bisecting: that
98206418 brought it.

**For the stand-in:** `FakeWindowSystem.setFrame` takes any size anywhere. True would be: height at most max(the height it has, visible bottom − 1 − y), width at most
max(the width it has, display's right edge − x), both worked out at the place where the size call arrives (size, position, size), the minimum size winning over both.

## Part 2. Asked call by call, Arbor not running

Written 07:12 UTC 2026-10-15. Read off `collab/evidence/how-far-a-window-grows/grow.jsonl`: 844 calls, 466 results, every AXError 0. ONE hosted Mac, macOS 26.6.2 (25G83), run 38691152836, branch
`probe/how-far-a-window-grows` at 60b4dd7a, script `scripts/mac-shell/probe-how-far-a-window-grows.sh` with `scripts/mac-shell/grow.swift`: plain `AXUIElementSetAttributeValue` on AXSize and
AXPosition, the frame read back through Accessibility after each call, the window server's frame (CGWindowList) beside it, AXMoved and AXResized taken on a thread of their own.
"line 157" is line 157 of `grow.jsonl`. `scripts/mac-shell/grow-table.py` prints it: `grow-table.py grow.jsonl`, `--orders` (with the half-way frames), `--late`,
`--calls <name> [label]`. The scripts have gained rounds since that run (the corner where Arbor parks beside a second display; the browsers' quarantine mark), which have not been played.

**Varied:** the Dock at the bottom, at the left, hidden (at the bottom); the display 1024×768 alone and 1920×1080 with a virtual 800×600 display to its right, left and below; a test window and
ten of Apple's apps and one Java app; Reduce Motion on (the test window's rounds A to F) and off (the apps), TextEdit with both; the visible bottom 705, 708, 710, 711 (the Dock shrank as apps came and went).
**Not varied:** the Mac and the macOS; scale 1 everywhere (no Retina display); macOS's tiling settings as they come (keys not set); one Space; no Stage Manager; no full screen; windows of apps in the background;
the menu bar always shown; the Dock's size as it comes. Calls of a journey 1 to 10 ms apart, never further.

The four orders: **SPS** size, position, size (`FramePlan.full`, today's); **PS** position, size; **SP** size, position; **sPS** the smaller of both widths and of both heights, position, size.

### The three answers

1. **Does position-then-size give the whole slot in every circumstance seen?** On ONE display, yes: of 78 journeys made in both orders, 74 end to the point as SPS ends, and the other four are the exception:
   **EXCEPT INTO A FRAME THAT HANGS OVER AN EDGE.** D6, target 530,43 495×400 on a display 1024 wide (1426,43 495×400 on 1920), 1 point over the right edge: PS ends 494 wide, SPS whole, 4 of 4: lines 230 against 227 (Dock at the bottom), 409 against 406 (left), 501 against 498 (hidden), 1034 against 1031 (1920×1080). A window cannot grow into such a
   frame once it has been moved there; SPS sizes it where it stood, where there was room (rule 11). The mechanism has no limit in size; only 1 point, only the right edge and only a start with room were tried. Round K of `probe-when-the-display-turns.sh` asks the rest. Always 1 AXMoved + 1 AXResized (83 of 83), where SPS
   gives 1 + 2 in 52 of 83 (table below). Not
   BETWEEN displays: wrong in 5 journeys of 9 (SPS: 3 of 9). And no order reaches a slot that ends at the visible bottom while the Dock is at the bottom (rule 2).
2. **Is a large window clamped on its way to a smaller display?** Yes, in height, by the position call itself (rule 7): 5 calls of 5. Every order that shrinks first (SPS, SP, sPS) avoids it: 9 journeys of 9. `FramePlan.swift`'s comment is true.
   But the way BACK to the larger display ends short in ALL four orders, 12 of 12 (rule 8): that one nobody knew.
3. **Are real apps clipped like the test windows?** Yes: 10 apps of the 10 that could be judged, of 11 tried (rule 9). It is not the plain test window. Chromium, Gecko, Electron, Qt: not seen.

### The rules

1. **The control holds.** Four times in the run, between the other rounds (lines 5 to 9, 535 to 539, 920 to 924, 1195 to 1199), with the visible bottom at 705, 705, 710, 711: 170,vb−485 480×348 asked 494×650 took 494×484
   (bottom vb−1); parked at 1023,vb−28 asked 1000×650 took all; sent to 1023,767 went to 1023,vb−28. 12 of 12 as part 1 says.
2. **"Less 1" belongs to the Dock, not to the bottom.** With the Dock at the bottom of the window's display, growth stops at the visible bottom less 1: 17 answers of the 17 that were clipped by more than 8 points on the test window, 40 of 40 on apps that take any height (Terminal: 6 more, a cell
   short of it). So a slot that ends AT the visible bottom is 1 short in every order: D1 and D8, 1024×768 (lines 192, 195, 241, 244) and 1920×1080 (996, 999, 1045, 1048), 8 of 8; one that ends 1 above is whole (D2: 199, 202, 1003, 1006).
   **With the Dock at the left or hidden the visible bottom is the display's bottom, 768, and growth goes all the way to it:** 18 clipped answers of 18 end at 768; D1 and D8 whole (371, 374, 420, 423; 463, 466, 512, 515). The same on the display of two that has no Dock:
   F4 ends at 600 of 600 (943, 1074), F2 at 1080 of 1080 when the Dock had gone to the display below (1137), where F4 then ends at 1630 of a visible 1631 (1141).
3. **Each edge is judged by itself.** Right edge over the display's edge, bottom above the line: the width is free (C2 500, C4; lines 155, 159), the height is free up to the line (C1 500, line 153) and stops there (C3: 100+604 = 704, line 157). Bottom far
   past, right edge inside: the height is free (C8, C9; 167, 169), the width stops at 1024 (C7: 100+924, line 165). Hanging over the LEFT edge changes nothing: −200,100 grows to right edge 1024 and bottom 704 (C10 to C12; 171 to 175).
4. **An edge is free only when it is off the display; in the Dock's strip it is held as it is.** Part 1's "an edge already past its line is free" is too wide. Bottom at 704, 705, 706 (visible bottom 705): asked 100 more, kept its height, no report, all three
   (C15 to C17; 181, 183, 185). Calendar, whose least height put its bottom at 729 of a visible 711: asked 650, kept 503 (1365). Bottom at 900, 1201 (off the display, 768): free (C8, C9, C13, A2). Right edge at 1024: held (C14, 179); at 1025: free (C18, 187).
   **Not seen: a bottom between 730 and 899**, so whether 768 is where it turns.
5. **Position calls are held back too, only elsewhere.** y at least the menu bar's bottom: 0 and −50 → 31 (D12, D13; 8 of 8 in four circumstances). y at most the visible bottom less the height of the window's title bar: less 28 (test window, Java), 32 (TextEdit, Terminal), 52 (Finder, Safari, Preview,
   Script Editor, Activity Monitor, Console, Notes, Calendar, which have a toolbar): 26 of 26. **x is free only while some of the window is on a display: sent wholly off, it is pulled back until 40 points show:** 1524 → 984, −600 → −440 (480 wide; 256, 258; 527, 529), with the Dock
   at the left −600 → −390, which is 40 points past the Dock (435). 1023 stays 1023 (1 point shows: it is on the display). With a display to the right 2420 is simply there (1062).
6. **The Dock at the left holds nothing back.** Sent to x 0, 20, −100: taken (E1 to E3; 440 to 444). Under the Dock, wider and taller: taken (E4, E5; 446, 448; a picture of that run shows it, which is not in the tree). Growth to the right stops at 1024 as ever (427).
7. **A position call that takes a window to a display whose visible frame is lower than the window cuts its height to that visible height and puts y at the visible top; at once, in that call; the width is left alone.** 1000×650 sent to −788,43 → −788,31 1000×569; to −800,31 → 1000×569
   (display left; 1078, 1080); to 12,1123 → 12,1111 1000×520; to 0,1111 → 1000×520 (display below, with the Dock; 1145, 1147); 798×650 → 12,1111 798×520 (1152). 5 of 5; the reports are AXResized alone, no AXMoved. 1000 wide on a display of 800: stays. A window that fits (567 high into 569) is not touched (947, 949, 954, 1085).
   After it PS ends wrong: y 12 too high (1154). **To the right it was not tried with a window that is too tall**: the probe's own placing had left it at 567 (rule 8 did that).
8. **For some milliseconds after a position call has taken a window to another display, a size call is still judged by the display it came from.** From a slot on the 800×600 display to 12,43 1000×650 on the 1920×1080 one, last call always "size 1000×650" at 12,43: took 1000×557 with the small display right or
   left (bottom 600, the OLD display's bottom; 966, 969, 976; 1097, 1100, 1107) and 788×650 with it below (right edge 800, the OLD display's right edge; 1164, 1167, 1174). **All four orders end short, 12 of 12** (SP for the plain reason: its only size call is made on the small display). It stays so: the same at rest 350 ms later. Nothing in the reports tells.
   **Shrinking is held back as well then:** at −788,43, come from the main display, asked 776 wide, took 812: right edge 24, so 24 points stay on the display it came from (1086). The probe's own placing shows more of it (position to the large display, size, position, back to back): asked 300 wide, kept 800 (placed
   100,131 800×200; results 984 to 991); asked 200 high, kept 520 (1182 to 1189); asked 650 high at y 33, took 567 (bottom 600; 947 to 963).
   **200 ms later the new display judges, 4 sightings of 4:** the window stood at −300,220 on the left display, was put at 1420,81 on the main one, and between 200 and 283 ms later grew to 1920 and no further (1067; by the old display, whose right edge is 0, it would have been free). And F3 three times: come from the main display, put on the
   second, 200 ms or more later asked 700 wide, it took 300, to the SECOND display's right edge (941, 1072, 1139; the main display's edge would have let it, or was passed already).
   **Not seen: where between 6 and 200 ms it turns, and what tells (AXMoved does not: it comes within 1 to 4 ms).** The table of every such call is below.
9. **Real apps are clipped alike.** Taller than there is room (A1, D9, H6): bottom at the visible bottom less 1 in TextEdit, Finder, Safari, Java's jconsole, Preview, Script Editor, Activity Monitor, Console, Notes (and Terminal, whose cells happened to fit: 709 of 710); Calendar could not be judged (rule 4). Wider than the display (D10): right edge 1024
   in TextEdit, Finder, Safari, Java (587, 662, 812, 887); Terminal 1026: it rounds to cells after the clip (737). Parked, grows freely (A2), right edge over, width free and height to the line (C1 to C3): the five of round G. The app's own least size wins as before: Finder 501 wide, Safari 574, Preview 708, Notes 709, Activity Monitor 740×384, Calendar 680×503,
   Script Editor 413 high, Console 400 high.
10. **Half points.** Position: x down, y up, as known (529.5 → 529, 43.5 → 44). **Size: down**, 12 of the 12 where no line was near (494.5 → 494: D7 in four circumstances; 723.5 → 723: D4 with the Dock left and hidden); in D3, and in D4 with the Dock at the bottom, the line gives the same number. So a slot at y 43.5 that ends at the line loses 0.5 at the top and 0.5 or 1.5 at the bottom.
11. **A target that passes the line is reached by SPS and not by PS, when there was room where the window stood.** D6, right edge 1 past the display: SPS 495 wide, PS 494 (227, 230; 406, 409; 498, 501; 1031, 1034). Part 1's rule 3 again (sized where there is room, then moved, not clipped again). For slots inside the visible frame it never matters.
12. **With a neighbour, a window is clipped at the edge of ITS display, not of the desktop:** on the main display near the shared edge, right edge 1920 (F1: 937, 1068, 1135), bottom 1080 with a display below (1137); on the second, its own right edge whichever side the main one is (F3: 941, 1072, 1139). A window that lies across the edge with the larger
    part on the neighbour (1820,81 400×300) grows to the NEIGHBOUR's right edge, 2720 (945); with no neighbour there it is free (1076, 1143).

### Rule 8, call by call: a size call right after a position call that changed the display

The time is from the position call's return to the size call's start (between them: two readings of the frame and one of the window server's list). "By the old display" is worked out from rules 2 and 3 with the display the window came from.

| line | second display | journey, order | wait | stood | asked | took | judged by |
|---|---|---|---|---|---|---|---|
| 966 | right | F9 SPS, small → large | 0.5 ms | 12,43 788×557 | 1000×650 | 1000×**557** | the old: bottom 600 |
| 969 | right | F9 PS | 4.4 ms | 12,43 776×545 | 1000×650 | 1000×**557** | the old |
| 976 | right | F9 sPS | 5.1 ms | 12,43 776×545 | 1000×650 | 1000×**557** | the old |
| 1097 | left | F9 SPS | 1.1 ms | 12,43 788×557 | 1000×650 | 1000×**557** | the old: bottom 600 (its right edge, 0, is passed: width free) |
| 1100 | left | F9 PS | 4.2 ms | 12,43 776×545 | 1000×650 | 1000×**557** | the old |
| 1107 | left | F9 sPS | 1.6 ms | 12,43 776×545 | 1000×650 | 1000×**557** | the old |
| 1164 | below | F9 SPS | 1.3 ms | 12,43 788×507 | 1000×650 | **788**×650 | the old: right edge 800 |
| 1167 | below | F9 PS | 5.6 ms | 12,43 776×496 | 1000×650 | **788**×650 | the old |
| 1174 | below | F9 sPS | 4.2 ms | 12,43 776×496 | 1000×650 | **788**×650 | the old |
| 1086 | left | F8 PS, large → small | 3.1 ms | −788,43 1000×567 | 776×545 | **812**×545 | the old: 24 points kept on it |
| 955 | right | F8 PS | 4.0 ms | 1932,43 1000×567 | 776×545 | 776×545 | cannot be told: whole by either |
| 1153 | below | F8 PS | 4.6 ms | 12,1111 798×520 | 776×496 | 776×496 | cannot be told |
| 983, 990 | right | F10 PS, sPS, small → the whole of the second | 5.1, 5.0 ms | 1920,31 800×200 | 800×569 | 800×569 | cannot be told (x 1920 is past the old display's edge, 600 is above its line) |
| 1114, 1121 | left | F10 PS, sPS | 3.1, 3.2 ms | −800,31 300×200 | 800×569 | 800×569 | cannot be told |
| 1181, 1188 | below | F10 PS, sPS | 4.1, 4.2 ms | 0,1111 300×520 | 800×520 | 800×520 | cannot be told |
| 952, 962, 980, 1083, 1093, 1111, 1150, 1160, 1178 | all | the last call of SPS and sPS in F8, of SPS in F10 | 0.2 to 6.0 ms | the target already | the same | no change | nothing asked of it |
| 1067 | left | F1, after the placing | 200 to 283 ms | 1420,81 400×300 | 900×300 | 500×300 | **the new**: right edge 1920 |
| 941, 1072, 1139 | right, left, below | F3, after the placing | 200 ms or more (not logged) | on the second, 300 from its right edge | 700×200 | 300×200 | **the new** |

So: judged by the old display in 10 calls of the 10 that can tell, 0.5 to 5.6 ms after the position call; by the new one in 4 of 4 at 200 ms or more. The probe's own placing (three calls back to back, not logged one by one) adds the three kept sizes named in rule 8.
**What would settle where it turns:** a round of its own: position to the other display, wait 0, 10, 25, 50, 75, 100, 150, 200, 250, 300 ms, size; both directions; the small display right, left and below; and today's size, position, size followed by one more size call after each of those waits, which is what a cure would do. The waits spun or by `mach_wait_until`
and logged as they really were (this run's run-loop waits came 12 to 160 ms late). `scripts/mac-shell/probe-when-the-display-turns.sh` is that round.

### Order × circumstance

Cell: how the window ended at rest (350 or 600 ms after the last call) · AXMoved + AXResized that arrived. "whole" is the target to the point. **Bold** is what differs from the target (w −166: 166 narrower). The half-way frames are in what `--orders` prints; in short, on one display:
SPS passes through "the new size as far as it goes, at the old place" and "that size at the new place"; PS through "the old size at the new place" (which hangs 325 points below the Dock's line in B3 and 494 past the right edge in B4); sPS through "the smaller size at the old place, then at the new": never larger than either frame.
Base's B rows were made twice, with and without reading the frame back between the calls: the same ends and the same reports, 20 pairs of 20.

| circumstance | journey (line) | from → to | SPS | PS | SP | sPS |
|---|---|---|---|---|---|---|
| 1024×768, Dock at the bottom | B1 grows (14) | 170,220 480×348 → 12,43 494×650 | whole · 1+2 | whole · 1+1 | **h −166** · 1+1 | whole · 1+1 |
| | B2 shrinks (42) | 12,43 1000×650 → 600,300 300×200 | whole · 1+1 | whole · 1+1 | whole · 1+1 | whole · 1+1 |
| | B3 wider and lower (70) | 518,43 494×650 → 12,380 1000×313 | whole · 1+2 | whole · 1+1 | **w −494** · 1+1 | whole · 1+2 |
| | B4 narrower and taller (98) | 12,380 1000×313 → 518,43 494×650 | whole · 1+2 | whole · 1+1 | **h −326** · 1+1 | whole · 1+2 |
| | B5 back from the corner (126) | 1023,677 325×524 → 12,43 494×650 | whole · 1+1 | whole · 1+1 | whole · 1+1 | whole · 1+1 |
| | D1 ends at the visible bottom (192) | → 12,43 494×662 | **h −1** · 1+2 | **h −1** · 1+1 | | |
| | D2 ends one above (199) | → 12,43 494×661 | whole · 1+2 | whole · 1+1 | | |
| | D5 ends at the right edge (220) | → 530,43 494×400 | whole · 1+1 | whole · 1+1 | | |
| | D6 ends one past it (227) | → 530,43 495×400 | whole · 1+1 | **w −1** · 1+1 | | |
| | D8 the whole visible frame (241) | → 0,31 1024×674 | **h −1** · 1+2 | **h −1** · 1+1 | | |
| Dock at the left (visible 50,31 974×737) | B1 (300) | 220,220 480×348 → 62,43 494×713 | whole · 1+2 | whole · 1+1 | **h −165** · 1+1 | whole · 1+1 |
| | B2 (314) | 62,43 950×713 → 600,300 300×200 | whole · 1+1 | whole · 1+1 | whole · 1+1 | whole · 1+1 |
| | B3 (328) | 518,43 494×713 → 62,443 950×313 | whole · 1+2 | whole · 1+1 | **w −444** · 1+1 | whole · 1+2 |
| | B4 (342) | 62,443 950×313 → 518,43 494×713 | whole · 1+2 | whole · 1+1 | **h −388** · 1+1 | whole · 1+2 |
| | B5 (356) | 1023,740 325×524 → 62,43 494×713 | whole · 1+1 | whole · 1+1 | whole · 1+1 | whole · 1+1 |
| | D1, D2, D5, D8 (371…) | end at 768, 767, at 1024, the whole visible frame | whole | whole | | |
| Dock hidden (visible 0,31 1024×737) | D1, D2, D5, D8 (463…) | the same | whole | whole | | |
| 1920×1080 beside a second display, staying on it | D1, D8 (996, 1045) | end at the visible bottom 1002 | **h −1** · 1+2 | **h −1** · 1+1 | | |
| | D2, D5 (1003, 1024) | | whole | whole | | |
| TextEdit | B1 (553), B4 (567) | as above, visible bottom 708 | whole · 1+2 | whole · 1+1 | **h −166, −329** · 1+1 | whole · 1+1, 1+2 |
| Java (jconsole) | B1 (853), B4 (867) | visible bottom 710 | whole · 1+2 | whole · 1+1 | **h −166, −331** · 1+1 | whole · 1+1, 1+2 |
| Finder (least width 501) | B1 (628), B4 (642) | | w +7 · 1+2 | w +7 · 1+1 | w +7, **h −166, −329** · 1+1 | w +7 · 1+1, 1+2 |
| Safari (least width 574) | B1 (778), B4 (792) | | w +80 · 1+2 | w +80 · 1+1 | w +80, **h −166, −331** · 1+1 | w +80 · 1+1, 1+2 |
| Terminal (cells) | B1 (703), B4 (717) | | w −2, h −6 · 1+2 | w −2, h −6 · 1+1 | w −2, **h −171, −336** · 1+1 | w −2, h −6 · 1+1, 1+2 |
| 11 apps and the test window | H7 into a slot, H8 out of it | 170,220 600×348 ⇄ 12,43 700×(vb−55) | as PS · 1+2, 1+1 | whole or the app's least size · 1+1 | | |
| **second display to the right** | F8 large to a slot on the smaller (953) | 12,43 1000×**567** → 1932,43 776×545 | whole · 1+1 | whole · 1+1 (it fitted) | whole · 1+1 | whole · 1+1 |
| | F9 back to the larger (967) | 1932,43 776×545 → 12,43 1000×650 | **h −93** · 1+2 | **h −93** · 1+1 | **w −212, h −93** · 1+1 | **h −93** · 1+1 |
| | F10 small to the whole of the second (981) | 100,131 300×200 → 1920,31 800×569 | whole · 1+1 | whole · 1+1 | whole · 1+1 | whole · 1+1 |
| **to the left** | F8 (1084) | 12,43 1000×650 (SPS; the others 567) → −788,43 776×545 | whole · 1+1 | **w +36** · 1+1 | whole · 1+1 | whole · 1+1 |
| | F9 (1098) | −788,43 776×545 → 12,43 1000×650 | **h −93** · 1+2 | **h −93** · 1+1 | **w −212, h −93** · 1+1 | **h −93** · 1+1 |
| | F10 (1112) | → −800,31 800×569 | whole · 1+1 | whole · 1+1 | whole · 1+1 | whole · 1+1 |
| **below (the Dock goes there)** | F8 (1151) | 12,43 1000×650 (SPS; the others 798×650) → 12,1123 776×496 | whole · 1+1 | **y −12** · 0+2 | whole · 1+1 | whole · 1+1 |
| | F9 (1165) | 12,1123 776×496 → 12,43 1000×650 | **w −212** · 1+2 | **w −212** · 1+1 | **w −212, h −143** · 1+1 | **w −212** · 1+1 |
| | F10 (1179) | → 0,1111 800×520 | whole · 1+1 | whole · 1+1 | whole · 1+1 | whole · 1+1 |

**Read together:** sPS ends to the point as SPS ends in all that was seen (34 results of 34), never larger on the way than the larger of its two frames, and gives one report fewer where the journey only grows (1+1 against 1+2). PS gives the fewest reports and is right on one display, but hangs over the edges on the way and is the one order that a smaller display clamps.
No order mends rule 8: a window that has changed display needs its size asked again later.

### H: who moves late?

One call, the frame read back at once, then three later looks; H7 and H8 with their calls back to back and the looks after the last. **The looks came later than they were meant to:** the "50 ms" look 62 to 209 ms after the call returned (half by 128), the "200 ms" one 200 to 346 (half by 258), the "600 ms" one 601 to 757 (half by 676): the
true time of every reading is in what `--late` prints. So nothing is known of the first 60 ms but the reading at once. Reduce Motion OFF for all apps (opened after the setting was changed), ON for the last row and for the test window.

**Late apps seen: none among the eleven tried (ten of Apple's, one Java), nor the test window.** Accessibility's frame at once is Accessibility's frame at all three looks: 170 results of 170 (130 of round H, 40 of B's journeys on the test window). No app sized at once and moved late, none that animates, by Accessibility or by the window server at the three looks.

**But the window server's list is behind Accessibility.** Read right after Accessibility's answer it differs from what Accessibility says in 143 results of 170; call by call, of 615 calls that changed the frame it still listed the frame before the call in 475, something older in 94, the new frame in 46. At the first look it had caught up in 165 of 170. The five, all on the test
window, all after calls back to back: 62 to 146 ms after the last call it listed a HALF-WAY frame (line 130: SPS back from the corner, at 146 ms "1023,677 494×650", the new size at the old place; lines 30, 46, 77, 122). At the second look (200 ms and later): 170 of 170. Whoever judges by CGWindowList within 150 ms of a call judges an older frame; and the half-way frames are
not only in the books: the window server had them for that long.

Cell: `=` Accessibility the same at once and at the three looks · which look first found the window server agreeing (0: at once) · (when the first look came, ms).

| app | H1 taller and wider | H2 smaller | H3 moved | H4 to the corner | H5 back | H6 taller than there is room | H7 SPS | H7 PS | H8 SPS | H8 PS |
|---|---|---|---|---|---|---|---|---|---|---|
| test window | = 1 (154) | = 0 (191) | = 1 (123) | = 1 (103) | = 1 (186) | = 1 (70) | = 1 (165) | = 1 (155) | = 1 (187) | = 1 (163) |
| TextEdit | = 0 (106) | = 1 (120) | = 1 (125) | = 1 (125) | = 1 (123) | = 1 (107) | = 1 (115) | = 1 (124) | = 1 (121) | = 1 (120) |
| Finder | = 1 (117) | = 1 (123) | = 1 (102) | = 1 (101) | = 0 (103) | = 1 (83) | = 1 (112) | = 1 (80) | = 1 (125) | = 1 (121) |
| Terminal | = 0 (117) | = 1 (113) | = 1 (103) | = 1 (112) | = 1 (103) | = 1 (129) | = 1 (117) | = 1 (116) | = 1 (114) | = 1 (129) |
| Safari | = 0 (124) | = 0 (122) | = 1 (126) | = 1 (109) | = 0 (109) | = 0 (96) | = 0 (124) | = 0 (105) | = 1 (118) | = 0 (128) |
| Java (jconsole) | = 0 (124) | = 0 (120) | = 1 (121) | = 1 (121) | = 1 (124) | = 0 (121) | = 1 (123) | = 1 (118) | = 1 (120) | = 1 (126) |
| Preview | = 0 (199) | = 1 (191) | = 1 (118) | = 1 (123) | = 1 (108) | = 1 (99) | = 1 (196) | = 1 (158) | = 1 (116) | = 1 (99) |
| Script Editor | = 1 (108) | = 1 (153) | = 1 (200) | = 1 (199) | = 1 (197) | = 1 (192) | = 1 (196) | = 1 (182) | = 1 (207) | = 1 (106) |
| Activity Monitor | = 1 (95) | = 1 (184) | = 1 (104) | = 1 (207) | = 1 (120) | = 0 (126) | = 1 (122) | = 1 (171) | = 0 (182) | = 1 (207) |
| Console | = 0 (200) | = 1 (193) | = 1 (108) | = 1 (104) | = 1 (183) | = 0 (89) | = 1 (195) | = 1 (202) | = 1 (201) | = 0 (197) |
| Notes | = 1 (98) | = 1 (200) | = 1 (147) | = 1 (117) | = 1 (154) | = 1 (91) | = 1 (132) | = 1 (96) | = 1 (197) | = 1 (201) |
| Calendar | = 0 (87) | = 1 (169) | = 0 (195) | = 1 (195) | = 1 (163) | = 0 (166) | = 1 (127) | = 0 (106) | = 1 (205) | = 0 (98) |
| TextEdit, Reduce Motion on | = 0 (193) | = 1 (194) | = 1 (198) | = 1 (197) | = 1 (198) | = 1 (202) | = 1 (200) | = 1 (202) | = 1 (194) | = 1 (200) |

**How long a call takes** (half of them within, the longest; ms): the test window size 1.5, 9.8 and position 0.6, 3.9; TextEdit 5.4, 11.4 and 0.7, 7.5; Terminal 5.8, 11.1; Java 8.3, 14.7; Preview 6.8, 15.8; Script Editor 7.5, 20.6; Notes 14.7, 22.1; Calendar 15.5, 36.7; Finder 18.0, 47.0; Safari 18.7, 33.5; Console 18.4, 34.6; Activity Monitor 13.9, **94.6**.
Positions: all within 21.3. **The reports** come within 52 ms of the first call in every app but Activity Monitor (182 ms, after a journey whose calls took 223 ms); on the test window within 14 ms. A call that changes nothing brings no report (C14 to C17; the last call of SPS when the first got everything).

### Not seen, so not known

- When after a change of display the new display begins to judge (between 6 and 200 ms), and what announces it. **The next probe's first question.**
- A window too tall for the smaller display sent to a display at the RIGHT; a window too WIDE only; a smaller display ABOVE; a Retina display; displays of unlike scale.
- A bottom edge between 730 and 899 with the display's bottom at 768 (rule 4).
- The first 60 ms after a call, but for the reading at once.
- Chrome and Firefox: both are installed, `open -g -b <bundle id> --args …` failed at once for both (the run's output, which is not in the tree), so no Chromium or Gecko window was asked; no Electron or Qt app is on a hosted Mac (by the run's listing of `/Applications`). Java's jconsole is the one window not drawn by AppKit's own views.
- The frontmost app's window (every app was opened in the background); a window being dragged; a minimized or full-screen one; Stage Manager; macOS's tiling with a window already tiled; "Displays have separate Spaces" off.
- Whether AppKit or the window server does the clipping. It leans to AppKit in the app's process: rule 8 is what a stale `NSWindow.screen` would give, and rule 7 is what `constrainFrameRect(_:to:)` does. By reading, not by any test.

### For the stand-in

`FakeWindowSystem.setFrame`, true to this: a size call takes width at most max(the width it has, right edge of ITS display − x) unless the right edge is past that edge already; height at most max(the height it has, L − y) with L the visible bottom less 1 where the Dock is at the bottom of its display and the display's bottom otherwise, unless the bottom is past the
DISPLAY's bottom already; sizes rounded down to whole points. A position call: y between the visible top and the visible bottom less the title bar's height; x pulled back to show 40 points when nothing would show on any display; onto a display whose visible frame is lower than the window: y the visible top, height the visible height. "Its display" after a position call to another
display: still the old one for the calls that follow at once.

## Part 3. One size call while a hand holds the window, Arbor not running

Written 09:23 UTC 2026-10-15. Read off `collab/evidence/how-far-a-window-grows/inhand.jsonl` (703 lines: every call, reading and report, and the very words the pointer tool got) and off three files of the run that are not in the tree: `samples.log` (the window server's list and the
pointer at 60 Hz), `ax-events.txt` (axwatch all the while), `output.txt`. ONE hosted Mac, macOS 26.6.2 (25G83), run 38705723680, branch `probe/a-size-call-in-the-hand` at 19ca32f1,
`scripts/mac-shell/probe-a-size-call-in-the-hand.sh` with `grow.swift` (steps `put`, `look`, `chain`), `pointer.swift`, `sampler.swift`, `axwatch.swift`. `scripts/mac-shell/grow-hand.py` prints it: `grow-hand.py inhand.jsonl`,
`--sum` (what the repeats of a trial have in common). "line 5" is a line of `inhand.jsonl`: where a trial begins.

**A SYNTHETIC POINTER STANDS FOR A HAND:** events posted at the HID tap, in even steps, resting while the call is made.

**Played:** the test window, eleven kinds of trial, five times each (55); TextEdit, six kinds, three times (18); Safari 7 trials, of which only 2 are drags (below). **Not played:** 11 more Safari trials and all of Terminal: the clock (440 s) stopped them; a trial took
5.3 s, I had counted 4. **Varied:** where the title bar is held (left, middle, right, 800 points in), smaller and larger, room below or not, in the hand and 5, 20, 50 ms after the release. **Not varied:** the Mac, the macOS; one display 1024×768 at scale 1; the Dock at the bottom, shown (visible
bottom 705, with TextEdit or Safari open 708); `com.apple.WindowManager` holds no tiling key (the image's state, printed at the top of output.txt); Reduce Motion ON, as the image has it; one Space; no modifier key; the pointer never near an edge, a corner or the menu bar; the pointer at rest
during the call, never moving; one size call at a time and never a position call in the hand; the window's app in front from the press on.

### The answers, by the numbers of the question

1. **Taken? Whole, as at rest, in one report.** 63 size calls with the button down: 45 on the test window, 15 on TextEdit, 3 on Safari. Each took what the same call takes at rest (part 2): the whole size where there is room, cut at the line where there is not, the app's least width (Safari 574). ONE AXResized and NO AXMoved for
   each call that changed anything (58 of 58), 0.7 to 2.0 ms after the call began on the test window, 1.7 to 3.8 on TextEdit, 6.7 to 9.4 on Safari: as the call returns (it lasts 0.7 to 2.1, 1.8 to 3.9, 6.8 to 9.7 ms). Accessibility reads the new frame at once and the same 50, 200 and 500 ms after (spun waits, on time). The window server's list, read right after:
   mostly still the old size; at 50 ms the new one in all. In the 60 Hz samples the new size first shows 2 to 79 ms after the call began (half by 24; TextEdit 5 to 73, Safari 16 to 60).
2. **The drag goes on.** After the call the pointer moves on 60 points in 10 steps: the samples hold the window at 9 to 12 different places, never more than one step (6 or 7 points) behind the pointer, and at the end the hold (pointer less origin) is what it was before the call, to 1 point. axwatch has AXMoved after AXMoved with `[button down]` as before the call
   (ax-events.txt, `--- test-window.T1-smaller.1`). **The release is a release:** 0.1 s and 0.7 s later the window is where it was let go; nothing tiles, nothing jumps. 35 trials of 35, TextEdit 12 of 12, Safari 2 of 2.
3. **The origin stays**, as at rest: moved by 0,0 in all 63 calls. The window server does not keep the point under the pointer; it keeps the OFFSET between pointer and origin that the drag began with.
4. **Narrower than the point it is held at** (line 14): 936 wide, held at x+800, asked 304: the window is 80,160 304×400, the pointer at 880,172: 496 points to the right of its right edge, over nothing of it. **It still follows**, step for step, at that distance: carried 60 to the left it is at 20,160 with the pointer at 820; released, it stays at 20,160. 5 of 5; TextEdit 3 of 3.
   So a window that shrinks in the hand is left behind by the pointer unless something moves it: and a position call in the hand was NOT tried.
5. **Wider and higher** 325×319 → 480×600 held at x+90, x+162, x+300 (lines 23, 32, 41): whole, origin kept, hold kept, 15 of 15; TextEdit 3 of 3; Safari once, 574×600.
6. **The cut in the hand is the cut at rest** (T6a, line 50): top at 404, 200 high, asked 600 high: 300, bottom 704 of a visible 705, 5 of 5; TextEdit 3 of 3 and Safari once: 303, bottom 707 of 708. **Carried up to y 80, the second call is taken whole, 600 high, still in the hand**, one AXResized, and the drag goes on and ends well: 5, 3 and 1.
   **T6b did not come about as asked, and that is a find** (line 62): the hand could not carry the 319-high window's top from 364 to 404: it stopped at y 385, **its bottom at 704**, while x went on following, and the pointer went 19 points further down alone: 5 of 5 (ax-events.txt: 305,369; 313,377; 321,385; 326,385; 332,385 …). Asked 600 high there, it kept 319, no report: as at rest at the line
   (part 2, rule 4). Carried up again it moved at once, with the new hold (30 or 31 points below its top in place of 12), and at y 62 took 600 whole. The 200-high window passed no line on its way.
   **A wall or a resistance? As far as the pointer went, a wall:** in the 60 Hz samples of all five trials y is 385 in every sample from the one where the pointer is at y 397.3 to the end at y 416, 0.4 to 0.6 s of movement and then about a second at rest: it does not creep by a point, while x follows step for step (321, 324, 326, 329, 332, 334, 337, 340). On the way up there is no slack to take in: at the pointer's FIRST step up
   (416 → 399.8) the window goes 385 → 368. So the 19 points are lost for good: the hold has changed. But 19 points is all that was tried, at some 30 to 45 points a second by the samples: whether a longer or faster pull takes the window past the line is not shown (the second in-hand probe pushes 19, 40, 80, 150 points past; the other session's probe of hands lets go low).
7. **After the release** (lines 74, 81, 88): the tool watches the button and spins: 5.01 to 5.02, 20.01 to 20.09, 50.01 to 50.12 ms after it saw the button up: 600×400 asked 480×300: whole, one AXResized, the origin where it was let go, the same at 50, 200, 500 ms: 15 of 15; TextEdit at 20 ms 3 of 3. ("Saw the button up" is the HID state; when the app heard of it is not known.)
8. **Real apps.** TextEdit: as the test window in all 18. **Safari: T1 (twice), T4 and T7 are NO DRAGS:** my press, 20 points below the top at x+300 and x+800, fell on its address field (apptool had called the point free: AXStaticText) or a button: the window never left 200,150 by the window server's account (lines 633 to 650), and axwatch has no AXMoved between `mouse down` and `mouse up`. They say nothing about a hand.
   **What "454,213 34×34" was:** not the window. The press in the address field opened a panel of Safari's own: samples.log has a new window 44 of Safari's, 374,202 404×177 growing to 370,202 412×181, from 69 ms after the press of T1 until 78 ms after the release of T4. While it was up, grow.swift, which starts anew for every question and picks from the app's AXWindows the first element
   whose window number is 42, got an element 34×34 at 454,213, which lies inside that panel; size calls on it returned in 0.1 ms and changed nothing. So Safari lists, under the main window's number, something that is not the main window while that panel is open. What the element is (role, subrole) the tool did not print in these trials. A first reading called it "the little picture Safari drags out of the field": that was a guess, and nothing shows it.
   T5 and T6a (lines 651, 660), held at x+162, are true drags, once each, three calls: as the others. Terminal: not played.
9. **At rest: sized where it fits, then moved** (line 95): at 624,404 400×319: position 624,80; size 400×600; position 624,404, back to back: **ends 624,404 400×600, bottom 1004, 299 below the line**, and stays: 5 of 5, TextEdit 3 of 3, Safari once (574 wide). Three calls in 1.4 to 2.6 ms (TextEdit 2.8 to 7.2, Safari 16.3). Reports: AXMoved, AXResized, AXMoved, within 2.6 ms (TextEdit 7.2, Safari 16.1).
   **In the window server's samples:** in 4 of the 9 it is seen at 624,80 400×319, the first call alone, 5 to 23 ms after the first call, for one or two samples; then the end frame, first seen at 21 to 90 ms. In the other 5 only the end frame. Never at 624,80 400×600. So the eye can catch the window up there for a sixtieth or two.

### Odd, and not understood

- TextEdit and Safari in T5: put at y 60 and dragged 30 down they stood at y 84, not 90, and kept that hold (18 and 26 in place of 12 and 20): 3 of 3 and 1 of 1. The test window stood at 90, 15 of 15. In T1, T4 and T6a (from y 150, 120, 364) nothing of the kind.
- After a drag the window rests 1 point to the right of where the arithmetic puts it in about half the readings with the button down (261 for 260), and at the round number after the release: the pointer tool's own "a point aside and back" at the end of a movement.

### Not seen, so not known

A size call while the pointer is MOVING; a position call in the hand (what (4) would need); two calls back to back in the hand; a real hand or trackpad; the pointer near an edge where macOS offers a tile, or with the tile's preview up; ⌥ down; a window dragged by a toolbar or by its background; Safari beyond three calls; Terminal; any app not AppKit's;
Reduce Motion off; a second display; Arbor's own taps in the way.

## Part 4. Since then, with Arbor running

The same five journeys (`scripts/mac-shell/reality.sh`, 70 steps, test windows, posted events) on hosted Macs through the morning of 2026-10-15, each run once. What was played is what the run's own `commit.txt` says. The runs' folders lie on output branches of the repository
and not in the tree; the numbers are what `scripts/reality-clip.py` ("took bottom 704"), `scripts/reality-clip-any-display.py` and `scripts/reality-slots.py` print of them.

| what was played | answers cut at the Dock's line | looks at a docked window on screen, of them not filling its slot | `setFrame` calls |
|---|---|---|---|
| the trunk of the first catch (part 1's run) | 23 | 82, 30 | 182 |
| the control of the cure's night (told by whoever ran it; its folder has been overwritten since) | 23 | 82, 30 | 182 |
| a new order of the calls alone, without the cure | 23 | 82, 30 | 182 |
| **the cure** (nobody in view is asked to grow where it stands) | **0** | 82, **0** | 155 |
| the cure and the new order | 0 | 82, 0 | 155 |
| the trunk itself with the cure landed (cd3b2dec) | 0 | 77, 6: five are a window under macOS's own zoom, which is let be; one is a drag whose release was never heard | 130 |
| a later trunk, plain | 0 | 84, 1 (macOS's zoom) | 154 |
| the same, the Dock at the left (visible 50,31 974×737) | 0 | 84, 1 (the zoom) | 131 |
| the same, the Dock at the right (visible 0,31 974×737) | 0 | 84, 1 (the zoom) | 130 |
| the same, a second display (main 1920×1080, second 1280×720 to its right) | 0 | 99, 2: the zoom, and the one below | 161 |

1. **The short window is cured, seen on a Mac**, beside a control of the same night, on the trunk itself, with the Dock at either side and with two displays. A second witness, the keeper of the real-window suite's, counted again for this page in the two runs' output: the whole suite on two hosted Macs with the cure, "windows match Arbor's layout" 203 of 203, "in its slot" 27 of 27, "fills the screen" 70 of 70.
   Not shown: real apps; a window that refuses a size for reasons of its own other than one minimum size.
2. **Part 2's rule 8 with Arbor running: small → large leaves a docked window short.** `move-to-display next` of a window docked on the second display at 1932,43 622×665: asked 1443,43 465×947, took 465×**677**; asked again 1 ms later, took 677 again; 0.4 ms after that Arbor asks 1443,178 465×677, the window centred in its slot
   as for one that will not grow. It stays so until the quit. 677 = 720 − 43: the bottom of the display it came from. Once, one Mac. The way large → small was taken as asked. Not measured: a drop by hand the moment the window has crossed.
3. **With the Dock at the right a window sent out of view does not leave the display.** Asked 1023,767 every time, took **934,740**: 20 of 20. In the plain run 1023,677; with the Dock at the left 1023,740; with two displays 1919,974. So a window's left edge goes no further right than the VISIBLE frame's right edge less 40 (974 − 40), and a corner 40 points wide to the
   visible frame's edge, 90 to the display's, and 28 high stays on the display. That corrects part 2's rule 5, which had seen the 40 points only where the visible frame and the display end together. By frames; no picture was taken during a journey.
4. **With the Dock at the right a window that grows in view stops at the visible right edge less 1.** 973 of 974, 2 of 2 (asked 480 wide, took 479: from 309 and from 261 wide). Three more asks that end at 974 were taken whole: one grew from the parked place, one only moved, one shrank. It is part 1's rule 1 turned on its side. No ask went beyond 974. One of the two windows
   was still 479 wide after the quit.
5. **Not asked:** a real app in any of these; a window on the second display for more than one step; the parked corner with a display to the right as tall as the main one, or below it.
