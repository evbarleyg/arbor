# F56: Keys follow the keyboard, gestures follow the pointer

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done (extends the provisional answer to Q2; see Q12)
Depends on: F01
Size: small

## Summary

Camera commands act on the display **under the pointer** and step in **toward the pointer**, wherever they come from. For a pinch that is right. For a shortcut it surprises:

- Two displays, typing in a window on the right one, the pointer left behind on the left one. ⌃⌥↑ zooms the **left** display out. ⌃⌥↩, pressed next, acts on the right one, because window commands follow the focus.
- One display, showing everything, keyboard only. ⌃⌥↓ steps toward wherever the pointer was last left, not toward the window being typed in. There is no way to choose with the keyboard at all until `focus <direction>` exists.

TrellisWM's site says "step in toward the pointer", while its `stepTowardPointer` setting defaults to **off** (T31): its own default seems to be the focused window. Q2's provisional answer keeps the pointer and adds a setting
`stepInToward` (`"pointer"` or `"focus"`); F33 proposes the same switch as `stepTowardPointer`. **One key, please: `stepInToward`.** This spec adds a third value that needs no choosing, and applies the same reasoning to which display a shortcut acts on, which neither covers.

## Behaviour

- A command from a **gesture, a click or a drag** uses the pointer: its display, and the space under it.
- A command from a **shortcut** uses the keyboard focus: the display of the focused window, and `in` steps toward the focused window.
- The exception that makes it feel right: if the pointer has **moved since the last key press or focus change**, the pointer wins for a shortcut too. Someone who points at a window and presses ⌃⌥↓ means that window.
- With no focused window that Arbor arranges, the pointer decides.
- Scripts and URLs: as shortcuts; `--display <id>` (F50) overrides.
- Setting `stepInToward`: `"auto"` (the rule above; proposed default), `"pointer"` (Q2's default), `"focus"`.

## Design notes

- Needs where a command came from (`Controller.perform(_:from:)`, shared with F43) and the time of the last pointer move and of the last focus change. The pointer's last move can be sampled: compare `cursorLocation()` with the value at the last command or focus event.
- `cameraDisplay()` is the one place that picks the display.

## Acceptance criteria

1. Two displays, focus on one, pointer at rest on the other: `out` from a shortcut acts on the focused window's display; from a gesture, on the pointer's.
2. The pointer moved after the last focus change: the shortcut acts on the pointer's display and steps toward it.
3. `in` from a shortcut with the pointer at rest steps toward the focused window.
4. No focused window: as today.

## Shipped (2026-10-14, `feat/F56-keys-follow-the-keyboard`)

- `CommandSource` reaches the controller through `perform(_:from:)`; `perform(_:)` is unchanged and counts as a script.
- `stepInToward`: `"auto"` (default), `"pointer"`, `"focus"`. It decides the display **and** the direction of `in`. Gestures and the menu
  follow the pointer whatever it says.
- "Since the last key press" is measured, not sampled: macOS says how long the pointer has been still and how long ago a key was last
  released. Sampling the pointer at commands and focus changes would miss the commonest way into the trap (click a window, push the
  mouse aside onto the other display, type).
- Shortcuts pressed one after another, with nothing typed in between, stay with the first one's choice.
- `in` toward a focused window that floats steps toward the Desktop. `in` from the menu: the pointer's display, toward the focused window.
- arbor-sim: `press <command>`, `from <source> <command>`, `type`, `wait <seconds>`.

- Follow-up (product owner): a focused window Arbor does not arrange (Don't Arrange “zoom.us”) still decides the display; a typo in `stepInToward` is logged once.

Not shipped: `--display <id>` (F50). Window commands (⌃⌥↩, ⌃⌥⌘ + arrow) still mean the focused window even right after pointing.
