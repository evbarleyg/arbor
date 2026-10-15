# Polish: what consumer-grade means for Arbor, in checks

Tests say whether windows end up in the right places. This page says whether getting there **feels right**, and it says so in
checks that nobody has to be asked about: a hosted Mac films Arbor, and agents judge the films and pictures in a sandbox,
with a ruler wherever a ruler can settle it and with their eyes, frame by frame, for the rest. The maintainer is never asked to look.

The result is one number, the **polish score**. It is on the scoreboard, and it only goes up: a change that lowers it is a
regression, found before it lands, like a failing test.

| | |
|---|---|
| What Linux proves | that the film script plays (`scripts/mac-shell/rehearse.sh scripts/mac-shell/films.sh`) and that the judge catches what it claims to catch (`scripts/polish/judge.py --self-test`: 32 drawn films, each wrong in one known way or right) |
| What a Mac must run | `scripts/mac-shell/films.sh`: unattended, on a free hosted runner, one run for everything, under ten minutes. It only records |
| What the sandbox judges afterwards | everything: `scripts/polish/judge.py score <run folder>`, then the sheets, by eye |

## How bad a miss is

| Severity | Means | Costs |
|---|---|---|
| 1 | Anybody sees it the first time, and it looks broken: a flash, a hop, a window that turns into something else, two motions for one key | 5 points |
| 2 | Felt within a day of use, even by somebody who could not name it: sluggish, abrupt, stuttering, hard to read | 3 points |
| 3 | A designer would circle it: a pixel off, a corner that is not concentric, a word too many | 1 point |

**What could not be seen counts as a miss.** A film that was not shot, a scene for a feature that has not landed, a window the
judge lost track of, a sheet nobody has gone through: all score nothing. So the score cannot be raised by looking at less, and
the scenes for tabs, double clicks and continuous zoom are in the sum from the first day.

## The laboratory

- **The Mac**: GitHub's `macos-26` runner, one display of 1024 × 768 at 1x; a virtual Retina display for pictures at 2x. macOS at
  its default settings (its own edge tiling on, click-wallpaper on), except Reduce Motion, which the runners come with and the script switches off.
- **The windows**: `ArborTestWindows`, each one flat colour, on a plain wallpaper: a window is then a rectangle that a script can find in every
  frame to the pixel. Each is an app of its own (`cast_start`), with a name and an icon in the window's colour, because a person's windows are not all
  one app's, and cards that all look alike are harder on the eye, and on the ruler, than anybody's desk.
- **The hand**: real keys and a real pointer (`pointer.swift`, `witness.swift`), one thing a person does per scene. Never the command behind the key.
- **The camera** (`scripts/mac-shell/camera.swift`): every frame ScreenCaptureKit delivers, up to 60 a second, lossless, each with the moment the display
  showed it; and, from an event tap at the head of the chain, the moment each key and button went down or up. Screen Recording is the one permission
  it needs, and child processes on the runner have it.
- **The metronome**: before Arbor is filmed, the camera films a square of its own that moves in a way that is known: once as this page asks
  (460 ms, Arbor's curve), then wrong in five ways (linear; 900 ms; in two pushes; a 9-pixel hop at the end; a flash of two frames). If the judge does
  not find exactly those faults in those films, **the run's score is void**. What the good film shows of delay and of waits between frames is the
  camera's and the runner's doing, and is allowed to Arbor's films as well.
- **A film** is a folder of PNGs (the first frame whole, then only the pixels that changed) and `film.log`, in the grammar of the window sampler's log
  (`<ms since 1970> <kind> …`), so that the two merge by time. `camera.swift`'s header has the details.

## The checks

**By**: *ruler* = `judge.py` measures it; *eyes* = an agent goes through the sheets (`judge.py sheet`) and writes the verdict, with the
frames that show it, into `collab/polish/eyes-run-<n>.json`; *stills* = measured on pictures of each panel alone (the gallery's `*-alone-*.png`).

### Motion: asked of every scene in which Arbor moves windows

The **cause** is the key going down, or the button coming up. **Followed** means: every flat rectangle in the room between menu bar and Dock is boxed in
every frame and linked from frame to frame; each of its edges that travels at least 24 points gives a road, from 0 (where it was) to 1 (where it stays).

| # | What | How it is measured | Passes when | Severity |
|---|---|---|---|---|
| M1 | **It answers at once** | cause → the first frame in which at least 150 pixels of the room differ | ≤ 100 ms | 2 |
| M2 | **It lasts about 460 ms** | the roads' median progress is fitted with the usual timing curves; the best fit's duration is what the motion was meant to last (the last tenth of an eased motion covers less than a pixel, so what is seen is shorter) | 400 to 520 ms | 2 |
| M3 | **It is eased**: quick off the mark, gentle at the end, never past it | time from 50% to 95% of the road, over time from 5% to 50% (1.0 for linear and for ease-in-out); the furthest point beyond the end; the largest step backwards; the largest share of the road in one frame | ratio ≥ 1.4; ≤ 2 px beyond or backwards; ≤ 34% in one frame | 2 |
| M4 | **One motion per action**: a window moves once, to where it ends up, and all move together | spells of change after the first (the heads-up line's fade does not count); speed that rises threefold again after its peak with more than 40 px to go; the widest gap between two roads' progress at one moment; for edges that enter or leave over the display's edge, the distance from the straight line that ties them to the others' progress | none; none; ≤ 10%; ≤ 6 px | 1 |
| M5 | **It is smooth**, with four windows and with eight | the longest wait between two frames from the first movement to 95% of the road | ≤ 2 frames (35 ms) | 2 |
| M6 | **No hop at either hand-over**: the stand-in begins where the window is, and the window is where the stand-in ends | at the end: a step of 3 px or more, at three times the speed before it, with 40 px or less to go. At the start: a first step larger than the second (a glide gathers speed). All the while: how far an edge that ends where it began is from there | none; none; ≤ 2 px | 1 |
| M7 | **What changes its look does so softly.** Arbor never asks for Screen Recording, so what ships travels as a card in the app's colour with its icon: window to card and card to window are fades | in a patch at the lower left of each followed rectangle, away from title bar, words and icon: the largest step of its mean colour between two frames | ≤ 10% of full scale (a fade of about 130 ms or more) | 1 |
| M8 | **Nothing flickers** | a followed rectangle missing from a frame in which its place shows the wallpaper, and back within 220 ms | never | 1 |
| M9 | **Nothing flashes**, least of all on its way out of view | a flat thing of at least 0.6% of the room that is there for 130 ms or less and neither comes nor goes over the room's edge | never | 1 |
| M10 | **At rest soon** | cause → the last frame of the first spell of change (stand-ins gone, ring drawn) | ≤ 700 ms | 3 |
| M11 | **The menu bar and the Dock are left alone** | the most pixels that change at once in either strip | ≤ 6000 px (clock, recording dot, Arbor's item); ≤ 1500 px | 2 |
| M12 | **A window looks like itself all the way** | whether a followed rectangle is plainly another colour on the way. Takes pictures of windows, which take a permission Arbor does not ask for: reported, never a condition | never | 3 |
| M13 | **Nothing is left behind** | Arbor's own windows on screen when the film ends, as the window server lists them | no stage, no drop preview | 1 |

What the ruler does not see: a sliver under 60 px at the room's edge that shows for a moment (it cannot be told from the first of a window that comes in); anything
on a wallpaper that is not plain; windows whose content is not flat. Those are for eyes.

### Without motion: Reduce Motion, `animationDuration` 0, quitting

| # | What | How | Passes when | Severity |
|---|---|---|---|---|
| R1 | **The end at once, nothing in between** | first changed frame → last changed frame of the first spell | ≤ 100 ms | 1 |
| R2 | **The same end** as with motion | the last frame of `reduced-x` against the last frame of `x`, windows' rectangles | within 1 px | 2 |
| R3 | **No stage, no fade, no slide** anywhere, panels included | Arbor's log has no "stage up"; no followed rectangle has more than two positions | so | 2 |

M1, M8, M9, M11 and M13 are asked here too.

### Drags: the pointer is the person's

| # | What | How | Passes when | Severity |
|---|---|---|---|---|
| D1 | **Arbor never pulls what is being dragged** | while the button is down: the dragged rectangle's offset from the pointer, frame by frame | stays within 3 px of what macOS alone does (control: the same drag with Arbor paused) | 1 |
| D2 | **The preview tells the truth** | the preview panel's frame while held, against the window's rectangle at rest | within 2 px | 2 |
| D3 | **The preview comes and goes softly, once** | spells of change in the preview's rectangle while the pointer rests | one fade in of 80 to 250 ms; no blink | 2 |
| D4 | **Others make room in one motion** | M2 to M9 for the windows that are not dragged, from the moment the preview shows | as there | 1 |

After the button comes up, M1 to M13 are asked with that as the cause.

### Panels: whatever Arbor draws of its own

| # | What | How | Passes when | By | Severity |
|---|---|---|---|---|---|
| P1 | **There at once, gone at once**, and never for a moment only | cause → first change; first → last change of the coming, and of the going; how long it is up | ≤ 100 ms; each ≤ 250 ms; ≥ 100 ms, and gone 500 ms after what it belongs to is over | ruler | 2 |
| P2 | **It fades or it is there; it does not jump** | the changed box from frame to frame while it comes | the same box throughout (or an eased slide: M3) | ruler | 2 |
| S1 | **Crisp at 1x and 2x** | across every straight edge at least 60 px long with a step of 60 levels or more: the pixels between 10% and 90% of the step | ≤ 1 device pixel | stills | 2 |
| S2 | **On the pixel** | the window server's frame of every panel; half-covered rows or columns along its straight edges | whole points; none | stills | 3 |
| S3 | **Text is never clipped** and never touches an edge | the box of the ink (pixels 60 levels from the panel's ground) against the panel's own | ≥ 6 pt at the sides, ≥ 3 pt above and below; with the longest words there are, and at the largest text size | stills, eyes | 1 |
| S4 | **It can be read** | contrast of ink to ground (WCAG) | ≥ 4.5 : 1; ≥ 3 : 1 from 18 pt | stills | 2 |
| S5 | **Light and dark** | S1 to S4 in both; the ground's lightness follows the system's | so | stills | 2 |
| S6 | **Increase Contrast is honoured** | with it on: contrast of each panel's outline to what is around it; of ink to ground | ≥ 3 : 1; ≥ 7 : 1 | stills | 2 |
| S8 | **Even gaps** | at rest: the gaps between neighbouring windows and to the room's edges | all equal to `gap` within 1 px | ruler | 3 |

**Not scored: translucency and blur.** A hosted Mac draws every system material as one flat colour, in Arbor as in any app: the look of Reduce
Transparency. So text has to be legible in that flat look (S4), and what a material adds on a person's Mac is not judged here, by ruler or by eye.

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

A verdict by eye names the run, the scene and the frames, and says in a sentence what is there. "Looks fine" is not a verdict.

## The scenes

One scene is one thing a person does. **Move** marks the scenes that stand for the five moves of the reference's public how-it-works page, in its order, as
Arbor does them. The reference is compared only by what that page shows and says, never by its assets or code; this page describes only Arbor.
The scenes of the five moves, and `frame`, are filmed twice: in light mode on a black wallpaper, and as `dark-…` in dark mode on a light one, where shadows and dark lines show.

| Scene | Kind | What the person does | Move |
|---|---|---|---|
| `tab-make`, `tab-change`, `tab-drag-group` | drag, structure, drag | drops a window on the middle of another; ⌃⌥⇥; drags the group to an edge | 1 (not landed: unseen) |
| `dock-drag-edge` | drag | drags a window to a screen edge, waits, lets go | 2 |
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
| `pictures-…` | | the same with `windowPictures`, which ships off: judged and reported, **not counted** | |
| `drag-alone` | bare | a drag that Arbor leaves alone (⌘ held): what macOS does by itself, to hold D1 against. Not counted | |
| `metronome-…` | control | the camera's own square: tests the instruments, not counted | |

The panels that S1 to S6 are asked of: the heads-up line, the drop preview, a tile, a seam, the focus ring, the peek's outline, the rectangle, the minimap, Go to…, the
shortcuts, the name field, the menu, the settings window, the coach, the setup check, the tab strip.

## The score

Every check that is asked of a scene is a cell. A cell that passes earns its severity's points; a miss, or a cell nobody could see,
earns nothing. **Score = 100 × points earned ÷ points there are.** `judge.py score` prints the table, the findings with the frames that show them,
and the number; beside it, how much of the table has been seen at all.

**The rubric passes** (issue #4, "Definition of viable"; `docs/VIABLE.md`) when no cell of severity 1 or 2 in a scene of the five moves, light or dark, misses or is unseen, and the score is at least 90.

**It only goes up.** The last line of the scoreboard below is the floor. A run that scores lower names the commits since that line, and the finding goes to
whoever owns them before anything else does. New scenes and checks are added with their cells unseen and the floor is restated on the same films under the
new table, in the same commit, so that a longer table is never mistaken for a worse Arbor.

## The loop

1. Film: `scripts/mac-shell/run.sh scripts/mac-shell/films.sh` on the trunk, or on a branch that claims to raise the score.
2. Judge: `scripts/polish/judge.py score .mac-shell/films-<run>`; then every scene's sheets (`judge.py sheets`), by reviewers with eyes who have built none of it. They give E1 to E4,
   and they confirm or refute **every miss the ruler claims**: the ruler follows flat rectangles, and overlapping cards, a preview's tint or a title bar in shadow fool it. A refuted miss
   counts as unseen, not as passed, and the ruler is mended. Verdicts into `collab/polish/eyes-run-<n>.json`, the report into `collab/polish/run-<n>.md`.
3. Findings become small pull requests, each naming the cell it turns green and the frame that showed the fault.
4. Film again. The pull request lands when the cell is green and no other cell has turned.

## Scoreboard

| Date (UTC) | Commit | Score | Seen | Severity 1 misses | Note |
|---|---|---|---|---|---|
