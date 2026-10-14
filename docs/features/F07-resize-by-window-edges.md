# F07: Resize docked windows by their own edges

Status: done (verified headlessly; one real edge drag on a test window moved its seam, 2026-10-14)
Depends on: F01

## Summary

Today, dragging a docked window's own edge is undone when the mouse is
released (the controller puts the window back). Instead, the resize should
move the boundaries it touched, exactly as if the user had dragged the seams.

## Behaviour

- While the user drags a docked window's edge, nothing else moves (live
  reflow is optional and off by default).
- On release, for each edge of the window that moved by more than 4 points,
  find the seam on that side (walk up the tree to the nearest split on that
  edge's axis that has a neighbour on that side, as `Controller.resize` does)
  and move it by that edge's displacement.
- An edge with no neighbour on that side (the outer edge of the view) is
  put back to the layout's frame.
- The resulting layout is applied immediately (relayout with `.structure`),
  and the change is saved.
- If the app clamped the size (the window is smaller or larger than the
  user dragged), use the frame the window actually has.
- Keyboard and other-app moves of docked windows (no mouse involved) are still
  put back, as today.

## Design notes

- `AXWindowSystem` already detects resizes: a geometry change with the mouse
  down and a changed size sets `resizingWindow`, and on mouse up it calls
  `refresh(window, userInitiated: true)`. Consider an explicit event instead,
  e.g. `WindowSystemEvents.resizeEnded(_ id: WindowID)`, and add it to
  `FakeWindowSystem` (`userResize(_:to:)` that sends changes with the mouse
  down, then `resizeEnded`).
- Put the logic in a new `Controller+EdgeResize.swift`; reuse the seam search
  from `Controller.resize(_:edge:by:)` (factor it into a helper rather than copying it).
- Compare against the frame in `layouts[display]?.windowFrames[id]`, not the
  window's previous snapshot.

## Acceptance criteria

1. In `[a | desktop | b]`, dragging `a`'s right edge 100 points right makes `a`
   100 wider and the Desktop 100 narrower; `b` is unchanged.
2. In a column `[a / c]`, dragging `a`'s bottom edge down 80 makes `c` 80 shorter.
3. Dragging two edges at once (a corner) moves both seams.
4. Dragging an outer edge (against the screen) is put back.
5. A resize the app clamps uses the clamped frame.
6. Moves without the mouse (other tools) are still put back (existing test
   `dockedWindowsMovedBySomethingElseAreReturned` keeps passing).
7. Minimum sizes from `moveBoundary` still hold (no child below 80 points).
8. `make check` passes.

## Shipped

- `WindowSystemEvents.resizeBegan`/`resizeEnded`. `AXWindowSystem` sends them
  when it classifies a change as a resize and on the mouse-up that ends it;
  `FakeWindowSystem.userResize(_:to:release:)` and `releaseMouse()` simulate
  them (plus `setMaximumSize`, so a window can sit smaller than its slot).
- `Controller+EdgeResize.swift`: on release, each edge that moved more than 4
  points moves the seam on that side so the slot matches the frame the window
  ended at; edges with no seam in view are put back. Relayout with
  `.structure` and save; a pure put-back uses `.enforce` and saves nothing.
- The seam search is shared with the `resize` command (`Controller.seam(on:of:in:layout:)`).
- arbor-sim `pull <id> <edge> <points>`; tests in
  `Tests/ArborKitTests/EdgeResizeTests.swift` cover every criterion above.

Beyond the letter of the spec:

- `resizeBegan` exists so enforcement can wait while a resize is in progress.
  The enforce timer reads the hardware button state, so it could fire between
  the button going up and the mouse-up event arriving, and undo the resize.
  It now waits until `resizeEnded`, or one round (0.25 s) past the button if
  the event is lost, and then puts the window back as before.
- An edge counts as moved only if it moved more than 4 points from the slot
  and from where the window sat before (`settled`). Otherwise an app that
  sits inside its slot (a terminal on its character grid, a window with a
  maximum size) would move an untouched seam on every resize.
- Seams nearer the root move first, each edge measured again in a fresh
  layout, so a ⌥-drag that moves both edges on an axis lands exactly even when
  the two seams are in nested splits. Edges the user did not move are not
  pinned: as with a seam drag, an outer seam rescales the splits inside it.

## Not shipped

- Live reflow while dragging (optional in this spec, off by default).
- The real Accessibility path has been tried once, on a test window
  (2026-10-14): dragging a
  docked window's right edge 60 points made it 60 wider on release and the
  Desktop gave up the space, and a double-click on a docked window's title bar
  changed nothing visible. Untried: other apps' windows, corners, outer edges,
  apps that clamp their size. The worry about the double-click (if AppKit zooms
  while the button is down, the AX layer sees a resize and the seams follow
  the zoomed frame) is F17's H5.
