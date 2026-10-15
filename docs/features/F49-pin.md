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
- A docked window that is pinned takes its own earlier size, however large (F48; `collab/QUESTIONS.md` Q20: Arbor picks no size for a floating window), wholly in view, in one move. Until 2026-10-14 one that would have
  covered more than half the display took half its width and height, and Float All left it so. With nothing remembered it keeps its slot's size and does not move. If its app insists on more than its own size it is slid into view, a second move; if its
  app does not answer at the pin, it takes its own size when the app does. A floating window that was both squeezed and mostly out of view comes into view at its own size.
- A pin follows its window to another display, comes to the main display when its own is unplugged, and goes back with it.
- After its app restarted, a pinned window is found again by app and title, as docked windows are.

### Keep in View makes room (2026-10-15, `collab/QUESTIONS.md` Q25; board 1.25)

Overrules, in the text above: "Docked windows do not avoid it … it overlaps, which is the point", "Arbor raises pinned windows after a camera move", acceptance criterion 2's raise, and the first point under "Shipped" (three looks within half a second).
Seen on hosted Macs: the Accessibility raise lifts another app's window over everything but the window that has the keyboard, so a pinned call lay wholly behind the window that filled the screen; one run counted 36 raises in vain.

- A pinned window reserves a strip of its display: from its inner edge to the display's edge, over the whole height or width, the cheapest of the four (`PinnedRoom`, ArborCore). Every layout of docked windows, real or tried (previews, live reflow,
  automatic docking, `layout`, Quit's places, the minimap's shape), is made in what is left: `Controller.roomForViews(on:)`, which is `Layout.frame`. `state` has it as `displays[].room`. What hangs over the display's edge needs no room.
- All strips of a display together take at most four tenths of it, in the order pinned, which is saved (`Workspace.pinned` is a list now; old files load). A window that lies in another's strip needs none.
- Without room: the reply and the line on screen say "… stays in view, but other windows can cover it here. Near a screen edge they make room for it."; the menu's ticked row reads "(Can Be Covered Here)"; `state` has `"covered": true` whenever another window really lies over a pinned or summoned window. The line is said again when a pin loses its room: dragged to the middle, or grown too large.
- Docked windows move once: at `pin` and `unpin`; when a drag or a resize of the pinned window ends (while the button is down they wait, whatever else lays out); when it is minimized, hidden or closed, and when it is back; after a command that moved or sized it (`grow`, `shrink`,
  `move-to-display`, undo); and a third of a second after its own app last moved or sized it, whatever that move is taken for. Let go where macOS's own tiling takes it, they go once, to where macOS's frame leaves them.
- While the view is held, at either strength, what the window's own app does brings no layout about: the docked windows follow when the hold ends, at the person's next command (not a script's), when their hand lets go of it, or with whatever else lays the display out. In macOS's full screen, and on its way out of it, it keeps its strip.
- One raise, at `pin`, and only if something covers the window then. No looks, no timers, nothing at a press of the mouse. A summoned window reserves nothing and is not raised: it comes with the keyboard.
- Once pinned, Arbor never moves or sizes it: not one that a hand pushed more than half over an edge, not one made smaller while Arbor was paused or not running; Quit, Float All and a pause leave it where it is, whoever moved it there. Two exceptions: it comes into view, at its own size,
  as it is pinned (not one that its person's own hand left mostly over an edge); and a change of the displays that takes more than half of it brings it wholly into view, in one move. `move-to-display` brings it at its own size, in one move: it is not squeezed onto a Desktop it does not live on. `unpin` neither moves nor sizes it. Where its person pinned or left it hanging over an edge, it hangs there again when its display comes back.
- The stand-in's `raise` stops behind the window that has the keyboard, as a Mac's does, so no test is green by a raise that no Mac would honour. New net in the walks: `pinned-room`; `raised-unasked` now excuses only the raise in the very step that pins or summons.
- Tests: `PinnedRoomTests` (core), `KeepInViewMakesRoomTests`, `collab/scenarios/49-the-call-has-room-of-its-own.sim`; `scripts/mac-shell/check-F49.sh` and the real-window suite's `65-pin.sh` ask the window server.

## Not shipped

- The docked windows go to their places beside a strip at once, without the motion every other act has: two layouts of different rooms are not views of one plane (`stageTransition`). Accepted for now (Q25, point 6).
- On a small display a strip can leave three columns too narrow, and they become tiles: on 1024 points a strip of 340 leaves three of 212, under `minimumUsableWidth`. It dissolves with halves and no Desktop column (Q29); Q25, point 9, has the guard if it does not.
- A window that lies across two displays has room only on the one it belongs to.
- A default shortcut: ⌃⌥⇧D is reserved in `docs/KEYBOARD.md`, unbound.
- A mark on the pinned window itself (a small pin in a corner); the menu's tick, `state` and `ascii` show it.
- Pins waiting for an app that has not opened its window yet at login: a `pin` rule covers that.
- Real windows: `scripts/mac-shell/check-F49.sh` ran on a hosted Mac on 2026-10-15 before the strip: ten checks of the name "nothing covers the call" were red.
