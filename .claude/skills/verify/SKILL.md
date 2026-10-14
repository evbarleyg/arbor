---
name: verify
description: How to verify an Arbor change by running it. arbor-sim drives the real controller on macOS and Linux; the real app needs a Mac with Accessibility permission.
---

# Verifying an Arbor change

## Pick the surface

| The change is in | Drive | Where |
|---|---|---|
| `ArborCore`, `ArborKit/Controller`, `Platform`, `Support`, `ArborTesting` | `arbor-sim` | macOS or Linux |
| `scripts/`, `Makefile` | the script itself, with good and bad arguments | macOS or Linux |
| `.github/workflows/` | push a draft PR and read the run's annotations | GitHub |
| `ArborKit/AX`, `UI`, `Input`, `IPC`, `App`, `arborctl`, `arbor-e2e` | `make run`, `arborctl`, `make e2e` | a Mac whose terminal has Accessibility |

Without such a Mac, the last row cannot be observed: macOS CI only proves it compiles. Say so,
and list the steps under "Still to check on a real Mac" in the report.

## arbor-sim

```bash
swift build
export ARBOR_HOME=$(mktemp -d)     # keeps arbor.log out of the real home folder
.build/debug/arbor-sim quiet "open Safari" "open Calc 300x400" "dock 101 left" "move 102 427 200 300 400" relayout ascii
```

No Swift on the machine, but Docker: `./scripts/linux.sh bash -c 'swift build && .build/debug/arbor-sim …'`
(the build lives in a Docker volume, so run the binary in the same command).

- Commands are arguments, or lines on stdin. The header of `Sources/arbor-sim/main.swift` lists the
  simulator's own (`open`, `close`, `move`, `drag`, `pull`, `seam`, `tile`, `cursor`, `flush`, `title`, `displays`…);
  everything else is an `arborctl` command (`help`).
- Start with `quiet` and end with `ascii` or `state`; otherwise every step prints a drawing.
- One display, 1440×900, visible frame y 25 to 900, gap 12. Window ids start at 101. With one window
  docked left, it spans x 12 to 714 and the Desktop x 726 to 1428.
- Saves and put-backs are scheduled: run `flush` to make them happen.
- `ARBOR_DEBUG=1` also logs failed commands to `$ARBOR_HOME/arbor.log`.
- `settings-file <path>` wires in a real settings.json as the app does; `diff` the file before and after.

Not reachable from arbor-sim: the watcher that applies settings.json as it is saved (macOS only; here
any command that changes settings, or `reload-settings`, takes the file in). Say so rather than calling it verified.

## CI changes

Open a draft PR, then read what each step published (logs may not be downloadable):

```bash
gh api repos/evbarleyg/arbor/commits/<sha>/check-runs --jq '.check_runs[] | "\(.id) \(.name) \(.status) \(.conclusion)"'
gh api repos/evbarleyg/arbor/check-runs/<id>/annotations --jq '.[] | "\(.annotation_level) [\(.title)] \(.message)"'
```
