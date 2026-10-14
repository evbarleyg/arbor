# Arbor: agent guide

Arbor is a free, open-source macOS window manager inspired by TrellisWM: real
windows dock into nested splits, and a "camera" zooms between spaces in that
tree. Read this file before changing anything. `AGENTS.md` is a symlink to it.

Arbor is built by two roles that collaborate through this repo: a
**documenter** (decides what to build: reference, specs, board, scenarios) and
**executors** (build it, prove it, merge it). Read `collab/README.md` for the
loop; start every session from `collab/BOARD.md`.

## Commands

```bash
make build      # swift build (debug)
make test       # swift test: core unit tests + controller scenario tests
make check      # build + test + the arbor-sim smoke run + the scenarios + the tools' self-test; must pass before every commit
make sim ARGS='"open Safari" "dock 101 left"'   # drive the real controller headlessly
make run        # run the debug Arbor binary from this terminal; like install and uninstall it declines without one: the Mac's owner decides
make app        # build build/Arbor.app (release; signed as docs/INSTALL.md describes)
make install    # make app, replace ~/Applications/Arbor.app, link arborctl, start it; make uninstall undoes it
make release    # universal build/Arbor.app as zip and disk image, with checksums, notes and the Homebrew cask
make e2e        # real windows, real Accessibility; see docs/TESTING.md
make e2e-drag   # real drags with the real pointer, which it takes over for half a minute
make typecheck-mac  # on Linux: type-check all the macOS-only code, tests included, against stand-ins for Apple's frameworks
make trace NAME=x  # record a trace from the running Arbor into collab/evidence/traces/x.jsonl (docs/TRACES.md)
make replay FILE=x # replay a trace against the real controller and see what happened
make attack     # hostile and broken clients against the control socket, for half a minute; after changing the socket
make scenarios  # the documenter's user journeys (collab/scenarios); VERBOSE=1 for arbor-sim's output
make parity     # score Arbor against TrellisWM; regenerates docs/FEATURES.md
make fuzz       # start Arbor on damaged state.json and settings.json files (a sample; docs/TESTING.md)
make linux      # check, scenarios and parity in the Linux image CI uses (needs Docker)
make clean      # remove .build and build
```

Swift 6 language mode, macOS 14+, no third-party dependencies.

The headless stack (`ArborCore`, the controller and platform protocols, `ArborTesting`, arbor-sim
and both test targets) also builds on Linux, where `build`, `test`, `check`, `sim`, `scenarios` and
`parity` work the same; CI runs them on Linux every time, and on macOS unless a Mac could prove nothing
new. See "Executors without a Mac" in `collab/README.md`.

## Layout

| Path | What it is | Rules |
|---|---|---|
| `Sources/ArborCore` | Pure model: `LayoutTree`, `LayoutEngine`, `Navigation`, `DropResolver`, `Workspace`, `Command`, `Settings`, `AsciiRenderer`, `Plane`, `TransitionPlanner` | No AppKit, no Accessibility, no I/O. Value types. Every change gets unit tests. Builds on Linux, where `import CoreGraphics` gets only the geometry types (`Sources/LinuxShims`). Use `overlaps`, not `intersects`. |
| `Sources/ArborKit/Controller` | `Controller`: turns commands and window events into tree changes and frames; `KeyBindings` | Talks to macOS only through the protocols in `Platform/`. Deterministic. Builds on Linux. |
| `Sources/ArborKit/Platform`, `Support` | The seams: `WindowSystem`, `OverlayPresenter`, `StateStore`, `Scheduler`, `ReleaseFeed`, `LoginItem`; `Log` | Change a protocol only with a matching change to the fakes in `ArborTesting`. Builds on Linux. |
| `Sources/ArborKit/Trace` | Recording traces: a decorator around each seam, `TraceRecorder`, the text form | Forwards everything unchanged; costs one branch while off. Never a window title. Builds on Linux. See `docs/TRACES.md`. |
| `Sources/ArborKit/AX`, `UI`, `Input`, `App` | Real implementations: Accessibility, AppKit panels, Carbon hotkeys, app lifecycle | macOS only: `Package.swift` leaves these folders out elsewhere. Almost none of it can run in tests (`EventTapThreadTests`, on macOS only, is the exception). Keep logic out of them; put it in the controller or core. |
| `Sources/ArborIPC`, `Sources/ArborKit/IPC` | The control socket: paths, framing and client; server and endpoint | POSIX and Dispatch only, so it builds and is tested everywhere. The server runs on the main queue: never block. |
| `Sources/Arbor` | The app's `main.swift`: calls `ArborApp.run()` | macOS only. |
| `Sources/LinuxShims` | A module named CoreGraphics that re-exports Foundation, whose `CGRect` Linux uses | Declared only off macOS. |
| `Sources/ArborTesting` | `FakeWindowSystem`, `FakeOverlays`, `MemoryStateStore`, `ManualScheduler`, `Harness`, `ScenarioExpectation` (the `expect` lines), `TraceReplayer` | Used by tests and arbor-sim. |
| `Sources/arborctl` | CLI client for the control socket | macOS only. |
| `Sources/arbor-sim` | Scriptable simulator printing ASCII layouts | Builds on Linux. |
| `Sources/arbor-fakemac` | The stand-ins behind `scripts/mac-shell/rehearse.sh`: Mac shell scripts run on Linux against the real controller | Built on Linux only. Wraps the fakes and copies `ArborApp`'s wiring: a new member of `WindowSystem` or `OverlayPresenter` needs a line in `Arbor.swift`. |
| `Sources/ArborTestWindows`, `Sources/arbor-e2e` | End-to-end runner and the windows it arranges | macOS only. |
| `scripts/` | What the make targets and CI run (`bundle.sh`, `e2e.sh`, `linux.sh`, `scenarios.sh`, `sim-smoke.sh`, `candidate-check.sh`, `parity.py`, `ci-step.py`, `ci-changes.py`, `ci-toolchain.sh`, `ci-build.sh`, `ci-build-key.sh` and `ci-mtimes.py` (what `.github/actions/mac-setup` gives a hosted Mac to start with), `ci-mac-shell.sh`, `mac-queue.py`, and their self-tests `test-tooling.py`, `test-ci-changes.py`, `test-ci-linux.py` and `test-mac-queue.py`), `mutate.py` (mutation testing), `mac-shell/` (the real app on a remote Mac) | Each file's header says how to use it; `docs/TESTING.md` covers `mutate.py` and `mac-shell/`. |
| `docs/` | `ARCHITECTURE.md`, `TESTING.md`, `ROADMAP.md`, `features/F*.md` specs, generated `FEATURES.md` | Specs belong to the documenter |
| `collab/` | Board, questions, ideas, reports, scenarios, parity data, evidence | See `collab/README.md` |

## How to verify your work without permissions

You almost certainly cannot grant Accessibility permission, so you cannot move
real windows. That is fine: everything above the `WindowSystem` protocol runs
against fakes.

1. **Core unit tests** (`Tests/ArborCoreTests`) for anything in `ArborCore`.
2. **Scenario tests** (`Tests/ArborKitTests`) using `Harness`: open fake windows,
   run commands with `h.run("dock 101 left")`, simulate the user with
   `h.system.drag/userMove/userFocus/setMinimized`, then assert on
   `h.frame(_:)`, `h.workspace`, `h.layout`, `h.overlays`. See
   `ControllerTests.swift` for the pattern. End a scenario with `expectWindowsMatchLayout(h)` (`ScenarioHelpers.swift`): it lays
   the arrangement out afresh, so it also catches a command that forgot to lay out.
3. **arbor-sim** to see what happens: `make sim ARGS='"open A" "open B" "dock 101 left" "state"'`.
4. **Traces** of real windows and real apps in `collab/evidence/traces/`: `make replay FILE=…` shows what macOS reported and
   what the apps answered, line by line, and replays it against your controller (`docs/TRACES.md`).
5. `make e2e` only if `arborctl status` reports Accessibility. Without a Mac, CI's
   `macos` job runs it, and a Mac shell script drives the real app with real drags,
   clicks and shortcuts and brings back screenshots (`docs/TESTING.md`, section 5).
   Say in your report what is still unchecked on real windows.

## Conventions

- Everything in ArborKit is `@MainActor`. AX, Carbon and AppKit callbacks arrive
  on the main run loop; hop in with `MainActor.assumeIsolated`. The one exception:
  event tap callbacks run on `EventTapThread` (`Input/EventTap.swift`), because
  macOS holds every tapped event system-wide until the callback returns. Keep
  them cheap, keep their state in a lock-protected box, and hop to the main
  actor with `DispatchQueue.main.async` only to run a command or draw.
- Coordinates are global, top-left origin, y down (the AX/CGWindowList space).
  Convert to AppKit only in `ScreenGeometry`.
- New user actions are `Command` cases with a text form (`parse`/`text`/`helpText`),
  so they work from hotkeys, the menu, `arborctl`, URLs and tests alike. URLs refuse a
  command until it is listed in `Command.isAllowedFromURL` (`CommandURL.swift`): list camera and
  arrangement commands there, never ones that change settings, delete things or quit.
- Put a feature's controller code in its own `Controller+<Feature>.swift` and
  add one line to the `perform` switch.
- Settings: add keys at the end of `Settings` (a property with its default, a
  `CodingKeys` case, one `try read(.key, into: &key)` line in `init(from:)`), and one entry in
  `SettingsSchema`, at the end of its section's list: it gives the key its range, `set` and `get`, and its row in
  docs/SETTINGS.md, which a test rewrites (it fails once; commit the file). Old settings files must keep loading.
  A command that changes settings asks `refusalToChangeSettings()` first and returns
  `reply("…", unsaved: change(settings: updated))` (`Controller+Settings.swift`).
- Never log window titles or the names people give to spaces. Log window ids, bundle ids and node ids.
- Comments explain why, not what. Match the surrounding style (2-space indent, ~110 columns).
- Commits: conventional (`feat:`, `fix:`, `test:`, `docs:`, `refactor:`, `chore:`), present tense, scoped.

## Working alongside other agents

Several executors may work on Arbor at once, one board item each.

1. **Pick work** from `collab/BOARD.md`: the top **Ready** item you can do whose
   dependencies are merged.
2. **Work in your own worktree and branch**, never directly on `main`:
   `git worktree add ../arbor-worktrees/F07 -b feat/F07-edge-resize main`
3. **Claim it**: move the item to **In progress** on the board and set the
   spec's `Status:` to `in progress (<branch>)`. Edit only your own spec, and
   only its status and Shipped note; ask in `collab/QUESTIONS.md` if the spec is wrong.
4. **Shared hot spots** that several features touch: `Command.swift`,
   `Controller+Commands.swift` (`perform`), `Settings.swift`, `KeyBindings.swift`,
   `StatusMenu.swift`, `OverlayPresenter.swift`, `WindowSystem.swift`. Keep edits
   there small and append-only (new cases and keys at the end) so merges stay mechanical.
5. **Definition of done**:
   - the spec's acceptance criteria are met, each covered by a test where testable;
   - `make check`, `make scenarios` and `make parity` pass, with your tests and
     e2e steps added to the item's entries in `collab/parity.json`;
   - the spec's status is `done` with a short "Shipped / Not shipped" note;
   - a report in `collab/reports/` (template in `collab/templates/report.md`).
6. **Merge**: rebase onto `main`, re-run the checks, merge into `main`, push,
   and move the item to **Done** on the board. Agents launched for a single
   feature by another session follow their launch instructions instead
   (usually: hand back without merging).

Do not add dependencies, do not use private APIs beyond `_AXUIElementGetWindow`
without justifying it in the spec, and do not weaken an existing test to make
it pass.
