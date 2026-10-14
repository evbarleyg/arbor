# Ideas: better than TrellisWM

Proposals for things TrellisWM does not do, or does in a way Arbor could
improve. Anyone adds; the documenter promotes the good ones into specs and
board items. Keep each to a few lines: the idea, why it helps, and a rough size.

## Already in Arbor

- Keyboard docking: ⌃⌥⌘+arrow docks or moves the focused window (A01).
- `arborctl` with JSON state and an ASCII drawing of the layout (A02).
- No window limit, free and open source.
- Minimum sizes learned from apps that refuse to shrink (A05).
- Windows left off-screen by a crash are recovered on launch (A06).
- Go to…: ⌃⌥G, a few letters, Return, and the view moves to any window or saved view, whatever kept it
  out of view (A27, F27).
- A focus ring: a line around the window that has the keyboard, which flashes when a command
  moved the keyboard (A15, F37). Tiling window managers on the Mac need a second tool for this.
- Named spaces: ⌃⌥N names the space in view, `go <name>` goes there from any display, and the name stays with its windows (I1; A20 to A22, F20).
- Keyboard tiling tools (F22): move focus by direction, into tiles, spaces and displays (A220); trade places
  (A221); grow, shrink and balance (A222); rotate and mirror a group (A223); send a window to another display (A224);
  focus another display, which is I4 without the pointer following (A225).
- I3, undo and redo for changes to the arrangement: ⌃⌥Z and ⌃⌥⇧Z, 50 steps per display (A31, F19).
- Scriptable events (was I5): `arborctl watch` streams the view, layout, focus, windows, displays, settings, pause and resume as
  JSON lines, for status bars (SketchyBar) and automation (A24, F24, `docs/SCRIPTING.md`).
- Options per display (was I6): `displays` in settings.json gives a display, by name, UUID, size, `main` or `builtin`, its own gap,
  tile size and screen edge band; `arborctl displays` (A25, F25).

## Proposed

- **I2: Layout presets.** Save a whole tree (by app) as a preset and re-apply
  it later, opening missing apps. Medium.
- **I4: Focus follows the camera across displays.** One shortcut moves the
  camera to the display under the pointer and focuses its last window. Small.
  (Shipped the other way round in F22: `focus-display` focuses a display's last window; the pointer stays.)
- **I6: Per-display gap and tile size.** Large displays want bigger gaps and
  larger tiles. Small.
- **I5: Scriptable events.** `arborctl watch` streams camera and layout
  changes as JSON lines, for status bars (SketchyBar) and automation. Medium.
- **I7: Record real window events, replay them in tests.** `arborctl trace on|off`
  writes every `WindowSystem` event and every frame Arbor sets as JSON lines
  (window ids, bundle ids, frames, mouse button state, timestamps; never
  titles) in Arbor's home folder. A replayer in `ArborTesting` feeds a trace to
  the real `Controller` through `FakeWindowSystem`. Whoever has a Mac records a
  drag in Safari, VS Code or System Settings once and commits it under
  `collab/evidence/traces/`; from then on it is a regression test that runs
  anywhere, and executors without a Mac can see what real apps do. Medium.
  (cloud executor, 2026-10-14)
- **I8: Screen sharing and video calls.** Parked windows sit in a screen corner
  with one point visible. Check what a Zoom or Meet share of "entire screen"
  shows; offer a "presenting" mode that keeps the shared window framed and
  never moves focus during a call. Small to medium. (documenter, from Q7, 2026-10-14)
- **From the product review (2026-10-14), each with a spec**: pin a window so that it stays in view (F49), peek: hold ⌃⌥Space to
  look and let go to land (F51), an unplugged display becomes a space (F52), summon an app over any view (F53), arrangements as a line of text (F54), hold the view while
  presenting (F58, answers I8), zoom with a mouse (F55), a command line worth scripting (F50).
- **I9: Carry a window across.** Drag a window against the screen edge while framed and hold: the view slides to the neighbouring space and the window comes along. The plane model
  already says what lies beyond the edge. Medium. (product review, 2026-10-14)
- **I10: Arrange, again.** ⌃⌥A pressed repeatedly cycles grid, main and side column, columns, rows; the most used window (`focusHistory`) gets the big slot. Small. (product review, 2026-10-14)
- **I11: Hash the titles in `state.json`.** `hints` keeps window titles in clear text, while the log never does. Matching after a restart needs only equality, so a salted hash will do. Small. (product review, 2026-10-14)
- **I12: Say what Arbor thinks is going on.** `arborctl why <window>`: docked or floating, in view or out of view and why (outside
  the view, in a tile because its app refused 464×319, on another macOS Space, minimized, full screen, ignored by rule 3,
  excluded). Every real-window bug found on 2026-10-14 took a state dump and a reading of the source to explain. Small. (R6, 2026-10-14)
- **I13: A picture overview.** Show Everything drawn from pictures of the windows, darkened, with icon and title, the real windows out of view meanwhile, as the reference does. Decided against as the default (QUESTIONS Q15).
  Only as an option, only where Screen Recording is granted already, only after `docs/VIABLE.md` has passed, and only if pictures hand over to the real windows without a jump that the detectors or the rubric can see. Large. (product owner, 2026-10-14)
- **I14: Gather Floating Windows.** A command, in the menu and undoable, that moves what floats onto the Desktop between the docked windows: what Arbor did by itself at every dock until QUESTIONS Q20, now as something a person asks for. It moves and does not resize. Small, while the placing function is still there. (product owner, 2026-10-14)
