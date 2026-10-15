# F54: Write an arrangement as a line of text

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done
Depends on: F01; gives I2 (presets) a format people can read, edit and share
Size: small to medium, all of it in the core
Rank among "what would make people recommend it": 5

## Summary

An arrangement is a tree, and trees have a natural one-line notation. Being able to type one, keep it in dotfiles, bind it to a key and paste it into a chat is the kind of thing that gets a tool passed around. `ascii` already draws the tree as
text; this is the way in.

## Behaviour

```
arborctl layout "Safari | Desktop | (Mail / Notes)"
arborctl layout "Xcode:2 | (Simulator / Terminal)"
arborctl layout "[Safari Chrome] | Slack"
arborctl layout                      # prints the current arrangement in the same notation
```

- `|` puts spaces side by side, `/` one above the other, `( )` groups, `[ ]` makes a tab group, `:n` is a relative size (default 1), `Desktop` is the Desktop (added at the right, at `arrangeDesktopWeight`, if not mentioned).
- A name is an app name or bundle id, in quotes if it contains spaces or punctuation. It takes that app's windows in most-recently-focused order: the second `Safari` takes the second window. `Safari*` takes all that remain, as tabs.
- Apps with no window are skipped and reported ("arranged 4 windows; no window of Mail"); with `--open` they are launched and join when their window appears (I2's behaviour).
- Windows not mentioned float.
- It applies to the display under the pointer; `layout @2 "…"` names another. One step for undo (I3).
- Mixing `|` and `/` without brackets is an error that shows where: `Safari | Mail / Notes`, "put brackets around one of them".
- Works in `bindings`, rules' future `then`, URLs (percent-encoded) and presets: a preset is a name and such a line per display.

## Design notes

- `LayoutNotation` in ArborCore: `parse(String) -> Spec` (a tree of names, weights and kinds), `Spec.resolve(windows:) -> LayoutTree`, and `LayoutTree.notation(names:) -> String`. Pure, with a round-trip property test on random trees.
- Same-axis nesting is flattened by the tree's own invariants, so `(A | B) | C` prints back as `A | B | C`.

## Acceptance criteria

1. Each example above produces the expected tree; printing and parsing it again gives the same tree.
2. Errors name the column and what was expected.
3. Two windows of one app are placed in focus order; `*` collects the rest.
4. Missing apps are reported and their slots closed up; invariants hold.
5. `layout` with no argument prints a line that recreates the current arrangement.

## Shipped / Not shipped

Shipped (2026-10-14, `feat/F54-layouts-as-text`): everything under Behaviour, and all five acceptance criteria. The guide is `docs/LAYOUTS.md`; every example in it is run by a test.

Beyond the spec, each because something above needs it:
- **A number is a window** (`412`, `w412`), and `layout --ids` prints them: with two windows of one app, only that recreates the arrangement exactly (criterion 5).
- **`Safari~Inbox` prefers a title**, and `layout --titles` prints them, so that a line can say everything a preset has to (I2). Titles are never printed unasked and never logged.
- **Names are forgiving**: after the exact name or bundle id come the last part of the bundle id and whole words of the name. The spec's own `[Safari Chrome]` would otherwise find nothing: the app is called Google Chrome.
- Options and `@display` go anywhere around the line; curly quotes from chat apps are read; a quote written twice stands for itself.

Different from the spec:
- `Spec.resolve(_:)` gives the windows of each slot and what is missing, and `Spec.tree(filling:)` builds the tree, instead of one `resolve(windows:) -> LayoutTree`: `--open` and presets need the step between.
- If nothing in the line is found (and nothing is being opened), the command fails and changes nothing, instead of floating everything.
- From a URL, `--open` and a line that names no window are refused unless `allowAllURLCommands` is on.
- The Desktop that is added is wider than `arrangeDesktopWeight` says when windows float on it and it would otherwise be too narrow to use.
- Saved views, names (F20) and history are kept where their spaces still hold the same windows, rather than cleared as `arrange` clears them. What goes with a space that the line takes apart is said in the reply.
- Brackets that are written are kept, also in the direction of the group around them (`A | (B | C)`), marked as a group that was turned is (`Keeps.turned`, F62). The product owner's measure: what Arbor prints, read back, costs nothing, no group, no name, no saved view (`whatIsPrintedAndReadBackCostsNothing`, with `--ids`). A group that comes to run like the one around it because a missing app's place closed up still joins it. The Desktop that is added counts such a group for the places it shows, so the brackets change nobody's share of the room; frames differ by a few points, because the gap inside comes out of the group's own room, as for every kept group (F62). Brackets that are all there is of a row, because the app beside them is not open, are brackets still: the Desktop is added beside them, the whole has the row's number and they have their own, so that whoever looks at everything still does when the window arrives.
- A window's number is written once: "layout, column 7: window 101 is already in this arrangement", like a second Desktop. It used to be left out in silence. A `Spec` that is given a number twice by another road than the parser holds it once, so that every value can still be written and read back.
- A line that docks a window that was kept in view, or that came and went with `summon`, says so, in the reply by its number and on screen by its app's name, as a loss that ⌃⌥Z takes back.
- For one line a window is given one frame, the one it ends at. Floating windows are moved by the layout alone, which `layout` tells that the docked space is all new. So "on the Desktop" means after a line what it means after every layout: out to the edge of the screen where nothing is docked beside the Desktop, and a window its user left hanging over that edge goes on hanging.

Not shipped: a way to write a named group that is down to one window (F62): brackets around one thing are that thing, so read back the name is that window's place's, and if the place has a name of its own one of the two goes, which the reply says (`aNamedGroupThatIsDownToOneWindowIsWrittenAsThatWindow`). A group that stood only because the view was on it, printed and read back, stays when the view has left it, like any brackets that are written: a round trip can add a group. Also not shipped: rules' `then` (it does not exist yet); presets (I2), which get `LayoutNotation.Spec` (Codable as its line) and `WindowSlot.assign` to build on. "One step for undo" comes with I3, whose recording wraps every command.
