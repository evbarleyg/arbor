# F62: A group keeps its identity

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done (all headless; 33 core and 5 controller tests)
Depends on: F01, and the review of the core (decoding, `Remap`)
Needed by: F20 named spaces, F52 an unplugged display becomes a space, F29 arrange styles, F58 hold the view, F59 carry, F04 tab groups, undo
Size: medium, all headless

## Summary

What a person frames, saves or names is **a group of windows**. The tree does not see it that way. It tidies itself: a split left with one child gives way to that child, and a split that comes
to lie inside another on the same axis dissolves into it. Both are right for the layout, which looks the same either way, and wrong for whatever points at the split: after a merge the nearest thing
left to point at is the parent, which holds more.

In arbor-sim: `[ (Mail / (Notes | Safari)) | Desktop | Slack ]`, the view on `Notes | Safari`. Close Mail. The column gives way to the row, the row dissolves into the top row, and **the view jumps to everything**. So does a view
saved on the pair, and so would its name. Zoomed in on the column, ⌃⌥⌘← on Mail sends it to the left of everything on the display instead of the left of the view.

## Behaviour

- **A group that is framed or saved stays that group.** Whatever leaves or arrives around it, the view and the saved view go on showing its windows and no others.
- So does **a group that has a guest window** (F57: a floating window that opened over it while it was framed): the guest keeps its host.
- A view on a group that shrinks to one window shows that window, as today.
- A view on a window that closes goes to what is left of the group the window was in, as today, and that no longer dissolves under it.
- **What is docked at an edge of the view joins what is in view** (T01: "beside everything currently in view"), on whichever edge: the view then shows what it showed and the newcomer. In `[Mail | Desktop | Slack]` with the view on Slack, a window docked at the right edge used to become one more in the row, and the view widened to everything. Seen from outside it lands where it always did, beside Slack and sharing Slack's room.
- The only window in view cannot be moved to an edge of the view: there is nothing to dock it beside.
- **Moving the view changes nothing in the arrangement.** A group the view has left (and nothing else keeps) lasts until the next change to the arrangement, so Back still finds it. Then it dissolves as it always did.
- **A named group, and a guest** (the arrangement of an unplugged display, F52), also survive **down to one window**: what is docked beside that window is in the group. They go when their last window goes, and the name goes with them rather than passing to the parent.
- **History keeps nothing.** A place visited long ago must not decide how a drag or a resize behaves today. History follows merges as before.
- **A drop aimed at a group means that group** until the window has landed, on all four edges, also when the window comes from beside the group and its leaving would have dissolved it.
- Moving a window with the keyboard past the end of a kept group first takes it out of the group, as with any group. Seen from outside that is the same place in the row, so what shows is its size.
- Nothing looks different: a kept group inside a row on its own axis is laid out as any group is. What differs is what groups do: it is a level for ⌃⌥↑ and ⌃⌥↓, and one tile when it is too small.
- **What cannot be seen does not change what a drag does** (the product owner, 2026-10-14; T05). The gap at the end of such a group resizes the window on either side of the gap and nothing else, as in a flat row; so do `resize` and either window's own edge. The least a space may be (80 points) is that window's, not the group's.
- **Rearranging a pair that is framed or saved keeps the pair.** Moving a window takes it out and puts it in again, and in between a group of two is a group of one. It is kept until the window has landed: beside the other one, on any edge, it is still in the group, and the view and the saved view show the two. If it lands elsewhere, the view is on the one that stayed, as above.

## Design

- `Node.keeps: Keeps?`, an option set of reasons: `.view`, `.name`, `.guest`. Nil for none, so old files load and equal trees compare equal. In the tree and not beside it, so that a tree can be judged valid on its own (decoding has to), and so that the mark travels
  with undo snapshots, `graft` and `prune`. The word is *keep* because F58 has *hold* and *release*.
- **The invariants become**: a split has at least two children, or one if it is kept firmly (`.name`, `.guest`); a split has no child split on its own axis unless the child is kept (for any reason). Only splits are kept.
- `tree.keep(_:for:)`, `stopKeeping(_:for:) -> Remap` (dissolves it now if nothing else keeps it), `keep(exactly:for:) -> Remap`, `isKept`, `isKeptFirmly`, `kept(for:)`. New file `LayoutTree+Keeps.swift`; `detach` and `flattenIfSameAxis` ask it.
- When a softly kept split collapses, its mark passes to the child, which must not dissolve under the reference either.
- **`.view` is nobody's to set.** `Workspace.changeStructure(keeping:_:)` marks what the view and the saved views are on, the hosts of guest windows (and what the change is aimed at), runs the change, applies its `Remap`, lets go of what nothing views, and then takes the mark off wherever it makes no difference (every split that does
  not lie in a parent on its own axis). So ordinary trees carry no marks, what is saved does not depend on where the view has been, and reading a file needs no step of its own. `forget`, `undock` and `dock` go through it; so must every new change of structure (`rebuild`, `move(node:)`, `graft`, `prune`).
- `.name` and `.guest` belong to their features, which keep the text or the display id in their own tables, keyed by a node id that stays good for as long as `tree.contains` it.
- `LayoutTree.dock(…, groupingFor: Keeps?)` always makes a group of the target and the window: it wraps the target also where the parent runs along that axis, and keeps the new split for that reason. `.cameraEdge` uses it with `.view`; F20 can with `.name`.
- `Remap.survivor(of:in:) -> NodeID?`: what holds the content a node held, or nil if the content is gone. `resolve` answers with the parent there, which suits a view and not a name.
- Decoding spares kept splits, drops marks on anything that is not a split, and hands a soft mark to the child on a collapse, as the live tree does.
- This replaces the first and last child that `Remap` remembered for merged splits: keeping the target does the same and also covers the two edges across the axis.

## Acceptance criteria

1. The example: with the view on the pair, closing Mail leaves the view on the pair. The same for a view saved on it, and for a view on the column, which narrows to the pair.
2. Zoomed in on the column, moving Mail to the left edge of the view leaves Mail, Notes and Safari in view.
3. With nothing on the pair, closing Mail gives the flat row of today.
4. Moving the view leaves the tree untouched; Back returns to the group; the next change to the arrangement dissolves it and history follows.
5. A firmly kept group survives down to one window, takes in what is docked beside that window, and goes with its last window; `survivor` is nil then.
6. A window dropped on any edge of the group it came from lands on that edge of that group.
7. A workspace with kept groups is equal to itself after saving and reading; trees saved before this load; marks that make no sense are dropped with a note.
8. Over random sessions: no view or saved view on a group ever comes to show a window it did not show, other than one docked into it; a firmly kept group lives exactly as long as it has a window; the invariants hold at every step.
9. Layout, stepping, neighbours and tiles work through a group on its parent's axis and through a group of one.
10. With the view on a window or a group, docking at any edge of the view leaves exactly the old view and the newcomer in view; once the view has left and the arrangement changes, the row is flat again. Showing everything, docking at an edge is as it was.
11. In `[ a | (c | d) | b ]` with the pair kept, moving the boundary between `d` and `b` by 50 points (the gap, `resize` on either, either's own edge) changes `d` and `b` by 50 and leaves `a` and `c` where they are. Over random trees, any seam moves only what is beside it.
12. With the view, or a saved view, on `(slack | mail)` in a row on the same axis, `dock slack beside mail <any edge>` leaves exactly the two in it, and the row outside as long as it was.

## Shipped / Not shipped

Shipped: everything above. `GroupIdentityTests` (core), `GroupIdentityControllerTests` (commands, events, frames, a restart), `treesWithKeptGroupsTileEveryDisplayToo`. Both key lines were mutated by hand and the tests, the random one among them, caught each.
Second round (11, 12): `GroupEndSeamTests`, `GroupOfTwoTests`, and three more in `GroupIdentityControllerTests`. `Seam.leadingEnds` / `trailingEnds` and `LayoutTree.moveBoundary(at:by:)`; `Keeps.move`, firm, set and taken off within `Workspace.dock`, never saved.
Not shipped: see below. Nothing here is macOS-only.

## Not in this item

- The names themselves (F20), guests (F52), and any way for a person to see or set a mark.
- A group nobody frames, saves or names still dissolves. Whether every group a person *made* should last is a product question (it would make ⌃⌥↑ stop at levels that look like part of a row).
