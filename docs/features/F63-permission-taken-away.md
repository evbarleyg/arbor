# F63: Accessibility permission taken away while Arbor runs

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done headlessly (`feat/F63-permission-lost`); the macOS-only part compiles on a Mac; the switch itself has not been tried on one yet
Depends on: F40 (stopping and starting in one process), the app shell review (#18: `start()` forgets what is transient; what is off screen at a start counts as out of view), F41 (`activeBindings`, `inputSettings`)
Size: small to medium

## Summary

People switch a window manager off in System Settings exactly when it misbehaves, which is when windows may be out of view. A reset of the privacy database, a management profile or a new build's signature do the
same without asking. Today nothing notices: shortcuts still swallow their keys, commands "succeed" and nothing moves, the menu looks normal, and the windows that are out of view are stuck there, because without the
permission **Arbor cannot move anything, not even back**. Quitting, the last of the three ways home, does not help either.

Arbor cannot prevent this. It can notice at once, stop pretending, say what is going on and what to do, and put everything right the moment the permission returns.

## Behaviour

**Noticing.** Within three seconds without anybody doing anything, and at once when a command is given:

- Arbor asks macOS every 2 s whether it still may (1 s while it may not). One "no" is not believed (the privacy daemon restarts now and then); Arbor asks again half a second later, and believes the second.
- Before every command that is not a query it asks as well, and there one "no" is enough: a command must never pretend. The same before a peek (F51), which begins without a command. Commands can come tens to the second (a held shortcut, the steps of a pinch), so within a second of a thorough "yes" only the flag is read; if the flag lags, the refused calls that follow are heard.
- The pointer taps' own watchdog (once a second, because a tap held without permission can stop all input) reports what it finds, which counts as a second opinion.
- So does a call that macOS refuses because Accessibility is disabled: not everything that moves windows is a command (a drop, a window that closes, a gap that is dragged).

**Stopping.** Nothing is moved: it could not be, and if the alarm was false nothing shows. Arbor saves the arrangement and the view, removes its own tiles, gap handles, previews and focus ring (they would
soon be wrong), stops observing, removes both pointer taps, and gives the shortcuts back to the apps. A pause in progress is over: granting the permission again means wanting Arbor, as launching it does.

**Saying so.**

- `status`, and every command that is not a query, in two sentences, the first of which is also the menu's first line: what happened, how many windows of which apps are out of view, that they come back with the permission, and where to grant it.
- The menu bar icon changes to a warning sign. The menu (state 1 in `docs/MENU.md`) has that sentence, Check Setup…, Help, and Quit, which says what quitting would leave behind: "Quit Arbor (3 windows stay out of view)".
- **If windows are out of view** Arbor also speaks up by itself, once: F10's welcome window, titled "Arbor needs its permission back", which counts them and has the button to the switch. If none is, nothing appears: whoever switched Arbor off on purpose is not nagged.
- **If windows are out of view the ways home stay registered**: Show Everything, `home`, Float All Windows and ⌃⌥⎋. They are what a person who misses a window presses. They cannot help, so they beep and open the place where the switch is, at most once in ten seconds however hard they are hammered. All other shortcuts are given back.
- `state` has `"accessibility": false`, `"running": false`, no window list and no frames, and still shows the arrangement that will come back.
- Later: a row in `doctor` (F10), the heads-up line (F43).

**Recovering.** When the permission returns Arbor starts as at launch: the saved arrangement and view are matched against the windows and displays that exist by then, and whatever is off screen is put where it belongs. **If windows
were out of view when the permission went, and it was gone for three seconds or more, Arbor then shows everything on every display** (as `home` does; Back returns to the old view): the person was promised their windows back, and after a fright they want to see them, not to be told that they are reachable again. A shorter loss is a false alarm or a slip of the finger: the view stays as it was.

**Quitting without the permission** leaves the windows where they are. The arrangement was saved, so the next launch with the permission brings them back, as after a crash.

## What a person can do without granting it

For the guide and the welcome window, not for Arbor to do: ⌘Tab to the app and choose Window → Center (macOS 15 and later; fn⌃C); or quit and reopen the app. Mission Control shows such windows but cannot fetch them.

## Design notes

- `Controller+Permission.swift` decides everything. The app provides one closure, `accessibilityProbe` (asked thoroughly, `EventTap.isPermitted()`: `AXIsProcessTrusted()`, and a tap made and thrown away, because the flag can stay true after Arbor is removed from the list; it talks to no app, so none can keep it waiting; asked in passing, the flag alone), and the controller
  asks it through the `Scheduler`, so that tests drive time.
- `PermissionWatch` (ArborCore, a value): samples in, `lost` / `returned` / nothing out.
- `shutdown(movingWindows: false)` is the stop (the same function to the line; `placeVisibly` and `putBack`, through which it moves windows, do nothing meanwhile, and `nothingIsMovedAndEveryOverlayGoes` fails if a third way is added); `start()` is the recovery. Both ends are paths that quitting, pausing and launching already exercise.
- `PermissionLoss`: how many windows were out of view and whose. `activeBindings` and `inputSettings` read it; the app registers and installs what they say on `.lifecycle`, as for a pause.
- **The first minute is the old road.** Launched without the permission, the app waits by itself (`ArborApp.waitForAccessibility`: a timer on `AXIsProcessTrusted()`, F10's welcome window) and calls `start()` when the flag turns. Until that first `start()` the controller does not
  watch: `askAboutAccessibility` and `accessibilityWasRefused` return at `isWatchingPermission`, there is no `permissionLoss`, and status, menu and Quit read as before F63.
- **The thorough way's no counts against the flag's yes only once it has said yes in this process.** Nobody has seen whether macOS lets a process make an event tap that was given the permission while it ran. If it does not, the taps stay away until the next launch, as before F63, and
  Arbor goes on arranging windows instead of announcing a loss in front of the welcome window.

## Acceptance criteria

1. Two "no" in a row stop Arbor within 3 s of simulated time; one "no" followed by "yes" changes nothing at all.
2. A command given after the permission went fails the first time, with the sentence, and moves nothing.
3. No `setFrame` is made while stopping or while stopped; every overlay is removed; drags, moves, new and closed windows cause nothing.
4. The sentence counts the windows that were out of view and names their apps, never their titles; with none out of view it says so by leaving them out.
5. With windows out of view only the ways home are held; with none, no shortcut; the taps' settings are off in both cases.
6. When the permission returns, arrangement, history and saved views are as they were; windows closed, opened and moved meanwhile are coped with; everything is in view if windows had been out of view, and the old view is one Back away; otherwise the view is as it was.
7. A pause, by hand, timed or for an app, ends with the loss and does not come back with the permission.
8. Losing it twice, losing it while it is already lost, and getting it back while running are harmless.
9. Quitting while it is lost is safe, and the next start brings the windows back.
10. (was "Manual"; board, section 5) On a hosted Mac, with a window out of view, the script takes the permission away (`tccutil reset Accessibility`) and gives it back: within three seconds the icon changes and the welcome window asks for the permission back; mouse and keyboard keep working; ⌃⌥Space beeps and opens the settings; switch it on: every window is in view.

## Shipped / Not shipped

Shipped: everything under Behaviour except what is marked "later". `PermissionWatch` (ArborCore), `Controller+Permission.swift`, about twenty lines in `ArborApp`, three in `PointerInput`, the lines, the Quit title and the
warning sign in F10's menu model (`Controller+Menu.swift`, `MenuBarModel.Icon.needsPermission`); `revoke` and `grant` in arbor-sim; scenario `63-permission-taken-away.sim`.

| Criterion | Tests (`PermissionLossTests`, `PermissionWatchTests`) |
|---|---|
| 1 | `itIsNoticedWithinThreeSecondsWithoutAnybodyDoingAnything`, `oneNoFollowedByYesChangesNothingAtAll`, `theSecondNoInARowIsBelieved` |
| 2 | `aCommandGivenAfterwardsFailsTheFirstTimeAndMovesNothing`, `theFlagAloneIsEnoughForANo`, `ifTheFlagLagsTheRefusedCallsTellTheTruthAndTheyAreBelievedThoroughly`, `commandsInQuickSuccessionAskThoroughlyOnceASecondAndOtherwiseReadTheFlag`, `theShowEverythingKeyPressedAfterwardsFailsTheFirstTimeTooInsteadOfPeeking`, `aRefusedCallIsASecondOpinionTooAndIsActedOnOnceTheCallerHasReturned` |
| 3 | `nothingIsMovedAndEveryOverlayGoes`, `whileItIsGoneArborReactsToNothing`, `aDragInProgressIsForgotten`, `aPeekInProgressEndsWithTheLoss` |
| 4 | `theSentenceCountsWindowsAndNamesAppsNeverTitles`, `withNothingOutOfViewItLeavesThemOut`, `oneWindowAndManyAppsReadWell` |
| 5 | `withWindowsOutOfViewOnlyTheWaysHomeAreHeld`, `theWaysHomeLeadToTheSettingsAtMostOnceInTenSeconds`, `withNothingOutOfViewNoShortcutIsHeld`, `everythingIsHeldAgainAfterwards` |
| 6 | `itComesBackWithinASecondWithEverythingInViewAndTheOldViewOneBackAway`, `aLossThatIsOverInAMomentLeavesTheViewAsItWas`, `withNothingOutOfViewTheViewIsAsItWas`, `itCopesWithWhatChangedMeanwhile`, `twoDisplaysBothShowEverythingAfterwards` |
| 7 | `aPauseEndsWithTheLossAndDoesNotComeBack`, `aTimedPauseDoesNotResumeIntoTheLoss`, `aPauseForAnAppEndsTooAndBeginsAgainAfterwardsIfTheAppIsStillInFront` |
| 8 | `losingItAgainAndAgainIsHarmless`, `itIsLostOnceHoweverOftenTheAnswerIsNo` |
| 9 | `quittingWithoutItIsSafeAndTheNextLaunchBringsTheWindowsBack` |
| The first minute | `launchedWithoutThePermissionThenGrantedThenRevokedThenGrantedAgain`, `ifMacOSRefusesTapsFromTheFirstMinuteArborBelievesTheFlagAndGoesOn`, `onceTheThoroughWayHasWorkedItsNoIsBelievedAgainstTheFlag`; on a Mac: the first step of `check-F63.sh` |
| 10 | `scripts/mac-shell/check-F63.sh`, only on GitHub's throwaway Macs: it switches the permission off for every app |

Not shipped:

- `AXWindowSystem` sends `accessibilityWasRefused()` from `setFrame` and `focus`; other reads that answer `.apiDisabled` say nothing.
- F43's line.
- A view moved by something that is not a command (a clicked tile, a drop) in the second or two before the loss is noticed counts as moved: the windows it would have brought into view are missing from the
  count, though not from what comes back with the permission.
- Arbor does not watch, while it may not move windows, whether the person fetched them by other means (the window server would tell without the permission): the count is the one from the moment of the loss.
- No question before quitting: the menu item says what quitting leaves behind, and a dialog in the way of Quit is what nobody wants from an app they are cross with.
