# F36: Appearance leftovers

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done except the manual look (`feat/F36-appearance-leftovers`: headless parts tested; the view code type-checked, not yet built or seen on a Mac)
Depends on: F10, F15
Reference items: T50, T54, T70

## Summary

The keys of TrellisWM's `ReleaseSettings.json` that change only how things look and that neither
F10 nor F15 mentions. None changes where a window goes. Worth doing only once the features they
decorate have been seen on a real Mac.

| Arbor key | Default | TrellisWM key | Effect |
|---|---|---|---|
| `tileIcon` | true | `coverIcon` | false: tiles show colour only |
| `tileFade` | 0.2 | `coverFade` | seconds a tile takes to fade in and out when a node crosses the usable size |
| `tintBehindArranged` | 0 | `tintOpacity` (0.8) | tints F15's backdrop with the accent colour |
| `desktopEdge` | 0.05 | `desktopEdgeStrength` | opacity of a hairline around the Desktop's area, so an empty Desktop between docked windows reads as a space |
| `historyButtons` | true | `historyButtons` | false: F10's menu bar item leaves out back and forward |
| `menuBarFill` | 0.12 | `menuBarFill` | opacity of the fill behind the current view's button |

Not planned, because nobody knows what they do: "Frame" (hidden, no key), `fixedMinimum`, `gesturesLand`,
`tabStripLights`, "Dragging a title bar (a choice)".

## Acceptance criteria

1. Every key decodes with its default when missing, and is clamped to 0...1 where it is an opacity.
2. The values reach `OverlayScene` or the menu bar model, checked in scenario tests.
3. Window frames are the same whatever these are set to.
4. `make check` passes. The gallery's pictures from a hosted Mac in light, dark and increased contrast are judged against `docs/POLISH.md` (was a manual look; board, section 5).

## Shipped / Not shipped

Shipped (2026-10-14, report `collab/reports/2026-10-14-F36-appearance-leftovers.md`): `tintBehindArranged`, `desktopEdge`, `tileFade`.

Not shipped, on purpose: `tileIcon` (F15's `"tileStyle": "plain"` says the same); `historyButtons` and `menuBarFill`, which F10 builds with the buttons they belong to. Criterion 4's manual look is open until
`scripts/mac-shell/shots-F15.sh` has run on a Mac.
