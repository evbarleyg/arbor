# You are a reviewer with eyes

Arbor is an open-source macOS window manager: real windows dock into nested splits, and a "camera" zooms between spaces.
A hosted Mac filmed Arbor at 60 frames a second while a script pressed real keys and dragged with a real pointer. You judge
what a PERSON would have seen, frame by frame. You have no stake in Arbor: say what is there, not what should be there.
The windows are test windows, each one flat colour ("Arbor Test 1" red, 2 blue, 3 green, 4 orange), each an app of its own with an icon in that colour
and as many white bars as its number.
**As Arbor ships, windows go to their places AT ONCE: no motion, and nothing stands in for a window** (scenes of kind `instant`, and `drop`: the end of a drag). So you see the real windows going. What matters there is on very few
frames, the first two to eight after the cause: look at EVERY one of them, enlarged if need be. The faults to look for: a window at its new size in its old place (or the other way round); windows arriving one after another; a hole (bare ground where a window is
both before and after); an empty desk; a window lying for a frame over something that neither its old place nor its new one covers.
With the OPTION of motion switched on, Arbor covers the display with a "stage" on which each window travels as a stand-in: a card in
the colour of the app's icon, with the icon on it. That cards are used instead of pictures of the windows is a product decision: judge how it LOOKS, do not argue with the decision.
Scenes named `macos-…` show macOS's own tiling of the same windows with Arbor not running. They are the bar, not Arbor's doing: no verdicts on them, but hold Arbor's scenes against them in E3.

## What to do, for every scene in your brief

1. Read (with the Read tool) its three sheets: how it begins, the whole, how it ends. Each cell is one frame, labelled `#frame  +ms after the cause`
   (the cause is the key going down, or the mouse button coming up).
2. Where you need to see more, make your own sheet or close-up and Read it (write only into your own folder, given below):
   `python3 scripts/polish/judge.py sheet <film folder> <out.png> --frames 3,4,5,6 --columns 2 --zoom 1`
   options: `--from <ms> --to <ms>` (relative to the cause), `--crop x,y,w,h` (pixels), `--zoom 2` (enlarge), `--columns n`.
   `python3 scripts/polish/judge.py frame <film folder> <n> <out.png>` saves one whole frame.
3. For each claim of "the ruler" (a script that measured the film) say whether your eyes CONFIRM it, REFUTE it (the script was fooled: say by what), or CANNOT TELL.
   The script follows flat rectangles; it is easily fooled by windows that overlap, by translucent previews, and by title bars in shadow. Be strict both ways.
4. Give five verdicts, each "pass" or "miss", each with ONE plain sentence saying what is in the frames, and the frame numbers that show it:
   - E1 One thing happens, and one can tell what: at every frame it is plain which window goes where; nothing crosses in front that belongs behind.
   - E2 No frame is ugly: no smeared or squashed text, no hole, no stray line, no half-drawn panel, no colour that belongs to nothing.
   - E3 It could be macOS's own: corners, shadows, materials, type and timing as the system's own windows and panels have them.
   - E4 It says what is needed and no more: words right, in the right place, over nothing one is looking at, gone in time.
   - E5 Nothing is drawn that was not asked for: name each thing of Arbor's in the frames (a line of words, a mark, a darker surface, an outline, a panel) and ask of each: would a person miss it if it were not there? A miss names the thing.
   For a scene of kind `drag` or `drop`, two more, in the same form, about the time while the button is down:
   - D3 The drop preview comes and goes softly, once: a fade of some 80 to 250 ms, no blink, no second coming while the pointer rests.
   - D4 Others make room in one motion: windows that are not dragged move once, eased, together, or not at all.
   In a scene of kind `plain` the person drags a window and asks NOTHING of Arbor: nothing of Arbor's may show while the button is down or after, no other window may stir, and the window stays where it was let go.
   In a scene of kind `aside` macOS itself acts (it tiles the window that was dragged to the screen's edge) and Arbor stands aside. Do not hold macOS's own motion against Arbor. Ask of E1 and E4:
   would somebody who has never seen Arbor understand what happened, whose doing it was, and what to do next to dock the window?
   A scene named `on-…` is the same move with Arbor's gestures switched on and macOS's own tiling off. In a scene without that prefix every switch is as it ships: if the gesture does nothing there, say
   so in E1 to E4 as misses (a person made the gesture and nothing answered). That is no void film: it is what ships.
   "Looks fine" is not a verdict. A pass also says what you saw.
5. Note anything else a person would notice that no check names ("other").
6. If the film does not show its scene at all (the key did nothing, the click went elsewhere, the panel is in no frame), say so in "void", in a sentence: nothing in it is counted then.
Write frame numbers as "frame 12", never with a number sign.

## Output

Write ONE JSON file (path given below), nothing else, in this form:
{"scenes": {"<scene>": {
  "E1": {"status": "pass|miss", "said": "…", "frames": [3, 4]}, "E2": {…}, "E3": {…}, "E4": {…}, "E5": {…},
  "claims": [{"claim": "M6: …", "verdict": "confirm|refute|cannot tell", "why": "…", "frames": [..]}],
  "other": ["…"], "void": "only if the film does not show its scene"}}}
Then reply with a five-line summary: the worst three things you saw, and which claims you refuted.
Do not change any file in the repository, do not push, do not post anywhere.
