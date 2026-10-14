# F49: Pin a window so that it stays in view

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done
Depends on: F01, F11
Size: small
Rank among "what would make people recommend it": 1

## Summary

Floating windows live on the Desktop, so they go out of view as soon as the view leaves it. That is right for most, and wrong for the few that are **companions to whatever you are doing**: a video call, a
timer, a music player, a chat with the person you are pairing with, a reference PDF, a simulator. Today the call disappears every time you frame your editor. The only way round is an `ignore` rule written in JSON
before the window opens. TrellisWM has nothing here. Every "always on top" utility sells because of this need.

## Behaviour

- `pin [window]`, `unpin [window]`, `toggle-pin [window]`; menu: **Keep "Zoom" in View**, with a tick. No default shortcut (⌃⌥⇧D is free if one is wanted later; see `docs/KEYBOARD.md`).
- A pinned window floats, and is **never moved out of view**: it keeps its place on the display through every camera move.
- Docked windows do not avoid it and it is not pushed off them: it overlaps, which is the point. Arbor raises pinned windows after a camera move so they are not buried under the window that just arrived.
- Docking a pinned window unpins it. Pinning a docked window floats it first (at its remembered size, F48).
- Rule action `pin`: `{ "app": "us.zoom.xos", "title": "Meeting", "action": "pin" }`.
- Pins are saved with the arrangement, and shown in `state` (`"pinned": true`).
- `float-all`, quit and `pause` leave pinned windows exactly where they are.

## Design notes

- `Workspace.pinned: Set<WindowID>?` (optional for old files). `placeFloatingWindows` skips parking and pushing for them; `ensureFocusIsVisible` counts them as visible.
- Raising without focusing: `kAXRaiseAction` alone, no `activate()`. Append `raise(_:)` to `WindowSystem`; the fake records the order.
- It cannot float above a full-screen Space or above all windows at all times: that needs the window's own level, which Accessibility cannot set. Say so in the README.

## Acceptance criteria

1. Pin a floating window, frame a docked one, walk to a neighbour, show everything: its frame never changes and it is never in `parked`.
2. After each camera move the pinned window was raised, and focus stayed where the camera move put it.
3. Dock unpins; pin on a docked window floats it.
4. The `pin` rule applies to new windows; a bad action is reported as other bad rules are.
5. Pins survive a restart (matched like other windows) and old state files load.

## Shipped (2026-10-14, `feat/F49-pin`)

All five criteria, each with scenario tests (`Tests/ArborKitTests/PinTests.swift`, `Tests/ArborCoreTests/PinModelTests.swift`,
`collab/scenarios/49-keep-the-call-in-view.sim`). Beyond the text above, decided while building (`collab/QUESTIONS.md`):

- Arbor looks whether a pinned window is covered not only after a camera move but after any layout and whenever another
  window takes the keyboard: a click on the editor under the call would otherwise bury the call, which is the everyday
  case. It looks three times within half a second, and raises only a window that something covers.
- A camera move never gives a pinned window the keyboard, and takes the keyboard along to the window that arrives, also out of a pinned window (the product owner's call).
- `zoom` in a pinned window un-frames what is beneath it; `zoom <pinned>` fails. Docking says that the pin ended. `pin` records the frame the window has as its floating frame.
- Dragging a pinned window moves it and never docks it; `arrange` leaves it out.
- A docked window that would cover more than half the display when pinned takes half its width and height (until F48 remembers sizes).
- A pin follows its window to another display, comes to the main display when its own is unplugged, and goes back with it.
- After its app restarted, a pinned window is found again by app and title, as docked windows are.

## Not shipped

- A default shortcut: ⌃⌥⇧D is reserved in `docs/KEYBOARD.md`, unbound.
- A mark on the pinned window itself (a small pin in a corner); the menu's tick, `state` and `ascii` show it.
- Remembered size when pinning a docked window: that is F48; `pin` goes through `floatingFrame(for:on:)`, where F48 will decide.
- Pins waiting for an app that has not opened its window yet at login: a `pin` rule covers that.
- Real windows: `scripts/mac-shell/check-F49.sh` is written and has not run.
