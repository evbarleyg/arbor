# Handoff from the maintainer: 2026-10-14, evening (Pacific)

For the product owner first, then the documenter and the executors. Read this before ordering the board tonight.

## What happened

The maintainer used Arbor (build 179) for a working session, then quit it and went back to macOS's
own tiling. Their verdict, in plain words: **for how they work today, macOS's tiling is better than Arbor.** Arbor does
too much by itself, has too many shortcuts, and gets in the way. No release has been made; a 0.9.0 pre-release was
built locally and is on hold until there is a better build.

Everything they said is in `collab/IDEAS.md`, I16 to I25. It is one theme: **Arbor should do less by itself and be simpler.**

| Idea | In short |
|---|---|
| I16 | ⌃⌥A (`arrange`) reached the app in front and did that app's own ⌃⌥A (it archived a conversation), twice |
| I17 | Too hard to work when not every open window can be seen |
| I18 | Bringing a few windows into a docked group should be one step |
| I19 | A double-click to fill the screen while arranged is pulled back (board 1.22, Q22, already decided: Arbor stands aside) |
| I20 | Arbor does less by itself: no Desktop column in Arrange; a dragged window floats unless asked; docking one window does not arrange the others; focus ring was unwelcome; window pictures, not icons, while windows move |
| I21 | A window would not dock on the right while another was minimized (not reproduced in `make sim`; needs a trace) |
| I22 | Fewer, simpler shortcuts: a core of about ten, each ⌃⌥ plus one key, no third modifier |
| I23 | One icon in the menu bar, not three |
| I24 | A newcomer's eval: an agent that knows nothing installs and uses Arbor on a hosted Mac, scored against macOS alone |
| I25 | Measure what a person feels: unasked actions as faults, a baseline without Arbor, a shortcut budget, clashes with common apps, every complaint a test |

## Tonight's ask: an overnight attempt at a better product

1. **Product owner:** reorder the board around this direction. Faults against the seven rules still come first; after
   them, I20, I22 and I23 before any further parity item. Decide what the ten core shortcuts are. Parity stays as a list,
   but it is no longer what "better" means: I25's numbers are.
2. **Instruments first, so the night can be judged without a person:** I25(c), the shortcut and menu bar budget, is a
   single test; then I25(a), unasked actions in `make day`, and I25(b), the same journeys without Arbor. Then I24, in
   its slower form through Git if no API key is granted (asking for one is a question for the maintainer, as money).
3. **Executors:** build the light Arbor against those numbers, one train at a time, as the board says.
4. **By morning:** a five-line plain summary in `collab/reports/`: what changed, what the numbers say against
   macOS alone, what is still rough, and whether a build is ready for a friend to try. The public release stays the
   maintainer's decision.

## Also

- Issue #153: `make check` stops at lint on a Mac whose `python3` is 3.11 (`scripts/test-fast-tests.py`, an f-string
  with a backslash). It was hit again tonight.
- Changing a default reaches nobody who has run Arbor before (Q27, part 2). Defaults changed for the light Arbor need
  that migration to reach the maintainer.
- Changing `arrangeDesktopWeight`'s default alone breaks about seventy tests and documentation examples that print
  `Desktop:0.5`; a branch that tried it was dropped. Do it together with I20(a).
