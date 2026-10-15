# Report: the real Accessibility layer, run on Linux on a model of a rude Mac

- Date: 2026-10-15
- Branch: test/the-real-ax-layer-on-linux
- What: `make mac-on-linux` (scripts/mac-on-linux/README.md; docs/TESTING.md, section 9)

`Sources/ArborKit/AX` ran in no headless test. Now it is compiled as it is, linked with a model of a Mac and run on Linux: 181 stories (707 ✔, 74 ✘ known) and a random walk under four kinds of bad manners, five seconds to run. The run enters 92 % of the lines and 81 % of
the regions of `AXWindowSystem.swift` (`COVERAGE=1`). Nineteen changes that take known cures out of a copy of the layer all turn their stories red (`make mac-on-linux-selftest`).

This report is what it found. Nothing in the layer was changed. Each finding says what a person would see, the lines concerned, and how sure the model is of the manners that bring it out: SEEN on a Mac, or GUESS. Every red check is listed in
`scripts/mac-on-linux/known-failures.txt`; whoever cures one deletes its lines. Line numbers are those of `Sources/ArborKit/AX/AXWindowSystem.swift` at f0d67cc.

| | What a person sees | Needs | How sure |
|---|---|---|---|
| R1 | (cured) a window opened in a running app is filed as open all along | focus reported before creation | seen; red again without the cure |
| R2 | (open) ⌘Tab or a click to another app: the view does not follow | `frontmostApplication` lags the notice | seen |
| N1 | a docked window closes, its slot stays empty, whatever one does | "destroyed" never comes | seen that it can happen; how often unknown |
| N2 | the same for an app that ends without a word, until some layout moves its window | an end nobody reports | seen |
| N3 | two windows of one app in the same place on two Spaces become one | the focus report beats the Space notice | guess as to the order |
| N4 | Arbor pulls at a docked window on its way into full screen | `AXFullScreen` says yes late | lateness seen; what the pull does unknown |
| N5 | **an app that is busy as it is switched to never gets the view; each ⌘Tab to it costs a second** | **nothing: a polite Mac** | the layer's own logic |
| N6 | ⌘T in a docked window makes a second window of it; closing the front tab loses the group | the app's list 10 ms behind | lists lag: seen; at that moment: guess |
| N7 | an app opens a window and gets busy: Arbor is dead for four seconds | three notifications on their way | the layer's own logic |
| N8 | two rare races | | for the record |
| L1 | **a drag of any length is not seen at all; nothing is logged** | the window server a moment late, the pointer more than 24 points away | guess that fits what loaded hosted Macs showed |
| L2 | a flick is not seen | the gesture over before Arbor hears of the press | the layer's own logic |

## Reproductions of what was already known

### R1. Fault (a), cured on the trunk: reproduces when the cure is taken out
Story "a window opens in a running app that reports the focus before the creation". Green on the trunk. With `hasOpenedSince` forced to false in the copy
(`make mac-on-linux-selftest`) the layer reports `found w102, focused w102` instead of `appeared w102, focused w102`: exactly the fault seen on the hosted Macs.

### R2. Fault (c), OPEN on the trunk: reproduces, at both storeys
Stories "⌘Tab to another app, and NSWorkspace names the old app for 5 / 50 ms more", "a click on another window of another app, …", "⌘Tab to an app whose window is
out of view, …". With a fresh `frontmostApplication` all green. Stale: the layer reports only `keyboard moved, keyboard moved`, never `focused`; at storey two the
window with the keyboard stays parked at 1023,673 (the very place seen on the hosted Mac) for the three seconds the story waits.
- Lines: 937 (`guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }`), reached from 475 (`appCameForward`) and 1075.
- NEW DETAIL 1: it is red at a lag of 5 ms too, where the property HAS caught up by the time `AXApplicationActivated` arrives (8 ms after the notice): line 1078 only
  says `keyboardFocusMoved()`, and the controller, which then asks `focusedWindow()` and gets the right answer, does not move the view on that. So a cure cannot
  lean on the controller's handling of `keyboardFocusMoved`; `AXApplicationActivated` has to lead to `reportFocus`, or the notice's own pid has to be believed.
- NEW DETAIL 2: a CLICK on another window of the other app is lost as well, not only ⌘Tab: `AXFocusedWindowChanged` and `AXMainWindowChanged` arrive about 2 ms after the
  press, BEFORE didActivate, when even a well-behaved NSWorkspace still names the old app, so both are dropped at 937; with a fresh property didActivate makes up
  for it, with a stale one nothing does. (Order of the AX reports against didActivate: GUESS from the traces' delays; `drag-onto-window` has the focus report 0.4 ms
  before the mouse-down.)
- A cure that waits for the property should know that nobody has measured how long it lags; the stories hold it to 5 ms and to 50 ms.

## New findings

### N1. A window that closes without "destroyed" stays a ghost, and not even a failed move clears it
WHAT A PERSON SEES: a docked window is closed; its slot stays empty and its neighbour does not get the room. Going on working (click, `show-all`, `zoom`, `show-all`) does not
help. It lasts until the same app opens a window or changes its focused window, or the Space changes.
STORIES: "a window closes and the notification never comes", "the last window of an app closes and the notification never comes" (storey one), "a docked window closes and the
notification never comes" (storey two).
WHY:
- An app's list is read only in `handle` for created / focused / main changed / deminiaturized / shown (1035, 1044, 1066, 1074, 1091), `answersAgain` (531) and a Space switch (576, 585).
  The focus report of a closing window comes 12 ms BEFORE the window goes (trace `close`; a `setFrame` in between still succeeds), so the one rescan it causes still finds the window listed and valid.
- `appCameForward` (469-476) reads the focused window, never the list: leaving the app and coming back changes nothing.
- `setFrame` (222-264): `perform` treats only `cannotComplete` and `apiDisabled` as special (271-275). A closed window answers `invalidUIElement` to both setters, `element.frame` is nil, `gaveUp` → `noteSilence`
  finds that no time passed and the process is alive (495-504) and returns. nil, for ever: "nothing is known", where in fact the app has said plainly that the window is gone.
HOW SURE: that a window can close without the notification is written down as seen (docs/ARCHITECTURE.md "has closed without a notification, and is dropped"; AXWindowSystem.swift 636-639); how often nobody knows. The 12 ms are from a trace.
What a closed window's element answers to a SET (`invalidUIElement`) is the documented behaviour, not measured here.
A CHEAP CURE TO CONSIDER: in `perform`, `invalidUIElement` → `drop(window)` (deferred, as 498 does); and a `rescan([pid])` in `appCameForward`.

### N2. The window of an app that ends without a word stays until some later layout happens to move it
WHAT A PERSON SEES: two docked windows; the process behind one (started from a shell) ends. The window vanishes from the screen, its slot stays empty, the other window keeps its half. Five seconds later: the same.
STORY: "an app with a docked window ends and nothing says so" (storey two). At storey one ("an app ends and nothing says so") the cure works as designed: the first call fails at once, `kill(pid, 0)` says ESRCH, the window is reported gone.
WHY: `noteSilence` (494-505) is reached only from a call, and after the end nothing calls: the app that comes forward instead is reported focused, which needs no layout. HOW SURE: the silence is written down as seen
(docs/ARCHITECTURE.md:837; ledger "an-app-can-end-without-a-word").
TO CONSIDER: when an app comes forward because another has gone, or at `didActivate` in general, `kill(pid, 0)` for the observed pids costs nothing and talks to nobody.

### N3. Two windows of one app that fill the same place on two Spaces are taken for native tabs, if the focus report beats the Space notice
WHAT A PERSON SEES: two browser windows, each filling the view on its own macOS Space (with Arbor that is the normal case: same slot, same frame). Switch Space: Arbor reports `replaced w102 by w101`. The controller hands the first
window's slot and everything it knows about it to the second and forgets the first. On the way back the same in reverse. Both windows now share one place in one tree; whatever differed between the two Spaces' arrangements is gone.
STORY: "two windows of one app fill the same place on two Spaces, and the Space is switched, the focus reported before the notice". With the notice first: green.
WHY: 1070-1075: "focused window changed" → `rescan([pid], afterSpaceSwitch: false)`; the comment at 595-598 knows the danger ("two that fill the same slot on different Spaces would be taken for tabs") and excludes it only for rescans that
KNOW they follow a switch. HOW SURE: GUESS as to the order. The backlog says it is not known in which order the reports of a switch arrive (M1096). The notice is known to come "in the middle of the transition", and an app's key window
changes when its Space comes up, so the focus report has every chance to be first. That the app already lists the new Space's window at that moment is the polite case; if it lists nothing, no harm is done.
TO CONSIDER: `isOnScreen` of the window that left the list does not help (it is off screen either way). The window server could: a background tab and a window on another Space differ in `kCGWindowWorkspace`-like facts only privately; cheaper is to
hold `windowReplaced` back for a moment when the successor was already `counted` (it existed before), and drop it if a Space notice arrives.
WORTH A RUN ON A HOSTED MAC: record a trace of a Space switch between two windows of one app (traces/README.md lists Spaces under "still to record").

### N4. Arbor pulls a docked window back into its slot in the middle of its way into full screen, if `AXFullScreen` says yes late
WHAT A PERSON SEES (model): green button on a docked window; 0.25 s into the animation Arbor sets size, position, size on it (three calls), because the "resized" reports say a docked window has left its slot and `AXFullScreen` still says no.
In the model the transition then ends as it should. What a real transition does when it is pulled at nobody knows.
STORY: "a docked window enters full screen and leaves it, saying so late" (storey two). Saying so in time: green.
WHY: `geometryChanged` (969-992) reads `AXFullScreen` with every resize, gets "no", reports `windowChanged(userInitiated: true)`; the controller enforces the slot. HOW SURE: the lateness is written down as seen (663-664: "the resize reports can arrive
before the window says it is in full screen"). How late, and whether the window takes a frame meanwhile: GUESS.

### N5. An app that is busy as it is switched to is never reported focused, also after it wakes; and each ⌘Tab to it costs the main thread a second   (FOUND BY THE WALK, ON A POLITE MAC)
WHAT A PERSON SEES: ⌘Tab (or the app in front quits) to an app that beachballs for two seconds and whose window is out of view. The window stays at 1023,673 with the keyboard in it, for good. Meanwhile Arbor is deaf for a second; switch away and back three times: three seconds.
STORIES: "⌘Tab to an app that hangs, and wakes two seconds later", "⌘Tab three times to an app that hangs" (3.0 s), "⌘Tab to an app whose window is out of view and which hangs for two seconds" (storey two). Walk: 17 of 300 polite seeds; shortest `arborFocuses 96 4; hang 85 52; dies 24 10`.
WHY: `reportFocus(of:)` 938: `app.element.element(kAXFocusedWindowAttribute)` waits out the 1 s and gives nil like "no focused window" → `keyboardLeftTheKnownWindows()`. No `noteSilence`: the app is not marked, no task asks whether it is back, the next activation waits again.
If the app WAS marked (by an earlier call), `answers(pid)` is false at 938 and the report is dropped at once; `answersAgain` (527-532) refreshes windows and rescans and reports no focus; and `AXApplicationActivated`, which the app posts on waking, leads only to `keyboardFocusMoved()` (1078).
The variant "wakes, and is clicked within the half second (1.5 s on a Mac) before Arbor has asked again" is lost the same way (walk, polite seed 111).
HOW SURE: everything here is the layer's own logic on a polite Mac; the only assumption is that a hung app lets `AXFocusedWindow` time out, which is what hanging means. Not covered by the cure proposed for (c) (below): the same with and without it.
TO CONSIDER: read with `read(_:)`, `noteSilence` on `.cannotComplete`; end `answersAgain` with `reportFocus(of: pid)`.

### N6. Native tabs go wrong in two ways if the app's list of windows is behind by as little as 10 ms   (FOUND BY THE WALK, stale answers: 44 of 150 seeds)
WHAT A PERSON SEES: (1) ⌘T in a docked window: the new tab is announced as a NEW WINDOW (`appeared w102`): it floats, or is docked somewhere else; the old window keeps its slot as a window "on another Space", so the slot collapses. Arbor now has two windows for one. (2) The tab in front is closed:
the whole group is reported gone (`destroyed w102`), and the tab that now shows is unknown to Arbor until the app's focus next changes.
STORIES: "native tabs of an app whose list of windows is 10 / 50 ms behind", "the tab in front is closed, and the app's list of windows is 50 ms behind" (at 10 ms the second is green: "destroyed" comes 12 ms after "main window changed").
WHY: 1032-1036: "created" → `rescan` reads the list, which still has the old window and not the new → nothing to do → `addWindow(element…)` announces the newcomer. At the next rescan it is "a window the controller knows as a window of its own" and no candidate (690-691). 1038-1046: both rescans find the old list, `drop`.
Only a Space switch gets a second reading (`rescanSoon`).
HOW SURE: that lists lag is SEEN (640-644: "the app's list is behind, or in flux"; ledger "an-apps-window-list-lags-behind-the-screen"). That they lag at the moment a tab is made, and by how much: GUESS.
TO CONSIDER: before announcing a window that was reported created, ask the window server whether another known window of the app at the same frame has just gone off screen (`isOnScreen`): that is a tab whatever the list says. Or `rescanSoon` after every created / destroyed.

### N7. "Whoever posts a notification is awake" costs a second for each notification that was on its way when the app hung   (FOUND BY THE WALK, overtaking)
WHAT A PERSON SEES: an app opens a window and is at once busy loading what goes into it. Arbor's shortcuts, menu and socket are dead for FOUR seconds (three notifications on their way: created, focused, main changed).
STORY: "an app opens a window and is busy at once, loading what goes into it" (4.0 s).
WHY: 1019 `element.windowID` waits 1 s (GUESS: that `_AXUIElementGetWindow` waits for a hung app like any call), 1035 `rescan` waits 1 s and marks the app silent; then 1029 for the NEXT notification: `!answers(pid)` → `answersAgain` → `refresh` → `makeSnapshot` reads the title: 1 s, marked silent again (and one more detached task that asks every
half second); and so on for each. HOW SURE: the logic is the layer's own. That an app posts and then blocks within the 2 to 15 ms a notification takes is an everyday thing (a document window). Without the guess about `_AXUIElementGetWindow` it is 3 s.
TO CONSIDER: a notification proves that the app was awake when it POSTED. Believe it only if the app has been marked silent for longer than a notification can be under way (say 0.1 s), or let `answersAgain` make its first call off the main thread as the pinging task does.

### N8. Rare races, for the record (walk, 1 or 2 of 300 seeds each; listed as "sometimes")
- ⌘T a quarter of a second into a Space transition: the notice arrives after "created", `rescan(afterSpaceSwitch: true)` does not look for tabs, the new tab is announced as a window (`polite|191|space 19 16; space 9 52 +0.002; tab 31 58`).
- A window opens 2 ms before its app hangs; two Space switches later `countWindows` has counted it as there, and when the app wakes it is announced as found, not new (`overtaking|153|open 96 86 +0.002; hang 12 68; space 76 57; space 72 28`).

## What held (no finding), under all four kinds of bad manners, 400 seeds × 40 steps × 6
every window is announced once; no window is reported gone that is still open; nothing is reported about a window that was not announced or is gone; what the layer has announced is what it lists; flags (minimized, hidden, full screen, Space) and frames right after two seconds;
the layer's last word on the keyboard in the lenient sense (keyboardFocusMoved + focusedWindow()); no drag or resize left open with the button up; a drag or resize begins once and ends once. Duplicated notifications, a second mouse-up, dropped `AXMoved`, swallowed releases and late calls found NOTHING.

## Drags that are lost on a loaded Mac

Two ways to lose a drag. The first loses a drag of ANY length and is the likely one on the loaded hosted Macs. "Lost": no `dragBegan` for the whole drag, so no preview and no drop. The window has moved in every case, and Arbor knows where it ends up.
Stories: `scripts/mac-on-linux/tests/LostDrags.swift`.

### L1. The 24 points of patience: the window server is a moment late, the pointer is not
| the window server begins to move the window … after the press | pointer 10 points away by then | 24 points | 40 points |
|---|---|---|---|
| 0 ms | drag began 11 ms after the press | 11 ms | 11 ms |
| 100 ms | began at 121 ms | began at 121 ms | **LOST** |
| 400 ms | began at 421 ms | began at 421 ms | **LOST** |

(Each drag then goes on for 0.65 s and 200 points. The lost ones: 8 `AXMoved` arrive with the button down, each passed on as `windowChanged(userInitiated: true)`, none makes a drag.)
WHY: a `leftMouseDragged` arrives, `lookAtPressedWindow` (1220-1231) reads the window server's bounds, they are those of the press, `WindowGrab.classify` (WindowGrab.swift, last lines) finds "not moved, not resized, pointer more than `patience` = 24 away" → `.neither` →
`decide` sets `press.isSettled = true` (1248-1249). From then on BOTH signs are deaf until the button comes up: `lookAtPressedWindow` and `noteMoveWhilePressed` (1235) each begin with `guard … !press.isSettled`. One early look settles the whole press.
24 itself is safe (`> patience`). It is the DISTANCE at the first look that finds the window unmoved that counts, not the time: a slow hand survives 400 ms, a brisk one does not survive 100.
HOW IT FITS THE HOSTED MACS: the traces' synthetic pointer takes steps of about 18 points (drag-to-edge: 510 → 493 → 476), flick-to-edge of 56. Two steps, or one of a flick, before the window server has moved the window, and the drag is gone. On an idle Mac the window server moves the
window with the very event, so it never shows. That a loaded window server lags the pointer is a GUESS that fits; nobody has measured it. WORTH A RUN: log `serverBounds` against `cursorLocation()` at every leftMouseDragged on a loaded runner.

### L2. The whole gesture is over before Arbor hears of the press
| | a drag of a second (200 points) | a flick (0.27 s from press to release) |
|---|---|---|
| the monitor hears of the press 0 / 20 / 100 ms late | began at 151 ms (the hand rests 150 ms) | began at 151 ms |
| 500 ms late | began at 551 ms, 5 of 10 moves seen | **LOST** |
| Arbor's main thread busy 300 ms from the press; backlog served by time | began at 300 ms | **LOST** |
| … Accessibility's reports first | began at 311 ms | **LOST** |
| … the mouse's events first | began at 300 ms | **LOST** |

WHY: `makePress(at: cursorLocation())` (1139, 1169) and `lookAtPressedWindow` read the pointer and the window server NOW, not as they were when the event happened. Served late, mouse-down finds the pointer at its last place and the window already there; every queued `leftMouseDragged` compares that frame with
itself (`.undecided`); mouse-up ends nothing. The `AXMoved` in the backlog are no help in any order: before the mouse-down there is no `press` (1235 `guard let press`), after the release `isMouseButtonDown()` (990) is false.
A LATE PRESS ALONE LOSES NOTHING as long as the window still moves afterwards: it only delays `dragBegan`, in all three orders of the backlog. The order makes 11 ms of difference and no other.
So the leftMouseDown being late against the first AXMoved (0, 20, 100, 500 ms) is harmless by itself; it needs a gesture shorter than the lateness.

### Is anything logged? NO, at no level
arbor.log with ARBOR_DEBUG=1: a drag that is seen logs `DEBUG w101 is being dragged`. A lost one logs NOTHING: `.neither` (1248) and `.undecided` are silent, and so is a mouse-up with no grab (1150-1152). A trace would show the raw mouse lines and the `changed` events and no `dragBegan`.
CHEAP AND WORTH HAVING WHATEVER THE CURE: a debug line at 1249 ("the press on \(window) is settled as not about it: pointer N points away, window where it was"), and one at mouse-up when the pressed window's bounds differ from `press.frame` and no grab was open ("\(window) moved by dx, dy while the button was down and no drag was seen").

### What a person sees (storey two: the real controller on top; brisk hand, window server 100 ms late)
| story | on time | 100 ms late |
|---|---|---|
| a floating window is dragged to the left edge of the screen | preview, docked | **no preview; let go, it is NOT docked**: it lies half off screen at -207,350 |
| a docked window is dragged out onto the Desktop | floats where it was let go | **0.25 s after the release Arbor puts it back in its slot** (12,43 325×650): the drag-out is undone. While it is held Arbor does not pull at it |

### Towards a cure (not made here)
- `.neither` by patience need not be for good. Keep it as "not yet": if the pressed window's bounds later differ from `press.frame` by what the pointer has moved since the press (± a few points), it is a drag, however far the pointer had gone first. What patience is there for (text selected a long way, then Arbor or the app
  moves the window: the story "text is selected in a window…", and the ledger's "a false drag when swept windows fly back") does not move the window IN STEP with the pointer.
- For L2, at mouse-up: if no grab was open and `serverBounds(of: press.window)` ≠ `press.frame`… does not help as it stands, because `press.frame` was read late. The event's own location (`NSEvent.locationInWindow` of a global monitor's event is the screen location at the time of the event) would give `makePress` the true point;
  the frame at that time is lost either way, but `records[window].snapshot.frame`, Arbor's belief from before, is a good stand-in. With both, a flick served late could still be told as dragBegan + dragEnded.
- The self-test has a change for the other direction already ("a drag is known only by what the app reports").

### How sure
SEEN: the layer's code paths above run unmodified; `WindowGrab` is the real one. The traces' pointer steps and rests. GUESS: that a loaded window server starts late and then catches up with the pointer in one jump (modelled so); how the run loop orders a backlog (all three orders played; no difference).
The 15 red checks are listed in scripts/mac-on-linux/known-failures.txt, so whoever cures this deletes the lines.

## A cure proposed for R2, held against the stories before a Mac saw it

The branch fix/an-app-switch-is-never-dropped at a698364 (it asks again every 10 ms, for half a second, until macOS names the app), with `REF=`: that commit's Sources, this branch's stand-ins and stories. 657 checks in 146 stories on each side at the time.

VERDICT: it cures what it sets out to cure, at both storeys, up to its own limit of half a second, and NO check that is green on the trunk goes red.

### (i) ⌘Tab / Dock, the app's focused window unchanged and out of view

"lag" = how long NSWorkspace.frontmostApplication goes on naming the old app AFTER didActivateApplication was delivered.

| lag | storey one: the window is reported focused, once | storey two: the view moves to the window | trunk (both storeys) |
|---|---|---|---|
| 0 (fresh) | green | green | green |
| 5 ms | GREEN | GREEN | red |
| 8 ms | GREEN | GREEN | red |
| 20 ms | GREEN | GREEN | red |
| 50 ms | GREEN | GREEN | red |
| 200 ms | GREEN | GREEN | red |
| 600 ms | RED | RED (window stays at 1023,673) | red |

600 ms is past the cure's fifty looks (0.5 s): it gives up, logs at DEBUG only ("came forward and was never named as the app in front: nothing is reported"), and nothing ever reports the window. By design; whether a loaded Mac can lag
that long nobody has measured. The report comes at most 10 ms after the property catches up (seen: caught up at +36.6 ms, reported at +44.6 ms).

### (ii) the first new detail of R2 (lag 5 ms, caught up before AXApplicationActivated at 8 ms)
GREEN with the cure at both storeys. It does not lean on AXApplicationActivated or on the controller's `keyboardFocusMoved`: its own look 10 ms after the notice reports the window.

### (iii) the second new detail of R2 (a CLICK on ANOTHER window of the other app; AXFocusedWindowChanged / AXMainWindowChanged about 2 ms after the press, before didActivate)

| property | with the cure | trunk |
|---|---|---|
| fresh | green | green |
| stale 5, 8, 20, 50, 200 ms | GREEN: the clicked window is reported focused, no other window is | red |
| stale 600 ms | RED | red |

The two AX reports are still dropped at the `guard` in `reportFocus(of:)` (they come before even a well-behaved NSWorkspace names the app); the look after didActivate makes up for them, and reads the focused window THEN, so it reports the clicked one.

### Regressions: none found
- Green on the trunk and red with the cure: NONE of 657 checks.
- Reported twice: no. "once" is green at every lag.
- A→B→A within the half second, gaps of 30, 100, 300 ms × lags of 0, 50, 200 ms, both storeys (18 stories): all green with the cure. The last window reported focused is A's, no window is reported twice in a row, at storey two A's window ends in view.
  The look at B is cancelled when A comes forward (`lookAtAppThatCameForward?.cancel()`), and `Task.sleep` ends early on cancel, which the model honours. Three of these are RED ON THE TRUNK (100 ms/50 ms, 300 ms/50 ms, 300 ms/200 ms) and green with the cure.
- The rude walk, 300 seeds × 40 steps each: rule "a window whose app came forward while NSWorkspace still named another is reported focused":
  trunk 158 / 171 / 184 of 300 seeds broken (overtaking / stale answers / all four); WITH THE CURE 0 / 0 / 0. The same set of other rules is broken on both; the cure adds none.

### What the cure does NOT cover (N5 above)
An app that HANGS, or is still marked as silent, at the moment it comes forward is never reported focused, also after it wakes: `reportFocus(of:)` waits out the 1 s timeout on `kAXFocusedWindowAttribute`, says `keyboardFocusMoved`, does not call `noteSilence`
(so nobody asks whether the app is back, and every further ⌘Tab to it costs the main thread another second), and `answersAgain` refreshes windows but reports no focus. 8 of 150 polite seeds. Shortest script: `arborFocuses 96 4; hang 85 52; dies 24 10`
(the app in front quits, the app behind, which hangs, comes forward, then wakes). An app that is busy as it is switched to is an everyday thing. Same on trunk and cure.

### Small print
- The model's order and delays around a switch: didActivate 4 ms after the switch (GUESS), AXApplicationDeactivated +0.6 ms and AXApplicationActivated +8 ms after the notice (SEEN on hosted Macs). The lag itself is the knob.
- On trunk AND cure, a click on another app's window with a FRESH property can report that window focused twice within a millisecond (once for AXMainWindowChanged, once for didActivate, which resets `lastReportedFocus`). Harmless so far as the stories see; not new.
- When the cure lands: delete the lines about 5 ms and 50 ms from scripts/mac-on-linux/known-failures.txt (the run fails until then: that is the arrangement). The 600 ms stories stay listed, with a word that this is the cure's chosen limit.

## Still to check on a real Mac

- The order of "focused window changed" and `activeSpaceDidChange` at a Space switch between two windows of one app (N3). A trace of a Space switch is on the list of traces still to record.
- Whether a loaded window server lags the pointer: log `serverBounds` against `cursorLocation()` at every `leftMouseDragged` on a loaded runner (L1).
- How long `frontmostApplication` lags at most (R2: the cure gives up after half a second).
- Whether an app's list is behind when "created" of a new tab arrives (N6).
- Whether `_AXUIElementGetWindow` waits for an app that hangs (N7: four seconds with, three without).
- What a window on its way into full screen does with a frame it is given (N4).
