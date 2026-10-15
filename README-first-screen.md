# Arbor

A free, open-source window manager for macOS. Your real windows dock into
nested splits, with the Desktop kept as a space between them, and a camera
zooms between those spaces: frame one window, step out to its group, step
out again to see everything.

Inspired by [TrellisWM](https://trelliswm.app) by Dan Fessler. Arbor is an
independent implementation and is not affiliated with it.

> Status: early. Docking, the camera, tiles, persistence and the command line
> work and are covered by tests; tab strips are on the
> [roadmap](docs/ROADMAP.md). Most of that proof is against a simulated window
> system. The runs on record on a real Mac arrange only Arbor's own test
> windows: by command in every macOS CI run (`make e2e`), and with a real pointer
> and keyboard for drags, seams, window edges, tiles, every default camera
> shortcut, the rectangle (with ⇧⌘, its keys until they became ⌃⌥), URLs, a restart and quitting
> ([evidence](collab/evidence/gestures-latest.txt); [docs/FEATURES.md](docs/FEATURES.md)
> says item by item what is proven how; [docs/RELEASE-NOTES.md](docs/RELEASE-NOTES.md) says it in words, with what is
> known to go wrong). Still untried on a Mac: other apps' windows, pinch, rules, your own shortcuts, a
> second display and Spaces.

**[Install it](docs/INSTALL.md)** from source in three commands.

## What it does

- **Dock**: drag a window to a screen edge to dock it beside everything you can
  see, or hold it over another window's edge for a moment to dock beside that
  window; a preview shows where it will land. Drop it on the Desktop to float it
  again, at the size it had before. Let go anywhere else, where no preview shows,
  and a docked window goes back to its place. Hold ⌘ while dragging and nothing
  docks: the window floats. The keyboard docks too: ⌃⌥⌘ + arrow.
- **The Desktop stays**: windows you have not docked float on the Desktop, between
  the docked ones. They make way when a window docks and go back to where you
  put them when there is room again.
- **Zoom**: ⌃⌥↩ frames the focused window (again to return), ⌃⌥↑ steps out a level, ⌃⌥↓ steps
  in toward the window you are typing in (or pointing at), ⌃⌥Space shows everything, ⌃⌥[ and ⌃⌥] go back and forward.
- **Peek**: hold ⌃⌥Space instead of tapping it. Everything shows while the keys are down; point at a window, or walk to it with
  the arrow keys, and let go: it is framed. One gesture from any window to any other, by where it is.
- **Motion that shows where things went**: every zoom, dock and close plays as one short motion.
  Zooming in enlarges the whole arrangement, so the other windows slide out past the screen edges;
  zooming out brings them back from there. A click ends it at once, a second shortcut carries on
  from where things are, and macOS's "Reduce motion" switches it off.
- **Stay on the keyboard**: ⌃⌥⇧ + arrow moves focus to the nearest window that way, into tiles, on to the
  next space and the next display. ⌃⌥⌘= and ⌃⌥⌘- grow and shrink the focused window, ⌃⌥⌘0 balances the
