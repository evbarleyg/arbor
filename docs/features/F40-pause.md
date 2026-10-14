# F40: Pause and resume

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done (`feat/review-ux`)
Depends on: F01, F06

## Summary

Sometimes a window manager has to get out of the way: a game, a remote desktop or virtual machine that needs ⌃⌥, an app Arbor is
fighting with, a moment when someone else uses the Mac. Quitting works but loses the menu bar item and has to be undone by hand. `pause` lets go of
everything and `resume` takes it back. (For a shared screen, where bringing every window into view is the last thing wanted, see F58.)

## Behaviour

- `pause`: windows **in view** (docked ones the view shows, floating ones on a Desktop that is in view) are not touched at all: same place, same size. Someone framed on a virtual machine who
  wants ⌃⌥ back sees nothing change. Windows **out of view** come back on screen without being raised: at the frame they floated at before they were docked if that is remembered (F48), otherwise in their slot with
  everything shown. Tiles, gap handles and previews go away. Arbor stops observing windows and moves nothing, whatever happens.
- Windows come into view **because** nothing reacts to ⌘Tab during a pause: a window left out of view would be lost. They end up behind what is in view, as on any Mac.
- **Quitting during a pause** leaves no trace either: Arbor looks once more, puts the windows nobody has moved since the pause began back where they floated, and stops. Nothing is laid out or sent out of view on the way.
- Every shortcut is handed back to the apps except those bound to `toggle-pause` or `resume`. The pinch and rectangle event taps are removed.
- `pause <minutes>` (up to 1440) resumes by itself. A second `pause` replaces the first one's end; `pause` without a number has no end.
- `resume`: the saved arrangement, view, history and saved views come back, matched against the windows and displays that exist by then, as at
  launch: windows closed meanwhile leave no empty slot, new ones float, windows moved by hand return to their slots. If nothing was touched meanwhile, what is in view does not move.
- `toggle-pause` (⌃⌥⎋) does whichever applies.
- While paused, other commands fail with "paused: … until `resume`"; queries work; `state` has `"paused": true`, no window list and no frames, and still
  shows the arrangement that will come back.
- The settings commands are the exception (`set`, `reset`, `bind`, `rule …`, `settings-window`): they work during a pause, are saved, move nothing, and count from
  `resume`. `unbind` of the last shortcut that ends the pause leaves the menu as the only way to resume, and says "no shortcut does now".
- The menu shows "Arbor is paused", Resume, Settings… and Quit; the menu bar icon is dimmed. ⌃⌥, is handed back like the other shortcuts.
- A pause does not survive a relaunch: starting Arbor means wanting it.

## Design notes

- `Controller+Pause.swift` calls `shutdown(leavingWhatIsInView: true)` and later `start()`, so both ends run code that quitting and launching already exercise. `resume` first drops what the
  controller knew about windows and displays.
- `resume` starts from a copy of the arrangement kept in memory, so it does not depend on `state.json` having been written.
- `Command.endsPause`, `KeyBindings.whilePaused(_:)` and `Controller.inputSettings` keep the decisions in tested code; `ArborApp` re-registers shortcuts and
  updates the taps on the `.lifecycle` change.

## Acceptance criteria

1. Pausing while framed leaves every docked and floating window at least 99% on a display and removes every overlay; the windows that were in view keep their frames, before, during and after (no `setFrame` for them).
   ✔ `pausingBringsEveryWindowBackIntoView`, `aPauseCannotBeSeenByWhoeverIsFramedOnAWindow`, `withEverythingInViewAPauseAndAResumeMoveNothing`
2. While paused, moves, drags, minimising, focus changes, new and closed windows, display changes and pending work cause no `setFrame`. ✔ `whilePausedArborMovesNothingWhateverHappens`
3. Resume restores workspace, camera and history exactly when nothing changed. ✔ `resumingRestoresTheArrangementAndTheCamera`
4. Resume copes with windows closed, opened and moved meanwhile, reported or not. ✔ `resumingCopesWithWhatChangedMeanwhile`, `resumingCopesWithChangesNobodyReported`
5. Timed pauses end by themselves, can be replaced, and are cancelled by a manual resume. ✔ three tests
6. Only shortcuts that end the pause stay registered; the taps' settings are off. ✔ `onlyTheShortcutsThatEndThePauseStayRegistered`, `thePointerTapsAreOffWhilePaused`
7. Quitting while paused is safe, keeps the arrangement for the next launch, and puts the windows nobody has moved back where they floated. ✔ `quittingWhilePausedIsSafe`, `quittingWhilePausedLeavesNoColumnShapedWindows`,
   `quittingWhilePausedLeavesWhatSomebodyMovedMeanwhile`

## Shipped / Not shipped

Shipped: everything above. Not shipped, and worth doing next:

- **Pausing by itself.** While displays are mirrored (`CGDisplayIsInMirrorSet`: a projector), and while an app on a list is frontmost (F41, `pauseForApps`).
  macOS has no public way to ask "is my screen being shared?", so that case stays manual.
- "Pause for an hour" in the menu (the command exists; the menu has only the plain toggle).
- Still to check on a real Mac: `AXWindowSystem` is stopped and started again in one process for the first time; ⌃⌥⎋ registers; other ⌃⌥ keys reach the
  frontmost app during a pause; the icon dims.
