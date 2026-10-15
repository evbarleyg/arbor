# F69: What cannot fit overlaps

Written by an executor from the product owner's ruling of 2026-10-15 (board 0.26: a dock takes nobody out of view); for the documenter to review.

Status: done (`fix/a-dock-takes-nobody-out-of-view`)
Depends on: F01, F61. Overrules, with the setting as it ships, parts of F61, F22 and T20 (below)
Rules of the product direction: 2 (nothing moves that the person did not move), 4 (the window you switch to is in front and in view), 7 (daily usefulness above parity)

## Shipped / Not shipped

Shipped: everything under Behaviour; the setting `windowsThatDoNotFit` (`overlap`; `tile` is how it was); `LayoutOptions.overlaps`, `Layout.tightPlaces`, `overhangs`, `slots`, `fits`,
`seamsInReach`; the loan that is not enough (`MakeRoom.serve`); `Controller+Overlap.swift`; `OverlapTests`, `ADockTakesNobodyOutOfViewTests`; the scenario
`a-dock-takes-nobody-out-of-view`; the rules `overhang` (the controller's own) and `overhang-too-large` (the walks').

Not shipped:
- A drop's target goes by the places, not by which of two overlapping windows lies in front, which Arbor does not know. The minimap and the surface behind docked windows show the places.
- Only with `desktopColumn`, which ships off (F68). **Where the Desktop's column stands between two that overlap** it is down to the least a space goes (80 points), under a window, and neither gap
  beside it moves: `grow`, `resize` and a pull at either window's inner edge are refused there, in the words for any space of 80 points. **Where it stands at an outer side** ([editor | mail |
  Desktop], as `arrange` leaves it) the mail app hangs over the editor and not over the Desktop's tile beside it: the overlap is larger by that tile and its gap than the windows demand. As
  Arbor ships, in the summary's story, all three are obeyed and `arrange` gives the keys' own frames.
- A bystander can be sized there and back at a dock that ends in an overlap, where Arbor learns a size on the way (`sized-there-and-back`, board 1.32): fewer than with tiles in all, but not none.

## Summary

⌃⌥← on an editor, ⌃⌥→ on a mail app, on a display 1920 points wide. Their smallest widths are 1188 and 760, which do not fit side by side, and halves do not help. **The one docked first
left the view as a tile.** Those are the welcome coach's own first two keys, and on laptops two ordinary apps are enough: of 112 pairs, sides and displays tried, 46 sent a window
away. macOS alone lets such windows overlap and hides nothing.

**By default nothing that is in view becomes a tile: what cannot fit overlaps.**

## Behaviour

- It is one switch, at the place where the layout decides "this one does not fit, it is the tile". As Arbor ships it says: **it stands at its smallest size, flush with the outer side of its place,
  and hangs over inwards.** The tree, the places, the shares and the ledger of loans do not know of it, and are what they would be with tiles, but for the next point.
- **Room first** (F61), **in two goes.** First F61 as it is: where everybody fits in the end, the gaps are F61's, whatever the setting. Only where somebody would still hang over is it
  done again from the same start, for the least overlap: whoever can have all they need gets it, in F61's order and on its terms; whoever is still short then takes what those who fit can
  spare, the Desktop first, written into the ledger like any loan. So the overlap is the least the windows allow, with or without a column for the Desktop. In that second go "all or nothing" does
  not hold, nor the Desktop's own claim to its smallest width (it is not topped up while a docked window hangs over, or the shares would never come to rest).
- **Nobody pays with their place for the window with the keyboard.** F61's one exception (what was lent to the others goes back for it, and if it takes that they lend what they need themselves)
  holds only with `tile`. That window is in view, and in front, however short its place, and a change of focus moves nothing. It is still served first.
- **After a hand on a gap** whoever hangs over is left as it is, not only the one whose place the hand made short: its person has seen the row and set it, and room made for it at some later
  layout would move the gap they have just put somewhere. It is like any other again once it has room with everything in view and everybody there.
- **Neither of two gives way.** Both stand at their smallest, so the overlap lies in the middle. In a row of three or more the first is flush left, the last flush right, those between
  flush with the left of their places, pushed in as far as it takes to stay inside the view. Columns likewise, top and bottom. Nothing lies under the menu bar or behind the Dock that could lie
  inside the view; one that is larger than the view by less than the gap around it takes of that gap rather than leave the display.
- **A place too small for any window** (under `minimumUsableWidth` × `minimumUsableHeight`) makes no tile either, nor does a group: each window stands at the larger of its known smallest size and
  that, and hangs over. Nobody is asked to go smaller than that. **Only the Desktop can be a tile.**
- **In front** is the window the act names, at that act: every `dock` gives it the keyboard, which brings it forward. Nobody else is raised. Later it is macOS's business: a click or ⌘Tab brings a
  window forward as on any Mac, and **moves and sizes nothing**.
- **The gap** between two that overlap lies under a window: it has no handle there, and nothing is drawn over a window. Where a stretch of it can be reached it has one. The one a hand is dragging
  keeps its handle while it is dragged, and for two seconds more: nobody tells Arbor that the button is up. A hand on it, on a docked window's
  own edge, or `resize`, `grow` and `shrink`, is obeyed as always: the shares move, each window follows as far as it goes, and the overlap grows or shrinks. **No hand makes a tile either.** A
  place that a hand made short stays as it was left (F61, criterion 6); `shrink` still stops at the window's smallest size.
- **It ends** at a layout that something else causes: a neighbour closes or floats, a larger display, an act of the person. No timer. A record of a smallest size that is older than `tileRetryMinutes` is put
  to the window again at such a layout, where it stands (F45).
- **Undo** is one step, back to the frames before the dock. Frame and back, and Show Everything, give the overlap as it was.
- `rotate`, `mirror`, `swap` and `grow` no longer refuse because a window would not fit: they overlap.
- **Said**: "Too wide to stand side by side · they overlap", in a column "Too tall to stand one above the other · they overlap", the first three times in all, at the act that causes it, and only where a window comes to lie
  over another: one that hangs over a gap or over the Desktop covers nobody. Never at a launch or a resume. `dock` replies "…; too wide to stand side by side, so they overlap".
- `state`: the window is docked, not parked, and has `overItsPlaceBy` (width and height). `ascii`: the places as the tree has them, the side a window hangs over drawn with `>`, `<`, `v` or `^`, and under
  the drawing "over its place: w101 Editor by 156"; "hidden:" does not name it. The menu's list of windows has no mark: it is in view.
- **What goes by the places** and not by the frames: what lies beside what (`focus`, `dock` and `swap` by direction, the peek's arrows), whose a point is (a drop), the surface behind docked windows, the minimap.

Not this rule's: a view on a part of the arrangement (what is outside it is out of view because its person asked); tabs behind the one in front; automatic docking, which counts hanging over as "no room:
it floats" (F23), and makes no overlap larger that is there already; pinned and floating windows.

Setting `windowsThatDoNotFit`: `overlap` (default) or `tile`; advanced.

## What it overrules

| where | what it said | with `overlap` |
|---|---|---|
| T20, A05, F01 | a window that cannot shrink to its slot becomes a tile | it hangs over |
| F61, "Nobody in view pays with their place"; criteria 2, 5, 11 | a newcomer that needs more than can be spared is the tile | it, or whoever F61 would have made the tile, hangs over |
| F61, design notes | all or nothing: half a solution helps nobody | what can be spared is taken |
| F61, "When it does not"; criterion 6 | someone who squeezes a window below its minimum gets the tile they asked for | the place is as they left it; the window hangs over |
| F22 | `rotate` refuses if a window that shows would become a tile | it rotates |

## Acceptance criteria

1. The summary's story, by the keys, as Arbor comes: both in view, the editor at (12, 37) 1188 wide, the mail app 760 wide with its right side at 1908, the mail app in front and with the keyboard, nobody raised. As a scenario.
2. The same frames in the other order of docks, with the editor in front.
3. Each window moves once.
4. A click on the one behind brings it forward; no frame is set, no share changes, the view stays.
5. Undo: one step, both at the frames they had before the second dock. Redo: the overlap.
6. The neighbour closes, or floats, or the display is larger: nobody hangs over.
7. An hour passes: no frame is set.
8. A gap dragged, or `resize`, until a place is 300 points short: no tile, the window hangs over by 300, and no later layout widens the place.
9. No handle lies under a window.
10. Two halves without a Desktop between: the one that fits gives what it can spare and the frames are those of 1.
11. Three windows of 900 on 1920; two of 640 high in a column of 1031; eight in a row on 1440: all in view, inside the view.
12. The line three times in all; not at a launch, not at a resume.
13. With `tile`: everything as before, by the tests that were there.
14. Of the 112 pairs of first keys none sends a window out of view.
15. On real apps on a hosted Mac: two that cannot both fit, a picture after each key, a click on the one behind, a picture.
