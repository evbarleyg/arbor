# Board

The documenter orders **Ready**; executors take the top item they can do,
move it to **In progress** with their branch, and to **Done** after merging
(see `collab/README.md`). Several executors can work at once on different items.

The marks [S], [L] and [M] name the executor an item was given to when the board was last ordered. They bind nobody now.

Last reordered by the documenter: 2026-10-14, 07:15 UTC.

## Review: branches finished, waiting for an executor to review and merge

| Item | Branch | Report | Merge notes |
|---|---|---|---|

## In progress

| Item | Branch | Started by |
|---|---|---|
| [S] S3 Record and replay window traces (built by M, handed over for review) | `feat/S3-window-traces`, PR #12 | Swarm, 2026-10-14 |
| [S] F09 Drag polish (with T08) | `feat/F09-drag-polish` | Swarm, 2026-10-14 |
| [S] F04 Tab strips (with T13 to T15) | `feat/F04-tab-strips` | Swarm, 2026-10-14 |
| [S] F02 Animated transitions, then F16 Continuous zoom and pan | `feat/F02-transitions`, `feat/F16-continuous-zoom` | Swarm, 2026-10-14 |
| [S] F14 Double-click actions | `feat/F14-double-click` | Swarm, 2026-10-14 |
| [S] F15 Appearance options | `feat/F15-appearance` | Swarm, 2026-10-14 |
| [S] F10 Menu bar controls and onboarding | `feat/F10-menu-bar` | Swarm, 2026-10-14 |
| [S] F12 Settings window (`set`/`get` commands first; B1 has merged, so the window can follow: notes in PR #44) | `feat/F12-settings-window` | Swarm, 2026-10-14 |
| [L] A state.json with fields of a later Arbor was saved over without them, with no note and no copy (found attacking the trunk's state.json for triage) | `fix/state-keys-of-a-later-version`, PR #240 against `swarm/trunk` | Executor L, 2026-10-14 |
| [S] F13 Distribution, the parts that need no Developer ID | `chore/F13-distribution` | Swarm, 2026-10-14 |
| [S] T21, and IDEAS I1 to I6 (undo, named spaces, presets, watch, per-display options) | `feat/I*` | Swarm, 2026-10-14 |
| [S] Chaos test: random commands and events against the controller's invariants | `test/chaos` | Swarm, 2026-10-14 |
| [S] Screenshots of the real app from the Mac shell workflow | `ci/screenshots` | Swarm, 2026-10-14 |

## Ready, in priority order

1. **[S] F17: Real-window hardening.** Drag detection that does not depend on
   move notifications, a limit on enforcement loops, window-level AX timeouts,
   and an opt-in real drag in the e2e runner. F07 has merged, so this can start now.
2. **[S] F05 follow-up: plain ⇧-drag on the Desktop frames** (Q11). Starts with no app window under the pointer; setting `frameRectangleOnDesktop` (default true). Small.
   First check on a Mac whether the mouse-down reaches macOS's "Click wallpaper to reveal desktop", which sweeps every window aside (see F14's note and F42 on `feat/review-ux`).
3. **The product review's specs F40 to F58** (on `feat/review-ux`, PR #15, accepted
   by the documenter), once they reach `main`, in this order: F47, F57
   (`"guest"` mode), F48, F43, F42, then F49, F51, F52, F53, F54, F58, F55,
   then F56, F45, F41, F46, F44, F50. F40 ships with the review itself.
## Blocked

| Item | Waiting for |
|---|---|
| F16 Continuous zoom and pan | F02 merged (F03 has merged); the swarm holds both |

## For the maintainer (optional; nothing waits on these)

The items below are
optional; the documenter decides open product questions provisionally (Q2, Q3,
Q7 answered) and nobody waits for them.

- **Observe TrellisWM** (QUESTIONS Q8 d–k): partly answered from the site's
  simulation (2026-10-14). The rest needs TrellisWM running, and it needs
  **Accessibility** (System Settings → Privacy & Security), which only you can
  grant. Then the documenter session can try it with throwaway windows.
- **Answer Q7**: what would make Arbor better than TrellisWM for you.

- Run the manual checks in `docs/TESTING.md` ("Manual checks") with
  `make run` from a terminal that has Accessibility permission, and note the
  results in `collab/evidence/manual-<date>.md`. Drag-to-dock, seam handles,
  tiles, hotkeys and the menu bar have not been checked on real windows yet.
- Answer Q2 in `collab/QUESTIONS.md` after trying ⌃⌥↓.

## Done

| Item | Merged | Evidence |
|---|---|---|
| F01 Dock and zoom | 2026-10-13 (`4a879e4`) | 82 tests; `make e2e` 42/42 on real windows |
| F06 Key bindings in settings.json | 2026-10-13 (`a902904`) | real-window check pending |
| F11 Per-app rules | 2026-10-13 (`a32e5a7`) | real-window check pending |
| F07 Resize docked windows by their own edges | 2026-10-13 | real-window check pending |
| F08 Display reconnects and Spaces | 2026-10-13 | real displays and Spaces pending |
| F03 Trackpad pinch, F05 Drag a rectangle | 2026-10-14 (`5399672`) | manual checks pending |
| S2 The headless stack builds and tests on Linux | 2026-10-14 (#4) | every test on Linux and macOS CI |
| S1 Make scenarios executable | 2026-10-14 (#5) | 5 scenarios, 45 expectations |
| P2 Mac shell workflow, P3 real windows in CI | 2026-10-14 (#2, #3) | `e2e` job passes 42/42 on every PR |
| B2 Huge numbers crash Arbor | 2026-10-14 (#14) | two new real-window steps in CI |
| B3 Event taps off the main thread | 2026-10-14 (#9) |  |
| F11 follow-ups: `ignore` for windows already open, late titles | 2026-10-14 | real-window check pending |
| B1 Hand-edited settings must survive rewrites | 2026-10-14 | three new real-window steps in CI |
| `main` into `swarm/trunk`: the F11 follow-ups and B1, conflicts resolved by their author | 2026-10-14 (#44) | L does these merges from now on when they conflict |
| B4 A damaged state.json must not crash or hang Arbor at launch | 2026-10-14 (#21, on `swarm/trunk`) | Built by the swarm's core review; checked by L with the B2 review's launch fuzzer: 32,144 launches on damaged files, no trap, no hang (713 and 72 in 5,720 without it). L's one finding (a huge `nextRawID` cost every later dock its place at each launch) merged with it |
| F12, first half: settings as commands, one schema, live reload, folded together with B1. Covers **B5** (every number has a range) | 2026-10-14 (#87, on `swarm/trunk`) | an independent review and two fuzzers |
| A window Arbor moved out of view could be taken by an `ignore` rule there and was lost (chaos lab, `parked-unmanaged`; L's own F11 follow-ups) | 2026-10-14 (#163, on `swarm/trunk`) | the lab's script and a 3,000-seed hunt with a control. Also #171: a test from #87 that failed one full run in five |
| Rules, round 1: four more doors to the lost window behind an `ignore` rule and one regression (a review of #163); two identical rules in settings.json each keep their own text | 2026-10-14 (#214, on `swarm/trunk`) | ten mutants each caught, a 3,000-seed chaos hunt equal to its control, both settings fuzzers clean; Linux only when it merged |
