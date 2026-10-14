# F30: Full-screen windows

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done, but for the proof on a real Mac (`fix/review-controller` #17, `feat/F17-hardening` #24, #54, `feat/F30-leftovers`)
Depends on: F08
Reference items: T63

## Summary

TrellisWM leaves full-screen apps to macOS (T63). Arbor only skips a window
that is **already** full screen when Arbor first sees it
(`AXWindowSystem.isStandardWindow`). A window Arbor already arranges stays
arranged when its green button is pressed, and that goes wrong in three ways:

1. The window's new frame arrives as a change nobody made with the mouse, so
   `windowChanged` schedules an enforce, which calls `setFrame(slot)` on a
   full-screen window.
2. macOS refuses, so the frame that comes back is the whole display. `apply`
   takes that as "the app refused to shrink" and **learns the display's size as
   the window's minimum size**. The slot is now too small for it, so the window
   becomes a tile and Arbor tries to park the full-screen window in the corner.
   Minimum sizes are never forgotten while the window lives, so after it leaves
   full screen it is a tile in every slot smaller than the display. (Played
   through against the fake on 2026-10-14; see the review-proof report.)
3. A floating window that goes full screen has the display's frame recorded as
   where the user put it.

## Observed on a real Mac (macOS 26.6, 2026-10-14)

`collab/evidence/gestures-latest.txt`, step "a docked window goes full screen and comes back", and
`collab/evidence/ax-events.txt`, "docked 32 goes full screen":

- Going in: two helper windows are created (subrole `AXUnknown`; Arbor rightly ignores them), then one `AXResized` for the
  window, at the display's full frame, **with `AXFullScreen` already true**. `activeSpaceDidChange` follows 0.65 s later.
- While it is full screen Arbor's state says `docked parked` and shows a tile for it.
- Coming out: `AXResized` and `AXMoved` with `AXFullScreen` false, at a frame macOS chose (once the visible frame, once the frame
  the window had before Arbor ever moved it), then the Space change 0.45 s later. Nothing puts the window back: it stays
  `docked parked`, a tile or no slot at all, lying over its neighbour.

## Behaviour

- A docked window that enters full screen keeps its place in the tree and
  takes no space, exactly like a minimized one. Arbor does not move, resize,
  park or focus it, and learns nothing from its size, until it leaves.
- When it leaves full screen it goes back to its slot.
- A floating window that enters full screen keeps the frame it floated at and
  returns to it (macOS restores it; Arbor must only not overwrite it).
- A window that is full screen when Arbor starts, or when it first appears, is
  not arranged (as today). When it leaves full screen it is a new window.
- `zoom`, `dock`, `float` and `resize` on a full-screen window fail with
  "w412 is full screen".
- `state` reports it: `"fullScreen": true`.

## Design notes

- `WindowSnapshot.isFullScreen` (default false, last in the initialiser), and
  `isPresent` becomes `!isMinimized && !isHidden && isOnActiveSpace && !isFullScreen`.
  Everything that lays out, parks or places already asks `isPresent`;
  `windowChanged` already lays out again when `isPresent` flips.
- In `windowChanged`, return before the floating and enforce branches when
  `window.isFullScreen`, so neither records the frame.
- `AXWindowSystem.makeSnapshot` reads `AXFullScreen`. There is no notification
  for it: `geometryChanged` must read it again on every resize (one more
  attribute read) and, when it changed, report with `userInitiated: false`
  and start neither a drag nor a resize. `rescan` goes through `makeSnapshot` already.
- `FakeWindowSystem.setFullScreen(_:_:)`: sets the flag, gives the window its
  display's full frame (remembering the old one for the way back), sends
  `windowChanged(userInitiated: false)`. While the flag is set `setFrame`
  returns the current frame unchanged, as macOS does, so that a controller
  that still tries is caught by the tests.
- `StateSnapshot.Window.fullScreen`, decoded with `decodeIfPresent`.
- arbor-sim: `fullscreen <id> on|off`; `expect hidden` holds for it.

## Acceptance criteria

1. `[a | desktop | b]`, `a` goes full screen: no `setFrame` for `a` in
   `frameLog`, the Desktop and `b` share the row, nothing pending in the scheduler moves `a`.
2. `a` leaves full screen: same tree, `a` back in its slot as a window, not a tile.
3. A floating window's remembered frame is the same before and after.
4. Commands on a full-screen window fail with the message above and change nothing.
5. Quitting while a window is full screen does not move it.
6. Old `state.json` files load.
7. `make check` passes. Real windows: the step "a docked window goes full screen and comes back" of
   `scripts/mac-shell/proof.sh` passes (it fails today); then list it under T63's `"e2e"` and set T63 back to shipped.

## Shipped / Not shipped

Shipped, by several hands: the controller's side and the fake's `setFullScreen` (#17), the Accessibility layer's side and two steps of `arbor-e2e --full-screen`
(#24), the refusals (#54), and the simulator's `fullscreen <id> on|off` with the journey `collab/scenarios/30-the-green-button.sim` (`feat/F30-leftovers`).

| Criterion | Proof |
|---|---|
| 1, 2 | `aDockedWindowThatGoesFullScreenIsLeftAlone`, `theNeighboursOfAFullScreenWindowTakeItsSpaceOnTheirOwnSpace`, the scenario |
| 3 | `aFloatingWindowThatGoesFullScreenKeepsTheFrameTheUserGaveIt`, the scenario |
| 4 | `commandsOnAFullScreenWindowAreRefused`, the scenario |
| 5 | `quittingLeavesAFullScreenWindowAlone` |
| 6 | Nothing about full screen is saved: `state.json` has no new field |
| 7 | **Open.** The evidence on record (`collab/evidence/gestures-latest.txt`) is from before the fix and shows the bug |

Not shipped:

- **The proof.** Run `scripts/mac-shell/proof.sh` (the step "a docked window goes full screen and comes back") or `arbor-e2e --full-screen` ("make a docked window full
  screen", "leave full screen") on a Mac, commit the evidence, and set T63 to shipped. Both take over the screen for some seconds.
- `StateSnapshot.Window.fullScreen` is decoded as a required field, not with `decodeIfPresent` as the design notes say. Only the reply to `state` carries it, and
  `arborctl`, `arbor-e2e` and the app are built together, so nothing old is ever read.
