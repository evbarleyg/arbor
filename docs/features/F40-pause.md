# F40: Pause and resume

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done (`feat/review-ux`)
Depends on: F01, F06

## Summary

Sometimes a window manager has to get out of the way: a game, a remote desktop or virtual machine that needs ⌃⌥, an app Arbor is
fighting with, a moment when someone else uses the Mac. Quitting works but loses the menu bar item and has to be undone by hand. `pause` lets go of
everything and `resume` takes it back. (For a shared screen, where bringing every window into view is the last thing wanted, see F58.)

## Behaviour

- `pause`: **as if Arbor had quit, and it comes back.** Every window Arbor has moved or resized, in view or out of it, goes back to where it was, in its own size, in one move and without being raised: a docked window
  to the frame it floated at before it was docked if that is remembered (F48), otherwise into its slot with everything shown; a floating window that docked ones pushed aside or squeezed to where its user left it. A window Arbor has not
  touched is not touched now. A docked window that is in the hand goes straight there too, not by way of its slot; a floating one stays where the hand has it. Tiles, gap handles and previews go away. Arbor stops observing windows and moves nothing, whatever happens.
  ("Quitting, Float All and pause give windows back their own earlier sizes, not just a visible position." Until 2026-10-14 a pause left what was in view as it was, in the shape of its slot. Someone framed on a virtual machine who
  only wants ⌃⌥ back has Shortcuts Off in “App” (F41), which moves nothing.)
- Windows come into view **because** nothing reacts to ⌘Tab during a pause: a window left out of view would be lost. They end up behind the window in use, as on any Mac.
- **Quitting during a pause** has nothing left to do, and asks no app anything.
- Every shortcut is handed back to the apps except those bound to `toggle-pause` or `resume`. The pinch and rectangle event taps are removed. Since a key that lands in another app can do there what cannot be taken back (IDEAS I16), the line on screen at the pause says whose the keys are now: "Arbor is paused: its keys are the apps’ again · ⌃⌥⎋ resumes" (QUESTIONS Q29, 2). A pause is one of the few ways in which a person gives Arbor's keys away; where nobody did, Arbor keeps them (F63): also in the pause it takes by itself when a logout begins, which any app can cancel.
- `pause <minutes>` (up to 1440) resumes by itself. A second `pause` replaces the first one's end; `pause` without a number has no end.
- `resume`: the saved arrangement, view, history and saved views come back, matched against the windows and displays that exist by then, as at
  launch: windows closed meanwhile leave no empty slot, new ones float, windows moved by hand return to their slots. Each window moves once, also when the keyboard has gone to a window that the saved view leaves out: a resume ends with that window in view (F41), so the view is worked out first and everything is laid out
  once. A floating window the pause took off the Desktop goes back on it, unless somebody has moved it
  meanwhile: then the resume leaves it where they put it.
- `toggle-pause` (⌃⌥⎋) does whichever applies.
- While paused, other commands fail with "paused: … until `resume`"; queries work; `state` has `"paused": true`, no window list and no frames, and still
  shows the arrangement that will come back.
- The settings commands are the exception (`set`, `reset`, `bind`, `rule …`, `settings-window`): they work during a pause, are saved, move nothing, and count from
  `resume`. `unbind` of the last shortcut that ends the pause leaves the menu as the only way to resume, and says "no shortcut does now".
- The menu shows "Arbor is paused", Resume, Settings… and Quit; the menu bar icon is dimmed. ⌃⌥, is handed back like the other shortcuts.
- A pause does not survive a relaunch: starting Arbor means wanting it.

**Changed on 2026-10-14 by the product owner (QUESTIONS Q21):** a pause has one meaning: as if Arbor had quit, and it comes back. Every window Arbor sized goes to its own earlier frame, one move each, nothing raised; resume brings arrangement and view back. "What you are looking at stays as it is" no longer holds. Built: the text above and below says what the trunk does.

## Design notes

- `Controller+Pause.swift` calls `shutdown()` and later `start()`, so both ends are the roads that quitting and launching take: what is mended on them is mended for a pause. `resume` first drops what the
  controller knew about windows and displays, but for where the pause left the windows it moved (`pausedFrames`), which tells it what nobody has touched since.
- `resume` starts from a copy of the arrangement kept in memory, so it does not depend on `state.json` having been written.
- `Command.endsPause`, `KeyBindings.whilePaused(_:)` and `Controller.inputSettings` keep the decisions in tested code; `ArborApp` re-registers shortcuts and
  updates the taps on the `.lifecycle` change.

## Acceptance criteria

1. Pausing leaves every docked and floating window at least 99% on a display and removes every overlay; every window Arbor had moved or resized is at its own earlier frame, after one `setFrame`, and the others after none; nothing is raised;
   a resume brings every frame back, after one `setFrame` each. ✔ `pausingBringsEveryWindowBackIntoView`, `aPauseGivesEveryWindowItsOwnFrameBackInOneMove`, `aPauseRaisesNothingAndLeavesTheKeyboardWhereItIs`,
   `resumingBringsTheArrangementAndTheViewBackInOneMove`, `aResumeWithTheKeyboardOutsideTheViewStillMovesEachWindowOnce`, `aGuestWithTheKeyboardBringsItsHostsViewBackInOneLayout`, `framedOnAWindowAPauseGivesThatOneItsSizeBackToo`, `aPauseLeavesTheWindowsWhereAQuitWould`, `aPauseAndAResumeMoveOnlyWhatArborHadMovedOnceEachWay`;
   `collab/scenarios/40-a-pause-gives-sizes-back.sim`
2. While paused, moves, drags, minimising, focus changes, new and closed windows, display changes and pending work cause no `setFrame`. ✔ `whilePausedArborMovesNothingWhateverHappens`
3. Resume restores workspace, camera and history exactly when nothing changed. ✔ `resumingRestoresTheArrangementAndTheCamera`
4. Resume copes with windows closed, opened and moved meanwhile, reported or not. ✔ `resumingCopesWithWhatChangedMeanwhile`, `resumingCopesWithChangesNobodyReported`
5. Timed pauses end by themselves, can be replaced, and are cancelled by a manual resume. ✔ three tests
6. Only shortcuts that end the pause stay registered; the taps' settings are off. ✔ `onlyTheShortcutsThatEndThePauseStayRegistered`, `thePointerTapsAreOffWhilePaused`
7. Quitting while paused is safe, keeps the arrangement for the next launch, and moves nothing: the pause has put the windows back. ✔ `quittingWhilePausedIsSafe`, `quittingWhilePausedLeavesNoColumnShapedWindows`,
   `quittingWhilePausedLeavesWhatSomebodyMovedMeanwhile`, `aQuitDuringThePauseHasNothingLeftToDo`, `aQuitDuringThePauseAsksNoAppAgain`

## Shipped / Not shipped

Shipped: everything above. Not shipped, and worth doing next:

- **A window in view whose app does not answer when the pause begins** keeps the shape of its slot, as after a quit (one that is out of view is tried again until it comes, F17); `pause` replies as if it had not.
- **With no display at all** a pause, like a quit, moves only what was out of view.
- **Floating windows go back on the Desktop in the resume's one layout, or not at all.** One that is minimized, hidden or hung at that moment, one whose app settled on another size after the pause had stopped listening, and all of them after a
  pause that ended otherwise (the watchdog brought it back after a crash; Accessibility was taken away and given back) stay where their user had left them, over the docked windows if need be.
- **A floating window moved during the pause** is left there by the resume, but what is remembered for it is still the frame of before (F48: "a move during a pause, which Arbor does not see"), so a later layout can take it back there; one that
  floats alone takes the Desktop again two seconds later (F18).
- **Two layouts are left** at a resume where the plan cannot tell whether the view will follow the keyboard: to a window of the saved view that is too small there and becomes a tile, and during a call, where the hold decides (F58).
- **One after the other.** A pause asks each app in turn, as a quit does, where a layout lets the apps work side by side (`moveTogether`).
- Nobody has watched the new pause on a Mac yet. The day with real apps that found the fault checks sizes, places and the number of moves at its steps "pause" and "resume"; `scripts/mac-shell/check-F18.sh` checks the window that fills the Desktop.

- **Pausing by itself.** While displays are mirrored (`CGDisplayIsInMirrorSet`: a projector), and while an app on a list is frontmost (F41, `pauseForApps`).
  macOS has no public way to ask "is my screen being shared?", so that case stays manual.
- "Pause for an hour" in the menu (the command exists; the menu has only the plain toggle).
- Still to check on a real Mac: `AXWindowSystem` is stopped and started again in one process for the first time; ⌃⌥⎋ registers; other ⌃⌥ keys reach the
  frontmost app during a pause; the icon dims.
