# Changelog

All notable changes, newest first. Maintained by the feature documenter as
feature branches merge. Feature ids refer to `docs/features/`.

## Unreleased

### Fixed

- **B2 Numbers from outside can no longer crash Arbor** (2026-10-14). A huge
  or not-a-number value in a command, a URL, `settings.json` or `state.json`
  used to crash Arbor or leave its layout broken for good: `resize 101 right
  1e300` killed it, a large `gap` made every frame invalid, and a bad date in
  `state.json` crashed it at every launch. Commands now refuse such numbers,
  and the layout, the scheduler and the gesture code stay finite.
- **B3 Event taps run on their own thread** (2026-10-14), so a slow app
  that keeps the main thread busy no longer holds up clicks, drags and
  trackpad gestures system-wide.

### Tooling

- **Real windows in CI** (P3, 2026-10-14): GitHub's macOS runners grant
  Accessibility, so every pull request runs `make e2e` on real windows (42 checks).
- **`mac-shell` workflow** (P2, 2026-10-14): any script from the repository on
  a macOS runner, on demand.
- **Executable scenarios** (S1, 2026-10-14): `expect` lines in arbor-sim; five
  user journeys run in `make check`.
- **Linux build** (S2, 2026-10-14): the core, controller, fakes, arbor-sim and
  all tests build and run on Linux, for agents without a Mac.

### Added

- **F03 Trackpad pinch** and **F05 Drag a rectangle to frame it** (2026-10-14).
  ⌥-pinch anywhere, or pinch on the Desktop, steps the camera in or out;
  ⇧⌘-drag a rectangle (or `frame-rect x y w h`) frames what it covers. Both
  run through one shared event tap that removes itself if Accessibility is
  revoked. 42 tests.
- **F08 Display reconnects and Spaces** (2026-10-13). A disconnected display's
  arrangement is kept (for 30 days, across restarts) and comes back when it
  reconnects; windows on other macOS Spaces keep their slots instead of
  dropping out of the tree. 26 tests.
- **F07 Resize docked windows by their own edges** (2026-10-13). Dragging a
  docked window's edge moves the seam on that side instead of springing back;
  outer edges still spring back. 17 scenario tests.
- **F11 Per-app rules** (2026-10-13). `rules` in settings.json decide what
  happens to new windows of an app: `float`, `dock <edge>`,
  `dock beside <bundle id> <edge>` or `ignore`. `arborctl rules` explains them.
  37 tests.
- **F06 Key bindings in settings.json** (2026-10-13). `bindings` maps chords
  such as `ctrl+opt+h` to any command, or `null` to remove a default;
  `reload-settings` re-registers them; `arborctl bindings` lists the table.
  27 tests.
- **F01 Dock and zoom** (2026-10-13). Real windows dock into nested splits
  with the Desktop kept as a space; a camera shows everything, steps in and
  out, frames one window, moves to neighbouring spaces, goes back and forward,
  and recalls nine saved views per display. Windows outside the view are parked
  in a screen corner and come back when the camera returns or when you switch
  to them. Tiles stand in for spaces too small to use and for apps that refuse to
  shrink. Seam handles resize neighbours. Floating windows live on the Desktop.
  Arrangements persist across restarts; quitting puts every window in view.
  Control through hotkeys, the menu bar item, `arborctl`, `arbor://` URLs and
  `settings.json`. Verified by 82 headless tests and a real-window `make e2e`
  run.
