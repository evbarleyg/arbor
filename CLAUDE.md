# Arbor: agent guide

Arbor is a free, open-source macOS window manager inspired by TrellisWM: real
windows dock into nested splits, and a "camera" zooms between spaces in that
tree. Read this file before changing anything. `AGENTS.md` is a symlink to it.

Arbor is built by agents in a few roles that collaborate through this repo: a
**documenter** (what Arbor should do: specs, scenarios), a **product owner** (decides, and orders the board),
**executors** (build it, prove it, hand it in) and a **coordinator** (has it reviewed and lands it). Issues #3 (what
Arbor is for) and #4 (how we work) are the maintainer's word on both. Read `collab/README.md` for the
loop; start every session from `collab/BOARD.md`.

## This repository is public

Whatever is pushed or posted here is public at once and for good. `docs/PUBLIC.md` says what stays out: names ("the
maintainer", "a tester"), anything about one person's Mac, apps, days or work, ids of and links to working sessions, e-mail
addresses, paths on a particular machine, internal hosts, cost, names of models, roles and numbers of the private phase.

- First thing in a clone: `make hooks`. Git then runs `scripts/public-check.py` before every push, and `scripts/public-clone.py`
  looks through the clone for history from somewhere else: a clone you were handed can hold branches that are not this
  repository's, under names that look right. Look at what it found and have it removed (`--remove`) before anything else. In a Claude Code session
  `.claude/hooks/session-start.sh` has run it for you, and you have read what it printed.
- Before you post a pull request's body, an issue or a comment: `scripts/public-check.py --text <file>`. The workflow
  `Public text` reads every post afterwards, replaces a link to a working session that a platform may have added, and
  names the rest in a comment on the thread: reword in place, and the comment goes.
- Commit under a no-reply address. Branch only from a branch of `origin`.

## Commands

```bash
make build      # swift build (debug)
make test       # swift test: core unit tests + controller scenario tests
make test-making-way  # the same tests with floatingWindowsMakeWay on wherever a test does not choose its settings (F64)
make check      # build + test + the arbor-sim smoke run + the scenarios + the tools' self-test; must pass before every commit
make gate       # on Linux: check, scenarios, parity, typecheck-mac and lint, each once and on every core: 4 minutes instead of 9
make sim ARGS='"open Safari" "dock 101 left"'   # drive the real controller headlessly
make run        # run the debug Arbor binary from this terminal; like install and uninstall it declines without one: the Mac's owner decides
make app        # build build/Arbor.app (release; signed as docs/INSTALL.md describes)
make install    # make app, replace ~/Applications/Arbor.app, link arborctl, start it; make uninstall undoes it
make release    # universal build/Arbor.app as zip and disk image, with checksums, notes and the Homebrew cask
make e2e        # real windows, real Accessibility; see docs/TESTING.md
make e2e-drag   # real drags with the real pointer, which it takes over for one to three minutes
make suite      # every shipped feature on real windows with real drags, clicks, keys and menus, in sections (SECTIONS="30 60"); docs/TESTING.md, section 10
make day        # from anywhere: an ordinary day with real apps on a hosted Mac, every frame sampled, a table of what broke which rule (docs/TESTING.md)
make newcomer   # from anywhere: a hosted Mac for somebody who knows nothing, seen in pictures, one act a round through Git; scored against macOS alone (scripts/newcomer/README.md)
make typecheck-mac  # on Linux: type-check all the macOS-only code, tests included, against stand-ins for Apple's frameworks
make mac-on-linux   # on Linux: RUN the real Accessibility layer (Sources/ArborKit/AX) on a model of a rude Mac; after every change there (scripts/mac-on-linux/README.md)
make trace NAME=x  # record a trace from the running Arbor into collab/evidence/traces/x.jsonl (docs/TRACES.md)
make replay FILE=x # replay a trace against the real controller and see what happened
make film SCRIPT=x OUT=y # play a film script against the real controller and write every frame down as JSON (docs/FILM.md)
make reality    # on Linux: the same script rehearsed and on a hosted Mac, compared step by step; one number; `make reality-trunk` after a batch has landed (docs/TESTING.md, section 11)
make attack     # hostile and broken clients against the control socket, for half a minute; after changing the socket
make scenarios  # the documenter's user journeys (collab/scenarios); VERBOSE=1 for arbor-sim's output
make parity     # score Arbor against TrellisWM; regenerates docs/FEATURES.md
make fuzz       # start Arbor on damaged state.json and settings.json files (a sample; docs/TESTING.md)
make linux      # check, scenarios and parity in the Linux image CI uses (needs Docker)
make clean      # remove .build and build
make hooks      # first thing in a clone: git then runs the next line's check before every push; looks for foreign history in the clone
make public-check  # nothing private in what this branch adds, and its history begins where the public one does (docs/PUBLIC.md)
```

Swift 6 language mode, macOS 14+, no third-party dependencies.

The headless stack (`ArborCore`, the controller and platform protocols, `ArborTesting`, arbor-sim
and both test targets) also builds on Linux, where `build`, `test`, `check`, `sim`, `scenarios` and
`parity` work the same; CI runs them on Linux every time (of a draft only `make lint`), and on macOS unless a Mac could
prove nothing new. See "Executors without a Mac" in `collab/README.md`.

## Layout

| Path | What it is | Rules |
|---|---|---|
| `Sources/ArborCore` | Pure model: `LayoutTree`, `LayoutEngine`, `Navigation`, `DropResolver`, `Workspace`, `Command`, `Settings`, `AsciiRenderer`, `Plane`, `TransitionPlanner` | No AppKit, no Accessibility, no I/O. Value types. Every change gets unit tests. Builds on Linux, where `import CoreGraphics` gets only the geometry types (`Sources/LinuxShims`). Use `overlaps`, not `intersects`. |
| `Sources/ArborKit/Controller` | `Controller`: turns commands and window events into tree changes and frames; `KeyBindings` | Talks to macOS only through the protocols in `Platform/`. Deterministic. Builds on Linux. |
| `Sources/ArborKit/Platform`, `Support` | The seams: `WindowSystem`, `OverlayPresenter`, `StateStore`, `Scheduler`, `ReleaseFeed`, `LoginItem`; `Log` | Change a protocol only with a matching change to the fakes in `ArborTesting`. Builds on Linux. |
| `Sources/ArborKit/Trace` | Recording traces: a decorator around each seam, `TraceRecorder`, the text form | Forwards everything unchanged; costs one branch while off. Never a window title. Builds on Linux. See `docs/TRACES.md`. |
| `Sources/ArborKit/AX`, `UI`, `Input`, `App` | Real implementations: Accessibility, AppKit panels, Carbon hotkeys, app lifecycle | macOS only: `Package.swift` leaves these folders out elsewhere. Almost none of it can run in tests (`EventTapThreadTests`, on macOS only, is one exception; `AX` is the other: `make mac-on-linux` runs it on a model of a Mac, and a cure there deletes its lines in `scripts/mac-on-linux/known-failures.txt`). Keep logic out of them; put it in the controller or core. |
| `Sources/ArborIPC`, `Sources/ArborKit/IPC` | The control socket: paths, framing and client; server and endpoint | POSIX and Dispatch only, so it builds and is tested everywhere. The server runs on the main queue: never block. |
| `Sources/Arbor` | The app's `main.swift`: calls `ArborApp.run()` | macOS only. |
| `Sources/LinuxShims` | A module named CoreGraphics that re-exports Foundation, whose `CGRect` Linux uses | Declared only off macOS. |
| `Sources/ArborTesting` | `FakeWindowSystem`, `FakeOverlays`, `MemoryStateStore`, `ManualScheduler`, `Harness`, `ScenarioExpectation` (the `expect` lines), `TraceReplayer`, the chaos lab (`Chaos*`), walks for a hosted Mac (`Walk*`, `RealApps`), `Film/` (what a display shows, frame by frame: docs/FILM.md) | Used by tests and arbor-sim. A fade or a duration changed in `ArborKit/UI` changes in `Film/` too; `StageTimingTests` says so on a Mac. |
| `Sources/arborctl` | CLI client for the control socket | macOS only. |
| `Sources/arbor-sim` | Scriptable simulator printing ASCII layouts | Builds on Linux. |
| `Sources/arbor-fakemac` | The stand-ins behind `scripts/mac-shell/rehearse.sh`: Mac shell scripts run on Linux against the real controller | Built on Linux only. Wraps the fakes and copies `ArborApp`'s wiring: a new member of `WindowSystem` or `OverlayPresenter` needs a line in `Arbor.swift`. |
| `Sources/ArborTestWindows`, `Sources/arbor-e2e` | End-to-end runner and the windows it arranges | macOS only. |
| `scripts/` | What the make targets and CI run (`bundle.sh`, `e2e.sh`, `linux.sh`, `scenarios.sh`, `sim-smoke.sh`, `candidate-check.sh`, `parity.py`, `ci-step.py`, `ci-changes.py`, `ci-toolchain.sh`, `ci-build.sh`, `ci-build-key.sh` and `ci-mtimes.py` (what `.github/actions/mac-setup` gives a hosted Mac to start with), `ci-mac-shell.sh`, `ci-tests.py` (which tests CI's Mac runs, and the proof that none ran nowhere), `mac-queue.py`, `reality.sh`, `reality-diff.py`, and their self-tests `test-tooling.py`, `test-ci-changes.py`, `test-ci-tests.py` and `test-mac-queue.py`), `mutate.py` (mutation testing), `mac-shell/` (the real app on a remote Mac) | Each file's header says how to use it; `docs/TESTING.md` covers `mutate.py` and `mac-shell/`. |
| `scripts/newcomer/` | The newcomer's eval: `rig.py` (the loop on the hosted Mac), `courier.sh` (the one process with a token), `kit/` (all the newcomer gets), `words.py` (its language), `tasks.py` (the tasks and their judges), `score.py`, `rehearse.py` with `fakemac.py` | `README.md` there. Python 3.9, which a hosted Mac has; `kit/mac` is POSIX sh. If you have read this file you are no newcomer: never play one. |
| `scripts/public-*`, `scripts/git-hooks/` | What keeps private things out of a public repository: `public-check.py` reads what is pushed, with its exceptions in `public-check.allow`; `public-text.py` reads what is posted; `public-clone.py` looks through the clone; `git-hooks/` is what `make hooks` installs; `test-public-*.py` hold them to tables of situations | `docs/PUBLIC.md`. Linux and Python only. The rules name kinds of things, never the things. |
| `docs/` | `ARCHITECTURE.md`, `TESTING.md`, `ROADMAP.md`, `features/F*.md` specs, generated `FEATURES.md` | Specs belong to the documenter |
| `docs/CENSUS.md` | What each test touches, which premises of the fakes a recording bears out, which real code nothing runs, which features no Mac has tried | Generated: `scripts/census.py --write`, words in `scripts/census-template.md`. By hand, not part of `make check` |
| `collab/` | Board, questions, ideas, scenarios, parity data, evidence | See `collab/README.md` |
| `collab/parity.json`, `collab/reality.json`, `scripts/mergeable.py`, `.gitattributes` | The files nearly every pull request adds to, and what makes that merge: a key and a name to a line, sorted (the ledger: its cases by id), and after `make hooks` a merge by meaning (items by id, lists as sets) in every rebase | Edited one by hand: `scripts/mergeable.py --tidy`. `make lint` holds them to the shape. The generated `docs/FEATURES.md` and `docs/REALITY.md` stay as they are in a rebase: make them again. |
| `collab/reality.json`, generated `docs/REALITY.md` | Every known case where real macOS differed from the stand-ins or from what a test expected, and what guards it | A real Mac surprised you: add an entry and run `scripts/reality-ledger.py`. `make lint` fails on a name that is gone or a stale page: you renamed a test or reworded a step that a case names, and the line under each ✘ says what to put where. |

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
   Say in the pull request what is still unchecked on real windows. Real Macs are GitHub's hosted runners and no others:
   nothing is run on, or asked of, a person's Mac.

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
  `SettingsSchema`, at the end of its section's list: it gives the key its range, `set` and `get`, its row in the settings
  window and in docs/SETTINGS.md, which a test rewrites (it fails once; commit the file). The file's header says how to
  choose words and level (`hidden: true` when in doubt); its place among the others is `SettingsSchema.order`. Old settings
  files must keep loading.
  A command that changes settings asks `refusalToChangeSettings()` first and returns
  `reply("…", unsaved: change(settings: updated))` (`Controller+Settings.swift`).
- What the app shows (menus, panels, the settings window, the line on screen, replies, `help`, `doctor`) is spelled as macOS spells: color,
  gray, neighbor, minimized. `make lint` reads the string literals for it. Keys of settings.json, comments and the docs stay as they are.
- Never log window titles or the names people give to spaces. Log window ids, bundle ids and node ids.
- Comments explain why, not what. Match the surrounding style (2-space indent, ~110 columns).
- Commits: conventional (`feat:`, `fix:`, `test:`, `docs:`, `refactor:`, `chore:`), present tense, scoped.

## Working alongside other agents

Several executors may work on Arbor at once, one board item each.

1. **Pick work** from `collab/BOARD.md`: the topmost item that is free, that you can do, and whose
   dependencies have landed.
2. **Work on a branch of your own that starts from `origin/swarm/trunk`**, in a worktree of your own if you have several:
   `git fetch origin && git worktree add ../arbor-worktrees/F07 -b feat/F07-edge-resize origin/swarm/trunk`.
   Never commit on, or push to, `main` or `swarm/trunk`.
3. **Claim it**: put your branch's name against the item on the board and set the
   spec's `Status:` to `in progress (<branch>)`, in your pull request's first commit. Edit only your own spec, and
   only its status and Shipped note; ask in `collab/QUESTIONS.md` if the spec is wrong.
4. **Shared hot spots** that several features touch: `Command.swift`,
   `Controller+Commands.swift` (`perform`), `Settings.swift`, `KeyBindings.swift`,
   `StatusMenu.swift`, `OverlayPresenter.swift`, `WindowSystem.swift`. Keep edits
   there small and append-only (new cases and keys at the end) so merges stay mechanical.
5. **Definition of done**:
   - the spec's acceptance criteria are met, each covered by a test where testable;
   - a fault was reproduced first, by a test that failed before the fix (headless if at all possible);
   - `make check`, `make scenarios`, `make parity` and, on Linux, `make typecheck-mac` pass, with your tests and
     e2e steps added to the item's entries in `collab/parity.json`;
   - what the board item says a hosted Mac must run has run there, and what agents must judge has been judged (#4). What
     only a person at a desk could check is not done: redesign it;
   - the spec's status is `done` with a short "Shipped / Not shipped" note.
6. **Hand it in**: a pull request against `swarm/trunk`, small, one thing. Its description is the report
   (`collab/templates/report.md`): first what it changes for a person, then how it was tried and what is still unchecked.
   It is ready when its own CI is green. The coordinator has it read by an independent reviewer and lands it: rebased, then
   `swarm/trunk` is moved forward to that very commit. Nobody uses the merge button, which makes a commit of its own under
   whatever address the account has on file (`docs/REPOSITORY.md`). When told that your branch conflicts, rebase it on
   `origin/swarm/trunk` at once. `swarm/trunk` goes to `main` as a train, with all the Mac jobs.

Do not add dependencies, do not use private APIs beyond `_AXUIElementGetWindow`
without justifying it in the spec, and do not weaken an existing test to make
it pass.
