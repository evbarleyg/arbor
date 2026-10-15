# How the documenter and executors work together

Arbor is built by two kinds of agents that talk only through this repository.

## Starting a session

Paste one of these into a new Claude Code session in a checkout of this repository:

**Executor**

> You are an executor for Arbor, the macOS window manager in this repository.
> Read CLAUDE.md and collab/README.md, then run
> the executor loop: take the top Ready item on collab/BOARD.md that you can
> do (merging branches under Review counts), build it in your own worktree,
> prove it with make check, make scenarios and make parity, write a report,
> merge, push, and update the board. Repeat until the board has nothing you
> can do. Ask in collab/QUESTIONS.md instead of guessing at product decisions.

**Documenter** (if this session is gone)

> You are the feature documenter for Arbor in this repository. Read CLAUDE.md
> and collab/README.md, then run the documenter loop: read new reports,
> questions and board changes, answer, update specs, parity
> data, scenarios and the changelog, re-order the board, run make parity and
> commit. You do not write product code or merge branches.

| Role | Who | Owns | Never |
|---|---|---|---|
| **Documenter** | One session | What Arbor should do: `docs/features/` specs, `collab/parity.json` entries, `collab/BOARD.md` priorities, `collab/scenarios/`, answers in `collab/QUESTIONS.md`, `CHANGELOG.md` | Writes product code or merges branches |
| **Product owner** | One session | Product decisions, against issues #3 and #4: answers in `collab/QUESTIONS.md`, the order of `collab/BOARD.md`, `docs/VIABLE.md`, `collab/TOUCHPOINTS.md`, GO or NO GO on finished work | Asks the maintainer anything but identity, money and what cannot be undone |
| **Executor** | Any coding agent pointed at this repo; several can run at once | Making it so: code, tests, merging branches into `main`, `collab/reports/`, evidence, statuses of the items it works on | Changes priorities or rewrites specs without asking |

The documenter decides **what** and **in what order**; executors decide
**how** and prove it. When an executor disagrees with a spec, it asks
(`QUESTIONS.md`) or proposes (`IDEAS.md`) instead of silently doing something else.

## The files

| File | Purpose | Written by |
|---|---|---|
| `docs/features/F*.md` | One spec per feature, with acceptance criteria | Documenter (executors edit only `Status:` and the Shipped note) |
| `collab/parity.json` | Every reference item and Arbor-only feature (A01…), its status, and the tests and real-window steps that prove it | Documenter adds entries; executors update `status`, `branch`, `tests`, `e2e` for items they ship |
| `docs/FEATURES.md` | Generated from `parity.json` by `make parity`; never edit by hand | `make parity` |
| `collab/BOARD.md` | The ordered work queue; each item says what Linux proves, what a hosted Mac runs and what agents judge | The product owner orders; executors claim items and report them done |
| `docs/VIABLE.md` | The gate: when Arbor is good enough to hand to somebody who did not build it, in numbers a program checks | Product owner |
| `collab/TOUCHPOINTS.md` | Each time the maintainer was needed, and what would have avoided it | Product owner |
| `collab/QUESTIONS.md` | Questions and answers, numbered Q1, Q2… | Anyone asks; the product owner answers product questions, the documenter questions about the reference |
| `collab/IDEAS.md` | Ways to make Arbor better than TrellisWM | Anyone proposes; the documenter promotes ideas into specs |
| `collab/reports/` | One report per finished work item (template in `templates/report.md`) | Executors (the documenter files reports handed to it by agents it ran) |
| `collab/scenarios/*.sim` | User journeys with expectations, run in arbor-sim | Documenter |
| `collab/evidence/` | Output of real-window runs (`make e2e` writes `e2e-latest.txt`; the real-window suite writes `suite-<section>-latest.txt`) and manual checks | Whoever ran them |
| `collab/reality.json` | Every known case where real macOS differed from the stand-ins or from what a test expected: what was expected, what happened, which stand-in plays it, what guards it | Whoever a real Mac surprised, in the pull request that cures it or at once with `"copes": "open"` |
| `docs/REALITY.md` | Generated from `reality.json` by `scripts/reality-ledger.py`, which looks every name up; never edit by hand | `scripts/reality-ledger.py` (`make lint` checks it) |

## The loop

### Executor, each work item

1. `git pull`. Read `collab/BOARD.md`, any new `QUESTIONS.md` answers, and the
   top **Ready** item's spec and reference items.
2. **Try** the current behaviour before changing it:
   - `make parity` for the baseline score and anything already broken;
   - `make scenarios` to run the documenter's user journeys;
   - `make sim ARGS='…'` to explore;
   - `make e2e` if your terminal has Accessibility permission (most agents do not; say so in the report).
3. Move the item to **In progress** on the board with your branch name, in
   the same commit as your first change.
4. **Build** it on a branch in your own worktree (see `CLAUDE.md`), with tests
   for every testable acceptance criterion.
5. **Prove** it: `make check` and `make parity` pass. Add your tests and e2e
   steps to the item's entries in `parity.json` and set their status.
6. **Report**: write `collab/reports/<date>-<item>.md` from the template:
   before and after parity, evidence, deviations from the spec, and what
   still needs checking on a real Mac.
7. **Merge** your branch into `main` (rebase, `make check`, fast-forward or a
   merge commit), push, and move the item to **Done** on the board.

### Documenter, each session

1. `git pull`; read new reports, questions and board changes since the last
   session (`git log --since=… -- collab docs`).
2. Answer questions. Fix specs that executors found ambiguous or wrong.
3. Turn report findings, scenario failures and `IDEAS.md` entries into
   specs and board items; re-order the board.
4. Add `parity.json` entries for anything new; write scenarios for new behaviour.
5. Update `CHANGELOG.md` for everything merged; run `make parity` and commit
   the regenerated `docs/FEATURES.md`.

## How "improve" is measured

`make parity` runs the test suite, reads the real-window evidence in
`collab/evidence/*-latest.txt`, and for every item in `parity.json` reports:

- **verified**: shipped, its tests pass, and its real-window steps passed (or
  it is a policy, `"kind": "policy"`, with nothing to test);
- **tested**: shipped and its tests pass;
- **unproven**: marked shipped but no listed test or step has run;
- **broken**, whatever the item's status: a listed test failed or is missing, a
  listed real-window step failed, or no runner has a step of that name (exit code 1);
- otherwise its plain status: partial, review, in progress, planned, missing
  (no spec yet), not planned.

A real-window step is a `▸` heading printed by `arbor-e2e` (`make e2e`,
`e2e-latest.txt`) or by a `claim "…"` line of a Mac shell script
(`scripts/mac-shell/proof.sh`, `gestures-latest.txt`); list it by its title under the item's
`"e2e"`. It has passed when the evidence shows at least one ✔ and no ✘ under it.
A step the runner has but the evidence does not yet is not counted and breaks nothing.

`make parity` also fails when the test run as a whole failed or did not finish
(a crash ends its record early; what came before proves nothing), and exits with
code 2 when `parity.json` itself is wrong: an unknown status or a spec that does not
exist.

What the tests did is read from the record Swift Testing writes for tools (`make test` leaves it in
`.build/test-report.jsonl`), never from what `swift test` prints, which loses some hundred lines now and
then from a run that went well. So "test … not found" means what it says: no such test ran. Do not run it
again; look for the test. `make check parity` runs the tests once.

**Keeping it honest.** `shipped` means a TrellisWM user who tried the thing the
reference describes, the way it describes it, would agree that Arbor does it. If it
works only through a command while the reference describes a gesture, or
fails on real windows, it is `partial`, and the `arbor` text says what is missing.
List tests that would fail if the claim stopped being true, not tests that pass near it.

A real-window step is a `▸` heading printed by `arbor-e2e` (`make e2e`,
`e2e-latest.txt`) or by a `claim "…"` line of the real-window suite
(`scripts/mac-shell/suite/`, `suite-<section>-latest.txt`). It has passed when the
evidence shows at least one ✔ and no ✘ under it. `scripts/mac-shell/suite-parity.py` lists the
suite's claims under the items they prove.

It prints the parity score (shipped TrellisWM items out of all TrellisWM
items that are not "not planned") and the next items to take. A change
improves Arbor when it raises the score or turns unproven or tested items
into verified ones, without making anything broken. CI runs the same check.

## Scenarios

A scenario is an arbor-sim script that tells a short user story with
`expect` lines, e.g.:

```
# A developer docks an editor and a terminal, then focuses the editor.
open Xcode
open Terminal
dock 101 left
dock 102 right
expect docked 101
expect left-of 101 102
zoom 101
expect fills 101
expect hidden 102
```

`expect` forms: `docked <id>`, `floating <id>`, `visible <id>`, `hidden <id>`
(an open window that is not visible: parked, inside a tile, an inactive tab,
minimized, hidden with its app, or on another Space), `tile <id>`, `fills <id>` (fills the screen minus
gaps), `left-of <a> <b>`, `above <a> <b>`, `camera root|desktop|<id>`
(the camera is on that window's leaf), `count docked <n>`, `ok` / `fail`
(the previous command's result), `ring <id>` / `ring none` (the focus ring is
around that window, where the window is; there is none), `outline <id>|desktop|none` (what a peek outlines), `shortcut <keys> on|off`
(whether Arbor holds that shortcut right now, e.g. `shortcut ctrl+opt+space off`), `shortcut <keys> shows <label>` and
`shortcut <keys> key <code>` (how menus show it, and which key it is, on the layout chosen with `keyboard german`), `pinned <id>`,
`in-front <id>` (no window covers it), `size <id> <w>x<h>`, `summoned <id>`, `space <name>` (some display's view is on the space of that name), `no-space <name>`,
`field open` / `field closed` (the field of `ask-name`; `field-type [text]` types into it and presses ↩, `field-cancel` presses ⎋), `minimap <id>|desktop|everything|none` (what the minimap marks as filling the view; there is none;
`map <id>|desktop|beside` clicks in it),
`held view|still|no` (F58), `focused <id>` (that window has the keyboard),
`still` / `still <id>` (during the line before, Arbor moved no window, or not that one), `moved-once` (it moved something, and nothing twice),
`at <id> <x> <y>` (the window's top-left corner), `replied <words>` (what the line before printed contains those words, ignoring case),
`preview none|showing` (the drop preview), `jolt <id>` (see below),
`said <words>` / `silent` (the heads-up line on screen now contains those words, ignoring
case; there is none. A line stays until `flush` or `wait`). `press <command>` runs a command as its shortcut would, which is what
makes Arbor answer on screen; arbor-sim prints each line as `on screen: …`. `relaunch` quits Arbor and starts it again. Failed expectations print
`EXPECTATION FAILED` and make arbor-sim exit with code 1.

arbor-sim checks each `expect` line as it runs (`ScenarioExpectation` in
ArborTesting). A line that does not hold prints `EXPECTATION FAILED: <why>`,
and arbor-sim exits with code 1 at the end, so `make scenarios` (part of
`make check` and of CI) fails when a user journey breaks. `expect ok` and
`expect fail` refer to the last command, not to earlier expectations.

**A window moves once.** After every line of every scenario arbor-sim looks at what Arbor asked of the windows. A window that did
as it was asked and was then asked for another frame before the line was over has been moved twice where once would have done
(`ArborTesting/Jolts.swift`): arbor-sim prints `MOVED TWICE` and the scenario fails. Asking again because an app answered with another size
than it was asked for does not count. `expect jolt <id>` on the next line answers for a fault that is known, beside a remark that names its row on
the board; it fails once the fault is mended, so it cannot outlive it.

A command that fails (a misspelt verb, a window that is not there) fails the
scenario too, unless the very next line is `expect fail`; so does a scenario
without a single `expect`. Otherwise a journey whose steps had stopped doing
anything would go on passing.

## Executors without a Mac (cloud sessions)

The app needs macOS to build (AppKit, Accessibility, Carbon), but everything
above the platform protocols does not: `ArborCore`, the controller,
`ArborTesting`, arbor-sim and the test targets build and run on Linux, and so does
the control socket (`ArborIPC`, `ArborKit/IPC`, `arborctl`), which needs only POSIX and Dispatch. There
`Package.swift` leaves out `ArborKit`'s `AX`, `App`, `Input` and `UI`
folders and the `Arbor`, `ArborTestWindows`
and `arbor-e2e` executables, and adds a module named CoreGraphics that re-exports
Foundation (`Sources/LinuxShims`), so `import CoreGraphics` works on both platforms.

**On Linux**, `make check`, `make scenarios`, `make parity` and `make sim` work as
on a Mac, so run them before pushing. **`make gate` runs all of it, with `make typecheck-mac` and `make lint`, in a third of
the time**: the tests once instead of twice, and on every core instead of one (`scripts/gate.sh`, `scripts/fast-tests.py`;
`make test-fast` for the tests alone). A machine with Docker but no Swift (or a
Mac, to check that the Linux build still works) runs the first three in the image
CI uses with `make linux`, or any command with `./scripts/linux.sh <command>`.

Three rules keep the Linux build working and the platforms telling the same story:

- Outside the four macOS-only folders, and in the tests, only the geometry
  types of CoreGraphics exist (`CGRect`, `CGPoint`, `CGSize`, `CGFloat`). Keep
  writing `import CoreGraphics` for them: on macOS, Foundation alone brings the
  types without their members. The reverse trap: on Linux that import passes on all
  of Foundation, so a file that uses `JSONEncoder` or `Date` and forgets
  `import Foundation` compiles there and fails on macOS. `make check` looks for that
  first (`scripts/lint-imports.py`).
- `CGRect` is CoreGraphics' on macOS and Foundation's on Linux, and they differ
  at the boundaries: use `overlaps`, not `intersects`. `GeometryTests` pins what
  Arbor relies on; add to it when you lean on something new.
- A test that needs a macOS framework lives in its own file and is `.disabled`
  elsewhere with a reason containing "only on macOS" (`CarbonKeyCodeTests.swift`
  is the pattern). `parity.py` takes exactly those as passing in a run off
  macOS, so `docs/FEATURES.md` comes out the same on both platforms. A test
  skipped for any other reason proves nothing and breaks the item that lists it, and so does
  one in a file that is compiled only on macOS (`EventTapThreadTests.swift`, all of it inside
  `#if os(macOS)`), which off macOS is not found: do not list such a test in `parity.json`.

**The macOS-only code** is proved through GitHub:

1. Push the work branch and open a **draft pull request** against `main`; the
   PR description is the report (same template).
2. GitHub Actions runs the headless stack on Linux and everything on `macos`.
   Both build, test, and run the simulator smoke test, the scenarios and
   `parity.py --check` (on the Mac: see below); `macos` then runs the real-window and real-pointer tests. A newer push
   cancels the run for the older one.

   Linux runners are plentiful, so the Linux work is several jobs side by side, each named `linux-…`
   (`linux-lint`, `linux-typecheck-mac`, `linux-sim`, `linux-tests`). The last job, `linux`, passes only if all of
   them did: that one is the Linux verdict. A new job gets a name that starts with `linux-` and a place in its `needs`;
   `scripts/test-ci-linux.py` (part of `make lint`) fails if it has none, or if a step of `make check` is run by no job.

   A macOS job is slow and runners are few, so a first small job,
   `changes`, leaves it out (it shows as skipped, and the annotation on
   `changes` says why) when a Mac could prove nothing new
   (`scripts/ci-changes.py`; the `linux-lint` job holds its rules to the table of
   cases in `scripts/test-ci-changes.py`):
   - the pull request changes only `collab/`, `docs/`, `*.md` files, `scripts/typecheck-mac/`, the scripts in
     `scripts/mac-shell/` that CI does not run (it runs `e2e-drag.sh` and `compile-tools.sh`, built on `lib.sh`, `pointer.swift` and
     `state.py`), the Mac shell workflow, and the rules and self-tests that only Linux runs;
   - or besides those only code that Linux builds and tests too: `Sources/ArborCore`,
     `Sources/ArborKit/{Controller,Platform,Support}`, `Sources/ArborTesting`,
     `Sources/arbor-sim`, `Sources/LinuxShims`, `Tests`;
   - or only prose has changed since the last commit that passed on a Mac
     (the report pushed after the code; a branch moved to a tested head).

   The second rule does not hold where work is integrated (pushes to `main`, pull requests into it,
   the pull request from `swarm/trunk`): there every change of code is compiled
   and driven on a Mac. So a change to the controller or a platform protocol can
   pass its own pull request and break the macOS-only code that uses it. The `linux-typecheck-mac`
   job type-checks that code against stand-ins (`make typecheck-mac`), which catches a changed
   name or type; it runs nothing. When
   you change something `AX`, `App`, `Input`, `IPC` or `UI` calls, run that first, and ask for the Mac with
   **`[mac]` in the subject of the head commit** (or the label `mac`), or
   compile with `scripts/mac-shell/run.sh scripts/mac-shell/compile.sh`.

   A Mac that does run need not repeat what `linux` runs on the same commit, nor build what an earlier job has built. There is
   one Mac job, `macos`: it sets up once, builds once, runs **only the tests a Mac can say something about**, then the
   real-window and real-pointer tests. `scripts/ci-tests.py select` lists the test files, each with its reason (a
   compile-time condition, a trait that switches a test on or off, an Apple framework, real files, sockets,
   processes, threads and clocks, or a place in that script's `ALWAYS`). The annotation on `changes` says how it runs, and why:
   - **in an ordinary pull request** it builds upon an earlier job's build (`docs/TESTING.md`, "What a run starts with");
   - **where work is integrated** (pull requests into `main`, the one from `swarm/trunk`, pushes to `main`) it builds from
     nothing, and only a pass of that kind (the job `macos-from-nothing` marks it) spares a later run there its Mac;
   - **every test, built from nothing**: every night on `main`, when **`[mac-full]` in the subject of the head commit** (or the
     label `mac-full`) asks for it, when the workflow is started by hand, and when anything is unclear.

   `real-windows` is still a check of its own, with its own annotations, but no longer a Mac of its own: it passes on what the two
   steps on real windows in `macos` said. So `macos` green and `real-windows` red means what it always did.

   Nothing is dropped on the way. Both jobs leave a record of every test and what became of it, and the job
   `tests-accounted-for` fails, naming each one, if a test ran neither on the Mac nor on Linux: one that only a
   Mac compiles and the selection missed, one that is skipped on both. Its summary counts what ran where. If it names
   your test, give the file a reason to be selected; a test that is to run on neither is a decision, and goes
   into `NOWHERE_ON_PURPOSE` with the reason. With a selection `macos` leaves `parity.py --check` to `linux`,
   which runs it on every commit.
3. Read the results. Every step publishes its outcome as check annotations:
   compiler warnings, test counts and the parity score when it passes; the
   errors and the end of its output when it fails (`scripts/ci-step.py`). They can
   be read where logs, `gh pr checks` and `gh run view` are not available:

   ```bash
   gh api repos/evbarleyg/arbor/commits/<sha>/check-runs \
     --jq '.check_runs[] | "\(.id) \(.name) \(.status) \(.conclusion)"'
   gh api repos/evbarleyg/arbor/check-runs/<id>/annotations \
     --jq '.[] | "\(.annotation_level) [\(.title)] \(.path):\(.start_line)\n\(.message)"'
   ```

   **Do not ask GitHub in a loop.** An account has five thousand requests an hour, and agents that work under one account share
   them: a dozen that wait for a check by asking every ten seconds spend the lot, and then nobody can read a check, open a
   pull request or start a run until the hour is up. ONE poller asks for everybody, every two or three minutes, sparingly: it runs at
   GitHub itself (`.github/workflows/state.yml`), under a limit of its own, and puts what it heard on the branch `state/github`.
   Everybody else reads: `scripts/gh-state.py --read <file> --from state/github 123` for a pull request's line, with `--wait 123` to
   wait for its checks without asking anybody. `<file>` is any file of yours, or one that agents share; it is brought up to date
   by `git fetch`. (Should the workflow be down: one agent runs `scripts/gh-state.py --out <file>`, and the others read that file.) Ask git for what git can tell (`git ls-remote origin swarm/trunk 'refs/pull/*/head'`): that has no such limit.
   When you must ask GitHub: one request for a whole commit, as above, and `gh api rate_limit`, which is free, to see what is left.

4. Fix and push until the checks pass, then mark the PR ready, merge it
   (squash or merge commit), and update the board and parity data in the same PR.
5. Real-window checks: CI's `real-windows` job runs `make e2e` (GitHub's macOS
   runners grant Accessibility) and keeps the evidence as the artifact
   `e2e-evidence`. Drags, clicks, shortcuts, the menu bar and what
   it all looks like can be checked from anywhere with a Mac shell script
   (below). A shipped feature's real-window steps belong in the real-window
   suite (`scripts/mac-shell/suite/`, "The real-window suite" in
   `docs/TESTING.md`): five lines, rehearsed on Linux for nothing, run on a Mac,
   their evidence committed and their titles listed under `e2e` in
   `parity.json`, which is what turns *tested* into *verified*. What even that
   cannot reach (other apps' windows, a real trackpad) goes under "Still to
   check on a real Mac".

### A remote Mac: the "Mac shell" workflow

`.github/workflows/mac-shell.yml` runs one script from the repository on
GitHub's macOS runner, with the newest Xcode selected, and pushes everything the
script leaves in `mac-shell/` to a throwaway branch. It is for anything the
full CI run does not cover: seeing the real app (screenshots, real drags,
clicks and shortcuts), `swift test --filter …`, a build of a release bundle.

1. Commit the script on your branch, e.g. `scripts/mac-shell/shots-F09.sh`, and
   push; the workflow only runs files from the checked-out ref, never text
   typed into the dispatch form, and the script never sees a token.
   `scripts/mac-shell/lib.sh` has what a real-window session needs.
2. Run it: `scripts/mac-shell/run.sh scripts/mac-shell/shots-F09.sh [branch]`.
   It needs only `git` and `gh api`. It starts the workflow, waits, fetches the
   output into `.mac-shell/<script>-<run id>/`, prints the end of it, and
   exits with the script's exit code.
3. Look at the pictures and read `output.txt` and `arbor.log` there.

"Seeing the real app from anywhere" in `docs/TESTING.md` is the manual.
The output is also kept as the artifact `mac-shell-output`, its end as check
annotations and in the run's job summary. By hand, the workflow starts with
`gh api -X POST repos/evbarleyg/arbor/actions/workflows/mac-shell.yml/dispatches -f ref=<branch> -f 'inputs[script]=<path>' -f 'inputs[tag]=<name>'`
and the output lands on the branch `mac-shell-out/<name>` (the run id when no
tag is given). Pushes to those branches start no workflow.

## Talking between sessions

The repo is the channel: files on `main`, pull requests, and the GitHub issue
titled "Executor: work the board", where executors post short progress notes
(one comment per finished item, linking its report or PR).
Messages only point at files; decisions are written in the files.
