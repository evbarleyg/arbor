# Board

**Ordered by the product owner against issues #3 (the seven rules) and #4 (how we work).** Last ordered: 2026-10-14, 23:00 UTC.

1. **Faults against the seven rules come first** (section 1), whatever else is nearly ready.
2. **Then the polish that is already written**, one train each, in this order: the motion's second step, tab groups, continuous zoom (section 3).
3. **Then the rest**, what serves a working day before what looks like the reference (section 4).
4. **The instruments** (section 2) run beside all of it: without them nothing can be judged.

**Every item says how it is proven** (#4, section 4): what Linux proves; what a hosted Mac runs, unattended, in under ten minutes; what agents judge afterwards from what the run brought back.
An item is done when all three are green on one commit, besides what `CLAUDE.md` asks. Detectors are named as in `docs/VIABLE.md`, section 5. **What only a person at a desk could check is not done: section 5 sends it back.**

Whether a thing ships switched on is decided by `collab/QUESTIONS.md`, Q18. Product questions go to the product owner, who answers within minutes; nobody asks the maintainer anything but identity, money and what cannot be undone (`collab/TOUCHPOINTS.md`).

Letters name the lane that has an item. "Archive" is the branch of patches issue #4 speaks of: a patch comes over only after every added line has been read. **free** means nobody has it: take it, and tell the coordinator.

## 1. Faults against the seven rules

| # | Rule | What a person meets | Who | Linux proves | A hosted Mac runs | Agents judge |
|---|---|---|---|---|---|---|
| 1.1 | 1, 3, 6 | With macOS as it comes, a drag to an edge or to the top is answered by macOS and by Arbor at once: no preview, nothing docks, the window fills the display, windows jolt | A, `fix/stand-aside-where-macos-tiles` | In macOS's own zones Arbor shows no preview and docks nothing (`MacTilingTests`, `MacTilingZoneTests`); the walks with the stand-in's tiling on | `e2e-drag.sh`, every drag at both settings of macOS tiling, the setting seen to act first | `fought`, `pulled`, `jolt` |
| 1.2 | 4 | ⌘Tab or a Dock click to an app, and Arbor does not notice: the window stays out of view or behind another | B | The recorded trace of the missed switch, replayed, fails first | `make e2e`, the two checks that are red for this; the probe of app switches | `behind`, `focus` |
| 1.3 | 2 | Arbor is started a second time and at once frames one window and sends the others out of view, a window that was never docked among them (Q16) | fixer 1 | Three tests that fail first: a start after Quit shows everything; a start after a crash keeps the view and sets no frame; with a newcomer in view it shows everything | `day.sh`, "The next morning", asking that everything is in view | `moved-unasked`, `lost` |
| 1.4 | 1 | The first run arranges nothing, but it also does not stop a person from docking into macOS's own tiling: the switches are listed, and the fix is a walk through System Settings | H; `probe/macos-switches` asks when macOS obeys a switch written from outside | `SetupCheck`'s tests; no frame is set before the findings have been shown; "Turn it off for me" changes exactly the switches named | From an empty home at macOS's defaults: the welcome window names what is on; one click; macOS is **seen** to have stopped tiling | pictures of the window against the rubric; `fought` |
| 1.5 | 1, 3 | A click on the wallpaper, as macOS comes, sweeps every window aside; Arbor hears nothing and believes them in their places | **free** (design first: Arbor stands aside: it notices from the window list, moves nothing while they are swept, and takes no swept frame for the person's) | The stand-in sweeps and brings back; the controller sets no frame meanwhile and remembers none | `day.sh`, "A click lands on the wallpaper" | every window is where it was before; `jolt`, `moved-unasked` |
| 1.6 | 6 | Nothing of Arbor's takes the mouse-up (Q17) | A | One table of Arbor's panels (level, takes the mouse or not, why) and a check that fails for a panel that is not in it | In `e2e-drag.sh`, every drag: button up within 50 ms, the window where the preview was, a click 300 ms later arrives in the window there | `input-held` |
| 1.7 | 3 | Jolts with real apps: whatever the day finds. Each find comes with its step, its story and the shortest script | D finds; a fixer each | The trace of that run, replayed, fails first | `day.sh` and its control without Arbor | `jolt`, `flash`, `slow`, `stuck` |
| 1.8 | 5 | Real apps after pause, Float All and Quit: their own sizes, and after the last two their own places | D finds; F fixes | F48's tests; every walk ends in the three ways back | `day.sh`, "The ways out" | `size-lost`, `left-behind` |
| 1.9 | 7 | A tap of the **key** ⌃⌥Space does less than Show Everything in the menu: it begins a peek, and does not fetch what a hold kept out | C; archive `handover/K2028-the-key` | Tests that press the key, not the command | `check-F51.sh` with the key tapped after a hold | `lost` |
| 1.10 | 7 | Float All refuses ("nothing is docked") while a floating window hangs out of view | F; the 28 cases are in the archive's `tools/decision-replays` | Those cases: 16 pass today | In the day: Float All with nothing docked and one window hanging over the edge | `lost` |
| 1.11 | lost window | A display changes and an app's report reaches Arbor first: a floating window ends mostly off screen | C, F; archive `fix/displays-bash-7`, then "what Arbor gives back is fitted unless its user left it there" and "what is found counts as left" | The sweeps of lid, side and size in the archive's replays, each beside a control that fails | The cell `two` of `docs/VIABLE.md`: a virtual display comes, goes, changes side and size; **the trace records in which order macOS reports** | `lost`; N enters the order into the ledger |
| 1.12 | 4 | Keys go to a window that shows as a tile; the view jumps when the focused window closes | G; archive `fix/controller-round-5` (its tests are red when merged: needs hands) | Its own tests, green on the trunk | ⌘W on the focused docked window in the day | `focus`, `moved-unasked` |
| 1.13 | 4 | After one of Arbor's panels closes (Go to…, the name field, the shortcuts, settings) the app from before does not have the keyboard | G; archive `later/view-bash-1-on-trunk` | The loan of the keyboard as a model with tests | Each panel opened and closed by key over a witness window, which then gets a typed key; also in a full-screen Space | `focus` |
| 1.14 | 4, 7 | At ⌃⌥Space the window being typed in becomes the tile | E; archive `fix/F61-keyboard-first` | Its tests; scenario 61 | On `laptop` with three real apps: frame, type, ⌃⌥Space | `focus`; a picture: the window with the keyboard is a window |
| 1.15 | severity 2 | An app that hangs stops Arbor for as long as it hangs; Quit meanwhile leaves that app's windows in the corner | **free**; archive `perf/ax-lanes-on-trunk` | The stand-in's hanging app: shortcuts answer within 100 ms; Quit ends within 5 s; what could not come back is said | The cast `awkward`: a test window hangs for 20 s during a view move, a Quit and a start | `crash`, `lost`, `slow` |
| 1.16 | 7 | At the end of a hold the person chose, what waited stays out | F | Tests on both ends of a hold: chosen, and by itself | `check-F58.sh` | `lost` |
| 1.17 | all | The rows of severity 1 and 2 that `collab/BACKLOG.md` calls open: that page is a day old | L: replay each row's script on the trunk; close it or make it a row here | the replay | | |

## 2. The instruments

| What | Who | Done when |
|---|---|---|
| The day with real apps, the sampler, the detectors, the controls without Arbor and by sabotage | D, `test/an-ordinary-day` | `docs/VIABLE.md`, section 9, is empty for D |
| The walks hunt the seven rules; walks that write scripts for a real Mac | L | violations per 10,000 walks: 0; half of the gate's acts come from walks |
| The ledger of differences between the stand-ins and real Macs; a rude stand-in | N | open rows that touch a detector: 0 |
| A Mac run of 5 to 8 minutes: one build, cached; the headless suite on a Mac once a night; several scripts a run; one queue | O | measured, and printed in every train's log |
| The polish rubric, the films, the judge | Q | `docs/POLISH.md`; the five moves filmed and scored once |
| Everything Arbor draws, looked at | M, `test/gallery` | share looked at: 100 %, in light, dark and increased contrast |
| The real-window suite; `docs/TESTING.md`'s "Manual checks" turned into scripts or struck out | E | no bullet is left that says "a person" |
| `make e2e` says what the specs say on a small display | B, pull request #5 | `real-windows` is green on the trunk |
| Guardrails that need no person: a privacy lint on files, commits and comments; hosted runners only; defaults that apply on silence | R | each avoidable row of `collab/TOUCHPOINTS.md` has a check that would have caught it |
| `scripts/viable.py`, `make viable`, the ledger | product owner, with O | it prints `NOT VIABLE` for the right reasons today |

## 3. The polish that is written: one train each, in this order

Each train lands whole or not at all, and is judged by the loop of #4, section 2. The look that is judged is the one that ships: **colour and icon, no Screen Recording** (Q15).

### 3.1 The motion's second step (F02) · K

**For a person:** what takes no part in a move stays in sight. Today a pinned call, a dialog, every floating window is covered for half a second at each motion: a flash, against rule 3.
**From the archive:** `fix/F02-bash-1-notes`, then the one commit that puts the stage one level below floating (the archive's list names its branch); `fix/F37-flash-after-the-stage`; `meet/F02-films-with-the-surface`.

| Linux proves | A hosted Mac runs | Agents judge |
|---|---|---|
| The plan has a hole for whatever Arbor does not move; every transition keeps its promises; final frames are the same with and without motion; the archive's walks of the two bug bashes find nothing; what changes in mid-motion without a layout puts only the picture right | `shots-F02.sh` at 0.46 s with eight windows, one pinned, one floating, one dialog: dock, frame, show everything, walk, close; a second command and a click in mid-motion; Reduce Motion; `animationDuration` 0. Filmed, with the stage's own log of frames. Both settings of tiling, light and dark | Measured: length, curve, cadence, hand-over, nothing stray (`docs/VIABLE.md`, section 8). From the film: no flicker, crisp, one thing. `flash`, `jolt`, `slow`; `input-held`: the click in mid-motion lands on the real window under it |

**Ships:** on, as the motion is. If it fails, the first step stays and the train goes back.

### 3.2 Tab groups (F04, F34) · J

**For a person:** windows that belong together share one place under a strip of tabs, and move as one.
**From the archive:** `handover/F04-tab-strips` (two menu tests red at the hand-over), then `handover/F34-tab-groups-and-follow-ups`; the archive's list also has a branch where tabs meet the motion.
**Closed within the train, not after it:** minimizing the showing tab makes the others vanish (severity 1); `tab close` outside a group closes any focused window (severity 1); a torn-off tab that dissolves its group closes the strip that holds the mouse button, so no mouse-up arrives (severity 2, and rule 6).

| Linux proves | A hosted Mac runs | Agents judge |
|---|---|---|
| A group of two reserves the strip, a group of one does not; click, cycle, reorder, tear off, whole groups docked, floated and minimized; the three faults above, each by a test that failed first; the walks know tabs and their timers; no title in a log or a trace | `shots-F04.sh` with real apps on `laptop`: a group made by a real drag onto the middle; each tab clicked; one torn off until the group dissolves; the group dragged whole to an edge; the close button; ⌃⌥⇥. Both settings of tiling, light and dark, filmed | `input-held` at every tear-off; `focus`: the tab clicked has the keyboard; `jolt`, `lost`, `told`. Rubric: the strip is crisp, titles legible on light and dark, the second of the five moves |

**Ships:** `tabsEnabled` false in the train; true by a commit of its own once Q18 holds.

### 3.3 Continuous zoom and pan (F16) · E

**For a person:** the arrangement follows the fingers, and settles on what fits best.
**From the archive:** `fix/F16-round-1` (one conflict where both sides are kept). After 3.1: it drives the same stage.

| Linux proves | A hosted Mac runs | Agents judge |
|---|---|---|
| The virtual camera from pinch and pan; the settle, the root and single windows included; every gesture, cancelled ones too, ends with the layout that `zoom`, `in` or `out` would give; a hold in mid-gesture wins | Pinches and two-finger scrolls posted by `witness.swift`: slow, fast, reversed, cancelled, past everything, with a key or a click during the settle; a scroll without Arbor's keys over a witness window. Filmed, with the stage's log of frames | Cadence while the fingers move; hand-over at the settle; `input-held`: foreign scrolls arrive, none more than 10 ms late; `jolt`, `flash`. Rubric: the fourth of the five moves **reads well as colour and icon**; if it does not, that is the design to mend |

**Ships:** `continuousZoom` false in the train; true by a commit of its own once Q18 holds. No hosted Mac has a trackpad, so nothing about its safety may rest on real fingers (section 5).

## 4. The rest, in this order

Mends before features; what a person meets every day before what they meet once.

| # | What a person gets | Who | Linux proves | A hosted Mac runs | Agents judge |
|---|---|---|---|---|---|
| 4.1 | A download that opens: no toolchain, no terminal (F13) | I | The release tools' tests; the pages pasted whole into a real zsh | On a fresh hosted Mac: fetch the archive as a browser would, open it, record what macOS says, start it, `arborctl version`, uninstall | Pictures of every dialog against `docs/INSTALL.md`: it names each one, in order; `left-behind` |
| 4.2 | A first run that leads to the first dock within a minute (F10, F46) | H | The coach's progress as a model; nothing moves (1.3, 1.4) | From an empty home: the welcome window, the three moves made by real drag and keys, each ticked | Pictures against the rubric; an agent that has never read the guide says what it would do next |
| 4.3 | Tiles say which window they are: `tileStyle` ships `"name"`, the caption is the title (Q15) | **free**, small | Two tiles of one app have different captions; held, the app's name; no title crosses a recorder, a log, `state` | The gallery's picture: two Safari windows, one a tile 63 points wide, one 157 | An agent tells the two apart from the picture; legible in light, dark, increased contrast; `told` |
| 4.4 | An app that is quit and opened again goes back to its place | **free**; archive `handover/K192-quit-and-relaunch` | Its tests; the walks quit and reopen apps | In the day: ⌘Q on a docked app, open it again | `jolt`: the new window moves once; `moved-unasked` |
| 4.5 | The settings window loses nothing that was typed (F12, second round) | K; archive `feat/F12-keeper-round-2` | The window's model | `shots-F12.sh`: every pane, every control by real click and key | Pictures of every pane; `axtool` finds a label on every control |
| 4.6 | The evening's mends: input (`fix/input-round-2`), peek (`fix/F51-round-3`), the core (`handover/core-after-rc1`), undo (`fix/F19-round-3`), automatic docking (`later/F23-round-2-on-trunk`), the layout line (`backup/F54-round-3`), summon (`feat/F53-follow-ups`), events and displays (`later/F24-F25-round-2`) | F, G | Each its own tests, failing first on the trunk | Only `fix/input-round-2`: `input-taps.sh` | `input-held` |
| 4.7 | Floating windows move together with the rest (performance, second round) | E; archive `fix/perf-round-2-restart` | The count of questions asked of the window system | `perf.sh` | `slow`, `busy` |
| 4.8 | A link may not replace a saved view unasked; by hand the reply says what was replaced; saving a view can be undone | **free**, small | Tests | | |
| 4.9 | An unplugged display becomes a space (F52); places survive on other Spaces (F35) | **free**; the archive's newest F52 branch | Its tests; never a tile for the window being typed in | The cell `two` | `lost`, `focus` |
| 4.10 | Arrange styles (F29), presets (F21) | **free**; archive `handover/F29-arrange-styles`, `handover/F21-presets` | Their tests | One script each with real apps | `jolt`; pictures |
| 4.11 | Carry with the keyboard (F59), a command line that is pleasant to script (F50), double-click a title bar (F14) | K; archive `ready/F59-carry`, `pick/F50-on-trunk`, `handoff/F14-alone-on-the-trunk` | Their tests | F14: real double-clicks on real apps' title bars, macOS's own double-click setting at each value | `input-held`: a double-click that is not Arbor's reaches the app |

## 5. Sent back: what only a person at a desk could check

"Manual" in a spec's criteria no longer counts as a way to be done. Each row is either turned into a script and a judgement, or the feature is changed so that its safety does not rest on it; until then it ships off and the guide calls it an experiment.

| Where | What it asked of a person | What becomes of it |
|---|---|---|
| F02 (4), F10 (3), F12 (3), F15 (4), F36 (4), F43 (6), F51 (5) | "looks right", "legible", "reads as one motion" | Pictures and films from hosted Macs, judged against `docs/POLISH.md` in light and dark (M, Q). **Workable: rewrite the criterion** |
| F03 (3), F16 (3), F55 (3) | real fingers on a trackpad, a real wheel | Posted gestures and scrolls only. **Redesign:** every gesture has an end that leaves real windows where a command would; a tap that fails is removed by macOS and Arbor goes on without it. The guide says "tried with posted gestures" |
| F58: `holdStillWhileCameraIsOn`, `holdStillWhileMicrophoneIsOn`, `holdStillFor`; K160 mirroring | a call in four apps, a camera, a headset, another device to look at the share | No hosted Mac has any of it. **Not done.** Holding by hand is the feature. The signs stay off and are experiments, until a script can raise each sign on a hosted Mac (mirroring: perhaps with a virtual display) |
| F08, F52: the lid, a second physical display, a login | a desk | The cell `two` with a virtual display, and the trace of the order of macOS's reports (N). **The lid stays unproven**, and the release notes say so; what protects a person is `lost` on every display change that can be made |
| F46 (4) | a notch and a crowded menu bar | **Workable:** a tool fills the menu bar until Arbor's icon is hidden; opening Arbor again shows the window |
| F63 (10) | taking Accessibility away in System Settings | **Workable:** `tccutil reset` from the script on a hosted Mac; within three seconds the icon and the window; input goes on reaching the witness |
| F41 (5), F44 (5), F47 (2), F42 (3) | Emacs or a remote desktop; a German keyboard; a dialog; flipping switches | **Workable, mostly written:** `check-F41.sh` and `check-F44.sh` with a witness that writes down its keys; `osascript` and the sampler; the switches written by script and **seen** to act |
| F60: the guard of the wallpaper click | a dozen things that a click on the wallpaper closes | **Workable:** each opened and closed by script, with the witness. Off until Q18 holds. 1.5 makes it less needed |
| F13 | a Developer ID, Gatekeeper on a stranger's Mac, Open at Login | Identity and money: the maintainer's, with a default (`collab/TOUCHPOINTS.md`). The rest is 4.1 |
| F12 | VoiceOver through a pane | **Workable in part:** `axtool` walks every pane: each control has a role, a label and a value. How it sounds stays unjudged, and the notes say so |
| `docs/TESTING.md`, "Manual checks" | some sixty bullets | E: each becomes a step of the real-window suite, or is struck out with its reason |

## 6. For the maintainer

Nothing waits for you. What only you can do, and what happens if you say nothing, is at the end of `collab/TOUCHPOINTS.md`.

## Done

Numbers with a # in this table are pull requests of the project's private beginnings; they mean nothing in this repository.

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
