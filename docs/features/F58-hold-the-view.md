# F58: Hold the view (presenting and screen sharing)

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done (`feat/F58-hold-the-view`); the macOS-only part has not been compiled or run yet, see the end
Depends on: F01, F40. Answers IDEAS I8 and point 3 of Q7
Size: small
Rank among "what would make people recommend it": 6 (first for anyone who shares their screen daily)

## Summary

`pause` (F40) is for getting Arbor out of the way, and it brings **every** window into view. On a shared screen that is the opposite of what is wanted: the mail, the chat and the half-written review all appear in front of the audience. What a
presenter wants is for the view to **stay exactly where it is** whatever happens behind it. Today three things move the view uninvited: an app that activates itself (a calendar alert, a finished build, a chat mention) has its out-of-view
window revealed; a rule docks a new window and widens the view to show it; and a slip of ⌃⌥ or a pinch zooms out over everything. An arrangement where everything else is already out of view is a very good
presenting tool. It only has to promise not to move.

## Behaviour

- `hold` / `release` / `toggle-hold`; menu: **Hold This View**, with a tick. No default shortcut to begin it: it is chosen once per meeting, from the menu. **⌃⌥⎋ releases it**, and nothing moves; the next press pauses. So the one key that answers everywhere lets go of the hold first, and every refusal can name it.
- While held, on **every** display:
  - no **shortcut or gesture** moves the view or brings a window into view, ⌃⌥⇧F included: one slip in front of an audience must not. Every camera command, pinch, rectangle, tile click and double-click fails with "the view is held" and the way out. `pause`, `float-all` and quitting work from the menu and from `arborctl`, and end the hold;
  - a window out of view that takes the focus **stays out of view**, and focus goes straight back to the window that had it (or the top-left one in view);
  - new windows float over the view where their app puts them, as today, and rules that dock are put off. **The end of a hold moves nothing either**, whether by hand, by the clock or because a call ended: a rule that waited is applied only if it leaves the view where it is and brings nothing into view, and not to a window the user has moved; otherwise the window goes on floating, and a release by hand says so;
  - closing or minimising a window in view lays out what remains inside the held space. **A held view never widens by itself**: if nothing is left in it (minimised, hidden with ⌘H, closed) it stays held and shows the wallpaper, which exposes nothing, until the window is back or the hold is released;
  - windows in view can still be dragged, docked, floated and resized among themselves;
  - F43's messages are not shown, so nothing of Arbor's appears in the share, except the one that says why a key did nothing.
- The menu bar icon shows a lock.
- `hold <minutes>` releases by itself, as `pause <minutes>` resumes.
- Not kept across a relaunch.

## What a share of the whole screen shows of windows that are out of view

One point of each, in the bottom corner, plus whatever shadow macOS draws around it. **Check on a Mac** (I8) with four windows out of view: if the shadows add up to a visible smudge, put windows that are out of view at `maxX + 0`, `maxY - 1` (a one-point strip under the
corner rather than a corner of the window, whose shadow is the strongest part).

## Design notes

- `Controller.isHeld`; `moveCamera` is the one gate, with a parameter for the few callers allowed through. `windowFocused` returns focus with `ensureFocusIsVisible`'s rule.
- Put-off rule actions are a list of `(window, rule)` replayed on release for windows that still exist and still float.

## Acceptance criteria

1. Held on a framed window: `userFocus` of an out-of-view window moves no window and no camera, and the fake's focus is back on the framed window.
2. Every camera command, `tileActivated` and `frame-rect` fails with the message and changes nothing; `release` restores all of them.
3. A `dock` rule's window floats while held. On release, at the end of a timed hold and when a call ends it docks only if the view stays where it is and shows what it showed; otherwise it goes on floating.
4. Minimising, hiding or closing the last window of the held space moves no other window and keeps the hold.
5. ⌃⌥⎋ on a held view releases it and moves nothing; pressed again it pauses. ⌃⌥⇧F from the keyboard is refused. `pause`, `float-all` and quitting from the menu and `arborctl` work and end the hold.

(Criteria 3 to 5 were changed by the product owner on 2026-10-14 after playing the first build: as first written they let an audience see every window that was out of view.)

## Shipped / Not shipped

Shipped (2026-10-14): what is under Behaviour as the product owner changed it on review (below), and each criterion has tests in `HoldTests`:
1 `aWindowOutOfViewThatTakesTheKeyboardStaysThereAndTheKeyboardGoesBack`; 2 `everyCameraCommandFailsAndChangesNothing`, `aClickOnATileDoesNothing`, `releaseRestoresEveryCameraCommand`;
3 `aDockRulesWindowFloatsWhileHeldAndDocksOnRelease`; 4, changed, `whenTheOnlyWindowInViewClosesTheViewStaysHeldAndEmpty`; 5, changed, `pauseWorksWhileHeldAndEndsTheHold`, `floatAllWorksWhileHeldAndEndsTheHold`,
`fromTheMenuAndTheTerminalBothAreStillWaysOut`, `quittingWorksWhileHeldAndTheHoldIsNotKept`. Scenario `collab/scenarios/58-hold-the-view.sim`.

**Changed on review** (the product owner): three things showed an audience every window that was out of view, two of them as this spec asked.

- **The end of a hold moves the view no more than the hold did** (criterion 3). It can come by itself. A rule that waited is applied only if a rehearsal leaves the view where it is and showing what it shows, and not to a
  window the user has moved; otherwise the window goes on floating and `release` says so. `aRuleThatWouldMoveTheViewIsNotAppliedOnReleaseAndTheReplySaysSo` and the six tests after it.
- **A slip on a key is not a way out** (criterion 5). On a held view ⌃⌥⎋ releases and moves nothing, and pauses at the next press, not while it stays down; ⌃⌥⇧F is refused. The menu and `arborctl` keep both.
  So the hold has a key, and every refusal names it. `theKeyThatPausesReleasesAHeldViewAndMovesNothing` and the six tests after it.
- **A held view never widens by itself** (criterion 4, and "if the space becomes empty the hold ends"). Minimized, hidden and closed are treated like full screen: the display shows the wallpaper and stays held.
  `whenTheOnlyWindowInViewClosesTheViewStaysHeldAndEmpty` and the five tests after it.
- `holdStillWhileMicrophoneIsOn` ships false until two checks on a Mac (docs/TESTING.md); `com.apple.FaceTime` is no longer in `holdStillFor`.

Beyond the spec, each logged in `collab/QUESTIONS.md`:

- **`hold still`**, a second strength: Arbor moves nothing by itself, the user's own keys, gestures, ⌘Tab and Dock clicks work. For someone in calls all day a view that cannot be moved at all is
  no use between the moments when they present. It starts by itself during a call, because macOS has no public way to ask whether the screen is being shared or recorded, but does say whether some
  app has a camera or a microphone running (`holdStillWhileCameraIsOn`, `holdStillWhileMicrophoneIsOn`); a window listed in `holdStillFor` counts too.
- **"Among themselves" is enforced.** Docking at the edge of a held view, floating or dragging away the only window in it, or a window closing in a held group could each widen the view to the whole row or
  column around it and show everything (the tree cannot nest a row in a row). A fence in `relayout` and a rehearsal of drops and commands prevent it; `HoldFuzzTests` looks for what was not thought of.
- With several displays each view stays held when it empties: which display is being shared is not for Arbor to know.
- `exclude`, `include` and `reload-settings` wait for release too; URLs can neither hold nor release.
- An app that keeps taking the keyboard is sent back three times in five seconds, then keeps it, still out of view.
- Arbor's own rescues wait: a window or (on a held view) a dialog that opens off screen, beside its app's window that is out of view, is not brought to the middle of the display (follow-up, `HoldRescueTests`).

Not shipped:

- **The line at the screen edge.** "One point of each" is not what macOS does: it stops a window with its title bar above the Dock, so four windows asked to go to 1023,767 wait at 1023,673 and show a line one point wide and 84 tall
  (`collab/evidence/screens/2026-10-14-F58-line-of-windows-out-of-view.png`, eight times enlarged, cut from a picture of an earlier run). Whether zero points, or a place beyond the shadow, is accepted and
  safe is the first thing `scripts/mac-shell/check-F58.sh` measures. Parking was left alone meanwhile; other work is changing `parkingOrigin` for the same clamp.
- **F43's messages** are on another branch. Whoever lands second: while `isHeld`, show only the line for a command that failed.
- ~~Mirrored displays (`CGDisplayIsInMirrorSet`: a projector) as a sign of presenting.~~ Built as K160: `holdStillWhileMirroring` (ships off like the other signs; the first to be switched on, once somebody has mirrored a display and seen the icon fill in and empty again), `MirroringTests`, scenario `58-mirrored-to-a-projector.sim`.
- **No hold has been tried on real windows.** `check-F58.sh` has not run yet. The macOS-only code (the lock icon, the menu,
  `AXWindowSystem.secondsSinceClickOrModifierKey()`, the observer in `ArborApp`, `App/CallSensor.swift`) has been built on a Mac, with the unit tests and the general e2e run passing, and
  nobody has looked at it. Whether "Hey Siri", Voice Control or a virtual audio device keep a microphone "running" for ever is not known, nor whether a shortcut that is kept down repeats (it is guarded against either way).
