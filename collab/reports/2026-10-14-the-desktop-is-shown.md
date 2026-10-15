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
