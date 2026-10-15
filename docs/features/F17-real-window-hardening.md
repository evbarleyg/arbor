# F17: Real-window hardening

Status: done
Depends on: F01 (merge after F07, which also edits the mouse handling in AXWindowSystem)

## Summary

`make e2e` proved docking, zooming, parking and quitting on real windows, but
it drives Arbor through commands. Three parts of the real Accessibility path
have never been exercised and have known weaknesses.

## Items

### H1: Detect title-bar drags without relying on move notifications

Today a drag starts when an AX "moved" notification arrives while the mouse
button is down (`AXWindowSystem.geometryChanged`). Some apps post that
notification only when the drag ends, which would turn a drag-to-dock into
an ordinary move.

- On left-mouse-down, record the topmost window under the pointer: the first
  layer-0 window in `CGWindowListCopyWindowInfo(.optionOnScreenOnly)` whose
  bounds contain the point, ignoring Arbor's own panels. Read its AX frame.
- On each left-mouse-dragged event until a drag or resize is recognised, read
  that window's frame: origin moved and size unchanged starts a drag
  (`dragBegan`); size changed marks an edge resize.
- Keep the notification path as a second trigger; whichever comes first wins.
- This is how Rectangle recognises drags for its snap areas.

### H2: Stop fighting apps that keep moving themselves

`.enforce` relayouts put a docked window back whenever something else moves
it. An app that resizes itself after every move would loop forever. After a
window has been put back three times within three seconds, accept its frame as
settled, log it once, and stop enforcing until the next structural change.

### H3: Time out on unresponsive windows, not only apps

`AXUIElementSetMessagingTimeout` is set on each app element but not on window
elements, which keep the 6-second system default. Set 1 second on every
window element when it is first seen.

### H4: An opt-in real drag in the e2e runner

Add `make e2e-drag`: after the existing scenario, post synthetic mouse events
(`CGEvent` left-mouse down, dragged steps, up) to drag a test window by its
title bar to the left screen edge, then check it docked. It moves the real
pointer for about a second, so it is a separate target and prints a warning
first.

### H5: Only real edge drags resize seams

F07 moves seams when a docked window is resized with the mouse. macOS also
resizes windows when their title bar is double-clicked (the "zoom" action),
which would be taken as an edge resize and move seams the user never touched.
Treat a resize as an edge drag only if, at mouse-down, the pointer was within
10 points of the window's frame edge (outside the title bar's middle). Keep
the rule in a pure function with unit tests.

## Acceptance criteria

1. H1: a `FakeWindowSystem`-level test is not possible for CGWindowList, so
   keep the decision logic (frame before/after → drag, resize or nothing) in a
   pure function with unit tests; on a hosted Mac (was a manual check; board, section 5): the day's real drags dock Safari,
   Finder, Terminal, System Settings and an app of another toolkit (`docs/VIABLE.md`, the casts).
2. H2: a scenario test where a fake window snaps back to its own frame after
   every `setFrame` ends with no more than three enforcements and no
   pending enforcement work.
3. H3: code review only.
4. H4: `make e2e-drag` passes on a Mac with Accessibility permission; `make e2e` is unchanged.
5. H5: unit tests for the edge-proximity rule; on a hosted Mac a real title-bar
   double-click on a docked window moves no gap and no neighbour (QUESTIONS Q22; `moved-unasked`).
6. `make check` passes.

## Shipped / Not shipped

Shipped (2026-10-14, `feat/F17-hardening`):

- **H1**: the press records the point and the window under it; with every movement that window's frame is read, and the
  notifications stay as the second sign. `WindowGrab.classify` decides (unit tests). **Deviation**: the frame is read from the window server
  (`CGWindowListCopyWindowInfo` for the one window), not through Accessibility. A Mac showed the window server to be a step (about 0.1 s)
  ahead of Accessibility during a drag, it costs about the same (0.18 ms), and it cannot hang on the app. Looking stops
  once the pointer is 24 points away with the window where it was, so a text selection costs a handful of reads.
- **H2**: `EnforcementLimiter` (unit tests) and `countPutBacks`; scenario test as specified; on real windows in `arbor-e2e`.
- **H3**: one second for the whole process (on the system-wide element, which a Mac showed to cover every element) and on every window
  element when first seen. Measured: window elements without a timeout of their own took 1.55 s per call, not 6.
  Beyond the spec: the first call that times out ends the conversation with that app until it answers again.
- **H4**: `make e2e-drag` (`scripts/mac-shell/e2e-drag.sh`, built on the Mac shell sessions' scripted pointer) and a step of CI's macOS job. `make e2e`
  moves no pointer, as before; it gained sessions with misbehaving windows.
- **H5**: the rule is part of `WindowGrab.classify` (`isNearEdge`, unit tests). A Mac showed that the resize of a title-bar double-click arrives with the
  button already up, so it never was taken for an edge drag on macOS 26; the rule still matters for a window macOS had tiled or zoomed,
  which gets its old size back while it is dragged by its title bar. `e2e-drag` double-clicks a docked window's title bar and checks that no seam moves.

Since (2026-10-14, after bug bash 1 and the chaos lab): a move that an app does not answer is owed, whoever asked for it. A floating window that missed a move of the
camera (`owedMoves`), a window summoned or pinned, and one that could not come back when a pause began (`couldNotComeBack`: tried again after 1, 2, 4… then every
30 seconds, for some ten minutes) are placed when the app answers. A window that cannot be moved, or cannot fill its slot, is not counted among the put-backs its neighbour causes.

Not shipped: the manual check of H1 in Safari, Finder, Terminal, an Electron app and System Settings (`docs/TESTING.md`, "Real apps").
**Quitting while an app with a window out of view hangs** (K003's quit half): the window is still out of view when the app wakes, and Arbor is gone. Opening Arbor again finds it
(`afterAQuitWhileAnAppHungOpeningArborAgainFindsItsWindow`). The cure that was written, `stop()` sending such moves without waiting for answers (M16), was tried on a hosted Mac and does nothing at a quit: macOS drops what a
dead process asked. At a pause, which Arbor lives through, the same calls bring the windows back, and are made (`itIsBackTheMomentItsAppWakes`, `aMoveOutOfViewThatLiesInAHungAppsQueueDoesNotOutlastThePause`).
