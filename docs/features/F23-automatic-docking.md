# F23: Automatic docking (new windows join the arrangement)

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done (headless: unit tests, scenario tests, arbor-sim; real windows pending, see Not shipped)
Depends on: F01, F11 (and its follow-ups: late titles, `change(settings:)`). Fits in with F04 (tabs), F57 (new windows while framed), F58 (hold the view), F19 (undo)
Reference items: T16, T18, T19 (inferred; Q13 asks what TrellisWM really does). F31 is a pointer to this spec
Size: medium, headless

## Summary

People who come from yabai, AeroSpace, Amethyst, bspwm or i3 expect a new window to take a place in the arrangement without being asked.
In Arbor every new window floats unless a rule names its app's exact bundle id. This adds one switch, off by default:
with it on, a new window docks beside the window the person was working in, and nothing else about Arbor changes.

The hard part is not docking. It is **not docking**: the colour picker, the "About" box, the window that cannot shrink, the window that opens
during a screen share, the twelve windows found on another macOS Space. Most of this spec is about those.

## One mechanism

There is one way to say what happens to new windows: the rules of F11. This feature adds to them

- the action **`dock auto`**: dock the window where Arbor finds room for it (below);
- the app **`*`**: any app. A `*` at the end of a bundle id stands for the rest of it: `com.jetbrains.*`.

The setting **`newWindows`** is `"float"` (default, today's behaviour) or `"dock"`. `"dock"` means exactly: *the list of rules ends with*
`{ "app": "*", "action": "dock auto" }`. So rules win because they come first, late titles (`ruleTitleWait`) can still take a window back
out, F58 puts it off like any rule that docks, and undo sees it as it sees any rule. `arborctl rules` shows the implied rule as the last line.
Any other value means `"float"`, and `rules` says so.

## Which windows

A rule that chooses for itself must be careful. **`dock auto`, and every rule for a `*` app that docks,** passes over a window (the next rule is tried; with none left
it floats) when

- it opened smaller than `autoDockMinimumWidth` × `autoDockMinimumHeight` (400 × 300) in either direction: inspectors, palettes, Get Info, small dialogs;
- its size cannot be changed (`WindowSnapshot.isResizable`, from `AXUIElementIsAttributeSettable(kAXSizeAttribute)`): Calculator, most settings windows, "About" boxes.

The size that counts is the one the window **opened** with, also when a late title brings a rule into play after the window was moved.
A rule that names an app in full and an edge (`"com.apple.calculator"`, `dock right`) was written for that app and is obeyed as before.

Never docked by any rule, as before: windows found at launch, after `resume`, or when their app is included again. New here: windows that were open all along and come to Arbor's notice because their
**macOS Space** is shown for the first time (`windowFound`, below). Only `arrange` docks those.

## Where (`dock auto`)

On the display the window opened on, in this order:

1. **Nothing is docked by itself** while the mouse button is down (a window is being dragged or resized, or the new window is itself in the user's hand: a tab torn off a browser), while the view is held (F58), or if the window takes
   no room (minimised, full screen, another macOS Space). It floats.
   Nor where somebody has said what is to happen: a window `summon` (F53) opened its app for comes over the view, which a docked window cannot; while `layout --open` (F54) waits for its windows on that display, others float, because the
   wait ends when the arrangement is no longer the one that was written; and a window that opens over a window in full screen (a draft over the mail app) floats, because the arrangement is on a macOS Space that does not show.
2. **The view is on one window or tab group**: F57 decides (guest, later tab). **The view is on the Desktop alone** while windows are docked elsewhere: it floats; the Desktop is where floating windows live.
3. **Beside the focused window.** The window that most recently had the keyboard among the docked windows *showing in the view* of that display. (By the time Arbor hears of a new window it already has the keyboard, so "focused" means
   "focused until a moment ago".) Its slot is split in two along its **longer side**, the new window after it: to the right of a wide slot, below a tall one, as bspwm and yabai do. If that leaves no room (below), the other
   direction is tried.
4. **No such window** (nothing docked, nothing in view has had the keyboard): the **right edge of the view**, or its bottom edge if the right edge has no room. (Since F62 docking at the view's edge joins the view; before, the right edge of a column could widen the view, and such a placement is still never made.)
   The very first window, with nothing docked and nothing floating in sight, leaves the Desktop what Arrange Windows would (`arrangeDesktopWeight`: half a window's share, so a third of the display): whoever ticks this wants windows to
   fill the display. With a window on it the Desktop keeps half, as after `dock right`.
5. **No room beside the focused window**: with tabs on (`tabsEnabled`, F04) it joins the focused window as a tab, selected. Otherwise the **largest window in view** shares its slot in the same way.
6. **No room there either**: it floats where its app put it.

In a burst (a browser restoring five windows) focus reports lag behind. For one second a window docked this way counts as the focused one for the next, so a burst spirals inward like windows opened one by one,
instead of halving the same slot five times.

**The view never moves.** The window lands inside the space the view is on. A placement that would bring anything else into view is not made.

## Room

"Room" means: after docking, **everything that was showing still shows, and so does the new window**. No window, group or the Desktop turns into a tile because a window opened.

- What is known is tried on a copy first (`minimumUsableWidth` × `minimumUsableHeight`, and the minimum sizes learned so far).
- A new window's own minimum is not known. So it is **offered its slot before anyone makes room**: Arbor resizes the new window alone. If it refuses (Safari will not go below 574 points wide, Notes 709, System
  Settings is 723 wide and nothing else), its size is learned and the next placement is worked out with it. The neighbours have not moved.
  A window that comes out a little too large is first asked for less (`askForLess`): a terminal takes the whole character cells nearest to what it is asked for, and that is not a refusal.
- A neighbour's minimum may not be known either. If, once docked, a neighbour refuses its half and something became a tile, the docking is **taken back** at once, what was learned stays, and the next placement is worked out.
- A window that ends up floating is put back exactly where its app opened it.
- **With F61 (room before tiles, `makeRoom`, on by default)** the layout after a docking moves gaps before it makes a tile, so the plan rehearses that too: a Notes that stops at 709 points gets them from its neighbour and still lands to its right. On
  F61's terms an **empty** Desktop may give until it is a tile; with a window floating on it, it stays usable, and a window there is then no room for floats.

At most seven rounds; each but the last learns a width or a height of the new window, the focused one or the largest one.

## Switching it

- `toggle-auto-dock`: flips `newWindows` between `"dock"` and `"float"`, and saves that one key to `settings.json` (`change(settings:)`). Replies "new windows dock beside the focused window" / "new windows float".
  Windows that are already open stay as they are, both ways.
- Menu: **Dock New Windows**, with a tick.
- ⌃⌥⇧A stays reserved and unbound (`docs/KEYBOARD.md`).
- Not accepted from `arbor://` URLs: it changes a setting.

## Afterwards

- One undo step per window docked: F19 (`feat/I3-undo-names-presets`) wraps `dockNewWindow`, which this goes through. A docking that was taken back leaves a step that changes nothing, which F19's `undo` skips; wrapping
  `dockAutomatically` as well when F19 lands leaves none.
- When the window closes, its room goes back as it does for any docked window.
- It is not focused by Arbor. Its app does that.

## Design notes

- `ArborCore/AutoDock.swift`, pure: `accepts(size:isResizable:minimum:)`, `plan(…)` (the candidates in order, each rehearsed on a copy of the workspace) and `keepsEverythingShowing(before:after:…)`.
- `AppRule`: `covers(bundleID:)` for `*`; `isCautious`; `RuleAction.dockAuto`. `Settings.newWindowRules` is `rules` plus the implied rule; `Controller+Rules.swift` matches against that.
- `Controller+AutoDock.swift`: the rounds of offer, dock, check, take back; the burst; `toggle-auto-dock`.
- Seam: `WindowSnapshot.isResizable` (default true). `WindowSystemEvents.windowFound(_:)`, for a window that was open before Arbor saw it; `AXWindowSystem` sends it for what a scan after a Space switch turns up. A saved slot that waits for it (F35) is still claimed; otherwise the controller adopts
  it as it adopts windows at launch (of the rules, only `ignore` applies).

## Acceptance criteria

1. Default settings: a new window floats, as today. An old `settings.json` loads; an unknown `newWindows` value means float.
2. `newWindows: "dock"`: a new window docks beside the focused docked window, right of a wide slot and below a tall one, taking half of it; nothing else moves.
3. With nothing docked it docks at the right edge of the view.
4. `{ "app": "*", "action": "dock auto" }` with `newWindows: "float"` does the same as criterion 2. A rule above it wins; `com.example.*` matches by prefix.
5. A window that opens smaller than 400 × 300, or that cannot be resized, floats. A rule naming its app in full still docks it.
6. No room beside the focused window: the largest window in view shares instead. No room anywhere: it floats where it opened, and nothing has become a tile. With `tabsEnabled` it joins the focused window as the selected tab.
7. A new window that refuses its slot: the neighbours are never moved for the failed attempt; the other direction is tried; otherwise it is back at its opening frame, floating.
8. A neighbour that refuses its half: the docking is taken back; every window that was showing is back in its slot.
9. The view on a group: the window docks inside that group and the view stays. The view on one window: it floats as F57's guest. On the Desktop alone: it floats. The view stays.
10. Two displays: a window docks on the display it opened on, beside that display's most recently focused window.
11. Five windows at once, with or without focus reports in between: as many dock as there is room for, each beside the one before; the rest float; nothing is a tile; invariants hold.
12. Windows found at launch, after `resume` and by `windowFound` float. While paused nothing happens at all.
13. A splash window that is replaced by the app's main window: the main window ends up where the splash was, whichever of "close" and "open" comes first.
14. A late title that matches a `float` rule takes the window back out, as F11's follow-up does for any rule that docked: it floats, and the frame it opened with is the one it goes back to.
15. `toggle-auto-dock` flips the setting, writes only `newWindows` to the file, moves no window, and is refused from a URL.
16. Nothing docks while a window is being dragged, or while the mouse button is down at all.
17. Closing the window gives its room back.
18. A window that was summoned floats and is summoned; a rule that names its app still docks it. While `layout --open` waits, a stranger floats and the awaited windows get their slots. A window that opens over one in full screen floats where it opened.

## Shipped

- `ArborCore/AutoDock.swift` (the guards, the plan, "everything still shows"), `AppRule` (`*`, `covers`, `isCautious`, the action `dock auto`), `Settings` (`newWindows`, `autoDockMinimumWidth`, `autoDockMinimumHeight`,
  `newWindowRules`), `Command.toggleAutoDock`.
- `Controller+AutoDock.swift` (offer, dock, check, take back; the burst; `windowFound`; the switch; the report's lines). `Controller+Rules.swift` matches against `settings.newWindowRules`, by the size a window opened with.
- Bug bash 1 (frozen trunk, 2026-10-14), criterion 18: F53, F54 and full screen are asked before anything docks.
  And with F61: a Desktop that became a tile while it was empty is owed room once a window floats on it, and the next layout pays it with a docked window's place. The plan now compares with what shows now, not with what that layout
  would show, so a new window floats rather than set it off; and a docking that is taken back leaves the debt standing. (Whether a small panel should cost a docked window its place at all is F61's question, and is with triage.)
  F58, F12 and the chaos harness landed meanwhile: `holdPutsOff` lists `.dockAuto`, the three keys have their `SettingsSchema` entries, and random walks flip the switch.
- F57, which landed meanwhile: a window `dock auto` leaves floating over a framed window becomes its guest, like a window no rule claimed.
- Seam: `WindowSnapshot.isResizable` (default true), filled once per window from `AXUIElementIsAttributeSettable(kAXSizeAttribute)`; `WindowSystemEvents.windowFound` (a listener that does not implement it gets `windowAppeared`), sent by
  `AXWindowSystem` for what a scan after a Space switch turns up. `FakeWindowSystem.open(… isResizable:)`, and `setListed(_, true)` now reports a window as found; arbor-sim's `open … fixed`.
- Menu: Dock New Windows, with a tick (`StatusMenu.swift`; it moves into F10's menu model when that lands).
- `arborctl rules` shows what the setting adds, and says so when `newWindows` has a value Arbor does not know.
- Tests: `ArborCoreTests/AutoDockTests.swift` and `ArborKitTests/AutomaticDockingTests.swift` (one or more per criterion, and twelve random journeys in which no opening window may cost another its place in
  view); scenario `28-new-windows-join.sim`; a session of `arbor-e2e` on real windows (`NewWindows.swift`), type-checked on Linux and not yet run.

## Not shipped

- **On a Mac: built, and tried on test windows only**. No real app has been tried. `make e2e`'s new session settles for test windows: that a new window is reported with the frame its app gave it; that Accessibility says a window without a resize control cannot be resized; that the window the
  person was in is still at the head of the focus history when the new one is reported; that a native tab (⌘T) in a docked window is reported as a replacement before it is reported as a window.
- **F04**: as a tab, the new window gets the whole slot. When tab strips land the slot it is offered comes from the same layout engine, so nothing should need changing.
- **A window two points taller or wider than its slot** shows as long as Arbor has not learned its minimum (the controller lets 2 points pass) and is a tile once it has (`LayoutEngine` lets 1 pass). A docking that is tried and taken back can teach
  Arbor that minimum, and then costs the neighbour its place after all: 1 random journey in 1500. The two numbers belong to the core; reported in bug bash 1.
- **What opened during a hold goes on floating after `release`**, and the reply says so (`HoldTests.dockNewWindowsWaitsLikeAnyRuleThatDocks`): F58's `keepsTheView` does not work out whether `dock auto` would keep the view. It always does, so
  `case .dockAuto: return true` there would let such windows dock as those of other rules do. Proposed to F58's owner in bug bash 1.
- **That a window opening over one in full screen is seen as such** rests on the fake: a full-screen window that its app lists is taken to be showing. No Mac has been asked.
- An app that opens a window small and enlarges it a moment later has it float; one that moves its window right after opening it is put back in its slot by the usual enforcement.
- An app that was too slow to be observed at launch and is taken on later has its windows announced as new (`AXWindowSystem.retryObserve`), so they dock. They should be `windowFound`, as should windows first listed because a focus report came before the Space switch was known, or because their app was unhidden: K050 makes a window new only if its app said that it was created, and takes this event over.
- A native tab is recognised by its frame (`NativeTabs`: same corner and width, height within 40 points). An app whose first tab changes the frame by more arrives as a new window and would dock beside its own group. Terminal is measured;
  Finder, Safari and Xcode are not.
- `isResizable` is asked once, when a window is first seen. Whether a window first seen minimised, hidden or in full screen answers as it would when shown has not been measured; such a window is not docked by itself anyway.
- **The empty Desktop gives way once, not for good** (the product owner's note). It gets `arrangeDesktopWeight` when the first window docks. Later windows halve each other's slots and leave it alone, and when a window that shared its row closes, the
  Desktop takes its part of the room like every neighbour (T06). Since F61 landed the empty Desktop also gives whatever windows are known to need, and gets back what Arbor took; it does not yet give way merely so that windows are larger
  than they must be. That is left for F29 (arrange styles).
