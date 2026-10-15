# F28: Traces: record real window events, replay them in tests

Status: done
Depends on: S2 (the headless stack on Linux), the Mac shell harness (`scripts/mac-shell`)
Board item: S3. Idea: IDEAS I7. Approved in QUESTIONS Q9; decisions in Q14. Manual: `docs/TRACES.md`.

## Summary

The agents writing Arbor cannot see how real apps behave. A trace turns what happened on a Mac into a file that any agent
can replay against the real `Controller` on Linux, read, debug, and keep as a regression test.

## Behaviour

1. **Format.** JSON lines, types in ArborCore. A header (format version, Arbor and OS versions, displays, settings, every window
   with id, pid, bundle id, app name, frame and flags, and what Arbor knew: workspaces, parked windows, learned minimum
   sizes, the filter), then one line per thing that crossed a platform seam, with the seconds since the start: every
   `WindowSystemEvents` callback with its arguments, every call into the `WindowSystem` with its result, every command with its
   result, overlay actions, the drop preview, scheduled work as it runs, settings as they are applied.
   **Never a window title**: each becomes a stable token, and the title patterns of rules become marks that the tokens carry, so
   title rules and re-matching still replay. High-frequency lines are thinned by a documented rule.
2. **Recorder.** Decorators around `WindowSystem`, `OverlayPresenter` and `Scheduler` that forward everything and write through a
   sink (a file in the app, memory in tests). Always installed; one branch per call while off.
   `trace on [name]`, `trace off`, `trace status`, `trace note <text>`. Files are `<Arbor home>/traces/<date>-<name>.jsonl`. A trace stops by
   itself at 20 MB or 10 minutes and says so.
3. **Replayer.** Builds a harness from the header and delivers the recorded stimuli to a real controller, with the clock at each
   line's time. Calls are answered from the trace where it has the same call, else by the fake's model. **Strict**: the same
   calls as recorded. **Free**: only invariants. Problems name the line of the file.
4. **Tests from traces.** Every `collab/evidence/traces/*.jsonl` is replayed in free mode by one parameterised test;
   `<name>.expect` adds expectations in arbor-sim's language. `arbor-sim replay <file> [--strict] [--verbose]` tells the story with drawings.
5. **Real traces** from a cloud Mac: `scripts/mac-shell/trace-demo.sh`.
6. **A recipe** for whoever has a Mac (`docs/TESTING.md`), `make trace`, `make trace-check`, `make replay`.

## Acceptance criteria

- [x] With tracing off nothing is written and every existing test passes through the decorators.
- [x] No window title, and no title pattern of a rule, reaches a trace by any route (header, events, settings, command results).
- [x] A session recorded on the fakes, with a bit of everything in it, replays in strict mode without a divergence and ends in the
      same state; so does a trace started in the middle of a session, and each scenario in `collab/scenarios`.
- [x] A changed frame, a missing call, an extra call, a changed order, a changed command result and a changed preview are each
      reported in strict mode with the line and both sides; free mode accepts them.
- [x] An app that refused a size in the recording refuses it in the replay, also for requests the trace does not have.
- [x] Scheduled work runs where the trace says it ran; work the trace does not mention runs by the clock.
- [x] An endless fight with an app, a lost window and a docked window left out of its slot are reported in both modes.
- [x] A trace stops by itself at its limits and says so; a sink that fails stops the trace and not Arbor.
- [x] Real traces recorded on a Mac are committed and replay on Linux and macOS.

## Shipped / Not shipped

Shipped: all of the above, plus `raw` lines (the Accessibility notifications and mouse events `AXWindowSystem` receives, before it makes
events of them), how long slow `setFrame` calls took, `problem <text>` in `.expect` files for traces of bugs nobody has fixed yet,
and a strict record-and-replay pass over every scenario in `make scenarios`.

Supersedes an earlier branch, `feat/S3-window-traces`, which is merged into this branch: same architecture; its path
helper, `make trace`, parity id and Q14 are kept, its format and replayer are replaced by the ones here (Q14 says why).

Not shipped: a menu item; recording from before `Controller.start()`; overlay scenes; re-recording a strict baseline from a replay.
