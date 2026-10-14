# F52: An unplugged display becomes a space

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: ready
Depends on: F08
Size: medium
Rank among "what would make people recommend it": 3

## Summary

Unplug a laptop from a big display and F08 remembers that display's arrangement for later, and **floats all its windows in a pile on the laptop's Desktop**. The arrangement someone built is unusable exactly when they carry on working on
the train. Every window manager has this problem, because for them a display is the top of the world. For Arbor it need not be: spaces nest without limit, and a display's arrangement is only a tree. Hang it in the remaining display's tree.

## Behaviour

- When a display goes away, its whole arrangement is docked as **one group** at the right edge of the main display's arrangement (bottom, if the lost display sat below). At "show everything" it is usually small enough to be a group tile lined with its
  splits (T51). Stepping into it gives the same arrangement, filling the laptop's screen.
- Its floating windows float on the main display's Desktop, as today.
- The view on the main display does not move. F43 says once: "The Studio Display's windows are in a group on the right."
- When the display returns, the group leaves the main tree and becomes that display's arrangement again, **including changes made meanwhile**: windows added to it travel with it, windows dragged out of it stay.
- Its saved views and camera come back with it; while it is a guest, its saved views are not reachable by number.
- Setting `unpluggedDisplays`: `"group"` (default) or `"float"` (today's behaviour).
- Act only when the set of displays has been stable for 1.5 s: on wake and while a dock negotiates, displays vanish and return within a second or two, and macOS moves windows itself in that time.

## Design notes

- `LayoutTree.graft(_ other: LayoutTree, beside:edge:) -> (root: NodeID, remap: [NodeID: NodeID])` renumbers the guest's nodes; the guest's Desktop leaf is dropped (a tree has exactly one). `LayoutTree.prune(_ node:) -> LayoutTree` is the way back and
  gives the new tree a Desktop again, where the old one was if its neighbours still exist. Both are pure and belong under the random-operations invariant test.
- `DormantWorkspace` keeps the camera, history and saved views, plus the id of the grafted node, instead of the tree.
- If the guest group was emptied or dissolved by the user meanwhile, the display comes back empty.

## Acceptance criteria

1. Unplug: every docked window of the lost display is docked under one node of the main tree, in the same relative layout; invariants hold.
2. Stepping into that node lays the windows out as on the lost display, scaled to the new frame.
3. Replug with no changes: both displays' workspaces equal what they were.
4. Replug after adding a window to, and removing one from, the group: the display gets the changed group.
5. A display that blinks away for under 1.5 s causes no `setFrame` at all.
6. `"float"` behaves as today (existing tests).
