# The demo film: storyboard and script

Two films for somebody who has never heard of a tiling window manager: a short one of 37 seconds and a long one of 68. Version 1 is drawn: a Mac desktop
of our own making, on which **the windows are moved by Arbor's real code**. `arbor-sim film` runs `demo/film.txt` and `demo/short.txt` against the
real controller and writes down, sixty times a second, where every window is, what Arbor draws, where the pointer is and which
keys are down; `demo/render` only paints that. Nothing on the drawn display is animated by hand except what a person or macOS
would do: the pointer, the keys, a window following the pointer while it is dragged, a badge in the Dock. Two things on it are the film's own: a faint ring where
the mouse button goes down, because a click cannot be seen, and three small rings that widen round Arbor's menu bar item when it appears or comes back, because it is too small to be noticed on a phone.

## Rules the film keeps

1. **Only what is on the trunk and works.** Every shot is a run of the real controller, on the trunk of the day the film is rendered. The script holds each caption to the truth with
   `expect` lines; a shot the controller refuses, or an expectation that fails, and there is no film. What a caption says of places and sizes ("puts everything back", "your layout is right back") the script says
   with marks that `render/audit.mjs` holds against the frames. **Never a caption the eye contradicts**, even where the end of the shot bears it out. **Never an act that a fresh Mac contradicts**: whoever installs Arbor because of the film does first what the film
   does first.
2. **It looks as Arbor looks, as it comes.** No setting is changed in any script. Overlays are painted from the same models the app paints from (the drop preview, the handle in a gap, the line on screen,
   Go to…, the menu, the menu bar item), with the app's own sizes, colours and fades; the grounds of its panels are read off pictures of the real app on a hosted Mac. A window is at its place at once: as Arbor
   ships, nothing stands in for a window that moves, and the film glides nothing that Arbor does not.
3. **Nobody's artwork.** Apps are called Browser, Mail, Notes and Chat; icons, wallpaper, menu bar and Dock are our own drawings.
   Nothing of the reference app: not its assets, words, film or page.
4. **The words are a newcomer's.** No caption needs the glossary (`docs/GLOSSARY.md`); where Arbor itself speaks on the display, those are its own words.
5. **Calm.** One idea per caption, one caption at a time, at most 50 characters, on screen for at least 2.5 seconds. No music is needed, no voice is needed.

## The picture

1920 × 1080, 60 frames a second. The drawn display (1440 × 810 points, menu bar, Dock, light appearance) sits in the upper part of the picture,
1600 × 900 pixels, with rounded corners on a quiet dark ground. Below it is a band that belongs to the film, not to the Mac:

```
+--------------------------------------------------------------+
|   +------------------------------------------------------+   |
|   |  menu bar                                     [|||]  |   |
|   |                                                      |   |
|   |                the drawn display                     |   |
|   |                                                      |   |
|   |                       Dock                           |   |
|   +------------------------------------------------------+   |
|   Need room? Fill the screen.      [⌃] + [⌥] + [↩]   |
+--------------------------------------------------------------+
```

- **Left: the caption**, 56 pixels high, white: legible on a phone held upright. Under it, rarely, a note: small and grey, for what has to be said and is not the story.
- **Right: what the hands do.** Key caps with a plus between them, so that they read as one shortcut: they show a moment before they are pressed, go down with the keys, and stay for a second
  and a half; a key that is held by itself, ⌘ during a drag, stands there for as long as it is held. And the words of the menu item that is chosen, from the moment the menu opens, since a menu is too small to read on a phone. A drag needs no sign: it is seen.
- The band never covers the display, so what Arbor itself says low on the display is seen as it is.
- The film never zooms into its own picture: in a film about zooming, a zoom that is not Arbor's would say something untrue.

## Shots

Times are targets; the script's own clock decides. "Says" is what Arbor itself puts on screen, not the film.

Each cut was shown, a still a second at phone size, to viewers who knew nothing and were allowed to read nothing else, and frame by frame to others who looked for faults. The
story was rebuilt after each round.

- The first: the heap never got tidy, a terminal was the hero, four chords in five seconds frightened, eleven seconds of a held view looked like a frozen film, and the last twenty seconds taught three ways
  to be rid of it.
- The second: "had it stopped at 0:37 with where to get it, probably".
- The third and fourth: both knew what Arbor is within ten seconds. Three of the four were most lost at "one step back"; "dock" was a word nobody had taught them; a sentence on the card spoke of zooming,
  which the film had never shown.
- The fifth to seventh. The first "probably", from somebody who likes small utilities, on the long film: "free, harmless, nothing moves unless I ask, it undoes itself". Both who saw the short film: "probably
  not", for one reason: "what does it do that my Mac does not? I do not know." **The short film showed exactly the part macOS has.** All three saw the loose windows shoved aside at the first dock and back
  at the second, under a caption that said "right where it was".

- The eighth to tenth saw the sixth story, below, before it was rendered: three times "maybe". All knew what it is within ten seconds; the gap, and fill the screen and back, were the best of it; the key caps
  "the best thing in the film". All three asked where the two loose windows had gone once the halves covered them (hence caption 4b). Both who saw the long film were lost when a docked window, as tall as the
  screen, was dragged out plainly and ran under the Dock, and both saw it lie in the middle after Quit under a caption that said "back where it was": that shot went, undo came back, and at Quit every window is
  where it was. "The same keys" meant two different shortcuts in one film (hence caption 9). What they said of Arbor's own words on screen, of the menu and of the address is with the product owner.

**Then the product turned** (`collab/QUESTIONS.md`, Q29: less by default), and much of what the strangers had stumbled over went with it: nine keys, each ⌃⌥ and one more; a plain drag is nobody's business but
the person's, and ⌘ held asks Arbor; two docks are two halves; what floats is never moved; nothing stands in for a window that moves, no ring, one icon in the menu bar. Every film made before shows an Arbor that no
longer ships. This is the sixth story, written for that Arbor. Its words are its second set: the maintainer found the first limp (they said what happens; these say what it is good for), and every caption and the card were
written again, shorter, to the same shots, the same timing and the same `expect` lines and marks.

- **It says at once what Arbor does not do** (shot 2): nothing until you ask. That is the worry somebody has about a window manager, and the film shows it: Arbor starts, and nothing moves.
- **The first act is one that a Mac as it comes leaves to Arbor**: two keys and an arrow. No setting of macOS's has to be changed first, so the note of the earlier films is gone.
- **A film whose main shots are what macOS has by key as well argues for macOS.** Halves it has. So the halves take the least time, and the weight is on what it lacks: the gap moves both neighbours, the
  arrangement is then this person's own (about 60 to 40), one window fills the screen, and the same keys bring both back *as they were*. The card says it in words.
- **No word has to be taught.** "Dock" is in no caption.
- **One action to a caption**, the caption first, then the keys, then the result, which is held. Keys never stand under a caption that speaks of something else.
- **Nothing glides.** Windows are where they belong at once, as Arbor ships. The film's calm has to come from its pace: every result is held.
- **It ends on the arrangement**, a tidy one: quit puts every window back where it was, starting again brings the arrangement back.

### The short film (37 seconds): `demo/short.txt`

| # | Time | What happens on the display | Hands | Caption |
|---|---|---|---|---|
| 1 | 0:00 | Four windows in a heap: Browser, Mail, and under them Notes and Chat. Two clicks: one comes forward, the next buries it again | two clicks | **Too many windows. One screen.** |
| 2 | 0:03 | One icon appears in the menu bar. Nothing else changes, and that is held | | **Meet Arbor. Nothing moves until you say so.** |
| 3 | 0:06 | Browser is in front: it takes the left half, at once | ⌃⌥← | **One shortcut. Snapped left.** |
| 4 | 0:10 | A click on Mail; it takes the right half. What was left alone lies where it lay, behind them | click, ⌃⌥→ | **One more. Snapped right.** |
| 4b | 0:13 | The two halves, held | | **Nothing closed. The rest wait behind.** |
| 5 | 0:16 | The pointer goes to the gap; the handle shows under it; the gap is dragged a long way: both follow | drag | **Drag the gap. Both windows resize.** |
| 6 | 0:20 | Mail fills the screen | ⌃⌥↩ | **Need room? Fill the screen.** |
| 7a | 0:24 | The same keys | ⌃⌥↩ | **Hit the same keys…** |
| 7b | 0:26 | Both are back, 60 to 40, held | | **…and your layout is right back.** |
| 8 | 0:29 | The end card | | |

### The long film (68 seconds): `demo/film.txt`

Shots 1 to 7b of the short one, on the same desk, and then:

| # | What happens on the display | Hands | Caption |
|---|---|---|---|
| 8 | ⌃⌥G opens Go to…; `c`, `h`, `a` narrow the list to Chat; ↩: it comes forward from behind the two, where it lay, loose as it was | ⌃⌥G, c h a, ↩ | **Lost a window? Just type its name.** |
| 9 | Chat goes to the right of Mail: three side by side, for which macOS has no key. They are narrow: Mail has no room for its letter | ⌃⌥→ | **Add a third. The others make room.** |
| 10 | Chat is loose again, exactly where it lay; the two have their room again, 60 to 40 | ⌃⌥Z | **Wrong move? Undo it.** |
| 11 | ⌘ goes down and stays down; Chat is dragged onto the lower part of Mail; the preview shows where it will land, for a full second; let go. *Note: No ⌘, no Arbor. A plain drag stays a plain drag.* | ⌘, drag | **Hold ⌘ and drop a window where you want it.** |
| | *Slot A, later: drop a window on the middle of another: tabs* | | |
| 12 | Menu: Quit Arbor; the band says what is chosen, and the caption comes with the result. All four go back, at once, to the place and the size they had in shot 1 | menu | **Quit. Arbor puts everything back.** |
| 13 | Arbor is started again (its icon is back in the menu bar): the arrangement is back, Browser beside Mail over Chat | | **Reopen it. Your layout is waiting.** |
| 14 | The end card | | |

**Left out, and why.** *A call that stays in view*: everybody who saw it in the earlier films remembered it, but Arbor no longer touches which window lies in front, so a loose call lies behind the window that fills the
screen; it comes back with the strip for such windows (Q25). *Show everything* (⌃⌥Space) and *back* (⌃⌥[): with two or three windows side by side there is nothing to see that ⌃⌥↩ has not shown.
*A plain drag*, of a loose window or of a docked one out of its place: it is what Arbor does not do, and a docked window is as tall as the screen while it is in the hand; a note says it under shot 11. *Float* (⌃⌥F): undo and the plain drag do as much. *Pause* (⌃⌥⎋): it is shots 12 and 13 over again. *One step back, spaces within spaces*: the idea that makes Arbor what it is, and three strangers of four were
most lost there; it belongs to the second week, not to the first minute. Everything that ships switched off: it belongs in a second film, for people who already have Arbor.

### The end card (8 seconds, the same in both films)

> **Arbor**
> **Your windows, in order.**
> **Your Mac forgets your layout. Arbor remembers.**
>
> Free and open source.
> Nothing moves until you ask.
> Always a way back.
>
> Find it at
> **github.com/evbarleyg/arbor** *(last, larger, held for four seconds)*

The third line is the answer to "what does it do that my Mac does not?": with it, three readers of three could say why Arbor. The film has shown it by then, in shots 5 to 7b.

### The loop for the README (a dozen seconds, no band): `demo/loop.txt`

Two keys and an arrow, twice; the gap; and undo, three times, which gives every window its own place and size back: the loop ends as it begins, by Arbor's own doing. It has no band, so the keys show on a
strip under the display.

## The voice, if there ever is one (optional track; about 100 words)

> Too many windows. One screen.
> Meet Arbor. Nothing moves until you say so.
> One shortcut, and a window snaps left. One more: snapped right.
> Drag the gap, and both windows resize.
> Need room? Fill the screen. Hit the same keys, and your layout is right back.
> Nothing was closed: the rest wait behind. Lost one? Just type its name. Add a third, and the others make room.
> Wrong move? Undo it. Hold command, and drop a window where you want it. No command, no Arbor.
> Quit, and Arbor puts everything back. Reopen it, and your layout is waiting.
> Your Mac forgets your layout. Arbor remembers.
> Arbor. Free and open source.

## What is open

- **The card promises nothing that is not there on the day.** No download is named: the address stands alone. "You cannot lose a window" is a claim no gate has proven yet: the card says "Always a way back."
- **A loose window that lies behind two docked ones shows through the gap between them**, and a press there is a press on it, not on the gap. So the heap is laid with Notes and Chat where no gap comes to lie.
  Whether the gap's handle should lie in front of what is behind both its neighbours is with the product owner.
- **What was left alone cannot be seen to be left alone**: two halves cover it. The scripts hold it to the truth all the same (`mark still.start`, and `same.start` once a window has filled the screen: for that while Arbor still takes the loose ones out of view and puts them back, unseen), and shot 8 of the long film fetches one of them from where it lay.
- **The call that stays in view** comes back once there is a place for such a window beside the one that fills the screen.
- **What the trunk will change in these pictures**, and the films with it, since they are made again on the trunk of the day: the menu, Arbor's own lines, the drop preview.
- **Version 2** replaces shots with real footage from a hosted Mac where that looks better, keeps the band, the captions and the end card, and fills slot A once it is on the trunk.
