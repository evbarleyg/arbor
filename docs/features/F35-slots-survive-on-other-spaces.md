# F35: A restart keeps the slots of windows on other Spaces

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: ready
Depends on: F08
Reference items: T60, T63

## Summary

T60 says the arrangement comes back after a restart. For windows on a Space that is not
showing when Arbor starts it does not (F08, "Not shipped"): the Accessibility API does not
list them, `reconcile()` finds no such window, and their slots are dropped. When their
Space is shown they float. Anyone who uses Spaces loses part of the arrangement at
every restart, update or crash.

## Behaviour

- At launch, a saved docked or floating window that Accessibility does not list, but that the
  window server still knows and that belongs to the same app, keeps its place as an absent
  window (it takes no space, like one on another Space while Arbor runs).
- When its Space is shown it is reported as usual and goes to its slot. Rules do not apply to it.
- If it is closed while Arbor cannot see it, its slot is dropped at the next Space switch.

## Design notes

- Append to `WindowSystem`: `func windowsKnownToTheServer() -> [WindowID: Int32]` (window number to
  owner pid). `AXWindowSystem`: `CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)`,
  layer 0 only, `kCGWindowNumber` and `kCGWindowOwnerPID`. Numbers and pids need no Screen Recording
  permission (window names do; do not read them). The fake returns its windows, including
  ones marked as not listed (`open(..., listed: false)`, `setListed(_:_:)`).
- `reconcile()`: before `rematch`/`forget`, keep `window` if the server knows it and
  `NSRunningApplication(processIdentifier:)`'s bundle id equals the saved hint's. The pid-to-bundle lookup
  belongs in the window system: return a small struct (pid, bundle id) rather than a bare pid if that is simpler.
- `windowAppeared` already lays out again, instead of adopting, when a workspace contains the window.
- Pruning: after a Space switch (`scheduleSpaceRelayout`), forget tree and floating windows that are in neither
  `windows` nor the server's list.
- Window numbers are only unique within a login session; A07's check (the app must match) still guards reuse.

## Acceptance criteria

1. Save with `[a | desktop | b]`, restart with `b` not listed but known to the server: the tree is unchanged, `a` and the Desktop share the row.
2. `b` is listed later: it goes to its slot; a rule for its app is not applied.
3. `b` unknown to the server at launch: dropped, as today.
4. `b` known at launch, closed unseen, then a Space switch: dropped, invariants hold.
5. A reused number belonging to another app is dropped (A07's test still passes).
6. `make check` passes. On a hosted Mac, by script: dock a window, go to another Space with ⌃→, restart Arbor, come back: the window is in its place (`lost`, `moved-unasked`).
