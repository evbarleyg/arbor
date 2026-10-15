# F55: Zoom with a mouse

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done headlessly (`feat/F55-zoom-with-a-mouse`); the sixty macOS-only lines are neither compiled nor tried on a Mac yet
Depends on: F03 (and F16 when it lands)
Size: small
Rank among "what would make people recommend it": 7

## Summary

Pinch is how TrellisWM and Arbor are meant to feel, and a Mac mini, Mac Studio or docked laptop with an ordinary mouse has no pinch. Those are also the Macs with the big displays Arbor suits best. Their owners get the keyboard only.

## Behaviour

- **⌃⌥ + scroll** anywhere: up steps in toward the pointer, down steps out. One step per notch of a wheel; on a Magic Mouse or trackpad, one step per `scrollZoomThreshold` points of travel (default 40), and momentum scrolling is ignored.
- Scroll on the Desktop, in a gap or on a tile does the same without the keys, as pinch does (T36). Off by default (`scrollOnDesktopZooms: false`): people scroll by accident.
- With F16 the same input drives the continuous zoom.
- The scroll is swallowed only while ⌃⌥, and no other modifier key, is down as it begins: ⌃⌥⌘ and the hyper key stay with the apps and with people. For a wheel ⇧ does not count, because ⇧ is how macOS turns a wheel sideways. `scrollOnDesktopZooms` means without any key.
- ⌃ + scroll is macOS's Accessibility zoom when that is enabled; ⌃⌥ + scroll is not used by macOS.
- `gesturesEnabled: false`, `pause` and F41 turn it off with the pinch.

## Design notes

- `GestureInterpreter` grows a scroll input beside magnification: same claim rule, its own threshold; unit-tested.
- The tap sees every scroll event on the system, so the callback must return at once when ⌃⌥ is not down: read the flags first (B3's rules for tap callbacks apply).

## Acceptance criteria

1. Interpreter tests: notches and continuous travel give the expected steps; momentum phases give none; a gesture claimed at its start stays claimed when the keys go up.
2. Without the keys, over an app window, nothing is swallowed.
3. (was "Manual"; board, section 5) On a hosted Mac, wheel events posted without phases: ⌃⌥ + a notch steps in and out toward the pointer; scrolls without the keys reach the witness, no more than 10 ms late (`input-held`). With macOS's own "scroll gesture with modifier keys to zoom" switched on by script, ⌃⌥ + scroll steps Arbor's view and leaves the screen's zoom alone.

## Shipped / Not shipped

Shipped, on top of F16's input half (#39), which had the scroll tap, `ScrollClaim` and `GestureRouter`:

- `ScrollZoom` (ArborCore): notches and points of travel into steps. One notch is one step whatever acceleration makes of its delta; travel steps once per `scrollZoomThreshold`, both ways; nothing is carried from one scroll to the next.
- `GestureRouter.scroll` takes ⌃ as well: ⌃⌥ as a scroll begins makes it a zoom, and it stays one when the keys go up; its momentum reaches neither the app nor Arbor. A wheel has no beginning: each notch is on its own, so letting go of the keys gives the wheel back at once.
  Travel without phases (drivers that smooth a wheel) steps by the threshold while the keys are held.
- With `continuousZoom`, the same scroll is streamed as the magnification of a pinch that would have stepped as often (40 points are 0.25), and a notch is a whole gesture worth one step. Sideways the same keys slide the view (F16): the way a scroll first moves decides for all of it, a diagonal counts as up or down, and nothing is decided until it moves. Without `continuousZoom` there is nothing to slide, so every scroll with the keys is a zoom. ⌥ alone is never Arbor's (the product owner, 2026-10-14).
- 2026-10-15 (Q26): `pointerGestures` is the one switch above this and every other gesture that needs an event tap. Off, `Controller.inputSettings` leaves the taps nothing to ask for. It ships off.
- Settings `scrollZoom` (default true; normal, beside the gestures), `scrollZoomThreshold` (40; advanced), `scrollOnDesktopZooms` (false; advanced). `gesturesEnabled: false`, a pause, F41 and F63 remove the tap with the pinch's: they all work through `gesturesEnabled` in `inputSettings`.
- ✔ 1: `oneNotchIsOneStepWhateverAccelerationMakesOfIt`, `fingersStepOncePerThresholdOfTravel`, `momentumGivesNoStepsAndDoesNotReachTheApp`, `aScrollClaimedAtItsStartStaysClaimedWhenTheKeysGoUp`. ✔ 2: `withoutBothKeysNothingIsLookedAtOrSwallowed`, `aScrollTheAppSawBeginStaysTheAppsWhenTheKeysGoDown`.
- `witness wheel`, `witness scroll --ctrl`, and a section in `scripts/mac-shell/input-taps.sh`.

Decisions:

- **The direction is the one macOS reports**, after "natural scrolling": what scrolls a page up steps in, as scroll-to-zoom does in Maps on the same Mac.
- **The scroll tap is installed by default, and paused** (the input owner's design). A trackpad sends a hundred scroll events a second for as long as anybody scrolls anything, momentum included; each would wake Arbor, all day, on battery, for something used a few times an hour, and a stalled tap
  thread would freeze scrolling everywhere. So the tap is switched on only while a scroll could be Arbor's (`GestureRouter.scrollTapIsWanted`, tested): ⌃⌥ is down, a scroll of Arbor's or its momentum is in progress whatever the keys do, or, with `continuousZoom`, a pinch of Arbor's is. Two monitors for
  modifier keys (they listen, they are in nobody's way; a global one, and a local one for what goes to Arbor's own windows) switch it with the keys, remembering nothing from one event to the next; the handlers switch it at the ends of pinches and scrolls. It fails the safe way: a busy main thread or secure keyboard entry leave the tap paused, and the scroll is the app's. This serves `continuousZoom` as well.
- With `scrollOnDesktopZooms` the tap is on all the time, every scroll has to be looked at, and what is under the pointer is asked once per scroll, or once per notch: that is a window list each time (0.25 ms, about 3 ms while an app hangs, read under the router's lock; a free-spinning or smoothed wheel sends a hundred or two a second), and one more reason for the default.

Not shipped: a wheel turned sideways does nothing (it is swallowed with the keys held), and so does a sideways stroke without `continuousZoom`; the verdict on what is under the pointer is not kept from one notch to the next. Still to do on a Mac: criterion 3; whether an app that saw `mayBegin` and then nothing keeps its scrollers showing; the cost per scroll event; a real wheel, a Magic Mouse.
