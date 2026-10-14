# F59: Carry a window with the keyboard

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: ready
Depends on: F01, F09 (targets and preview); F04 for the "middle" target
Size: medium, nearly all headless

## Summary

"Keyboard first" has a hole in the middle. ⌃⌥⌘ + arrow docks a window at an edge of the view or swaps it with a neighbour, and that is all. **Nothing by keyboard puts a window under one other window**, which is the move that makes
a group, the thing Arbor is about. In arbor-sim: `[Safari | Desktop | Slack | Terminal]`, Slack focused; ⌃⌥⌘↓ puts Slack under *everything*; there is no sequence of keys that puts it under Terminal. Nor can the keyboard make a tab group, or send a window to a
particular place on another display. A drag can do all of these, because a drag chooses among **targets**. Give the keyboard the same targets.

## Behaviour

- **⌃⌥⌘Space** (`carry [window]`) picks up the focused window. By the map's rule, ⌃⌥Space looks at everything; add ⌘ and it moves anywhere. The view steps out until it shows more than the window itself.
- While carrying, the **drop preview** shows where the window would land, exactly as during a drag, starting at its own place.
- **Arrows** move the choice to the next target in that direction. The targets are those a drag has: each edge of each window, tile and the Desktop in view; the four edges of the view; the middle of a window (a tab group, with F04); the Desktop (float). Order: from the current
  preview's centre, the nearest target whose preview lies that way. Pressing toward a window first offers its near edge, then its middle, then its far edge, as a pointer crossing it would.
- **⌃⌥↑ / ⌃⌥↓, ⌃⌥← / ⌃⌥→, ⌃⌥1–9** still move the view while carrying, so a window can be carried to a space that was out of view. The pointer's display changes with ⌃⌥⌘[ and ⌃⌥⌘] (reserved for this; previous and next display).
- **↩ or Space** drops it there. **⎋**, or any other command, puts everything back as it was, view included.
- One undo step (I3).
- The plain keys (arrows, ↩, Space, ⎋) are registered only while carrying, and are released on every way out: drop, cancel, the window closing, `pause`, quitting.

## Design notes

- `Controller+Carry.swift`. A carry is a `DragSession` without a pointer: it ends in `finishDrop(_:target:on:source:)`, so a carried drop and a dragged drop cannot differ.
- Enumerating targets is pure: `DropResolver.targets(layout:tree:visibleFrame:options:) -> [DropTarget]`, each with the frame `Workspace.previewFrame` gives it; duplicates (two targets with the same preview) collapse into one. Choosing the next one by direction is pure too. Both belong in
  ArborCore with unit tests.
- Commands `carry`, `carry <direction>`, `carry drop`, `carry cancel`, so that scenarios and scripts can drive it; the temporary keys are bound to those.
- Temporary shortcuts: `KeyBindings.whileCarrying`, next to `whilePaused`; `ArborApp` registers whatever `Controller.activeBindings` says (F41 proposes that function).

## Acceptance criteria

1. The example above: `carry`, `carry right`, `carry down` (or however many steps the order needs, pinned by the test), `carry drop` leaves `[Safari | Desktop | (Terminal / Slack)]`.
2. Every target a drag can reach in a given layout is reachable with arrows, and the result equals the drag's result (a property test over random trees).
3. `carry cancel`, the window closing and `pause` each restore the tree and the view and release the temporary shortcuts.
4. Carrying across a view change: `carry`, `view 2`, `carry drop` docks the window in the space of view 2.
5. A floating window can be carried; dropping on the Desktop floats a docked one.
