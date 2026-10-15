# Report: board 1.5, a click on the wallpaper sweeps every window aside

- Date: 2026-10-14
- Executor: a fixer session
- Branch: `fix/a-window-that-comes-back-is-no-drag`
- Board item: 1.5 (rules 1 and 3); the product owner's decision is Q24
- Spec: none; `docs/ARCHITECTURE.md`, "Drag and drop"

## The question only a Mac could answer

What do Accessibility, the window list and the workspace report during and after a sweep; what tells a sweep from a person who
moves windows; what becomes of a frame that is set meanwhile; what ends a sweep; what does Arbor do today?

One run on a hosted Mac (macOS 26.6.2, 1024 × 768, "click wallpaper to reveal desktop" not set, which is on; Reduce Motion off), 22 sweeps.
The probe and its tool, which writes down both views of every window sixty times a second with every notice that arrives,
are on the branch `probe/the-desktop-is-shown` (`probe-sweep.sh`, `twoviews.swift`). An ordinary day with nine real apps on 1600 × 900 showed the same.

## What it answered

**A sweep is a picture.**

| | The window list | Accessibility |
|---|---|---|
| The sweep begins | every window at the side of its display, in one sample, 80 to 300 ms after the button came **up**; sizes unchanged; still "on screen" | the frames from before; no `AXMoved`, no `AXResized` |
| A frame is set through Accessibility, or the app moves its window | nothing changes, not even the size | the new frame, at once, with the usual notifications |
| The sweep ends | every window where Accessibility has it, in one sample | nothing |

- **Where to:** away from the middle of the display: left, right, up or down, until 12 points show (below the menu bar if it went up). It also
  drifts along the edge, by up to some hundred points.
- **What ends it:** a click on the wallpaper (the list changes about 70 ms after the button came up); a press on the strip of a window (about 27 ms
  after the button went **down**; macOS keeps the click, Finder stays in front); ⌘Tab; an app that really comes forward, which is what Arbor's
  `focus` brings about.
- **What does not:** `AXRaise`, minimizing and restoring, a frame that is set, twelve seconds. A window that opens meanwhile opens in view, and is
  swept with the others the next time.
- **What is reported:** what a click on the wallpaper always brings (Finder active, the app from before not). And the Dock does say it: the
  Accessibility notifications `AXExposeShowDesktop` and `AXExposeExit` on the Dock's application element, one each per sweep, 120 to 230 ms **after** the
  list changed. A window of the Dock's as wide as the display, at level 18, is listed for as long as the sweep lasts. Arbor uses neither.
- **F11** (Show Desktop) is the same thing. **Reduce Motion** changes none of it.
- **Arbor's own panels** (gap handles, the surface behind docked windows) go with the windows and come back with them; the focus ring goes when
  Finder takes the keyboard. Nothing of Arbor's stays on the bare desktop.

**Arbor as it was** ended ten cases right: left alone, a window closing, `dock`, `zoom` and `show-all`, `focus`, `pause`, Quit, each while swept. Every
window changed its place on screen once: from the side to where it belonged.

**The one fault:** a press on a docked window's strip that slipped by three points. The list had the window leap 325 points with the button down,
`AXWindowSystem` asked `WindowGrab.classify`, which called every move a drag: `dragBegan`, a drop preview, `dragEnded`, "moved by the user".
On that run the drop fell on the window's own slot. On the stand-ins, which now sweep as the Mac did, the same click on a **floating** window's strip
docks it at the edge of the display and resizes everything else.

## What changed

- The design. "Arbor moves nothing while the windows are swept" is withdrawn by the product owner: a move made meanwhile shows nowhere, and one put
  off until they are back would be a jolt. Instead: **while swept Arbor goes by Accessibility, never by the window list.**
- **A press on a strip takes hold of nothing.** `AXWindowSystem.makePress` (three lines) asks `WindowGrab.isListedElsewhere`: a window that the
  window server lists more than 32 points from where Accessibility last had it is a picture of a window. This is what the backlog's K2015
  proposed, "if its premise holds". It holds.
- **A window that leaps is not in the hand**, whatever made it leap. `WindowGrab.classify`: moved farther than the pointer went, by more than 32 points,
  with its size unchanged, is `.neither`. Either rule alone stops the fault the Mac showed; the first also covers a window that was laid out
  meanwhile and comes back with another size, the second a list that changes between the press and Arbor's look at it.
- **No stage over the bare desktop.** A layout is shown as motion on a stage that covers the display, and a panel that is put up during a sweep shows,
  as a window that opens does. `stageTransition` asks the new `SweptAside.isSwept` (ArborCore) about the list it reads anyway, and moves the windows at once.
- `FakeWindowSystem+SweptAside.swift`: `clickOnTheWallpaper()`, `pressShowDesktopKey()`, `clickOnTheStrip(of:at:slippingBy:resting:)`, which asks the judges the
  Accessibility layer asks; `stackedWindows()` lists what the window server would.
- arbor-fakemac (K220): the list stays as it was for as long as the sweep lasts; four directions; a press on a strip, and the first move of a real
  drag, are judged by the same `WindowGrab`.
- `scripts/mac-shell/check-sweep.sh`.

## Evidence

- Failing first, each with its own rule switched off: four tests in `WindowGrabTests` with the Mac's own numbers; of the real controller on the stand-ins,
  `SweptAsideTests.aClickOnAStripThatSlipsIsNoDrag` (preview, arrangement, frames: a mere click docks a floating window),
  `norIsOneOnTheStripOfAWindowThatWasLaidOutMeanwhile`, `whatHappensMeanwhileIsLaidOutAtOnce…` (the stage); the rehearsal of `check-sweep.sh`.
- Controls that must go on passing: a drag that is flung, one that the menu bar stops, the same layout shown as motion with nothing swept.
- Real windows: `check-sweep.sh` on a hosted Mac (macOS 26.6.2, as it comes), 62 of 62, with the sampler of the ordinary day beside it. In each of seven sweeps every
  window changed its place in the window server's list exactly twice, out and back, also the one during which Arbor laid out. By the trace Arbor was told of
  no drag, no resize and no window moved by hand, showed no preview, and through the five sweeps in which nothing was asked of it set no frame. The stage
  went up for a `resize` with nothing swept, and not for the same while swept. Two real drags, one of them flung, were drags. The first seven steps are
  `collab/evidence/traces/desktop-shown.jsonl`. (A first run came to 61 of 62: the control for the stage minimized a window, the Dock grew by it, the display's
  visible frame with the Dock, and a layout for another frame is never shown as motion.)

## Afterwards: a press that is served late (2026-10-15)

The first rule had a hole, found on the model of a Mac that runs the real Accessibility layer (`make mac-on-linux`). A busy Mac serves a press late. By then a
window that is really in the hand has gone some way, its app has not been heard, and the window server lists it "elsewhere": the press took hold of
nothing, and **the drag was lost**, with nothing logged. For the same reason a second try at a late press (at the pointer's place of now, when no window lies
under the press's own place any more) cured nothing, lost a drag that used to be seen, and had been taken out again.

Putting that second try back without the rule for strips, which was the plan, does not do. Two reviews, each with stories of its own on the model, showed that it
takes hold of whatever the pointer has come to, forgets the place of the press when it finds nothing, and never runs when another window shows at that place,
which under a floating window over tiles is always. And late presses turned out to lose more than drags, most of it older than the rule:

| A press heard 300 or 500 ms late, or Arbor's main thread busy for 300 ms from the press | Before |
|---|---|
| a window dragged away from under the place of the press, heard late | no drag |
| a window dragged **sideways**, which stays under that place | no drag: "listed elsewhere" |
| a window that **lies over another** (a floating one over tiles) | no drag: the press takes hold of the window below |
| a tall window dragged up against the menu bar, the pointer going on into it | no drag: "listed elsewhere" |
| a window **flicked**, or dragged and held still, the gesture over when the press is served | no drag |
| a window **made wider by its left edge** | **a drag**, which ends in a drop |

**What changed.** The decision is out of the Accessibility layer. `makePress` reads the list once, and what shows at the press and at the pointer;
`WindowGrab.hold` (ArborCore, tabled in `WindowGrabTests`) says what the press takes hold of:

- **A window in the hand goes first**, under the pointer or still under the press. It is known by being ahead of its app's word, the way the pointer went and no
  farther. It is judged from the place of the press and **its app's last word**, which is the nearest there is to the frame it had at the press, and is that
  frame if Arbor was too busy to hear more. So the way it has come counts, and a gesture that is over by then is still seen.
- **An edge that has left the press behind** (its app heard meanwhile) is judged from where the pointer is, if the pointer is at an edge and the press is not.
- Otherwise the press is looked for at its own place, under the rule for strips, as before; and if nothing is found it keeps its own place, which is what a
  report from a window's app is held against.
- **Nothing is made of a few points**: the pointer must have gone more than 24, the window be 10 ahead. A press on time comes with a tremble, and the two frames of a
  window at rest may differ a little; to go by the app's word then would make a drag of the difference.
- **A window that the pointer has merely come to is not in the hand**: it is where its app says. (A rubber band over the icons on the desktop.)
- **No strip is**: it can only be pulled inwards, the other way than its window was swept. That does not rest on the 27 ms, which were measured on a Mac at rest.
  More than 100 points ahead, a window must also have been under the press by its app's word, so a pointer that comes to a strip from the bare desktop finds nothing.

**Evidence.** All on the model, which no Mac can be asked for: lateness to order.

- **The model shows its desktop** (`FakeMacOS/DesktopShown.swift`: the key, and a press on a strip). `tests/DesktopShown.swift`: a click that slips and a pull at a strip,
  heard 0, 20, 100 and 500 ms late and with the main thread busy, in all three orders; a Mac that takes 400 ms to bring the windows back; a window given another
  frame meanwhile; with the real controller, a floating window's strip. In `tests/LatePresses.swift`, a rubber band from the bare desktop that comes to a strip.
- `tests/LatePresses.swift` and more of `tests/LostDrags.swift`: with the above, 161 new stories. **55 checks are red on the trunk's layer and green on this one, none the other
  way** (`REF=origin/swarm/trunk make mac-on-linux`: 1434 ✔ against 1489 ✔). 36 checks of the new stories are red on both, none of them a drag or a resize that was not
  one, each listed in `known-failures.txt` with its reason. Six lines that stood there are cured and gone.
- Of the stories that were there before, the layer reports something else in six: four drags seen sooner or at all, two flicks seen at all
  (`collab/evidence/mac-on-linux/heard.jsonl`).
- 3,000 random gestures (title bar, four edges, content, wallpaper; alone, over another window, beside a tile; eight kinds of lateness; windows and apps that start
  late), played on both layers by the second review and again on the last state: **547 come out right that came out wrong, 11 the other way**. Nine of
  the 11 are drags there and back, which the measure took for nothing. Two are real: see below.
- Three changes in `mutants.py` take the rules out one by one, and the stories about them go red.

**Still lost**, as before: what is at rest when the press is served and is dragged on afterwards; an edge that takes the window's place nowhere (right, bottom) or has left
the place of the press, once its app has been heard; a window stopped by the menu bar with its app heard first. **Worse than before**, two in 3,000: a window
over another whose window server starts 400 ms late **and** whose press is served 300 ms late, with the pointer near one of its edges by then, is judged from
there, and the drag is not seen.

## Not done, and why

- **A leap of less than 32 points.** A window that hangs off its display with 40 points showing is swept until 12 show. A click on its strip that slips is
  still a drag.
- **During a pause** Arbor looks in the window list for a window that left full screen into the corner, and for one whose app hung when the pause
  began, and fetches what it finds out of view. Both are after windows that **are** out of view, and fetching those is right, swept or not, and unseen.
  To fetch one that was not lost it takes a window that somebody else has brought into view, in the seconds before Arbor's next look, and a sweep.
- **The keyboard's heir.** When the window that had the keyboard **last** closes or is minimized, Arbor gives the keyboard to another in view, also when
  Finder has had it since. During a sweep that brings everything back, uninvited; without one it takes the keyboard from the desktop. Older than
  this, and not about sweeps: told to the coordinator, with a script.
- **`guardDesktopClicks`** (off, an experiment): after F11 a click on what Arbor believes to be bare Desktop would be kept from macOS, and so not bring
  the windows back. For whoever switches the guard on.
- **Two displays**, and a sweep while the view is on one window: not tried on a Mac.
- The backlog's rows K001, K2015 and K220 are about this. That page is generated, so they are not edited here.
