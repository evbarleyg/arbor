# F08: Display reconnects and Spaces

Status: done (verified headlessly; `scripts/mac-shell/check-displays.sh` ran on a hosted Mac with a virtual second display for the first time on 2026-10-15: 110 passed, 19 failed, eighteen of them one family, board 1.33, and one the script's own; Spaces, `check-desktop.sh`, have not run)
Depends on: F01

## Summary

When a display is disconnected, its windows currently float onto the main
display and its arrangement is thrown away. Unplugging a laptop from a
monitor and plugging it back in should restore the arrangement. Separately,
windows on other macOS Spaces should not be lost from the tree.

## Behaviour

### Displays

- When a display disappears, keep its workspace as **dormant** (in memory and in
  `state.json`), keyed by display UUID. Its windows float on the main display
  as today, and the dormant workspace remembers where each one was docked.
- When a display with a dormant workspace appears, restore it: every window
  still open and still floating where it was evacuated to (not docked
  elsewhere since) goes back to its slot; windows docked elsewhere since then
  stay where they are and are removed from the dormant tree.
- Dormant workspaces older than 30 days are discarded on load.
- A display whose visible frame changes (Dock moved, resolution changed)
  re-lays out without losing anything (already true; add a test).

### Spaces

- Windows on another Space are reported missing by the Accessibility API but
  still exist. They must not be removed from the tree when a Space switch
  hides them; they should be treated as absent (take no space) and come back
  when their Space is active again.
- Only `windowDestroyed` (or the app terminating) removes a window.

## Design notes

- Add `dormant: [DisplayID: DormantWorkspace]` to `PersistedState` (decode as
  optional for old files) and to `Controller`. `DormantWorkspace` holds the
  `Workspace` and the date it went dormant.
- `Controller.displaysChanged()` is where evacuation happens today.
- For Spaces: `AXWindowSystem.rescanAll()` runs on `activeSpaceDidChange`.
  Add an `isOnActiveSpace` flag to `WindowSnapshot` (true by default, so the
  fakes and existing tests are unaffected). `WindowSnapshot.isPresent` must
  include it. On rescan, windows no longer listed get `isOnActiveSpace = false`
  and a `windowChanged` event, rather than being dropped. A window listed again
  flips back. The fake gets `setOnActiveSpace(_:_:)`.

## Acceptance criteria

1. Disconnect then reconnect a display: its tree, camera and saved views come
   back, and its windows return to their slots.
2. A window docked on the main display while its old display was away stays
   on the main display after the reconnect, and the restored tree is valid
   (`invariantViolations()` empty).
3. Dormant workspaces survive a restart (`state.json`) and old ones expire.
4. A window on another Space keeps its slot and takes no space; it comes back
   to the same slot.
5. Changing a display's visible frame relays out without changing the trees.
6. Old `state.json` files (without `dormant`) still load.
7. `make check` passes.

## Shipped

- A display that disconnects keeps its workspace as dormant
  (`Controller.dormant`, `PersistedState.dormant`, with the date it went away)
  and its windows float on the main display. If the main display's Desktop is
  out of view they wait there parked, like its other floating windows. The
  display's tiles and seam handles are removed.
- When it reconnects, its tree, camera, history and saved views come back.
  Windows that are still open and not docked anywhere else return to their
  slots (floating ones to their frames); windows docked elsewhere meanwhile,
  closed, or no longer arranged are removed with `Workspace.forget`. When a
  workspace goes dormant, the windows docked in it are removed from older
  dormant workspaces, so the newest arrangement of a window wins.
- Dormant workspaces are saved in `state.json` (files without the key still
  load), re-matched at launch like the connected ones (docked windows by app
  and title), restored at launch if their display is back, and discarded at
  launch after 30 days. A saved workspace whose display is missing at launch
  becomes dormant. Displays with nothing arranged are not remembered.
- If every display disappears for a moment, the arrangements come back with
  the displays.
- A drag that outlives the display it started on ends cleanly (it crashed on
  a force unwrap before).
- Spaces: `WindowSnapshot.isOnActiveSpace` (part of `isPresent`) and
  `FakeWindowSystem.setOnActiveSpace(_:_:)`. `AXWindowSystem` asks the apps for
  their windows again after a Space switch, when an app is shown and when a
  window is un-minimized, and marks the windows it no longer lists as off the
  active Space instead of dropping them. An app that does not answer in time
  keeps its windows as they were. The controller lays a display out once after
  a Space switch (after the drop, if a window is being dragged) rather than
  after each window, so no window is moved for one whose Space went away.
- Scenario tests in `Tests/ArborKitTests/DisplayTests.swift` and
  `SpaceTests.swift` cover every acceptance criterion, including save,
  restart and old-format decoding.

## Not shipped

- Windows on other Spaces when Arbor launches: the Accessibility API does not
  list them, so their saved slots are dropped and they float once their Space
  is shown. Keeping them needs another way to know a window still exists (for
  example `CGWindowListCopyWindowInfo`).
- A window moved to another Space without a Space switch (Mission Control,
  "Assign To") is noticed at the next switch.
- Dormant workspaces expire only at launch. Floating windows of a dormant
  workspace are not re-matched when their numbers change (docked ones are).
- No `arbor-sim` commands for displays or Spaces.
- Not verified with real windows: which windows the Accessibility API lists
  after a Space switch (minimized windows, hidden apps, several displays with
  separate Spaces) and whether it lists them by the time the notification
  arrives; and a real unplug and replug, where macOS moves windows itself.
