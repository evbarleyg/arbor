# F25: Options per display

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done (headless; the two macOS-only places that read a display's name and kind type-check on Linux and have not been compiled on a Mac yet)
Depends on: F01, F08
From: IDEAS I6

## Summary

One `gap` and one tile size serve every display. A gap that looks right on a laptop is lost on a 27-inch display, and a space
too small to use there would be a comfortable window on the laptop. `settings.json` can now say what differs where.

## Behaviour

`settings.json` gains an optional `displays` list. The first match wins, as for rules, but key by key: on a display each key has the value of the
first entry that matches the display and sets that key.

```json
"displays": [
  { "match": "builtin", "gap": 8 },
  { "match": "Studio Display", "screenEdgeBand": 24 },
  { "match": ">=2500", "gap": 16, "minimumUsableWidth": 300, "minimumUsableHeight": 200 }
]
```

- `match`, required, is text:
  - `main`: the display with the menu bar;
  - `builtin`: a laptop's or an iMac's own display;
  - `>=2500`, `>2500`, `<=1800`, `<1800`: the display's width in points compared with a number;
  - anything else: the display's UUID (whole, ignoring case), or text its name contains (ignoring case). `arborctl displays` shows both.
  - not a display's number (`2`, `@2`): numbers change with the arrangement of the displays. Such an entry is skipped, with that reason.
- The other keys replace the general settings of the same names on the displays that match: `gap` (0 to 100),
  `minimumUsableWidth` and `minimumUsableHeight` (0 to 1000), `screenEdgeBand` (0 to 100). A key an entry leaves out comes from the next
  entry that matches and sets it, or stays as it is everywhere. So a particular entry goes before a general one and need not repeat it.
- Unknown keys are ignored. An entry that cannot be read (no `match`, a comparison without a number, a value that is not a number or is
  out of range) is skipped, logged, and listed with its reason by `arborctl displays`; the others still apply.
- What a display *is* decides, not which one it was: when the lid closes and the external display becomes the main one, `main` matches it.
- `reload-settings` lays every display out again with its options.
- `arborctl displays` (a new query) lists every display, counted as `@2` counts (the main one, then from left to right and top to bottom), with its name, size and id,
  each value in effect and the entry it comes from.
- `set gap 20` (F12) changes the general value; the reply, and `get`'s, says which displays keep their own: "gap = 20 (was 12); Built-in Display keeps 8 (`displays` in settings.json)".

## Design notes

- `ArborCore/DisplayOptions.swift`: `DisplayOptions` (an entry), `DisplayMatch` (parsed from and written as its text),
  `DisplayTraits` (what a match goes by), and `DisplayOptionsList`, which reads the list entry by entry as `RuleList` does.
- `Settings.applying(to: DisplayTraits) -> Settings` returns the settings in effect on a display. `layoutOptions` and `dropOptions` are then
  read from the result as usual, so a key another feature adds to them keeps working, and making it settable per
  display takes one optional property, one line in `applying`, one in `keysSet` and one in `init(from:)`.
- `Controller.options(for: DisplayID) -> Settings` (`Controller+DisplayOptions.swift`) is the one way to options for a display: `layout(of:)`,
  the drop resolver, the drop preview, the keyboard dock's trial layouts, `arrange`, `float-all`, `shutdown()`, the slack around the Desktop for floating
  windows, the focus ring's room in the gap and the simulator's `expect fills` all go through it.
  **New code that lays out or hit-tests a display must too**, never `settings.layoutOptions` directly; a test reads the controller's sources and names the line that does.
- `DisplaySnapshot` gains `name` and `isBuiltIn`, with defaults; `AXWindowSystem` fills them from `NSScreen.localizedName` and `CGDisplayIsBuiltin`.

## Acceptance criteria

1. Two displays with different `gap`s are each laid out with their own, around the edges and between windows; a framed window too.
2. A space that is a tile on one display is a window of the same size on another with a lower `minimumUsableWidth`.
3. The drop preview is the frame the window lands in, on either display; a window dragged across takes the destination's gap.
4. A pointer inside one display's `screenEdgeBand` and outside another's docks on the first only.
5. `float-all` and quitting put a window of which Arbor does not remember where it floated (F48) where that display's own gap puts it.
6. For each key the first matching entry that sets it counts; a key none of them sets keeps the general value; a display no entry matches uses the general settings.
7. `main`, `builtin`, the four comparisons, a UUID and part of a name match as described; `match` round-trips through its text; a display's number is refused in words.
8. Bad entries are skipped with a reason; the other entries and the rest of the file still load. Unknown keys are ignored.
9. Old `settings.json` files load; `displays` survives being saved and loaded.
10. `reload-settings` applies edited entries at once; a display that becomes the main one takes `main`'s options.
11. `displays` lists each display, each value in effect, the entry it comes from and the skipped entries, and answers before Arbor has started.
12. No file of the controller reads one of the four keys, `layoutOptions` or `dropOptions` from the general settings.
13. `make check` passes.

## Shipped

- Everything above. Tests: `ArborCoreTests/DisplayOptionsTests.swift` (matching, decoding, skipped entries, round trips) and
  `ArborKitTests/DisplayOptionsScenarioTests.swift` (a 1440×900 built-in display beside a 2560×1440 one; one or more scenarios per criterion).

## Not shipped

- Only the four keys that exist today and depend on the display. Candidates when they land: the tab strip's height (F04), the backdrop (F15).
- `set` (F12) does not reach into the list; it is edited by hand. `set gap 20` changes the general value, and a display whose entry sets `gap` keeps its own; `set displays …` is refused in words; `settings` and docs/SETTINGS.md list the key. No command changes it, so when Arbor saves another setting the list stays as it was written, entries Arbor could not read included.
- The focus ring's own options (F37) and whatever else is drawn are the same on every display.
- Real displays: names and `builtin` come from macOS and have not been seen on a real Mac.
