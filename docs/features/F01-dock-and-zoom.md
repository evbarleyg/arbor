# F01: Dock and zoom

Status: done (82 headless tests when it merged; `make e2e` passes on real windows; an edge drag, a seam, a tile, two shortcuts, the menu and quitting tried with real input on test windows, 2026-10-14)
Depends on: none

## Summary

The core of Arbor: real windows dock into a nested tree of splits with the
Desktop kept as a space, and a camera moves between spaces.

## Shipped

- Docking by drag (screen edges dock at the edge of the view, window edges
  dock beside that window, the Desktop or a window's middle floats, a
  window's own slot snaps back) with a live drop preview.
- Docking by keyboard (⌃⌥⌘ + arrow docks the focused window at that edge of
  the view; on a docked window it trades places with its neighbour or steps
  out of its group) and by command (`dock`, `dock … beside …`, `float`,
  `toggle-float`, `arrange`, `float-all`, `resize`).
- Camera: show everything (⌃⌥Space), step out/in (⌃⌥↑/↓, toward the pointer),
  neighbouring space (⌃⌥←/→, ⌃⌥⇧↑/↓), back/forward (⌃⌥[ ]), frame the
  focused window (⌃⌥↩), Desktop (⌃⌥D), saved views (⌃⌥⇧1–9 saves, ⌃⌥1–9 recalls).
- Windows outside the view are parked in a screen corner; focusing one moves
  the camera to show it, and keyboard focus leaves windows that go out of view.
  Until 2026-10-14 that held on a real Mac only when the app's own focused window
  changed (⌘`, the Window menu): macOS posts no focus change when an app merely
  comes forward (⌘Tab, a Dock click, a click across apps), and the camera stayed
  (`collab/evidence/gestures-latest.txt`). Since then Arbor observes app activation too.
- Floating windows live on the Desktop: they leave and return with it,
  remember where the user put them, and are pushed back onto the Desktop when
  docked space grows over part of them. One that docked space covers completely
  stays where it is and can end up behind the docked window.
- Tiles for nodes too small to use and for windows whose app refuses to
  shrink (minimum sizes are learned); clicking a tile zooms onto it. On real
  windows a `dock` command that ends in such a tile moves the camera onto the
  window instead of leaving the tile in view (finding 2 of the same report).
- Seam handles in the gaps resize neighbours (on real windows only since
  2026-10-14; before that, clicks fell through the transparent handle).
- Minimized windows, hidden apps and closed windows give their space to their
  neighbours; minimized and hidden ones come back to the same place. On a real
  Mac un-minimizing also zooms the camera onto the window, because the focus
  change is reported before the window counts as present (same evidence).
- Persistence across restarts, with re-matching by app and title and
  protection against reused window numbers; windows left off-screen by a crash
  are brought back; quitting puts every window in view.
- Per-app exclusion (`exclude`/`include`, menu item), settings file, control
  socket and `arborctl`, `arbor://` URLs, menu bar item, launch at login.

## Not shipped (see other specs)

Still open: animation (F02), tab strips (F04), drag dwell (F09). Shipped since:
gestures (F03), rectangle framing (F05), configurable keys (F06), resizing by
window edges (F07), display re-attach and Spaces (F08).
