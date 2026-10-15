# F05: Drag a rectangle to frame it

Status: done except manual check (headless parts tested; the band, the framing on release, that no event of the drag reaches an app, and the hand-back of a ⇧⌘-click checked with real input on test windows, `scripts/mac-shell/input-taps.sh`, 2026-10-14; other apps' windows still to check. **Since 2026-10-14 the default keys are ⌃⌥, not ⇧⌘** (product owner, K069): wherever this spec says ⇧⌘, read "the frame modifier". With ⌃⌥ nothing has been seen on a Mac yet: a ⌃⌥-drag over a window must draw the band and open no contextual menu, and a ⌃⌥-click without a drag must still open the app's)
Depends on: F01

## Summary

Hold ⇧⌘ and drag a rectangle anywhere: the camera moves to the node that best
fits it (`Navigation.bestFit`, already written and tested).

## Behaviour

- ⇧⌘ + drag draws a translucent rubber band; release frames the best-fitting node.
- A drag smaller than 40 × 40 points is ignored.
- The modifier is configurable (`frameRectangleModifier`, default `shift+cmd`).
- The mouse events of the gesture are swallowed so apps do not also select text.

## Design notes

- `Sources/ArborKit/Input/RectangleFramer.swift`: a CGEventTap on left mouse
  down/dragged/up with the modifier held; a rubber-band panel (reuse `OverlayPanel`).
- A new command `frame-rect <x> <y> <w> <h>` so it is testable headlessly
  and scriptable; the tap issues that command on release.

## Acceptance criteria

1. Scenario: `frame-rect` over one window frames that window; over a column frames the column; over everything shows everything (since 2026-10-14, by the product owner: a rectangle that changes nothing to look at fails with "that is already the view", also with nothing docked).
2. Tiny rectangles do nothing.
3. (was "Manual"; board, section 5) On a hosted Mac, a real ⌃⌥-drag over a witness window: the sampler sees the band's panel follow the pointer within 6 points; the witness receives no event of the drag; a plain drag and a ⌃⌥-click reach it as without Arbor (`input-held`).
4. `make check` passes.

## Shipped

- `frame-rect <x> <y> <w> <h>` (global points, origin at the top-left of the
  main display; also `arbor://frame-rect/x/y/w/h`), with parsing, text form
  and help. `Controller+FrameRect.swift` moves the camera to
  `Navigation.bestFit` in the current layout of the display that contains the
  rectangle's centre. A rectangle with a side under 40 points fails and moves
  nothing; negative sizes are normalised; the move goes into back/forward
  history. Scenario tests in `Tests/ArborKitTests/FrameRectTests.swift` cover
  one window, a column, everything, a tile, tiny rectangles, nothing in view,
  a second display and history.
- `ArborCore/RectangleGesture.swift`: what to do with each mouse event, and
  the modifier parser (`shift+cmd`, `Command + Shift`, `⇧⌘`, `none`). The
  modifiers must match exactly, so ⇧⌘⌥-drag stays with apps. Unit tests in
  `Tests/ArborCoreTests/PointerInputTests.swift`.
- `Input/RectangleFramer.swift`: `EventTap`s (the type is shared with F03) on
  left mouse down/dragged/up. Since board item B3 (2026-10-14) they run on
  their own thread, and the tap on drags and mouse-ups is paused except while a
  modifier press is being followed, so ordinary drags never pass through Arbor
  and nothing waits on the main thread. With the modifier held the whole
  drag is swallowed, a translucent band (an `OverlayPanel`) follows the
  pointer, and `frame-rect` is sent on release.
- Not in the original spec: a modifier-click that does not drag (the pointer
  moves 4 points or less) is handed back. The mouse-down is held until the
  button comes up, then sent on ahead of the mouse-up, so ⇧⌘-click keeps
  working in apps (Safari opens a link in a new tab with it).
- 2026-10-15 (Q26): `pointerGestures` is the one switch above this and every other gesture that needs an event tap. Off, `Controller.inputSettings` leaves the taps nothing to ask for.
- Setting `frameRectangleModifier` (default `shift+cmd`), applied at launch
  and on every settings change (`reload-settings`). `none` or `off` turns
  rectangle framing off and removes its tap. An unreadable value is logged
  and the default is used.
- Follow-up (QUESTIONS Q11, T38): plain ⇧-drag that **starts** where no app's
  window is under the pointer (the Desktop, a gap between windows, a tile, a
  seam) frames a rectangle too, as TrellisWM's does. Only the start counts: the
  rectangle is drawn over the windows it is meant to frame. ⇧⌘-drag anywhere
  stays. The decision is `RectangleGesture.mouseDown(at:modifiers:onDesktop:)`
  with `desktopTrigger`, unit-tested; what is under the pointer is decided by
  F60's three questions (where Arbor knows of no window, the window list,
  about 3 ms, then whoever draws the Desktop), so something must be docked on
  the display and the drag must not start on an icon. ⇧ must be the only
  modifier. A ⇧-click that does not drag is handed back like a ⇧⌘-click, so
  Finder still adds an icon to the selection. Setting
  `frameRectangleOnDesktop` (default true); with it off and
  `frameRectangleModifier` `none`, both taps are removed.

## Not shipped

- A rectangle can only frame what is in view. Drawn around the whole screen
  while zoomed in, it keeps the current view, because `bestFit` runs against
  the current layout. Step out with a pinch or ⌃⌥↑.
- ⇧-drag on the wallpaper no longer extends Finder's selection while something is docked;
  `frameRectangleOnDesktop: false` gives that back. (Since F60, ⇧-drag asks the same three questions as the
  guard of the Desktop. So one that starts on an icon or a widget is Finder's, as is one nobody answered for in
  time; the Dock and the menu bar are outside Arbor's view; and with nothing docked on the display Arbor takes no interest.)
- The modifier for the Desktop is ⇧ and cannot be changed.

## Needs manual check

On a Mac with Accessibility granted to Arbor:

1. ⇧⌘-drag: the band appears once the pointer has moved, follows it on every
   display, and disappears on release.
2. Around one window it frames that window; around a column, the column;
   around everything (from the overview), everything stays in view.
3. Text under the drag is not selected, and windows under it neither move nor
   come to the front.
4. A drag smaller than 40 × 40 points does nothing.
5. ⇧⌘-click on a link in Safari still opens it in a new tab. If it does not,
   or the click lands twice, the replay in `RectangleFramer` (`tapPostEvent`)
   is at fault.
6. Plain drags, ⇧-drags and ⌘-drags in apps behave as without Arbor.
7. Clicks and drags stay immediate while Arbor rearranges many windows (for
   example `arrange` with ten windows, one of them in an app that is slow to
   answer).
8. ⇧⌘4, then drag the screenshot area while still holding ⇧⌘: the screenshot
   still works. If Arbor draws its band instead, the default modifier
   collides with screenshots.
9. Revoking Accessibility while Arbor runs leaves input working (F03 check 8
   covers both taps).
10. ⇧-drag from the wallpaper around a window frames it; ⇧-drag in a text
    document, a Finder window's list and a spreadsheet extends the selection as
    without Arbor; ⇧-click on an icon on the Desktop adds it to the selection.
    (`input-taps.sh` checks the events on test windows; this is about real apps.)
