# F32: Float All means all

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done (built by the product review, #15, from this text: `float-all` on every display, `float-all here`, `arrange all`, ⌃⌥⇧F)
Depends on: F01
Reference items: T16, T17, T62

## Summary

"Float All Windows on Desktop" is TrellisWM's built-in undo: everything
undocks and the Mac is normal again (T17, T62). Arbor's `float-all` works only
on the display under the pointer. With two displays, choosing it from the
menu bar leaves the other display docked, perhaps zoomed in with windows parked
in its corner, which is exactly what the user wanted to get out of.

## Behaviour

- `float-all` undocks every window on **every** display and brings every parked
  window (docked or floating) back into view; each camera returns to the root.
  It succeeds if anything was docked anywhere and reports the total.
- `float-all here` keeps today's behaviour (the display under the pointer).
- `arrange` still arranges the display under the pointer, because arranging is a
  choice about one screen. `arrange all` arranges every display that has windows.
- The menu's "Float All Windows" runs `float-all`.

## Design notes

- `Command.floatAll` and `.arrange` gain a scope. To stay append-only in
  `Command.swift`, add new cases (`floatAllHere`, `arrangeAll`) at the end rather
  than changing the existing ones; `float-all` keeps its text form.
- `Controller.floatAll()` becomes a loop over `workspaces.keys.sorted()` around the present body.
- If undo (IDEAS I3) has merged, one `float-all` is one undo step.

## Acceptance criteria

1. Two displays, windows docked on both, one zoomed in: after `float-all`
   nothing is docked, nothing is parked, every window is at least half on a display.
2. `float-all here` leaves the other display as it was.
3. `float-all` with nothing docked anywhere fails with "nothing is docked".
4. `arrange all` docks the windows of each display on that display.
5. Text forms round-trip; `help` lists them.
6. `make check` passes.
