# F47: No dialog opens out of view

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done (built and unit-tested; not yet seen on a Mac)
Depends on: F01
Size: small (macOS-only, with the decision in a pure function)
Severity of what it fixes: a window the user cannot find; the app looks hung

## Summary

Only standard windows are arranged (T64), which is right. But apps place dialogs, alerts and panels **relative to their main window**, and Arbor keeps windows that are out of view just past a corner of the
display. A background app whose window is out of view and which asks "Save changes?", reports an error or shows a permission request may open that dialog off screen. Nothing
reveals it: it is not a window Arbor knows, so focusing it moves no camera. The Dock icon bounces, the app ignores clicks, and quitting it (or logging out) stalls.
Sheets are safe: they belong to their window and come into view with it.

Reasoned from how AppKit centres alerts over the key or main window; how often it bites depends on the app. Worth ten minutes on a Mac: frame Safari, then from Terminal run
`osascript -e 'tell application "TextEdit" to display dialog "hello"'` with TextEdit's window out of view.

## Behaviour

- When a window Arbor does **not** arrange (any subrole other than standard) of an observed app appears, or takes the focus, and less than half of it is on any display, Arbor moves it, without resizing, to the
  middle of the display its app's windows belong to (or the display under the pointer).
- It is moved once. Arbor does not track it afterwards.
- Windows that are off screen on purpose are left alone: smaller than 40 × 40 points, or belonging to an excluded or ignored app.

## Design notes

- `AXWindowSystem.addWindow` already sees these elements and drops them after two retries; that is the place. `kAXFocusedWindowChangedNotification` also delivers them.
- The rule (frame, displays, size → where to put it, or nothing) is a pure function in ArborCore with unit tests.
- Log the window id and bundle id, never the title.

## Acceptance criteria

1. Unit tests for the rule: off screen → centred; half visible → untouched; tiny → untouched; no displays → untouched.
2. Manual: the `osascript` check above shows the dialog in the middle of the display.
3. Spotlight, menus, tooltips, the Dock and Notification Centre are unaffected (they belong to apps Arbor does not observe, or are on screen).

## Shipped / Not shipped

Shipped (2026-10-14, `feat/F17-hardening`): `StrayDialog.home` in ArborCore with unit tests for criterion 1 and more; `AXWindowSystem.bringIntoViewIfDialog`, called where an element is given up as a window, so when a
dialog appears, takes the focus, or is on its app's list at any later reading. Moved once, never resized, logged by window id and bundle id.

Narrower than the Behaviour above, on purpose:

- Only the subroles `AXDialog` and `AXSystemDialog`, not "any subrole other than standard": palettes, tooltips and the stand-ins macOS lists during a full-screen transition are nobody's lost dialog.
- Only if one of the app's own ordinary windows is out of view. Then the dialog's place is Arbor's doing. It also leaves excluded and ignored apps alone without the Accessibility layer having to know about exclusions: Arbor never sends their windows out of view.
- It goes to the display nearest to where it opened, which is the one whose corner its app's window waits at; the pointer is not asked.

Not shipped: criterion 2 (the `osascript` check) and 3, which need a Mac. `arbor-e2e` has the step "a dialog opens over a window that is out of view", which says what happened without failing the run: nobody has
seen yet whether a plain `NSPanel` calls itself `AXDialog`. Make it a check once it has held.
