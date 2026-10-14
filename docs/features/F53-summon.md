# F53: Summon an app over any view

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done
Depends on: F01, F06; shares its mechanism with F49 (pin)
Size: small to medium
Rank among "what would make people recommend it": 4

## Summary

Some apps are visited for ten seconds, many times a day: a terminal, a scratch note, a calculator, the music player, a password manager. Giving them a slot wastes space; leaving them on the Desktop means a camera trip there and back. Tiling
window managers call the answer a scratchpad, terminals call it a drop-down (Quake) mode, and people install separate tools to get it.

## Behaviour

- `summon <app>`: that app's most recently used window appears **over the current view**, at the size and place it had the last time it was summoned (the first time: centred, its own size), focused. The view does not move.
- `summon <app>` again, or focusing anything else, sends it out of view again. (`"summonStays": true` keeps it until summoned away.)
- If the app has no window, it is activated so that it opens one (`NSWorkspace.openApplication`), and that window is summoned when it appears. If it is not running it is launched.
- A summoned window is floating. If it was docked, `summon` only moves the view to it, as ⌘Tab would: a docked window has a place, and the place wins.
- No default shortcuts; the README shows the recipe:
  `"bindings": { "ctrl+opt+`": "summon com.apple.Terminal", "ctrl+opt+'": "summon Notes" }`.

## Design notes

- A summoned window is a pin (F49) that ends by itself: `Workspace.summoned: WindowID?` and a remembered frame per bundle id.
- `windowFocused` for another window ends the summon; so do pausing, floating everything and closing the window.
- Launching goes through a new `WindowSystem.open(bundleID:)`, appended; the fake records it and can "open" the window later.

## Acceptance criteria

1. Framed on a docked window, `summon Terminal`: Terminal's floating window is in view and focused; camera and every other frame are unchanged.
2. Again: it is out of view, and focus returns to the window that had it.
3. Focusing another window sends it away; with `summonStays` it stays.
4. Moved or resized while summoned, it returns to that frame next time, also after a restart.
5. No window, or not running: the app is asked to open, and the window is summoned when it appears within 5 s.

## Shipped (2026-10-14, `feat/F53-summon`, on top of F49)

All five criteria, each with scenario tests (`Tests/ArborKitTests/SummonTests.swift`, `Tests/ArborCoreTests/SummonModelTests.swift`,
`collab/scenarios/53-summon-a-terminal.sim`). Beyond the text above, decided while building (`collab/QUESTIONS.md`):

- **Sent away, a window is stashed**: it stays out of view in every view, the Desktop and Show Everything included, until it is summoned again. A window that went back to living on the
  Desktop could not be sent away in any view that includes the Desktop, and the second press of the key would seem to do nothing. Switching to a stashed window (⌘Tab, the Dock) summons it. `home` (⌃⌥0), docking, pinning and
  `float-all` make it an ordinary window again; `show-all` leaves it alone; `status` counts it among the windows out of view. (Accepted by the product owner, who added `home`.)
- `Workspace.summoned` holds the window **and** the key its frame is filed under (`Summon`), so that the core alone keeps `summonFrames` up to date whenever the window's floating frame changes.
- Frames are remembered per display and app. The window comes to the display camera commands act on: since F56 the one that has the keyboard, or the pointer's if the pointer moved last.
- Another window of the same app does not end the summon; only a report for a window that really has the keyboard does.
- One summoned window per display; summoning another app replaces it, and the keyboard later returns to where it was before both.
- A minimized window or a hidden app counts as "no window": the app is opened, and the window summoned when it shows.
- `summon` is **not** accepted from `arbor://` URLs unless `allowAllURLCommands` is on: it can launch any app.
- The seam is `WindowSystem.openApplication(_:) -> Bool`, taking a bundle id or a name (`summon Notes` has no bundle id to give), not `open(bundleID:)`.

Follow-ups from the product owner's verdict (`feat/F53-follow-ups`): a window in view with the keyboard in it, where the user put it, is summoned where it is; a summoned window that was minimized or hidden since comes back with one press;
`zoom <id>` on a window that was sent away summons it; `float` makes a summoned or sent-away window an ordinary floating window again.

- Since the bug bash (`fix/F49-F53-round-2`): `summon` of a docked window toggles too (product owner, 13:27 UTC): there as ⌘Tab would go, and back where you were. A window the Desktop had squeezed is its own size once summoned where it is (product
  owner, 12:03 UTC: "grow"). Carried by hand to a display with a summoned window of its own, it takes that one's place.

## Not shipped

- A menu item: which apps to summon is for `bindings` to say.
- A grace period or animation; the window appears and goes at once (F02's stage is not involved).
- Real windows: `scripts/mac-shell/check-F53.sh` is written and has not run.
