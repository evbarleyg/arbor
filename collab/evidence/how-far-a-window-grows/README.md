# How far macOS lets a window grow or go: the lines

What `collab/reports/2026-10-15-how-far-a-window-grows.md` was read off. All from hosted Macs, macOS 26.6.2, on 2026-10-15. No window title is in any of it: the traces hold a title's length, the probes' lines none.

| | what | made by | read with |
|---|---|---|---|
| `first-catch/traces/*.jsonl` | the five traces of Arbor (the trunk at 848da3f7) in which the short window was first seen: run 38685233668, one display 1024×768, the Dock at the bottom, 182 `setFrame` calls. The report's part 1 cites them by line ("commands 26") | `scripts/mac-shell/reality.sh` | `scripts/reality-clip.py collab/evidence/how-far-a-window-grows/first-catch` |
| `grow.jsonl` | 844 calls and 466 results, Arbor not running: run 38691152836. Part 2 cites it by line | `scripts/mac-shell/probe-how-far-a-window-grows.sh` at 60b4dd7a | `scripts/mac-shell/grow-table.py` |
| `inhand.jsonl` | 703 lines: a size call while a synthetic pointer holds the window, Arbor not running: run 38705723680. Part 3 cites it by line | `scripts/mac-shell/probe-a-size-call-in-the-hand.sh` at 19ca32f1 | `scripts/mac-shell/grow-hand.py` |

`scripts/mac-shell/grow.swift`'s header says what is in a line of the last two; `docs/TRACES.md` what is in a line of a trace.

They are records of what happened once and are never written again. Not here, because they are large or are pictures: the runs' `output.txt`, the 60 Hz samples and the watcher's notes of the third run, three pictures of the second.
