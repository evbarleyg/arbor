# F61: Make room before making a tile

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done (feat/F61-room-before-tiles)
Depends on: F01. Goes with F45 (what is learned about a size can be unlearned) and T21 (a single floating window fills the Desktop)
Size: medium
Reference items: T03, T20, A05

## Shipped / Not shipped

Shipped: everything under Behaviour except what follows, with `ArborCore.MakeRoom` (pure), `LayoutTree.setShares`, `Controller+MakeRoom.swift`, the setting `makeRoom`, a truthful drop preview, scenario 61, 21 unit tests
and 33 scenario tests, two of them seeded fuzzes. Where building it taught something, the text below was changed and says so with "(as built)".

Not shipped: the reply and the F43 line "Made room for Notes" (F43 has not landed; `arbor.log` has `made room for w101`); neighbours making room under a drag (with `reflowWhileDragging`, F09, a trial is laid out plainly, so it can show a tile where the drop then makes room); undo in one step (I3 has not landed; the
weights change inside the layout that follows the command, so a snapshot taken before the command covers them). Criterion 12, real apps, waits for a Mac: `scripts/mac-shell/compat.sh` still has its own `make_room`.

## Second round (2026-10-14, decided by the product owner between 12:21 and 13:27; it overrules the text below wherever they differ)

1. **Docked windows come before the Desktop, always.** Somebody has asked for each docked window, nobody for the Desktop's points. It gives down to a tile whether or not something floats on it, and what floats on a Desktop that is a tile shows
   over the arrangement. **No docked window becomes a tile for the Desktop's sake**, at the dock or later. Being in use decides only that the Desktop is served first from what can be spared, and how much it then gets: up to an even
   share of its row and the size of the largest window floating on it. Pinned, summoned and stashed windows and guests of a space do not float on the Desktop.
2. **Room goes back to whom it was taken from.** The tree keeps a ledger (`LayoutTree+Loans.swift`): who gave how much to whom, for whose sake. It is repaid when the window closes, floats or is docked elsewhere, and as soon as the window can spare it
   (a neighbour has closed, the display is larger); only windows whose minimum is known give back, so a launch moves nothing. So the arrangement is what the person made it plus the least its windows need, in whatever order things happened. What
   was lent across a gap that a person has moved since is forgotten: that gap is theirs. The ledger is saved with the tree, and comes and goes with undo.
3. **The window with the keyboard is the last to become a tile**: it is served first, then the others, the one docked last first. If what can be spared is not enough for it, what Arbor lent to its neighbours goes back first, and they are served again from what is
   left: the one exception to "nobody in view pays with their place". So of Mail and a chat that do not both fit, the one that shows after ⌃⌥Space is the one the person was typing in, as long as the gaps between them are where Arbor put them. How far it reaches:
   - The window that has the keyboard now, not the one that had it last: when a floating window closes and nobody has it, nobody pays.
   - Only in the rows and columns that the window itself is in, as far as they are in view as a whole: a look into a group changes nothing outside it, and in a column beside it the same windows show as before.
   - On every occasion, also when the app being typed in makes its own window larger than its place (decided by the product owner, 2026-10-15). An app in the background that does so costs nobody their place: its window is the tile.
   - All or nothing: for a window that still does not fit, nothing goes back and nobody pays. It is the tile.
   - A place that the person's own hand has made short, or shorter, stays as they left it: it is not served, whoever has the keyboard (criterion 6), and gives nothing back for it.
   - Nobody is left with less than a tile, and what cannot go back stays owed.
   - A drop's preview goes by the window in the hand, as the drop will: its place is one that only the drop makes.
   - Switching to a window moves no gap by itself. It happens at the next layout: ⌘Tab to a tile's window still frames it.
   - **A limit, known:** only what Arbor lent goes back. A gap that a person has moved since is theirs, nothing is owed across it, and beside it the window being typed in can still be the tile, against `docs/VIABLE.md` ("The window with the
     keyboard is never the tile"). The cure is decided (the neighbours lend what they need themselves, written into the ledger, so that the gap comes back) and is a change of its own.
4. Tiles give in two steps: first what leaves them large enough for a window, below that only if it takes that.
5. A gap moved by hand marks only the slots it made short, or shorter, as squeezed; it cancels what the Desktop is owed only if it is one of the Desktop's own gaps; looking at the Desktop cancels nothing; `layout <line>` starts afresh like `arrange` (all
   four from the review by R6).

## Third round: there and back is nothing (2026-10-14; the decision is the product owner's, `collab/QUESTIONS.md` Q20; this is what was built)

Seen with real apps on a hosted Mac: Finder 501, the Desktop 175, Safari 574 and TextEdit 290 points wide on 1600; ⌘H in Finder and a click on its Dock icon left the Desktop at 80 and TextEdit at 385. While Finder was away Safari could spare what TextEdit had lent it and paid it back (round 2, point 2); on the way
back it borrowed afresh, from the Desktop first.

Shipped: `Controller+ThereAndBack.swift`, `LayoutTree.takeGaps(from:)`, scenario 66, `ThereAndBackTests`. The gaps and the ledger as they stood after the person's last change to the arrangement are kept, with the docked windows that took space then; the layout for a docked window that has gone or come back
(hidden, minimized, another macOS Space) starts from them. With the same windows, view, display and known sizes the layout that stood stands, and no room is made. As built:

- A size learned meanwhile, or a display that changed, is an occasion to make room as ever.
- The window somebody is typing in does not leave the view for this (round 2, point 3): then the gaps go on from where they are, and that is the arrangement from then on.
- A window that was away at the person's last change belongs, once it is back, to the windows whose gaps come back.
- No gap moves for this under a hand, nor when a window is only put back in its place: the next layout does it.

Not shipped: kept across a restart (`state.json` has the gaps as they stand). A change that Arbor tries, lays out and takes back (a `rotate` that is refused) counts as somebody's. A drop that changes nothing lays nothing out, so for whoever went during the drag the neighbours close up at the next layout. While somebody is
away a move of the view goes on from the gaps as they are. A window that comes back as a tile with the keyboard in it is framed after the layout that gave it its tile, so its neighbours move twice. `reveal` and Go to… pick the view for a window on its way back by the gaps as they are, not as they will be. Frame and Show
Everything, and floating windows, are not this fix's.

## Summary

Dock Notes on the left and Safari on the right of a MacBook Air's screen. The result is **two tiles and an empty Desktop**. Nothing is wrong by the rules: the Desktop keeps a column of its own between docked windows (T03), so
each column gets a third of the width, 464 of 1440 points; Notes will not go below 709 and Safari not below 574; a window that cannot shrink to its slot becomes a tile (T20, A05). But a third of the screen is lying empty beside
them. The person has to know that the gap can be dragged, drag it twice, and only then sees the two windows they docked. It is the first thing most people will try.

In arbor-sim: `open Notes 1000x660 min 709x300`, `open Safari 1324x800 min 574x240`, `dock 101 left`, `dock 102 right`: both are tiles. `resize 101 right 260`, `resize 102 left 125`: both are windows, with a narrow
Desktop between. Arbor should have done that itself.

How common it is, measured on real apps (macOS 26.6):

| smallest width | apps |
|---|---|
| under 464 | TextEdit 115, Terminal 177, Calculator 230 (fixed), Script Editor 334 |
| 464 to 600 | Finder 501, Font Book 508, Safari 574 |
| over 600 | Maps 660, Calendar 680, Preview 708, Notes 709, System Settings 723 (fixed), Activity Monitor 740 |

| display, points | a third, after gaps | stock apps of the 13 that are tiles in it |
|---|---|---|
| 1280 (13" scaled) | 411 | 9 |
| 1440 (MacBook Air 13") | 464 | 9 |
| 1512 (MacBook Pro 14") | 488 | 9 |
| 1728 (MacBook Pro 16") | 560 | 7 |
| 1920 | 624 | 6 |

Third-party apps are no slimmer: chat and mail clients, editors and browsers mostly stop between 500 and 800.

## Behaviour

**When a layout would turn a window into a tile only because its slot is smaller than the window's minimum size, Arbor first moves the gaps around it, as the person would, taking the missing points from whoever can spare them.** Only if
that is not enough does the window become a tile.

Who gives, in this order, along the axis that is short (width first, then height, each on its own):

1. **The Desktop**, if it is a sibling in that row or column. It gives down to the smallest usable size (`minimumUsableSize`, 240 × 160) while a floating window lives on it (not a pinned or summoned one, which is in view wherever the view goes, nor
   a stashed one, nor the guest of a space, which comes and goes with that), and down to the width of a tile (80) when it is
   empty. An empty Desktop squeezed into a tile is still one click or ⌃⌥D away.
2. **The other siblings** in that row or column that have more than they need, in proportion to what each can spare. A sibling needs the largest minimum of the windows in it (for a group: summed along its own axis with
   its gaps, the largest across it), and never less than the smallest usable size.
3. **The row or column above**, in the same way, if the window's own row or column has nothing left: the group the window is in grows, then the window inside it.

What does not give: a window at its own minimum, a group's tile, anything outside the view. A window that is a tile gives too, at first what leaves it large enough for a window (whatever is docked beside a tile later shares its row or column, and would be a tile at once in one that is too narrow for any window), and if
that is not enough as far as a tile goes, 80 points: it has no place to lose (as built; otherwise the window docked
last could not be served ahead of an older one that is short too, and of three wide windows only one would fit where two can, beside two narrow tiles).

**Nobody in view pays with their place** (as built). Room is what others can spare. A newcomer that needs more than that is the tile; the windows already in view stay. The one exception is the Desktop in use, below.

If several windows are short at once, **the one that was given its place last is served first**, and so on back to the oldest (as decided in review: the outcome depends on the arrangement alone, not on who had the keyboard or on what
happened in which order). Those that still do not fit are tiles, as today.
Who comes first does not depend on whom Arbor has met before either (as built): a minimum is learned only when a window refuses its slot, in the middle of a layout; the layout then starts again from the gaps as it found them, so the outcome
is what it would have been with everything known at the start.

**The Desktop gets back what it gave** (as built). It gives first, but a Desktop that Arbor has squeezed into a tile is topped up to the smallest usable size from whatever its neighbours can spare, at once and whenever that changes (the window
it made room for closes, the display is exchanged for a larger one). For a mere move of the view, which includes a launch and a change of displays, only windows whose minimum is known give to an empty Desktop: what the others can spare could
only be found out by asking them. A Desktop that is narrow because somebody made it so (a gap dragged, `arrangeDesktopWeight`) is left alone.

**A window that comes to float on a Desktop Arbor has squeezed** (decided by the product owner in review). The first ⌘N after Notes and Safari were docked floats on a Desktop that is a tile, and a window on a tile is out of view in Show
Everything. So what Arbor took from the Desktop it gives back while a window floats on it: not when the window opens (nothing jumps for a ⌘N; it is in view where it opened), but at the next layout that a move of the view or a change of
the arrangement causes. The Desktop then comes first, takes the smallest usable size, and if nobody can spare that, the docked window that was given its place first becomes the tile: who is in view is what it would be had the window
been floating there from the start. No more windows leave the view than must. When the floating window has gone, the tile is served again. That the Desktop is owed room is saved with the workspace. An app that moves its own window is
no occasion, and a Desktop squeezed by hand stays as it is.

**When it happens**: whenever Arbor itself changes who has how much: a dock by drag, shortcut, command or rule; `arrange`; a window closing, minimizing or coming back; a display changing size; a minimum learned for the first time.
**When it does not**: while the person drags a gap or a window's edge, and on `resize`. Someone who squeezes a window below its minimum on purpose gets the tile they asked for (T20), and Arbor does not push back, then or
later (as built): the slot stays as they left it through every later layout, until their own hand widens it or the window is given another place. This is not saved: after a restart such a window is served like any other.

**It lasts.** The gaps stay where Arbor moved them, exactly as if the person had dragged them: they are saved, undo (I3) takes them back in one step with the dock that caused them, and dragging them afterwards works as ever. When the window
leaves, its space is shared out as for any window (T06).

**The preview tells the truth.** While a window whose minimum is known is dragged, the drop preview shows the frame it will really get, and (with `reflowWhileDragging`, T09) the neighbours where they will really end up.
For a window whose minimum is not known yet the preview shows the plain share, as today, and the layout corrects itself on the drop.

**Replies and F43** say what happened once per session: "Made room for Notes: it needs 709 points." A dock that still ends as a tile keeps today's reply.

Setting `makeRoom` (default on; advanced: nobody should need it). Off is today's behaviour.

## What it gives on a 1440-point display (1392 points to share between three columns; the numbers are arbor-sim's)

| docked | today | with F61 |
|---|---|---|
| Notes, Desktop, Safari | tile, 464, tile | 709, 109 (a tile, empty), 574 |
| the same with a Calculator floating on the Desktop | tile, 464, tile | tile (443), 240, 709 with Notes docked last; tile (469), 349, 574 with Safari docked last: the two need 1283 of the 1152 left |
| the same with the Calculator opened after the two docks, at the next move of the view | tile, 464, tile | tile (578), 240, 574 |
| Safari, Desktop, Terminal | tile, 464, 464 | 574, 354, 464 |
| System Settings, Desktop, Finder over Terminal | tile, 464, tile over 464 | 723, 168 (a tile), 501 |
| Notes, Desktop, Calendar, Safari (1380 for four) | tile, 345, tile, tile | tile (312), 80, tile (414), 574: the window docked last is in view; no two of these fit beside the rest |
| Notes, Desktop, Safari, Mail (500) | tile, 345, tile, tile | tile (226), 80, 574, 500 |

**Changed on 2026-10-14 by the product owner (QUESTIONS Q20):** floating windows are left where they are, so they need no room on the Desktop: with `floatingWindowsMakeWay` false the Desktop counts as not in use, and docked windows come first. Being built; until it lands the text below is what the trunk does.

## Design notes

- **Move weights, do not bend the layout.** The tempting place is `LayoutEngine.placeSplit`: raise every child to its need at layout time and leave the tree alone. It breaks the gaps: a `Seam` carries `pointsPerWeight`, and a drag converts points
  to weights on the assumption that frames are proportional to weights. With frames bent after the fact a gap would not follow the pointer. So F61 changes the **weights**, once, and the layout stays a pure function of the tree.
- Core, pure, unit-tested (as built): `MakeRoom.serve(&tree, camera:in:options:isPresent:minimumSize:terms:)` lays the tree out, picks the short slot with the highest node id (ids only grow, so that is the one given its place last), and works on a copy, width then height: it reads lengths from
  `layout.nodeFrames`, walks up from the leaf, and in each row (or column) along the axis takes what is missing from the siblings' spare lengths. What a row higher up gains goes to the leaf alone: in the rows below, its neighbours keep their lengths. The new lengths
  become weights with `LayoutTree.setShares`, which keeps the sum. The copy is kept only if the window is in view in its layout and nobody else has left it: half a solution helps nobody. After each success the ones that failed are tried again.
- The floor of a giver: stack → the visible window's learned minimum, at least `minimumUsableSize`; a window's tile, and a window that has to make way for the Desktop → 80 × 80; Desktop → 240 × 160 or 80 × 80 as above; split across the axis → the largest floor in it; **split along the axis → its length
  times the largest floor-to-length ratio among its children**, not the sum of their floors, because a row that shrinks does so in proportion to its weights.
- Controller (`Controller+MakeRoom.swift`): `relayout` calls `roomyLayout(of:for:)` where it called `layout(of:)`. A minimum learned in `apply` goes round again from the gaps as the layout found them. Two such rounds, then two plain ones, so an app that keeps raising
  its minimum cannot keep Arbor busy. With no tile in the plain layout it costs nothing.
- A gap drag, an edge drag and `resize` wrap their `relayout` in `byHand { … }`.
- `Workspace.previewFrame(…makingRoom:)` docks into a copy, lays it out, and serves the copy on the same terms, with the dragged window no longer counted as floating (its new slot is the newest, so it is first).
- Only nodes in view take part (`layout.nodeFrames`), so zooming never rearranges what is out of view. After zooming out, a window that is short in the wider view is served then.
- Windows that size in steps (Terminal): the minimum is only learned after `askForLess` has failed (`Controller+SizeSteps.swift`), so cells never trigger F61.
- F45 unlearns wrong minimums. Room that was made for one is not given back; the person has a wider window than needed, which is harmless.
- Minimum sizes are not readable through Accessibility, so the first dock of each window still goes through one refusal: the window is seen too large for a moment, then its neighbours move. With F02 the stage hides that.

## Acceptance criteria

1. The scenario of the summary (1440 × 900, minimums 709 and 574): after the two docks both windows are in view at no less than their minimums, nothing overlaps, and the Desktop is a tile between them. As a scenario in `collab/scenarios/`.
2. The same with a floating window in view on the Desktop: the Desktop keeps 240 points, the window docked last is in view, the other is a tile.
3. A window with a minimum of 574 docked beside two that have no minimum: both give in proportion to what they can spare, neither goes under 240, and the sum of the weights in the split is what it was.
4. A column of two windows, the lower with a minimum height larger than half: the upper one gives. A group whose column is too narrow for a window inside it: the group's column grows (rule 3).
5. Nothing to give (every sibling at its need): the window is a tile and no weight has changed.
6. Dragging a gap, dragging a window's edge, and `resize` can still squeeze a window into a tile, and no later layout widens that slot again.
7. The drop preview for a window with a known minimum is the frame the window gets on the drop.
8. The weights are saved: quit and start again, and the layout is the same without any window being asked twice.
9. `makeRoom: false` gives today's results in all of the above.
10. (added in review) `open Notes…`, `open Safari…`, `dock 101 left`, `dock 102 right`, `open Terminal`: nothing moves. `zoom 101`, `show-all` (or `home`, or `back`): Terminal is in view, Safari too, Notes is the tile. The same after a restart
    between the docks and the ⌘N. Terminal closes: Notes and Safari are both in view again.
11. (added in review) Notes, Safari and a Mail of 500 points docked in that order: Safari and Mail are in view, Notes is a tile.
12. On real apps: `scripts/mac-shell/compat.sh notes safari settings calendar` at 1600 × 900 and at 1344 × 756 (`COMPAT_DISPLAY`): the steps `dock-left`, `dock-right` and `dock-below` are ✔ without the suite's own `make_room`, which can then go.

## Open questions

- Should an **empty** Desktop really go down to a tile by itself? The alternative (never under 240) leaves Notes and Safari unsolved on every MacBook. TrellisWM's behaviour here has not been observed (`squeezeBelowMinimum`, `fixedMinimum` in its bundle suggest
  it covers a squeezed window with a stand-in instead).
- A different default would avoid much of this: give the Desktop a smaller share from the start (a quarter, or `arrange`'s half weight) when a second window is docked. It helps the 500-to-600 apps on 1440 points and none of the 700 ones, so it is not
  a substitute.
