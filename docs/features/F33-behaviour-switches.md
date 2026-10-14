# F33: The switches TrellisWM has

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done
Depends on: F01 (F12's `set` command makes them reachable without editing the file)
Reference items: T05, T06, T11, T31, T52

## Summary

Five behaviours that TrellisWM lets the user turn off or around
(`ReleaseSettings.json`) are fixed in Arbor and appear in no spec. Each is a
key in `settings.json`, each is headless and testable, and each default keeps
today's behaviour.

| Arbor key | Default | TrellisWM key (default) | Effect |
|---|---|---|---|
| `previewDrags` | true | `previewDrags` (true) | false: no preview while dragging; drops work the same |
| `gapHandles` | "shown" | `deskGapHandles` (true) | "hidden": nothing is drawn in the gaps. "off": the gaps are not handles; `resize` and edge drags (F07) still work |
| `shareRemovedSpace` | true | `shareRemovedSpace` (true) | false: a leaving window's space goes to one neighbour, not the whole row |
| `stepInToward` (built by F56) | "auto" | `stepTowardPointer` (false) | "focus": `in` prefers the space holding the focused window. "pointer": the one under the pointer |
| `shrinkOutOfView` | false | `parkOutOfViewSmall` (false) | true: windows out of view are also shrunk |

## Behaviour

- **`previewDrags: false`**: `overlays.showDropPreview` is never given a frame.
- **`gapHandles: "off"`**: `OverlayScene.seams` is empty. `Layout.seams` is unchanged,
  because `resize` and edge drags use it. **`"hidden"`**: the seams are there and
  `OverlayScene.showsSeamHandles` is false.
- **`shareRemovedSpace: false`**: when a child leaves a split (closed, floated, dragged
  out), its weight is added to the sibling before it, or after it if it was the
  first. The same holds while a window is only absent (minimized, hidden, on another
  Space): its weight counts for that neighbour in the layout and comes back with it.
- **`stepInToward`**: see F56, which settles QUESTIONS Q2 and also chooses the display.
- **`shrinkOutOfView: true`**: `park` also sets the size to 320 × 200. Docked windows get their size
  back from the layout; floating ones from the frame remembered in
  `Workspace.floating`, which parking must not overwrite (it does not today).
  Sizes learned while parked must not count as minimum sizes.

## Design notes

- Settings go at the end of `Settings` as usual.
- `shareRemovedSpace`: `LayoutTree.remove` gets the flag for the permanent case;
  `LayoutOptions` gets it for the absent case, where `placeSplit` sums the weights of
  absent children into the nearest effective sibling. Seams' `pointsPerWeight` is
  per split and does not change.

## Acceptance criteria

1. Every key missing from the file takes its default, and with defaults every existing test passes untouched.
2. One scenario test per switch showing the other behaviour, and for `previewDrags` and
   `gapHandles` that the drop and the `resize` command still work.
3. `shareRemovedSpace: false` in `[a | b | c]`: closing `b` leaves `c` as wide as before and `a`
   wider by `b`'s width and one gap; minimizing and restoring `b` returns all three to their widths.
4. `shrinkOutOfView`: after zoom and back, every window has its old frame.
5. `make check` passes.

## Shipped (2026-10-14, `feat/F33-switches`)

Four of the five switches, each with its default keeping the old behaviour; the fifth, `stepInToward`, is F56's.

- **The keys above are the ones that shipped.** The spec first called them `dropPreview`, `seamHandles`,
  `stepTowardPointer` and `parkSmall`. `previewDrags` is F09's key and TrellisWM's. `gapHandles` and `shrinkOutOfView` use the
  words of `docs/GLOSSARY.md` ("gap", "out of view"). The product owner made `gapHandles` one choice of three values in
  place of this spec's boolean and F15's `showGapHandles`. F15 draws the handle; until then "shown" and "hidden" look alike.
- F56 builds `stepInToward` whole (`"auto"`, `"pointer"`, `"focus"`, and which display a shortcut acts on), so this
  item adds nothing for Q2.
- `shareRemovedSpace` false is exact (criterion 3): summing weights alone would have widened `c` by its
  share of the freed gap, so with the switch off the layout takes each weight to cover a slot and
  the gap after it. See "Who gets freed space" in `docs/ARCHITECTURE.md`.
- `shrinkOutOfView` remembers each window's size for the ways out of the corner that go by the window's own
  size, chooses the corner again for an app that refuses to shrink, and learns no minimum sizes there.
- Found on the way and fixed: after a crash, a floating window that the saved arrangement knew stayed in
  the corner for good, with or without `shrinkOutOfView`. Windows found out of view at launch now count as parked.
- Second round. With `shrinkOutOfView` on, a floating window taken by its sliver while it is small has its own size again when it is let go; it
  stayed small until something else laid the display out. Let go where macOS tiles, it is left to macOS. With `shareRemovedSpace` off, room is made (F61) beside a window that is minimized, hidden
  or on another Space: what a neighbour shows of the reserved place is neither its own to give nor to keep, and of its own slot it keeps a usable
  width, so that it is still a window when the other comes back. The slot a window left in full screen comes back to is worked out with the switch as it
  is set. `lint-share-space.py` reads `Drop.swift` too. Known limits: in a row inside a row that grows, the reserved place grows along and the window is
  not served (it stays a tile; nothing is lost); a docked window taken by its sliver and refused by the place it is dropped on stays small.

Not shipped: nothing in the menu or a settings window (F12's `set` and `SettingsSchema` were not on the
trunk; each of the four keys needs an entry there). arbor-sim has a stand-in `set <key> <value>` until then.
