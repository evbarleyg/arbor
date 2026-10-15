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

**What changed.** The decision is out of the Accessibility layer. `makePress` reads the list once, what shows at the press and at the pointer, and whether the desktop is
shown; `WindowGrab.hold` (ArborCore, tabled in `WindowGrabTests`) says what the press takes hold of:

- **A window in the hand goes first**, under the pointer or still under the press. It is known by being ahead of its app's word, the way the pointer went and no
  farther. It is judged from the place of the press and **its app's last word**, which is the nearest there is to the frame it had at the press, and is that
  frame if Arbor was too busy to hear more. So the way it has come counts, and a gesture that is over by then is still seen.
- **A hand takes a window by its top or by an edge.** Where its app has the window under the press, the press must be there (the upper 60 points, or 10 from the border): in a text
  that is being selected, a window that goes the pointer's way goes by itself. Where it has not, the app has been heard since: it is at most 100 points behind, and the
  pointer is still where a hand holds.
- **While macOS shows its desktop nothing is in the hand.** Every window is then listed far from its app's word, some of them the way the pointer went. Two signs tell it, both in the
  list that is read anyway: the Dock's window as large as the display at level 18, which is there for as long as a sweep lasts (seen on macOS 26; nobody has looked on 14 and 15), and
  `SweptAside.isSwept`, which goes by the frames.
- **An edge that has left the press behind** (its app heard meanwhile) is judged from where the pointer is, if the pointer is at an edge and the press is not. Not for a
  press in the upper 60 points: that is a window held by its title bar, which has not stirred yet, with the pointer gone along the bar as far as a corner, or which trails a hand going up.
- Otherwise the press is looked for at its own place, under the rule for strips, as before; and if nothing is found it keeps its own place, which is what a
  report from a window's app is held against.
- **Nothing is made of a few points**: the pointer must have gone more than 24, the window be 10 ahead. A press on time comes with a tremble, and the two frames of a
  window at rest may differ a little; to go by the app's word then would make a drag of the difference.
- One line at debug level for every press: where the button went down, where the pointer was by then, and what the press was found to be on.

**Four rounds found what argument did not.** Two reviews and an independent judge, twice, each with stories of its own on the model. The first state (the second try put back) took hold of
whatever the pointer had come to. The second judged every late press from the pointer's place, and lost what had come to rest. The third made **a false drag of a swept window**: a
press on the bare desktop within ten points of where a tile's far edge really is, the pointer thrown to that tile's strip, the press served late; with the real controller on top two tiles
were swapped and resized. It also made a drag of a stubborn window going back under a selection, and lost a window alone that starts late. "A strip can only be pulled the other way than it was
swept" is true of a press ON the strip, and of nothing else. The fourth lost a window that trails a hand going up, and knew a sweep only while more windows were aside than in place. All
their stories are in the tree.

**Evidence.** On the model, which no Mac can be asked for: lateness to order.

- **The model shows its desktop** (`FakeMacOS/DesktopShown.swift`: the key, a press on a strip, the Dock's sign; its header says what was seen and what is a guess). It is a layer over the
  list: with the trunk's layer every older story has line for line the account it had.
- `tests/DesktopShown.swift`, `tests/LatePresses.swift`, `tests/Judge.swift` and `tests/Judge2.swift` (the judge's), more of `tests/LostDrags.swift`: 607 new stories, each shape also served on
  time, as a control.
- `make mac-on-linux`: **886 stories, 2566 ✔, 298 known ✘, 0 new, exit code 0.** `REF=origin/swarm/trunk make mac-on-linux`, the trunk's layer with the same stories and the same list: 2399 ✔, **167
  new ✘**, and 7 that are listed pass. So **167 checks are red there and green here, and 7 the other way** (below).
- 228 checks of the new stories are listed in `known-failures.txt`, each with its reason: 221 red on both layers, the 7. Six lines that stood there are cured and gone.
- **Twice 4,000 random gestures**, the judge's (`tests/JudgeRandom.swift`, `tests/JudgeRandom2.swift`, told on request; truth is what became of the windows; a quarter with the desktop
  shown; the second lot with top edges, corners, taller title bars, longer throws):

  | | right, here | right, the trunk's layer | better | worse | false | wrong, here | wrong, the trunk's |
  |---|---|---|---|---|---|---|---|
  | the first 4,000 | 3,379 | 2,826 | 553 | 0 | 0 | 0 | 3 |
  | the second 4,000 | 3,260 | 2,783 | 477 | 0 | 0 | 3 | 4 |

  The rest are lost on both.
- `make mac-on-linux-selftest`: 33 changes noticed, ten of them new: each takes one of these rules out.

**On a hosted Mac** (macOS 26.6.2, before the last mend, which changes nothing for a press that is served on time): `check-sweep.sh` 62 of 62, `check-drag-from-behind.sh` 37 of 37, `e2e-drag.sh` 32 of
35, the three ✘ the trunk's own: they fail the same in another branch's run of the same hour. By the new line of the log **all 48 presses of the run were served on time**. So the Mac says that this
does no harm where nothing is late; what it does where something is, only the model says.

**Worse than before, seven checks, both shapes contrived:** a window that goes the pointer's way **by itself** under a press in its upper 60 points that is served late. A title bar double-clicked and the
window zoomed with the button still down, the pointer slipping the way its corner went (a Mac zooms when the button comes up); text selected in a field 30 points below the top of a window that goes
back 60 points. Each is taken for a drag. Served on time the same stories are false drags on every layer.

**Still lost or mistaken**, as before:
- what is at rest when the press is served and is dragged on afterwards; an edge that takes the window's place nowhere (right, bottom) or has left the place of the press, once its app has been
  heard; a window stopped by the menu bar with its app heard first; a window server that runs a whole step ahead of the pointer;
- **a resize taken in the upper 60 points** (the left edge 30 or 55 below the top, the top edge, both upper corners), served late, is taken for a **drag**: it cannot be told from a title bar held while
  the pointer goes along it to a corner. The three wrong ones of the second 4,000;
- **the 60 points are a guess**, with room over what has been measured (26 to 52). A bar of 90 points taken 62 to 88 below the top, or a window taken by its background, is lost when late;
- **the only window in view**, really carried to the bottom or the right edge until less than a quarter of it is left on the display, is taken for a sweep by its frames, and lost when late. On a
  macOS that has the Dock's sign the frames need not be asked; until somebody has looked on 14 and 15 they are;
- a window moved with ⌘ **under** another: only the frontmost window at a place is looked at;
- above the layer: the only floating window carried briskly to the bottom edge, the press served late. The layer reports the drag, but is told the pointer's place of now, at the edge, and the
  controller discounts an edge that was never left: no preview, no dock.

The facts are gone by the time a late press is served. The cure is to note the window under the press when it happens, off the main thread.

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
