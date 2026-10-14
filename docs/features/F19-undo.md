# F19: Undo and redo for the arrangement

Status: done
Depends on: F01 (works with F04, F07, F08, F11, F17, F57 and the waiting slots of the app shell review)

Written by the executor swarm, 2026-10-14; for the documenter to review. From IDEAS I3.

## Summary

One slip of the hand (⌃⌥A instead of ⌃⌥D, a window dropped on the wrong edge) can rearrange a
display that took minutes to set up. `back` and `forward` only move the view. `undo` and `redo` step
through the changes to the **arrangement**, so every such slip costs one shortcut. TrellisWM has nothing like it.

## Behaviour

- `undo` (⌃⌥Z) takes back the last change to the arrangement of one display; `redo` (⌃⌥⇧Z) puts it back. Which
  display is `cameraDisplay()`'s choice, as for `show-all` or `arrange`, by F56's rule: a shortcut means the display being
  typed on unless the pointer moved last, the menu the display whose menu bar was clicked. Both are in the menu, which
  names the step in a word or two ("Undo Dock", "Redo Float All"); plain "Undo" and "Redo" are greyed out when there is
  nothing to do there.
- In a window that is full screen both are refused, as `dock` is: its display's arrangement is on another of the macOS
  Spaces, where nobody would see it change.
- **A step is one change the user made**, however it was made:
  - commands: `dock` (docking and moving), `dock … beside`, `float`, `toggle-float`, `arrange [all]`,
    `float-all [here]`, `resize`, and any later command that changes a tree or who floats;
  - dropping a dragged window (on an edge, beside a window, as a tab, on the Desktop);
  - dragging a gap: everything between pressing the button and releasing it is one step;
  - resizing a docked window by its own edges (one step, on release);
  - a rule docking a new window (undoing it leaves the window floating on the Desktop). Nobody asked for that
    change just then, so unlike every other step it leaves `redo` alone.
- **Quick repeats of one small adjustment are one step.** `resize` of the same edge of the same window again within a
  second goes on with the same step, so a dozen taps on a shortcut cost one undo and do not push the real
  changes out of the 50 steps. A pause, another edge, another window or any other change starts a new step.
- **Not steps**: moving the view (`back` and `forward` do that), also when Arbor then moves gaps by itself to make room for a
  window (F61), summoning an app's window (F53), pinning a floating window (F49), saving a view, switching tabs, moving a
  floating window around, windows opening, closing or minimizing, `exclude` and `include`, and anything
  that fails or changes nothing.
- **Straight after a change, undo puts back exactly what was there**: the tree, the sizes, which windows
  float and where they were on screen, the view, its history and the saved views. A change can move the
  view itself (floating the framed window does, `arrange` always does); that is undone with it.
- **What was done since that is not arrangement is kept**:
  - the view stays where it has been moved to, if that space still exists in the restored
    arrangement; otherwise it goes back to where it was before the change. History keeps the places that still exist;
  - views saved since are kept if their space still exists;
  - floating windows moved since stay where they were put;
  - tab groups keep showing the tab switched to since;
  - a window that opened over a framed window since (F57) still belongs to that space, if the space still exists.
- **Every undo shows what it did.** With one window framed, a change elsewhere would show nothing, and the natural second
  press would take back something else. Or it would show only that a window has left the Desktop, and not where it went.
  So when the view would stay put, it steps out just far enough to look different and to have in it the windows that
  changed places: in their slots, or on the Desktop. `back` returns. If nothing shows from anywhere (every window the
  change was about is minimized), the view stays. The same goes for redo, so undo followed by redo gives back the
  arrangement exactly, and the view either exactly or stepped out from where it was.
- **The restored arrangement is fitted to the windows that exist now.** Every window stays in exactly one
  place, docked or floating:
  - windows closed since (or excluded since) leave the restored tree the way closing a window does;
  - windows opened since stay floating;
  - minimized windows, hidden apps and windows on other macOS Spaces keep their place and take no space;
  - a window docked on another display since stays there; a window floating on another display comes back to
    its slot, but one that was floating here as well was simply moved since, and stays;
  - a saved slot that still waits for its window after a launch goes on waiting, and the window that takes it is
    from then on the window every older step means. The same holds for a native tab that comes to the front
    (to macOS each tab is a window of its own, F17): the steps follow whichever tab stands for the window.
- A step that would change nothing any more (every window it was about has closed) is skipped, so each
  press does something visible.
- **What cannot be taken back is said once.** When a docked window closes, or `exclude` takes docked windows away, the
  arrangement changes before the user's eyes and undo cannot bring it back. The next `undo` fails and says so:
  `cannot undo the closing of a window of Notes; undo again to take back dock w101 left`. The press after that goes on with the
  older step. Several in a row (an app that quits) count as one; a floating window that closes is no obstacle;
  `redo` is not held up.
- **Each display has its own history.** A change that touches several displays (`float-all`, `arrange all`, a
  window dragged or docked across) is one step on each of them. Undoing it on any of them takes it back
  on all: one slip, one undo, wherever the pointer is. A display that has changed again since is left
  out and keeps its part of the step until its own turn comes; a window that would go back to such
  a display floats here until then.
- 50 steps per display. A new change clears redo on the displays it touches. The history is not saved between
  launches, and a display that disconnects loses its history (its arrangement still comes back, F08). It
  survives `pause` and `resume` (F40); while paused the commands fail like any other.
- Replies say what happened: `undid dock w101 left`, `redid arrange`, `undid resize w101 right` (no amount: it may be
  several), `undid drag the gap between Safari (n1) and the Desktop`, `nothing to undo` (with several displays: `… on the focused window's display`),
  `cannot undo while a window is being dragged`. What they call a step never holds part of a window's title or the name of
  a space, because replies are logged: `undid layout Safari~… | Mail`, `undid drag the gap between Safari and Mail (n4) and the Desktop`.
- `arbor://undo` and `arbor://redo` are accepted: they only rearrange, and each takes the other back.
- `arborctl state` has `undo` and `redo` for each display: what each would act on, or nothing. They pass over what
  the commands would pass over, and the menu items are greyed out by the same answer.

## Design notes

- Trees are values, so a step (`UndoStep`, ArborCore) is the display's `Workspace` before the change, the
  workspace right after it, and where the floating windows in view actually were (docked windows push
  them away from where the user put them, which is all the workspace remembers).
- `UndoHistory` (ArborCore) only stores steps: per display, both directions, the limit, steps that
  share an id across displays, and steps left open for more of the same change.
- `Workspace.restored(over:since:)` carries over what was done since. "Since" is whatever differs between the
  workspace right after the change and the workspace now.
- A node id alone does not say that a space still exists: `arrange` and `float-all` start a new tree that
  numbers from 1 again. `LayoutTree.isSameNode(_:in:)` also wants the same kind of node with a window
  (or the Desktop) in common.
- Recording happens in one place. `Controller.perform` wraps every command in `beginUndoStep` and
  `endUndoStep`, which compare the workspaces before and after (`hasSameArrangement`: the tree without
  the showing tabs, and who floats). New commands need nothing. **An entry point that is not a
  command and changes a workspace wraps itself in `recordingUndo("what it is called") { … }`.** Nested calls record once.
- A change is recorded as a step only if undoing it straight away would change something. Otherwise, if it changed
  what is docked, it is kept as a step that only says it cannot be undone (`UndoStep.isIrreversible`). That
  covers closing, `exclude` and `reload-settings` without a list of exceptions.
- A step can stay open for more of the same change (`UndoContinuation`): until the mouse button is up (a gap drag),
  until a second has passed without another (`Command.mergesWithRepeats`), or until its owner says so.
- **A step is a copy of the whole `Workspace`, so every field anybody adds to `Workspace` meets undo.** The rule for a new
  field is in `docs/ARCHITECTURE.md`, "A new field in `Workspace`", and a test fails until
  `Workspace.restored(over:since:)` deals with the field.
- A window can change its number (a waiting slot is taken, a native tab comes to the front, an app restarted
  during a pause). Wherever the controller calls `replaceWindow`, it also calls `undoHistory.renumber(_:as:)`.
- No event says that the button went up over one of Arbor's own panels, so an open gap drag is closed by
  a scheduled check of `isMouseButtonDown()` every 0.25 s. Releasing and grabbing the same gap again faster
  than that counts as one drag.
- Restoring is `Controller.restorations(from:)` (pure: it is also how a recording is tried out) and then
  `install`, which decides where the floating windows go (`floatingPlan`, pure as well) and lays the displays out. The
  layout moves them, so that an undo is one journey on F02's stage like any other change.

## Acceptance criteria

1. Each of `dock`, moving with `dock`, `dock … beside`, `float`, `toggle-float`, `arrange`, `float-all` and `resize` is
   one step; `undo` restores the workspace and every frame exactly, `redo` the state after the command.
2. Drops, gap drags (one step per press of the button), edge resizes, tab drops and rule docks are steps.
3. View moves, saved views, tab switches, moves of floating windows, failed commands and commands that change nothing are not.
4. The view is not undone, except when the change moved it or its space no longer exists.
5. Undoing `arrange` and `float-all` brings back the view, history, saved views and floating frames.
6. Windows closed since are removed with the usual remap; opened since float; minimized or on another
   macOS Space keep their slot; docked on another display since are not duplicated.
7. A step whose windows are all gone is skipped; with nothing left the command fails and says so. After a docked
   window closed or was excluded, the first `undo` fails, names it and names what the next one would take back.
8. 50 steps per display; a new change clears redo; nothing survives a restart or a disconnect; a pause does no harm.
9. A change to several displays (`float-all`, `arrange all`, a window sent across) is undone and redone as one
   from any of them; a display that has changed since keeps its part.
10. `undo` is refused while a window is being dragged or resized with the mouse.
11. Random walks of commands, drags, closings, native tabs, undos and redos on two displays never lose or duplicate a
    window, and `undo` followed by `redo` gives back the same workspaces, the same windows out of view and the same slots.
12. With a window framed, an undo elsewhere steps the view out just far enough to show it, with the windows that changed
    places in view.
13. Quick resizes of one edge are one step; a pause, another edge or another change starts a new one.
14. Guests stay guests, waiting slots go on waiting and never float, and steps follow a window that changes its number.
15. A test fails when `Workspace` gains a stored property that `restored(over:since:)` does not mention.
16. `make check`, `make scenarios` and `make parity` pass.

## Shipped

- `ArborCore/UndoHistory.swift` (`UndoStep`, `UndoHistory`, `Command.label(focused:)`, `Command.mergesWithRepeats`),
  `ArborCore/LayoutTree+Comparison.swift` (`hasSameArrangement`, `isSameNode`), and
  `Workspace.hasSameArrangement(as:)`, `restored(over:since:)` and `renumber(_:as:)` at the end of `Workspace.swift`.
- `Controller+Undo.swift`: recording, the two commands, fitting old workspaces to the present, stepping out, placing
  floating windows. Two lines in `perform`, `seamDragged`, `finishDrop` and `windowDestroyed`; one each in `dragBegan`,
  `resizeEnded`, the rules' `dockNewWindow`, `retireWorkspace`, and beside each of the six calls of `replaceWindow`.
- `undo` and `redo` commands, ⌃⌥Z and ⌃⌥⇧Z, two menu items, `undo` and `redo` in `arborctl state`.
- Tests: `ArborCoreTests/UndoHistoryTests.swift` (history, tree comparison, carrying over, renumbering, labels, the
  check of `Workspace`'s fields), `ArborKitTests/UndoTests.swift` (one or more scenarios per criterion, thirty random
  walks on two displays, forty launches with windows that come back late),
  `collab/scenarios/F19-undo.sim`, and real windows in `scripts/mac-shell/shots-F19.sh`.

## Not shipped

- Saving a view over another (⌃⌥⇧3 instead of ⌃⌥3) is not a step, so it cannot be undone. It would be an
  invisible step for someone using only shortcuts. For the documenter to decide (QUESTIONS, "Decided by the executor").
- A floating window goes back to where it really was on screen, with two exceptions, in which the picture is
  not exactly the old one: a window that is still where its app opened it, which nobody chose, and one
  that hung more than half off the display. Both are put on the Desktop, as by any change to the arrangement.
- Closing a window cannot be undone: Arbor cannot reopen it. `exclude` is not undone either: it is a setting.
- `arrange` and `float-all` give up the slots that wait for windows; undoing them does not make the slots wait again.
- After a rule docked a new window, `redo` puts back an arrangement that does not know that window, so it floats.
- While the view is held (F58, `hold`) `undo` and `redo` are refused: they can move the view. They work after `release`.
