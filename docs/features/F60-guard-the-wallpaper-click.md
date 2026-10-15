# F60: A click on the Desktop does not sweep the windows away

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: in progress (`feat/F60-guard-wallpaper-click`): the headless parts are done and tested; the macOS half has not been compiled or run on a Mac yet
Depends on: the rules for event taps (board item B3), F05's `RectangleFramer` (holding and replaying a press), `PointerSurface`
Size: small to medium; the decision is headless, the tap is macOS-only
Supersedes the advice in F42, the README and the guide to change a system setting, which stays as the fallback

## Summary

Since macOS 14, "Click wallpaper to reveal desktop" is on by default: one click on the wallpaper sweeps every window to the screen edges. On an ordinary Mac the wallpaper is mostly covered. Under Arbor it is **always in reach**: the Desktop sits between the docked
windows, and every gap is wallpaper. Accessibility reports nothing when it happens, so Arbor goes on believing the windows are in their places. It will be most people's first "Arbor lost my windows" (`collab/evidence/screens/2026-10-14-review-ux-3-wallpaper-click.png`).

Asking every newcomer to find a switch in System Settings before their first click is a poor answer, and it turns out not to be the only one. **A session event tap that swallows the click stops the sweep.** Measured on macOS 26.6 by F14's check script, with its control
(`mac-shell-out/feat-F14-double-click.check-F14`, `output.txt`, "survey: one click on the wallpaper" and "experiment"): an ordinary click moves the two windows from `12 43` and `518 176` to `-482 -17` and `1012 82`; with the mouse-down, the mouse-up or both swallowed, the frames do not change.

Today three gestures start with that press and each treats it differently: F05's ⇧-drag swallows it (safe), F14's double-click lets both clicks through (the windows sweep away and back), and a plain single click, the common case, is nobody's.

## Behaviour

- While something is docked on a display, a **plain left press** (no modifiers) on **bare Desktop inside Arbor's view** of that display, that is, on the Desktop's part of the layout or in a gap, with no window, menu, panel, Dock or Desktop icon under the pointer, is **held**.
  - If the pointer then moves more than the drag threshold with the button down, the press is **replayed** and everything that follows goes to Finder untouched: its selection rectangle works as ever.
  - If the button comes up first, press and release are both **swallowed**. macOS sees no click, and nothing is swept.
- A second such click within the double-click interval is F14's double-click on the Desktop, which no longer flashes.
- Desktop icons and widgets keep their clicks, drags and double-clicks.
- With nothing docked on the display, while paused (F40), while a pass-through app is frontmost (F41) and with `guardDesktopClicks` false, Arbor takes no interest in such presses at all.
- **What is lost**: a click on the wallpaper no longer makes Finder the active app or clears its selection, while something is docked. Clicking a Finder window, the Dock or ⌘Tab still does. Nobody is likely to miss revealing the desktop under Arbor: ⌃⌥D shows the Desktop.
- Setting `guardDesktopClicks` (default true, advanced). **False since 2026-10-14**, by the coordinator's decision, until the guard has been seen at work on a Mac. The two faults below are mended.
- `doctor` (F42): with the guard on, the macOS switch is reported as fine ("Arbor keeps clicks on the Desktop from sweeping windows away"); with it off, as a problem, as now.
- The README's and the guide's "four switches" become three.

## Design notes

- One tap, one rule. Fold this, F14's Desktop double-click and F05's ⇧-press into `RectangleFramer`'s mouse-down tap, or a sibling that shares its hold-and-replay code: they ask the same question ("is this bare Desktop inside the view?") about the same event. Two taps that each hold presses would see each other's replays
  (`EventTap.replayMark`).
- The question has two halves. **Inside the view**: a lock-protected list of rectangles the controller publishes after each layout (the Desktop's frame and the gaps; empty when nothing is docked, when paused, when the view has no Desktop and no gap), as `DoubleClickTap.follow` does. This is the cheap exit, before anything else: most clicks on a Mac are
  on windows. **Bare**: `PointerSurface` over the window list, plus "not an icon or widget", for which F14 asks Finder through Accessibility. There should be one such rule (round 2 of the product owner's report found two that disagree about icons and the Dock).
- The rules for taps in `docs/ARCHITECTURE.md`, "Writing an event tap", apply: swallow in pairs, never swallow a mouse-up whose mouse-down the app saw, forget a half-followed press in `onReset`, no logging in the callback, and if the follow-up tap cannot be installed let the press through.
- The decision (`held`, `replay`, `swallow`) is a small state machine like `RectangleGesture`, in ArborCore, with unit tests.

## Acceptance criteria

1. Unit tests: press and release inside a published rectangle → both swallowed; press, move past the threshold → replay, nothing further touched; press outside every rectangle, or with a modifier, or with no rectangles published → ignored.
2. Scenario tests: the published rectangles are the Desktop and the gaps of the current layout; empty with nothing docked, while paused, and after `float-all`.
3. Real Mac (a script exists to copy from, `check-F14.sh`): with the macOS switch at its default, a click on the Desktop and a click in a gap leave every window's window-server frame unchanged; a drag on the Desktop draws Finder's selection rectangle; a click and a double-click on a Desktop icon select and open it.
4. With `guardDesktopClicks` false the click sweeps the windows, as macOS intends.
5. No click anywhere else on the Mac is delayed: measure the callback's time for a click on a window.

## Shipped / Not shipped

Shipped (headless parts tested; nothing below has been seen at work on a Mac):

- 2026-10-15 (Q26): the guard works through an event tap, so it goes with `pointerGestures`. With that off there is no guard whatever `guardDesktopClicks` says, and `doctor` and the welcome window name macOS's switch again.

- The behaviour above for a click, a drag, an icon or widget, nothing docked, a pause, a pass-through app in front (F41) and the setting.
- "Inside the view" is turned inside out, as the product owner asked: the zone is the whole view of a display with something docked, and the cheap exit is the real frame of a window Arbor knows to be in view
  (docked, floating, pinned, a guest). So the wallpaper around a docked window that cannot fill its slot is guarded too.
- One rule for "bare Desktop": F05's ⇧-drag asks the same three questions, so one that starts on an icon, beside the Dock or with nothing docked is Finder's.
- Finder is asked from a queue of its own while the button is down, never from the callback: no input waits for Finder. A click nobody answered for in time is given back.

Not shipped:

- F14's double-click on the Desktop: F14 is not on the trunk. Until it is, a double-click on bare Desktop is two clicks that reach nobody.
- `doctor` (F42) still reports the macOS switch as a problem, and the "four switches" stay four, until the guard has been seen at work on a Mac.
- Acceptance criteria 3, 4 and 5: written (`scripts/mac-shell/input-taps.sh`, session 3), not run.

Found after the merge, by the platform reviewer, reading: the guard asks what is under the pointer and never what else is waiting for the click. With a menu, Spotlight, Control Centre or a Dock stack open, a click on the wallpaper to be rid of it reaches nobody and it stays open; and an item of Arbor's own
menu that hangs over the Desktop's part of the layout cannot be clicked, because Arbor looks through its own untitled windows whatever their level. So the setting is off by default.

Mended (`fix/F60-click-away`; headless parts tested against the window list of a real Mac at rest; nothing seen at work on a Mac):

- The click is kept back only if everything on screen above the palettes is what a Mac at rest has there. Any other window, anywhere, Arbor's own menu included, gets the click given back: a list of what is harmless, because nobody has measured the levels of what is not.
- Whatever lies in front of Finder's icons (a widget, a tool that draws on the wallpaper) gets its clicks without being asked.
- While a name is being edited on the Desktop the click is given back, which ends the editing. Half an answer from Finder counts as none.
- ⇧-drag waits for Finder's answer instead of losing to it.

Still lost with the guard on: a click on the wallpaper does not close what is an ordinary window to the window server (a popover, a list of completions). (Tap to click, where the button is up before Finder has answered: mended on `fix/F60-tap-to-click`, by holding the mouse-up as well. Not seen on a Mac.)
