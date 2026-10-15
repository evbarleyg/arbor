# F15: Appearance options

Status: done except the manual look (`feat/F15-appearance`: headless parts tested; built, tested and run end to end on a Mac; nobody has seen it on a screen yet)
Depends on: F01 (and F02 for the options that apply to moving windows)

## Summary

TrellisWM's appearance settings change how arranged windows sit on the
Desktop. Arbor draws nothing behind docked windows today. This spec covers the
options worth matching.

## Behaviour

Each option is a `settings.json` key, off unless stated:

| Key | Effect |
|---|---|
| `dimBehindArranged` (number 0–1, default 0) | Darkens the wallpaper behind docked windows by that opacity, so the docked area reads as one surface |
| `blurBehindArranged` (points, default 0) | Blurs the wallpaper in the same area |
| `appColours` (default true) | Tiles use each app's icon colour; false uses one neutral colour |
| `appColourAmount` (0–1, default 0.25) | How strongly app colour tints tiles and (with F02) moving stand-ins |
| `showSeamHandles` (default true) | Draw a faint line in the middle of each gap on hover |
| `tileStyle` (`"name"` default, `"icon"`) | What a window tile shows: `"name"` is the icon with a caption that says which window it is (the note below says which words); `"icon"` is the app icon alone, as TrellisWM's tiles are (T50) |

- The dim and blur sit in a single panel at the desktop level (below every
  normal window, above the wallpaper), shaped to the union of docked slots
  with rounded corners. It follows layout changes.
- Changes apply on `reload-settings`.

**Decided on 2026-10-14 by the product owner (QUESTIONS Q15; not built yet, on the board):** `tileStyle` ships as `"name"`. A window's tile is captioned with the space's name if it has one, else the window's
title, else the app's name. A tile too narrow for eight letters shows the icon alone; every tile has its caption as its help tag. While the view is held the app's name stands in for the title. A title is drawn and
nothing else: never logged, never in a trace. The measure: two windows of one app can be told apart in the overview without a click.

## Design notes

- Extend `OverlayPresenter.update` with the docked slots (or reuse
  `layout.windowFrames` and tiles) so the backdrop panel can be shaped;
  `FakeOverlays` records it.
- Blur: `NSVisualEffectView` in a borderless panel at
  `CGWindowLevelForKey(.desktopIconWindow) + 1`. Check that it never catches clicks
  meant for the Desktop (`ignoresMouseEvents = true`).

## Acceptance criteria

1. Every key decodes with its default when missing; old settings files load.
2. Scenario tests: the backdrop shape matches the docked slots after dock,
   zoom, float and close.
3. Tile colour follows `appColours` / `appColourAmount`.
4. (was "Manual"; board, section 5) On a hosted Mac, `shots-F15.sh` in light, dark and increased contrast: the pictures are judged against `docs/POLISH.md`; a click and a drag on a Desktop icon under the surface arrive as without Arbor (`input-held`).
5. `make check` passes.

## Shipped / Not shipped

Shipped (2026-10-14): the backdrop (darkening and blur, one rounded surface per display that keeps off the Desktop and lets
clicks through), redrawn tiles, a handle in the gap under the pointer, a drop preview with the windows' own corner radius, and six keys. The keys as built, where they differ from the table above:
`dimBehindArranged` defaults to 0.25; `blurBehindArranged` is an amount from 0 to 1; `showSeamHandles` is `gapHandles` with `"shown"`, `"hidden"` and `"off"`; `tileStyle` also takes `"plain"`.

Not shipped: tint and the Desktop's edge (F36); a blur radius (macOS offers one strength); blur while F02's stage is up; a resize cursor over a gap (macOS takes a cursor only from the active app);
a command or shortcut for the backdrop (⌃⌥B stays reserved); entries in F12's settings schema. Criterion 4, the manual look in light and dark mode, is open until `scripts/mac-shell/shots-F15.sh` has run on a Mac.
