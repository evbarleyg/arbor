# Polish: what consumer-grade means for Arbor, in checks

Tests say whether windows end up in the right places. This page says whether getting there **feels right**, and it says so in
checks that nobody has to be asked about: a hosted Mac films Arbor, and agents judge the films and pictures in a sandbox,
with a ruler wherever a ruler can settle it and with their eyes, frame by frame, for the rest. The maintainer is never asked to look.

The result is one number, the **polish score**. It is on the scoreboard, and it only goes up: a change that lowers it is a
regression, found before it lands, like a failing test.

**What is scored is what ships, and the bar is macOS alone.** The first person to work with Arbor quit it for macOS's own tiling: it did too much by itself (`collab/HANDOFF-2026-10-14-maintainer.md`; `collab/QUESTIONS.md`,
Q29). This page had given points for how well a ring and cards were drawn, and the first person to see them wanted neither. So the first column holds only what a person meets who has switched nothing on; everything else is the
second column, *the options*, judged by the same rules and read by no gate. And every run films macOS's own tiling of the same windows, with Arbor not running: whatever Arbor does with a window is held against that.

| | |
|---|---|
| What Linux proves | that the film scripts play (`scripts/mac-shell/rehearse.sh scripts/mac-shell/films-light.sh scripts/mac-shell/films.sh`) and that the judge catches what it claims to catch (`scripts/polish/judge.py --self-test`: 73 drawn films, each wrong in one known way or right; `scripts/polish/stills.py --self-test`: 30 drawn pictures) |
| What a Mac must run | `scripts/mac-shell/films-light.sh`, what ships: unattended, on a free hosted runner, about ten minutes; for the options `scripts/mac-shell/films.sh`, about a quarter of an hour. They only record |
| What the sandbox judges afterwards | everything: `scripts/polish/judge.py score <run folder>`, then the sheets, by eye |

## How bad a miss is

| Severity | Means | Costs |
|---|---|---|
| 1 | Anybody sees it the first time, and it looks broken: a flash, a hop, a window that turns into something else, two motions for one key | 5 points |
| 2 | Felt within a day of use, even by somebody who could not name it: sluggish, abrupt, stuttering, hard to read | 3 points |
| 3 | A designer would circle it: a pixel off, a corner that is not concentric, a word too many | 1 point |

**What could not be seen counts as a miss.** A film that was not shot, a film in which nothing happens or that does not show its scene, a scene for a
feature that has not landed, a window the judge lost track of, a sheet nobody has gone through: all score nothing. So the score cannot be raised by looking at less, and
the scenes for tabs, double clicks and continuous zoom are in the sum from the first day.

## The laboratory

- **The Mac**: GitHub's `macos-26` runner, one display of 1024 × 768 at 1x; a virtual Retina display for pictures at 2x. macOS at
  its default settings (its own edge tiling on, click-wallpaper on): the runners come with Reduce Motion and Reduce Transparency on, and the script switches both off.
- **Arbor, in two columns.** **As it ships** (`scripts/mac-shell/films-light.sh`): every switch of Arbor's and of macOS's as it comes. This is the score, and what the gate reads. An act that does nothing as shipped is filmed doing
  nothing, and scores nothing. **The options** (`scripts/mac-shell/films.sh`): motion, the ring, the menu bar's buttons, the whole map of keys, the gestures, each switched on in so many words; the gestures with macOS's own tiling off (`on-…`). It says how good
  an option is for whoever switches it on, and how good it will be the day it ships; it passes no gate. Until the second build's defaults are on the trunk its switches are written out in `films-light.sh`, one key fewer with every default that lands.
- **The look that is scored first is the one a Mac comes with**: Reduce Transparency off. The flat look is second, being what a person with Reduce Transparency sees.
- **macOS alone**: in every run, after Arbor has quit, the same windows are tiled by macOS itself from each app's Window menu (`macos-…`). Filmed, measured, not counted: it is the bar. As first measured (`collab/polish/light-1.md`): the real window glides and grows in one
  piece, eased, 283 to 317 ms, 16 to 18 frames of the 18 to 20 that sixty a second would make (waits of 33 ms, as the camera's own square has there), on a curve like Arbor's own stretched to 0.3 s; of two windows tiled at once the one in front glides and the other jumps.
- **Test windows are the strict judge, a real app the lenient one.** Which of the states between two askings get drawn depends on how long a state lasts and on how fast the app draws. A test window draws at once and shows them all; Safari, asked for a size and then
  for a place, may not have drawn itself when the place comes. A cure is held to the strict judge and shown on the lenient one (`scripts/mac-shell/films-arms.sh`: the same acts on one Mac by Arbor as built from several commits; `scripts/polish/arms.py` counts).
- **A first use is told from a standing cost.** What is made for the first time in a session (a tile, a panel, a drawing context) can take many times what it ever takes again. A scene that stalls is filmed a second time in the same session (`…-again`): both count, since a first use is met at every launch.
- Every session records a trace (`docs/TRACES.md`), which comes back beside the films: what Arbor asked of macOS, and when.
- **The window server's account**: `sampler.swift` runs beside the camera and writes down where every window is, sixty times a second. A film cannot show where a real window is while a
  stand-in covers it; `judge.py home <run>` lays the two side by side, scene by scene. It scores nothing: it says where the cause of a miss is to be looked for.
- **The windows**: `ArborTestWindows`, each one flat colour, on a plain wallpaper: a window is then a rectangle that a script can find in every
  frame to the pixel. Each is an app of its own (`cast_start`), with a name and an icon in the window's colour, because a person's windows are not all
  one app's, and cards that all look alike are harder on the eye, and on the ruler, than anybody's desk.
- **The hand**: real keys and a real pointer (`pointer.swift`, `witness.swift`), one thing a person does per scene. Never the command behind the key.
- **The camera** (`scripts/mac-shell/camera.swift`): every frame ScreenCaptureKit delivers, up to 60 a second, lossless, each with the moment the display
  showed it; and, from an event tap at the head of the chain, the moment each key and button went down or up. Screen Recording is the one permission
  it needs, and child processes on the runner have it.
- **The metronome**: before Arbor is filmed, the camera films a square of its own that moves in a way that is known: once as this page asks
  (460 ms, Arbor's curve), then wrong in five ways (linear; 900 ms; in two pushes; a 9-pixel hop at the end; a flash of two frames). If the judge finds
  anything in the good film, cannot follow it, or does not find in each of the others the fault that was put there, **the run's score is void**. (A motion in two pushes is also too long: what else a
  wrong film misses is not held against the judge.) One exception, which run 2 needed: a spark whose timer came late and that stayed too long to be a flash is a control that failed, not a judge; the run counts if the judge
  found the spark and measured how long it stayed. Since then Core Animation times it. What the good film shows of delay and of waits between frames is the
  camera's and the runner's doing, and is allowed to Arbor's films as well.
- **A film** is a folder of PNGs (the first frame whole, then only the pixels that changed) and `film.log`, in the grammar of the window sampler's log
  (`<ms since 1970> <kind> …`), so that the two merge by time. `camera.swift`'s header has the details.

## The checks

**By**: *ruler* = `judge.py` measures it; *eyes* = an agent goes through the sheets (`judge.py sheet`) and writes the verdict, with the
frames that show it, into `collab/polish/eyes-run-<n>.json`; *stills* = measured on pictures of each panel alone (the gallery's `*-alone-*.png`).

### At once: asked of every act by key, from the menu, or at the end of a drag, as Arbor ships

Arbor ships without motion: windows go to their places at once and nothing stands in for them. So the real windows are seen going: each is another app's, is asked for its place and its size one after the other, and obeys when it gets round to it.
A **piece** is a frame in which a window comes, goes, or changes its place or size, up to the film's end. A line of words that fades in afterwards is no part of the windows' arriving; nor is a panel of Arbor's that was up when the act began, or
what lies under a menu that macOS is fading out (the menu's frame is noted, and the judge looks beside it). **An act after which, by Arbor's own account, no window has another frame or state than before, earns nothing**, whatever came and went on the display. `judge.py acts <run>` prints all of this for every act, with the window server's own account beside it.

| # | What | How | Passes when | Severity |
|---|---|---|---|---|
| R1 | **At once** | the first piece → the last | ≤ 100 ms | 1 |
| R4 | **Every window is where it was or where it belongs** | frames in which a followed window is at a place or size that is neither its old nor its new one | none | 2 |
| R5 | **In one piece** | between the first piece and the last: frames in which the ground shows where there is a window both before the act and after it (a hole, over 1% of the room); in which nothing at all is on a desk that had windows and has them again; in which a window on its way covers what neither its old frame nor its new one covers (over 400 square points) | none | 1 |
| R2 | **The same end** as with motion (the options only) | the windows' rectangles in the last frame of `reduced-x` against those of `pictures-x`, the session that presses the same keys from the same beginning with motion on | within 1 px | 2 |
| R3 | **No stage, no fade, no slide** with Reduce Motion (the options only) | Arbor's log has no "stage up"; no followed rectangle has more than two positions | so | 2 |

M1, M8, M9, M11, M13 and S8 are asked here too (S8 not in the dark scenes: on a light wallpaper shadows fill the gaps, and no ruler can measure them). **R5 is the second build's mark** (the product owner, 2026-10-15): size and place are two askings, so the state between them must lie within the old frame or the new one; what grows is seen to before what leaves is
sent away; tiles come at once. R4, none at all, stays the aim: `fill`, `everything` and `back` show that it can be had.

**R5 has one exception** (the product owner, 2026-10-15), told by its predicate and not by a list of acts: a window may show its new size at its old place if it grows (wider or higher by half a point or more) and its new frame lies within no display's room
(x from the display's left to its right edge, y from its top to the visible frame's bottom). macOS cuts growth at the display's edge once the window stands there, and a size lost for good outranks a frame seen for a moment. It excuses only the new size at the old
place: a hole, an empty desk or a stray anywhere else in the same act is booked as ever, and R4 books the frame all the same. The ruler counts how often the exception was used and prints it beside the verdict and under the score: an exception that nobody counts grows.

### Motion, an option: asked of every scene in which Arbor moves windows with `animationDuration` above 0

The **cause** is the key going down, or the button coming up. **Followed** means: every flat rectangle in the room between menu bar and Dock is boxed in
every frame and linked from frame to frame; each of its edges that travels at least 24 points gives a road, from 0 (where it was) to 1 (where it stays).

| # | What | How it is measured | Passes when | Severity |
|---|---|---|---|---|
| M1 | **It answers at once** | cause → the first frame in which at least 150 pixels of the room differ | ≤ 100 ms | 2 |
| M2 | **It lasts about 460 ms** | the roads' median progress is fitted with the usual timing curves; the best fit's duration is what the motion was meant to last (the last tenth of an eased motion covers less than a pixel, so what is seen is shorter) | 400 to 520 ms | 2 |
| M3 | **It is eased**: quick off the mark, gentle at the end, never past it | time from 50% to 95% of the road, over time from 5% to 50% (1.0 for linear and for ease-in-out); the furthest point beyond the end; the largest step backwards; the largest share of the road in one frame | ratio ≥ 1.4; ≤ 2 px beyond or backwards; ≤ 34% in one frame | 2 |
| M4 | **One motion per action**: a window moves once, to where it ends up, and all move together | spells of change after the first (the heads-up line's fade does not count); speed that rises threefold again after its peak with more than 40 px to go; the widest gap between two roads' progress at one moment; for edges that enter or leave over the display's edge, the distance from the straight line that ties them to the others' progress | none; none; ≤ 10%; ≤ 6 px | 1 |
| M5 | **It is smooth**, with four windows and with eight | the longest wait between two frames from the first movement to 95% of the road; a standstill of more than 120 ms after which a fifth of the room or more changes at once | ≤ 2 frames (35 ms); none | 2 |
| M6 | **No hop at either hand-over**: the stand-in begins where the window is, and the window is where the stand-in ends | at the end: a step of 3 px or more, at three times the speed before it, with 40 px or less to go. At the start: a first step larger than the second (a glide gathers speed). All the while: how far an edge that ends where it began is from there | none; none; ≤ 2 px | 1 |
| M7 | **What changes its look does so softly.** Arbor never asks for Screen Recording, so what ships travels as a card in the app's colour with its icon: window to card and card to window are fades | in a patch at the lower left of each followed rectangle, away from title bar, words and icon: the largest step of its mean colour between two frames | ≤ 10% of full scale (a fade of about 130 ms or more) | 1 |
| M8 | **Nothing flickers** | a followed rectangle missing from a frame in which its place shows the wallpaper, and back within 220 ms | never | 1 |
| M9 | **Nothing flashes**, least of all on its way out of view | a flat thing of at least 0.6% of the room that is there for 130 ms or less, whose place plainly looked otherwise just before and just after, and that is not the first or the last of something that comes or goes over the room's edge; or two fifths of the room being something else for 130 ms or less and then what they were | never | 1 |
| M10 | **At rest soon** | cause → the last frame of the first spell of change (stand-ins gone, ring drawn) | ≤ 700 ms | 3 |
| M11 | **The menu bar and the Dock are left alone** | of what each showed when the film began, the share that is plainly another colour at any moment. The bar is all its own; the Dock's own are its icons, told by their colours: its plate is glass, and shows what passes under it, as it does with any window | ≤ 25% of the bar (clock, recording dot, Arbor's item, the app's name); ≤ 10% of the icons | 2 |
| M12 | **A window looks like itself all the way** | whether a followed rectangle is plainly another colour on the way. Takes pictures of windows, which take a permission Arbor does not ask for: reported, never a condition | never | 3 |
| M13 | **Nothing is left behind** | Arbor's own windows on screen when the film ends, as the window server lists them | no stage, no drop preview | 1 |

What the ruler does not see: a sliver under 60 px at the room's edge that shows for a moment (it cannot be told from the first of a window that comes in); anything
on a wallpaper that is not plain; windows whose content is not flat. Those are for eyes.

### Drags: the pointer is the person's

| # | What | How | Passes when | Severity |
|---|---|---|---|---|
| D1 | **Arbor never pulls what is being dragged** | while the button is down, in the frames in which all of the window is seen as it was taken: its left and its bottom against where the pointer, at the grip it took, has had them in the last 100 ms (macOS's own dragging trails the pointer; `drag-alone`, which Arbor leaves alone, came to 1 px) | within 6 px | 1 |
| D2 | **The preview tells the truth** | the preview panel's frame while held, against the window's rectangle at rest | within 2 px | 2 |
| D3 | **The preview comes and goes softly, once** | by eye, until the ruler can: the frames while the button is down | one fade in of 80 to 250 ms; no blink; no second coming while the pointer rests | 2 |
| D4 | **Others make room in one motion** | by eye, until the ruler can: the windows that are not dragged, while the button is down | they move once, eased, together, or not at all | 1 |
| D5 | **In a plain drag nothing of Arbor's is on screen** | Arbor's own windows while the button is down, as the window server lists them | no preview, no stage, no line of words | 1 |
| D6 | **After a plain drag the window is where it was let go** | its frame before and after against where the button went down and came up; the other windows' frames | moved by what the pointer moved, within 2 px, its size its own, floating; no other window elsewhere | 1 |

After the button comes up, M1 to M13 are asked with that as the cause.

### Panels: whatever Arbor draws of its own

| # | What | How | Passes when | By | Severity |
|---|---|---|---|---|---|
| P1 | **There at once, gone at once** | every key or click → the first change after it; first → last change of that spell. (Never for a moment only is M9's; nothing left behind is M13's) | ≤ 100 ms; ≤ 250 ms | ruler | 2 |
| P2 | **It fades or it is there; it does not jump** | the changed box from frame to frame while it comes | the same box throughout (or an eased slide: M3) | ruler | 2 |
| S1 | **Crisp at 1x and 2x** | across every straight edge at least 60 px long with a step of 60 levels or more: the pixels between 10% and 90% of the step | ≤ 1 device pixel | stills | 2 |
| S2 | **On the pixel** | the window server's frame of every panel; half-covered rows or columns along its straight edges | whole points; none | stills | 3 |
| S3 | **Text is never clipped** and never touches an edge | the box of the ink (pixels 60 levels from the panel's ground) against the panel's own | ≥ 6 pt at the sides, ≥ 3 pt above and below; with the longest words there are, and at the largest text size | stills, eyes | 1 |
| S4 | **It can be read**, flat and on glass | contrast of ink to ground (WCAG), the ground being what the display shows behind the ink | ≥ 4.5 : 1 for words one must read to act; ≥ 3 : 1 for secondary ones; nothing under 3 | stills | 2 |
| S5 | **Light and dark** | S1 to S4 in both; the ground's lightness follows the system's | so | stills | 2 |
| S6 | **Increase Contrast is honoured** | with it on: contrast to what is outside of the line at each panel's side (of its ground, where it has no line of its own); of ink to ground | ≥ 3 : 1; ≥ 7 : 1 | stills | 2 |
| S7 | **Reduce Transparency is honoured** | with it on, over windows of strong colours: how much a panel's ground varies with what lies behind it | ≤ 2 levels, within a stretch of ground and between stretches over different colours | stills | 3 |
| S8 | **Even gaps** | at rest: the gaps between neighbouring windows and to the room's edges | all equal to `gap` within 1 px | ruler | 3 |

**The ruler's error.** Tried on 1,800 lines of words drawn in known colours, the contrast `stills.py` reads in a line's worst strip is 2% low in the middle and no more than 4% low in 19 lines of 20. A reading
up to 4% under a mark reaches it.

**Where macOS draws its own control in its own colour, macOS is the measure** (the product owner, 2026-10-15). "Nothing under 3" is written for what Arbor draws as text.
A disabled control as macOS draws it is no cell: it says "not now", and a brighter one would lie. A placeholder in macOS's own colour is exempt only where something else says
what the field is for (a magnifier, a label beside it). Where the placeholder is the field's only label it is a word a person must read in order to act, and it misses under 4.5. The cure is then not
a brighter placeholder, which would look typed, but a label or an icon that says it.

**Glass.** GitHub's Macs come with Reduce Transparency on, which draws every system material as one flat colour. A Mac does not come so: the films and the pictures
switch it off (`glass on`), and what ships is text on a material that lets through what lies behind it. So S4 is measured twice, flat and on glass, and on glass in
pictures of the **whole screen** over windows of strong colours: the picture the window server hands over of a panel alone shows the material without what is behind it.

### Fingers: what follows a gesture while it lasts

| # | What | How | Passes when | Severity |
|---|---|---|---|---|
| G1 | **It follows closely** | the script writes down what the fingers have said so far, event by event (`fingers.log` in the film's folder: `<ms> G <magnification> <pan x> <pan y>`); each stand-in's width in each frame is held against it | never more than 2 frames (35 ms) behind; no step over 2% of the width that the fingers did not make | 1 |

When the fingers come up (the mark `fingers up`), M2 to M13 are asked with that as the cause.

### Eyes: asked of every scene, on its sheet

| # | What to ask of the frames | Severity |
|---|---|---|
| E1 | **One thing happens, and one can tell what**: at every frame it is plain which window goes where; nothing crosses in front that belongs behind | 2 |
| E2 | **No frame is ugly**: no smeared or squashed text, no hole, no stray line, no half-drawn panel, no colour that belongs to nothing | 2 |
| E3 | **It could be macOS's own**: corners, shadows, materials, type and timing as the system's own windows and panels have them | 3 |
| E4 | **It says what is needed and no more**: words right, in the right place, over nothing one is looking at, gone in time | 3 |
| E5 | **Nothing is drawn that was not asked for**: name each thing of Arbor's in the frames (a line, a mark, a surface, a panel) and ask of each: would it be missed? | 2 |

A verdict by eye names the run, the scene and the frames, and says in a sentence what is there. "Looks fine" is not a verdict.

## The scenes

One scene is one thing a person does.

### The first column: what ships

**Gate** marks what the gate asks for: the nine keys, Go to…, the menu with its one icon, a plain drag, a drag with the key held. Those scenes are filmed twice: in light mode on a black wallpaper, and as `dark-…` in dark mode on a
light one, where shadows and dark lines show. The keys are asked of Arbor (`bindings`), so the films follow the map in effect; an act that no key does is not filmed, and scores nothing.

| Scene | Kind | What the person does | Gate |
|---|---|---|---|
| `dock-first`, `dock-second` | instant | docks a floating window at the left; a second one at the right | ✔ |
| `fill`, `everything`, `back` | instant | fills the screen with a docked window; shows everything again; fills, and goes back | ✔ |
| `float`, `undo`, `float-back` | instant | floats a docked window; undoes that; floats it, and takes it back in | ✔ |
| `pause`, `resume` | instant | pauses Arbor: every window gets its own size back; resumes | ✔ |
| `go-to`, `go-to-choose` | panel, instant | opens Go to…, closes it; with another window chosen in it, presses ↩ | ✔ |
| `menu`, `menu-arrange` | panel, instant | clicks the icon in the menu bar, closes the menu; chooses Arrange Windows with four floating windows | ✔ |
| `drag-plain` | plain | drags a floating window over a docked one, waits, lets go. Nothing was asked of Arbor | ✔ |
| `drag-held` | drop | the same with ⌘ held: the preview comes, and letting go docks | ✔ |
| `drag-out` | out | drags a docked window out, plainly: nothing of Arbor's shows meanwhile; it floats at its own size where it was let go, and its place closes at once | ✔ |
| `dock-third`, `dock-fourth`, `dock-fourth-again` | instant | more docks than the display has room for: every window becomes a tile; the same a second time in the session | |
| `close`, `quit` | closes, told | closes a docked window (macOS fades it out over whatever Arbor does beneath: no ruler can part the two, so R1, R4 and R5 are not asked); quits Arbor: every window gets its own size back (no key says when: M1 is not asked) | |
| `eight-arrange`, `eight-fill`, `eight-everything` | instant | the same with eight windows on a display of 1920 × 1080 | |
| `macos-left`, `macos-right`, `macos-fill`, `macos-previous`, `macos-left-and-right` | bare | macOS's own tiling of the same windows, Arbor not running: the bar. Not counted | |
| `ground`, `dark-ground` | bare | the bare desk, before a session's first window opens: the wallpaper as the display shows it, which the judge cannot tell any more once shadows lie on what is left of it. Not counted | |
| `metronome-…` | control | the camera's own square: tests the instruments, not counted | |

The panels of the first column: the menu, the drop preview, a tile, Go to…, the heads-up line, the coach, the setup check, the settings window.

### The second column: the options

**Move** marks the scenes that stand for the five moves of the reference's public how-it-works page, in its order, as Arbor does them with everything switched on. The reference is compared only by what that page shows and says, never by its assets
or code; this page describes only Arbor. The scenes of the five moves, and `frame`, are filmed in light and in dark.

| Scene | Kind | What the person does | Move |
|---|---|---|---|
| `tab-make`, `tab-change`, `tab-drag-group` | drag, structure, drag | drops a window on the middle of another; ⌃⌥⇥; drags the group to an edge | 1 (not landed: unseen) |
| `dock-drag-edge` | aside | drags a window to the left edge of the screen, waits, lets go. On a Mac as it comes that edge is macOS's: it tiles the window, Arbor stands aside and says so. What moves is macOS's to answer for; asked of Arbor: M1, M8, M9, M11, M13, and by eye whether a stranger understands what happened and what to do next. With everything on it is a `drag` like the others | 2 |
| `dock-drag-beside` | drag | drags a window onto a part of a docked one: a space inside a space | 2 |
| `rearrange` | drag | drags a docked window to another place | 2 |
| `tile`, `tile-open`, `tile-back` | structure, camera, camera | docks a window that is too large for its slot; clicks the tile; ⌃⌥[ (light only) | 2 |
| `double-click-desktop`, `double-click-again`, `double-click-title` | camera | double-clicks the Desktop; again; a title bar | 3 (not landed: unseen) |
| `rectangle`, `save-view`, `view` | drag, panel, camera | ⌃⌥ and a drag over two windows; ⌃⌥⇧1; later ⌃⌥1 | 4 |
| `show-everything` | camera | ⌃⌥Space | 5 |
| `pinch-in`, `pinch-out` | camera | ⌥ and two fingers apart, together | 5 |
| `zoom-continuous` | follow | a slow pinch, held half-way, let go | 5 (not landed: unseen) |
| `frame` | camera | ⌃⌥↩ | |
| `dock-key` | structure | ⌃⌥⌘← on a floating window | |
| `neighbour`, `back`, `out`, `in`, `desktop`, `desktop-back` | camera | ⌃⌥→, ⌃⌥[, ⌃⌥↑, ⌃⌥↓, ⌃⌥D, ⌃⌥[ | |
| `twice-quickly` | camera | ⌃⌥↩ and, 0.2 s later, ⌃⌥Space: the second carries on from where things are | |
| `peek` | hold | holds ⌃⌥Space, an arrow meanwhile, lets go | |
| `seam`, `drag-out` | drag | drags a seam; drags a docked window out | |
| `float`, `undo`, `close` | structure | ⌃⌥F, ⌃⌥Z, closes a docked window | |
| `panel-shortcuts`, `panel-go-to`, `panel-minimap`, `panel-menu` | panel | opens it, closes it | |
| `quit` | instant | quits Arbor: every window gets its own size back, at once | |
| `reduced-dock-key`, `reduced-frame`, `reduced-show-everything` | instant | the same keys with Reduce Motion on | |
| `eight-frame`, `eight-show-everything` | camera | the same keys with eight windows docked on a display of 1920 × 1080 | |
| `on-…`, `on-dark-…` | | the scenes of the moves with the gestures on and macOS's own tiling off: where one was filmed it is the one that counts | |
| `pictures-…` | | the same with `windowPictures`, which ships off: judged and reported, **not counted** | |
| `drag-alone` | bare | a drag that Arbor leaves alone (⌘ held): what macOS does by itself, to hold D1 against. Not counted | |
| `metronome-…` | control | the camera's own square: tests the instruments, not counted | |

The panels of the second column: a seam, the focus ring, the peek's outline, the rectangle, the minimap, the shortcuts, the name field, the tab strip. Five of all sixteen (the preview, a seam, the ring, the peek's outline, the
rectangle) have no words and no ground of their own: S3, S4 and S7 have nothing to ask of them and are no cells there; nor are S3 and S4 for the minimap, which has no words. The pictures are the gallery's (branch `gallery/pictures`, `collab/evidence/gallery`); reviewers
with eyes name the rectangles and `scripts/polish/stills.py` measures inside them (`scripts/polish/REVIEWERS-STILLS.md`).

## The score

Every check that is asked of a scene is a cell. A cell that passes earns its severity's points; a miss, or a cell nobody could see,
earns nothing. **Score = 100 × points earned ÷ points there are**, in the first column. `judge.py score <run of films-light.sh>` prints the table, the findings with the frames that show them,
and the number, and how much of the table has been seen at all; `judge.py score --options <run of films.sh>` does the same for the second column.

**The rubric passes** (issue #4, "Definition of viable"; `docs/VIABLE.md`) when no cell of severity 1 or 2 in a scene the gate asks for, light or dark, misses or is unseen, and the score is at least 90.

**It only goes up.** The last line of the scoreboard below is the floor. A run that scores lower names the commits since that line, and the finding goes to
whoever owns them before anything else does. New scenes and checks are added with their cells unseen and the floor is restated on the same films under the
new table, in the same commit, so that a longer table is never mistaken for a worse Arbor.

## The loop

1. Film: `scripts/mac-shell/run.sh scripts/mac-shell/films-light.sh` (for an option: `films.sh`) on the trunk, or on a branch that claims to raise the score.
2. Judge: `scripts/polish/judge.py score .mac-shell/films-<run>`; then every scene's sheets (`judge.py sheets`), by reviewers with eyes who have built none of it. They give E1 to E5,
   and they confirm or refute **every miss the ruler claims**: the ruler follows flat rectangles, and overlapping cards, a preview's tint or a title bar in shadow fool it. A refuted miss
   counts as unseen, not as passed, and the ruler is mended. Verdicts into `collab/polish/eyes-run-<n>.json`, the report into `collab/polish/run-<n>.md`.
3. Findings become small pull requests, each naming the cell it turns green and the frame that showed the fault.
4. Film again. The pull request lands when the cell is green and no other cell has turned.

## Scoreboard

### From the second build on: what ships

| Date (UTC) | Commit | Score: what ships | The options | Seen | Severity 1 misses | Cells the gate still wants | Note |
|---|---|---|---|---|---|---|---|

### The first build (closed)

By the table as it was then: one list of scenes, the five moves of the reference as the gate, ring and cards counted as shipped. 44.6 stands as the first build's last score.


Restated on 2026-10-15 under the table as it is now (S4 on glass and S7 added; the drag to an edge asked as `aside`; no cells where a panel has no words to read or no ground to see through) and by the judge as a second review left it (a film in which no window moves earns nothing; of two keys in a row the second's answer cannot be told): run 1 was 36.6 and run 2 was 42.8 as they were first scored. In both, gestures still shipped on and the edges were Arbor's, so the two columns are one.

| Date (UTC) | Commit | Score, as it ships | With everything on | Seen | Severity 1 misses | Note |
|---|---|---|---|---|---|---|
| 2026-10-14 23:27 | `a391fe4` | **36.2** | 36.2 | 49% | 36 | Run 1 (`collab/polish/run-1.md`). Tabs, double clicks, the followed pinch and all stills unseen; four films void |
| 2026-10-15 01:38 | `302a0b0` | **41.9** | 41.9 | 54% | 40 | Run 2 (`collab/polish/run-2.md`). A cast of four apps, panels in the picture; two films void |
| 2026-10-15 05:00 | `302a0b0`, pictures of `5f18637` | **44.6** | 44.6 | 59% | 41 | Run 2's films, and for the first time the pictures at rest (`collab/polish/stills-1.md`): 56 of 125 cells seen, 38 pass |
