# The demo film

A drawn Mac desktop on which the windows are moved by Arbor's real code. No Mac is needed to make it: Linux, Swift, Node with Playwright's Chromium, ffmpeg, and the fonts Inter and DejaVu Sans.

```bash
demo/make.sh demo/out            # demo/out/arbor-demo.mp4 (1920 × 1080, 60 frames a second, H.264), arbor-demo-short.mp4, arbor-loop.webp for the README
demo/make.sh demo/out --stills   # instead: a picture every second, to look at
```

| | |
|---|---|
| `STORYBOARD.md` | The story, shot by shot, the captions, the text for a voice, and the rules the film keeps |
| `film.txt`, `short.txt`, `loop.txt` | The same as scripts for `arbor-sim film` ([docs/FILM.md](../docs/FILM.md)): what the person does, and `expect` lines that hold every caption to the truth |
| `icons/` | The apps' icons as Arbor samples them, so that the colours of covers and tiles are the ones Arbor takes from them. `render/icons.mjs` writes them |
| `render/scenery.js` | What is not Arbor's: wallpaper, menu bar, Dock, icons, window frames and contents, the pointer. All of it our own drawing |
| `render/paint.js` | What is Arbor's, painted from the frames as the app's own views paint it, view by view; and the band under the display |
| `render/timeline.js` | Captions, key caps and the end card over time |
| `render/render.mjs` | Pictures in headless Chromium, then ffmpeg |
| `render/audit.mjs` | Holds a film to the storyboard's rules that a machine can check: its length, how long a caption is and stays, that captions and key caps never meet, and what a caption says of places and sizes |
| `render/gallery.html`, `gallery.mjs` | The scenery on its own, at many sizes, to look at |

**How it stays true.** `arbor-sim film` runs a script against the real controller and writes down sixty times a second where every window is, what Arbor draws and how faint it is, where the pointer is
and which keys are down. The painter decides nothing about any of that. If Arbor refuses a line of the script or an `expect` does not hold, there are no frames under the name asked for, and no film. So
the film is made again whenever the trunk changes what it shows, and shows that.

The films themselves are not kept in the repository.
