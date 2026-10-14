# F09: Drag polish

Status: done
Depends on: F01

## Summary

Make dragging feel deliberate: targets activate after a short hold, a
modifier suppresses docking, and (optionally) neighbours make room while you drag.

## Behaviour

- **Dwell**: a drop target activates only after the pointer has stayed in it
  for `dropDwell` seconds (default 0.15); moving to another target restarts the
  timer. Screen-edge targets activate immediately.
- **Suppress**: holding ⌥ while dragging disables docking (the window just floats), and macOS's own tiling is not affected.
- **Live reflow** (setting `reflowWhileDragging`, default false): when a
  docked window is dragged out of its slot, its neighbours take the space at
  once; if it is dropped back, they make room again.
- The preview animates between targets (short fade) instead of jumping.
- When a drop docks beside the Desktop, also outline the region the Desktop
  keeps, as TrellisWM does (T11). Arbor's preview already matches the
  rest of TrellisWM's look: a tinted rounded region with a brighter outline.

## Design notes

- The controller needs time: inject it through `Scheduler` (`ManualScheduler`
  lets tests advance it) rather than reading the clock.
- `WindowSystem.isModifierDown(_:)` (or modifier flags on drag events) so the fake can simulate ⌥.

## Acceptance criteria

1. Scenario: passing quickly over a window edge does not dock; holding does.
2. With ⌥ held, a drop over any target floats the window.
3. With reflow on, neighbours expand during the drag and the final layout matches the no-reflow result.
4. Existing drag tests keep passing (with dwell satisfied).
5. `make check` passes.

## Shipped (2026-10-14, `feat/F09-drag-polish`)

- **Dwell**: `dropDwell` (0.15 s, kept between 0 and 2). Windows and tiles wait, including the
  middle of a window when tabs are on; screen edges, the Desktop and the window's own slot do
  not. Let go before the hold is over, a floating window stays where it is and a docked one goes
  back to its slot (the product owner's decision). Without `previewDrags` nothing waits.
- **Only the Desktop, or ⌘, takes a docked window out of the arrangement** (the product owner's
  decision): let go over the middle of another window or a gap, where nothing is previewed, it goes back.
- **Suppress**: with **⌘, not ⌥** as written above: since macOS 15, ⌥ held during a window drag brings
  up macOS's own tiling preview (the coordinator's decision, see `collab/QUESTIONS.md`). It is looked
  at on any move, when the hold ends and at release; a docked window is undocked even over its
  own slot. Pressing or releasing ⌘ takes effect without moving the pointer.
- **Live reflow**: `reflowWhileDragging` (false), from trial copies of the workspaces; it also
  makes room at an active target, on any display. **Stay pushed**: `keepPushed` (true).
- **Preview**: fades in and out and glides between targets in 0.12 s (not with "Reduce
  motion"); `previewDrags` (true) turns it off.
- Also: the dragged window is left alone by every layout that happens during a drag; a
  command, a closing window or a display change during a drag makes it forget its target; a
  window dragged back from out of view counts as in view; and every way a drag can be cut short
  (F17's lost release, another drag, the window closing or becoming a native tab, pause, quit)
  ends in the same place: a docked window goes back to its slot, a floating one stays.

Not shipped: `previewStyle` (there is one style); a setting for the suppress key; the outline of the region the Desktop
keeps when a drop docks beside it (T11).
Seen on real windows in three Mac shell runs of `scripts/mac-shell/check-F09.sh`: the dwell, ⌘, the fades and live reflow. What
only a hand on a mouse can tell has not been tried yet.
