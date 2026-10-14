# F51: Peek: hold to look, let go to land

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done
Depends on: F01; much better with F02
Size: small to medium
Rank among "what would make people recommend it": 2

## Summary

Going from one framed window to another takes three decisions: zoom out, find it, zoom in. ⌘Tab is one gesture but sorts by recency, not by place, and Arbor's whole promise is that things have a **place**. Make Show
Everything spring-loaded, like ⌘Tab, Exposé's hold-the-key mode and spring-loaded folders.

## Behaviour

- **Tap** ⌃⌥Space (released within 0.3 s): as today, the view stays on everything.
- **Hold** ⌃⌥Space: everything is shown while the keys are down. The window or tile under the pointer is outlined; the arrow keys move the outline too. **Letting go frames what is outlined.**
- Letting go with the outline where you came from, or pressing ⎋ first, returns to the view you left, and history gets no entry.
- A click while holding frames what was clicked at once.
- History records one move, from where you were to where you landed.
- Setting `peek` (default true).

## Design notes

- Carbon reports `kEventHotKeyReleased` for a registered hot key; add it to `HotKeyCenter`'s event spec and forward `(command, phase)`. ⌃ or ⌥ going up first also ends the hold: watch `flagsChanged` with a
  passive `NSEvent` global monitor only while a peek is on.
- Controller: `peekBegan()`, `peekMoved(to:)`, `peekEnded(commit:)` in `Controller+Peek.swift`, with the tap-or-hold decision made from `scheduler` time, so tests drive it with `ManualScheduler`.
- The outline is a new field of `OverlayScene`.
- The arrows need temporary hot keys (plain arrows, ⎋) registered only during the hold.

## Acceptance criteria

1. Press and release within 0.3 s: the view is on everything, one history entry.
2. Hold, move the pointer over a window, release: that window is framed; `back` returns to the view before the peek.
3. Hold and release without moving, or ⎋: the original view, no history entry.
4. Temporary hot keys are gone after every ending, including the window under the outline closing and Arbor pausing.
5. Manual: with F02 the whole thing reads as one motion out and one in.

## Shipped (2026-10-14, `feat/F51-peek`)

- Everything under Behaviour, for whatever shortcut is bound to `show-all`; `home` (⌃⌥0) never peeks. Setting `peek`, default true.
- The decision is a pure value, `Peek` (ArborCore). `HotKeyCenter` forwards press and release and nothing else.
- **The arrow keys and ⎋ are ⌃⌥ + arrow and ⌃⌥⎋**, not the plain keys: ⌃⌥ are being held. All five are bound by default, so a peek takes those chords by
  their keys, whatever they are bound to; temporary hot keys are registered only for the ones a user has unbound.
- Nothing differs from a plain Show Everything for the first 0.3 s: ⌃⌥Space ⌃⌥↓ rolled off the fingers still shows everything and steps in.
- Instead of a `flagsChanged` monitor and a mouse monitor, a timer reads the keys, the pointer and the button 30 times a second during the hold. It also ends a
  peek whose release was never reported. In doubt a peek ends as a tap, so Show Everything cannot start springing back.
- A click lands when the button comes up. The outline's panel takes the click and reports it, so the app underneath never sees a ⌃⌥-click; the timer also
  watches the button, for a click on a space other than the outlined one.
- Another command, a drag or an edge resize during the hold leaves the view on everything, and the release then does nothing. A camera moved by
  anything else (a clicked tile) is the landing: one history entry from the view before the peek.
- The outlined window closing does not end the peek: the outline returns to the view that was left, or disappears if that is gone too.
- arbor-sim: `keydown`, `keyup`, `key <shortcut>`, `mouse down|up`, `expect outline <id>|desktop|none`.

- Follow-up (product owner, after the merge): a hold during which nothing was chosen (no pointer move beyond the slop, no arrow) and that lasted under 1 s counts as a tap: everything stays.
  Someone who is lost presses three keys slowly and on purpose. From 1 s on, letting go without choosing returns, as acceptance 3 says.

Not shipped: a setting for the 0.3 s. Acceptance 5 (one motion out, one in) waits for F02 and a Mac. **Not yet compiled or run on a Mac.**
