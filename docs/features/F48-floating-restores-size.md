# F48: A window that floats again gets its old size back

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done (`feat/F48-floating-restores-size`)
Depends on: F01; touches `Workspace`, as I3 (undo) does
Size: small to medium

## Summary

Docking stretches a window to its slot. Floating it again leaves it stretched: a small Notes window that spent an hour as a 700 × 850 column stays 700 × 850, and floating a **framed** window leaves a
display-sized window floating over whatever the view moved to. "Float All Windows: back to a normal Mac" (T17, T62) and quitting (T61) leave a Mac full of column-shaped windows. macOS 15's own tiling, Rectangle, Magnet and
Windows all give a window its previous size back when it leaves a tile, so this is what people expect.

## Behaviour

- When a floating window is docked (drag, command, rule, `arrange`), Arbor remembers the frame it floated at.
- `float`, `toggle-float`: the window takes its remembered **size**, centred on where its slot was, fitted into the Desktop if the Desktop is in view, otherwise into the display.
- Dragging a docked window out and dropping it to float: remembered size, placed so that the pointer stays over the title bar at the same relative position. (Resizing at the drop is safe. Resizing when the
  drag starts, as macOS does, looks better but means setting a frame during a live drag; try it on a Mac behind a setting before making it the default.)
- `float-all`, quitting and pausing: remembered **frame**, position too: these mean "as it was".
- A window docked since Arbor first saw it, with nothing remembered, keeps today's behaviour.
- Remembered frames are saved with the arrangement and dropped when the window closes.

**Changed on 2026-10-14 by the product owner (QUESTIONS Q20, Q21):** Arbor no longer places or squeezes floating windows (`floatingWindowsMakeWay` ships false), so a floating window has only one frame, its own, and nothing to be given back. A pause gives docked windows their own frames back as Quit does: built. The first is being built; until it lands the text below is what the trunk does.

**Changed on 2026-10-15 by the product owner (board 1.87):** there and back is nothing. On every way out but a drag (`float` and `toggle-float` by key, menu and arborctl, `float-all`, pausing, quitting, excluding) a docked window is given the **frame** it had when it was docked, size and place, over whatever stays docked there. However it has moved about the arrangement since, by key or by hand: a slot is a place in the arrangement, not on the desk. Only if that frame is known to be a place for it: all of it is in view, or its person's own hand left it hanging over an edge, on this display as it is, with its title bar within reach. What a change of displays left hanging nobody chose; a frame larger than the display, with its title bar under the menu bar, or lower than a title bar's height above the bottom, macOS lets nobody give a window. Otherwise as above; and one window that floats where `floatingWindowsMakeWay` is on goes onto the Desktop as above. `float` and `toggle-float` on a window that has not the keyboard give it the keyboard, and with it the front, if it is in view: what names a window asks for it, and where it was may lie under a window that stays docked.

## Design notes

- `Workspace.undockedFrames: [WindowID: CGRect]?` (optional, so old `state.json` files load with the synthesised decoder). Set in `Workspace.dock` from `floating[window]` before it is cleared, only if nothing is
  remembered yet (moving a docked window must not overwrite it); cleared in `forget` and `undock`. `arrange` and `reset(tree:)` go through the same helper.
- `Controller.frameToGoBackTo(_:on:)` says whether a docked window can go back to where it was, on every way out; `Controller.floatingFrame(for:on:)` is the one place that decides where one window goes if it cannot, `asItWas` where it goes when Arbor lets go.
- A remembered frame on a display that has gone is fitted into the current one.

## Acceptance criteria

1. Dock a 400 × 300 window, float it: 400 × 300, where it was. (Until 2026-10-15: centred on its old slot, inside the Desktop. Still so if where it was is no place for a window any more.)
2. Frame it, then float it: 400 × 300, and the view is one that shows the Desktop.
3. `arrange` then `float-all`: every window is back at its exact frame. The same for quit.
4. Moving a docked window around with ⌃⌥⌘ + arrows does not change what is remembered.
5. An old `state.json` loads; the new one round-trips.

## Shipped / Not shipped

Shipped: everything above. Each criterion has a scenario test in `Tests/ArborKitTests/UndockedFrameTests.swift` (1 `aFloatedWindowTakesItsOldFrame` and `Tests/ArborKitTests/FloatGivesThePlaceBackTests.swift`, 2 `floatingAFramedWindowShowsTheDesktop`,
3 `floatAllPutsEveryWindowBackExactlyWhereItWas` and `quittingPutsEveryWindowBackExactlyWhereItWas`, 4 `movingADockedWindowAroundDoesNotChangeWhatIsRemembered`, 5 `anOldStateFileLoadsAndItsWindowsKeepTheirSlotsSize` and
`theNextLaunchDocksThemAgainAndStillRemembers`); the model's part is in `Tests/ArborCoreTests/UndockedFrameTests.swift`; `collab/scenarios/48-float-gets-its-size-back.sim` tells the story; `arbor-e2e` checks `float` and quitting on real windows.

Beyond the list above:

- **Excluding an app** lets go as quitting does: the remembered frame.
- **Pausing** lets go as quitting does (F40; QUESTIONS Q21, which replaces "a pause does not touch what is in view"): every window, in view or not, is back at the remembered frame, in one move, and a floating one that
  was pushed aside or squeezed is where its user left it. It takes the road a quit takes (`shutdown()`). Resuming docks and squeezes them again, in one move each. ✔ `Tests/ArborKitTests/PauseGivesSizesBackTests.swift`, on the desk of a day with
  real apps on a hosted Mac, where two docked windows had kept their slots' sizes and four floating ones had stayed squeezed; `collab/scenarios/40-a-pause-gives-sizes-back.sim`.
- **Windows that take no space** (minimized, hidden, on another macOS Space) get their frame back from `float-all` and quitting too, or they would come back later in the shape of a slot.
- **A window docked by a rule as it opens** goes back to the frame its app gave it.
- **A dropped window is not pushed onto the Desktop** by the layout that follows the drop, so it does not jump away from the pointer when its old slot closes and the Desktop moves.
- **Its own size, also beside a narrow Desktop** (the product owner's review): "fitted into the Desktop" moves the window and does not shrink it. After `arrange`, whose Desktop is a narrow column, `float` gives 800 × 600 back as a drag does: on the
  Desktop as far as it fits, over the docked windows for the rest, kept on the display, and left alone by the layout that follows.
- **With the Desktop out of view** a window that starts to float (by command or by a drop) is a guest of the view it floats over (F57), so it leaves and comes back with that view.
- **A window that grows at the drop** slides back onto the display as far as the pointer stays on its title bar.
- **To a smaller display and back costs nothing** (2026-10-14): a window that `move-to-display`, `swap`, `dock … beside`, a layout or a dock by drag takes to a display too small for its own size is fitted there. It takes its own size along when
  one of these takes it away again, docked or floating, or when it is dragged out of its slot onto a display with room; Undo of the way back costs nothing either. A size somebody gives it meanwhile, by hand or by command, is its own from then on, and so is
  the fitted size once a hand has carried it to another display. **Not shipped:** the note is kept while Arbor runs, not in `state.json`, so after a restart on the smaller display the fitted size is its size; `summon` across displays, and a drag out of a slot
  that drops the window to float on a *smaller* display, fit it and remember nothing; a place that waits for its window takes nothing along.
- **Slots that wait for their window** (the app shell review's pending slots) keep what is remembered, and `Workspace.repaired()` drops frames remembered for windows that are not docked.
- **Windows that floated all along** are let go of too: one that docked windows pushed aside or squeezed to keep it on the Desktop goes back to where the user left it.
- **A floating window that can no longer be as small as it was** (its app's minimum grew: a sidebar opened, a larger font): when it is pushed onto the Desktop and its app refuses the size, what is remembered grows on that side to the
  size the app took. The window ends on the screen, in one move from then on. A window merely squeezed onto a narrow Desktop still goes back to the size the user gave it.
- **A tile's window floated while the Desktop is a tile too** (two large windows after `arrange all`): the room its slot took goes to the Desktop (F61), so `float` looks at the layout that is to come, not at the one before room is made, and the window comes into
  view with the Desktop, at its own size, in one move. Should a layout ever show the Desktop against that forecast, it places the window like any other floating one.
- **An app that does not answer** when its window is to be put back: a window that was out of view still counts as out of view and is placed as soon as the app answers. One that was in view stays where it is, at its slot's size.
- **A move is not a resize.** A floating window that Arbor squeezed to keep it on the Desktop, and that its user then only moves (by the title bar or otherwise), keeps its own size to go back to, from where it is now. Only a resize by its user changes the size that is remembered.
  A move or a resize during a pause, or after a quit, which Arbor does not see, is learnt at the resume or the start: Arbor wrote down where it left the window. After a run that did not quit it cannot tell.
- **A frame given while Arbor was away.** A docked window that somebody moves or resizes during a pause, or between a quit and the next launch, is docked again, in one move, and has that frame for its own from then on: that is where
  the next pause, quit and Float All put it, and the size it floats at (the product owner's note of 2026-10-15 in `collab/QUESTIONS.md`; `DockedAsFoundTests`, scenario 95). Whether somebody has is known from where Arbor left it, as for a floating window. Here too a move is
  not a resize: one left in the shape of its slot, because its app did not answer, and only pushed aside, keeps its own size, from where it is now. Undo and redo take back steps in the arrangement, not this frame.
- **Exactly** means exactly: a window that hung over a screen edge goes back there. A frame is fitted into its display only when it is no longer a place for a window (larger than the display, less than half
  on it, its title bar under the menu bar).
- **Other displays**: a window docked on another display than the one it floated on keeps its size and its distance from the display's corner. When a display goes away, its docked windows float on the
  main one at their own sizes.
- **A restarted app's window**, matched again by app and title, keeps what was remembered.
- **A window in macOS's full screen** is left alone; macOS does not let it be moved.
- **Guests** (F57) that are out of view come back where they were; a guest in view is where its app or its user put it, so no way of letting go moves it; a guest that is docked and floats again has its own size.
- Placing the dropped window relative to the pointer needs its frame at mouse-up. `AXWindowSystem.endGrab` (F17) reads it from the window server just before `dragEnded`.

Not shipped:

- **Shrinking when the drag starts**, as macOS's own tiling does. It means setting a frame during a live drag; nobody has tried that on a Mac yet.
- **Tearing a tab off its strip** (F04) is not on the trunk yet. Dragging a tab's window out and `float` on either tab are covered (`aTabThatFloatsGetsItsOwnSizeBack`); a drop that ends in `finishDrop` with its pointer gets the size back.
- **What the user did while Arbor was not looking**, where Arbor cannot tell. (Where it can, that is built: see "A frame given while Arbor was away" above.) A docked window somebody moved or resized still goes back to the frame remembered
  before: after a run that did not quit; where the displays are not the ones Arbor let go on, since macOS moves windows then; and after a pause for an app (`pauseForApps`), which may have changed the resolution and changed it back. What is not
  noticed, so that what macOS made of a window is taken for somebody's wish: a display that changed its resolution between a quit and a launch, and displays that changed and changed back during a pause by hand, or while Arbor was not
  running. (During a pause Arbor could listen for that; it does not.) One taken to another display meanwhile keeps the size it was given, and comes back on the display it is docked on. Undo of a step that took the window from one display
  to another takes the frame back with it.
