# F16: Continuous zoom and pan

Status: blocked (needs F02 and F03)
Depends on: F02, F03

## Summary

F03 makes a pinch step the camera one level per threshold. TrellisWM goes
further: the whole desktop scales with your fingers, you can pan with two
fingers while pinching, and when you let go the view settles on the space
that fits best. Real windows cannot be scaled frame by frame through the
Accessibility API, so the gesture drives F02's stand-ins and only the settled
result moves real windows.

## Behaviour

- During a pinch (with ⌥, or on the wallpaper) every visible window is
  replaced by its stand-in and the whole arrangement scales around the pointer
  as the fingers move. Two-finger movement pans it (`panSensitivity`, default 1.8).
- On release, the camera settles on the node that best fits what is on
  screen (`Navigation.bestFit` on the scaled view), animating into place.
- Pinching out past the root shows everything; pinching in on a window frames it.
  Past the root, the arrangement keeps shrinking below the display's size,
  centred, with wallpaper around it, while the fingers stay down (see
  T36). Released there, it settles on the root (TrellisWM's demo does not show
  the release; this is Arbor's choice).
- Setting `continuousZoom` (default true once shipped) falls back to F03's steps when false.
- A click or key press during the settle animation ends it immediately.

**Decided on 2026-10-14 by the product owner (QUESTIONS Q15, Q18):** judged with colour and icon first, since that is what ships. Criterion 3 ("Manual: … at 60 Hz") is replaced by the board's row for the zoom train: pinches posted by a
script on a hosted Mac, the stage's own count of frames, a film, the detectors and the rubric. No hosted Mac has a trackpad: what rests on real fingers alone (whether scroll events arrive during a pinch) must not be what the feature's safety rests on.

## Design notes

- Model the gesture's virtual camera (a rectangle in layout space) in a pure
  type in ArborCore, so the scale/pan maths and the settle choice are unit-tested.
- F02's transition presenter needs a "follow" mode where the controller
  streams frames rather than a fixed from/to pair.

## Acceptance criteria

1. Unit tests: pinch and pan produce the expected virtual camera; release
   settles on the best-fitting node, including the root and single windows.
2. Scenario tests: a simulated gesture ends with the same layout as the
   equivalent `zoom`, `in` or `out` command.
3. Manual: motion follows the fingers smoothly at 60 Hz with eight windows open.
4. `make check` passes.

## Shipped: the input half

The model and the motion are still to come. What is there is everything up to the controller's door.

- `Controller.gesture(_ update: GestureUpdate)` (`Controller+Gesture.swift`) is that door. With `continuousZoom` on, the gesture taps
  call it on the main actor. Tests and arbor-sim can call it with plain values, so the model needs no tap to be tested. Until the
  model is there it counts a streamed pinch into F03's steps and ignores the pan.
- `GestureUpdate` (ArborCore): `phase` (began, changed, ended, cancelled), `location` (the pointer at the latest event, global), `magnification` and
  `pan`, each the **sum** since the update before. Every update can carry movement, the first and the last included.
- What the listener can rely on (`GestureStream`, tested, one test with 20 000 events in random order):
  exactly one `began`, then any number of `changed`, then exactly one `ended` or `cancelled`. One update per burst of events, however long the main
  thread was busy: a whole pinch made meanwhile arrives as `began` and `ended`, with the sum in the latter. A pinch and a scroll that overlap are one gesture, from the
  first beginning to the last end. macOS switching a tap off, a pause, quitting, losing Accessibility and a change of the setting all end it as `cancelled`.
  Numbers are finite, and one event moves at most 2.0 of magnification and 2000 points.
- Whose a scroll is (`ScrollClaim`): Arbor's if ⌥ is held as it begins, or a pinch of Arbor's is in progress; decided once and kept to the end.
  The momentum after a scroll of Arbor's reaches neither the app, which never saw the scroll, nor the listener: the view settles when the fingers lift, and coasting would fight that.
  A wheel mouse has no phases and is left to the app, ⌥ or not.
- `GestureRouter` puts these together with F03's `GestureInterpreter`, so the taps only read events and do as they are answered.
- `Input/GestureTap.swift` has a second tap, on scroll events, installed only while `continuousZoom` and `gesturesEnabled` are on, because every scroll on the Mac passes through it. A scroll without ⌥
  leaves after one comparison under a lock, before anything is read from the event.
- Setting `continuousZoom`, **default false** for now, so that this half changes nothing by itself. Whoever ships the model flips it.
- `scripts/mac-shell/witness.swift` posts two-finger scrolls (`witness scroll`), and `input-taps.sh` has a section for all of this.

Not shipped: panning from the two fingers of the pinch themselves (TrellisWM's `touchPinchPan`). macOS reports a pinch and a scroll as separate gestures and may not send both at once; following
the raw touches of the gesture events would be the way. Nobody has tried on a real trackpad whether scroll events arrive during a pinch.
