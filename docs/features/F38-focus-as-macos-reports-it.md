# F38: Focus, as macOS reports it

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: in progress (rule 1 is on the trunk since #15; rules 2 to 5 and the fake's reports are built on `fix/review-controller`, #17, and `feat/F17-hardening`, #24; use this as their checklist)
Depends on: F01
Reference items: T07, and QUESTIONS Q7's "focus must never jump to a parked window"

## Summary

"Focusing a window that is out of view moves the camera to show it" is one line in F01 and one method,
`Controller.windowFocused`. It was written against `FakeWindowSystem.userFocus`, which sends one tidy event when a person
focuses a window and nothing otherwise. macOS does neither. Four real-window bugs found on 2026-10-14 come from that
difference. This spec says what should happen for each thing macOS really sends
(`collab/evidence/ax-events.txt`).

## What macOS sends

| What happened | Events, in order |
|---|---|
| Arbor focuses the window that has the focus | none |
| Arbor focuses another window of the same app | `AXFocusedWindowChanged`, about 5 ms after the frame echoes |
| Arbor focuses another app's window | `AXFocusedWindowChanged` two to four times, app activation 30 ms later |
| A person clicks a window of the app in front, or presses ⌘` | `AXFocusedWindowChanged` |
| A person clicks another app's window, presses ⌘Tab, clicks a Dock icon | `AXApplicationActivated`; **`AXFocusedWindowChanged` only if that app's own focused window changed** |
| The focused window is minimized or closed | `AXFocusedWindowChanged` for the app's next window **first**, then the minimize or the destroy |
| A window is un-minimized | `AXFocusedWindowChanged` **first**, then the un-minimize |
| A new window opens | created, then `AXFocusedWindowChanged`, in the same millisecond |

## Behaviour

1. **An app that comes forward counts as a focus change.** `AXWindowSystem` also subscribes to `kAXApplicationActivatedNotification` and
   reports the app's `AXFocusedWindow` through `windowFocused`. ⌘Tab to an app whose window is out of view moves the camera to it.
2. **Only the window that has the focus now moves the camera.** When `windowFocused(id)` is handled and `system.focusedWindow() != id`, the event
   is old news (an echo that arrived after the next command, the second of four): it goes into the focus history and does nothing else.
3. **Arbor's own focus calls never move the camera.** A focus event for the window Arbor last passed to `system.focus`, within half a
   second, is an echo. A `dock` that ends in a tile leaves the tile in view.
4. **A window that takes no space is not revealed.** If the window is minimized, hidden, on another Space or full screen when the event
   arrives, nothing moves. When it becomes present (`windowChanged`), the display is laid out as today, and only then, if it is the
   focused window and the new layout does not show it, it is revealed. Un-minimizing a window whose slot is in view changes nothing but that slot.
5. **A focus macOS chose is not a focus the person chose.** When the focused window closes or is minimized, macOS hands the focus to the
   app's next window, which may be out of view. The camera stays, and Arbor focuses a window that is in view (`ensureFocusIsVisible`), or
   leaves the focus alone if none is. To tell the two apart, a reveal caused by a focus event waits for the end of the current
   run-loop turn (`scheduler.schedule("reveal", after: 0)`): if by then the window that had the focus before is gone or minimized, it was macOS's choice.
6. **A new window's focus does not move the camera** unless the window is docked and out of view because the person's rule put it there, in which
   case the camera widens just enough (`reveal`), never onto the leaf of a tile.

## Design notes

- The controller needs `lastFocused` (what `system.focusedWindow()` was before the event) and `lastFocusRequest: (WindowID, Date)`, set in one
  wrapper around `system.focus`.
- `FakeWindowSystem` must send what the table says, in that order, or none of this is tested: `focus(_:)` echoes through the scheduler;
  `close`, `setMinimized` and `open` send the focus events; `activate(pid:)` sends one only when the app's focused window changed. Keep a switch for
  the few tests that want silence.
- Nothing here needs a private API.

## Acceptance criteria

1. One scenario test per row of the table, each asserting where the camera is and which window has the focus.
2. `unMinimizingPutsTheWindowBackAndLeavesTheCameraAlone` (ParityProofTests) is enabled and passes.
3. A `dock` command whose window becomes a tile leaves the camera where it was, with the echo switched on.
4. Four echoes of one focus call, delivered after a later `show-all`, do not move the camera.
5. `make check` passes.
6. Real windows: the steps "switching to an app whose window is out of view brings it into view" and "minimize a docked window and bring it
   back" of `scripts/mac-shell/proof.sh` pass (both fail today). Then T07 is `shipped` again.
