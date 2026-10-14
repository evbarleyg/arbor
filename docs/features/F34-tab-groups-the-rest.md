# F34: Tab groups, the rest

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: ready (start when F04 has merged)
Depends on: F04
Reference items: T14, T15, and move 2 on TrellisWM's how-it-works page

## Summary

`collab/parity.json` files T14 under F04 and the board files T15 there too, and dragging
a whole tab group was meant for F04 as well. F04's text has none of the
three: it describes the strip, clicking, tearing off, a close button on hover and
`tab next/previous`. This spec is what is left. Whoever ships F04 should strike out
whatever F04 already did.

## Behaviour

### Moving a whole group (move 2)

- Dragging the strip by a part that is not a tab (its empty end, or the gap between tabs)
  drags the whole stack: the same drop targets, preview and dwell as a window drag. Dropped on
  a screen edge or beside a window the stack docks there with its tabs and active tab
  unchanged. Dropped on the Desktop every window in it floats, cascaded by 24 points.
  Dropped on another stack's middle the two merge, the dragged tabs after the existing ones.
- Dragging the **active window's own title bar** moves only that window (it tears off), as
  F04 has it for tabs.
- Commands, so that it is testable and scriptable: `dock-node <node> <edge>` and
  `dock-node <node> beside <node> <edge>` move any node, a stack or a whole split, with its contents.

### Window buttons act on the group (T15, inferred)

- Setting `windowButtonsActOnGroup` (default true, as in TrellisWM).
- Minimizing the active window of a stack minimizes the others too, so the slot empties
  instead of the next tab popping up; un-minimizing any of them restores all.
- Closing the active window with its own red button closes only that window. Closing
  other apps' windows on a guess is not something to do by default: TrellisWM's
  behaviour here is inferred from a setting's name. A tab's own close button closes that tab.

### Strip options (T14)

| Arbor key | Default | TrellisWM key |
|---|---|---|
| `tabCloseButtons` | true | `tabCloseButtons` |
| `tabCloseOnRight` | false | `tabCloseOnRight` |
| `tuckStrips` | false | `tuckStrips`: hide the strip while its stack is being dragged or animated |

The purely visual keys (`tabStyle`, `tabSelectedChip`, `tabChipMargin`, `tabInset`, `tabPadding`, `tabTint`,
`tabStripLights`, `tabGlassOpaqueWhenInactive`) and "also show the controls on each tab strip" are not
planned: say so in `parity.json` rather than leaving T14 as planned for ever.

## Design notes

- `LayoutTree` can already remove and insert single windows. Moving a node needs
  `LayoutTree.move(_ node:, beside:, edge:)`, refusing to move a node into its own subtree,
  the root, or the Desktop, and returning a `Remap` like `remove` does.
- The strip reports a group drag through `OverlayActions`, in the same three steps as
  `WindowSystemEvents`' drag; `FakeOverlays` gets a helper that plays them.
- Minimizing other apps' windows needs `WindowSystem.setMinimized(_:_:)` (append to the protocol, with the fake's version).

## Acceptance criteria

1. `dock-node` moves a stack of two to the other side of the tree: same tabs, same active tab, invariants hold.
2. `dock-node` on the root, the Desktop, or into the node's own subtree fails and changes nothing.
3. A group drag to a screen edge, beside a window, onto the Desktop and onto another stack does what is described above, and the preview matches the result.
4. With the setting on, minimizing the active tab empties the slot and restoring brings the stack back with the same active tab; off, the next tab shows.
5. The strip model carries the three options; old settings files load.
6. `make check` passes.
