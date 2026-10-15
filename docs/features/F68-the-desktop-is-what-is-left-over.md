# F68: The Desktop is what is left over

Written by the executor, 2026-10-15, from `collab/IDEAS.md` I20 (a) and `collab/QUESTIONS.md` Q28 and Q29 (5); for the documenter to review.

Status: done (headless; pictures of Arrange Windows with two to six real windows from a hosted Mac)
Board: 0.6
Depends on: Q27 (a changed default reaches a Mac that has run Arbor), F61, F62
Size: medium; an engine change

## Summary

The first person to work with Arbor set the width of the Desktop column to its floor, and that was still too much: wanted was none. Until now the Desktop
always took room: a second dock made thirds (window, Desktop, window) and shrank the first window, and Arrange Windows left a column free at the right.

**The Desktop is what is left over, not a place with a share of its own.** Two docks are two halves. Arrange Windows leaves nothing over.

## Behaviour

As Arbor ships (`desktopColumn` off):

- **One dock takes a half**, as before. What is left over is the Desktop.
- **The next dock in that row takes all that is left**, however much that is, and nobody else gives anything: at the far side the first window gets no frame at
  all; docked on the first window's own side, the first keeps its size and moves over once. The same for a drop on a window's side edge in that row and on the
  Desktop's own side edges, and for a window that docks by itself.
- **Too little to show any window in is nothing** (under the smallest usable size, 240 × 160 as it ships: beside an Xcode that will not go under 1200 points, or a gap
  dragged far). Then everybody in the row gives, as with nothing left, and the window just docked, with the keyboard in it, is not a tile from the start.
  That is said of what the dock found: as little as a hand has left a window since is what that hand wanted.
- **With nothing left docked windows give**, as before: at the edge of everything an even share from all, beside a window half of that window.
- Across the row (top, bottom) nothing has changed: what is left over stays left over beside them.
- **A docked window that is only moved brings its share along.** Nothing is left over where it was, and where it goes it takes a share like the others', not what is
  left over: from two halves, `dock top` puts the one above the other, both as wide as the display, and `dock left` puts it back. The Desktop neither opens nor closes because a
  window has changed places.
- **Arrange Windows leaves nothing over**: the same grid, without the column and without a gap for one. With one window that is the whole display; `dock left` or
  `dock right` on it then gives it that half.
- **Whoever is left alone stays as it is.** Of the two places that everything consists of one closes, floats or is dragged out: the other gets no frame, and the room
  that is freed is left over, where it was freed, whichever of the two left and however the picture was made. One docked window alone has a half, read by state and not
  by order. From three or more down the others share, and no column opens; so they do inside a group: **no hole opens among docked windows.** One thing goes back
  first: what the one that stays had lent for the sake of the one that leaves (F61). That is its own, and a gap its person dragged is where they left it.
- A window that took what was left over and leaves a row that is still as it found it gives it back: there and back is nothing.
- If the one that leaves was away at the time (minimized, hidden, a place kept for a window that is not open), whoever is there has its room already and keeps it,
  however it leaves: closed, floated, pinned, by a rule, to another display, or with its app taken out of Arbor's hands.
- Minimize and hide are as before: who is away lends its room to who is there, and there and back is nothing. With every docked window away, everything is left
  over.
- **A Desktop without room is still a place to go.** Show the Desktop (the menu; ⌃⌥D in the whole map of keys), the menu bar's button, a view saved on it, a name given to it and Back all mean it: it fills the
  display, docked windows are out of view, what floats and the real desktop are in view. From there `out` leads to everything, and `neighbor` to the window on
  that side of its place in the row; `in` with the keyboard in a floating window, or the pointer on one, leads there, whatever is docked under it (one that lies behind a docked window is not what the pointer is on). A window docked while the view is on it gets a share like the
  others', and leaves no column when it goes again.
- Beside the others it has **no rectangle, no tile, no gap, no gap handle, no drop zone**; it is nobody's neighbour, and it is not on the minimap.
- **Floating windows** are in view wherever the Desktop is part of the view, room or none. With none they lie over the docked windows.
- `balance` leaves a Desktop without room without, and counts it for no place; one that has room counts as one.
- `layout`: a line that does not mention the Desktop gives it no room, and a Desktop without room is not written (`Safari | Mail`). `Desktop` and `Desktop:0.5` typed
  still mean it. Where it lies inside a group, which such a line could not say, it is written `Desktop:0` (`(Safari | Desktop:0 | Mail) / Notes` after docks left, right
  and bottom): a view of "these two and the Desktop" shows what floats, and what is printed, read back, costs no saved view and no name.
- **Room before tiles (F61):** while the Desktop has room it still gives first. It is never owed any: no docked window gives for an empty Desktop. Whoever takes all
  that is left takes what the Desktop is owed with it. Two halves are each window's own, with nothing lent that could go back: there F61's "the window with the
  keyboard is never the tile, if it fits at all" is what counts, by which the neighbours lend what they need themselves, and the gap is back to the point afterwards. Whoever
  comes back into view does so in one move, to what it is owed and not by way of its smallest size.
- A place that waits for a late window with its room kept open (Q16) has lent it to nobody. Given up, it is like a window that closes.
- A Desktop tile is left only where a person dragged a gap until it is one, or where F61 took most of a Desktop that had room.
- **A `state.json` of the first build** with a column is read as it is: nothing moves at a start. The next dock in its row takes the column, the next Arrange Windows drops it.

With `desktopColumn` on, all of this is as in the first build: thirds at the second dock, a column `arrangeDesktopWeight` wide after Arrange Windows, `balance` and a
`layout` line that does not mention the Desktop, and room that is owed to the Desktop. Off, `arrangeDesktopWeight` is read by nobody: a file may hold it at its floor as
somebody's wish to be rid of the column.

## Design

- The tree keeps its one Desktop leaf, so every word that means it keeps its meaning. **No room is weight 0** (`LayoutTree.desktopHasRoom`), allowed for the Desktop
  alone and only beside others. Amounts add up: the newcomer gets the Desktop's weight, and what leaves gives its weight to the Desktop.
- `TreeView.isEffective`: the Desktop takes up space if it has room, or if no docked window is present anywhere. `effectiveAncestor` lets the Desktop stand for itself, so a
  view can be on it.
- `LayoutTree.dock(…, desktopColumn:)` takes what is left first; `detach` sees to whoever is left alone (a Desktop without room can lie anywhere and nobody
  sees the difference, so it takes the place of what leaves; `LayoutTree.everything` is the row or column the two places are counted in); `grid`, `equalize` and `LayoutNotation.Spec.tree` take an optional width, nil for none.
- The setting travels as `shareRemovedSpace` does: a parameter of `Workspace.dock`, a field of `Drop` and of `LayoutOptions` (which previews, `MakeRoom` and `AutoDock` read).
- A build older than this one reads weight 0 as damage and gives the Desktop a share again.
- A trace that lacks the key was recorded before there was a choice, and is replayed with the column (`RecordedSettings`).

## Acceptance

| | Proven by |
|---|---|
| Two docks: halves, and the first does not move at the second | `NoDesktopColumnTests`, `DesktopWithoutRoomTests`, scenario `I20a-no-column-for-the-desktop.sim`, `arbor-e2e` |
| Arrange Windows with one to six windows: no column, no gap for one | `NoDesktopColumnTests.arrangeLeavesNothingOver`, `DesktopWithoutRoomTests.aGridLeavesNothingOver`; pictures from a hosted Mac |
| `desktop` (its key in the whole map), the menu and Go to… still reach the Desktop | `NoDesktopColumnTests` ("The Desktop is still a place to go") |
| The old thirds by the setting | `NoDesktopColumnTests.theSettingBringsTheColumnBack`; every test that says `.withDesktopColumn`; `make test-classic` |
| Whoever is left alone stays as it is | `NoDesktopColumnTests.whoeverIsLeftAloneStaysAsItIs`, the scenario; the walks `RoomGivenBackTests.visitsLeaveAnyTreeAsItWas` and `ReviewShareRemovedSpaceTests.leavingForGoodLooksLikeBeingAway` end where this rule begins, and check it there |
| What the others lent for the keyboard's sake goes back to the gap the hand left | `NoDesktopColumnTests.whatTheOtherLentForTheKeyboardsSakeGoesBackToTheGapTheHandLeft`, `atAStartNobodyPaysWithTheirPlace` |
| Too little left over is nothing; no hole among docked windows; what floats over two halves | scenarios `F68-too-little-left-over.sim`, `F68-no-hole-among-docked-windows.sim`, `F68-what-floats-over-two-halves.sim` (what two adversarial readers played) |
| What a hand has made stays; who is away leaves no column; the pointer means what it is seen on | scenario `F68-what-a-hand-has-made-stays.sim`, `NoDesktopColumnTests.placesThatWaitSideBySideAndAreGivenUpLeaveTheOtherAsItIs`, `DesktopWithoutRoomTests` ("What a second reading found") |
| What `layout` prints, read back, costs nothing | `LayoutCommandTests.whatIsPrintedAndReadBackCostsNothing`, `LayoutNotationTreeTests.anyTreeComesBackFromItsLine` |

## Shipped / Not shipped

Shipped: all of the above.

Not shipped: "room comes back when a person drags a docked window's inner edge inward" (Q28). A gap or a window's edge between two docked windows moves the boundary
between the two, as before. The product owner: only if use asks for it. By a plain drag a docked window cannot leave an arrangement that fills the display until board
0.4 ("a plain drag means out") is in; ⌃⌥F, the menu and a ⌘-drag take it out.

Known, and left: "whoever is left alone stays as it is" beats "a window that comes and goes leaves the row as it found it" where ONE docked place had everything (Arrange
Windows with one window; the first window with `newWindows` `dock`), a second took half of it and leaves again: the first stays at its half. `desktop` from an arrangement
that fills the display plays no transition: there is no rectangle to fly to. A Desktop that has been given a name, visited by a window docked on its view, keeps a column
when the window has gone (without the name, or with a saved view instead, none). On the Desktop's own view a dock to an edge fills the display, and says "at the left edge". The
welcome window rests "between the two" only while there is a between: after the second dock it goes to its place for "nothing docked yet".
Where the Desktop lay without room inside a group (`(Safari | Desktop:0 | Mail) / Notes`) and Notes leaves, it takes Notes's place: a view or a name on that group
no longer shows what floats, which "everything" does. With `makeRoom` off a drop's preview shows the sliver that is left over, where the drop then gives a share like
the others'. Three mends of F61 that this change brought to light hold with `desktopColumn` on as well, so that "as in the first build" is not true of them: whoever is served when an
app has grown its own window gets what it is owed in the same move; a lender that leaves calls its loans in first; a guest of the Desktop passes its claims on.
