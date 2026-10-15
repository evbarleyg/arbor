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
- **I15: macOS's tiling as a way into Arbor.** A window that macOS has tiled to a half or a quarter is taken as docked there, without being moved: the next layout the person causes puts it on Arbor's gaps. Then a drag to the edge docks at every setting of macOS, and nobody fights (QUESTIONS Q23). To be looked at first: macOS gives a tiled window its earlier size back when it is dragged away, and so does F48. Medium. (product owner, 2026-10-14)
- **I17: A lookout for the event taps' clock.** Shelved by the product owner on 2026-10-15; written, on the branch `fix/a-net-under-the-taps-clock`, with no pull request. While a tap is installed a timer outside the taps' thread looks every 0.4 s whether their clock (`TapPermission`) has beaten since the last look (`TapNet`); at the third look without a beat it invalidates the taps' ports itself and leaves the thread a note to tidy up.
  **Why it is on the shelf:** 63 lines of code where fifteen had been promised; the case it was ruled for, a thread that runs while its timer does not, has no known cause; what it guards against has shrunk from "for ever" to about a second at every event a switched-on tap asks for; and with no tap switched on unless Arbor's keys are down (board 1.53) the rope is up for seconds a day.
  **What an adversarial read found, for whoever takes it off the shelf:** (1) The probe it came with cannot fail for the one line that carries the risk: with only the timer stopped the thread still runs the note, which does the whole measured removal a few milliseconds after the invalidation from outside. (2) The case that needs that line is a thread that STANDS after the right has gone. It was argued away ("macOS switches the taps off by itself"), on rounds in which Arbor was halted before the permission was taken. Once the right is gone it makes no difference to the window server whether the thread answers: such an Arbor meets what the bare tapper met. (3) Whether invalidating a port from another thread makes the window server forget the tap is unmeasured, and so is whether it is safe while that tap's own callback runs, which the rules for handlers forbid; `CGEvent.tapEnable(false)` from outside frees nothing, is allowed anywhere and may be enough. A bare tool with two threads settles both. (4) "Counts looks and compares no times" is not immune to a halt: a repeating dispatch timer that was held up fires once to catch up and then again on its old grid, so two looks can come before the first beat; a one-shot timer re-armed after each look mends it. (5) A stall of 0.8 to 1.2 s with no event, which cost nothing before, now takes the taps away for a second; after the note has run the thread evidently runs, so it could ask at once. (6) `clockStood` needs the guard `heard` has for taps that went meanwhile; a timer that dies while the permission is gone is silent and for good; the note should be posted before the log line.
  **The author's verdict:** the shelf is right. If it comes off, aim it at the standing thread, try `tapEnable(false)` from outside first, and give it a hook that makes the thread stand. Of this branch only the hook `ARBOR_TAP_CLOCK_STOPS_AFTER` is wanted now, as a sabotage for the probes.
