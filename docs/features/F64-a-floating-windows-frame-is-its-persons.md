# F64: A floating window's frame is its person's

Written by an executor from the product owner's decision (`collab/QUESTIONS.md`, Q20), 2026-10-14; for the documenter to review.

Status: done (`fix/a-floating-windows-frame-is-its-persons`)
Depends on: F01. Overrules, with the setting as it ships, parts of F18, F48, F49, F53 and F61 (below)
Rules of the product direction: 2 (nothing moves that the person did not move), 3 (no jolts), 5 (windows keep their own sizes)

## Shipped / Not shipped

Shipped: everything under Behaviour; the setting `floatingWindowsMakeWay` (false); `Controller+OwnFrames.swift`; `FloatingFrameTests`, at the frames of the hosted day;
scenarios 67 and 70; the rules of the walks (`ChaosInvariants+OwnFrames.swift`: `own-frame`, `own-frame-fit`; and `floating-taken-out-of-view`, a gate since Q29, 4); `expect at` for scenarios.

Since Q29, 4 (`feat/a-floating-window-never-leaves-the-view`): **Arbor never takes a floating window out of view.** "Out of view and back" below is withdrawn with the
setting as it ships, and goes on with it on; `FloatsStayInViewTests`, scenario `I20c`. What is left of putting back is for windows that something other than a view took away.

Not shipped: nothing on real windows yet (see "How it is proven"). "Gather Floating Windows", a command that moves them onto the Desktop when asked, is an idea for
later; the placing it would use is still there, behind the setting.

## Summary

The first day played with nine real apps on a hosted Mac, at macOS's defaults, showed Arbor shoving and squeezing windows nobody had touched. One dock made Safari 794
points wide instead of 1324 and moved eight other windows. ⌘M, ⌘H and ⌘Q in a docked window moved seven floating ones each, and unhiding did not undo it. After Frame
and Show Everything they came back somewhere else than they had been. All of it followed from one idea: that floating windows are kept on the Desktop.

**Arbor sets a floating window's frame only to take it out of view and to put it back exactly where it was**, said Q20. Q29, 4 withdraws the exception: **it never takes one
out of view.** A floating window is moved, sized, raised or hidden only by a command that names it.

## Behaviour

- **A floating window in view is never moved and never resized by Arbor.** Not by a dock, however made; not when a docked window closes, is minimized, hidden or quit, or
  comes back; not when a gap moves; not by `arrange` or `layout` for the windows they leave floating; not at a start, a quit, Float All or a pause.
- **Wherever the view goes, it stays** (Q29, 4): a docked window framed, another space, the Desktop left behind. It is where it was, behind whatever came forward, and
  Arbor has not called its app. One that is out of view all the same (an Arbor that died with the setting on, or an earlier build, left it in its corner) comes back
  with the next layout, whatever the view shows: same place, same size, one move.
- **The one exception**, because "never lost" outranks "never moved": if the displays have changed and its frame would show less than half of the window (or
  leave its title bar out of reach), it is fitted: moved the least that brings it wholly into view, made smaller only if it is larger than the display. With its
  display as it was, a window pushed aside by hand until a strip shows goes back to that strip, if a hand could get hold of it there (24 points of its title bar, as
  ever). That the display has not changed under a frame Arbor knows only from the note it takes when a hand leaves a window somewhere; the note is not saved. Where
  in doubt, after an accident say, a window of which less than half would show is brought in.
- **A place** is where some display shows half of the window and a hand could get hold of its title bar (24 points of it on some display, the one measure of that), not behind a menu bar.
- **A start takes floating windows in view as it finds them**: what happened while Arbor was not looking is nobody's to undo. One that it finds where no window can be
  used (no place, below), and where no hand is known to have left it, is fitted by the next layout, ⌃⌥0 for one: a start itself sets no frame (Q16). An undo or a redo moves a floating window in
  view only if the step changes what is remembered of it.
- **At a pause and at a quit Arbor gives back what Arbor has put out of view, and nothing else.** A window its person pushed aside stays where it was left, however little of it
  shows, as long as somebody can get hold of it (the title bar within reach, the one measure of that): the same at a pause, a quit, a start and a resume. (Product
  owner, 2026-10-15. A first wording had every window of which less than half shows fetched, whoever left it so.) Still fetched, because Arbor will not be there to do
  it later: one that nobody could get hold of, and one of which less than half shows where nobody is known to have left it (a change of displays, an app or a tool
  that took it across a border, an accident before anything was saved). After a pause its own frame is still remembered.
- **A change of displays** also displaces windows that are in view. One that macOS shuffled before Arbor heard goes back where it was. One of which less than half shows
  now is fitted, unless its person's own hand left it hanging, its display is as it was then and no less of it shows than it left showing. One that Arbor fitted goes back to its own frame when that is a place
  again: a lid that closes and opens, a resolution that shrinks and grows back, add up to nothing.
- **Floating and docked windows may overlap**, as windows on a Mac do. macOS's order says which is in front. The window acted on or switched to comes to the front
  (rule 4); Arbor raises nothing else, and going out of view and back changes nobody's place in the order. ⌃⌥D shows all that floats.
- **The window a command is about** is its person's act: `float` gives it its own size around where it was docked, `grow` and `shrink` resize it, `move-to-display`
  sends it, `undo` puts it back. Each may put it anywhere on the display, not only on the Desktop.
- **F61 counts the Desktop as not in use**, whatever floats: docked windows come first, nothing is asked of them for a floating window's sake, and a `dock` no longer
  keeps the Desktop wide enough to use because something floats on it.
- **F18 is off**: a window that floats alone is not stretched over the Desktop. `soleFloatTakesDesktop` needs `floatingWindowsMakeWay` as well.

### The setting

`floatingWindowsMakeWay`, false as it ships, advanced in the settings window. True is the behaviour until this spec, whole: floating windows are kept on the Desktop,
pushed aside and squeezed by docked ones, and go back as room returns. The tests written for that run with it on and say so, so they keep their meaning, and the
decision can be undone. When it goes off, every window that is pushed aside, squeezed or stretched at that moment gets its own frame back, once.
`make test-making-way` runs the whole suite with the setting on wherever a test does not choose its settings, which is how the suite ran until this spec.

### Overruled while the setting is off

"Floating windows make way" (scenario 20). "A window that floats alone takes the Desktop" (F18). The squeeze and what follows from it: own sizes of squeezed windows (F48, and
F49 and F53 where a squeezed window is pinned or summoned), a move that is not a resize. "What Arbor took from the Desktop it gives back while a window floats on
it", the Desktop's wish and its turn before the docked windows (F61). `keepPushed` (F09).

## How it is proven

| Linux proves | A hosted Mac runs | Agents judge |
|---|---|---|
| `FloatingFrameTests`: each step of the day at its own numbers, beside a control with the setting on that fails; the exception; the order. Scenario 67. The walks: after any command or event, no floating window in view has been moved that nobody touched; one that comes back is where it was, in one move; after a change of displays at least half of it shows. Every test whose point is that no window is lost runs in both settings | `day.sh`: the docks, ⌘H, ⌘M, ⌘Q, Frame and Show Everything, unattended, under ten minutes. `make suite`, sections 10 and 66: two docks by hand move no floating window and squeeze none; each beside the same steps with the setting on | `moved-unasked`, `size-lost` and `jolt` name no floating window at those steps |

## Acceptance criteria

1. On the desk of the day (1600 points, the frames in `FloatingFrameTests`): docking Finder left, Safari right and TextEdit right sets the frame of no other window.
2. Frame and Show Everything, and every other way out and back: no frame is set on a floating window, none is raised, and each is in view throughout (Q29, 4).
3. ⌘M and back, ⌘H and back, ⌘Q and ⌘W of a docked window set the frame of no floating window.
4. A start, a quit, Float All, with a window framed too: no frame is set on a floating window in view.
5. With `soleFloatTakesDesktop` on and nothing else changed, a lone floating window keeps its frame.
6. Notes (709) and Safari (574) docked on 1440 points with a Calculator floating: both are in view, the Desktop is a tile, the Calculator has not moved.
7. The displays change while a window is out of view: it comes back exactly if half of it shows, else wholly in view, moved the least, no smaller than it must be.
8. With the setting on, step 25 of the day happens again, to the point.
