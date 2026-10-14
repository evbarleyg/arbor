# F20: Named spaces

Written by the executor swarm, 2026-10-14; for the documenter to review. From IDEAS I1.

Status: done
Depends on: F01, F08, F62 (a group keeps its identity). Works with F04, F10, F19, F24, F26, F27, F40, F56
Size: medium

## Summary

A saved view is a number, and nine numbers are hard to keep apart: was Mail on 3 or on 4? People think of their
spaces as "Writing", "Review", "the call". So a space can have a **name**: give it one with ⌃⌥N, and go there
from anywhere with `go Writing`, the menu or Go to… (⌃⌥G). Arbor then calls the space by that name wherever
it speaks of it. TrellisWM has saved views only.

## Behaviour

### Giving a name

- `name <text…>` names **the space that fills the view** on the display the command acts on (F56: the focused
  window's display from the keyboard, the one under the pointer otherwise). Any space can have a name: one window's
  place, a tab group, a group, the Desktop, everything.
- **What a name may be.** 1 to 40 characters in any script, emoji included. Capitals are kept as typed and ignored
  when names are compared. Spaces at either end go, and a run of spaces counts as one. So does `/`, which separates
  words in commands and URLs: `Design/Review` becomes `Design Review`. Control characters and invisible formatting
  characters (they can forge a log line or turn text round in a menu) are refused.
- **A direction is not a name.** `go left` means the neighbouring space, so a space cannot be named `left`, `right`,
  `up`, `down`, `top` or `bottom`, nor any other word `go` takes for a direction (`l`, `r`, `u`, `d`, `north`, `south`,
  `east`, `west`). "Left Monitor" is fine: only the whole name counts.
- **One name per space, and each name once per display.** Naming a space that has a name renames it. Giving a space
  a name that another space on the same display has moves the name here. Two displays may each have a "Mail".
- `name` without text, and `unname`, take the name off the space in view. `unname <text…>` takes that name off
  wherever it is: the whole name has to be given (capitals aside), because removing is no place for guessing; the
  acting display is looked at first, then the others.
- The arrangement and the view never change when a name is given, moved or removed.

### Typing a name: ⌃⌥N

- `ask-name` (⌃⌥N; **Name This Space…** in the menu) shows one field in the upper middle of the display, over the
  space it will name. It starts with the name the space has, selected. A line under the field says what ↩ will do, as
  it is typed: which space gets the name, that the name moves here from another space, that an empty field removes
  the name, or what is wrong with the text.
- ↩ runs `name <text>` (or `unname` for an empty field). A name that is refused keeps the field open. ⎋, ⌃⌥N again, a click
  elsewhere, or `ask-name cancel` close it and change nothing.
- While the field is open, `name` and `unname` act on its space, wherever the pointer or the keyboard has gone meanwhile.
- The field belongs to the space it was opened on. It closes by itself when the view leaves that space, when the space or
  its display goes away, when another window gets the keyboard (a click, ⌘Tab, a new window, a swipe to another macOS Space), and when Arbor
  pauses or quits, and when the view begins to be held (F58): no field of Arbor's in front of an audience. The app in front stays in
  front and no window moves.

### Going to a name

- `go <text…>` moves the view to the space of that name. A direction word still means the neighbour (`go` stays an alias
  of `neighbor`); anything else is a name.
- **Which space:** 1. the whole name, capitals aside, on the acting display; 2. the whole name on another display (in
  the order macOS lists them); 3. the only name on the acting display that begins with the text; 4. the only name on
  the other displays that does. If several begin with it, nothing moves and the reply lists them.
- A space on another display is shown **there**: that display's view moves, and the keyboard goes to the window in that space
  that had it last (or the top-left one), so that the next shortcut acts where the user went. The pointer is left alone.
- `back` returns, as after any move of the view. Going where the view already is succeeds and changes nothing.
- A name that waits on a display that is not connected cannot be gone to, and the reply says that this is why.

### What a name stays with

A name means the windows that were in the space when it was named, and whatever joins them.

- **A named group is kept** (F62): it does not dissolve into the group around it when its neighbours leave, and it stays a
  group when it is down to one window, so that the next window docked there is inside it again.
- **What is docked at an edge of the view while a named space fills it joins that space**, on whichever edge. F62 groups the
  newcomer with what was in view and leaves the view on that group; the name goes along. Someone who is in "Code" and docks a terminal
  below is still in "Code". A saved view of the old group stays on the old group.
- A window docked beside a member lands inside; a window docked beside the whole space from outside stays outside.
- The name of a space that holds a single window (its own place, or a group that is down to it) follows that window when it is docked
  somewhere else, as saved views do. If it becomes a tab in a place without a name, the tab group has the name; a place that has a name keeps its own.
- The only window of a named group has nowhere to go inside its view: moving it with the keyboard is refused, as for a framed window.
- Minimizing, hiding, full screen and other macOS Spaces change nothing: the windows keep their places (F01, F30, F35).
- **When the last window of a named space closes, floats or moves away, the name goes with it.** It is not handed to the group around
  it, which was never called that; an empty space would be something to go to and find nothing. (A space that
  holds the Desktop never empties.) Undo brings the name back together with the arrangement.
- `arrange` and `float-all` build the arrangement anew, so names go as saved views do, and `undo` brings them back. Nobody sees a name go, so
  the reply says it: `arranged 4 windows; 2 names are gone`. So do `layout`, and `float`, `toggle-float` and `exclude` when they take the last
  window of a named space.
- **Undo** (F19) restores names with the arrangement they belonged to. Naming is not itself a step, like saving a view; names
  given since the step are kept if their space still exists.
- **Relaunch, pause and resume:** names are saved in `state.json` with the arrangement, and follow the windows that are matched again. A name waits with a place
  that is kept for a window its app has not restored yet, and goes when the place is given up.
- **A display that is unplugged** keeps its names with its arrangement, and they return with it, also when no window was on it.

### Where names show

- Replies call a named space by its name: `moved to Writing (n5)`, `stepped out to Writing (n5)`.
- `spaces` (a query) lists every name, what the space holds and where it is:

  ```
  Mail      Mail and Calendar (n7)
  Writing   Safari and Notes (n5)      in view
  Music     Music (n3)                 on another display
  ```
- `state`: each display has `names`, from name to node number. `ascii`: the line under the drawing names the space in view, and a
  second line lists the names.
- A tile that stands for a named space is captioned with the name.
- The menu, as `docs/MENU.md` has it: in **Saved Views**, after the numbers, one row per name `go` can reach, ticked when in view; then **Name This Space…**. (An empty field removes a name, so that needs no row.)
- For other features: `Controller.namedSpaces()` (Go to…, F27), `Controller.spaceName(of:on:)` (`watch`, F24; the minimap's
  caption, F26), `Controller.Change.names` for whoever mirrors them.

### Who may run what

- `arbor://go/Writing` and `arbor://go/Writing/Desk` are accepted: they only look.
- `name`, `unname` and `ask-name` are refused from URLs. A page could otherwise put its own words into the menu and the
  replies, delete names, or open a field that takes the keyboard. `spaces` is refused with the other queries.
- While Arbor is paused, `spaces` answers; the others fail as every command does.
- While the view is held (F58), `name`, `unname` and `spaces` work, since they move nothing; `go <name>` and `ask-name` are refused;
  `ask-name cancel` is not.
- **Names are not logged**, like window titles: they are the user's own words (a client, a project nobody should know of), and the log is what
  people paste into a bug report. The log has `go ‹name›: moved to ‹name› (n5)`: the space's number stays.

## Design notes

- `SpaceName` (ArborCore): what a name may be, how names compare, and how a typed text picks one of several. Pure.
- `Workspace.names: [String: NodeID]`, beside `savedViews`: as typed → node. Mutated only through `setName` and `removeName`, which keep both rules
  (one name per node, no two names alike) and tell the tree which groups are kept for `.name`.
- Names follow `Remap.survivor(of:in:)`: like saved views, except that a name never follows a node that was deleted with its last window.
- The named groups, and only they, are kept for `.name` (F62), which is a firm reason: not merged into a parent, not replaced by the last child.
- Reading `state.json`: `names` is optional; an entry that points nowhere, is not a possible name, or repeats a name or a node is dropped with a note that does not quote it.
- The log: `perform` takes every name there was before or is after the command, and the text the command carries, out of the line it logs (`withoutNames`), so no reply has to remember to.
  Whatever logs a space's words without passing through `perform` asks `name(of:on:byName: false)`.
- `Controller+NamedSpaces.swift`: the commands, the lookup across displays, `namedSpaces()`, the menu's rows (`namedSpacesMenu()`), the field's model.
- The field is `OverlayScene.namePrompt`, a model with its frame and every sentence worked out; `NamePanel` (AppKit) shows it and runs commands through `OverlayActions.perform`.

## Acceptance criteria

1. `name Writing Desk` names the space in view; `state`, `spaces` and `ascii` show it; windows and view stay as they were.
2. Text is tidied (ends, runs of spaces, `/`), capitals are kept, and names that are empty, too long, hold control or formatting
   characters, or are direction words are refused with a reason, from the command line and in the field alike.
3. Naming a named space renames it; a name given to a second space on the display moves; two displays can hold the same name.
4. `name` without text and `unname` remove the name in view; `unname <text>` needs the whole name and looks at the acting display first.
5. `go` finds the whole name first, then a prefix that fits only one; several fits are listed; direction words still move to the neighbour.
6. `go` to a name on another display moves that display's view and gives a window there the keyboard; the acting display's view stays.
7. A named group survives its neighbours leaving, and being down to one window; the next window docked at any edge of its view is inside it.
8. The name of a window's place follows the window when it is docked elsewhere; a tab group keeps its name while tabs come and go.
9. The last window closing, floating or moving away removes the name; nothing else takes it over.
10. `arrange` and `float-all` remove names; undo brings them back; a name given after a step survives undoing that step.
11. Names survive a relaunch (with windows matched again), pause and resume, and unplugging and replugging a display; a state file without `names`, or with
    nonsense in it, loads.
12. Replies, tiles and the menu's model call a named space by its name.
13. ⌃⌥N opens the field; ↩ names, renames or removes; a refused name keeps it open; ⎋, ⌃⌥N, leaving the space, another window getting the keyboard, unplugging, pause and quit close it; no window moves.
14. URLs may `go`, and may not `name`, `unname`, `ask-name` or `spaces`.
15. No name reaches `arbor.log`, whichever command's reply speaks it.

## Shipped

Everything above except what follows, on Linux: 140 tests (`SpaceNameTests`, `NamedSpaceCommandTests`, `WorkspaceNamesTests`, `NamedSpacesTests`, `NameFieldTests`), among them random
sessions that check the rules after every step, and the journey `collab/scenarios/F20-named-spaces.sim`.

## Not shipped

- **The field has not run on a Mac.** `UI/NamePanel.swift` (170 lines) and the rows in `StatusMenu.swift` are written and read, not compiled here. `scripts/mac-shell/check-F20.sh` tries them with real keys. A22 says `partial` until it has passed.
- **Go to…** (F27, #77), **`watch`** (F24, #74), **the minimap** (F26) and **the menu bar model** (F10, #73) each have a place waiting for names.
- Names in F54's notation and in presets; names of a display that F52 turns into a guest space. See `collab/QUESTIONS.md`.
