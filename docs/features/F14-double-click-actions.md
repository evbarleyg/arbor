# F14: Double-click actions

Status: ready
Depends on: F01

## Summary

TrellisWM uses double-clicks as quick camera moves: double-click a window's
title bar to give it the whole screen, double-click the Desktop to focus on
it, and double-click again to step back. Arbor has keyboard commands for all
of these but no double-click equivalents, and it opens tiles on a single click.

## Behaviour

- **Title bar**: double-clicking a docked window's title bar frames that window
  (`zoom <id>`). Double-clicking it again while it is framed goes back. This
  replaces macOS's own title-bar double-click action (zoom or minimize, set in
  System Settings → Desktop & Dock) for docked windows only; floating windows
  keep the macOS behaviour.
- **Desktop**: double-clicking bare wallpaper inside the Desktop's area focuses
  the Desktop (`desktop`); double-clicking it again while the camera is on the
  Desktop goes back.
- **Tiles**: open on double-click instead of single click, matching TrellisWM;
  a single click selects (highlights) the tile. Setting `tileClick` with values
  `single` (today's behaviour) and `double` (default).
- Setting `titleBarDoubleClick` (default true) turns the title-bar action off.
- **macOS gets the first click on the wallpaper.** With "Click wallpaper to
  reveal desktop" set to Always (System Settings → Desktop & Dock; the
  default since macOS 14), one click on the Desktop's area sweeps every
  window to the screen edges, Arbor's docked windows included, and
  Accessibility reports nothing. The swarm saw this on macOS 26.6
  (`feat/review-ux`, F42). A Desktop double-click therefore starts by
  sweeping the windows aside. Before building the Desktop action, try on a
  Mac whether an event tap that swallows the first click stops the sweep. If
  it does not, ship the title-bar and tile parts and have the Desktop part
  wait for F42's setup check to ask for "Only in Stage Manager".

## Design notes

- Detection needs the global mouse monitor that `AXWindowSystem` already
  installs. Add `doubleClicked(at:)` to `WindowSystemEvents` (append at the end
  of the protocol) and a simulation helper on `FakeWindowSystem`.
- Deciding what was double-clicked is controller logic and testable: a point
  inside a docked window's frame within 28 points of its top edge is its title
  bar; a point inside `layout.desktopFrame` with no floating window under it
  is the Desktop. Put it in a new `Controller+DoubleClick.swift`.
- Stopping macOS's own title-bar action needs the event to be swallowed,
  which an `NSEvent` monitor cannot do. Use the `EventTap` helper from F03/F05
  (`Input/EventTap.swift`) once it has merged.

## Acceptance criteria

1. Double-click a docked window's title bar: the camera frames it; again: back.
2. Double-click the Desktop: the camera moves to the Desktop; again: back.
3. Double-clicks inside a window's content, or on a floating window, do nothing in Arbor.
4. Tiles open on double-click by default and on single click with `tileClick: "single"`.
5. Old settings files still load.
6. `make check` passes. On a hosted Mac (was a manual check; board, section 5): real double-clicks on real apps' title bars, with macOS's own
   title-bar action set to Zoom, Fill, Minimize and None: one of the two acts, never both (`fought`, `jolt`); a double-click that is not Arbor's reaches the app (`input-held`).
