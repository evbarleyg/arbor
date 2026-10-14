# F18: A window that floats alone takes the Desktop

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done (`feat/F18-sole-float`)
Depends on: F01. Fits together with F48 (a window's own size), F49 (pinned windows), F57 (guests)
Reference: T21 (inferred from the name of a setting; nobody has seen TrellisWM do it)

## Summary

With two windows docked and one floating, the floating one sits somewhere on the Desktop at whatever size it happened to have, with wallpaper
around it. TrellisWM has a setting, `soleFloatTakesDesktop`, on by default, whose name says that a single floating window takes the Desktop's
space. Arbor gets the same setting under the same name. While it is on, a window that floats alone looks docked but is not: it fills the
Desktop, follows it as the gaps move, and is its old self again as soon as it has company.

**Off by default in Arbor.** All that is known of TrellisWM's behaviour is the key and its default. A floating window that changes size by itself is a
surprise to someone who did not ask for it, and the promise of floating is "like any Mac window".

## Behaviour

With `soleFloatTakesDesktop` on, for each display by itself:

- **Who.** Exactly one floating window that takes up room on the display: not minimized, not hidden with its app, not on another macOS Space,
  not in macOS's full screen, not of an app Arbor does not arrange. Pinned windows (F49) do not live on the Desktop and do not count, either as
  the one or as company. Guests of a space (F57) sit on the Desktop while it is in view, so they count like any floating window.
- **When.** A docked window takes up room on that display, and the Desktop is in view and not a tile. Where none does (nothing is docked, all of it is
  minimized, or this is a macOS Space with nothing docked on it) the Desktop is the whole display and Arbor has arranged nothing: a lone window stays
  as it is, so that Float All Windows still means "back to a normal Mac".
- **What.** The window takes the Desktop's rectangle, the way a docked window takes its place. It follows the Desktop when a gap is dragged, a
  docked window comes or goes, or the view moves (framing the Desktop makes it fill the view). It goes out of view and comes back with the Desktop
  like any floating window; and like any floating window it stays where it is when a change to the arrangement squeezes the Desktop into a tile.
  It is still floating: `float` says so, `dock` docks it, dragging it works as before.
- **A new window** that opens as the only floating one takes the Desktop wherever its app opened it.
- **Its own frame** is the one its user last gave it, kept where it always was (`Workspace.floating`). It gets it back as soon as
  - a second floating window appears, is restored, unhidden or dropped on the display;
  - the setting goes off;
  - the last docked window leaves (`float-all`, closing it);
  - Arbor quits, or stops arranging its app.
  A pause leaves it as it is, like everything in view (F40); quitting during the pause gives it its frame back.
  Docking it remembers that frame, not the Desktop's, as the one to float at again (F48).
- **The user's hand wins.** Moving, resizing or dropping the window while it is alone makes that its own frame, and Arbor stops filling until the window
  has had company or has been docked. Being minimized, hidden or on another macOS Space for a while does not count as company.
  - A resize is taken as it is.
  - A drag by the title bar that ends on the Desktop gives the window its own size back under the pointer, as macOS does with a window dragged out
    of its own tiling, and F48 with one dragged out of the arrangement.
  - A docked window dragged out onto an empty Desktop, and a window dropped on another display's empty Desktop, stay where they were dropped.
    (`float` and ⌃⌥F are the way to say "take the Desktop".)
  - A few points of difference from where Arbor put it are its app rounding, not the user. Nor is a window that, with no button down, stays in its corner and only shrinks by
    up to a text cell (36 points): Terminal snapping to whole cells, late. It is then as near to filling the Desktop as its app lets it come, and is not asked again.
- **Windows that refuse.** One that cannot grow that far (Calculator, System Settings) sits in the middle of the Desktop at its largest, and is not asked
  again while the Desktop stays as it is. One that cannot shrink that far hangs over the Desktop's left or top edge, as a floating window
  already does.
- **At launch** floating windows are left where they are found at first: not every window is reported at once, and a window that grows and shrinks again as
  the others turn up would be worse than one that waits. Two seconds after the last window has turned up, the one that is alone takes the Desktop, once; other floating
  windows stay as they were found. (A pause leaves it filling, so on resume there is nothing to do.)
- **`float`** on a window that floats alone and was taken in hand makes it take the Desktop again; otherwise it says "already floating" as before.

## Design notes

- There is one memory of a window's own frame, and this feature adds none: `Workspace.floating` while it floats, F48's `undockedFrames` while it is docked.
  Filling the Desktop is a different answer to "where does this floating window go now?" in `placeFloatingWindows`, as being pushed aside by docked windows is.
  That is why most of the ways back need no code.
- `Controller+SoleFloat.swift` has all of it. The only state is which window its user has taken in hand on each display, and which is being dragged;
  neither is saved.
- Hooks, a line or so each: `floatingMoves` (who is alone: `.fill` instead of `.place`), `placeFloatingWindows` and F02's plan (what `.fill` means), `windowAppeared` and `windowChanged` (a floating window
  arriving or moving causes no layout otherwise), `dragBegan` and `finishDrop`, `windowReplaced`, `pin` and `unpin`, F48's `undock`, `start`.
- `movesInSight` (performance review) foretells docked windows only, so it has nothing to learn from this.

## Acceptance criteria

All in `SoleFloatTests` (65 tests) and `SoleFloatFuzzTests` (200 random walks); the journey is `collab/scenarios/18-alone-on-the-desktop.sim`.

1. Off (the default): no floating window is resized to the Desktop. ✔ `offByDefaultAndThenNothingIsStretched`
2. On: beside a docked window, the only floating window has exactly the Desktop's frame; it follows a moved gap and a window docked or closed beside
   it. ✔ `theOnlyFloatingWindowTakesTheDesktop`, `itFollowsTheDesktop`, `aWindowFloatedOutOfTheArrangementTakesTheDesktop`,
   `aNewWindowThatIsTheOnlyFloatingOneTakesTheDesktopWhereverItOpened`
3. Framing the Desktop fills the view; moving the view off the Desktop takes the window out of view; coming back fills again; a Desktop squeezed into a
   tile leaves it in view. ✔ `itGoesOutOfViewAndComesBackWithTheDesktop`, `itStaysInViewWhenTheDesktopIsSqueezedIntoATile`
4. A second floating window (opened, restored, unhidden, back from another macOS Space or from full screen, dropped from another display) gives the
   first its own frame back and is not moved itself; when it goes, the first fills again. ✔ `aSecondFloatingWindowGivesItItsOwnFrameBack`,
   `windowsThatTakeNoRoomAreNoCompany`, `windowsArborDoesNotArrangeAreNoCompany`, `aWindowDroppedOnAnotherDisplaysDesktopIsCompanyThereAndMissedHere`
5. Turning the setting off, `float-all`, closing the last docked window, quitting (also minimized, out of view, or during a pause) and excluding its app each give it its own
   frame back; a pause leaves it as it is. ✔ `turningTheSettingOffAndOn`, `floatAllMeansANormalMac`, `closingTheLastDockedWindowGivesItItsOwnFrameBack`,
   `quittingGivesItItsOwnFrameBack`, `quittingWhileItIsOutOfViewGivesItItsOwnFrameBack`, `quittingWhileItIsMinimizedGivesItItsOwnFrameBack`,
   `quittingDuringAPauseGivesItItsOwnFrameBack`, `excludingItsAppGivesItItsOwnFrameBack`, `aPauseLeavesItAsItIsLikeEverythingInView`;
   docked, it remembers its own frame, and floated alone it goes straight to the Desktop's size: `dockedItRemembersItsOwnFrameNotTheDesktops`, `floatedAloneItGoesStraightToTheDesktopsSize`
6. Where no docked window takes up room nothing is stretched. ✔ `withNothingDockedNothingIsStretched`,
   `onAMacOSSpaceWhereNothingDockedShowsNothingIsStretched`
7. A move or resize by the user sticks through later layouts until the window has had company or been docked; being away itself is not company; dragging
   another window changes nothing. ✔ `aResizeByTheUserSticksUntilTheWindowHasHadCompany`, `aMoveByAnotherToolCountsAsTheUsers`,
   `beingAwayItselfIsNotCompany`, `dockingItAndFloatingItAgainIsANewBeginning`, `draggingAnotherWindowDoesNotUndoTheUsersChoice`,
   `anAppRoundingItsSizeAMomentLaterIsNotTheUser`
8. A title-bar drag that ends on the Desktop ends at the window's own size with the pointer still on its title bar; one that ends on a drop target
   docks it; whatever is dropped on the Desktop stays there. ✔ `draggedOffTheDesktopItFilledItIsItsOwnSizeAgainUnderThePointer`, `draggedToADropTargetItDocks`,
   `aDockedWindowDroppedOnTheEmptyDesktopStaysWhereItWasDropped`, `aWindowDraggedWhileItHadCompanyFillsOnceItIsAlone`,
   `aLayoutDuringTheDragLeavesTheDraggedWindowAlone`, `afterADragWhoseEndNobodySawItIsItsOwnSizeWhereItWasLeft`
9. A window with a maximum size is centred and asked once; one with a minimum size larger than the Desktop stays on the display; one whose app does
   not answer is placed when it does. ✔ `aWindowThatCannotGrowThatFarSitsInTheMiddleAndIsAskedOnce`, `aWindowThatCannotShrinkThatFarStaysOnTheDisplay`,
   `aWindowOutOfViewWhoseAppDoesNotAnswerComesBackWhenItDoes`, `aWindowThatOnlyGrowsSidewaysSitsHalfwayDown`,
   `aWindowThatIsOnlyTooTallHangsOverTheTopOfTheDesktop`
10. Each display counts for itself; an unplugged display's window arrives at its own size. ✔ `eachDisplayCountsForItself`,
    `anUnpluggedDisplaysWindowArrivesAtItsOwnSize`
11. At launch nothing floating is moved at once; two seconds after the last window turned up the one that is alone takes the Desktop; a late window spares it the trip; others stay as found; a pause
    silences the wait. Old settings files load, with the setting off. ✔ `atLaunchItTakesTheDesktopOnceTheWindowsHaveTurnedUp`, `aWindowThatTurnsUpLateAtLaunchSparesItTheTrip`,
    `eachLateWindowAtLaunchStartsTheWaitAfresh`, `atLaunchOtherFloatingWindowsStayAsTheyWereFound`, `aPauseRightAfterLaunchSilencesTheWait`, `settingsFilesWithoutTheKeyLoadAndTheKeyIsWrittenAndRead`
12. Nothing is asked of a window that is already where it belongs, and F02's motion shows it going where it goes. ✔ `aLayoutThatChangesNothingAsksNothingOfIt`,
    `theMotionShowsItGoingWhereItGoes`
13. A guest (F57) takes the Desktop while that is in view and is itself again over its host. ✔ `aGuestTakesTheDesktopWhileThatIsInViewAndIsItselfAgainOverItsHost`
14. A pinned window (F49) is no company and does not take the Desktop; pinning the window that fills the Desktop gives it its own size first. ✔ `aPinnedWindowIsNoCompany`,
    `aPinnedWindowDoesNotTakeTheDesktop`
15. Another tab of a native tab group (F17) is the same window: it goes on filling, and what the user chose holds. ✔ `anotherTabOfItsNativeTabGroupIsTheSameWindow`

16. `float` says "take the Desktop again". ✔ `floatSaysTakeTheDesktopAgain`, `floatOnAFloatingWindowIsRefusedAsEverWithoutTheSetting`
17. A late snap to text cells is not the user; the same with the button down, growing, moving or more than a cell is. ✔ `aTerminalSnappingToWholeCellsLateIsNotTheUser`, `theSameChangeWithTheButtonDownIsTheUser`,
    `growingOrMovingByThatMuchIsTheUser`

## Shipped / Not shipped

Shipped: everything above, with two steps in `arbor-e2e` and `scripts/mac-shell/check-F18.sh` for real windows.

Not shipped:

- The arithmetic of `frame(ofSize:inPlaceOf:under:)` is F48's `droppedFrame` over again, for a window that is not docked. Worth one function once F09 (#49) has settled the drop.
- **Waits for F53** (#62): summoned and stashed windows must not count either; `windowAloneOnDesktop(of:)` then asks `workspace.role(of:) == nil` instead of
  `!workspace.isPinned`. Its author does that on the rebase.
- Which window its user has in hand is not saved, so after a relaunch Arbor fills again.
- Dragging the edge of a window that fills the Desktop resizes only that window. It could move the gap beside it, as a docked window's edge does (F07).
- Part of it is still to be checked on a real Mac.
