# Traces

Recordings of what passed between Arbor and macOS (`docs/TRACES.md`). `TraceCorpusTests` replays every `.jsonl` file here against the
real controller, on macOS and Linux, in free mode: Arbor may change what it does, but with these windows and these apps'
answers nothing may get lost, no tree may break, no fight with an app may go on for ever, and windows must end up where Arbor
put them. `<name>.expect` adds expectations about the end. See one with `make replay FILE=collab/evidence/traces/<name>.jsonl`
(`VERBOSE=1` for every line). Record one with `make trace NAME=<name>`, or on a cloud Mac with `scripts/mac-shell/trace-demo.sh`.

Window ids, process ids, app names, bundle ids, frames and times; never window titles. Under 200 KB each.

| Trace | Recorded | What it shows |
|---|---|---|
| `sim-dock-zoom-drag` | arbor-sim, 2026-10-14 | Three simulated windows: dock 101 left and 102 right, drag 103 to the left screen edge, zoom 101, back, minimize 102, run the pending work, restore 102, pull 101's right edge by 60 points. No real app; a sample of the format. |

All the rest were recorded on GitHub's macOS runner (macOS 26.6.2, one 1024×768 display) by `scripts/mac-shell/trace-demo.sh` on 2026-10-14, with a real
pointer (`pointer.swift`). The header's `arbor` says which commit. **B1 to B7** are the bugs the first traces showed; a trace that
shows one has a `problem` line in its `.expect` file and says when it is fixed. **B1, B5, B6 and B7 were fixed by the controller review (#17)**: their traces
went red, the `problem` lines were deleted, and they are regression tests now. **B3 went the same way with the compatibility lab (#23).** B2 was fixed in `AXWindowSystem` (#24), below what a trace
records; its two traces say what was done about that. **B5 came back with #101**, and `seam-drag-futile` has its `problem` line again.

**Test windows and a real pointer** (`ArborTestWindows`)

| Trace | What it shows |
|---|---|
| `click-title-bar` | A press and release on a title bar: no event at all reaches Arbor, and mouse-up arrives twice. |
| `drag-to-edge` | A floating window dragged by its title bar to the left screen edge: how late `dragBegan` is, how "moved" lags the pointer, the preview, the drop, the echoes of four `setFrame` calls. |
| `drag-onto-window` | A floating, unfocused window dragged onto the right part of a docked one: the focus event comes first. |
| `edge-resize` | A docked window's right edge dragged 60 points toward its docked neighbour: focus, `resizeBegan`, "resized" in bursts, enforcement polling the button, `resizeEnded`, the neighbour giving way. |
| `seam-drag` | The seam between two docked windows dragged 40 points: one `seamDragged` per mouse event, each with its layout. No raw mouse lines: the global monitor does not see events that go to Arbor's own panels. |
| `seam-drag-futile` | The same in the first run, with a floating window (w30) that is too big for the Desktop: it got a `setFrame` it refuses at every step. **B5** (fixed in #17, back since #101; the `.expect` file says how). |
| `minimize-restore` | A docked window minimized with its yellow button and restored by its app. The Dock changes the visible frame both times. B7 (fixed). |
| `close` | A framed, docked window closed with its red button: focus moves to the app's next window before the window is destroyed. |
| `drag-out` | A docked window dragged by its title bar out onto the Desktop; the preview changes eight times on the way. (First run; a window Arbor believes parked is on screen, see B1.) |
| `flick-to-edge` | A quick drag to the right screen edge, released at once: the last frame reported is 170 points behind the pointer. (First run.) |
| `quit` | `quit` with windows docked: everything is put back in view, then `stop`. |

**Test windows doing things by themselves**, as odd apps do (lines on `ArborTestWindows`' stdin)

| Trace | What it shows |
|---|---|
| `too-big` | A window that refuses to be smaller than 700×500 is docked into a smaller slot: the refusal, the second layout, the tile. Then B6 (fixed), then `show-all`. |
| `too-big-jump` | The same, cut before `show-all`, so that its end is the jump. B6 (fixed). |
| `tile-click` | A real click on that tile, then `show-all`. |
| `zoom-back` | `zoom` and `back`: parking (asked for y 767, took 673) and returning. |
| `title-change` | The app renames a docked and a floating window. |
| `self-move` | The app moves its own docked window without the mouse; Arbor puts it back 0.26 s later. |
| `app-minimize` | The app minimizes and restores its own docked window. B7 (fixed). |
| `stubborn-fast` | A window that goes back to its old frame 0.05 s after every move is docked. B2 (fixed in #24, below the seam: one line was added by hand, as the trace says, for what `AXWindowSystem` reports since). (First run.) |
| `stubborn-slow` | The same at 0.4 s: two rounds of a fight, then B2 ended it (fixed in #24; one line added by hand, likewise). |
| `hide-unhide` | The app hides and unhides itself. B1 (fixed), **B4**. |
| `app-switch-unreported` | Two apps: three docked windows of the first (29, 30, 31) and one of the other (75). 29 is framed, 75 is out of view, and the other app brings itself forward (arbor-e2e's "switch to the other app", cut after the switch). `didActivateApplication` came 5 ms before `frontmostApplication` named the app, so `AXWindowSystem` took it for an app in the background and dropped it: no `focused` line, only "the keyboard focus moved", twice, and the window had the keyboard out of view. One switch in three went like that. Fixed in `AXWindowSystem`, below what a trace records: one line was added by hand, as the trace says, for what it reports since. |

**An app that hangs**: two apps of test windows, one of which stops answering for 20 s (`scripts/mac-shell/check-hang.sh`, 2026-10-15, same kind of runner)

| Trace | What it shows |
|---|---|
| `hang-view` | The view moves six times while the app hangs. The first `setFrame` on one of its windows comes back `null` after 1.04 s, on the main thread; every later one `null` at once; the other app's windows take their slots meanwhile. When the app wakes its windows are reported and placed. |
| `hang-quit` | Quit half a second after the app hangs, with its two windows out of view. Each is asked to where it floated, in its own size (`null`, the first after 1.04 s), and at the end of the quit to "anywhere in view" (`null` again). The trace ends there; on the Mac both were still past the corner after the app woke. |

**Real apps**, one per session (`ARBOR_ONLY_PIDS`)

| Trace | What it shows |
|---|---|
| `textedit-commands`, `finder-commands`, `settings-commands`, `terminal-commands`, `calculator-commands` | Dock left (a slot 494 wide), make the slot 250 narrower, frame, show the Desktop, show all, float: what each app answers to each size and to being parked. **B3** in Terminal's and Finder's. |
| `terminal-rounds-up` | `terminal-commands` cut after its second command. B3 (fixed in #23). |
| `textedit-drag`, `finder-drag`, `terminal-drag` | Floating: dragged 150 points right and 60 down, then to the left screen edge. Finder ends as a tile for 7 points. |
| `textedit-edge`, `finder-edge`, `terminal-edge`, `calculator-edge` | Docked in a slot 760 wide, the right edge dragged 80 points left. Terminal shrinks a character at a time and renames itself before each "resized". Calculator cannot be resized: nothing is reported. |
| `textedit-drag-out`, `settings-drag-out`, `calculator-drag-out` | Docked, dragged by the title bar out onto the Desktop. |
| `apps-arrange` | All five together: `arrange` (three of them refuse their slots), `desktop`, `show-all`, `float-all`. |
| `app-quits` | TextEdit quits while its docked window is framed. |

Still to record: a double-click on the title bar of a docked and of a floating window;
Safari, an Electron app, full screen, Spaces, a second display. The script has the double-clicks.

## What real macOS does that `FakeWindowSystem` does not

Read off the traces above (macOS 26.6 on GitHub's runner, 1024×768, October 2026). Each of these is a way for a test on the fake to pass
while real windows misbehave. The trace in brackets shows it; `make replay FILE=… VERBOSE=1` prints every line.

| | Real macOS | The fake (on 2026-10-14 at 07:00 UTC, before the controller review made it more faithful) |
|---|---|---|
| 1 | **Echoes.** Every `setFrame` that changes something is followed by one to three `windowChanged(userInitiated: false)` (resized, moved, resized: `setFrame` sets size, position, size), each with the window's *current* frame. They come after the controller's handler has returned: usually 2 to 15 ms later, 0.3 to 0.55 s later for Finder, Terminal and now and then any window. A `setFrame` that changes nothing has no echo. [`drag-to-edge`, `finder-commands`, `calculator-commands`] | `setFrame` emits nothing |
| 2 | **Focus.** `focus(id)` is answered by `windowFocused(id)` 5 to 20 ms later, after the echoes, sometimes twice; not at all if the window had the focus. [`too-big`, `tile-click`, `zoom-back`] | `focus` emits nothing |
| 3 | **A title bar never goes below the visible frame.** Asked for y 767, windows took 673 (test windows), 676 (TextEdit), 679 (Terminal), 658 (Calculator, Finder, System Settings): the visible frame's bottom minus the title bar or toolbar. x is not limited. So a parked window shows a sliver one point wide and 30 to 50 high. [`zoom-back`, `*-commands`] | Takes any origin |
| 4 | **Whole points.** 150.5 became 150, 46.5 became 47, 261.5 became 261. [`settings-commands`, `apps-arrange`] | Keeps fractions |
| 5 | **Sizes.** Calculator is 230×408 whatever is asked. System Settings is 723 wide, at least 470 high, and has an empty title. Finder is at least 501 wide. Terminal rounds to whole characters *both ways*: 494×656 → 492×649, 244 → 247, 1000 → 1003. TextEdit took everything down to 244. A `setFrame` that only moves a window which is below its minimum size makes it grow to it. [`*-commands`, `apps-arrange`, `drag-to-edge`] | A minimum and a maximum; no rounding |
| 6 | **A drag begins late.** `dragBegan` comes 0.28 to 0.34 s after the press, after two or three mouse-dragged events, with the pointer 40 to 70 points away and the window already moved; a `changed` follows at once. "Moved" notifications come eight to ten a second, not one per mouse event, so `dragMoved` and `changed` are not in step, and the frame lags the pointer, also at the release. [`drag-to-edge`, `flick-to-edge`] | `dragBegan` before any movement, then `changed` and `dragMoved` in pairs |
| 7 | **Pressing on a window that is not focused** sends `windowFocused` first, so before `dragBegan` or `resizeBegan`. [`drag-onto-window`, `edge-resize`] | `drag` and `userResize` never focus |
| 8 | **Mouse-up arrives twice** at the global monitor (mouse-down sometimes), the second after Arbor has reacted. [`click-title-bar`, `drag-to-edge`] | Below the seam |
| 9 | **"Resized" can stall** for a second in the middle of an edge drag, while enforcement polls the button. [`edge-resize`] | One `changed` per step |
| 10 | **A new title** is `changed(userInitiated: true)` with the same frame. Terminal changes its title with every resize, and that `changed(userInitiated: true)` carries the new frame and comes *before* the echo, or before `resizeBegan` in a mouse resize. [`title-change`, `terminal-commands`, `terminal-edge`] | No helper for titles |
| 11 | **Unhiding moves windows.** Before "application shown", macOS brings windows that were nearly off screen back (1023,673 → 24,55): `changed(userInitiated: true)`, still hidden. [`hide-unhide`] | `setHidden` changes the flag only |
| 12 | **Restoring focuses first.** `windowFocused(id)` arrives while the window still counts as minimized, 1 to 2 ms before `changed`. [`minimize-restore`, `app-minimize`] | `setMinimized(false)` sends `changed` only |
| 13 | **Minimizing changes the display.** "Miniaturized" comes 0.55 s after the click, and 15 to 20 ms later `displaysChanged`: the Dock grows by the thumbnail and the visible frame changes by 2 points; back again on restoring. [`minimize-restore`] | One `changed` |
| 14 | **Closing focuses first.** `windowFocused(the app's next window)` comes 10 ms before `windowDestroyed`, and a `setFrame` on the closing window in between succeeds. [`close`] | `close` sends `windowDestroyed` only |
| 15 | **A window that cannot be resized** produces no event when its edge is dragged. [`calculator-edge`] | `userResize` reports a resize that changes nothing |
| 16 | **`setFrame` takes time**: 1 to 20 ms, 44 ms (Finder) and 101 ms (TextEdit) the first time. All of a layout's calls are made before any echo is heard. [`took` in every trace] | Instant |
| 17 | **An app that hangs makes the caller wait**: the first `setFrame` returns `null` after the whole timeout, 1.04 s. [`hang-view`, `hang-quit`] | `setUnresponsive`: `null` at once |
