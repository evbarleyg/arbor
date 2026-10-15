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
- **I16: ⌃⌥A must not reach the app in front.** On a tester's Mac, pressing ⌃⌥A (`arrange`) with a widely used desktop chat app in front archived the open conversation in that app, twice in a row: the app's own ⌃⌥A ran, so the key was not taken from it. First find out why a registered hotkey reached the app at all (Arbor running, not paused, nothing in `passThroughApps`). Then, so the next clash is found before a person meets it: Arbor reads the frontmost app's menu bar through Accessibility and `bindings` and the log list every default of Arbor's that the app also uses. A shortcut that destroys or hides something in another app is worse than one that does nothing. Small to find, small to report. (maintainer, 2026-10-14)
- **I17: Every open window should be easy to see.** In the maintainer's words, it is too hard to work when not all open windows are visible. Windows out of view, parked or behind the framed space are hard to find again; Show Everything and Go to… are not enough as the way back. Wanted: a plain, always-available way to see every open window at once and pick one, and a default that keeps windows in view unless the person sent them away. To be decided by the product owner against Q15 (I13) and F26. (maintainer, 2026-10-14)
- **I18: Bring a few windows into a docked group in one step.** It should be easier to take a handful of windows and dock them together as the space in focus: choose two to four windows (from the overview, Go to… with several picked, or by ⇧-clicking), and Arbor docks them side by side and frames them. Today it takes one dock per window. Medium. (maintainer, 2026-10-14)
- **I19: A double-click to fill the screen must stick while arranged.** After `arrange`, double-clicking a window's title bar to make it fill the screen works for a moment, then Arbor puts it back where the arrangement had it. A person who asks macOS for a bigger window has said what they want: Arbor should take it as `zoom` on that window (or let it be until the next double-click), never undo it. Likely the same family as "a hand set outranks every debt Arbor remembers". Small. (maintainer, 2026-10-14)
- **I20: Arbor does less by itself.** More from the same session, with I17 to I19 one theme: the person wants to stay in charge and Arbor to step in only when asked. (a) No empty Desktop column in Arrange: `arrangeDesktopWeight` was set to its floor, 0.1, and even that is too much; wanted is none. The Desktop leaf always takes space today (`LayoutView.isEffective`), so none is an engine change, and a new default would also need Q27's second part to reach anyone who has run Arbor. (b) A dragged window should be assumed to float: docking at a screen edge or beside a window only when asked (by keys, or a modifier held). Today `screenEdgeBand 0` and `windowEdgeFraction 0` come close as a workaround. (c) Docking one window should not arrange every window in the background. (d) The blue focus ring was unwelcome and was switched off (`focusRing false`); worth asking whether it should ship on. (e) While windows move, a tile with the app's icon stands in for the window; wanted is the window itself (`windowPictures`, not ready). (maintainer, 2026-10-14)
- **I21: A window would not dock on the right while another window was minimized.** On a tester's Mac, with one window minimized, a browser window could not be docked on the right. `make sim` with `open Safari`, `open Mail`, `open Chrome`, `dock 101 left`, `minimize 102`, `focus 103`, `dock right` docks it fine, so the difference is on the real Mac (a drag rather than the keys, the browser's own windows, or the minimized window's place in the tree). Needs a trace (`make trace`). (maintainer, 2026-10-14)
- **I22: Fewer, simpler shortcuts.** The maintainer finds the shortcuts too elaborate. The default map binds some fifty keys across ⌃⌥, ⌃⌥⇧ and ⌃⌥⌘ (`docs/KEYBOARD.md`), and several actions differ only by one modifier (look, focus and move on the same arrows). Proposed: a small core of perhaps eight to ten that a newcomer learns in a minute (see everything, go back, dock left/right, undo, float, pause), everything else reachable from Go to… and the menu, and the rest unbound by default and offered in the README's `bindings` recipes. Fewer global keys also means fewer clashes with apps (I16). For the product owner to decide which keys stay. (maintainer, 2026-10-14)
- **I15: macOS's tiling as a way into Arbor.** A window that macOS has tiled to a half or a quarter is taken as docked there, without being moved: the next layout the person causes puts it on Arbor's gaps. Then a drag to the edge docks at every setting of macOS, and nobody fights (QUESTIONS Q23). To be looked at first: macOS gives a tiled window its earlier size back when it is dragged away, and so does F48. Medium. (product owner, 2026-10-14)
