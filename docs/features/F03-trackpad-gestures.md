# F03: Trackpad pinch and pan

Status: done except manual check (headless parts tested; pinches posted by a script reach the tap on a real Mac and are claimed, swallowed and stepped as specified, `scripts/mac-shell/input-taps.sh`, 2026-10-14; no pinch from a real trackpad has been tried, so that waits for a person at a Mac)
Depends on: F01

## Summary

TrellisWM zooms with a pinch: ⌥-pinch anywhere, or pinch on bare wallpaper.
Pinching in steps the camera in toward the pointer; pinching out steps out.

## Behaviour

- ⌥ + pinch anywhere: the gesture goes to Arbor, not the app under the pointer.
- Pinch on the Desktop (no window under the pointer) works without ⌥.
- Pinching in past a threshold (default magnification 0.25) runs `in`;
  pinching out past it runs `out`. One gesture can step several levels, one per threshold crossed.
- A setting `gesturesEnabled` (default true) and `pinchThreshold`.

## Design notes

- A pure `GestureInterpreter` in ArborCore: feed it magnification deltas and
  gesture phase (began/changed/ended), it returns commands. Unit-test it.
- `Sources/ArborKit/Input/GestureTap.swift`: a `CGEventTap` (requires the
  Accessibility permission Arbor already has) listening for gesture/magnify
  events (`NSEvent(cgEvent:)`, type `.magnify`), checking ⌥ or "pointer over
  the Desktop" (no on-screen window under the pointer in CGWindowList, layer 0),
  swallowing handled events, and re-enabling the tap on
  `tapDisabledByTimeout`.
- Wire it in `ArborApp.startController()`, off when `ARBOR_NO_HOTKEYS` is set.

## Acceptance criteria

1. Interpreter: thresholds, multi-level steps, and phase handling are unit tested.
2. Interpreter emits nothing for magnification below the threshold.
3. (was "Manual"; board, section 5) On a hosted Mac, pinches posted by `witness.swift` (`input-taps.sh`): ⌥-pinch in on a window frames it; a pinch out on the wallpaper shows everything; a pinch without ⌥ reaches the witness window, no more than 10 ms late (`input-held`). No hosted Mac has a trackpad: the guide says "tried with posted gestures", and nothing about the feature's safety rests on real fingers: every gesture, cancelled ones too, ends with real windows where a command would put them.
4. `make check` passes.

## Shipped

- Direction: spreading two fingers (positive magnification, the gesture that
  zooms in in Maps and Photos) runs `in`; pinching them together runs `out`.
- `ArborCore/GestureInterpreter.swift`: one `in` or `out` per `pinchThreshold`
  of travel, so one pinch can step several levels or reverse; travel starts
  from zero each gesture; whether a pinch is Arbor's is decided when it begins
  and holds until it ends, so a pinch is never split between Arbor and an app.
  A threshold that is not a positive number means 0.25, and anything below
  0.05 is raised to 0.05. Unit tests in `Tests/ArborCoreTests/PointerInputTests.swift`.
- `Input/EventTap.swift`: the session event tap shared with F05, on a thread
  of its own since B3. Events pass unchanged unless a handler swallows them;
  when macOS switches the tap off it is switched back on and its owner
  resets, unless that keeps happening: after three times in ten seconds, counted over all
  of Arbor's taps, all of them are left off for thirty (`TapHealth`).
- `Input/GestureTap.swift`: taps CG gesture events (type 29) and lets
  `NSEvent(cgEvent:)` pick out the magnify events. A pinch goes to Arbor and
  is swallowed when ⌥ is held as it begins, or when no app's window is under
  the pointer (the Desktop, a gap between windows, or one of Arbor's tiles;
  a menu, the menu bar and a floating palette count as an app's:
  `PointerSurface`); all other events go to the app. A rotation that begins
  during a pinch of Arbor's is swallowed with it. Commands run after the tap
  callback returns.
- `Input/PointerInput.swift` checks once a second, while a tap is installed,
  that Arbor still has Accessibility permission (`AXIsProcessTrusted()` and a
  throwaway tap), and removes both taps at once if not, because losing the
  permission with an active tap installed has been reported to stop all
  input on macOS. They come back when permission does.
- 2026-10-15 (Q26): `pointerGestures` is the one switch above this and every other gesture that needs an event tap. Off, `Controller.inputSettings` leaves the taps nothing to ask for. It ships off.
- Settings `gesturesEnabled` (true) and `pinchThreshold` (0.25), applied at
  launch and on every settings change (`reload-settings`): the tap is
  installed only while gestures are on.
- Started from `ArborApp.startController()` through `Input/PointerInput.swift`
  and updated from `Controller.onSettingsApplied`; skipped when
  `ARBOR_NO_HOTKEYS` is set, stopped first on quit.

## Not shipped

- Pan: the title mentions it, but this spec defines no pan behaviour.
- A rotation the app saw begin before Arbor's pinch began stays with the app.

## Needs manual check

On a Mac with Accessibility granted to Arbor:

1. ⌥ + spread over a window steps in toward the pointer until that window is
   framed; ⌥ + pinch steps back out.
2. Without ⌥, pinching on the wallpaper or in a gap between docked windows
   steps out until everything shows; spreading there steps in.
3. Without ⌥, pinching over Safari or Preview zooms the page, and Arbor does nothing.
4. Pressing or releasing ⌥ halfway through a pinch does not hand the pinch
   from the app to Arbor or back.
5. With `ARBOR_DEBUG=1`, each pinch logs "pinch began (NSEvent phase 1)" and
   "pinch ended (NSEvent phase 8)", saying whether it was Arbor's. No
   "pinch event without a phase" lines should appear: they would mean macOS
   does not report phases to taps.
6. Two-finger scrolling, swipes between pages and pinching in apps feel as
   quick as without Arbor, including while Arbor rearranges windows of an app
   that is slow to answer (one showing the spinning cursor).
7. Mission Control, App Exposé and Launchpad gestures behave as without Arbor.
8. With Arbor running, switch it off in System Settings → Privacy & Security
   → Accessibility, then remove it from the list: the mouse, trackpad and
   keyboard keep working, and `arbor.log` says the taps were removed. Adding
   it back reinstalls them.
