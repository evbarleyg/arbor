# F46: The first three minutes

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done, with F10 (`feat/F10-menu-bar`: `FirstSteps`, `OnboardingFlow`, `OnboardingModel`, `OnboardingSession`: "Three moves to try", ticked live, the three ways back with their shortcuts, Open at Login, Arbor's mark beside the words
that say where it lives; the window reopens when Arbor is opened again) and `feat/F46-first-launch`: it opens by itself at the first launch when the permission is already there (`welcomed` in `state.json`), on what there is to put right or else
on the three moves; the moves tick in any order; for the three moves the window waits at the right of the display; the footnote says what to do when a full menu bar or the notch hides the icon. Since 2026-10-15 (Q20, Q23, and four readings by an agent that knew nothing, which scored the screens 6, 6, 7 and 7.5 of 10): the first move is worded as the Mac is set ("Click a window and press ⌃⌥⌘←" while macOS's tiling has the left and right edges, "Drag a window to the left edge of the screen" otherwise, changing at once with the switch), and so is the invitation to dock a second window;
the second and third begin with "Then"; the signs on the keys are named over the moves; the first page is headed "Ready, with one suggestion", marks what is required with an arrow and what is suggested with a lightbulb, and says what Arbor is in words that need no glossary. **Four moves since 2026-10-15** (the product owner's ruling on the readers' "I never see two side by side"): dock, dock a second beside it (ticked when two are docked on one display), frame, show everything. For them the window is 420 points wide, says nothing but the moves and the ways back, explains only the next move, and waits low over the Desktop
(`OnboardingModel.restingPlace`) until somebody takes hold of it. After the last tick: a fifth move for whoever likes (a third window onto the edge of a docked one), the one step once more for whoever made the moves with the keys, where Arbor lives, Open at Login. The footnote says "Click" while the menu bar item is one icon and "Right-click" while it is a row of buttons. To a newcomer the first page is headed by what Arbor is for, over the product's one sentence (a fifth reading: three of three could not say why they would use Arbor rather than what their Mac does). **Not shipped**: the link to the shortcuts
(F43's panel is not on the trunk; one line in `OnboardingModel` when it is), finding out whether macOS is hiding the icon (needs a notched Mac to try)
Depends on: F10 (the window and the permission page), F42 (the setup page)
Size: small, for what is left

## Summary

F10's onboarding "closes itself when permission is granted". At that moment nothing on screen has changed: every window still floats, there is no Dock icon, and the only sign of Arbor is one more small
icon in the menu bar, which a notch may be hiding. The person has been asked for a frightening permission and given nothing. Then the first ⌃⌥↩ makes all their other windows vanish.
Three guided moves, on their own windows, turn both moments around.

## Behaviour

After the permission page (or at first launch if permission is already there) the window continues:

1. **Setup** (F42): only the problems, each with its button. Skipped when there are none.
2. **Try it**: three lines, each ticked live as the person does it, in any order, with whatever windows they have:
   - "Drag a window to the left edge of the screen and let go." ✔ when anything docks.
   - "Press ⌃⌥↩ to frame it. **Your other windows are out of view, not closed.**" ✔ when the view is on a single window.
   - "Press ⌃⌥Space to show everything." ✔ when the view returns to everything.
3. **If you get lost**, always visible under the three lines: "Show Everything (⌃⌥Space) · Float All Windows (⌃⌥⇧F) puts your Mac back to normal · quitting Arbor brings every window back into view."
4. **Done**: a tick box "Open Arbor at login", where the menu bar icon is (an arrow or a picture), and a link to the shortcuts (F43).

Also:

- The window floats above others, is never arranged (it is Arbor's own), moves itself out of the way of a dock on the left, and can be closed at any time. **Welcome…** in the menu reopens it.
- **Opening Arbor.app while it is running shows this window** (`applicationShouldHandleReopen`). With a hidden menu bar icon that is the only door.
- Shortcuts shown are the ones in effect.

## Design notes

- `Coach` in the controller layer: a value with three flags, fed from `Controller.observe` (`.layout`: any docked window; `.camera`: camera on a leaf; then camera on the root after that). Unit-tested with `Harness`.
- "Shown once" is a flag in `state.json` (optional key).
- Wording comes from `docs/GLOSSARY.md`, "Sentences to reuse".

## Acceptance criteria

1. The three flags follow dock, frame and show-everything in any order, from keys, drags or commands.
2. The window appears on the first launch only, and again from the menu or by reopening the app.
3. Closing it half-way never blocks anything; nothing is arranged on the person's behalf.
4. (was "Manual"; board, section 5) On a hosted Mac a tool fills the menu bar with items until Arbor's is hidden; opening Arbor.app again shows the window.
