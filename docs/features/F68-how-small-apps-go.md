# F68: Arbor knows how small apps go

Written by an executor, 2026-10-15, from the product owner's decision (`collab/QUESTIONS.md`, "how small apps go"; board 1.32); for the documenter to review.

Status: the store is done headlessly (`feat/arbor-knows-how-small-apps-go`), never run on a Mac; the shipped table is the second step
Depends on: F45 (what is learned about a window can be unlearned), F61 (room before tiles), "a refused size costs nobody a second move" (`Controller+AskFirst.swift`: a stranger is asked where it stands, then moved once)
Size: small

## Summary

Only asking tells how small a window goes, and the answer shows. A window Arbor has never seen at its smallest is a stranger: its slot is worked out as if it took any size, it refuses, and by then it has been moved once. It
moves again, and so do the neighbours that now make room. Two strangers that cannot both fit cost one of them a width that goes there and back. Every run of Arbor begins with nothing but strangers, so every
morning pays for what was found out the day before (rule 3: a window moves once, to where it ends up).

So Arbor remembers. What a docked window of an app answered is kept for the next window of that app, in this run and the next, and a layout is worked out on paper before anything moves.

## Behaviour

**What is kept.** For each app, by bundle id: the width and the height its docked windows would not go below (either can be unknown), the major version of macOS, and a date. No titles, no paths, nothing about what is
in a window. It lies in `state.json` under `appSizes`; files without it load as before, and an entry that cannot be read or believed costs only itself.

**What it is used for.** The **frames of docked windows** are worked out with what is known of their apps, wherever a window has not answered for itself: layouts, room before tiles, the preview of a drop, and where automatic docking tries (it tries a place and takes it
back, so it has to reckon as the layout does). Nothing is copied: what is foreseen of a window is looked up when it is wanted, so that it holds for a window that was open before its app was met, and ends when the entry does. Nothing is moved on its account: while nothing is docked,
nothing moves.

**It is foresight, never the truth.** What a window answered itself is kept apart from what is foreseen of it, and everything else goes by the answers alone: where floating windows are put, a gap or an edge in the
person's hand, how far `shrink` goes, whatever **chooses**: which arrangement a dock by key or `layout` makes, which view a switch to a window takes, whether `rotate` may go ahead (a refusal comes before any layout, so that nobody would ever be asked); and what a trace says the windows
refused. And **no plan stands on foresight unasked**:

- **A window whose slot is just what is foreseen of it** (not one that happens to be a point or two larger) **is asked for a step (40 points) less**, where it stands, about what is foreseen and nothing else, when the strangers in the plan have answered and before anybody is moved. If the foresight is right it stops at the size that was planned, and goes to its place from there: one road (`Roads.swift`), which is how any window is moved on a Mac (size, position, size),
  and from then on it has answered for itself. If it gives way the store is put right at once, what was borrowed for it goes back, it is a stranger again, and the plan is made anew; nobody has been moved for the old one. A window that is in its place already is asked all the same: if the foresight is right, nothing shows.
  **A question moves nobody, and makes nobody larger.** The next answer may overturn the plan, and where in its slot a window belongs (in the middle, if it cannot be as large) is for `place` to say, which knows more. It asks for less than the window has, so no edge of the screen is in the way of the answer. (One window is moved by it: one that its person has left lower than macOS lets anybody put a window would not stay where it stands, and is asked at the corner of its slot, at the size it has.)
  **What the product owner holds it to:** (a) it is put only inside an act a person asked for (a command, a drop, a move of the view, which a start is too), and only to windows for which that act must make room; what a timer, a putting-back or another window's coming and going lays out goes by the paper, and whoever has its room on that is asked at the next thing its person asks for; (b) it never makes a window larger, on either side; (c) it is put once, not once for every stranger that refuses in the same act. `theQuestionInSightIsPutOnlyInsideAnActAPersonAskedFor`, `noQuestionMakesAWindowLarger`, `inOneActAWindowIsAskedOnceHoweverManyStrangersRefuse`.
  **The strangers come first**, also in the order in which `askingFirst` asks: whoever shrinks for a plan that a stranger then overturns may have to grow again, where it stands, which a Mac cuts short at the edges of the screen. (Until the walks said otherwise it was put at the corner of the slot, which saved a request when everything was right, and cost a second move whenever a stranger refused afterwards or the window could not fill its slot.)
- **A window that would be a tile because of what is foreseen is asked in its corner**, where nobody sees, for a step less, and has the size it had back there and then. Whatever `tileRetryMinutes` says, and in a hold: nobody is asked *again* here. Not during a
  drag or an edge resize; the layout that ends it asks. If the foresight was wrong the window goes out and comes back, once. **A tile that is in view all the same** (a start lets the window with the keyboard be where it stands) is not asked: let be means that no frame is set (the product owner's ruling), so of that window the paper is believed, as of a lender. A launch is then planned on paper, as a resume is. At the first thing its person asks for it is a window like any other, goes to its corner, and is asked there.
- **So is every docked window that the view leaves while somebody is a tile in it**: one of them may have been believed to have nothing to spare (below). Where nobody is a tile, whoever the view leaves is not asked: a question is a round trip to an app, and squeezes
  its window for a moment.
- **An app that does not answer** cannot be asked, and what cannot be asked about is not gone by until it answers: nobody gives room for it. When it does it is offered its share, like a stranger.
- A window that has been **offered less than is foreseen**, as happens under the hand, has been asked, whatever it made of it.

So what is too high in the store is put right the first time a window is given room for it or refused a place for it. With the one exception that follows it does not outlive a restart, as nothing did when nothing was kept.

**What is left: a lender** (decided by the product owner, 2026-10-15). A window in view, in a slot *larger* than what is foreseen of it, that would have to give room for a neighbour to fit, cannot be asked for nothing: in sight it would go there and back whenever the
store is right, which is the fault this item is about. **The paper is believed.** If the store is too high about it, the neighbour is a tile, also after a restart, until the lender next goes out of view (which is what clicking the tile does: it is asked in its corner, and Back fits both), a hand
moves the gap, `relayout`, a docked window of that app is seen smaller, or thirty days have passed. A follow-up may ask it beneath the stage, where there is one.

**What changes it.** Only docked windows count, both ways: it is docked windows that are planned with it, and what floats beside an app's main window is often another kind of window.

- What a docked window **stopped at** when it was asked for less replaces what is known of its app in that direction, larger or smaller.
- A docked window **seen smaller** than what is known, or a window whose own record is brought down because it was seen smaller (F45), makes that direction **unknown** again. Not "as small as it was seen": nobody stood by that size, and the next
  smaller slot would disprove it again. A window that is smaller already than what is foreseen of it is not held to it.
- **`relayout`** forgets it, with every other record, for the apps that have a window open.
- **The date** is when all that is known of the app was last stood by: there is one date for two numbers, and it is the older one's. Merely foreseeing renews nothing. **Thirty days** after it, or on **another major version of macOS**, the entry is no
  longer gone by, and leaves the file at the next layout. With the size known and room to spare no window is asked, so this is also how often the truth is looked at again.
- At most 200 apps are kept; the oldest go first.

**Where it errs it errs low.** Too low costs what not knowing costs: the window refuses, and is believed.

## How it is proven

- **Linux:** pairs of apps that cannot both fit, side by side and one above the other, met on an earlier day, docked without a stage (as with Reduce Motion): no docked window is seen to go out of its way. The same for a second window of an app met today. With a store
  that is right, too high and too low, about each of three apps in turn: the layout ends as in a home that knows nothing. Forty-two mutants of it: forty killed by a test, one that changes nothing but a redundant call, one (automatic docking's plan) for which no script could be found in which it shows. The nets over ordinary walks, before and after, from an empty home and from one that has
  met the apps (`ARBOR_CHAOS_MET_BEFORE=1`).
- **A hosted Mac:** `scripts/mac-shell/check-F68.sh` (Reduce Motion on, so that every move shows): two test apps with bundle ids of their own over one home, five days: nothing known, what is kept right, too high, the day after that, too low; then Notes and Terminal, two days. Every frame asked for and taken comes back, command by command, with how long each answer took. Rehearsed on Linux (19 of 19; a rehearsal has no real apps). What only a Mac can tell: that a real window asked for less than it goes stays as it is, at once, in one answer.
- **Agents judge:** `jolt` in that run's frames.

## Acceptance criteria

1. Two apps that cannot both fit, each met before (together or alone, in this run or an earlier one): docked one after the other, no docked window is seen to go out of its way (`Roads.swift`: one change of place at most, each edge and each side one way only), and a window whose slot is
   just what is foreseen of it changes place once.
2. What is written holds the bundle id, two numbers, the version of macOS and a date, and nothing else.
3. A window that is given room, or refused a place, because of what is foreseen has been asked by the end of that layout: where the store was too high the layout ends as it does in a home that knows nothing. Also with `tileRetryMinutes` 0, in a hold, at the next start, and
   with the window in its place already. (Not a lender: above.)
4. Merely foreseeing renews nothing, nor does a size that was only seen: what nobody stood by for thirty days is gone, from the file too.
5. While nothing is docked, nothing moves because something is known.
6. Files from before load; a damaged entry costs only itself, and is no loss to tell a person of.
7. Floating windows, a gap in the hand, `shrink` and whatever chooses an arrangement or a view, or judges whether a command may go ahead, go by what windows answered themselves.
8. Where the store is wrong about one window, its neighbours still go straight to where they end up.
9. What is shown is what a layout made now would say, also while an app hangs; and a trace needs nothing but itself: it says what was known of its apps, also of one whose first window comes while it is recorded, and who had been asked.

## Shipped / Not shipped

**Shipped, the first step: the store.** `ArborCore/AppSizes.swift` (the pure type: what is kept, what changes it, the file), `Controller+KnownSizes.swift` (foreseeing, asking, remembering), five lines in `relayout`, and `plannedSizes` in place of `minimumSizes` in
`layout(of:)` (where it is about the view as it is), `roomyLayout`, `previewFrame` and automatic docking's plan. `apply`, `place`, `movesInSight` and `Controller+AskFirst.swift` are untouched: in `relayout` this asks first, then `askingFirst` asks the strangers. By criterion:

1. `theNextDayEachOfAPairThatCannotBothFitMovesOnce` (six pairs), `soIsAPairOfWhichEachWasMetAlone`, `aSecondWindowOfAnAppMetTodayIsNoStranger`, `inAColumnEachOfAPairThatCannotBothFitMovesOnceToo`, `aWindowWhoseRoomIsForeseenIsAskedForAStepLessWhereItStands`, and two that the walks found: `aWindowThatCannotFillItsSlotGoesWhereItGoesInAHomeThatKnowsNothing`, `nobodyIsPutIntoAPlaceThatTheNextAnswerTakesAway`, and four that readers found: `whoeverIsForeseenIsAskedWhenTheStrangersHaveAnswered`, `askedInACornerToTheLeftItStaysWithinReach`, `noQuestionMakesAWindowLarger`, `aWindowThatGoesALittleLessSmallThanForeseenIsPlannedFor`; where windows dock by themselves, `aNewcomerThatIsForeseenNotToFitIsLeftWhereItsAppPutIt`; and two that the gate found, on tests that had come to the trunk meanwhile: `whoeverGivesWayFillsItsSlotAllTheSame`, `ofTheWindowThatIsLetBeThePaperIsBelievedUntilItsPersonAsksForSomething`, `letBeAtMoreThanIsForeseenItIsNotMadeSmallerInSight`.
2. `nothingIsWrittenButTheAppTwoNumbersTheVersionAndADate`; `aTraceSaysWhatWasKnownOfTheAppsInItAndOfNoOther`.
3. `whatIsTooHighCostsNoNeighbourItsPlace`, `whoeverTheStoreIsWrongAboutThingsEndAsIfNothingWereKnown` (each of three, `tileRetryMinutes` 10 and 0), `aHeightThatIsTooHighCostsNobodyItsPlaceEither`, `whereTheStoreIsWrongAboutTwoBothAreAskedInTheSameLayout`,
   `inAHoldTooNobodyIsATileOnForesightAlone`, `aWindowThatIsInItsPlaceAlreadyIsAskedAllTheSame`, `aWindowThatWouldBeATileOnForesightIsAskedInItsCorner`, `whatCannotBeAskedAboutIsNotGoneBy`; the lender: `aLenderIsBelievedUntilItNextGoesOutOfView`.
4. `merelyForeseeingRenewsNothing`, `aDockedWindowMadeSmallerByHandDisprovesAndRenewsNothing`, `theDateIsRenewedOnlyWhenAllThatIsKnownHasBeenStoodBy`, `afterThirtyDaysByWhichNobodyStoodItIsGone`, `inALongRunWhatIsTooOldLeavesTheFileToo`.
5. `whileNothingIsDockedNothingMovesBecauseSomethingIsKnown`.
6. `filesFromBeforeLoad`, `whatCannotBeReadCostsNoArrangementAndIsNoLoss`, `anEntryThatCannotBeBelievedCostsOnlyItself`; the launch fuzzer has the key in a base state.
7. `aFloatingWindowIsPlacedByWhatItAnsweredItselfOnly`, `whatFloatsTeachesNothing`, `underTheHandNothingIsForeseen`, `theKeyThatShrinksIsNotStoppedByWhatIsOnlyForeseen`, `whateverChoosesAnArrangementGoesByAnswersAlone`,
   `theViewIsNotChosenByWhatIsOnlyForeseen`, `aCommandIsNotRefusedBecauseOfWhatIsOnlyForeseen`; `automaticDockingDoesNotTryWhatTheLayoutWillNotGive`.
8. `whenTheForesightIsWrongTheNeighboursStillMoveOnce`.
9. `whileAnAppHangsWhatIsShownIsWhatALayoutMadeNowWouldSay`, `aTraceSaysWhoHasBeenAsked`, `aReplayForeseesAnAppWhoseFirstWindowCameDuringTheRecording` (free and strict), `whatIsKnownOfSuchAnAppIsToldOnceAndOfNoOtherApp`, `theNextRecordingIsToldAfresh`, `aSpaceNamedLikeTheAppCostsTheReplayNothing`.

The lab's known failure of this row, `sized-there-and-back`: from an empty home two of its three scripts still break the rule, so the entry stays until the table is there and the stand-ins have real bundle ids; in a home that has met the apps every rule holds in all three.

Also shipped: with `ARBOR_DEBUG=1` the log says who was foreseen, who was asked and what they did (window ids, bundle ids, sizes). `ARBOR_CHAOS_MET_BEFORE=1` starts the lab's walks in a home that has met their apps.

Three designs went before this one. The first wrote what is foreseen into `minimumSizes`: an entry that was too high then outlived restarts and cost a neighbour its place at every launch, and leaked into everything that reads that
dictionary. The second asked for "the share the window would have had", worked out by a copy of `roomyLayout`, inside `apply`: neighbours moved into plans that were overturned a moment later. The third copied what was foreseen for each window at first sight: the copy outlived the entry it came
from, windows that were open before their app was met stayed strangers, and views were chosen and commands refused on sizes nobody had asked about.

Not shipped:

- **The table** of what hosted Macs measured: the second step. Until then a first day meets nothing but strangers, as before.
- **How large apps go**: not needed any more. Since "a refused size costs nobody a second move" where a window stops growing is learnt at the first question, where it stands, with no wrong place; keeping it for its app would save one request.
- **The lender beneath the stage**: ask only, never wait, and believe the paper if the answer is late. Its proof is a film from a hosted Mac.
- A question in the later rounds of one layout. A window that comes to rest on what is foreseen only after a stranger has refused in the same layout is asked at the next one. No script could be found in which that shows.
- With `reflowWhileDragging` on, the trial layouts of a drag go by answers alone, as before, while the preview of the drop is worked out with what is foreseen: the hole that opens can be narrower than the preview.
- The entry of an app that is excluded afterwards stays until it is thirty days old.
- An older Arbor that reads the file says that `appSizes` is not read by it, keeps a copy, and saves without it, as with every key that is new to it.
- **Where the store is too high and less than a step of room was made for it**, the window that gives way is up to 40 points smaller on the way than it ends up, once; then the store is right. To ask for no less than the share it would have by answers alone takes a plan made for the asking, and making a plan writes to the arrangement.
- **Where the store is too high, a stranger beside the window pays once too.** The strangers are asked first, for a plan that rests on what is kept; the question then overturns it, and the stranger, which had shrunk where it stood for the narrower slot, ends up wider: narrower on the way than it ends, by as much as the store was too high (480 → 276 → 325 in the rehearsal of `check-F68.sh`). It changes place once, and it is paid once an app, not once a day: the entry is put right in that very act. Asked the other way round, a window about which the store is *right* pays whenever a stranger refuses, which is every first meeting.
- **Never run on a Mac.** What only a Mac can tell is above, under "How it is proven".
