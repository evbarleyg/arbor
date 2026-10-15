# F26: The minimap

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done headlessly and built on a Mac; nobody has seen the panel yet
Depends on: F01. Fits together with F43 (the heads-up line), F20 (names), F51 (peek), F58 (hold the view)
Size: medium
TrellisWM has nothing like it.

## Summary

Zooming raises one question every time: where am I now? Motion (F02) answers it while it lasts, and not at all with motion off, with Reduce
Motion, or some time later. ⌃⌥M shows a small picture of the display's whole arrangement near the bottom of that display, with the part now in view
marked. It takes clicks, so it is also the shortest way from one framed window to any other. Whoever wants it can have it show by itself for a moment
after each move of the view.

**As it ships (the product owner's decision, 2026-10-14): only ⌃⌥M.** The passing minimap is off (`minimapDuration` 0): something that appears by itself at the bottom centre, over a chat's input field, after every move of the view, and that
nobody has seen on a Mac, is not a day-one default, and motion now shows where things went. To be decided again when both can be seen together.

## Behaviour

### After the view moves (off by default)

- With `minimapDuration` above 0 (at most 10; 0.9 is what it was designed for): whenever **another space comes to fill a display's view**, the minimap shows on that display for that many seconds. It does not matter what
  moved the view: a shortcut, a pinch, a click on a tile, a saved view, `back`, switching to a window that is out of view, or the framed window closing, being minimized or hidden.
- Another move replaces the picture and starts the time again. A change of the arrangement while it shows is drawn into it without keeping it up longer.
- It does **not** show
  - **when the view goes to everything**: it would be a small picture of what is on screen. One that is still up from an earlier move goes at once, because it marks a place the view has left. So a peek (F51), which begins by
    showing everything, has the display to itself, and its landing shows the minimap;
  - **when macOS changes what is there**: switching macOS Spaces, a window going into or out of full screen. What fills the view changes with it, but nobody has gone anywhere in the arrangement;
  - when only the arrangement changes and the view stays on the same space;
  - on a display whose view did not move;
  - when Arbor starts or resumes, or a display is plugged in: what Arbor restores is not a move;
  - when no docked window takes up space on the display, so that the Desktop is all there is;
  - while Arbor is paused;
  - while the view is held, at either strength (F58), once that is on the trunk: one gate, `minimapMayAppearUnasked`, which takes F58's `mayShowUnasked`.
- No click can hit it, it never takes the keyboard, and no window's frame depends on it.

### What it shows

- The whole arrangement as Show Everything would lay it out, in a map of at most 220 × 140 points with the proportions of the display's usable area.
- Each docked window is a rounded rectangle in its app's colour, fainter if it is out of view. A tab group is one rectangle, its front window's. Minimized and
  hidden windows take no room, as in the arrangement itself.
- The Desktop is an outline.
- The space in view is framed in the accent colour.
- A caption above the map: the space's name (F20) or else "View 3" if a saved view leads to it (the lowest number if several do). Most spaces have neither, and then
  there is no caption. The panel grows upwards by the caption's line, so the map itself never jumps.
- No window titles, and no app names.

### Where

- Centred, its bottom edge 56 points above the bottom of the display's usable area: the place F43 keeps for "the lowest of Arbor's passing panels".
- F43's heads-up line sits 10 points above it when both show (`HeadsUpModel.placed(in:above:)`), and moves down again when the minimap has gone.
  Moving the line does not start its time again. `minimap` itself says nothing on screen when it succeeds, as `show-shortcuts` does not: the panel is its own answer. A refusal is said.
- The same look as the line: a heads-up background with 12-point corners, fading in over 0.1 s and out over 0.25 s; with Reduce Motion it appears and is gone.
- Above F02's stage, hidden in Mission Control, on every macOS Space.

### On demand: `minimap`, ⌃⌥M, "Show Minimap" in the menu

- Shows the minimap on the display that commands for the view act on (`cameraDisplay()`: the one under the pointer today, F56 refines it), whatever `minimapDuration` says, for 5 seconds. **The time does not run out under the pointer:** while the pointer is on the panel it keeps starting again, because on a Mac
  the click that was on its way would land in the app below while the panel fades.
- Asked for, it **takes clicks**: a click on a window frames that window and gives it the keyboard, a click on the Desktop's outline shows the Desktop. It then goes: at once, or, where the passing minimap is on, after
  marking the new place like after any move. A click on the panel beside the picture puts it away.
- ⌃⌥M again puts it away.
- Moving the view with the keyboard while it is up keeps it up, and the 5 seconds start again: ⌃⌥M, then the arrows, is a way of walking with the map open.
- The space under the pointer is outlined: what a click would frame.
- One that was asked for stays when the view goes to everything, with the whole of it marked.
- With nothing to show the command fails and says why: nothing is docked yet, or no docked window takes up room just now (minimized, hidden, on another macOS Space).
- The menu's row (docs/MENU.md, row 10; one line in `Controller+Menu.swift`) is about the display under the pointer, as its neighbours are: greyed out where the command would fail, ticked while a minimap that was asked for is up
  there, which is the one that choosing the row again puts away.
- Where it takes clicks it is one of the panels of the guard of the Desktop (F60, `desktopGuardZones().panels`), so that a click in it over bare Desktop is not kept from it. Its coming and going are announced as `.frames`.
- **One family with peek (F51): hold to look, let go to land.** A tap of ⌃⌥M (let go within 0.3 s) is all of the above. **Held**, the minimap stays for as long as the keys are down, however long, and **letting go frames the
  space the pointer is over**; over none, or over the space already in view, it is only put away. A click while holding decides at once, and the release then does nothing more. ⌃ or ⌥ going up first
  counts as letting go. **⎋ while holding gives up**, as in a peek: the minimap goes and nothing else happens. (With ⌃⌥ down it is ⌃⌥⎋, which would pause Arbor and bring every window into view.) With `peek` off, held is tapped.

### Going away

It goes at once, leaving no timer, when Arbor quits or pauses and when its display is unplugged.

## Design notes

- `ArborCore/Minimap.swift`, pure and unit-tested:
  - `Minimap`: the geometry. The real layout engine at the root, into the map's rectangle, with a gap of 2 and nothing too small to show, so that the map cannot disagree with the
    arrangement. The highlight is the rectangle of the node that fills the view.
  - `MinimapModel`: what the panel draws. Its frame in global coordinates; everything inside in the panel's own (origin top-left, y down), so that the view decides nothing.
    Colours are the view's business, which has the icons: the model carries pid and bundle id. `space(at:)` turns a click into a node.
- `Controller+Minimap.swift` observes the controller's own changes. **The trigger is `.layout`, not `.camera`:** the view has moved when `layouts[display].camera` is another node than at the last layout. That also
  catches the moves nobody announces (the framed window closed; a dock widened the view), and ignores announced moves that went nowhere. A display seen for the first time only sets the baseline.
- `OverlayPresenter.showMinimap(_:on:)` and `OverlayActions.minimapClicked(display:at:)`, appended. `FakeOverlays` records `minimaps` and `minimapHistory`, and clicks with `clickMinimap`.
- One timer per display through the scheduler: `minimap-<display>`.
- A click goes the way a click on a tile goes (`tileActivated`), so whatever gates that gates this. Letting go after a hold is a click where the pointer is.
- Presses and releases come through F51's one door, `Controller.shortcut(_:_:run:)`: `minimapTakes` beside `peekTakes`, and `minimapKeyWentDown` after the press's command has run, so that the clock starts once the
  minimap is up. While a minimap that takes clicks is up or its keys are down, one timer (`minimap-tick`, thirty times a second, like the peek's) moves the outline and asks `isHolding`, which finds a release nobody
  reported. A hold that was decided some other way is `spent` until the keys are up, so that it can neither land twice nor leave the key dead.
- `UI/MinimapPanel.swift`: one panel per display, kept and reused; one `NSView.draw`, which hands the model to `MinimapDrawing.draw`. That is apart from the view so that `MinimapDrawingTests` (macOS only, part of `swift test`)
  can have the real AppKit code draw into bitmaps off screen, check pixels, and leave pictures of a dozen arrangements, light and dark, at both scales, in `.build/pictures/F26/`.
- arbor-sim: `map <id>|desktop|beside` clicks in the minimap, `expect minimap none|everything|desktop|<id>` checks what is marked, and every change of it is printed.

## Acceptance criteria

1. A move of the view shows the model on that display; `minimapDuration` later it is hidden and no timer is left. Every way of moving the view does, including the ones without a command.
2. A second move within that time replaces the model and the time starts again.
3. The map has the proportions of the display's usable area and fits 220 × 140; every rectangle lies inside it; the panel lies inside the usable area, centred, 56 points from its bottom.
4. The highlight is the framed window's rectangle, a group's, the Desktop's outline, or the whole map.
5. Minimized and hidden windows are not on the map; a tab group is one rectangle.
6. Nothing shows at start, on resume, when a display is plugged in, with nothing docked, for a change of arrangement alone, on a display whose view stayed, when the view goes to everything, when macOS switches Spaces or a window goes into or out of full screen, or with `minimapDuration` 0, which is the default.
7. `minimap` shows it for 5 s, also with `minimapDuration` 0; again puts it away; with nothing to map it fails in words.
8. Only a minimap that was asked for takes clicks. A click on a window frames and focuses it, on the Desktop shows the Desktop, beside the map puts the minimap away; after a click the map goes like a passing one.
8a. Held past 0.3 s it outlasts the five seconds; letting go frames what the pointer is over or puts it away; a tap, auto-repeat, a click while holding, an unreported release, a pause, the display going away and
    `peek` off all end cleanly, with no timer left and the key still working.
8c. ⎋ while holding puts it away and pauses nothing; once it has gone, and when nothing is held, ⌃⌥⎋ pauses as ever. The five seconds do not run out while the pointer is on the panel. One that takes clicks is among the guard's panels, and every change of that is announced.
8b. The space under the pointer is outlined in a minimap that takes clicks, and in no other.
9. A saved view's number is the caption, the panel grows upwards by a line, and the map stays where it was.
10. Quitting, pausing and unplugging the display hide it at once and leave no timer.
11. Negative, huge and not-a-number durations do no harm; old settings files get 0.
12. Windows end up in the same frames with the minimap on and off.
13. `make check scenarios parity` pass.
13a. On a Mac, off screen (`MinimapDrawingTests`): every window is where the model puts it, the right way up, in its app's colour, fainter out of view; the accent frame is around the space in view; the Desktop is an outline; a long caption stays in its line.
14. On a Mac (`scripts/mac-shell/shots-minimap.sh`): the pictures look right, a click goes through a passing minimap, a click on an asked-for one frames the window, and nothing is left after quitting.

## Shipped

- Everything under "Behaviour" except what is listed below, proven headlessly: `ArborCoreTests/MinimapTests.swift`, `ArborKitTests/MinimapScenarioTests.swift`, `collab/scenarios/29-where-am-i.sim`.
- `scripts/mac-shell/shots-minimap.sh`, rehearsed on Linux (76 of 76 checks), to run when a Mac is available.

## Not shipped

- **Nobody has seen it.** Sizes, alphas and radii are first guesses to be judged from the pictures. Criteria 13a and 14 are open.
- What waits for a neighbour to land, each a line or a few: `MinimapPanel` as F43's `PassingPanel`, no minimap while the view is held (F58).
- Floating windows are not drawn; the Desktop's outline stands for them.
- No hand cursor over a minimap that takes clicks. While ⌃⌥M is held, the arrows move the view (they are ⌃⌥ + arrow), not the outline. ⎋ gives up only where ⌃⌥⎋ is a registered shortcut, as it is by default: the peek's temporary
  shortcuts have no counterpart here.
- Whether it stays out of shared screens and recordings is up to macOS: the panel asks for it (`sharingType = .none`), nobody has tried it, and no document for users promises it.
