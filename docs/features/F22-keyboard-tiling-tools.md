# F22: Keyboard tiling tools

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done (headless; the real-window checks have not run)
Depends on: F01, F06 (default keys), F07 (the seam search), F11 (the focus history), F56 (which display), F57 (guests), F61 (room before tiles), F62 (groups that stay)

## Summary

What people who come from yabai, AeroSpace, Amethyst or i3 expect from a window manager and TrellisWM
does not have: move focus, trade places, resize, balance, rotate and mirror a group, and reach other
displays, all without the mouse. Every one is a command, so it works from a shortcut, the menu,
`arborctl`, a URL and a test alike.

## Behaviour

Directions are `left`, `right`, `up`, `down` (and every other word `dock` accepts for an edge).

### `focus <direction>`

1. **In view.** Focus goes from the focused window to a window in view that lies that way. Docked windows
   count by their slots, floating windows by their frames. A window lies that way when its centre is
   past the focused window's edge on that side, so a floating window that overlaps the focused one can
   still be reached. One that lies over the focused window, or under it, also counts the way its centre lies from
   that window's centre: a dialog or a guest wholly inside a framed window is past none of its edges. Of those:
   - windows **beside** the focused one come before diagonal ones (beside: the span they share across the
     direction of travel is at least a quarter of the shorter of the two);
   - then the **nearest** wins, so nothing in between is jumped over;
   - between equally near ones (within 2 points), the one sharing the **longest span**;
   - then the **most recently focused**; then the topmost, then the leftmost.
2. **A tile in the way is entered**: the camera moves onto it, and focus goes to the window there nearest the
   edge one came through. A tile for the Desktop is passed over: it is still part of the view, so what floats on it is in view,
   over the docked windows, and is a stop itself. Whenever the view moves, focus
   goes to what arrived with it: to a pinned window (F49), which was there before, only if nothing else did.
3. **From a floating window that lies over a docked one**, with nothing that way, focus goes to the window beneath it: that one
   has its turn before the view moves.
4. **At the edge of the view** it does what `neighbor <direction>` does, on the display the keyboard is on: the
   camera moves to the neighbouring space, and focus goes to the window there that is nearest the edge
   one came through and level with where one was. On an empty Desktop there is nothing to focus; the
   command still succeeds, and the same key goes on from there.
5. **Past the last space**, if a display lies that way, focus goes to the nearest window in view there (a display
   with nothing in view is passed over).
6. Otherwise it fails: "no window or space to the left".

With **no focused window to start from** (none, one Arbor does not arrange, or one that is out of view), focus goes to
what is under the pointer, else to the top-left window in view, whatever the direction. With nothing in view
at all, it goes on with step 4.

### `focus next` | `focus previous` | `focus <window>`

`next` and `previous` cycle through the windows in view on the display the keyboard is on: docked ones in tree
order, then floating ones in the order they were opened, wrapping around. Tiles, inactive tabs, and windows out of
view are not visited. With one window in view they fail.

`focus <window>` focuses a window by its id and brings it into view the way a click in the Dock or ⌘Tab does (its
tab is shown, the camera zooms out just far enough, or onto it), on whichever display it is.

### `swap [window] <direction>` | `swap <window> <window>`

The slot of the focused (or named) docked window and the nearest slot that way exchange what they hold.
**The slots keep their sizes**; `dock <edge>` is the command that moves a window and its size along. The search is
the one `focus` uses, over docked windows and window tiles in view. The Desktop is passed over. A tab group travels
whole. Focus stays with the window, unless its new slot is too small to show it. Nothing happens beyond
the view: at its edge the command fails. A group shown as a tile is refused with a hint to name a window.

`swap <window> <window>` does the same for any two docked windows, in view or not, on one display or two,
and leaves focus where it was (unless that window went out of view).

**What was saved of a window goes with the window**, as when it is docked somewhere else: saved views and history that frame
it, the windows that opened over it (F57), and the view itself. So `swap` with the view on one of the two changes
nothing that can be seen. Across displays none of that can follow: views stay with the place, and the windows that opened
over a window that left become ordinary floating windows.

### `grow [points]` | `shrink [points]`

Makes the focused window bigger or smaller by that many points (setting `resizeStep`, 40, if not given) in width
and in height, wherever a seam beside it is in view. One seam moves by the whole amount; two seams on opposite
sides share it. Points must be positive, finite and at most 1,000,000.

- Growing stops when a neighbour is down to the 80 points every seam keeps.
- **Shrinking stops while the window can still be shown**: at `minimumUsableWidth` × `minimumUsableHeight`, or at
  the size its app insists on. If the app's minimum is not known yet and it refuses the smaller slot, the
  seams go back as far as the window needs instead of leaving it as a tile.
- A floating window changes about its middle and does not go below 80 × 80. On the Desktop it grows no further than
  the Desktop (grown over its docked neighbours, it would be squeezed back at the next change of the arrangement). One that
  its user put over docked windows, a guest and a pinned window have the whole display, and stay where they grew.
- With no seam in view (the window fills the view), or nothing left to give, the command fails and says which.
- Both are the person's own hand, like `resize` and a drag of the gap: Arbor does not push back by making room (F61).

### `balance [all]` (also `equalize`)

Every split under the camera gets equal weights per child; `all` starts at the root. The camera stays. A group that runs
the same way as the one around it (a rotated pair) looks like part of the row, and counts for as many places as it shows:
four columns come out equal, whether or not two of them are a pair. The
Desktop counts as one window, except where `arrange` puts it (last in a root that runs left to right), where it
counts as `arrangeDesktopWeight`, bounded as `arrange` bounds it: evening out an arranged display gives back exactly what
`arrange` made. Windows that are minimized, hidden or on another Space get an equal share to come back to. A window whose
equal share is smaller than its app allows is given the room it needs, if the others can spare it (F61), also one that
was once squeezed into a tile by hand: the sizes start afresh. If the focused window is a tile all the same, focus goes
to a window in view. (The code calls it
`equalize`; users read "balance" everywhere: the command, Balance Sizes, "balanced 2 groups".)

### `rotate` | `mirror`

Both act on the **group of the focused window**: the nearest split around it that shows more than that window (a
split whose other windows are all minimized is passed over). Without a docked window in focus, they act on
the view itself.

- `rotate` turns a row into a column and a column into a row, keeping order and weights. Axes alternate
  down the tree, so every split inside the group turns too: groups stay groups. A group that is not the root now runs the
  same way as the one around it, where the tree would dissolve it. **It stays a group** (F62, kept as "turned"), in exactly
  the room it had: it can be framed and stepped out to like any other, and **`rotate` is its own way back**, from any of
  its windows: twice gives the same arrangement, to the point. The group goes when it is down to one window.
- `rotate` refuses, changing nothing, when a window that shows now would be too small to show afterwards, even with the room
  F61 can make for it (and says what to
  do: grow them, or frame the group and rotate it there), and when the focused window fills the view. How small an app
  lets its window get is known only once it has been asked: if one refuses its new slot, the group is turned back at once.
- `mirror` reverses the order of the group's children. Sizes go with the windows; what is inside each child
  stays as it is.

### `move-to-display <next|previous|n> [window]` | `focus-display <next|previous|n>`

Displays are counted from 1, left to right and then top to bottom; `next` and `previous` wrap around.

- `move-to-display` sends the focused (or named) window to another display, docked or floating as it was. A docked
  window docks at the edge of that display's view that faces the display it came from, and a Desktop there with windows
  on it stays usable, as for `dock`. A floating one floats in the middle of that display's Desktop (of the display, if the
  Desktop is out of view). It keeps its size; on a smaller Desktop it is squeezed like any floating window, gets its size
  back when there is room, and if its app will not make it that small it hangs over docked windows rather than off the
  display. Over a framed window it is a guest of that view (F57). A pin (F49) goes along.
  One tab leaves its group. Focus goes with it; if its new slot is too small to show it, it
  is framed, as any focused window is. A minimized window moves without taking focus.
- `focus-display` focuses the window that had focus last among those in view there (else the top-left one). On a display
  with nothing in view there is nothing to focus: `next` and `previous` pass over it, a number fails. This is IDEAS I4.

**The pointer stays where the hand left it**, whatever these commands do. It used to be sent along to another display, because
shortcuts that move the view acted under the pointer; since F56 they follow the keyboard, so there is nothing left for it to mend.

**Which display.** `focus`, `rotate`, `mirror` and `focus-display next` start from the focused window: they act on its display, or
on the one under the pointer if Arbor does not arrange that window. `balance` is about the view, and chooses as the
commands that move the view do (F56): the focused window's display, or the pointer's if the pointer moved last.

**While the focused window is full screen** all that rearrange are refused ("w412 is full screen"): the arrangement is on another
of the macOS Spaces, and nothing is rearranged unseen.

**From a URL** every one may run but `focus <window>`, `swap <window> <direction>` (which focuses the window it names), `focus-display`
and `move-to-display`: a web page must not pick the window the keyboard types into.

### Default keys

From `docs/KEYBOARD.md`:

| Keys | Command |
|---|---|
| ⌃⌥⇧ + arrow | `focus <direction>` (⌃⌥⇧↑ and ⌃⌥⇧↓ were `neighbor up` and `down`; framed on one window they still do the same) |
| ⌃⌥⌘= / ⌃⌥⌘- | `grow` / `shrink` |
| ⌃⌥⌘0 | `balance` |
| ⌃⌥R / ⌃⌥⇧R | `rotate` / `mirror` |

`swap`, `focus next`, the display commands and the vi keys have none; the README has a recipe for `bindings`.

### Menu

As docs/MENU.md has it: **Adjust ▸** Grow, Shrink, Balance Sizes; Rotate Group, Mirror Group; Lay Out Again. With more than one
display, Move to Next Display at the end of **Dock Focused Window ▸**. The rows are lines in the headless menu model (F10,
`Controller+Menu.swift`), greyed out where the command would only beep.

## Design notes

- `ArborCore/DirectionalSearch.swift`: `nearest(from:toward:among:)` over any rectangles with an id and a recency (windows, tiles,
  displays), `approaching(_:from:toward:)` for entering a view or a display, `facingEdge(of:from:)`. Pure, unit-tested.
- `ArborCore/TilingCommands.swift`: `FocusTarget`, `DisplayTarget` and the words for directions.
- `LayoutTree.equalize(under:desktopWeight:)`, `rotate(_:)` with `Keeps.turned` (called inside `Workspace.changeStructure`), `mirror(_:)`,
  `tradePlaces(of:and:)` (two leaves exchange parent, position and weight and keep their ids, so whatever refers to a window's
  leaf follows the window), and `swapLeaves(of:in:and:in:)` for two trees.
- `Controller+KeyboardFocus.swift` and `Controller+Tiling.swift`. `giveFocus(to:)` focuses a window and handles the focus change at
  once, because macOS reports it a moment later. Until it does (half a second at most), `keyboardFocus()` takes the window
  that was asked for as the focused one, for every command that acts on the focused window, so keys pressed
  faster than macOS moves focus are not lost. The request is over at once when a focus change is reported that goes
  neither to that window nor to one asked for just before it: a click, ⌘Tab or another command has the last word.
- `moveCamera(on:to:record:refocus:)`: a caller about to focus a window of its own choice passes `refocus: false`.
- arbor-sim: `focus 101` is still the user clicking a window, `focus left` is the command; `expect focused <id>`.

## Acceptance criteria

1. `focus <direction>` picks by the rules above in view, including floating windows, three columns split at different
   heights, and equal neighbours; it moves no window.
2. At the edge of the view it takes the path `neighbor` takes; a space is entered at the edge one came through.
3. Window tiles and group tiles are entered; what floats on a Desktop that is a tile is a stop itself.
4. Past the last space it crosses to the display that way, passing over empty ones; shortcuts then act there.
5. With nothing to start from, the pointer decides, then the top left. With one window or none, every form fails.
6. `focus next` and `previous` visit exactly the windows in view, in order, wrapping.
7. `swap` exchanges contents and leaves slot sizes; works across levels, with tiles, tab groups, by id, and across displays;
   saved views, history, guests and the view follow their window.
8. `balance` evens out the view, `balance all` the display; after `arrange` it gives back the arranged tree.
9. `rotate` and `mirror` do the above; `rotate` twice is the identity; the randomised invariant test covers them and `balance`.
10. `grow` and `shrink` give the exact amount with one seam, two seams, and seams at different depths; they stop at
    the limits; no amount crashes.
11. `move-to-display` keeps the dock state; `focus-display` picks the last focused window in view; numbering follows position.
12. Every command round-trips through its text, is in `help`, rejects bad input and can be bound to a key; a URL runs all but three.
13. An old `settings.json` without `resizeStep` loads.
14. `make check`, `make scenarios` and `make parity` pass.

## Shipped

Everything above. Tests: `DirectionalSearchTests`, `TilingCommandTests`, `TilingTreeTests` and the extended
`randomOperationsKeepInvariants` (core); `KeyboardFocusTests`, `SwapTests`, `EqualizeTests`, `RotateAndMirrorTests`,
`GrowAndShrinkTests`, `DisplayCommandTests` and `TilingRobustnessTests` (the real controller, including a seeded random run of
every command on two displays, among windows that open, close, hide, go full screen and are held by the mouse, pauses, pins and
a macOS that is slow to move focus); `collab/scenarios/22-keyboard-tiling.sim`.

## Not shipped

- `close [window]` and `minimize [window]`: `WindowSystem` had no `close` on the base when this was built (F04 adds one).
- `swap` and `grow` do not reach beyond the view or across displays by direction; `swap <window> <window>` does.
- `swap` with a floating window, or with the Desktop.
- Windows of excluded apps and ignored windows are never focused by these commands.
- The pointer does not follow the keyboard to another display (above). A setting for people who want it would be small.
- `focus <window>` refuses a window that is minimized, hidden or on another of the macOS Spaces. `reveal <window>` (F27) fetches
  those; once it is on the trunk the refusal should name it.
- A floating window in the very middle of the focused window (centres within two points) is reached by `focus next`, not by a
  direction: nothing says which way it lies. From it, every arrow leads to the window beneath.
