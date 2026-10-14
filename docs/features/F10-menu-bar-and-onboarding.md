# F10: Menu bar controls and onboarding

Status: done
Depends on: F01

Shipped (2026-10-14, `feat/F10-menu-bar`): the buttons (back, forward,
the Desktop, Show Everything, one per saved view, the current one filled in, and one that opens the menu) for the display under
the pointer, with a tooltip each, and Arbor's mark alone while nothing is docked there; right click, ⌃-click or ⌥-click for the full menu, built from a headless model in the order of `docs/MENU.md`, with native shortcuts and ticks, and greyed out where a command would fail; settings
`menuBarControls`, `historyButtons`, `menuBarFill`; the app icon and the same mark in the menu bar; the welcome window with live
ticks for Accessibility and the Desktop & Dock settings that compete with Arbor (Screen Recording has a row too, not offered until pictures of windows have been seen to work on a Mac), and rows for competing apps,
VoiceOver and input sources when they apply; the commands `doctor`, `check-setup`, `welcome`, `menu-bar` and `menu`.
Differs from criterion 2, by the coordinator's decision after the product review: when the permission arrives the window
does not close but goes on to a second page, three moves to try, ticked off live, ending on the three ways back. It also
opens when Arbor is opened again.
With `feat/F10-no-room`: falling back to the single icon by itself when macOS leaves a wide item out of a full menu bar, and `doctor`'s row "Menu bar item" (tested against a stand-in; what macOS really answers is unseen).
Not shipped: following the pointer to another
display without waiting for the next change; the rows of `docs/MENU.md` that change while ⌥ is held; noticing that the permission was taken away while Arbor
runs, which is F63; what is left of F42 and F46 (see their status lines).

## Summary

TrellisWM's menu bar item shows back/forward buttons and one button per saved
view, with the current one filled in; right-click opens the menu. First launch
explains the permissions.

## Behaviour

- The status item shows: back, forward, and buttons for Desktop, Everything
  and each saved view; the button for the current camera is filled. Left-click
  a button to go there; right-click (or ⌥-click) anywhere opens the full menu.
  A setting `menuBarControls` (default true) falls back to the single icon.
- An app icon (also used for the menu bar template image).
- First launch without Accessibility permission opens a small window: what
  Arbor does, why it needs Accessibility, a button that opens the right
  System Settings pane, and a live checkmark when permission arrives.
  Mentions turning off macOS's "Drag windows to screen edges to tile".

## Acceptance criteria

1. The menu bar reflects camera changes within one relayout (observe the controller after each command).
2. Onboarding appears only while permission is missing and closes itself when it is granted.
3. Manual: buttons work, right-click menu works, icons look right in light and dark menu bars.
4. `make check` passes.
