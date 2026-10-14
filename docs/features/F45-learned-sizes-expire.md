# F45: What Arbor learns about a window's size can be unlearned

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done (`feat/F45-learned-sizes-expire`)
Depends on: F01. Goes with F30 (full-screen windows), which removes the worst way to learn a wrong size
Size: small

## Summary

When a window ends up larger than the slot it was asked to fill, Arbor records that size as the window's minimum (A05), and from then on shows it as a tile in any smaller slot. The record is dropped only when the window
closes. But a refusal is not always a property of the window: an app that is busy, a sheet that is open, a sidebar that is showing, a toolbar in customise mode, a transition to full screen (F30) all make a window refuse once. One such
moment turns a window into a tile for the rest of its life, and nothing the person can do, short of closing it, brings it back.

(This number was first announced for "a docked window that goes full screen". F30, written at the same time by another review, covers that fully, so this spec keeps only what F30 leaves open.)

## Behaviour

**Ask again where nobody can see.** A window that is a tile is out of view anyway. So before a layout turns a window into a tile because of a recorded minimum, and at most once every ten minutes per window, Arbor asks the window, **where it
is parked**, to take the size of the slot it would get. If it does, the record was wrong: forget it and give the window its slot. If it refuses, the record stands (with the size just seen) and the window stays a tile. Nothing on
screen flickers either way, which is what rules out the simpler plan of forgetting the record and trying in place: a window that really cannot shrink would flash over its neighbours each time.

The record is also forgotten outright:

- when the **user resizes** the window by hand to something smaller than the record (proof that the record is wrong);
- on **`relayout`**, which people run because something looks wrong, and where a visible retry is expected.

## Design notes

- `minimumSizes: [WindowID: CGSize]` becomes a small struct with the size and when it was last confirmed (`now()`).
- The question is one `setFrame` at the parking origin with the slot's size, in `relayout` before the second layout pass; a window that is a tile but not yet parked (it has just refused) was asked a moment ago and is not asked again.
- `misfits` (added with the product review for windows that cannot grow) is cleared for the window at the same moments.

## Acceptance criteria

1. A fake window refuses to shrink once, then allows it: at the first layout ten minutes later, and at once on `relayout`, it is a window in its slot again, not a tile.
2. A window that always refuses is asked at most once per ten minutes, only while out of view, and no frame it is given overlaps a display by more than the parking point; no other window moves.
3. A user resize below the recorded size clears the record.

## Shipped / Not shipped

Two of the three ways out of a wrong record came with the controller review (#17): a window **seen smaller** than its record lowers it, whoever resized it (`lowerDisprovedMinimum`; three times at most for an app that bounces), and
**`relayout`** forgets every record (`forgetLearnedMinimums`). This item adds the third, **asking again where nobody can see** (`Controller+LearnedSizes.swift`), and tests all three against the criteria:

1. `aWindowThatRefusedOnceIsAWindowAgainAtTheFirstLayoutTenMinutesLater`, `relayoutAsksAtOnce`, `itComesBackWithoutShowingAnywhereButInItsSlot`, `anyLayoutWillDo`.
2. `aWindowThatAlwaysRefusesIsAskedAtMostOnceInTenMinutesAndOnlyOutOfView` (fifty minutes, a layout every ten seconds: five questions, one move each, one square point in view, nothing else moves), and three tests for the corner
   to the left of a display, where a window that stays wider than asked would otherwise reach into view.
3. `aResizeByHandBelowWhatWasLearnedUnlearnsIt`.

Also shipped:

- The interval is the setting `tileRetryMinutes` (10; 0 or less never asks). It is what lets a script on a real Mac try this in seconds.
- No timer: time alone moves nothing. The question rides on a layout that happens anyway.
- Nobody is asked during a drag or an edge resize (a tile that turns into a window would change the drop targets under the pointer), while paused, minimized, hidden, on another macOS Space or in full screen, or when its
  slot is simply too small to use.
- A refusal leaves the size just seen on record, which can be lower than before, so a slot that grows a little may do without another question (`aRefusalLeavesTheSizeJustSeenOnRecord`).
- A window that takes the size out of view and refuses it in its slot is a tile again within the same layout: `relayout` lays out up to three times instead of two (`aWindowThatRelentsOutOfViewAndRefusesInItsSlotIsATileAgainAtOnce`).
- A window that comes in steps (Terminal's character cells) and takes the step above the slot's size is asked for less in its corner, as it is in its slot (`askForLess`, from the compatibility lab), so a cell too large is not
  taken for a refusal (`aWindowThatComesInStepsIsNotTakenToRefuseByACell`).
- arbor-sim: `min <id> <WxH>` and `wait <seconds>`; `collab/scenarios/45-a-tile-gets-another-chance.sim`.

Different from the design notes:

- `minimumSizes` keeps its type. When each record last held is in a dictionary beside it, `confirmedSizes`, which follows `minimumSizes` at every layout, whoever wrote to it (three places do by now, and more branches are open).
- The question comes after the first pass has been applied, as the notes say, so a window whose slot has just shrunk below an old record is parked and asked in the same layout. If the record was wrong it goes to its corner and comes
  straight back; if that shows on a real Mac, ask such a window to shrink where it is instead (it cannot overlap more than it already does).
  **Done since (K204, K427)**: `askBeforeTheyLeave` runs before the first pass is applied. A window that is in view and would be a tile because of a record older than `tileRetryMinutes` is asked, where it is, for the size of the slot
  (never for more than it has in either direction). If it takes it, it goes from there into its slot and is never out of view. If it refuses, the record is confirmed, so it is not asked again in its corner. A fresh record is believed as before.

Not shipped:

- `misfits` (windows that cannot grow) has no clock. It needs none: an entry holds only while both the slot and the window's frame stay as they were, and `relayout` clears it. It is cleared for a window whose record is forgotten.
- Records are not saved: a relaunch starts with none, as before.

Follow-up (the bug bash on the first candidate): **a floating window is asked for less too before anything is learned from it.** Squeezed onto the Desktop, a Terminal takes the character cell nearest to what it is asked for, which can be the larger one; `placeFloatingWindows`, and `fill` for a window
alone on the Desktop, read three points over as a refusal and learned 861 points as the minimum of a window that goes down to 177. Docked next, room was made for it (F61): browser 574, Desktop 245, Terminal 861 instead of thirds, and nothing but Float All Windows mended it. Both call `askForLess` now, as `apply` does
(`SizeStepTests.aFloatingTerminalSqueezedOntoTheDesktopTeachesNoMinimum`, `aTerminalThatFillsTheDesktopTeachesNoMinimumEither`; a real minimum is still learned: `aFloatingWindowWithARealMinimumStillTeachesIt`).
