# F37: Focus ring

Written by the executor swarm, 2026-10-14; for the documenter to review

Status: done (headless tests; 45 checks and pictures on real test windows on macOS 26; other apps' windows still to see)
Depends on: F01

## Summary

Someone who moves between windows with the keyboard has to see which window will take what they type.
macOS says so with the colour of three small buttons and a slightly stronger shadow, which is little to go by when
six tiled windows change places at a keystroke. Arbor draws a line around the window that has the keyboard.
TrellisWM has nothing like it; people who use tiling window managers on the Mac install a separate tool
(JankyBorders) for it.

## Behaviour

- The ring is a line around the focused window, if Arbor arranges that window and it is in view: docked and shown by
  the layout, or floating and not parked. There is at most one ring, on the display whose workspace holds the window.
- **No ring at all while nothing is docked on any display** (product owner, 2026-10-14): before the first dock the person has not asked Arbor for anything, and after Float All Windows they have asked for a normal
  Mac. Every window Arbor looks after counts as floating, so without this rule every focused window on the Mac wore an accent-coloured line from the first second after launch. Docked anywhere is enough, so that the ring
  does not come and go as the keyboard moves between displays.
- No ring for: a window Arbor does not arrange (excluded or ignored apps, sheets, dialogs, panels), the desktop, a parked window,
  a window inside a tile, a tab behind another, a minimized window, a hidden app, a window on another Space.
- It is around the frame the window really has, not its slot: a terminal that snaps to character cells sits a little
  inside its slot, and the ring hugs the terminal.
- **It covers no content.** The line lies just outside the window, in the gap. If the gap is thinner than the line,
  the line takes what fits outside and the rest lies inside; with a gap of 0 it is inside altogether. Floating windows have
  room all round. On a side where the window reaches the edge of the usable screen (a floating window that fills the
  screen), the line moves inside, because beyond that edge it could not be seen.
- **It follows at once**: focus changes (clicks, ⌘Tab, ⌘`, commands), relayouts, and the focused window moving by
  itself. Following focus moves no window and lays nothing out again.
- **It stays away from the mouse.** While a window is dragged or resized with the mouse (title bar, window edge, seam),
  the ring is hidden, because Accessibility reports a window's moves well behind the pointer and the ring would
  trail it. It returns when the button is up. A click that only moves the keyboard does not hide it: the ring
  is on the clicked window before the button is released.
- **It flashes when Arbor moved the keyboard.** When the ring goes to another window (or comes back) within half a second
  of a command or a camera move (`dock`, `zoom`, `focus …`, a tab switch, a clicked tile, ⌘Tab to a window out
  of view), a band three times the line's width fades out over 0.25 s, outwards only, so the eye finds it. Clicks do not flash:
  the eye is already there. With macOS's "Reduce motion" on there is no flash.
- It never takes a click, never takes focus, is not in the window cycle, and Mission Control hides it.

## Settings

| Key | Default | Meaning |
|---|---|---|
| `focusRing` | true | Draw the ring |
| `focusRingWidth` | 3 | Thickness in points, clamped to 1…12 |
| `focusRingColour` | `"accent"` | `accent` (the accent colour of System Settings), `#RRGGBB` or `#RRGGBBAA`. Anything else falls back to `accent` with a line in the log |
| `focusRingRadius` | 0 | The radius of the window corners the line follows, up to 60. 0 picks it by system: 17 on macOS 26, 10 before |

They apply on `reload-settings`. Old settings files load.

## Design notes

- **Model.** `OverlayScene.focusRing: FocusRingModel?` (`Platform/FocusRingModel.swift`): the window, its frame, the line's outer
  edge, width, radius, colour and a `pulse` token that changes when the ring should flash. `band(reaching:automaticRadius:)`
  gives the view the rounded frame to paint, for the line and for the flash. Colour parsing, clamping and the line's
  place are in `ArborCore/FocusRing.swift`.
- **Who has the keyboard** is asked of `system.focusedWindow()` every time the ring is worked out
  (`Controller+FocusRing.swift`), not remembered from `windowFocused` events: an app in the background reports focus
  changes too. Events only say when to look again. One is new, `WindowSystemEvents.keyboardFocusMoved()`: another app came to the
  front (which changes no app's own focused window), or the keyboard went to something that is not a known
  window. It refreshes the ring and does nothing else. `AXWindowSystem` sends it when an app without a known focused window becomes
  active (one with such a window sends `windowFocused`), and for each observed app's own activated and deactivated notifications. Because an event can arrive before the window system's
  answer has changed, the controller looks once more a quarter of a second after each.
- **Refreshing.** A relayout works the ring out as part of the display's scene. Everything else sends a fresh scene only to
  the displays whose ring is out of date (at most two).
- **The mouse.** No event reports the end of a seam drag, and dropping a floating window lays nothing out. So while the ring is held
  back, the controller looks every 0.1 s whether the button is up. If the button is up but the drag or resize has
  not been reported as over after half a second, that event was lost and the ring returns anyway.
- **View** (`UI/FocusRingPanel.swift`): one mouse-transparent panel per display with two `CAShapeLayer`s, the line and the flash, each
  the area between two rounded rectangles with the continuous corner curve (`UI/ContinuousCorners.swift`). Measured on a
  screenshot of macOS 26, a window's corner starts to bend some 24 points before the corner and fits the continuous curve of
  radius 17; circular arcs, and a layer's border, left slivers of wallpaper at the corners' shoulders. Frame changes are not
  animated; the flash is.
- **Level.** The panel is at the normal level, ordered directly above the focused window
  (`order(.above, relativeTo:)` takes the window server's numbers, so another app's window works). It behaves like part
  of the window: a floating panel, a picture-in-picture video or the window's own popover that overlaps the window's edge also covers
  the ring, and so does F02's stage, which is in front of every real window. At the floating level the line would cut
  across all of those. The price: a clicked window takes the keyboard first and comes to the front afterwards, which leaves
  the ring behind, under other windows' shadows (seen on real windows), and nothing reports a change of stacking. So the view
  puts the ring above its window again on every mouse-up, and 0.15 s after that and after every update.
- The panel spans the window it surrounds, so `GestureTap`'s "is an app's window under the pointer" skips Arbor's own windows
  instead of stopping at the first.

## Acceptance criteria

1. The ring is around the focused window after clicks, app switches and commands; a background app's focus change does not take it.
2. No ring for unmanaged, parked, tiled, hidden-tab, minimized, hidden and other-Space windows, or when nothing is focused.
3. It moves with relayouts and with a window that moves by itself, and is around the frame the app took.
4. It is hidden during title-bar drags, edge resizes and seam drags and back when the button is up, even if the event that ends the drag is lost.
5. It exists on one display only, and follows the window to another display.
6. The `pulse` token changes when a command or a camera move moved the ring, and not for clicks or after a drag.
7. Width, colour, radius and the switch follow the settings; the line is outside with a gap, inside without; old settings files load; unknown colours fall back and are reported.
8. Windows end up in the same places with the ring on and off.
9. On real windows: aligned with the window's corners, visible on light and dark, lets clicks through.
10. `make check` passes.

## Shipped

- **An option since 2026-10-15: `focusRing` ships false** (`collab/QUESTIONS.md`, Q29: nothing is drawn that was not asked for). Everything below
  holds once it is switched on; its tests, scenario and scripts switch it on.
- Everything above. 59 scenario tests and 15 core tests (`FocusRingTests.swift` in both test targets), the scenario
  `collab/scenarios/06-focus-ring.sim` with the new `expect ring <id>|none`, and `scripts/mac-shell/shots-focus-ring.sh`, which
  checks the ring's place and stacking on real windows against the window server's own list and takes the pictures
  (`collab/evidence/focus-ring/`).
- `AXWindowSystem.focusedWindow()` no longer asks an app it does not observe: such an app has no window Arbor knows, and the
  question could wait six seconds for an app that hangs.

## Not shipped

- No command or menu item switches the ring; `set focusRing false` will when F12's `set` lands, and the four keys need a line each in
  its `SettingsSchema`.
- One radius for every window. macOS 26 gives windows with a toolbar rounder corners than windows with a plain title bar, and nothing
  public tells which a window has; around a rounder window a little wallpaper shows at the corners.
- The panel spans the window it surrounds, so tools that pick "the window under the pointer" from the window list
  (⇧⌘4 then Space) may pick the ring over the focused window. Not seen, not ruled out. If it does, build the ring from four
  strips and four corners instead of one panel.
