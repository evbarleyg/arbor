# F02: Animated transitions

Status: done (`feat/F02-transitions`; the pictures of windows have not been seen on a Mac yet, see the Shipped note)
Depends on: F01 (merge after F04 and F09 if they are in flight)

## Summary

Camera moves and layout changes are instant today. TrellisWM animates every
split, dock and close with one 460 ms motion. Moving real windows through the
Accessibility API frame by frame is too slow, so animate stand-ins instead.

## Behaviour

- On a camera move or structural change, every window whose frame changes is
  covered by a stand-in panel that animates from its old frame to its new frame
  over 460 ms with an ease-out (fast start, gentle settle, no overshoot).
- A camera move is a zoom of the whole plane (T43): windows leaving
  the view slide out past the display's edges at their scaled size, and
  windows entering arrive from beyond them. Nothing shrinks or fades in place.
  Structural changes (dock, split, close) move each window from its old frame
  to its new one.
- Stand-ins show a still picture of the window when Screen Recording
  permission is available (ScreenCaptureKit `SCScreenshotManager`), otherwise
  the app colour and icon (as tiles do).
- The real windows are moved to their final frames during the animation,
  hidden behind the stand-ins, and revealed when it ends.
- A new command during an animation finishes it immediately (no queueing).
- A `animationDuration` setting (seconds; 0 disables) and macOS "Reduce
  motion" (`NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`) both turn it off.
- Nothing is recorded or stored; pictures are discarded after the animation.

Changed on 2026-10-14 by the documenter, after watching the site's
simulation (T43): windows leaving or entering on a camera move
follow the plane instead of shrinking toward their parent, and the curve is an
ease-out rather than ease-in-out. If a branch already implements the old
motion, merge it as it is and do the plane zoom as a follow-up; do not hold a
finished branch for this.

**Decided on 2026-10-14 by the product owner (QUESTIONS Q15, Q18):** Arbor never asks for Screen Recording by itself and `windowPictures` stays false, so colour and icon is the look that ships: the motion is judged in that
look first, and with pictures as a second look. Criterion 4 ("Manual") is replaced by the board's row for the motion train: a film from a hosted Mac, read by the detectors and judged against the polish rubric.

## Design notes

- Extend `OverlayPresenter` with `animate(_ transition: Transition)` where
  `Transition` lists `(window, from, to, style)` items; `FakeOverlays` records it.
- `Controller.relayout` knows the old frames (`windows[id].frame`, parked set)
  and the new layout; compute the transition there before applying frames.
- **Projected frames** give the plane zoom without a per-frame camera model
  (F16 adds that). Lay the tree out once at the root with no tiles and nothing
  parked; a camera's transform maps its node's frame in that root layout onto
  the display's visible frame (a scale on each axis plus an offset). A
  window's projected frame under a camera is its root-layout frame through
  that transform. A window that is parked or tiled at one end of the move
  uses its projected frame at that end: leaving the view, it animates to its
  projected frame under the new camera, which lies partly or wholly beyond the
  display edge on its node's side; entering, it starts from its projected
  frame under the old camera. Windows on screen at both ends use their real
  frames. Put the projection in ArborCore so it is unit-tested.
- New `Sources/ArborKit/UI/TransitionAnimator.swift` with Core Animation on
  borderless panels (reuse `OverlayPanel`). Screen Recording is optional:
  check `CGPreflightScreenCaptureAccess()` and never prompt on your own.

## Acceptance criteria

1. Scenario tests: zoom, back, dock and close each produce a transition with
   correct from/to frames for every window that moves; a window leaving the
   view on a zoom animates to its projected frame, beyond the display edge on
   the side where its node lies (a window right of the new camera ends past
   the right edge), and a window entering starts from its projected frame.
2. With `animationDuration: 0` no transition is produced.
3. Final window frames are identical with and without animation (existing tests unchanged).
4. (was "Manual"; board, section 5) A hosted Mac films `shots-F02.sh` with the stage's own log of frames. Measured: length, curve, cadence, hand-over, nothing stray (`docs/VIABLE.md`, section 8), also with ⌃⌥Space twice in quick succession. Judged from the film against `docs/POLISH.md`: no flicker, one motion.
5. `make check` passes.

## How motion is measured

Motion is judged from what an unattended run on a Mac brings back. While a trace is recorded, each stage logs what it was asked to play and where every stand-in is drawn at every tick of the
display; `arbor-sim stage-judge` measures each motion from that. The lines, what is measured, the limits and what the log cannot show are in docs/TRACES.md, "The stage's log".

- **Linux proves** (`make check`): the lines, their writer and reader, and that no word can get into one (`StageLogTests`); the judge, on logs of a good motion and of each fault (`StageJudgeTests`, `StageJudgeReviewTests`); when
  lines are written and when none, that they are not thinned, keep their time and are skipped by a replay (`StageLogTraceTests`); the way through a trace file, rehearsed (`scripts/sim-smoke.sh`).
- **A Mac runs**: any Mac shell script that records a trace while Arbor animates (`ctl trace on <name>`, the commands, a second's wait, `ctl trace off`, as `scripts/mac-shell/trace-demo.sh` does) and brings the file back; well under ten
  minutes. `scripts/mac-shell/shots-F02.sh` is the one that is to do so, with eight windows at 0.46 s. Only `UI/StageSampler.swift` runs there alone: a display link while a stage is up and a trace is recorded, and the reading of the layers. It has
  no window and no view, moves nothing and takes no event. **It has never run on a Mac.**
- **Judged afterwards**: the trace, through the judge, by anybody. Steps in brightness, dropped frames and whatever else only the screen shows are judged from films.

## Shipped (2026-10-14, `feat/F02-transitions`)

**An option since 2026-10-15: `animationDuration` ships 0** (`collab/QUESTIONS.md`, Q29): windows go to their places at once, and nothing stands in for
them. No stage is put up and none is got ready; the apps' colours and icons still are, for the tiles. The motion comes back as a default only with pictures of the windows that are ready.

Shipped: the plane (`Plane`, `PlaneMap`), the plan (`Keyframe`, `Transition`, `TransitionPlanner`), the
controller's side (`Controller+Transitions.swift`), `animationDuration`, `OverlayPresenter.animate` and
`finishAnimations`, `transitions` in arbor-sim, and the macOS presenter: one stage per display
(`UI/Stage.swift`, `UI/StageDirector.swift`) and still pictures (`UI/WindowPictures.swift`). On a real Mac
(GitHub's, macOS 26.6) the stage was filmed with app colours and icons: docking, zooming in and out, a
neighbour, a refused slot, a tile, the Desktop, a second command in mid-motion, a click in mid-motion,
the setting at 0 and "Reduce motion" (`collab/evidence/2026-10-14-F02-mac-shell.txt`, `collab/evidence/screens/`).

Different from the text above, each with its reason in `collab/QUESTIONS.md` ("Decided by the executor"):

- One full-display stage with a layer per window, not a panel per window.
- The plane is laid out at the two cameras' common ancestor, not always at the root, so that whatever is
  on screen starts exactly where it is. From or to Show Everything the two are the same.
- A window in a tile starts and ends at its place in the tile, as the tile draws it, not at its projected frame.
- A projected frame that is still on the display (behind the Dock or the menu bar, in the outer gap) is slid
  on until it is off it.
- A new command does not finish the motion: it carries on from where things are. A click finishes it.
- Pictures are kept between motions, in memory only, because a motion cannot wait for one.

Not shipped, or not proven:

- **Pictures of windows have not been seen working.** Their first run on a Mac crashed (a colour that
  ScreenCaptureKit does not retain); that is fixed, and they have not run on a Mac since. Everything
  else about the stage was seen with `ARBOR_NO_PICTURES=1`. So they ship off (`windowPictures`, false): no picture is taken,
  whatever macOS allows, until somebody has seen them work.
- Asking for Screen Recording permission (F10's onboarding; `WindowPictures.isAllowed` is there for it).
- The background and caption of a group's or the Desktop's tile are not drawn on the stage, only the windows in it.
- Windows Arbor cannot see (dialogs, sheets, panels, picture-in-picture, its own settings window) are
  covered for the length of the motion.
- A window sent to another display by command stays put on the stage of the display it leaves.
