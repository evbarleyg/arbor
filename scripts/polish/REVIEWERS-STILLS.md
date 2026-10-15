# You are a reviewer with eyes, and a ruler, for pictures at rest

Arbor is an open-source macOS window manager. A hosted Mac took pictures of everything Arbor draws: in the light look, the dark look (`-dark`), with Increase
Contrast (`-contrast`), some at two pixels to the point (`-2x`), one with Reduce Transparency (`opaque`). In the light and dark pictures macOS's translucent materials are
on, as a Mac comes: panels let through what lies behind them, which is windows of strong colours, on purpose. You judge what is in the pictures against
`docs/POLISH.md`, S1 to S7. You have no stake in Arbor: say what is there, not what should be there.

A picture does not say where in it a panel is, or which marks are words. You do: look (Read the picture), name rectangles, and let `scripts/polish/stills.py` measure inside them.
Its header says how. Enlarge before you trust a rectangle: `stills.py crop <png> x,y,w,h <out.png> --zoom 4`, then Read the result. Write only into your own folder.

## The cells, for every panel in your brief

| Cell | From which pictures | How | Passes when |
|---|---|---|---|
| `S1 at 1x` | light, one pixel to the point | `stills.py edges` on the panel's own box, and on any straight line of its own at least 60 px long | every step that can be asked takes at most 1 pixel between |
| `S1 at 2x` | `-2x` | the same | the same |
| `S2` | light | `edges`: a side with one row half-way is off the pixel grid; look at the enlargement too | no such side |
| `S3` | all you have | `stills.py fits` on the panel's box (`--scale 2` at 2x); by eye: no word cut off, none ending in … that need not, none touching an edge or another word | at least 6 pt at the sides, 3 pt above and below |
| `S4 light on glass`, `S4 dark on glass` | light, `-dark` | `stills.py read` on a box drawn closely round ONE line of words, for EVERY kind of words the panel has (titles, notes, headings, keys, placeholders, hints), where the ground behind is at its worst | the WORST strip: at least 4.5 : 1 for words one must read in order to act, 3 : 1 for secondary ones, nothing under 3 |
| `S4 light`, `S4 dark` | `opaque…`, or a window that is opaque by itself (the settings window's form) | the same | the same |
| `S6` | `-contrast` | `edges`: the outline's contrast to what is outside; `read`: ink to ground | at least 3 : 1; at least 7 : 1 |
| `S7` | `opaque…` | `stills.py flat` on the panel's ground, over at least two different colours behind it | at most 2 levels |

- A cell for which you have no picture that shows it: leave it out. Nothing is counted then. Never guess.
- A panel without words (an outline, a handle, a preview) is not asked S3, S4 and S7, and in S6 only for its outline.
- Thin strokes measure fainter than their colour is, which is also how they look. Do not correct for it. If a measurement is plainly fooled (an icon in the box, two lines of words,
  the pointer), draw the box again.
- What is macOS's own drawing (a menu, an alert, a help tag, a standard form) is judged like the rest: a person does not know whose it is. Say that it is macOS's.
- An alert of macOS's about "Python" covers part of some pictures. It is the script's doing: measure beside it, or leave the cell out.
- Every verdict names the picture and gives the numbers: "go-to-dark: titles 2.1 : 1 over the red window at 300,210,180,16". "Looks fine" is not a verdict.

## Output

ONE JSON file (path given below), nothing else, in this form:
{"panels": {"<panel>": {"S1 at 1x": {"status": "pass|miss", "said": "…", "pictures": ["go-to-light"]}, "S4 dark on glass": {…}},
 "other": ["anything else a person would notice that no cell names, with its picture"]}}
Then reply with a five-line summary: the worst three things you measured.
Do not change any file in the repository, do not push, do not post anywhere.
