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
  new ✘**, and 7 that are listed pass. So **167 checks are red there and green here, and 7 the other way**, four of them by a story that is at fault (below).
- 228 checks of the new stories are listed in `known-failures.txt`, each with its reason: 221 red on both layers, and those 7. Six lines that stood there are cured and gone.
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

**Worse than before, three checks, contrived:** a window that goes the pointer's way **by itself** under a press in its upper 60 points that is served late: text selected in a field 30 points below the
top of a window that goes back 60 points is taken for a drag. Served on time the same story is a false drag on every layer. The other four of the seven are one story of the judge's (a title bar
double-clicked and the window zoomed with the button still down) that its author has since called at fault: the model really drags there, so "no drag" is the wrong thing to expect.

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

## Afterwards: a picture only while the desktop is shown (2026-10-15)

The same night a probe on a hosted Mac showed that **the window server's list is behind after a call through Accessibility**: of 615 calls that changed a frame, the list read right after still had the
frame before the call in 475 and something older in 94; at the first later look (60 ms or more) it had caught up in 165 of 170, the other five (62 to 146 ms) were half-way frames; from 200 ms on it was
right, 170 looks of 170. Accessibility's own frame was right at once. The product owner asked whether a window that Arbor has
just laid out, listed where it was, could be taken for one in the hand.

- **It is not.** 18 stories: Arbor moves a window 80 points, 20 ms later the button goes down in a field of its toolbar, and the pointer goes towards where the window was, away from it, across; on time,
  60 and 100 ms late, with the main thread busy for 100 ms (late, but served while the list is still behind). No drag, before and after.
- **But a real drag begun then was not seen at all**: by the title bar, 8 stories of 18, served on time among them. Listed 80 points from its app's word, the window was "listed elsewhere", which since the first
  change above meant a picture of a swept window: the press took hold of nothing. A docked window grabbed a moment after a layout would have been put back under the hand.
- **The cure is one line** in `WindowGrab.hold`, now that the press knows whether the desktop is shown: listed elsewhere, a window is a picture **only while the desktop is shown**. That is what Q24 says; "listed
  elsewhere" was only the way of telling a sweep, and said more.
- **The prices.** "Listed elsewhere" caught more than sweeps, by accident. The judge's 906 stories found four things red with the line and green before, each rare and mild:
  1. **a sweep that neither sign tells** (a macOS without the Dock's window at level 18, and as many windows opened since as were swept) leaves a slipped click on a strip to the second net alone, the one that
     takes a window that leaps for none in the hand; a window given another size meanwhile is then taken for resized by hand: 8 of 120, needing all four conditions; with the controller nothing moves or shows;
  2. **a window in flight to the Dock**: the button down 300 to 500 ms after a minimize, under the box the list gives, in the window below, a slip of 3 points: a drag of the flying window: 15 of 108; the time
     in which it can happen grows from some 50 to some 250 ms of the 0.55 s; the window ends in the Dock and comes out where it was. Who gets such a press on a Mac nobody has measured;
  3. **a stubborn window** going back under a selection right after Arbor moved it: 24 of 96 a false drag that the old rule hid for as long as the list was behind: the listed fault (4), no new one;
  4. **half-way frames**: none of 168 within what was measured; beyond it 5 of 48 a false resize. What protects is the echo filter's 0.15 s against a worst measured 146 ms: 4 ms, on a Mac at rest.
  By reading only: Mission Control, App Exposé and Stage Manager's strip are in no model; if the list has the pictures' places there, "listed elsewhere" was the only net.
- **It buys more than the 36 say** (the judge's): moved 40, 80, 200 points, the list 30 to 200 ms behind, the press 5, 20, 100 ms after the call, by the title bar: 0 of 180 drags seen before, 180 of 180 after; with the
  real controller a tile taken 20 ms after `arrange`: before no drag, no preview, no swap; after, all three. All of it rests on a guess: that a drag begun meanwhile starts from the listed frame.
- Measured by the older nets too: `make mac-on-linux` 922 stories, 2656 ✔, 0 new; 18 more listed checks cured (a bar of 90 points taken below the upper 60); the two lots of 4,000 random gestures against the layer
  before: 4 and 15 better, none worse, none false; 34 changes noticed. The model's window server can lag behind a call (`serverListsACallAfter`; half-way frames are not played).

## Afterwards: one jump is no hand (2026-10-15, board 1.85)

Once a plain drag is the way out of an arrangement, **whatever the layer wrongly takes for a drag of a docked window takes the window out**, silently, and its neighbour is laid out anew. The judge's five
stories, with the real controller: Arbor sends a stubborn tile 80 points, it goes back by itself 0.2 or 0.47 s later, and meanwhile text is selected in it over 120 points, either way, from 20 or 200 ms after Arbor's
call. Five false drags; two of them take the tile out today, all five with the controller that is coming. `classify` calls "another place, no farther than the pointer went" a drag, wherever the press was.

- **A hand takes a window along by its top.** A press below that (`Hold.isBelowTheTop`: below the upper 60 points) is asked by `WindowGrab.judge` for **two looks**: the window gone the pointer's way, in two places more than
  two points apart, at one size. One jump, however well it fits the pointer's travel, is no hand. An edge still changes the size at one look. A window that was in the hand when a late press was served has shown where the
  hand is, and is not asked twice. Nothing changes in the controller.
- **The five: no drag, no preview, both stay tiles.** Five more listed checks are cured: a stubborn window under a selection served on time (three), and the two that the cure for late starts had left (a window that
  jumps by itself to within 24 points of the pointer's travel).
- **The first state was too narrow, and a review with 106 stories of its own said where.** It spoke of "the middle" of a window, which let five false drags through and lost a drag it need not have. Mended, each with its stories
  and a change in the self-test that they notice:
  - a **scroll bar** within ten points of the border: an edge changes a window's size, it never merely moves it, so a bare move under it is asked for two looks as well;
  - **the list behind Arbor's call:** by the frame it still lists, a press in the text can be "at the top" of a window that was sent up. At the top by the list and by the app's word, or not at the top. A move of Arbor's own starts the looks afresh;
  - **the two signs of one jump:** the window server's list and the app's word are both looked at, and if they differ by a point or two for good, one jump shows as two places. Hence more than two points;
  - **no list at all**, or nothing listed under a late press: the press is held against where the window's app had it, is asked whether that is at the top, and keeps to that window from there on, so that it can be looked at twice;
  - **a window that gets its old size back in the hand** (macOS had tiled it), taken by its background or by a tall bar: the size it had at the press does not count, only that two looks agree on one. An edge that has left a late press
    behind takes the window's place along too, and its size with it: that is why they must agree;
  - after one jump the window server is asked ten times a second again, not with every movement;
  - the log says of every press whether it was below the top, and once when a window has moved under such a press.
- **Red first:** the review's shapes and the judge's five on the layer before: 28 checks are red there (27 false drags, two tiles lost among them) and none here.
- **Windows that are taken along by their background, by name:** the model can play them (`isMovedByItsBackground`), the test app and its stand-in too (`by-background`). Dragged for a second, on time, heard 300 ms late, with the main
  thread busy in three orders: seen, 5 of 5, and the same with no list from the window server. At sixty movements a second, two and a half points each, the drag is seen **two movements later at the most** than by the title bar.
- **On time, with a hand that goes on, nothing is lost:** 24 stories hold that sentence: taken by the background and by a bar of 90 points 70 down, four ways, slowly (2 points a movement), briskly, and in coarse steps of 66 points.
- By the older nets: `make mac-on-linux` 988 stories, 2786 ✔, 280 known, 0 new. The layer before with the same stories: 33 checks red there and green here, 2 the other way (the price, below). 42 changes noticed by the self-test, seven of them new.
- **The prices, wider than first said, and wider again by the judge's word** (4,285 stories, the 180 true drags among them: none lost; 12,000 random gestures: no new false drag). None moves a window wrongly: what is not seen goes back
  to its place, or lies where it was let go.
  1. **One look is no drag.** Whatever is taken below the upper 60 points gives one look if the window starts late and catches up in one jump with the hand at rest, if its press is served late with little of the gesture left, or **if the whole
     gesture is one movement of the pointer**, on time too (28 of 28). A hand never makes one; a script that warps the pointer does. Right of 4,000 random gestures against the layer before: 3,382 / 3,383; 3,270 / 3,275; with every window
     taken along by its background (`judge2: B`, new) 3,096 / 3,116. None better, **none false**.
  2. **A drag below the top begins later:** a fast hand 8 to 33 ms, one or two movements. A slow hand (1 point a movement) was 150 ms late at the median on the head that was judged: two looks less than a point apart slowed the looks down.
     Mended: they slow down only once the pointer has gone 24 points on with the window standing. Held now to 3 movements at 1 point, 6 at half a point, 2 where every movement is heard twice.
  3. **One drag by a plain title bar** is lost that was seen before (seed 621 of the first lot: up to the menu bar, Arbor busy for 300 ms, the window server a step ahead, the app silent). 672 stories aimed at it do not bring it about again.
  4. **The press that found no window** kept for good to the first that spoke: 12 of 12 lost with the window beneath speaking first, and one new false drag. Mended: it keeps to a window only below that window's top, and gives it up for the
     next that speaks.
- **Lines that no story held**, by the judge's taking each out: the fresh start after a move of Arbor's own, forgetting a window that turns back, the slowing down after one jump, the keeping to a window. Each has a story and a change in the
  self-test now; the model counts how often its list is asked for.
- **What still takes a tile out**, all red before as well, and dearer once every false drag costs the tile: a press in the upper 60 points that is no title bar (a field of a toolbar 40 down: 5 of 6); a press in the text served late with the
  pointer come to the window's top by then (1 of 3, before 2); the list 2.5 points or more off the app's word; a window that goes on by itself by 3 points or more, or the pointer's way in several steps.
- **The order of two words:** where a report from the window's app is the first look, the controller hears "it moved, not by Arbor" before "a drag began", as it does for every window that starts late. A floating window docked that way and undone
  comes back a step from where it was taken.
- `scripts/mac-shell/check-one-jump.sh` asks a Mac: the button goes down in the middle of the test app's stubborn window, a tile; Arbor sends it 80 points; it goes back with the pointer going on, each way; that it did move under the button is
  checked. The same tile by its title bar is the control. A test window told `by-background`. (Its first state asked nothing: the Desktop lay between the two tiles and took the 80 points. Its second was not rehearsed though the rehearsal
  ended well: the stand-in's pointer had refused an option, and every gesture after it.)

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
